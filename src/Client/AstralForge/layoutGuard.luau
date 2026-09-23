local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
local Reflect = core.Reflect
local Controller = core.Controller
local ClientLog = require(script.Parent.log).ClientLog
-- Type-only: erased at compile time, so this does NOT become a runtime require("./framework")
-- and cannot participate in the circular require that framework/index.ts's "side effect"
-- import of this file would otherwise create (framework/index.ts -> layoutGuard.ts -> back to
-- framework/index.ts). Keep this a `import type` — switching it to a value import would
-- reintroduce that cycle.
-- A generic runtime layout-repair pass: watches a designated GUI root for the specific
-- failure shapes that actually happen in this app (a ScrollingFrame's CanvasSize falling out
-- of sync with its real content so the player can't scroll to the bottom; a stray
-- GuiObject rendered with degenerate/off-screen geometry after a bad state transition;
-- two interactive controls stacked so the top one silently eats the bottom one's input) and
-- applies the narrow, safe correction for each one. It does not attempt general "does this
-- look right" layout reasoning — that would be far too prone to false-positiving on
-- deliberately overlapping decorative frames (glows, gradients, accent bars) that this UI
-- uses constantly. An element opts out of the overlap check entirely by setting the
-- "LayoutGuardIgnore" attribute to true, which is the same escape hatch decorative composed
-- stacks (IconTile glow layers, Panel accent bars, etc.) already need.
local SCAN_INTERVAL_SECONDS = 0.75
local IGNORE_ATTRIBUTE = "LayoutGuardIgnore"
local MAX_NODES_PER_SCAN = 4000
local stats = {
	scans = 0,
	canvasDesyncFixed = 0,
	scrollingReenabled = 0,
	degenerateHidden = 0,
	overlapDemoted = 0,
}
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
-- Roblox already ignores hits on a GuiObject with Visible=false or Active=false, and
-- InputBegan doesn't fire on descendants covered by a higher-ZIndex sibling that also has
-- Active=true — that native occlusion is exactly what we're checking hasn't gone wrong here.
-- This only flags a *same-parent* pair since ZIndex comparisons across different parents
-- aren't meaningful, and only pairs at the same ZIndex (a deliberately layered higher-ZIndex
-- control on top of a lower one, like a close button over a card, is the normal, correct
-- pattern this app uses everywhere and must not be touched).
local function checkOverlappingHitboxes(root)
	local byParent = {}
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("GuiButton") then
			continue
		end
		if not descendant.Visible or not descendant.Active then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		local parent = descendant.Parent
		if parent == nil then
			continue
		end
		local list = byParent[parent]
		if list then
			table.insert(list, descendant)
		else
			local _arg1 = { descendant }
			byParent[parent] = _arg1
		end
	end
	for _, siblings in byParent do
		if #siblings < 2 then
			continue
		end
		for i = 0, #siblings - 1 do
			local a = siblings[i + 1]
			if a:GetAttribute(IGNORE_ATTRIBUTE) == true then
				continue
			end
			local rectA = rectOf(a)
			local areaA = rectArea(rectA)
			if areaA <= 0 then
				continue
			end
			do
				local j = i + 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						j += 1
					else
						_shouldIncrement = true
					end
					if not (j < #siblings) then
						break
					end
					local b = siblings[j + 1]
					if b:GetAttribute(IGNORE_ATTRIBUTE) == true then
						continue
					end
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
					b.ZIndex = a.ZIndex + 1
					stats.overlapDemoted += 1
					ClientLog:warnEvery(`layoutguard:overlap:{a:GetFullName()}`, 30, "LayoutGuard", `{a.Name} and {b.Name} share ZIndex {a.ZIndex} and overlap {string.format("%.0f", (overlap / smaller) * 100)}% — separated so input reaches the top one`)
				end
			end
		end
	end
end
-- AutomaticCanvasSize covers most cases, but any ScrollingFrame that computes CanvasSize
-- manually (this app has several, sized off a hand-rolled row/virtualization total) can drift
-- from its real content if a size calculation elsewhere is wrong — the failure mode is
-- "content extends past the bottom of the canvas and the player can never scroll to see it."
-- Detect that specific direction only (canvas too small) and grow it to fit; never shrinks a
-- canvas, since a canvas intentionally taller than content (for bottom padding/safe-area) is
-- normal and not a bug.
local function checkScrollingFrames(root)
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("ScrollingFrame") then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		if not descendant.ScrollingEnabled and descendant:GetAttribute("LayoutGuardAllowDisabledScroll") ~= true then
			descendant.ScrollingEnabled = true
			stats.scrollingReenabled += 1
			ClientLog:warnEvery(`layoutguard:scrolldisabled:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} had ScrollingEnabled=false with no opt-out attribute — re-enabled`)
		end
		if descendant.AutomaticCanvasSize ~= Enum.AutomaticSize.None then
			continue
		end
		local maxBottom = 0
		-- Prefer Roblox's own authoritative measurement when a UIListLayout/UIGridLayout is
		-- driving this frame's children — it already accounts for padding, fill direction, and
		-- wrapping correctly, which the manual per-child scan below can't fully replicate.
		local layoutContentHeight
		for _1, child in descendant:GetChildren() do
			if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
				layoutContentHeight = child.AbsoluteContentSize.Y
				break
			end
		end
		if layoutContentHeight ~= nil then
			if isFiniteNumber(layoutContentHeight) then
				maxBottom = layoutContentHeight
			end
		else
			for _1, child in descendant:GetChildren() do
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
			continue
		end
		local currentCanvas = descendant.CanvasSize.Y.Offset
		-- Layouts here already build in their own bottom safe-area padding, so only correct a
		-- canvas that's actually short of content — a modest margin (24px) avoids fighting
		-- sub-pixel layout math with a fix-loop on every scan.
		if currentCanvas + 24 < maxBottom then
			descendant.CanvasSize = UDim2.new(descendant.CanvasSize.X, UDim.new(0, math.ceil(maxBottom)))
			stats.canvasDesyncFixed += 1
			ClientLog:warnEvery(`layoutguard:canvas:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} CanvasSize ({currentCanvas}px) was shorter than its content ({string.format("%.0f", maxBottom)}px) — resynced`)
		end
	end
end
-- A GuiObject can end up with NaN/inf geometry after a bad computed Position/Size (e.g. a
-- division by a transient zero during a viewport resize race) — Roblox renders that as
-- either invisible or wildly off-screen depending on platform, so it fails silently instead
-- of erroring. Hiding it is strictly safer than trying to guess a corrected position: a
-- hidden broken element is a visual gap; a guessed-wrong position is fully overlapping the
-- wrong content, which is worse to run into live.
local function checkDegenerateGeometry(root)
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("GuiObject") then
			continue
		end
		if not descendant.Visible then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		local size = descendant.AbsoluteSize
		local pos = descendant.AbsolutePosition
		local broken = not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y)
		if not broken then
			continue
		end
		descendant.Visible = false
		stats.degenerateHidden += 1
		ClientLog:warnEvery(`layoutguard:degenerate:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} rendered with non-finite geometry — hidden to avoid a broken/mispositioned element on screen`)
	end
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
	function LayoutGuardController:constructor(components)
		self.components = components
		self.elapsed = 0
		self.scanning = false
	end
	function LayoutGuardController:onStart()
		self.components:onComponentAdded(function(component)
			self.target = component
			return self.target
		end, "client/framework/init@UiRootComponent")
		local _binding = self.components:getAllComponents("client/framework/init@UiRootComponent")
		local existing = _binding[1]
		if existing ~= nil then
			self.target = existing
		end
	end
	function LayoutGuardController:onTick(_dt)
		local _root = self.target
		if _root ~= nil then
			_root = _root.instance
		end
		local root = _root
		if root == nil then
			return nil
		end
		self.elapsed += _dt
		if self.elapsed < SCAN_INTERVAL_SECONDS then
			return nil
		end
		self.elapsed = 0
		if self.scanning then
			return nil
		end
		self.scanning = true
		task.defer(function()
			checkScrollingFrames(root)
			checkDegenerateGeometry(root)
			checkOverlappingHitboxes(root)
			self.scanning = false
		end)
	end
	do
		-- (Flamework) LayoutGuardController metadata
		Reflect.defineMetadata(LayoutGuardController, "identifier", "client/layoutGuard@LayoutGuardController")
		Reflect.defineMetadata(LayoutGuardController, "flamework:parameters", { "$c:components@Components" })
		Reflect.defineMetadata(LayoutGuardController, "flamework:implements", { "$:flamework@OnStart", "$:flamework@OnTick" })
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
