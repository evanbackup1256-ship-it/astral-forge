local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
local Reflect = core.Reflect
local Controller = core.Controller
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local Geom = require(script.Parent.LayoutKit)("layoutGeom")
local Plan = require(script.Parent.LayoutKit)("layoutGuardPlan")
local Diagnostics = require(script.Parent.LayoutDiagnostics)
local diagnostics = Diagnostics.new(os.clock)
local UserInputService = game:GetService("UserInputService")
local IGNORE_ATTRIBUTE = "LayoutGuardIgnore"
local FIT_SLOP = 6
local WILD_ASPECT_SLOP = 2
local MAX_TRIES = Plan.MAX_TRIES
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
	smallTouchTargets = 0,
	actionsOutsideViewport = 0,
	actionsOutsideParent = 0,
	actionCollisions = 0,
	clippedActions = 0,
	geometryChanges = 0,
	dirtyDescendants = 0,
	nestedScrollConflicts = 0,
}
local MIN_TOUCH_TARGET = 44
local INPUT_SHIELD_SHARE = 0.8
local COLLISION_CELL = 96
local DIRTY_DESCENDANT_CAP = 128
local REPORT_EVERY = 60
local FRAME_BUDGET_SECONDS = 0.0015
-- Live clients use a smaller budget; all diagnostics and bounded collision passes still run.
local IS_STUDIO = game:GetService("RunService"):IsStudio()
local LIVE_BUDGET_SECONDS = 0.0005
local TEXT_COVER_SHARE = 0.08
local TEXT_COVER_HEIGHT = 0.3
local tryCount = setmetatable({}, { __mode = "k" })
local abandoned = setmetatable({}, { __mode = "k" })
-- Inspection priority is learned from observed defects, not from changing the UI.
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
	if not Diagnostics.canRecover(inst, "Canvas") and not Diagnostics.canRecover(inst, "FloatingPanel") then
		return false
	end
	if abandoned[inst] or suppressed(inst) then
		return false
	end
	local tries = tryCount[inst] or 0
	if tries >= MAX_TRIES then
		diagnostics:record(inst, "OwnerConflict", "Scoped recovery repeatedly reset by owner; further writes suppressed")
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
local interactionLayer
local function isActionable(instance)
	return (instance:IsA("GuiButton") and instance.Active) or (instance:IsA("TextBox") and instance.TextEditable)
end
local function recordViewportAction(instance, rect)
	local layer = interactionLayer(instance)
	if layer == nil then
		return
	end
	local layerRect = rectOf(layer)
	if Geom.overflowAmount(rect, layerRect) > FIT_SLOP then
		if diagnostics:record(instance, "ActionOutsideViewport", "Active control extends beyond the visible viewport") then
			stats.actionsOutsideViewport += 1
		end
	end
end
local function clippingAncestor(instance, rect)
	local ancestor = instance.Parent
	while ancestor ~= nil and not ancestor:IsA("LayerCollector") do
		if ancestor:IsA("GuiObject") and ancestor.ClipsDescendants and not ancestor:IsA("ScrollingFrame") then
			if Geom.overflowAmount(rect, rectOf(ancestor)) > FIT_SLOP then
				return ancestor
			end
		end
		ancestor = ancestor.Parent
	end
	return nil
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
	local pos = label.AbsolutePosition
	local rect = Geom.rectFromPosSize(pos.X, pos.Y, size.X, size.Y)
	if isActionable(label) then
		if UserInputService.TouchEnabled and (size.X < MIN_TOUCH_TARGET or size.Y < MIN_TOUCH_TARGET) then
			if diagnostics:record(label, "SmallTouchTarget", `Editable field is {math.floor(size.X)}×{math.floor(size.Y)}px; touch fields need at least {MIN_TOUCH_TARGET}×{MIN_TOUCH_TARGET}px`) then
				stats.smallTouchTargets += 1
			end
		end
		recordViewportAction(label, rect)
		local clippedBy = clippingAncestor(label, rect)
		if clippedBy ~= nil and diagnostics:record(label, "ClippedAction", `Action exceeds clipped ancestor {clippedBy:GetFullName()}`) then
			stats.clippedActions += 1
		end
	end
	if label.TextFits then
		tryCount[label] = nil
		return nil
	end
	diagnostics:record(label, "TextOverflow", `Text {label.TextBounds.X}×{label.TextBounds.Y} exceeds box {size.X}×{size.Y}; owner must wrap, reflow or allocate space`)
end
local function repairButton(button)
	if button:IsA("TextButton") then
		repairText(button)
	end
	if abandoned[button] or button:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	if not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y) then
		return nil
	end
	local rect = Geom.rectFromPosSize(pos.X, pos.Y, size.X, size.Y)
	if isActionable(button) then
		if UserInputService.TouchEnabled and (size.X < MIN_TOUCH_TARGET or size.Y < MIN_TOUCH_TARGET) then
			if diagnostics:record(button, "SmallTouchTarget", `Active control is {math.floor(size.X)}×{math.floor(size.Y)}px; touch controls need at least {MIN_TOUCH_TARGET}×{MIN_TOUCH_TARGET}px`) then
				stats.smallTouchTargets += 1
			end
		end
		recordViewportAction(button, rect)
		local clippedBy = clippingAncestor(button, rect)
		if clippedBy ~= nil and diagnostics:record(button, "ClippedAction", `Action exceeds clipped ancestor {clippedBy:GetFullName()}`) then
			stats.clippedActions += 1
		end
	end
	local parent = button.Parent
	if parent == nil or not parent:IsA("GuiObject") or parent:IsA("ScrollingFrame") or engineOwns(button) then
		return nil
	end
	local pad = parent:FindFirstChildOfClass("UIPadding")
	local parentSize = parent.AbsoluteSize
	local parentPos = parent.AbsolutePosition
	if not isFiniteNumber(parentSize.X) or not isFiniteNumber(parentSize.Y) or not isFiniteNumber(parentPos.X) or not isFiniteNumber(parentPos.Y) then
		return nil
	end
	local left = if pad ~= nil then pad.PaddingLeft.Scale * parentSize.X + pad.PaddingLeft.Offset else 0
	local top = if pad ~= nil then pad.PaddingTop.Scale * parentSize.Y + pad.PaddingTop.Offset else 0
	local right = if pad ~= nil then pad.PaddingRight.Scale * parentSize.X + pad.PaddingRight.Offset else 0
	local bottom = if pad ~= nil then pad.PaddingBottom.Scale * parentSize.Y + pad.PaddingBottom.Offset else 0
	local box = Geom.rect(parentPos.X + left, parentPos.Y + top, parentPos.X + parentSize.X - right, parentPos.Y + parentSize.Y - bottom)
	if Geom.rectWidth(box) < 8 or Geom.rectHeight(box) < 8 then
		return nil
	end
	local parentOverflow = Geom.overflowAmount(rect, box)
	if parentOverflow <= (if math.max(size.X, size.Y) < 64 then WILD_ASPECT_SLOP else FIT_SLOP) then
		tryCount[button] = nil
		return nil
	end
	if isActionable(button) and diagnostics:record(button, "ActionOutsideParent", `Action exceeds its padded parent by {math.ceil(parentOverflow)}px`) then
		stats.actionsOutsideParent += 1
	end
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
	if not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y) or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or size.X < 8 or size.Y < 8 then
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
	diagnostics:record(panel, "ViewportOverflow", `Panel exceeds viewport by {dx}, {dy} pixels`)
	if not Diagnostics.canRecover(panel, "FloatingPanel") then return end
	if not allowWrite(panel) then
		return nil
	end
	panel.Position = UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset + dx, panel.Position.Y.Scale, panel.Position.Y.Offset + dy)
	stats.pulledIntoView += 1
end
local function repairScrollingFrame(descendant)
	if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	if descendant:GetAttribute("LayoutGuardAllowNestedScroll") ~= true then
		local ancestor = descendant.Parent
		while ancestor ~= nil and not ancestor:IsA("LayerCollector") do
			if ancestor:IsA("ScrollingFrame") and ancestor.ScrollingEnabled and ancestor:GetAttribute("LayoutGuardAllowNestedScroll") ~= true then
				local childDirection = descendant.ScrollingDirection
				local parentDirection = ancestor.ScrollingDirection
				local childX = childDirection == Enum.ScrollingDirection.X or childDirection == Enum.ScrollingDirection.XY
				local childY = childDirection ~= Enum.ScrollingDirection.X
				local parentX = parentDirection == Enum.ScrollingDirection.X or parentDirection == Enum.ScrollingDirection.XY
				local parentY = parentDirection ~= Enum.ScrollingDirection.X
				if (childX and parentX) or (childY and parentY) then
					if diagnostics:record(descendant, "NestedScrollConflict", `Shares a scroll axis with {ancestor:GetFullName()}`) then
						stats.nestedScrollConflicts += 1
					end
					break
				end
			end
			ancestor = ancestor.Parent
		end
	end
	local heldScroll = false
	if not descendant.ScrollingEnabled and descendant:GetAttribute("LayoutGuardAllowDisabledScroll") ~= true then
		heldScroll = true
		diagnostics:record(descendant, "DisabledScroll", "Owner disabled scrolling without LayoutGuardAllowDisabledScroll")
	end
	if descendant.AutomaticCanvasSize ~= Enum.AutomaticSize.None then
		return nil
	end
	local maxBottom, maxRight = 0, 0
	local size = descendant.AbsoluteSize
	local pad = descendant:FindFirstChildOfClass("UIPadding")
	local bottomPad = if pad then pad.PaddingBottom.Scale * size.Y + pad.PaddingBottom.Offset else 0
	local rightPad = if pad then pad.PaddingRight.Scale * size.X + pad.PaddingRight.Offset else 0
	for _, child in descendant:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			local layoutContentHeight = child.AbsoluteContentSize.Y
			local layoutContentWidth = child.AbsoluteContentSize.X
			if isFiniteNumber(layoutContentHeight) then maxBottom = math.max(maxBottom, layoutContentHeight) end
			if isFiniteNumber(layoutContentWidth) then maxRight = math.max(maxRight, layoutContentWidth) end
		elseif child:IsA("GuiObject") and child.Visible then
			local bottom = child.AbsolutePosition.Y - descendant.AbsolutePosition.Y + descendant.CanvasPosition.Y + child.AbsoluteSize.Y
			local right = child.AbsolutePosition.X - descendant.AbsolutePosition.X + descendant.CanvasPosition.X + child.AbsoluteSize.X
			if isFiniteNumber(bottom) then maxBottom = math.max(maxBottom, bottom) end
			if isFiniteNumber(right) then maxRight = math.max(maxRight, right) end
		end
	end
	if maxBottom > 0 then maxBottom += bottomPad end
	if maxRight > 0 then maxRight += rightPad end
	local direction = descendant.ScrollingDirection
	local xScroll = direction == Enum.ScrollingDirection.X or direction == Enum.ScrollingDirection.XY
	local yScroll = direction ~= Enum.ScrollingDirection.X
	local canvas = descendant.CanvasSize
	local currentX = math.max(size.X, canvas.X.Scale * size.X + canvas.X.Offset)
	local currentY = math.max(size.Y, canvas.Y.Scale * size.Y + canvas.Y.Offset)
	local shortX = xScroll and currentX + 1 < maxRight
	local shortY = yScroll and currentY + 1 < maxBottom
	if not shortX and not shortY then
		if not heldScroll then
			tryCount[descendant] = nil
		end
		return nil
	end
	diagnostics:record(descendant, "CanvasOverflow", `Canvas {currentX}×{currentY}px is shorter than content {maxRight}×{maxBottom}px`)
	if not Diagnostics.canRecover(descendant, "Canvas") then return end
	if not allowWrite(descendant) then
		return nil
	end
	descendant.CanvasSize = UDim2.new(
		if shortX then 0 else canvas.X.Scale, if shortX then math.ceil(maxRight) else canvas.X.Offset,
		if shortY then 0 else canvas.Y.Scale, if shortY then math.ceil(maxBottom) else canvas.Y.Offset
	)
	stats.canvasDesyncFixed += 1
	ClientLog:warnEvery(`layoutguard:canvas:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} CanvasSize was shorter than its content; scoped recovery applied`)
end
function interactionLayer(instance)
	local current = instance.Parent
	while current ~= nil and not current:IsA("LayerCollector") do
		current = current.Parent
	end
	return current
end
local function isAncestorOf(ancestor, instance)
	local current = instance.Parent
	while current ~= nil do
		if current == ancestor then
			return true
		end
		current = current.Parent
	end
	return false
end
local function checkOverlappingHitboxes(root)
	local cellSize = COLLISION_CELL or 64
	local shieldShare = INPUT_SHIELD_SHARE or 0.8
	local byLayer = {}
	local list = if typeof(root) == "table" then root else root:GetDescendants()
	for _, descendant in list do
		coroutine.yield()
		if descendant.Parent == nil or not descendant:IsA("GuiButton") or not isTrackedClass(descendant) then
			continue
		end
		if not Diagnostics.visible(descendant) or not descendant.Active then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		local layer = interactionLayer(descendant)
		if layer == nil then
			continue
		end
		local rect = rectOf(descendant)
		local area = rectArea(rect)
		local layerArea = rectArea(rectOf(layer))
		if area <= 0 or (layerArea > 0 and area >= layerArea * shieldShare) then
			continue
		end
		local items = byLayer[layer]
		if items == nil then
			items = {}
			byLayer[layer] = items
		end
		items[#items + 1] = { instance = descendant, rect = rect, area = area }
	end
	for _, items in byLayer do
		if #items < 2 then
			continue
		end
		local cells = {}
		for index, item in items do
			coroutine.yield()
			local x0 = math.floor(item.rect.x0 / cellSize)
			local x1 = math.floor((item.rect.x1 - 0.001) / cellSize)
			local y0 = math.floor(item.rect.y0 / cellSize)
			local y1 = math.floor((item.rect.y1 - 0.001) / cellSize)
			for x = x0, x1 do
				for y = y0, y1 do
					local key = `{x}:{y}`
					local bucket = cells[key]
					if bucket == nil then
						bucket = {}
						cells[key] = bucket
					end
					bucket[#bucket + 1] = index
				end
			end
		end
		local compared = {}
		for _, bucket in cells do
			for leftSlot = 1, #bucket do
				for rightSlot = leftSlot + 1, #bucket do
					coroutine.yield()
					local leftIndex = bucket[leftSlot]
					local rightIndex = bucket[rightSlot]
					local pairKey = `{leftIndex}:{rightIndex}`
					if compared[pairKey] then
						continue
					end
					compared[pairKey] = true
					local left = items[leftIndex]
					local right = items[rightIndex]
					local a = left.instance
					local b = right.instance
					if a.Parent == nil or b.Parent == nil or not Diagnostics.visible(a) or not Diagnostics.visible(b) then
						continue
					end
					if isAncestorOf(a, b) or isAncestorOf(b, a) then
						continue
					end
					local overlap = overlapArea(left.rect, right.rect)
					local smaller = math.min(left.area, right.area)
					local threshold = if a.Parent == b.Parent then 0.12 elseif a.ZIndex == b.ZIndex then 0.35 else 0.2
					if smaller <= 0 or overlap < 64 or overlap / smaller < threshold then
						continue
					end
					local culprit = a
					local victim = b
					if (a.ZIndex or 1) < (b.ZIndex or 1) then
						culprit = b
						victim = a
					end
					if diagnostics:record(culprit, "ActionCollision", `Overlaps {victim:GetFullName()} by {math.floor(overlap / smaller * 100 + 0.5)}% at the same input layer`) then
						stats.actionCollisions += 1
					end
				end
			end
		end
	end
end
local function paintsOver(button)
	if button:IsA("TextButton") then
		return (button.BackgroundTransparency or 0) < 0.6 or (button.Text or "") ~= ""
	end
	if button:IsA("ImageButton") then
		return (button.BackgroundTransparency or 0) < 0.6 or ((button.Image or "") ~= "" and (button.ImageTransparency or 0) < 0.6)
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
	diagnostics:record(label, "TextCollision", `Text overlaps {button:GetFullName()}; owner must reserve space`)
	return false
end
local textPassLabels = {}
local textPassButtons = {}
local textPassLayerLabels = {}
local textPassLayerButtons = {}
local function checkTextUnderButtons(list)
	table.clear(textPassLabels)
	table.clear(textPassButtons)
	table.clear(textPassLayerLabels)
	table.clear(textPassLayerButtons)
	for _, inst in list do
		coroutine.yield()
		if inst.Parent == nil or not isTrackedClass(inst) or not Diagnostics.visible(inst) then
			continue
		end
		local layer = interactionLayer(inst)
		if inst:IsA("GuiButton") then
			if inst.Visible and paintsOver(inst) and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
				local bucket = textPassButtons[inst.Parent]
				if bucket == nil then
					bucket = {}
					textPassButtons[inst.Parent] = bucket
				end
				table.insert(bucket, inst)
				if layer ~= nil then
					local layerBucket = textPassLayerButtons[layer]
					if layerBucket == nil then
						layerBucket = {}
						textPassLayerButtons[layer] = layerBucket
					end
					table.insert(layerBucket, inst)
				end
			end
		elseif inst:IsA("TextLabel") and inst.Visible and inst.Text ~= "" then
			local bucket = textPassLabels[inst.Parent]
			if bucket == nil then
				bucket = {}
				textPassLabels[inst.Parent] = bucket
			end
			table.insert(bucket, inst)
			if layer ~= nil then
				local layerBucket = textPassLayerLabels[layer]
				if layerBucket == nil then
					layerBucket = {}
					textPassLayerLabels[layer] = layerBucket
				end
				table.insert(layerBucket, inst)
			end
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
					coroutine.yield()
					local right = labels[j]
					if left.Parent == nil or right.Parent ~= left.Parent or not Diagnostics.visible(left) or not Diagnostics.visible(right) then
						continue
					end
					if right == left or right.AbsoluteSize.X < 8 then
						continue
					end
					local rightText = textRectOf(right)
					if rightText.x0 > leftText.x0 + 4 and Plan.labelsCollide(leftText, rightText) then
						clearTextOfButton(left, right, rightText)
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
				coroutine.yield()
				if label.Parent == nil or button.Parent ~= label.Parent or not Diagnostics.visible(label) or not Diagnostics.visible(button) then
					continue
				end
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
				clearTextOfButton(label, button, buttonRect)
				break
			end
		end
	end
	for _, labels in textPassLayerLabels do
		for _, label in labels do
			local layer = interactionLayer(label)
			local buttons = if layer ~= nil then textPassLayerButtons[layer] else nil
			if buttons == nil then
				continue
			end
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
			for _, button in buttons do
				coroutine.yield()
				if label.Parent == nil or button.Parent == nil or button.Parent == label.Parent or not Diagnostics.visible(label) or not Diagnostics.visible(button) then
					continue
				end
				if isAncestorOf(label, button) or isAncestorOf(button, label) or (button.ZIndex or 1) < (label.ZIndex or 1) then
					continue
				end
				local buttonRect = rectOf(button)
				local hidden = math.max(0, math.min(textRect.x1, buttonRect.x1) - math.max(textRect.x0, buttonRect.x0))
				local shared = math.max(0, math.min(textRect.y1, buttonRect.y1) - math.max(textRect.y0, buttonRect.y0))
				if hidden / textWidth < TEXT_COVER_SHARE or shared / textHeight < TEXT_COVER_HEIGHT then
					continue
				end
				stats.textUnderButtonSeen += 1
				clearTextOfButton(label, button, buttonRect)
				break
			end
		end
	end
	table.clear(textPassLayerLabels)
	table.clear(textPassLayerButtons)
end
local SOLID_MIN_GAP = 4
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
	diagnostics:record(label, "StackCollision", `Text runs into {solid:GetFullName()} by {math.ceil(intrude)}px`)
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
		coroutine.yield()
		local parent = inst.Parent
		if parent == nil or not isTrackedClass(inst) or not Diagnostics.visible(inst) then
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
				coroutine.yield()
				if label.Parent == nil or solid.Parent ~= label.Parent or not Diagnostics.visible(label) or not Diagnostics.visible(solid) then
					continue
				end
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
	local before = diagnostics:observations()
	inspectOnce(inst)
	if inst.Parent ~= nil and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
		learn(inst, diagnostics:observations() > before)
	end
end
function inspectOnce(inst)
	if inst.Parent == nil or not isTrackedClass(inst) then
		return nil
	end
	if not Diagnostics.visible(inst) then return end
	local size = inst.AbsoluteSize
	local pos = inst.AbsolutePosition
	local broken = not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y)
	if broken and inst:IsA("GuiObject") and inst.Visible and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
		diagnostics:record(inst, "InvalidGeometry", "Non-finite geometry; owner must reject invalid layout values")
		return nil
	end
	if inst:IsA("ScrollingFrame") then
		repairScrollingFrame(inst)
	elseif isFloatingPanel(inst) then
		repairFloatingPanel(inst)
	elseif inst:IsA("CanvasGroup") then
		return nil
	elseif inst:IsA("GuiButton") then
		repairButton(inst)
	elseif inst:IsA("TextLabel") or inst:IsA("TextBox") then
		repairText(inst)
	end
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
		self.geometryConnections = setmetatable({}, { __mode = "k" })
		self.geometryReadyAt = setmetatable({}, { __mode = "k" })
		self.geometryUsers = setmetatable({}, { __mode = "k" })
		self.trackedAncestors = setmetatable({}, { __mode = "k" })
		self.layerConnections = {}
		self.watchedLayers = {}
		self.pendingOverlap = false
		self.hotCursor = 1
		self.deadline = math.huge
		self.overlapPhase = 1
		self.collisionWork = nil
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
	function LayoutGuardController:queueGeometryDirty(instance)
		local now = os.clock()
		if now < (self.geometryReadyAt[instance] or 0) then
			return
		end
		self.geometryReadyAt[instance] = now + 0.2
		stats.geometryChanges += 1
		self:markDirty(instance)
		local parent = instance.Parent
		if parent ~= nil and self.trackedIndex[parent] ~= nil then
			self:enqueue(parent, Plan.SETTLE_FRAMES)
		end
		local queued = 0
		if instance:IsA("GuiObject") then
			for _, descendant in instance:GetDescendants() do
				if self.trackedIndex[descendant] ~= nil and not self.freshSet[descendant] then
					self:enqueue(descendant, Plan.SETTLE_FRAMES)
					queued += 1
					if queued >= DIRTY_DESCENDANT_CAP then
						break
					end
				end
			end
		end
		stats.dirtyDescendants += queued
		if queued >= DIRTY_DESCENDANT_CAP then
			self.sinceSweep = math.max(self.sinceSweep, Plan.MIN_SWEEP_SECONDS)
		end
		self.pendingOverlap = true
	end
	function LayoutGuardController:watchGeometry(instance)
		if not instance:IsA("GuiObject") then
			return
		end
		local users = (self.geometryUsers[instance] or 0) + 1
		self.geometryUsers[instance] = users
		if self.geometryConnections[instance] ~= nil then
			return
		end
		local properties = { "Position", "Size", "Visible", "ClipsDescendants" }
		if instance:IsA("GuiButton") then
			table.insert(properties, "Active")
			table.insert(properties, "Rotation")
			table.insert(properties, "ZIndex")
		elseif instance:IsA("TextLabel") or instance:IsA("TextBox") then
			table.insert(properties, "Text")
			table.insert(properties, "TextFits")
			table.insert(properties, "TextWrapped")
			table.insert(properties, "TextScaled")
			table.insert(properties, "TextSize")
			if instance:IsA("TextBox") then
				table.insert(properties, "TextEditable")
			end
		elseif instance:IsA("ScrollingFrame") then
			table.insert(properties, "AutomaticCanvasSize")
			table.insert(properties, "CanvasPosition")
			table.insert(properties, "CanvasSize")
			table.insert(properties, "ScrollingDirection")
			table.insert(properties, "ScrollingEnabled")
		end
		local connections = {}
		for _, property in properties do
			local ok, signal = pcall(function()
				return instance:GetPropertyChangedSignal(property)
			end)
			if ok and signal ~= nil then
				connections[#connections + 1] = signal:Connect(function()
					self:queueGeometryDirty(instance)
				end)
			end
		end
		self.geometryConnections[instance] = connections
	end
	function LayoutGuardController:unwatchGeometry(instance)
		local users = self.geometryUsers[instance]
		if users == nil then
			return
		end
		if users > 1 then
			self.geometryUsers[instance] = users - 1
			return
		end
		self.geometryUsers[instance] = nil
		local connections = self.geometryConnections[instance]
		if connections ~= nil then
			for _, connection in connections do
				connection:Disconnect()
			end
			self.geometryConnections[instance] = nil
		end
		self.geometryReadyAt[instance] = nil
	end
	function LayoutGuardController:track(instance)
		if self.trackedIndex[instance] ~= nil or not isTrackedClass(instance) then
			return nil
		end
		local tracked = self.tracked
		local index = #tracked + 1
		tracked[index] = instance
		self.trackedIndex[instance] = index
		local ancestors = {}
		local ancestor = instance.Parent
		while ancestor ~= nil and not ancestor:IsA("LayerCollector") do
			if ancestor:IsA("GuiObject") then
				ancestors[#ancestors + 1] = ancestor
				self:watchGeometry(ancestor)
			end
			ancestor = ancestor.Parent
		end
		self.trackedAncestors[instance] = ancestors
		self:watchGeometry(instance)
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
		self:unwatchGeometry(instance)
		local ancestors = self.trackedAncestors[instance]
		if ancestors ~= nil then
			for _, ancestor in ancestors do
				self:unwatchGeometry(ancestor)
			end
			self.trackedAncestors[instance] = nil
		end
	end
	function LayoutGuardController:releaseSubtree(instance)
		self:untrack(instance)
		local ok, descendants = pcall(function()
			return instance:GetDescendants()
		end)
		if not ok or descendants == nil then
			return
		end
		for _, descendant in descendants do
			self:untrack(descendant)
		end
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
		local connections = {}
		self.layerConnections[layer] = connections
		table.insert(connections, layer.DescendantAdded:Connect(function(instance)
			self:track(instance)
			self:markDirty(instance)
		end))
		table.insert(connections, layer.DescendantRemoving:Connect(function(instance)
			self:releaseSubtree(instance)
			tryCount[instance] = nil
			abandoned[instance] = nil
		end))
	end
	function LayoutGuardController:unwatchLayer(layer)
		local connections = self.layerConnections[layer]
		if connections ~= nil then
			for _, connection in connections do
				connection:Disconnect()
			end
			self.layerConnections[layer] = nil
		end
		if not self.watchedLayers[layer] then
			return
		end
		self.watchedLayers[layer] = nil
		self:releaseSubtree(layer)
	end
	function LayoutGuardController:bindRoot(root)
		if self.diagnosticEndpoint then
			self.diagnosticEndpoint:Destroy()
			self.diagnosticEndpoint = nil
		end
		if self.layerConnections ~= nil then
			for layer in self.layerConnections do
				self:unwatchLayer(layer)
			end
		end
		for _, connection in self.rootConnections do
			connection:Disconnect()
		end
		for instance, connections in self.geometryConnections do
			for _, connection in connections do
				connection:Disconnect()
			end
			self.geometryConnections[instance] = nil
		end
		table.clear(self.rootConnections)
		table.clear(self.tracked)
		table.clear(self.trackedIndex)
		table.clear(self.fresh)
		table.clear(self.freshReady)
		table.clear(self.freshSet)
		table.clear(self.freshScratch)
		table.clear(self.freshReadyScratch)
		if self.geometryUsers ~= nil then table.clear(self.geometryUsers) end
		if self.trackedAncestors ~= nil then table.clear(self.trackedAncestors) end
		if self.geometryReadyAt ~= nil then table.clear(self.geometryReadyAt) end
		self.collisionWork = nil
		self.layerConnections = {}
		self.watchedLayers = {}
		if root == nil then
			return nil
		end
		self:watchLayer(root)
		local playerGui = root:FindFirstAncestorOfClass("PlayerGui")
		local endpoint = Instance.new("BindableFunction")
		endpoint.Name = "AstralForgeLayoutDiagnostics"
		endpoint.OnInvoke = function()
			return {
				Diagnostics = diagnostics:snapshot(),
				Stats = table.clone(stats),
				Tracked = #self.tracked,
				Fresh = #self.fresh,
				Cursor = self.cursor,
				PendingOverlap = self.pendingOverlap,
				OverlapPhase = self.overlapPhase,
			}
		end
		-- React owns root descendants and removes children created before mounting.
		endpoint.Parent = playerGui or root
		self.diagnosticEndpoint = endpoint
		table.insert(self.rootConnections, root.Destroying:Connect(function()
			endpoint:Destroy()
		end))
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
				self:unwatchLayer(layer)
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
			diagnostics:reset()
			table.clear(tryCount)
			table.clear(abandoned)
			-- A fight at the old size must not suppress repairs in the new layout.
			for _, entry in model do
				entry.thrash = 0
			end
		end
		self.cursor = 1
		self.sinceSweep = Plan.MIN_SWEEP_SECONDS
		self.pendingOverlap = false
		self.overlapPhase = 1
		self.collisionWork = nil
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
		self.deadline = os.clock() + (if IS_STUDIO then FRAME_BUDGET_SECONDS else LIVE_BUDGET_SECONDS)
		diagnostics:beginPairs(self.deadline)
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
				if self.collisionWork == nil then
					self.collisionWork = coroutine.create(function()
						if self.overlapPhase == 1 then
							checkOverlappingHitboxes(self.queue)
						elseif self.overlapPhase == 2 then
							checkTextUnderButtons(self.queue)
						else
							checkStackedText(self.queue)
							table.clear(textPassLabels)
							table.clear(textPassButtons)
						end
					end)
				end
				if diagnostics:runWork(self.collisionWork) then
					self.collisionWork = nil
					if self.overlapPhase == 3 then self.pendingOverlap = false end
					self.overlapPhase = self.overlapPhase % 3 + 1
				end
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
		local total = diagnostics:total()
		if total == self.reportedTotal then
			return nil
		end
		local delta = total - self.reportedTotal
		self.reportedTotal = total
		ClientLog:info("LayoutGuard", `{delta} layout diagnostic{if delta == 1 then "" else "s"} in the last {REPORT_EVERY}s; component owners retain geometry`, {
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
			smallTouch = stats.smallTouchTargets,
			outsideViewport = stats.actionsOutsideViewport,
			outsideParent = stats.actionsOutsideParent,
			actionCollisions = stats.actionCollisions,
			clippedActions = stats.clippedActions,
			geometryChanges = stats.geometryChanges,
			dirtyDescendants = stats.dirtyDescendants,
			nestedScroll = stats.nestedScrollConflicts,
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
	layoutGuardDiagnostics = function() return diagnostics:snapshot() end,
	LayoutGuardController = LayoutGuardController,
}
