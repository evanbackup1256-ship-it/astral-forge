local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local source = fs.readFile("src/Client/AstralForge/SkyViewport.luau")
local start = assert(source:find("local function piece(", 1, true))
local body = source:sub(start)

local function runScene(props, size)
	local frameCallback, cleanup
	local disconnected, destroyed, pivots = 0, 0, 0
	local parts = {}
	local viewport = { AbsoluteSize = size }
	function viewport:GetPropertyChangedSignal()
		return { Connect = function(_, callback)
			return { Disconnect = function() disconnected += 1 end }
		end }
	end
	local react = {
		useRef = function() return { current = viewport } end,
		useEffect = function(callback) cleanup = callback() end,
	}
	local instance = { new = function(class)
		local object = { ClassName = class, CFrame = roblox.CFrame.identity }
		function object:Destroy() destroyed += 1 end
		function object:PivotTo(_) pivots += 1 end
		if class == "Part" then table.insert(parts, object) end
		return object
	end }
	local runService = { RenderStepped = { Connect = function(_, callback)
		frameCallback = callback
		return { Disconnect = function() disconnected += 1 end }
	end } }
	local palette = {}
	for _, name in { "muted", "lineSoft", "creamSoft", "graphite", "ink" } do
		palette[name] = roblox.Color3.fromRGB(90, 80, 100)
	end
	local component = luau.load(body, {
		environment = {
			React = react, Instance = instance, RunService = runService, P = palette,
			h = function(kind, properties, children) return { kind = kind, props = properties, children = children } end,
			Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
			CFrame = roblox.CFrame, UDim = roblox.UDim, UDim2 = roblox.UDim2, Enum = roblox.Enum,
			Random = { new = function() return { NextNumber = function(_, low, high) return (low + high) / 2 end } end },
		},
	})()
	local rendered = component(props)
	local initialPivots = pivots
	assert(rendered.kind == "viewportframe" and viewport.CurrentCamera, "scenes own an actual viewport camera")
	assert(viewport.CurrentCamera.CFrame.Position.Z > 0, "aspect-aware camera remains in front of the scene")
	for _, part in parts do
		assert(part.Anchored and not part.CanCollide and not part.CastShadow, "preview models remain inert")
		if props.entry and part.Name == "Star" .. (props.plotted + 1) then
			assert(part.Material == roblox.Enum.Material.Neon and part.Color == props.accent, "the next star stays visibly highlighted even in reduced motion")
		end
	end
	if props.reducedMotion then
		assert(not frameCallback, "reduced motion must not subscribe to animation")
	else
		assert(frameCallback, "animated scenes subscribe exactly once")
		frameCallback(1 / 60)
		if props.entry then
			assert(pivots - initialPivots == 1, "chart motion updates the shared scene, not individual GUI positions")
		else
			assert(pivots - initialPivots == 4, "each receiver signal physically animates as one model")
		end
	end
	cleanup()
	assert(viewport.CurrentCamera == nil and destroyed == 2, "unmount releases camera and WorldModel")
	assert(disconnected == (if props.reducedMotion then 1 else 2), "all animation and resize subscriptions disconnect")
	return #parts
end
local accent = roblox.Color3.fromRGB(100, 200, 240)
local entry = { Id = "probe", Stars = { { 0.15, 0.2 }, { 0.5, 0.7 }, { 0.85, 0.25 } }, Edges = { { 1, 2 }, { 2, 3 } } }
for _, size in { roblox.Vector2.new(300, 300), roblox.Vector2.new(337, 128), roblox.Vector2.new(128, 337) } do
	for _, reduced in { false, true } do
		assert(runScene({ entry = entry, plotted = 1, accent = accent, reducedMotion = reduced }, size) == 37, "charts retain stars, links and a bounded backdrop")
		assert(runScene({ glyphs = { 1, 2, 3, 4 }, colors = { accent, accent, accent, accent }, accent = accent, reducedMotion = reduced }, size) == 44, "cipher previews retain all four authored glyphs")
		assert(runScene({ glyphs = { 4, 4, 4, 4 }, colors = { accent, accent, accent, accent }, accent = accent, reducedMotion = reduced }, size) <= 64, "receiver previews remain within their part budget")
	end
end

local core = fs.readFile("src/Client/AstralForge/UiCore.luau")
local a = assert(core:find("local function AmbientLayer(", 1, true))
local b = assert(core:find("local function ConfettiBurst(", a, true))
local ambient = core:sub(a, b - 1)
local antialag = { allowAmbient = true, constrained = false, glowScale = 1 }
local phase = 0
local clockEnabled
local binding = { map = function(_, callback) return callback(phase) end }
local component = luau.load(ambient .. "\nreturn AmbientLayer", {
	environment = {
		useAntilag = function() return antialag end,
		useClock = function(enabled) clockEnabled = enabled; return binding end,
		React = { createElement = function(kind, props, children) return { kind = kind, props = props, children = children } end },
		Palette = { mint = accent, cyan = accent, violet = accent, white = roblox.Color3.new(1, 1, 1) },
		UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
		ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	},
})()
assert(#component({ intensity = 1 }).children == 14, "the enabled aurora actually mounts its curtains")
assert(clockEnabled, "normal ambient decoration animates")
assert(#component({ intensity = 1, reducedMotion = true }).children == 14, "reduced motion retains a still aurora")
assert(not clockEnabled, "reduced motion stops the aurora clock")
local first = component({ intensity = 1 }).children
phase = 2 * math.pi
local wrapped = component({ intensity = 1 }).children
for index, curtain in first do
	local other = wrapped[index].props
	for _, property in { "Size", "Position" } do
		local original = curtain.props[property]
		local resumed = other[property]
		assert(math.abs(original.X.Scale - resumed.X.Scale) < 1e-8 and math.abs(original.Y.Scale - resumed.Y.Scale) < 1e-8, "aurora geometry must not jump at clock wrap")
	end
	assert(math.abs(curtain.props.Rotation - other.Rotation) < 1e-8, "aurora rotation must wrap continuously")
end
phase = 0
antialag.constrained = true
assert(#component({ intensity = 1 }).children == 8, "constrained devices use fewer curtains")
antialag.allowAmbient = false
assert(component({ intensity = 1 }).children == nil, "disabled ambient decoration creates no curtains")
assert(not clockEnabled, "disabled ambient decoration stops its clock")
assert(core:find('Name = "BoltSprite"', 1, true) and core:find('Image = "rbxassetid://70681368255210"', 1, true), "Bolt uses the uploaded authored atlas")
assert(core:find('Name = "TopbarResourceRail"', 1, true) and core:find("local chips = allChips", 1, true), "topbar resources must not be pruned")
local mobileStart = assert(core:find("local function MobileHeader(", 1, true))
local mobileEnd = assert(core:find("local function MobileQuickActions(", mobileStart, true))
local mobileWidth, rail, renderedChips = 401, nil, {}
local mobilePalette = {}
for _, name in { "cyan", "mango", "violet", "panel", "panelSoft", "line", "cream" } do
	mobilePalette[name] = accent
end
local unlocked = true
local mobileHeader = luau.load(core:sub(mobileStart, mobileEnd - 1) .. "\nreturn MobileHeader", {
	environment = {
		useViewport = function() return { width = mobileWidth } end,
		AppHelpers = {
			pageEntry = function() return { icon = "Overview", label = "Overview" } end,
			featureUnlocked = function() return unlocked end,
		},
		React = { createElement = function(kind, properties, ...)
			if kind == "Chip" then table.insert(renderedChips, properties) end
			if properties and properties.Name == "MobileResourceRail" then rail = properties end
			return { kind = kind, props = properties, children = { ... } }
		end },
		__load = function() return { readLevelState = function() return 4, nil, {} end, progressFraction = function() return 0.5 end } end,
		Chip = "Chip", Icon = "Icon", IconTile = "IconTile", Palette = mobilePalette,
		darken = function(color) return color end,
		UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Enum = roblox.Enum,
		Font = { new = function() return {} end },
	},
})()
for _, width in { 280, 320, 375, 401, 480, 720, 1280 } do
	mobileWidth = width
	for _, height in { 36, 48 } do
		renderedChips, rail = {}, nil
		mobileHeader({ state = { Cash = 10, Stardust = 20, Cores = 30 }, page = "Overview", accent = accent, topPad = 0, barHeight = height, edgePad = 8 })
		assert(#renderedChips == 3, "phone headers retain every unlocked currency regardless of width")
		assert(renderedChips[1].value == 10 and renderedChips[2].value == 20 and renderedChips[3].value == 30, "mobile resource order and values are preserved")
		assert(rail.ScrollingDirection == roblox.Enum.ScrollingDirection.X and rail.AutomaticCanvasSize == roblox.Enum.AutomaticSize.X, "phone resources remain horizontally accessible")
		assert(rail.Size.X.Offset >= 48 and rail.Size.X.Offset < width - 120, "resource rail retains title and player-button room")
		assert(rail.Size.Y.Offset <= height, "resource rail fits both header heights")
	end
end
unlocked = false
renderedChips = {}
mobileHeader({ state = { Cash = 10 }, page = "Overview", accent = accent, topPad = 0, barHeight = 48, edgePad = 8 })
assert(#renderedChips == 1, "locked currencies are still hidden")
local reportStart = assert(core:find("local function ReportSheet(", 1, true))
local reportEnd = assert(core:find("local function PlayerlistOverlay(", reportStart, true))
local memberfs = require("./_memberfs")(fs)
local model = luau.load(memberfs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#PlayerlistModel"))()
local states, initialized, buttons, labels = {}, {}, {}, {}
local ordinal, blocked, calls = 0, 0, {}
local reportedAt = {}
local function bindingFor(value)
	return { value = value, map = function(_, callback) return callback(value) end }
end
local fakeReact = {
	Fragment = "Fragment",
	useRef = function(value) return { current = value } end,
	useEffect = function() end,
	useState = function(value)
		ordinal += 1
		local index = ordinal
		if not initialized[index] then states[index] = value; initialized[index] = true end
		return states[index], function(nextValue) states[index] = nextValue end
	end,
	joinBindings = function(values)
		local valuesNow = {}
		for index, value in values do valuesNow[index] = value.value end
		return bindingFor(valuesNow)
	end,
	createElement = function(kind, properties, ...)
		if kind == "Button" then table.insert(buttons, properties) end
		if kind == "Text" then table.insert(labels, properties.value) end
		return { kind = kind, props = properties, children = { ... } }
	end,
}
local report = luau.load(core:sub(reportStart, reportEnd - 1) .. "\nreturn ReportSheet", {
	environment = {
		React = fakeReact, Model = model, Button = "Button", Text = "Text", Icon = "Icon",
		useGuiSize = function() return bindingFor(roblox.Vector2.new(380, 530)) end,
		useFlipperSpring = function() return bindingFor(1) end,
		pixelPosition = function() return roblox.UDim2.fromOffset(0, 0) end,
		darken = function(color) return color end,
		Palette = setmetatable({}, { __index = function() return accent end }),
		Audio = { play = function() end }, reportedAt = reportedAt,
		UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Enum = roblox.Enum,
		Font = { fromEnum = function(value) return value end },
	},
})()
local reply = { ok = false, error = "Retry this diagnostic report." }
local params = {
	target = { UserId = 123, DisplayName = "Probe" }, width = 380, maxHeight = 530,
	reducedMotion = true, onClose = function() end,
	onBlock = function() blocked += 1 end,
	dispatch = function(action, data, callback)
		table.insert(calls, { action = action, data = data })
		callback(reply)
	end,
}
local function renderReport()
	ordinal = 0; buttons = {}; labels = {}
	return report(params)
end
local function findButton(text)
	for _, button in buttons do if button.text == text then return button end end
	error("Missing button: " .. text)
end
local tree = renderReport()
assert(findButton("PICK A REASON").disabled, "report submission waits for a reason")
assert(tree.children[1].props.Size.Y.Offset == 530, "long report forms cap their visible height")
buttons[1].onClick()
buttons[#model.REASONS + 3].onClick()
findButton("Also block Probe: OFF").onClick()
renderReport()
assert(not findButton("SEND REPORT").disabled, "reason selection enables report submission")
findButton("SEND REPORT").onClick()
assert(#calls == 1 and calls[1].action == "ReportPlayer", "shared report controls preserve the server action")
assert(calls[1].data.UserId == 123 and calls[1].data.Reason == model.REASONS[1].id and calls[1].data.Severity == "Urgent", "report target, reason and selected severity survive restyling")
assert(blocked == 0 and reportedAt[123] == nil, "failed reports neither block nor record success")
renderReport()
assert(table.find(labels, reply.error), "report failures remain visible and retryable")
reply = { ok = true }
findButton("SEND REPORT").onClick()
renderReport()
assert(findButton("DONE") and blocked == 1 and reportedAt[123] ~= nil, "blocking happens only after a successful report")
print("[INFO] [TEST] presentation passed | viewport lifecycle, reduced motion, aurora, Bolt, report retry/payload")
