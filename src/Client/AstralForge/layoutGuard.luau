local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
local Reflect = core.Reflect
local Controller = core.Controller
local UserInputService = game:GetService("UserInputService")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
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
	stackSeparated = 0,
	pulledIntoView = 0,
	gaveUp = 0,
	learnedUpdates = 0,
	hotChecked = 0,
	signaturesSuppressed = 0,
}
local REPORT_EVERY = 60
local FRAME_BUDGET_SECONDS = 0.0015
local TEXT_COVER_SHARE = 0.08
local TEXT_COVER_HEIGHT = 0.3
local MIN_LABEL_WIDTH = 40
local LABEL_GAP = 6
local tryCount = setmetatable({}, { __mode = "k" })
local abandoned = setmetatable({}, { __mode = "k" })
local pendingFloor = setmetatable({}, { __mode = "k" })
local floorRejected = setmetatable({}, { __mode = "k" })
local followUp: ((Instance) -> ())? = nil
local touchProfile = false
-- Online repair model. Every inspection is a labelled sample ("did this element need a
-- repair?") for its signature: class + name + parent name, which is stable across
-- remounts of the same React tree. Each signature keeps a running repair probability
-- (a 1/n mean that settles into an exponential average), so the guard learns which
-- parts of the UI actually break on this device and re-checks those between sweeps.
-- Signatures whose repairs keep getting undone by their owner are learned as
-- "fighting" and left alone instead of burning budget every frame.
local LEARN_RATE = 0.18
local HOT_THRESHOLD = 0.3
local HOT_CAP = 48
local HOT_EVERY_FRAMES = 6
local HOT_BUDGET = 8
local THRASH_LIMIT = 3
local MODEL_CAP = 2048
local signatureCache = setmetatable({}, { __mode = "k" })
local model = {}
local modelSize = 0
local hotList = {}
local hotSet = setmetatable({}, { __mode = "k" })
local function signatureOf(inst)
	local cached = signatureCache[inst]
	if cached ~= nil then
		return cached
	end
	local parent = inst.Parent
	local signature = `{inst.ClassName}|{inst.Name}|{if parent ~= nil then parent.Name else ""}`
	signatureCache[inst] = signature
	return signature
end
local function forgetWeakest()
	local kept = 0
	for signature, entry in model do
		if entry.thrash == 0 and entry.p < 0.05 then
			model[signature] = nil
		else
			kept += 1
		end
	end
	if kept >= MODEL_CAP then
		table.clear(model)
		kept = 0
	end
	modelSize = kept
end
local function entryFor(signature)
	local entry = model[signature]
	if entry == nil then
		if modelSize >= MODEL_CAP then
			forgetWeakest()
		end
		entry = { p = 0, n = 0, thrash = 0 }
		model[signature] = entry
		modelSize += 1
	end
	return entry
end
local function learn(inst, repaired)
	local entry = entryFor(signatureOf(inst))
	entry.n += 1
	local rate = math.max(LEARN_RATE, 1 / entry.n)
	entry.p += ((if repaired then 1 else 0) - entry.p) * rate
	stats.learnedUpdates += 1
	if entry.p >= HOT_THRESHOLD and not hotSet[inst] and #hotList < HOT_CAP then
		hotSet[inst] = true
		hotList[#hotList + 1] = inst
	end
end
local function suppressed(inst)
	local entry = model[signatureOf(inst)]
	return entry ~= nil and entry.thrash >= THRASH_LIMIT
end
local function noteThrash(inst)
	local signature = signatureOf(inst)
	local entry = entryFor(signature)
	entry.thrash += 1
	if entry.thrash == THRASH_LIMIT then
		stats.signaturesSuppressed += 1
		ClientLog:warnEvery(`layoutguard:fight:{signature}`, 120, "LayoutGuard", `{signature} keeps undoing repairs; learned to leave it alone`)
	end
end
local function repairTotal()
	return stats.canvasDesyncFixed + stats.scrollingReenabled + stats.degenerateHidden + stats.overlapDemoted + stats.outOfBoxFixed + stats.textFitFixed + stats.textFloorRaised + stats.canvasSharpFixed + stats.textClearedOfButton + stats.textWrapped + stats.labelsUntangled + stats.stackSeparated + stats.pulledIntoView
end
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
	if abandoned[inst] or suppressed(inst) then
		return false
	end
	local tries = tryCount[inst] or 0
	if tries >= MAX_TRIES then
		abandoned[inst] = true
		stats.gaveUp += 1
		noteThrash(inst)
		return false
	end
	tryCount[inst] = tries + 1
	return true
end
local function isFloatingPanel(instance)
	return instance:IsA("Frame") and instance.Parent ~= nil and instance.Parent:IsA("LayerCollector")
end
local function isTrackedClass(instance)
	local ancestor = instance
	while ancestor ~= nil and not ancestor:IsA("LayerCollector") do
		if ancestor:GetAttribute(IGNORE_ATTRIBUTE) == true then
			return false
		end
		ancestor = ancestor.Parent
	end
	return instance:IsA("TextLabel") or instance:IsA("TextBox") or instance:IsA("GuiButton") or instance:IsA("CanvasGroup") or instance:IsA("ScrollingFrame") or isFloatingPanel(instance)
end
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
local function paintsOver(button)
	if button:IsA("TextButton") then
		return button.BackgroundTransparency < 0.6 or button.Text ~= ""
	end
	if button:IsA("ImageButton") then
		return button.BackgroundTransparency < 0.6 or (button.Image ~= "" and button.ImageTransparency < 0.6)
	end
	return false
end
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
local SOLID_MIN_GAP = 4
local MIN_LABEL_HEIGHT = 10
local stackPassLabels = {}
local stackPassSolids = {}
local function isSolid(inst)
	if not inst:IsA("GuiObject") or not inst.Visible or inst:IsA("TextLabel") then
		return false
	end
	if inst:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return false
	end
	if inst:IsA("TextBox") or inst:IsA("GuiButton") then
		return true
	end
	if inst.BackgroundTransparency < 0.9 then
		return true
	end
	return inst:FindFirstChildWhichIsA("TextBox") ~= nil or inst:FindFirstChildWhichIsA("GuiButton") ~= nil
end
local function innerBottom(parent)
	local pad = parent:FindFirstChildOfClass("UIPadding")
	local size = parent.AbsoluteSize
	local bottom = if pad ~= nil then pad.PaddingBottom.Scale * size.Y + pad.PaddingBottom.Offset else 0
	return parent.AbsolutePosition.Y + size.Y - bottom
end
local function separateStack(label, solid)
	local textRect = textRectOf(label)
	local solidRect = rectOf(solid)
	local across = math.min(textRect.x1, solidRect.x1) - math.max(textRect.x0, solidRect.x0)
	if across < 8 then
		return false
	end
	local labelRect = rectOf(label)
	if labelRect.y0 >= solidRect.y0 then
		return false
	end
	local intrude = textRect.y1 + SOLID_MIN_GAP - solidRect.y0
	if intrude <= 0.5 then
		return false
	end
	if engineOwns(solid) or engineOwns(label) then
		return false
	end
	local parent = solid.Parent
	local room = if parent ~= nil and parent:IsA("GuiObject") and not parent:IsA("ScrollingFrame") then innerBottom(parent) - solidRect.y1 else 0
	if room >= intrude and allowWrite(solid) then
		local shift = math.ceil(intrude)
		solid.Position = UDim2.new(solid.Position.X.Scale, solid.Position.X.Offset, solid.Position.Y.Scale, solid.Position.Y.Offset + shift)
		stats.stackSeparated += 1
		ClientLog:warnEvery(`layoutguard:stack:{solid:GetFullName()}`, 60, "LayoutGuard", `{label.Name} text ran into {solid.Name}; moved {solid.Name} down {shift}px`)
		return true
	end
	local available = solidRect.y0 - SOLID_MIN_GAP - labelRect.y0
	if available < MIN_LABEL_HEIGHT or not allowWrite(label) then
		return false
	end
	local current = labelRect.y1 - labelRect.y0
	local size = label.Size
	label.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + (available - current))
	if label.TextYAlignment == Enum.TextYAlignment.Center then
		label.TextYAlignment = Enum.TextYAlignment.Top
	end
	if not label.TextScaled then
		label.TextScaled = true
		if label:FindFirstChildOfClass("UITextSizeConstraint") == nil then
			local constraint = Instance.new("UITextSizeConstraint")
			constraint.Name = "LayoutGuardTextFit"
			constraint.MinTextSize = 8
			constraint.MaxTextSize = math.clamp(label.TextSize, 8, 42)
			constraint.Parent = label
		end
	end
	stats.stackSeparated += 1
	ClientLog:warnEvery(`layoutguard:stack:{label:GetFullName()}`, 60, "LayoutGuard", `{label.Name} text ran into {solid.Name}; fitted the label above it`)
	return true
end
local function checkStackedText(list)
	table.clear(stackPassLabels)
	table.clear(stackPassSolids)
	local seen = {}
	local function addSolid(solid)
		local parent = solid.Parent
		if parent == nil or seen[solid] or not isSolid(solid) then
			return
		end
		seen[solid] = true
		local bucket = stackPassSolids[parent] or {}
		stackPassSolids[parent] = bucket
		table.insert(bucket, solid)
	end
	for _, inst in list do
		local parent = inst.Parent
		if parent == nil then
			continue
		end
		if inst:IsA("TextLabel") then
			if inst.Visible and inst.Text ~= "" and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
				local bucket = stackPassLabels[parent] or {}
				stackPassLabels[parent] = bucket
				table.insert(bucket, inst)
			end
		elseif inst:IsA("TextBox") or inst:IsA("GuiButton") then
			addSolid(inst)
			if parent:IsA("Frame") and not engineOwns(inst) then
				addSolid(parent)
			end
		end
	end
	for parent, labels in stackPassLabels do
		local solids = stackPassSolids[parent]
		if solids == nil or parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
			continue
		end
		for _, label in labels do
			if label.AbsoluteSize.X < 8 or label.AbsoluteSize.Y < 4 then
				continue
			end
			for _, solid in solids do
				if separateStack(label, solid) then
					break
				end
			end
		end
	end
	table.clear(stackPassLabels)
	table.clear(stackPassSolids)
end
local inspectOnce
local function inspect(inst)
	local before = repairTotal()
	inspectOnce(inst)
	if inst.Parent ~= nil and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
		learn(inst, repairTotal() > before)
	end
end
function inspectOnce(inst)
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
		self.fresh = {}
		self.freshReady = {}
		self.freshSet = setmetatable({}, { __mode = "k" })
		self.freshScratch = {}
		self.freshReadyScratch = {}
		self.tracked = {}
		self.trackedIndex = setmetatable({}, { __mode = "k" })
		self.lastReportAt = os.clock()
		self.reportedTotal = 0
		self.queue = self.tracked
		self.cursor = 1
		self.lastWidth = -1
		self.lastHeight = -1
		self.burstLeft = 0
		self.armed = false
		self.rootConnections = {}
		self.watchedLayers = {}
		self.pendingOverlap = false
		self.hotCursor = 1
		self.deadline = math.huge
		self.overlapPhase = 1
	end
	function LayoutGuardController:hotPass(budget)
		local cursor = self.hotCursor or 1
		while budget > 0 and #hotList > 0 and os.clock() < self.deadline do
			if cursor > #hotList then
				cursor = 1
			end
			local inst = hotList[cursor]
			local entry = model[signatureOf(inst)]
			if inst.Parent == nil or entry == nil or entry.p < HOT_THRESHOLD * 0.5 or entry.thrash >= THRASH_LIMIT then
				hotSet[inst] = nil
				hotList[cursor] = hotList[#hotList]
				hotList[#hotList] = nil
			else
				cursor += 1
				budget -= 1
				if not self.freshSet[inst] then
					inspect(inst)
					stats.hotChecked += 1
				end
			end
		end
		self.hotCursor = cursor
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
	function LayoutGuardController:enqueue(instance, delay)
		if self.freshSet[instance] or not isTrackedClass(instance) then
			return nil
		end
		if #self.fresh >= Plan.FRESH_CAP then
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
		table.clear(self.tracked)
		table.clear(self.trackedIndex)
		self.watchedLayers = {}
		if root == nil then
			return nil
		end
		self:watchLayer(root)
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
		table.insert(self.rootConnections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:checkResize(root)
		end))
		self.lastWidth = -1
		self.lastHeight = -1
		self:checkResize(root)
	end
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
			-- A new viewport is new evidence: halve learned fights so they get re-tested.
			for _, entry in model do
				entry.thrash = entry.thrash // 2
			end
		end
		self.cursor = 1
		self.sinceSweep = Plan.MIN_SWEEP_SECONDS
		self.pendingOverlap = false
		self.overlapPhase = 1
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
	function LayoutGuardController:drainFresh(budget)
		local fresh = self.fresh
		local ready = self.freshReady
		if #fresh == 0 or budget <= 0 then
			return nil
		end
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
		local keptItems = self.freshScratch
		local keptReady = self.freshReadyScratch
		table.clear(keptItems)
		table.clear(keptReady)
		local count = #fresh
		local done = 0
		for index = 1, count do
			local instance = fresh[index]
			if done < budget and ready[index] <= self.frame and os.clock() < self.deadline then
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
		self.deadline = os.clock() + FRAME_BUDGET_SECONDS
		self.sinceSweep += _dt
		self:checkResize(root)
		local budget = Plan.budget(self.burstLeft, #self.fresh)
		if self.burstLeft > 0 then
			self.burstLeft -= 1
		end
		self:drainFresh(budget.fresh)
		local tracked = self.tracked
		if self.cursor > #tracked then
			if self.pendingOverlap then
				if os.clock() >= self.deadline then
					return nil
				end
				if self.overlapPhase == 1 then
					checkOverlappingHitboxes(self.queue)
				elseif self.overlapPhase == 2 then
					checkTextUnderButtons(self.queue)
				else
					checkStackedText(self.queue)
					table.clear(textPassLabels)
					table.clear(textPassButtons)
					self.pendingOverlap = false
				end
				self.overlapPhase = self.overlapPhase % 3 + 1
				self:report()
				return nil
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
		while sweepBudget > 0 and self.cursor <= #tracked and os.clock() < self.deadline do
			local inst = tracked[self.cursor]
			self.cursor += 1
			sweepBudget -= 1
			if inst.Parent == nil or self.freshSet[inst] then
				continue
			end
			inspect(inst)
			stats.sweepChecked += 1
		end
		if self.frame % HOT_EVERY_FRAMES == 0 then
			self:hotPass(HOT_BUDGET)
		end
		self:report()
	end
	function LayoutGuardController:report()
		local now = os.clock()
		if now - self.lastReportAt < REPORT_EVERY then
			return nil
		end
		self.lastReportAt = now
		local total = repairTotal()
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
			stacked = stats.stackSeparated,
			intoView = stats.pulledIntoView,
			overlap = stats.overlapDemoted,
			outOfBox = stats.outOfBoxFixed,
			gaveUp = stats.gaveUp,
			learned = modelSize,
			hot = #hotList,
			hotChecked = stats.hotChecked,
			fighting = stats.signaturesSuppressed,
		})
	end
	do
		Reflect.defineMetadata(LayoutGuardController, "identifier", "client/layoutGuard@LayoutGuardController")
		Reflect.defineMetadata(LayoutGuardController, "flamework:parameters", { "$c:components@Components", "client/framework/init@UiRuntimeController" })
		Reflect.defineMetadata(LayoutGuardController, "flamework:implements", { "$:flamework@OnInit", "$:flamework@OnStart", "$:flamework@OnTick" })
	end
end
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
