local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
local Reflect = core.Reflect
local Controller = core.Controller
local UserInputService = game:GetService("UserInputService")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
-- Type-only: erased at compile time, so this does NOT become a runtime require("./framework")
-- and cannot participate in the circular require that framework/index.ts's "side effect"
-- import of this file would otherwise create (framework/index.ts -> layoutGuard.ts -> back to
-- framework/index.ts). Keep this a `import type` — switching it to a value import would
-- reintroduce that cycle.
-- Layout guard for a UI-only game, working in real time.
-- React and the engine layout objects already place almost everything. This pass
-- only repairs what they leave behind, and it refuses to fight them:
--   * text that spills its box, and buttons clipped on a wild aspect ratio
--   * text too small to read on a phone, raised when it still fits
--   * CanvasGroup positions that land on a fractional pixel (that is what blurs them)
--   * a scrolling canvas that is shorter than its content
-- It runs every frame on a small budget (layoutGuardPlan): anything newly mounted
-- is checked the frame after the engine measures it, a background sweep revisits
-- everything else about once a second, and a resize or rotation gets a burst so
-- the whole screen settles almost at once. It writes a property only when the
-- measured defect is still there, and gives up if a write does not stick. That
-- keeps the screen from flickering and keeps AbsoluteSize reads off the hot path.
local Geom = require(script.Parent.LayoutKit)("layoutGeom")
local Plan = require(script.Parent.LayoutKit)("layoutGuardPlan")
local usesDesktopStructure = require(script.Parent.CoreKit)("interaction").usesDesktopStructure
local IGNORE_ATTRIBUTE = "LayoutGuardIgnore"
local FIT_SLOP = 6
local WILD_ASPECT_SLOP = 2
local MAX_TRIES = Plan.MAX_TRIES
local CANVAS_SHARP_EDGE = 512
local stats = {
	scans = 0,
	freshChecked = 0,
	sweepChecked = 0,
	bursts = 0,
	canvasDesyncFixed = 0,
	scrollingReenabled = 0,
	degenerateHidden = 0,
	overlapDemoted = 0,
	outOfBoxFixed = 0,
	textFitFixed = 0,
	textFloorRaised = 0,
	textFloorReverted = 0,
	canvasSharpFixed = 0,
	textClearedOfButton = 0,
	textUnderButtonSeen = 0,
	textWrapped = 0,
	labelsUntangled = 0,
	pulledIntoView = 0,
	gaveUp = 0,
}
-- How often repairs are rolled up into one log line (seconds). Individual repairs are
-- counted in `stats`; only a window that actually repaired something is reported.
local REPORT_EVERY = 60
-- A button counts as covering text once it hides this share of the text's real
-- (TextBounds) WIDTH while overlapping at least TEXT_COVER_HEIGHT of its height.
local TEXT_COVER_SHARE = 0.08
local TEXT_COVER_HEIGHT = 0.3
-- Never shrink a label below this many pixels to clear a button.
local MIN_LABEL_WIDTH = 40
local LABEL_GAP = 6
local tryCount = setmetatable({}, { __mode = "k" })
local abandoned = setmetatable({}, { __mode = "k" })
-- Labels whose size was raised for touch legibility, awaiting a fit check:
-- label -> the size React gave it.
local pendingFloor = setmetatable({}, { __mode = "k" })
local floorRejected = setmetatable({}, { __mode = "k" })
-- The guard's own follow-up checks (a raised label to verify next frame).
local followUp: ((Instance) -> ())? = nil
local touchProfile = false
local function isFiniteNumber(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end
local function rectOf(object)
	local pos = object.AbsolutePosition
	local size = object.AbsoluteSize
	return {
		x0 = pos.X,
		y0 = pos.Y,
		x1 = pos.X + size.X,
		y1 = pos.Y + size.Y,
	}
end
local function overlapArea(a, b)
	local x = math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0))
	local y = math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0))
	return x * y
end
local function rectArea(rect)
	return math.max(0, rect.x1 - rect.x0) * math.max(0, rect.y1 - rect.y0)
end
local function engineOwns(gui)
	if gui:FindFirstChildOfClass("UIFlexItem") ~= nil then
		return true
	end
	local parent = gui.Parent
	if parent == nil then
		return false
	end
	for _, child in parent:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPageLayout") or child:IsA("UITableLayout") then
			return true
		end
	end
	return false
end
local function allowWrite(inst)
	if abandoned[inst] then
		return false
	end
	local tries = tryCount[inst] or 0
	if tries >= MAX_TRIES then
		abandoned[inst] = true
		stats.gaveUp += 1
		return false
	end
	tryCount[inst] = tries + 1
	return true
end
-- A panel parented straight to a ScreenGui layer (portaled popovers, sheets) is
-- checked for spilling off the screen.
local function isFloatingPanel(instance)
	return instance:IsA("Frame") and instance.Parent ~= nil and instance.Parent:IsA("LayerCollector")
end
local function isTrackedClass(instance)
	return instance:IsA("TextLabel") or instance:IsA("TextBox") or instance:IsA("GuiButton") or instance:IsA("CanvasGroup") or instance:IsA("ScrollingFrame") or isFloatingPanel(instance)
end
-- Phones and tablets: raise small text to a readable size, but only when it
-- still fits its box. The raise is checked on the next frame and undone (for
-- good) if the text no longer fits.
local function applyTextFloor(label): boolean
	local original = pendingFloor[label]
	if original ~= nil then
		pendingFloor[label] = nil
		if not label.TextFits then
			label.TextSize = original
			floorRejected[label] = true
			stats.textFloorReverted += 1
		end
		return true
	end
	if floorRejected[label] or not touchProfile or not label:IsA("TextLabel") and not label:IsA("TextButton") then
		return false
	end
	local target = Plan.textFloor(touchProfile, label.TextSize, label.TextScaled)
	if target == nil or not label.TextFits then
		return false
	end
	pendingFloor[label] = label.TextSize
	label.TextSize = target
	stats.textFloorRaised += 1
	if followUp ~= nil then
		followUp(label)
	end
	return true
end
local function repairText(label)
	if abandoned[label] or label:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	if label.Text == "" or not label.Visible then
		return nil
	end
	local size = label.AbsoluteSize
	if size.X < 8 or size.Y < 8 or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
		return nil
	end
	if applyTextFloor(label) then
		return nil
	end
	if label.TextFits then
		tryCount[label] = nil
		return nil
	end
	if not allowWrite(label) then
		return nil
	end
	-- Room for two lines: wrap first, and only shrink if that still doesn't fit.
	if Plan.shouldWrap(label.TextSize, size.Y, label.TextWrapped, label.TextScaled) then
		label.TextWrapped = true
		stats.textWrapped += 1
		if followUp ~= nil then
			followUp(label)
		end
		return nil
	end
	local wrote = false
	if not label.TextScaled then
		label.TextScaled = true
		wrote = true
		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint == nil then
			constraint = Instance.new("UITextSizeConstraint")
			constraint.Name = "LayoutGuardTextFit"
			constraint.MinTextSize = if touchProfile then 9 else 8
			constraint.MaxTextSize = math.clamp(label.TextSize, 8, 42)
			constraint.Parent = label
		end
	elseif not label.TextWrapped and label.TextTruncate == Enum.TextTruncate.None then
		label.TextTruncate = Enum.TextTruncate.AtEnd
		wrote = true
	end
	if wrote then
		stats.textFitFixed += 1
	else
		abandoned[label] = true
		stats.gaveUp += 1
	end
end
local function repairButton(button)
	if button:IsA("TextButton") then
		repairText(button)
	end
	if abandoned[button] or button:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	local parent = button.Parent
	if parent == nil or not parent:IsA("GuiObject") or parent:IsA("ScrollingFrame") or engineOwns(button) then
		return nil
	end
	local pad = parent:FindFirstChildOfClass("UIPadding")
	local parentSize = parent.AbsoluteSize
	local parentPos = parent.AbsolutePosition
	local left = if pad ~= nil then pad.PaddingLeft.Scale * parentSize.X + pad.PaddingLeft.Offset else 0
	local top = if pad ~= nil then pad.PaddingTop.Scale * parentSize.Y + pad.PaddingTop.Offset else 0
	local right = if pad ~= nil then pad.PaddingRight.Scale * parentSize.X + pad.PaddingRight.Offset else 0
	local bottom = if pad ~= nil then pad.PaddingBottom.Scale * parentSize.Y + pad.PaddingBottom.Offset else 0
	local box = Geom.rect(parentPos.X + left, parentPos.Y + top, parentPos.X + parentSize.X - right, parentPos.Y + parentSize.Y - bottom)
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	if not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
		return nil
	end
	local rect = Geom.rectFromPosSize(pos.X, pos.Y, size.X, size.Y)
	if Geom.rectWidth(box) < 8 or Geom.rectHeight(box) < 8 then
		return nil
	end
	if Geom.overflowAmount(rect, box) <= (if math.max(size.X, size.Y) < 64 then WILD_ASPECT_SLOP else FIT_SLOP) then
		tryCount[button] = nil
		return nil
	end
	if not allowWrite(button) then
		return nil
	end
	local fitted = Geom.fitRect(rect, box, button.AnchorPoint.X, button.AnchorPoint.Y, 28, 28)
	local dw = Geom.rectWidth(fitted) - size.X
	local dh = Geom.rectHeight(fitted) - size.Y
	local shift = Geom.offsetDelta(button.AnchorPoint.X, button.AnchorPoint.Y, fitted.x0 - pos.X, fitted.y0 - pos.Y, dw, dh)
	button.Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset + dw, button.Size.Y.Scale, button.Size.Y.Offset + dh)
	button.Position = UDim2.new(button.Position.X.Scale, button.Position.X.Offset + shift.x, button.Position.Y.Scale, button.Position.Y.Offset + shift.y)
	stats.outOfBoxFixed += 1
end
-- A floating panel that hangs off the edge of its layer is moved back in.
local function repairFloatingPanel(panel)
	if abandoned[panel] or panel:GetAttribute(IGNORE_ATTRIBUTE) == true or not panel.Visible then
		return nil
	end
	local layer = panel.Parent
	if layer == nil or not layer:IsA("LayerCollector") then
		return nil
	end
	local screen = layer.AbsoluteSize
	local pos = panel.AbsolutePosition
	local size = panel.AbsoluteSize
	local layerPos = layer.AbsolutePosition
	if not isFiniteNumber(pos.X) or not isFiniteNumber(size.X) or size.X < 8 or size.Y < 8 then
		return nil
	end
	-- Full-screen hosts are layout roots, not floating panels.
	if size.X >= screen.X - 2 and size.Y >= screen.Y - 2 then
		return nil
	end
	local x0, y0 = pos.X - layerPos.X, pos.Y - layerPos.Y
	local dx, dy = Plan.nudgeIntoView(x0, y0, x0 + size.X, y0 + size.Y, screen.X, screen.Y)
	if math.abs(dx) < 1 and math.abs(dy) < 1 then
		tryCount[panel] = nil
		return nil
	end
	if not allowWrite(panel) then
		return nil
	end
	panel.Position = UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset + dx, panel.Position.Y.Scale, panel.Position.Y.Offset + dy)
	stats.pulledIntoView += 1
end
local function repairCanvasGroup(group)
	if abandoned[group] or group:GetAttribute(IGNORE_ATTRIBUTE) == true or engineOwns(group) then
		return nil
	end
	local size = group.AbsoluteSize
	local pos = group.AbsolutePosition
	if not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y) or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
		return nil
	end
	-- Larger than the sharp raster: resizing it would fight the layout that sized it.
	if math.max(size.X, size.Y) > CANVAS_SHARP_EDGE then
		return nil
	end
	local dx = Geom.snapPixel(pos.X) - pos.X
	local dy = Geom.snapPixel(pos.Y) - pos.Y
	if math.abs(dx) < 0.05 and math.abs(dy) < 0.05 then
		tryCount[group] = nil
		return nil
	end
	if not allowWrite(group) then
		return nil
	end
	group.Position = UDim2.new(group.Position.X.Scale, group.Position.X.Offset + dx, group.Position.Y.Scale, group.Position.Y.Offset + dy)
	stats.canvasSharpFixed += 1
end
-- AutomaticCanvasSize covers most cases, but any ScrollingFrame that computes CanvasSize
-- manually can drift short of its content. Grow only; never shrink a canvas that is
-- intentionally taller for bottom padding. One frame per visit, not a full-tree walk.
local function repairScrollingFrame(descendant)
	if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	local heldScroll = false
	if not descendant.ScrollingEnabled and descendant:GetAttribute("LayoutGuardAllowDisabledScroll") ~= true then
		heldScroll = true
		if allowWrite(descendant) then
			descendant.ScrollingEnabled = true
			stats.scrollingReenabled += 1
			ClientLog:warnEvery(`layoutguard:scrolldisabled:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} had ScrollingEnabled=false with no opt-out attribute — re-enabled`)
		end
	end
	if descendant.AutomaticCanvasSize ~= Enum.AutomaticSize.None then
		return nil
	end
	local maxBottom = 0
	for _, child in descendant:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			local layoutContentHeight = child.AbsoluteContentSize.Y
			if isFiniteNumber(layoutContentHeight) then
				maxBottom = layoutContentHeight
			end
			break
		end
	end
	if maxBottom <= 0 then
		for _, child in descendant:GetChildren() do
			if not child:IsA("GuiObject") or not child.Visible then
				continue
			end
			local bottom = child.Position.Y.Scale * descendant.AbsoluteSize.Y + child.Position.Y.Offset + child.Size.Y.Scale * descendant.AbsoluteSize.Y + child.Size.Y.Offset
			if isFiniteNumber(bottom) then
				maxBottom = math.max(maxBottom, bottom)
			end
		end
	end
	if maxBottom <= 0 then
		return nil
	end
	local currentCanvas = descendant.CanvasSize.Y.Offset
	if currentCanvas + 24 >= maxBottom then
		if not heldScroll then
			tryCount[descendant] = nil
		end
		return nil
	end
	if not allowWrite(descendant) then
		return nil
	end
	descendant.CanvasSize = UDim2.new(descendant.CanvasSize.X.Scale, descendant.CanvasSize.X.Offset, 0, math.ceil(maxBottom))
	stats.canvasDesyncFixed += 1
	ClientLog:warnEvery(`layoutguard:canvas:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} CanvasSize ({currentCanvas}px) was shorter than its content ({string.format("%.0f", maxBottom)}px) — resynced`)
end
-- Roblox already ignores hits on a GuiObject with Visible=false or Active=false, and
-- InputBegan doesn't fire on descendants covered by a higher-ZIndex sibling that also has
-- Active=true — that native occlusion is exactly what we're checking hasn't gone wrong here.
-- This only flags a *same-parent* pair since ZIndex comparisons across different parents
-- aren't meaningful, and only pairs at the same ZIndex (a deliberately layered higher-ZIndex
-- control on top of a lower one, like a close button over a card, is the normal, correct
-- pattern this app uses everywhere and must not be touched).
local function checkOverlappingHitboxes(root)
	local byParent = {}
	local list = if typeof(root) == "table" then root else root:GetDescendants()
	for _, descendant in list do
		if descendant.Parent == nil or not descendant:IsA("GuiButton") then
			continue
		end
		if not descendant.Visible or not descendant.Active then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		local parent = descendant.Parent
		local siblings = byParent[parent]
		if siblings then
			table.insert(siblings, descendant)
		else
			byParent[parent] = { descendant }
		end
	end
	for _, siblings in byParent do
		if #siblings < 2 then
			continue
		end
		for i = 1, #siblings do
			local a = siblings[i]
			local rectA = rectOf(a)
			local areaA = rectArea(rectA)
			if areaA <= 0 then
				continue
			end
			for j = i + 1, #siblings do
				local b = siblings[j]
				if a.ZIndex ~= b.ZIndex then
					continue
				end
				local rectB = rectOf(b)
				local areaB = rectArea(rectB)
				if areaB <= 0 then
					continue
				end
				local overlap = overlapArea(rectA, rectB)
				local smaller = math.min(areaA, areaB)
				if smaller <= 0 or overlap / smaller < 0.85 then
					continue
				end
				-- Same ZIndex, same parent, one almost entirely covers the other, and neither
				-- opted out: this is the shape of a real accidental stack (e.g. a row's tap
				-- target left full-width behind a narrower action button added later), not a
				-- deliberate composed layer — those always differ in ZIndex in this codebase.
				-- Fix by giving the later sibling (b, which draws on top and therefore already
				-- wins ties) priority and nudging the occluded one behind it, restoring input
				-- to whichever control the ZIndex ordering already implies should win.
				-- React may write the prop ZIndex back; give up after MAX_TRIES instead of
				-- climbing forever.
				if not allowWrite(b) then
					continue
				end
				b.ZIndex = a.ZIndex + 1
				stats.overlapDemoted += 1
				ClientLog:warnEvery(`layoutguard:overlap:{a:GetFullName()}`, 30, "LayoutGuard", `{a.Name} and {b.Name} share ZIndex {a.ZIndex} and overlap {string.format("%.0f", (overlap / smaller) * 100)}% — separated so input reaches the top one`)
			end
		end
	end
end
-- Does this button actually paint over what is behind it? Most buttons in this UI are
-- transparent hit areas with painted frames inside them; those cover nothing. Only a
-- button with its own visible fill, image or label can hide a sibling's text.
local function paintsOver(button)
	if button:IsA("TextButton") then
		return button.BackgroundTransparency < 0.6 or button.Text ~= ""
	end
	if button:IsA("ImageButton") then
		return button.BackgroundTransparency < 0.6 or (button.Image ~= "" and button.ImageTransparency < 0.6)
	end
	return false
end
-- Where the glyphs really are inside a label (TextBounds placed by the alignment),
-- which is usually much smaller than the label's box.
local function textRectOf(label)
	local pos = label.AbsolutePosition
	local size = label.AbsoluteSize
	local bounds = label.TextBounds
	local w = math.min(bounds.X, size.X)
	local h = math.min(bounds.Y, size.Y)
	local x0 = pos.X
	if label.TextXAlignment == Enum.TextXAlignment.Right then
		x0 = pos.X + size.X - w
	elseif label.TextXAlignment == Enum.TextXAlignment.Center then
		x0 = pos.X + (size.X - w) / 2
	end
	local y0 = pos.Y
	if label.TextYAlignment == Enum.TextYAlignment.Bottom then
		y0 = pos.Y + size.Y - h
	elseif label.TextYAlignment == Enum.TextYAlignment.Center then
		y0 = pos.Y + (size.Y - h) / 2
	end
	return { x0 = x0, y0 = y0, x1 = x0 + w, y1 = y0 + h }
end
-- A label's text is partly hidden by a painted sibling button. The common shape is a
-- row: a full-width label with an action button laid over its right (or left) end. The
-- label is narrowed so its text ends before the button, on the side the button
-- intrudes from, keeping its anchored edge fixed. Anything the engine lays out, anything
-- centered, and anything that would end up too narrow is left alone (and only counted).
local function clearTextOfButton(label, button, buttonRect)
	if label:GetAttribute(IGNORE_ATTRIBUTE) == true or engineOwns(label) then
		return false
	end
	local labelRect = rectOf(label)
	local current = labelRect.x1 - labelRect.x0
	local anchor = label.AnchorPoint.X
	local target
	if anchor == 0 and buttonRect.x0 > labelRect.x0 + MIN_LABEL_WIDTH then
		target = buttonRect.x0 - labelRect.x0 - LABEL_GAP
	elseif anchor == 1 and buttonRect.x1 < labelRect.x1 - MIN_LABEL_WIDTH then
		target = labelRect.x1 - buttonRect.x1 - LABEL_GAP
	else
		return false
	end
	if target >= current - 2 or target < MIN_LABEL_WIDTH then
		return false
	end
	if not allowWrite(label) then
		return false
	end
	local size = label.Size
	label.Size = UDim2.new(size.X.Scale, size.X.Offset + (target - current), size.Y.Scale, size.Y.Offset)
	if not label.TextWrapped and not label.TextScaled and label.TextTruncate == Enum.TextTruncate.None then
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end
	stats.textClearedOfButton += 1
	return true
end
-- Sibling pass over the tracked set: for every visible label with text, find a painted
-- button under the same parent that sits at or above it and covers a meaningful share of
-- the glyphs. `byParent` is reused between runs (cleared, not rebuilt).
local textPassLabels = {}
local textPassButtons = {}
local function checkTextUnderButtons(list)
	table.clear(textPassLabels)
	table.clear(textPassButtons)
	for _, inst in list do
		if inst.Parent == nil then
			continue
		end
		if inst:IsA("GuiButton") then
			if inst.Visible and paintsOver(inst) and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
				local bucket = textPassButtons[inst.Parent]
				if bucket == nil then
					bucket = {}
					textPassButtons[inst.Parent] = bucket
				end
				table.insert(bucket, inst)
			end
		elseif inst:IsA("TextLabel") and inst.Visible and inst.Text ~= "" then
			local bucket = textPassLabels[inst.Parent]
			if bucket == nil then
				bucket = {}
				textPassLabels[inst.Parent] = bucket
			end
			table.insert(bucket, inst)
		end
	end
	for parent, labels in textPassLabels do
		local buttons = textPassButtons[parent]
		-- Labels laid over each other in a row: the left one is narrowed to end before
		-- the right one's glyphs start.
		if #labels > 1 and not parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
			for i = 1, #labels do
				local left = labels[i]
				if left.AbsoluteSize.X < 8 then
					continue
				end
				local leftText = textRectOf(left)
				for j = 1, #labels do
					local right = labels[j]
					if right == left or right.AbsoluteSize.X < 8 then
						continue
					end
					local rightText = textRectOf(right)
					if rightText.x0 > leftText.x0 + 4 and Plan.labelsCollide(leftText, rightText) then
						if clearTextOfButton(left, right, rightText) then
							stats.labelsUntangled += 1
							ClientLog:warnEvery(`layoutguard:labels:{left:GetFullName()}`, 60, "LayoutGuard", `{left.Name} ran into {right.Name}; narrowed to clear it`)
						end
						break
					end
				end
			end
		end
		if buttons == nil then
			continue
		end
		for _, label in labels do
			local size = label.AbsoluteSize
			if size.X < 8 or size.Y < 8 or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
				continue
			end
			local textRect = textRectOf(label)
			local textWidth = textRect.x1 - textRect.x0
			local textHeight = textRect.y1 - textRect.y0
			if textWidth <= 0 or textHeight <= 0 then
				continue
			end
			for _, button in buttons or {} do
				if button.ZIndex < label.ZIndex then
					continue
				end
				local buttonRect = rectOf(button)
				-- Measured on each axis, not as an area share: tall (wrapped or scaled)
				-- text would otherwise hide a real slice of its width and still score low.
				local hidden = math.max(0, math.min(textRect.x1, buttonRect.x1) - math.max(textRect.x0, buttonRect.x0))
				local shared = math.max(0, math.min(textRect.y1, buttonRect.y1) - math.max(textRect.y0, buttonRect.y0))
				if hidden / textWidth < TEXT_COVER_SHARE or shared / textHeight < TEXT_COVER_HEIGHT then
					continue
				end
				stats.textUnderButtonSeen += 1
				if clearTextOfButton(label, button, buttonRect) then
					ClientLog:warnEvery(`layoutguard:textcover:{label:GetFullName()}`, 60, "LayoutGuard", `{label.Name} text was under {button.Name}; label narrowed to clear it`)
				end
				break
			end
		end
	end
end
-- One instance: hide non-finite geometry, then the class-specific repair.
local function inspect(inst)
	if inst.Parent == nil then
		return nil
	end
	local size = inst.AbsoluteSize
	local pos = inst.AbsolutePosition
	local broken = not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y)
	if broken and inst:IsA("GuiObject") and inst.Visible and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
		if allowWrite(inst) then
			inst.Visible = false
			stats.degenerateHidden += 1
			ClientLog:warnEvery(`layoutguard:degenerate:{inst:GetFullName()}`, 30, "LayoutGuard", `{inst.Name} rendered with non-finite geometry — hidden to avoid a broken/mispositioned element on screen`)
		end
		return nil
	end
	if inst:IsA("ScrollingFrame") then
		repairScrollingFrame(inst)
	elseif isFloatingPanel(inst) then
		repairFloatingPanel(inst)
	elseif inst:IsA("CanvasGroup") then
		repairCanvasGroup(inst)
	elseif inst:IsA("GuiButton") then
		repairButton(inst)
	elseif inst:IsA("TextLabel") or inst:IsA("TextBox") then
		repairText(inst)
	end
end
local function readTouchProfile()
	return UserInputService.TouchEnabled and not usesDesktopStructure()
end
-- A Flamework controller rather than a plain module: its "root" is the same singleton
-- ScreenGui that UiRootComponent/DiagnosticsController already resolve via Components DI
-- (see framework/index.ts), so unlike most systems in this app it has no runtime constructor
-- argument Flamework's zero-arg controller instantiation would need to work around — it can
-- just ask Components for the current UiRootComponent the same way DiagnosticsController does.
local LayoutGuardController
do
	LayoutGuardController = setmetatable({}, {
		__tostring = function()
			return "LayoutGuardController"
		end,
	})
	LayoutGuardController.__index = LayoutGuardController
	function LayoutGuardController.new(...)
		local self = setmetatable({}, LayoutGuardController)
		return self:constructor(...) or self
	end
	function LayoutGuardController:constructor(components, runtime)
		self.components = components
		self.runtime = runtime
		self.frame = 0
		self.sinceSweep = 0
		-- Fresh work: instances just mounted (or awaiting a follow-up check),
		-- each with the frame it becomes ready on.
		self.fresh = {}
		self.freshReady = {}
		self.freshSet = setmetatable({}, { __mode = "k" })
		-- Second buffer for drainFresh: entries are compacted into it and the two swap, so
		-- draining allocates nothing even when work is being queued while it runs.
		self.freshScratch = {}
		self.freshReadyScratch = {}
		-- The tracked set: every text, button, canvas and scrolling instance under the
		-- root, kept current from DescendantAdded/Removing instead of being rebuilt by a
		-- full-tree walk. `trackedIndex` makes removal O(1) (swap with the last entry).
		self.tracked = {}
		self.trackedIndex = setmetatable({}, { __mode = "k" })
		self.lastReportAt = os.clock()
		self.reportedTotal = 0
		-- The background sweep: a round-robin cursor over `tracked`.
		self.queue = self.tracked
		self.cursor = 1
		self.lastWidth = -1
		self.lastHeight = -1
		self.burstLeft = 0
		self.armed = false
		self.rootConnections = {}
		self.watchedLayers = {}
		self.pendingOverlap = false
	end
	function LayoutGuardController:onInit()
		self.armed = true
		touchProfile = readTouchProfile()
		followUp = function(instance)
			self:enqueue(instance, Plan.SETTLE_FRAMES + 1)
		end
		local refresh = function()
			touchProfile = readTouchProfile()
		end
		UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh)
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	end
	-- Queue one instance for a check `delay` frames from now.
	function LayoutGuardController:enqueue(instance, delay)
		if self.freshSet[instance] or not isTrackedClass(instance) then
			return nil
		end
		if #self.fresh >= Plan.FRESH_CAP then
			-- Too much at once (a whole page mounting): the sweep will get there.
			return nil
		end
		self.freshSet[instance] = true
		table.insert(self.fresh, instance)
		table.insert(self.freshReady, self.frame + (delay or Plan.SETTLE_FRAMES))
	end
	function LayoutGuardController:track(instance)
		if self.trackedIndex[instance] ~= nil or not isTrackedClass(instance) then
			return nil
		end
		local tracked = self.tracked
		local index = #tracked + 1
		tracked[index] = instance
		self.trackedIndex[instance] = index
	end
	function LayoutGuardController:untrack(instance)
		local index = self.trackedIndex[instance]
		if index == nil then
			return nil
		end
		local tracked = self.tracked
		local last = #tracked
		local moved = tracked[last]
		tracked[index] = moved
		self.trackedIndex[moved] = index
		tracked[last] = nil
		self.trackedIndex[instance] = nil
	end
	function LayoutGuardController:markDirty(instance)
		if instance ~= nil then
			tryCount[instance] = nil
			abandoned[instance] = nil
			self:enqueue(instance, Plan.SETTLE_FRAMES)
		end
	end
	-- Track one layer's descendants and keep the set current from its add/remove events.
	function LayoutGuardController:watchLayer(layer)
		if self.watchedLayers[layer] then
			return nil
		end
		self.watchedLayers[layer] = true
		for _, descendant in layer:GetDescendants() do
			self:track(descendant)
		end
		table.insert(self.rootConnections, layer.DescendantAdded:Connect(function(instance)
			self:track(instance)
			self:markDirty(instance)
		end))
		table.insert(self.rootConnections, layer.DescendantRemoving:Connect(function(instance)
			self:untrack(instance)
			tryCount[instance] = nil
			abandoned[instance] = nil
			pendingFloor[instance] = nil
		end))
	end
	function LayoutGuardController:bindRoot(root)
		for _, connection in self.rootConnections do
			connection:Disconnect()
		end
		table.clear(self.rootConnections)
		-- Start the tracked set over for the new root: one walk now, then only deltas.
		table.clear(self.tracked)
		table.clear(self.trackedIndex)
		self.watchedLayers = {}
		if root == nil then
			return nil
		end
		self:watchLayer(root)
		-- Every other game layer too: dropdowns, sheets and toasts are portaled into
		-- their own ScreenGuis and used to go unchecked.
		local playerGui = root:FindFirstAncestorOfClass("PlayerGui")
		if playerGui ~= nil then
			local function consider(layer)
				if layer:IsA("LayerCollector") and layer ~= root and layer:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
					self:watchLayer(layer)
				end
			end
			for _, layer in playerGui:GetChildren() do
				consider(layer)
			end
			table.insert(self.rootConnections, playerGui.ChildAdded:Connect(consider))
			table.insert(self.rootConnections, playerGui.ChildRemoved:Connect(function(layer)
				self.watchedLayers[layer] = nil
				for _, descendant in layer:GetDescendants() do
					self:untrack(descendant)
				end
			end))
		end
		-- A resize is handled the frame it happens, not at the next scan.
		table.insert(self.rootConnections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:checkResize(root)
		end))
		self.lastWidth = -1
		self.lastHeight = -1
		self:checkResize(root)
	end
	-- A new screen size (window resize, rotation, keyboard): forget old caps,
	-- restart the sweep and spend a burst budget so everything settles quickly.
	function LayoutGuardController:checkResize(root)
		local size = root.AbsoluteSize
		if not Plan.resized(self.lastWidth, self.lastHeight, size.X, size.Y) then
			return false
		end
		local first = self.lastWidth < 0
		self.lastWidth = size.X
		self.lastHeight = size.Y
		if not first then
			table.clear(tryCount)
			table.clear(abandoned)
		end
		-- Restart the round-robin from the top; the tracked set itself stays (it is kept
		-- current by the add/remove events, a resize does not change what exists).
		self.cursor = 1
		self.sinceSweep = Plan.MIN_SWEEP_SECONDS
		self.pendingOverlap = false
		self.burstLeft = Plan.BURST_FRAMES
		stats.bursts += 1
		return true
	end
	function LayoutGuardController:onStart()
		self.components:onComponentAdded(function(component)
			self.target = component
			self:bindRoot(component.instance)
			return self.target
		end, "client/framework/init@UiRootComponent")
		local _binding = self.components:getAllComponents("client/framework/init@UiRootComponent")
		local existing = _binding[1]
		if existing ~= nil then
			self.target = existing
			self:bindRoot(existing.instance)
		end
	end
	-- Fresh work whose settle frame has come, oldest first, up to `budget`.
	function LayoutGuardController:drainFresh(budget)
		local fresh = self.fresh
		local ready = self.freshReady
		if #fresh == 0 or budget <= 0 then
			return nil
		end
		-- Nothing due yet (the common frame while a batch is still settling): skip the
		-- two table allocations below.
		local anyDue = false
		for index = 1, #fresh do
			if ready[index] <= self.frame then
				anyDue = true
				break
			end
		end
		if not anyDue then
			return nil
		end
		-- Compact into the reusable second buffer and swap. inspect() can queue follow-ups
		-- (enqueue appends to `fresh` while we iterate), so remember how many entries we
		-- started with and carry over anything appended past that point afterwards.
		local keptItems = self.freshScratch
		local keptReady = self.freshReadyScratch
		table.clear(keptItems)
		table.clear(keptReady)
		local count = #fresh
		local done = 0
		for index = 1, count do
			local instance = fresh[index]
			if done < budget and ready[index] <= self.frame then
				done += 1
				self.freshSet[instance] = nil
				if instance.Parent ~= nil then
					inspect(instance)
					stats.freshChecked += 1
				end
			else
				keptItems[#keptItems + 1] = instance
				keptReady[#keptReady + 1] = ready[index]
			end
		end
		for index = count + 1, #fresh do
			keptItems[#keptItems + 1] = fresh[index]
			keptReady[#keptReady + 1] = ready[index]
		end
		self.freshScratch = fresh
		self.freshReadyScratch = ready
		self.fresh = keptItems
		self.freshReady = keptReady
	end
	function LayoutGuardController:onTick(_dt)
		local _root = self.target
		if _root ~= nil then
			_root = _root.instance
		end
		local root = _root
		if root == nil and self.runtime ~= nil then
			local primary = self.runtime:primary()
			if primary ~= nil then
				self.target = primary
				root = primary.instance
				self:bindRoot(root)
			end
		end
		if root == nil then
			return nil
		end
		self.frame += 1
		self.sinceSweep += _dt
		self:checkResize(root)
		local budget = Plan.budget(self.burstLeft, #self.fresh)
		if self.burstLeft > 0 then
			self.burstLeft -= 1
		end
		self:drainFresh(budget.fresh)
		-- The background sweep. A finished sweep runs the hitbox pass over what it
		-- saw (geometry repairs have settled by then), then waits out the minimum
		-- interval before walking the tree again.
		-- The sweep walks `tracked` with a round-robin cursor: no tree walk, no new table.
		-- (A removal swaps the last entry into the freed slot, so an entry can occasionally
		-- be skipped for one pass; the next pass picks it up.)
		local tracked = self.tracked
		if self.cursor > #tracked then
			if self.pendingOverlap then
				-- self.queue IS the tracked set (aliased in the constructor).
				checkOverlappingHitboxes(self.queue)
				checkTextUnderButtons(self.queue)
				-- Do not keep parents alive between passes.
				table.clear(textPassLabels)
				table.clear(textPassButtons)
				self.pendingOverlap = false
			end
			if self.sinceSweep < Plan.MIN_SWEEP_SECONDS then
				self:report()
				return nil
			end
			self.sinceSweep = 0
			self.cursor = 1
			self.pendingOverlap = true
			stats.scans += 1
		end
		local sweepBudget = budget.sweep
		while sweepBudget > 0 and self.cursor <= #tracked do
			local inst = tracked[self.cursor]
			self.cursor += 1
			sweepBudget -= 1
			if inst.Parent == nil or self.freshSet[inst] then
				continue
			end
			inspect(inst)
			stats.sweepChecked += 1
		end
		self:report()
	end
	-- One rolled-up line per window that actually repaired something (instead of a
	-- warning per repair). Totals are the sum of every repair counter in `stats`.
	function LayoutGuardController:report()
		local now = os.clock()
		if now - self.lastReportAt < REPORT_EVERY then
			return nil
		end
		self.lastReportAt = now
		local total = stats.canvasDesyncFixed + stats.scrollingReenabled + stats.degenerateHidden + stats.overlapDemoted + stats.outOfBoxFixed + stats.textFitFixed + stats.textFloorRaised + stats.canvasSharpFixed + stats.textClearedOfButton + stats.textWrapped + stats.labelsUntangled + stats.pulledIntoView
		if total == self.reportedTotal then
			return nil
		end
		local delta = total - self.reportedTotal
		self.reportedTotal = total
		ClientLog:info("LayoutGuard", `{delta} repair{if delta == 1 then "" else "s"} in the last {REPORT_EVERY}s`, {
			tracked = #self.tracked,
			textFit = stats.textFitFixed,
			textOffButton = stats.textClearedOfButton,
			wrapped = stats.textWrapped,
			labels = stats.labelsUntangled,
			intoView = stats.pulledIntoView,
			overlap = stats.overlapDemoted,
			outOfBox = stats.outOfBoxFixed,
			gaveUp = stats.gaveUp,
		})
	end
	do
		-- (Flamework) LayoutGuardController metadata
		Reflect.defineMetadata(LayoutGuardController, "identifier", "client/layoutGuard@LayoutGuardController")
		Reflect.defineMetadata(LayoutGuardController, "flamework:parameters", { "$c:components@Components", "client/framework/init@UiRuntimeController" })
		Reflect.defineMetadata(LayoutGuardController, "flamework:implements", { "$:flamework@OnInit", "$:flamework@OnStart", "$:flamework@OnTick" })
	end
end
-- (Flamework) LayoutGuardController decorators
Reflect.decorate(LayoutGuardController, "$:flamework@Controller", Controller, { {
	loadOrder = 10,
} })
local function layoutGuardStats()
	return stats
end
return {
	layoutGuardStats = layoutGuardStats,
	LayoutGuardController = LayoutGuardController,
}
