--!nonstrict
-- Game feel. Numbers pop where you tapped, coins fly into the counter they belong to and the counter
-- bounces when they land, sparkle bursts mark big moments, short status lines float up mid-screen,
-- and the screen flashes for the biggest hits. Everything is drawn by one host in its own ScreenGui
-- (same insets as the main UI, so AbsolutePosition and tap positions share one space) from one clock.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local theme = require(script.Parent.CoreKit)("theme")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local P = theme.Palette
local h = React.createElement

local Juice = {}

local CAPS = { number = 22, coin = 40, burst = 5, flash = 2, ring = 8, press = 6, spark = 16 }
local LIFE = { number = 1.15, burst = 0.8, flash = 0.4, ring = 0.55, press = 0.42, spark = 0.45 }
local COIN_SCATTER = 0.22
local COIN_FLIGHT = 0.55
local COIN_STAGGER = 0.035

local effects = {}
local hostSetter = nil
local clockSetter = nil
local nextId = 0
local targets = {}
local arrivalListeners = {}
local lastPointer = nil
local lastPointerAt = -math.huge
local reduced = false
local Feedback = require(script.Parent.MotionKit)("feedback")
local pressedButton = nil
local pressedAt = -math.huge

UserInputService.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		lastPointer = Vector2.new(input.Position.X, input.Position.Y)
		lastPointerAt = os.clock()
		local at = lastPointer
		task.defer(function()
			local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if playerGui == nil or reduced then
				return
			end
			for _, object in playerGui:GetGuiObjectsAtPosition(at.X, at.Y) do
				if object:IsA("GuiButton") and object.Active and object.Visible then
					Juice.press(at, P.cream)
					-- every button squashes under the finger and springs back on release (buttons that
					-- animate themselves keep their own UIScale and are left alone)
					local size = object.AbsoluteSize
					local screen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
					if size.X * size.Y < screen.X * screen.Y * 0.25 and size.X < 720 then
						pressedButton = object
						pressedAt = os.clock()
						Feedback.press(object, "press")
					end
					return
				end
			end
		end)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local kind = input.UserInputType
	if (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) and pressedButton ~= nil then
		local button = pressedButton
		task.defer(function()
			Feedback.press(button, "release")
		end)
	end
end)

-- the button the player pressed last, if it was recent (failures shake it)
function Juice.lastPressed(withinSeconds: number?): GuiObject?
	if pressedButton ~= nil and pressedButton.Parent ~= nil and os.clock() - pressedAt <= (withinSeconds or 1.5) then
		return pressedButton
	end
	return nil
end
-- physical feedback on anything: "press" | "release" | "pop" | "bounce" | "pulse" | "shake" | "wiggle"
function Juice.feedback(instance, kind: string)
	Feedback.on(instance, kind)
end

local function now()
	return os.clock()
end

local function notify()
	if hostSetter ~= nil then
		hostSetter(table.clone(effects))
	end
end

local function push(effect)
	nextId += 1
	effect.id = nextId
	effect.born = now()
	local count = 0
	for index = #effects, 1, -1 do
		if effects[index].kind == effect.kind then
			count += 1
			if count >= CAPS[effect.kind] then
				table.remove(effects, index)
			end
		end
	end
	table.insert(effects, effect)
	if clockSetter ~= nil then
		clockSetter(effect.born)
	end
	notify()
	return effect
end

-- where the last tap landed, if it was recent; otherwise nil
function Juice.pointer(): Vector2?
	if now() - lastPointerAt < 1.2 then
		return lastPointer
	end
	return nil
end

function Juice.setReducedMotion(value: boolean)
	reduced = value == true
	Feedback.setReduced(reduced)
end

local function screenSize()
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function defaultOrigin()
	local size = screenSize()
	return Juice.pointer() or Vector2.new(size.X / 2, size.Y * 0.62)
end

-- a GuiObject's centre in the effects layer's space
local function centreOf(object)
	if object == nil or object.Parent == nil then
		return nil
	end
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	if size.X <= 0 then
		return nil
	end
	return Vector2.new(position.X + size.X / 2, position.Y + size.Y / 2)
end

function Juice.centreOf(object)
	return centreOf(object)
end

-- "+1.2K", floating up from where you tapped
function Juice.number(text: string, color: Color3?, options: { at: Vector2?, big: boolean?, small: boolean?, icon: string? }?)
	local opts = options or {}
	push({
		kind = "number",
		text = text,
		color = color or P.cream,
		at = opts.at or defaultOrigin(),
		big = opts.big == true,
		small = opts.small == true,
		icon = opts.icon,
		drift = math.random(-34, 34),
		tilt = math.random(-8, 8),
	})
end

-- coins that burst out of `from` and fly into the named counter, which bounces as they land
function Juice.coins(target: string, color: Color3?, icon: string?, count: number?, from: Vector2?)
	local destination = centreOf(targets[target])
	if destination == nil then
		return false
	end
	local origin = from or defaultOrigin()
	local total = math.clamp(math.floor(count or 8), 1, 14)
	for index = 1, total do
		local angle = math.random() * math.pi * 2
		local reach = 30 + math.random() * 46
		push({
			kind = "coin",
			target = target,
			color = color or P.mango,
			icon = icon,
			from = origin,
			scatter = Vector2.new(math.cos(angle) * reach, math.sin(angle) * reach),
			to = destination,
			delay = (index - 1) * COIN_STAGGER,
			bend = math.random(-120, 120),
			arrived = false,
			last = index == total,
		})
	end
	return true
end

-- a sparkle burst: four-point stars, rays and a ring
function Juice.burst(at: Vector2?, color: Color3?, scale: number?)
	push({ kind = "burst", at = at or defaultOrigin(), color = color or P.mango, scale = scale or 1, spin = math.random() * 360 })
end

-- a quick ring under a tap
function Juice.ring(at: Vector2?, color: Color3?)
	push({ kind = "ring", at = at or defaultOrigin(), color = color or P.cream })
end

-- a button press: short rays burst out around the tap
function Juice.press(at: Vector2?, color: Color3?)
	push({ kind = "press", at = at or defaultOrigin(), color = color or P.cream, spin = math.random() * 45 })
end

-- a little four-point sparkle (where coins land, and drifting around the screen)
function Juice.spark(at: Vector2, color: Color3?, size: number?)
	push({ kind = "spark", at = at, color = color or P.white, spin = math.random() * 45, size = size or 30 })
end

-- ===========================================================================================
-- The island's player. Every message in the game goes through here and nowhere else.
--
-- One shared queue and one frame-driven clock, owned by this module rather than by any island:
--   * an island that remounts (phone <-> desktop layouts, a page rebuild) picks up exactly where
--     the player is; nothing queued is lost, nothing plays twice
--   * any number of islands show the same thing at the same time
--   * time, not a chain of callbacks, moves it on, so an error anywhere cannot stall it
--   * input is cleaned (tostring, no newlines, capped length), repeats coalesce into "x3",
--     milestones jump the queue, then warnings and errors, then everything else
--   * with no island mounted, messages wait (up to QUEUE_CAP) and play when one appears
-- ===========================================================================================
local QUEUE_CAP = 10
local TITLE_CAP = 64
local SUBTITLE_CAP = 150
local islandQueue = {}
local islandCurrent = nil
local islandSubscribers = {}
local islandToken = 0
local islandDriver = nil

local function cleanText(value, cap)
	if value == nil then
		return nil
	end
	local text = string.gsub(tostring(value), "[\r\n\t]+", " ")
	text = string.gsub(text, "%s%s+", " ")
	text = string.match(text, "^%s*(.-)%s*$") or text
	if text == "" then
		return nil
	end
	if utf8.len(text) and utf8.len(text) > cap then
		local cut = utf8.offset(text, cap) or (cap + 1)
		text = string.sub(text, 1, cut - 1) .. "…"
	end
	return text
end

local function priorityOf(info)
	if info.style == "moment" then
		return 3
	end
	local tone = string.lower(tostring(info.tone or ""))
	if tone == "error" or tone == "warning" then
		return 2
	end
	return 1
end

local function islandNotify()
	local queued = #islandQueue
	-- a fresh copy each time, so a count going up still reads as a change
	local snapshot = if islandCurrent ~= nil then table.clone(islandCurrent) else nil
	for callback in islandSubscribers do
		local ok, problem = pcall(callback, snapshot, queued)
		if not ok then
			warn("[Island] a subscriber failed: " .. tostring(problem))
		end
	end
end

local function holdFor(info)
	local base = info.duration or (if info.style == "pill" then 1.5 elseif info.style == "moment" then 3.2 else 2.6)
	-- a backlog plays through faster
	local backlog = #islandQueue
	return math.clamp(base * (if backlog >= 3 then 0.55 elseif backlog >= 1 then 0.75 else 1), 0.9, 6)
end

local function islandAdvance()
	islandCurrent = nil
	if next(islandSubscribers) ~= nil then
		local nextInfo = table.remove(islandQueue, 1)
		if nextInfo ~= nil then
			islandToken += 1
			nextInfo.token = islandToken
			nextInfo.hold = holdFor(nextInfo)
			nextInfo.startedAt = os.clock()
			islandCurrent = nextInfo
		end
	end
	islandNotify()
end

local function ensureDriver()
	if islandDriver ~= nil then
		return
	end
	islandDriver = RunService.Heartbeat:Connect(function()
		local ok, problem = pcall(function()
			if islandCurrent ~= nil then
				if os.clock() >= islandCurrent.startedAt + islandCurrent.hold then
					islandAdvance()
				end
			elseif #islandQueue > 0 and next(islandSubscribers) ~= nil then
				islandAdvance()
			end
			if islandCurrent == nil and #islandQueue == 0 and islandDriver ~= nil then
				islandDriver:Disconnect()
				islandDriver = nil
			end
		end)
		if not ok then
			-- never let one bad message wedge the player: drop it and carry on
			warn("[Island] skipped a message: " .. tostring(problem))
			islandCurrent = nil
		end
	end)
end

-- an island registers here; callback(current, queuedCount) runs now and on every change
function Juice.subscribeIsland(callback)
	islandSubscribers[callback] = true
	pcall(callback, if islandCurrent ~= nil then table.clone(islandCurrent) else nil, #islandQueue)
	ensureDriver()
	return function()
		islandSubscribers[callback] = nil
	end
end

-- tapping the island moves on to the next message
function Juice.skipIsland()
	if islandCurrent ~= nil then
		islandAdvance()
		ensureDriver()
	end
end

function Juice.hasIsland(): boolean
	return next(islandSubscribers) ~= nil
end

-- style: "notice" (title + line), "moment" (a big milestone: taller, rainbow rim), "pill" (one short line)
function Juice.banner(title: string, subtitle: string?, color: Color3?, icon: string?, duration: number?, tone: string?, style: string?)
	local cleanTitle = cleanText(title, TITLE_CAP) or cleanText(subtitle, TITLE_CAP)
	if cleanTitle == nil then
		return
	end
	local cleanSubtitle = cleanText(subtitle, SUBTITLE_CAP)
	if cleanSubtitle == cleanTitle then
		cleanSubtitle = nil
	end
	local info = {
		title = cleanTitle,
		subtitle = cleanSubtitle,
		color = if typeof(color) == "Color3" then color else P.mango,
		icon = if type(icon) == "string" then icon else nil,
		duration = if type(duration) == "number" and duration == duration then duration else nil,
		tone = tone,
		style = if style == "moment" or style == "pill" then style else "notice",
		count = 1,
	}
	-- the same message again just counts up on the one already showing or waiting
	local function same(other)
		return other ~= nil and other.title == info.title and other.subtitle == info.subtitle
	end
	if same(islandCurrent) then
		islandCurrent.count += 1
		islandCurrent.startedAt = os.clock() -- and stays up a little longer
		islandNotify()
		return
	end
	for _, waiting in islandQueue do
		if same(waiting) then
			waiting.count += 1
			islandNotify()
			return
		end
	end
	-- higher priority goes ahead of anything lower that is still waiting
	local rank = priorityOf(info)
	local at = #islandQueue + 1
	for index, waiting in islandQueue do
		if priorityOf(waiting) < rank then
			at = index
			break
		end
	end
	table.insert(islandQueue, at, info)
	while #islandQueue > QUEUE_CAP do
		-- the oldest, least important message makes room
		local drop, dropRank = #islandQueue, math.huge
		for index, waiting in islandQueue do
			local r = priorityOf(waiting)
			if r < dropRank then
				drop, dropRank = index, r
			end
		end
		table.remove(islandQueue, drop)
	end
	islandNotify()
	ensureDriver()
end

-- a big milestone ("REBIRTH 12!", "NEW WORLD!")
function Juice.moment(title: string, subtitle: string?, color: Color3?, icon: string?)
	Juice.banner(title, subtitle, color, icon, 3.2, "Special", "moment")
end

-- a short reply to a tap ("No rewards to claim."): a quick pill out of the island
function Juice.status(text: string, tone: string?)
	local color = if tone == "error" then P.coral elseif tone == "success" then P.mint elseif tone == "special" then P.mango else P.cream
	local icon = if tone == "error" then "Close" elseif tone == "success" then "Check" elseif tone == "special" then "Boost" else "Wave"
	Juice.banner(text, nil, color, icon, 1.5, tone, "pill")
end

-- live activities the island can show while they last ("combo" = { combo, multiplier, max, window })
local activityListeners = {}
function Juice.onActivity(callback)
	activityListeners[callback] = true
	return function()
		activityListeners[callback] = nil
	end
end
function Juice.activity(kind: string, data)
	for callback in activityListeners do
		task.spawn(callback, kind, data)
	end
end
function Juice.flash(color: Color3?, strength: number?)
	if reduced then
		return
	end
	push({ kind = "flash", color = color or P.cream, strength = math.clamp(strength or 0.35, 0, 0.8) })
end

-- counters register so coins know where to fly; returns a cleanup
function Juice.registerTarget(name: string, object: GuiObject)
	targets[name] = object
	return function()
		if targets[name] == object then
			targets[name] = nil
		end
	end
end

function Juice.onArrive(name: string, callback: () -> ())
	arrivalListeners[name] = arrivalListeners[name] or {}
	arrivalListeners[name][callback] = true
	return function()
		if arrivalListeners[name] then
			arrivalListeners[name][callback] = nil
		end
	end
end

local function arrive(name)
	for callback in arrivalListeners[name] or {} do
		task.spawn(callback)
	end
end

-- hook for a counter: a ref to attach, and a 0..1 bump binding that kicks each time coins land
function Juice.useTarget(name: string)
	local ref = React.useRef(nil)
	local bump, setBump = React.useBinding(0)
	React.useEffect(function()
		local object = ref.current
		local release = if object then Juice.registerTarget(name, object) else nil
		local decay = nil
		local level = 0
		local stopListening = Juice.onArrive(name, function()
			level = math.min(1, level + 0.55)
			setBump(level)
			if decay == nil then
				decay = RunService.RenderStepped:Connect(function(dt)
					level = math.max(0, level - dt * 3.2)
					setBump(level)
					if level <= 0 and decay then
						decay:Disconnect()
						decay = nil
					end
				end)
			end
		end)
		return function()
			stopListening()
			if release then release() end
			if decay then decay:Disconnect() end
		end
	end, { name })
	return ref, bump
end

-- big-number deltas between two snapshots: what you gained (or spent), shown where you tapped
local omegaModule = nil
local function omega()
	if omegaModule == nil then
		local ok, module = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
		end)
		omegaModule = if ok then module else false
	end
	return omegaModule or nil
end
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local CURRENCIES = {
	{ field = "Cash", target = "FLUX", icon = "Flux", color = P.cyan, unit = "flux" },
	{ field = "Stardust", target = "DUST", icon = "Dust", color = P.mango, unit = "stardust" },
	{ field = "Cores", target = "CORES", icon = "Core", color = P.violet, unit = "cores" },
	{ field = "Vault", target = "VAULT", icon = "Flux", color = P.green, unit = "flux stored", gainOnly = true },
}
function Juice.celebrateGains(before, after, options: { spend: boolean?, big: boolean?, coins: number?, skipVault: boolean? }?)
	local O = omega()
	local opts = options or {}
	if O == nil or type(before) ~= "table" or type(after) ~= "table" then
		return 0
	end
	local origin = defaultOrigin()
	local shown = 0
	for _, currency in CURRENCIES do
		if currency.field == "Vault" and opts.skipVault then
			continue
		end
		local ok, delta = pcall(O.Sub, after[currency.field] or 0, before[currency.field] or 0)
		if not ok then
			continue
		end
		local at = origin + Vector2.new(0, -shown * 40)
		if O.Gt(delta, 0) then
			Juice.number(`+{compactNumber(O.Persist(delta))} {currency.unit}`, currency.color, { at = at, big = opts.big, icon = currency.icon })
			Juice.coins(currency.target, currency.color, currency.icon, opts.coins or (if opts.big then 10 else 6), origin)
			shown += 1
		elseif opts.spend and not currency.gainOnly and O.Lt(delta, 0) then
			Juice.number(`-{compactNumber(O.Persist(O.Sub(0, delta)))} {currency.unit}`, P.coral, { at = at })
			shown += 1
		end
	end
	return shown
end

local function easeOutBack(x)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local function easeOutCubic(x)
	return 1 - (1 - x) ^ 3
end
local function easeInCubic(x)
	return x * x * x
end

local function outlined(text, size, color, transparency, z)
	return h("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = P.white,
		TextSize = size,
		TextTransparency = transparency,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = z,
	}, h("uigradient", {
		Color = ColorSequence.new(theme.lighten(color, 0.3), color),
		Rotation = 90,
	}), h("uistroke", {
		Color = theme.darken(color, 0.82),
		Thickness = math.max(2, math.floor(size / 9)),
		Transparency = transparency,
		LineJoinMode = Enum.LineJoinMode.Round,
	}))
end

local function star(size, color, transparency, z)
	-- a four-point sparkle: two tapered bars crossed
	local function bar(rotation)
		return h("frame", {
			Size = UDim2.fromOffset(math.max(2, size * 0.18), size),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ZIndex = z,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}))
	end
	return h("frame", {
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, bar(0), bar(90), h("frame", {
		Size = UDim2.fromOffset(size * 0.22, size * 0.22),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = P.white,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))
end

local function renderEffect(effect, clock)
	local function age()
		return clock:map(function(t) return t - effect.born end)
	end
	if effect.kind == "number" then
		local size = if effect.big then 34 elseif effect.small then 17 else 24
		local t = age()
		local textW = #effect.text * size * 0.52
		local ghost = not effect.small and outlined(effect.text, size, effect.color, t:map(function(a)
			return math.clamp(0.55 + a / 0.45, 0, 1)
		end), 30)
		return h("frame", {
			key = effect.id,
			Size = UDim2.fromOffset(360, size + 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 30,
			Position = t:map(function(a)
				local p = easeOutCubic(math.clamp(a / LIFE.number, 0, 1))
				return UDim2.fromOffset(effect.at.X + effect.drift * p * 0.4, effect.at.Y - 22 - p * (if effect.small then 34 else 96))
			end),
			Rotation = t:map(function(a)
				return effect.tilt * (1 - math.clamp(a / 0.35, 0, 1))
			end),
		}, h("uiscale", {
			Scale = t:map(function(a)
				local pop = math.clamp(a / 0.22, 0, 1)
				return 0.35 + easeOutBack(pop) * 0.65
			end),
		}), outlined(effect.text, size, effect.color, t:map(function(a)
			return math.clamp((a - LIFE.number * 0.6) / (LIFE.number * 0.4), 0, 1)
		end), 31), ghost and h("frame", {
			-- an echo that swells and fades behind the number
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 30,
		}, h("uiscale", {
			Scale = t:map(function(a) return 1 + easeOutCubic(math.clamp(a / 0.45, 0, 1)) * 0.9 end),
		}), ghost), effect.icon and h("frame", {
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.new(0.5, -textW / 2 - size * 0.7, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.darken(effect.color, 0.55),
			BackgroundTransparency = t:map(function(a)
				return math.clamp((a - LIFE.number * 0.6) / (LIFE.number * 0.4), 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 31,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = theme.lighten(effect.color, 0.35),
			Thickness = 2,
		}), h(Icon, {
			kind = effect.icon,
			color = P.white,
			accent = effect.color,
			size = size - 6,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			spin = false,
		})))
	elseif effect.kind == "coin" then
		local t = age()
		local size = 22
		return h("frame", {
			key = effect.id,
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 26,
			Position = t:map(function(a)
				local local_ = a - effect.delay
				if local_ <= 0 then
					return UDim2.fromOffset(effect.from.X, effect.from.Y)
				end
				if local_ < COIN_SCATTER then
					local p = easeOutCubic(local_ / COIN_SCATTER)
					local spot = effect.from + effect.scatter * p
					return UDim2.fromOffset(spot.X, spot.Y)
				end
				local p = easeInCubic(math.clamp((local_ - COIN_SCATTER) / COIN_FLIGHT, 0, 1))
				local start = effect.from + effect.scatter
				local mid = (start + effect.to) / 2 + Vector2.new(effect.bend, -80)
				local a1 = start:Lerp(mid, p)
				local a2 = mid:Lerp(effect.to, p)
				local spot = a1:Lerp(a2, p)
				return UDim2.fromOffset(spot.X, spot.Y)
			end),
			Visible = t:map(function(a) return a >= effect.delay end),
		}, h("uiscale", {
			Scale = t:map(function(a)
				local local_ = a - effect.delay
				local grow = easeOutBack(math.clamp(local_ / 0.16, 0, 1))
				local shrink = 1 - 0.45 * math.clamp((local_ - COIN_SCATTER - COIN_FLIGHT * 0.6) / (COIN_FLIGHT * 0.4), 0, 1)
				return math.max(0.05, grow * shrink)
			end),
		}), h("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme.darken(effect.color, 0.55),
			BorderSizePixel = 0,
			ZIndex = 26,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = theme.lighten(effect.color, 0.35),
			Thickness = 2,
		}), effect.icon and h(Icon, {
			kind = effect.icon,
			color = P.white,
			accent = effect.color,
			size = size - 6,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			spin = false,
		})))
	elseif effect.kind == "burst" then
		local t = age()
		local s = effect.scale
		local children = {}
		local progress = t:map(function(a) return math.clamp(a / LIFE.burst, 0, 1) end)
		-- rays
		for index = 1, 10 do
			local rotation = effect.spin + index * 36
			children["ray" .. index] = h("frame", {
				Size = progress:map(function(p)
					return UDim2.fromOffset(4 * s, (40 + easeOutCubic(p) * 110) * s)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 1),
				Rotation = rotation,
				BackgroundColor3 = effect.color,
				BackgroundTransparency = progress:map(function(p) return 0.25 + p * 0.75 end),
				BorderSizePixel = 0,
				ZIndex = 27,
			}, h("uigradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(1, 0),
			}))
		end
		-- white core flash
		children.core = h("frame", {
			Size = progress:map(function(p)
				local d = (24 + easeOutCubic(math.min(1, p * 3)) * 70) * s
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = P.white,
			BackgroundTransparency = progress:map(function(p) return math.clamp(0.1 + p * 2.2, 0, 1) end),
			BorderSizePixel = 0,
			ZIndex = 29,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
		-- ring
		children.ring = h("frame", {
			Size = progress:map(function(p)
				local d = (30 + easeOutCubic(p) * 190) * s
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 27,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = theme.lighten(effect.color, 0.3),
			Thickness = 3,
			Transparency = progress:map(function(p) return p end),
		}))
		-- stars flung outward
		for index = 1, 8 do
			local angle = math.rad(effect.spin + index * 45 + (index % 2) * 18)
			local reach = (70 + (index % 3) * 34) * s
			local starSize = (if index % 2 == 0 then 38 else 26) * s
			children["star" .. index] = h("frame", {
				Size = UDim2.fromOffset(starSize, starSize),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 28,
				Position = progress:map(function(p)
					local e = easeOutCubic(p)
					return UDim2.new(0.5, math.cos(angle) * reach * e, 0.5, math.sin(angle) * reach * e)
				end),
				Rotation = progress:map(function(p) return p * 90 end),
			}, h("uiscale", {
				Scale = progress:map(function(p) return math.sin(math.min(1, p * 1.3) * math.pi) * 1.2 + 0.01 end),
			}), star(starSize, if index % 3 == 0 then P.white else theme.lighten(effect.color, 0.4), 0, 28))
		end
		return h("frame", {
			key = effect.id,
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(effect.at.X, effect.at.Y),
			BackgroundTransparency = 1,
			ZIndex = 27,
		}, children)
	elseif effect.kind == "ring" then
		local t = age()
		return h("frame", {
			key = effect.id,
			Size = t:map(function(a)
				local d = 18 + easeOutCubic(math.clamp(a / LIFE.ring, 0, 1)) * 70
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromOffset(effect.at.X, effect.at.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 25,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = effect.color,
			Thickness = 2,
			Transparency = t:map(function(a) return 0.2 + math.clamp(a / LIFE.ring, 0, 1) * 0.8 end),
		}))
	elseif effect.kind == "press" then
		local t = age()
		local progress = t:map(function(a) return math.clamp(a / LIFE.press, 0, 1) end)
		local spokes = {}
		for index = 1, 8 do
			local angle = math.rad(effect.spin + index * 45)
			spokes["s" .. index] = h("frame", {
				Size = progress:map(function(p) return UDim2.fromOffset(3, 6 + (1 - p) * 10) end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = math.deg(angle) + 90,
				Position = progress:map(function(p)
					local r = 14 + easeOutCubic(p) * 26
					return UDim2.fromOffset(math.cos(angle) * r, math.sin(angle) * r)
				end),
				BackgroundColor3 = effect.color,
				BackgroundTransparency = progress:map(function(p) return 0.1 + p * 0.9 end),
				BorderSizePixel = 0,
				ZIndex = 25,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
		spokes.ring = h("frame", {
			Size = progress:map(function(p)
				local d = 16 + easeOutCubic(p) * 44
				return UDim2.fromOffset(d, d)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 25,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = effect.color,
			Thickness = 2,
			Transparency = progress:map(function(p) return 0.25 + p * 0.75 end),
		}))
		return h("frame", {
			key = effect.id,
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(effect.at.X, effect.at.Y),
			BackgroundTransparency = 1,
			ZIndex = 25,
		}, spokes)
	elseif effect.kind == "spark" then
		local t = age()
		return h("frame", {
			key = effect.id,
			Size = UDim2.fromOffset(effect.size or 30, effect.size or 30),
			Position = UDim2.fromOffset(effect.at.X, effect.at.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 34,
			Rotation = t:map(function(a) return effect.spin + a * 120 end),
		}, h("uiscale", {
			Scale = t:map(function(a) return math.sin(math.clamp(a / LIFE.spark, 0, 1) * math.pi) * 1.3 + 0.01 end),
		}), star(effect.size or 30, effect.color, 0, 34))
	elseif effect.kind == "flash" then
		local t = age()
		return h("frame", {
			key = effect.id,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = effect.color,
			BorderSizePixel = 0,
			ZIndex = 20,
			BackgroundTransparency = t:map(function(a)
				return 1 - effect.strength * (1 - math.clamp(a / LIFE.flash, 0, 1))
			end),
		})
	end
	return nil
end

local function lifeOf(effect)
	if effect.kind == "coin" then
		return effect.delay + COIN_SCATTER + COIN_FLIGHT + 0.02
	end
	return LIFE[effect.kind] or 1
end

-- the host: mount once, above everything
function Juice.Host(_props)
	local list, setList = React.useState({})
	local clock, setClock = React.useBinding(now())
	React.useEffect(function()
		hostSetter = setList
		clockSetter = setClock
		-- (no ambient twinkles: random sparks over buttons and text read as glitches)
		local twinkling = true
		local lastCoinTick, coinRun = -math.huge, 0
		local connection = RunService.RenderStepped:Connect(function()
			if #effects == 0 then
				return
			end
			local t = now()
			setClock(t)
			local removed = false
			for index = #effects, 1, -1 do
				local effect = effects[index]
				local age = t - effect.born
				if effect.kind == "coin" and not effect.arrived and age >= effect.delay + COIN_SCATTER + COIN_FLIGHT then
					effect.arrived = true
					arrive(effect.target)
					-- the sound lands with the coin: a soft tick that climbs through a shower
					if t - lastCoinTick > 0.035 then
						coinRun = if t - lastCoinTick > 0.4 then 0 else coinRun + 1
						lastCoinTick = t
						pcall(function()
							require(script.Parent.AudioKit)("audio").Audio:play("countTick", 1 + math.min(coinRun, 12) * 0.035 + (if effect.last then 0.12 else 0))
						end)
					end
					if effect.last then
						Juice.spark(effect.to + Vector2.new(math.random(-10, 10), math.random(-8, 8)), theme.lighten(effect.color, 0.5))
					end
				end
				if age >= lifeOf(effect) then
					table.remove(effects, index)
					removed = true
				end
			end
			if removed then
				notify()
			end
		end)
		return function()
			connection:Disconnect()
			twinkling = false
			if hostSetter == setList then
				hostSetter = nil
				clockSetter = nil
			end
		end
	end, {})
	local children = {}
	for _, effect in list do
		children[effect.id] = renderEffect(effect, clock)
	end
	-- Studio only: the command bar gets its own copy of this module, so tests reach the live one
	-- through an event on the layer ("number" | "coins" | "burst" | "status" | "flash" | "ring", args...)
	local hostRef = React.useRef(nil)
	React.useEffect(function()
		if not RunService:IsStudio() then
			return nil
		end
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local event = Instance.new("BindableEvent")
		event.Name = "JuiceDebug"
		event.Parent = host
		local connection = event.Event:Connect(function(kind, ...)
			local fn = Juice[kind]
			if type(fn) == "function" then
				fn(...)
			end
		end)
		return function()
			connection:Disconnect()
			event:Destroy()
		end
	end, {})
	return h("frame", {
		ref = hostRef,
		Name = "JuiceFx",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 1,
	}, children)
end

return Juice
