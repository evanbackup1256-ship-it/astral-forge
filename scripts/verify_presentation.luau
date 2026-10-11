local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local accent = roblox.Color3.fromRGB(100, 200, 240)
local wheelSource = fs.readFile("src/Client/AstralForge/AuthoredWheel.luau")
local shop = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau")
local consoleStart = assert(shop:find("local function WheelConsole(", 1, true))
local consoleEnd = assert(shop:find("local function WheelView(", consoleStart, true))
assert(not shop:sub(consoleStart, consoleEnd - 1):find("WheelPrizeViewport", 1, true), "the active reward console must not mount viewports")
local palette = {}
for _, name in { "ink", "cream", "creamSoft", "void", "panelRaised" } do palette[name] = accent end
local function element(kind, props, ...)
	assert(kind ~= "viewportframe", "the wheel must not create viewports")
	return { kind = kind, props = props, children = { ... } }
end
local wheelStart = assert(wheelSource:find("return function(props)", 1, true))
local artSource = fs.readFile("src/Client/AstralForge/ArtKit.luau")
local iconStart = assert(artSource:find("local function rewardIconKind(", 1, true))
local iconEnd = assert(artSource:find("local function prizeShapeFromReward(", iconStart, true))
local rewardIconKind = luau.load(artSource:sub(iconStart, iconEnd - 1) .. "\nreturn rewardIconKind")()
for field, expected in { Cores = "Core", Stardust = "Dust", Boost = "Boost", FreeSpins = "Wheel",
	Keys = "Crate", CashMinutes = "Flux", Signals = "Command", Essence = "EchoForge" } do
	assert(rewardIconKind({ [field] = 1 }) == expected, "reward art must describe the actual grant")
end
local wheel = luau.load(wheelSource:sub(wheelStart), {
	environment = {
		h = element, Ui = { Text = "Text" }, Palette = palette, FACE = "rbxassetid://74107873507267",
		Art = { Icon = "Icon", rewardIconKind = rewardIconKind },
		Color3 = roblox.Color3, UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
		Enum = roblox.Enum, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
	},
})()
local rewards = {}
for index = 1, 20 do rewards[index] = { Id = "prize" .. index, Reward = { CashMinutes = index } } end
local function wheelBinding(value)
	return { value = value, map = function(_, callback) return callback(value) end }
end
for _, diameter in { 140, 220, 340, 410 } do
	for _, reduced in { false, true } do
		for winner = 0, 19 do
			local rotation = (360 - winner * 18) % 360
			local controller = { winner = winner, rotation = wheelBinding(rotation), spinEnergy = wheelBinding(1), pointerKick = wheelBinding(0.5) }
			local rendered = wheel({ controller = controller, rewards = rewards, diameter = diameter, reducedMotion = reduced })
			local rotor = rendered.children[2]
			assert(rotor.props.Rotation == controller.rotation, "the existing controller owns rotor motion")
			assert(rotor.children[1].props.Image == "rbxassetid://74107873507267", "the authored wheel face is mounted")
			local details = rotor.children[2].children[1]
			for index = 1, 20 do
				local prize = details["prize-prize" .. index]
				local badge = prize.children[1]
				assert((rotation + prize.props.Rotation + badge.props.Rotation) % 360 == 0, "prize labels remain upright")
				if index - 1 == winner then
					assert((rotation + prize.props.Rotation) % 360 == 0, "every server winner aligns exactly with the top pointer")
				end
				if diameter >= 220 then
					local glyph = prize.children[3]
					assert(glyph.props.Name == "RewardGlyph" and (rotation + prize.props.Rotation + glyph.props.Rotation) % 360 == 0,
						"authored reward glyphs remain upright and do not change prize alignment")
					assert(glyph.children[1].props.reducedMotion, "reward glyphs never run competing animation clocks")
				end
			end
			local clicker = rendered.children[5]
			assert(clicker.props.Rotation == (if reduced then 0 else -9), "reduced motion suppresses detail motion")
		end
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
print("[INFO] [TEST] presentation passed | 2D wheel landing/labels/reduced motion, aurora, Bolt, report retry/payload")
