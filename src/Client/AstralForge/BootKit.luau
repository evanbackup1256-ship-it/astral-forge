--!nonstrict
--[=[
	BootKit: merged module suite.
	Members (4): BootScreen, BootStageText, LoadingDots, SoftShutdownScreen.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("BootKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("BootKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: BootScreen   (merged from BootScreen.luau, 445 lines)
-- ======================================================================
__defs["BootScreen"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local GAME_ICON_ASSET = require(script.Parent.ArtKit)("Icon").GAME_ICON_ASSET
local EMBER_COUNT = 22
local BootStageText = __load("BootStageText").BootStageText
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
-- Pure curves only (the boot screen loads before the React motion stack).
local MotionTokens = require(script.Parent.MotionKit)("motionTokens")
local BOOT_MODULE_TIMEOUT = 9
local MIN_BOOT_SECONDS = 3.2
local BOOT_MOTION = {
	motionScale = 1,
	viewportScale = 1,
	textScale = 1,
}
local EXIT_SPIN_SECONDS = 0.22
local EXIT_VEIL_SECONDS = 0.32
local STALL_SECONDS = 45
local SYSTEMS = { "bridge", "remotes", "state", "assets", "modules", "fonts", "audio", "shell", "mail", "research", "forge", "trade", "boosts", "settings", "mobile" }
local STAGE_LABELS = { "CONNECTING", "LOADING ASSETS", "LOADING FONTS", "LOADING SOUNDS", "LOADING ANIMATIONS", "LOADING UI", "LOADING SAVES", "LOADING MAIL", "LOADING RESEARCH", "LOADING FORGE", "LOADING TRADE", "LOADING BOOSTS", "LOADING SETTINGS", "LOADING MOBILE", "FINISHING", "READY" }
local LOADING_TIPS = { "Tap machines to overcharge them for bonus flux.", "Research is permanent — it survives rebirths.", "Complete daily lab orders for stardust rewards.", "Build your guild hall and recruit forgemasters.", "Check the Star Grid for permanent passive boosts.", "Stabilize anomalies to charge the reactor faster.", "Trade with other players to complete your collection.", "Activate boosts before a long session for max gains.", "Rebirth at the right moment to multiply your output.", "Equip relics to specialize your forge style.", "Claim mail rewards daily for free resources.", "Unlock new worlds to access rare machines.", "Join a guild goal — everyone's contribution counts.", "Weekly directives reset every Monday with fresh rewards.", "Spin the wheel daily — pity guarantees a rare eventually.", "Command XP unlocks crew upgrades and expedition slots.", "Forge echoes stack traits — chase a matching affinity set.", "Convergence events reward a shared production boost.", "Auto-forge keeps your best machine buying while you're away.", "Milestones track lifetime stats — they never reset.", "Season tiers bank XP even before you claim a reward.", "Salvage unwanted relics for essence to reroll better ones.", "Signal shop offers rotate daily — check back often.", "Streak shields protect your daily login streak once.", "Open Settings → GUIDE anytime to replay the tutorial.", "Xbox: Y collects the vault · LB / RB switches pages." }
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function statusFor(marks, ready, stalled, loaded, total)
	if ready then
		return "READY"
	end
	local stage = 0
	for _, key in SYSTEMS do
		if marks[key] then
			stage += 1
		else
			break
		end
	end
	if stalled then
		return "FINISHING"
	end
	if stage >= #SYSTEMS then
		return "READY"
	end
	local _condition = STAGE_LABELS[math.min(stage, #STAGE_LABELS - 1) + 1]
	if _condition == nil then
		_condition = "LOADING"
	end
	return _condition
end
local function progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	local complete = 0
	for _, key in SYSTEMS do
		if marks[key] then
			complete += 1
		end
	end
	local partial = 0
	if not marks.assets and assetsTotal ~= nil and assetsTotal > 0 and assetsLoaded ~= nil then
		partial += math.clamp(assetsLoaded / assetsTotal, 0, 1) * 0.85
	end
	if not marks.modules and modulesTotal ~= nil and modulesTotal > 0 and modulesLoaded ~= nil then
		partial += math.clamp(modulesLoaded / modulesTotal, 0, 1) * 0.85
	end
	return math.clamp((complete + partial) / #SYSTEMS, 0, 1)
end
local function bootChecklistReady(marks)
	for _, key in SYSTEMS do
		if not marks[key] then
			return false
		end
	end
	return true
end
local function bootProgress(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	return progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
end
local function BootScreen(_param)
	local marks = _param.marks
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local startedAt = _param.startedAt
	local assetsLoaded = _param.assetsLoaded
	local assetsTotal = _param.assetsTotal
	local modulesLoaded = _param.modulesLoaded
	local modulesTotal = _param.modulesTotal
	local _version = _param.version
	local onExitDone = _param.onExitDone
	local _condition = startedAt
	if _condition == nil then
		_condition = os.clock()
	end
	local mountedAt = React.useRef(_condition)
	local finished = React.useRef(false)
	local exitClock = React.useRef(0)
	local spinClock = React.useRef(0)
	local exiting, setExiting = React.useState(false)
	local gone, setGone = React.useState(false)
	local stalled, setStalled = React.useState(false)
	local tipIndex, setTipIndex = React.useState(0)
	local clock, setClock = React.useBinding(0)
	local spinFade, setSpinFade = React.useBinding(0)
	local veilFade, setVeilFade = React.useBinding(0)
	local progressPulse, setProgressPulse = React.useBinding(0)
	-- The bar glides toward the real progress instead of jumping between
	-- loading stages.
	local shownProgress, setShownProgress = React.useBinding(0)
	local shownRef = React.useRef(0)
	local targetProgress = React.useRef(0)
	React.useEffect(function()
		local alive = true
		Audio:setScene("boot")
		local start = function()
			if alive and os.clock() - mountedAt.current <= 0.55 then
				Audio:play("bootStart")
			end
		end
		if Audio:isWarm() then
			start()
		else
			Audio:whenWarm(start)
		end
		return function()
			alive = false
			Audio:setScene("default")
		end
	end, {})
	React.useEffect(function()
		-- The medallion is the first thing on screen: fetch it before anything else.
		task.spawn(function()
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({ GAME_ICON_ASSET })
			end)
		end)
	end, {})
	React.useEffect(function()
		local current = tipIndex
		local token = task.delay(3.2, function()
			return setTipIndex((current + 1) % #LOADING_TIPS)
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { tipIndex })
	React.useEffect(function()
		if ready then
			return nil
		end
		local elapsed = os.clock() - mountedAt.current
		local remaining = math.max(0, STALL_SECONDS - elapsed)
		local token = task.delay(remaining, function()
			return setStalled(true)
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { ready })
	React.useEffect(function()
		if ready and not exiting and not finished.current then
			local elapsed = os.clock() - mountedAt.current
			local hold = math.max(0, MIN_BOOT_SECONDS - elapsed)
			local token = task.delay(hold, function()
				if finished.current then
					return nil
				end
				finished.current = true
				exitClock.current = 0
				setExiting(true)
				Audio:play("bootReady")
			end)
			return function()
				pcall(task.cancel, token)
			end
		elseif not exiting and not finished.current then
			local timeout = if RunService:IsStudio() then 22 else 36
			local token = task.delay(timeout, function()
				if not finished.current then
					finished.current = true
					exitClock.current = 0
					setExiting(true)
				end
			end)
			return function()
				pcall(task.cancel, token)
			end
		end
	end, { exiting, ready })
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			shownRef.current += (targetProgress.current - shownRef.current) * (1 - math.exp(-dt * 7))
			setShownProgress(shownRef.current)
			-- The spinner keeps turning while it fades out; stopping it read as a freeze.
			local rate = if softMotion then 0.55 else 1
			spinClock.current += dt * rate
			setClock(spinClock.current)
			setProgressPulse((math.sin(spinClock.current * 2.4) + 1) * 0.5)
			if not exiting then
				return nil
			end
			exitClock.current += dt
			local elapsed = exitClock.current
			local spinSeconds = if softMotion then EXIT_SPIN_SECONDS * 0.55 else EXIT_SPIN_SECONDS
			local veilSeconds = if softMotion then EXIT_VEIL_SECONDS * 0.55 else EXIT_VEIL_SECONDS
			-- The spinner leaves by accelerating away; the veil lifts on a smooth S.
			setSpinFade(MotionTokens.EASE.accelerate(clamp01(elapsed / spinSeconds)))
			setVeilFade(MotionTokens.EASE.smoothInOut(clamp01((elapsed - spinSeconds) / veilSeconds)))
		end)
		return function()
			return connection:Disconnect()
		end
	end, { exiting, softMotion, setClock, setSpinFade, setVeilFade })
	React.useEffect(function()
		if not exiting then
			return nil
		end
		local span = (EXIT_SPIN_SECONDS + EXIT_VEIL_SECONDS) * (if softMotion then 0.55 else 1) + 0.05
		local token = task.delay(span, function()
			setGone(true)
			onExitDone()
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { exiting, onExitDone })
	if gone then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local status = statusFor(marks, ready, stalled, assetsLoaded, assetsTotal)
	local progress = if ready then 1 else progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	targetProgress.current = progress
	local tipText = LOADING_TIPS[tipIndex + 1] or ""
	local countText = ""
	if not ready then
		local pieces = {}
		if assetsTotal ~= nil and assetsTotal > 0 then
			table.insert(pieces, `{math.min(assetsLoaded or 0, assetsTotal)} / {assetsTotal} assets`)
		end
		if modulesTotal ~= nil and modulesTotal > 0 then
			table.insert(pieces, `{math.min(modulesLoaded or 0, modulesTotal)} / {modulesTotal} modules`)
		end
		countText = table.concat(pieces, "   ·   ")
	end
	local hidden = spinFade:map(function(amount)
		return amount
	end)
	local showing = spinFade:map(function(amount)
		return amount < 0.98
	end)
	local function fadeFrom(base)
		return hidden:map(function(amount)
			return math.clamp(base + amount, 0, 1)
		end)
	end

	-- Embers rising off the forge glow. Each one's path is fixed by its index, so
	-- the field looks random without any per-frame randomness.
	local embers = {}
	for index = 1, EMBER_COUNT do
		local seed = math.abs(math.sin(index * 12.9898) * 43758.5453) % 1
		local seedB = math.abs(math.sin(index * 78.233) * 12345.678) % 1
		local speed = 0.07 + seedB * 0.09
		local size = 2 + math.floor(seed * 4)
		embers["ember" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(size, size),
			Position = clock:map(function(t)
				local rise = (t * speed + seed) % 1
				local sway = math.sin(t * (0.8 + seedB) + index) * 0.015
				return UDim2.fromScale(0.08 + seed * 0.84 + sway, 1.02 - rise * 0.75)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = clock:map(function(t)
				return (t * 60 * (seedB - 0.5)) % 360
			end),
			BackgroundColor3 = if index % 3 == 0 then Palette.mango elseif index % 3 == 1 then Palette.ember else Palette.brass,
			BackgroundTransparency = React.joinBindings({ clock, veilHide }):map(function(values)
				local rise = (values[1] * speed + seed) % 1
				-- Bright as it leaves the glow, gone by the time it reaches the middle.
				return math.clamp(0.15 + rise * 1.1 + values[2], 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	end

	-- Sparks thrown back off the hot tip of the bar.
	local sparks = {}
	for index = 1, 6 do
		local phase = index / 6
		local spread = 0.6 + 0.4 * math.abs(math.sin(index * 2.3))
		sparks["spark" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(3, 3),
			Position = clock:map(function(t)
				local k = (t * 1.7 + phase) % 1
				return UDim2.new(0.5, -k * 30 * spread, 0.5, -k * 24 * spread + k * k * 34)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 2 == 0 then Palette.cream else Palette.mango,
			BackgroundTransparency = React.joinBindings({ clock, spinFade }):map(function(values)
				local k = (values[1] * 1.7 + phase) % 1
				return math.clamp(k * 1.1 + values[2], 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 9,
		})
	end

	local barW = 300
	local barH = 10
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = veilHide,
		BorderSizePixel = 0,
		Active = not exiting and not gone,
		ClipsDescendants = true,
		ZIndex = 420,
		Visible = veilFade:map(function(amount)
			return amount < 0.995
		end),
	}, React.createElement("frame", {
		-- The forge glow: warm light coming up from below the screen.
		Size = UDim2.fromScale(1.4, 0.7),
		Position = UDim2.fromScale(0.5, 1.12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = React.joinBindings({ progressPulse, veilHide }):map(function(values)
			return math.clamp(0.72 - values[1] * 0.05 + values[2], 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.mango, Palette.ember),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Rotation = 90,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, embers), React.createElement("frame", {
		-- Medallion: the game icon in a brass ring, like the in-game logo, breathing slowly.
		Size = UDim2.fromOffset(112, 112),
		Position = UDim2.new(0.5, 0, 0.4, -40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(14, 10, 17),
		BackgroundTransparency = fadeFrom(0),
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = showing,
	}, React.createElement("uiscale", {
		Scale = React.joinBindings({ progressPulse, spinFade }):map(function(values)
			return 1 + values[1] * 0.025 - values[2] * 0.08
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.brass,
		Thickness = 3,
		Transparency = fadeFrom(0.05),
	}, React.createElement("uigradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.brassDeep),
			ColorSequenceKeypoint.new(0.5, Palette.mango),
			ColorSequenceKeypoint.new(1, Palette.brassDeep),
		}),
		Rotation = clock:map(function(t)
			return (t * 40) % 360
		end),
	})), React.createElement("imagelabel", {
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = GAME_ICON_ASSET,
		ImageTransparency = fadeFrom(0),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 6,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		-- Halo behind the medallion.
		Size = UDim2.fromOffset(190, 190),
		Position = UDim2.new(0.5, 0, 0.4, -40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = React.joinBindings({ progressPulse, spinFade }):map(function(values)
			return math.clamp(0.86 - values[1] * 0.04 + values[2], 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 4,
		Visible = showing,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})), React.createElement("textlabel", {
		-- Wordmark: ASTRAL in cream, FORGE in brass.
		Size = UDim2.new(0.9, 0, 0, 40),
		Position = UDim2.new(0.5, 0, 0.4, 34),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		RichText = true,
		Text = `<font color="#FCF7F0">ASTRAL</font> <font color="#FABE48">FORGE</font>`,
		TextTransparency = fadeFrom(0),
		TextSize = 34,
		TextScaled = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 6,
		Visible = showing,
		}, React.createElement("uitextsizeconstraint", {
			MaxTextSize = 34,
			MinTextSize = 20,
		}), React.createElement("uistroke", {
		Color = Palette.void,
		Thickness = 2,
		Transparency = fadeFrom(0.3),
	})), React.createElement("frame", {
		-- The bar: a cold steel track that fills with molten metal.
		Size = UDim2.new(0.72, 0, 0, barH),
		Position = UDim2.new(0.5, 0, 0.4, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.graphite,
		BackgroundTransparency = fadeFrom(0),
		BorderSizePixel = 0,
		ZIndex = 6,
		Visible = showing,
		}, React.createElement("uisizeconstraint", {
			MaxSize = Vector2.new(barW, barH),
		}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.brassDeep,
		Thickness = 1.5,
		Transparency = fadeFrom(0.1),
	}), React.createElement("frame", {
		Size = shownProgress:map(function(shown)
			return UDim2.new(math.clamp(shown, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = fadeFrom(0),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		-- Cooling to deep red behind, white-hot at the tip.
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.ember),
			ColorSequenceKeypoint.new(0.7, Palette.mango),
			ColorSequenceKeypoint.new(1, Palette.cream),
		}),
	}), React.createElement("frame", {
		-- The hot tip's glow.
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = React.joinBindings({ progressPulse, spinFade }):map(function(values)
			return math.clamp(0.55 - values[1] * 0.2 + values[2], 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.zero,
	}), sparks))), React.createElement("frame", {
		Size = UDim2.new(0.9, 0, 0, 20),
		Position = UDim2.new(0.5, 0, 0.4, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Visible = showing,
	}, React.createElement(BootStageText, {
		text = status,
		clock = clock,
		leaving = hidden,
		reducedMotion = reducedMotion,
		textSize = 12,
		color = Palette.creamSoft,
		width = 340,
		height = 20,
	})), React.createElement("textlabel", {
	Size = UDim2.new(0.9, 0, 0, 14),
	Position = UDim2.new(0.5, 0, 0.4, 134),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Text = shownProgress:map(function(shown)
		local pct = `{math.floor(math.clamp(shown, 0, 1) * 100 + 0.5)}%`
		return if countText ~= "" then pct .. "   ·   " .. countText else pct
	end),
		TextColor3 = Palette.muted,
		TextTransparency = fadeFrom(0.25),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		ZIndex = 6,
		Visible = showing,
	}), React.createElement("frame", {
		-- Tip card along the bottom.
		Size = UDim2.new(0.92, 0, 0, 34),
		Position = UDim2.new(0.5, 0, 1, -44),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = fadeFrom(0.2),
		BorderSizePixel = 0,
		ZIndex = 6,
		Visible = showing,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = if stalled then Palette.mango else Palette.line,
		Transparency = fadeFrom(0.3),
	}), React.createElement("uisizeconstraint", {
		MaxSize = Vector2.new(460, 34),
	}), React.createElement("textlabel", {
		Size = UDim2.fromOffset(44, 34),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = if stalled then "WAIT" else "TIP",
		TextColor3 = Palette.brass,
		TextTransparency = fadeFrom(0),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -66, 1, 0),
		Position = UDim2.fromOffset(54, 0),
		BackgroundTransparency = 1,
		Text = if stalled then "Still loading. Hang tight, your save is safe." else tipText,
		TextColor3 = Palette.creamSoft,
		TextTransparency = fadeFrom(0.05),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	})), _version ~= nil and React.createElement("textlabel", {
		Size = UDim2.fromOffset(160, 14),
		Position = UDim2.new(1, -16, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Text = `v{_version}`,
		TextColor3 = Palette.line,
		TextTransparency = fadeFrom(0),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
	}))
end
return {
	bootChecklistReady = bootChecklistReady,
	bootProgress = bootProgress,
	BootScreen = BootScreen,
	BOOT_MODULE_TIMEOUT = BOOT_MODULE_TIMEOUT,
	BOOT_MOTION = BOOT_MOTION,
}
end

-- ======================================================================
-- Module: BootStageText   (merged from BootStageText.luau, 159 lines)
-- ======================================================================
__defs["BootStageText"] = function()
-- Boot status text that rolls like NumberSpinner: each glyph rides a vertical reel
-- when the status string changes. Clipped host, fixed height, no AbsoluteSize bombs.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette

local ROLL = 0.42
local CHAR_W = 8.2
local MAX_CHARS = 42

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function easeOutCubic(t: number): number
	local u = 1 - clamp01(t)
	return 1 - u * u * u
end

type Props = {
	text: string,
	clock: React.Binding<number>,
	leaving: React.Binding<number>?,
	reducedMotion: boolean?,
	textSize: number?,
	color: Color3?,
	width: number?,
	height: number?,
}

local function BootStageText(props: Props)
	local text = props.text or ""
	local clock = props.clock
	local leaving = props.leaving
	local reducedMotion = props.reducedMotion == true
	local textSize = props.textSize or 12
	local color = props.color or Palette.muted
	local width = props.width or 340
	local height = props.height or 20
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave

	local prevRef = React.useRef(text)
	local fromRef = React.useRef(text)
	local rollStartRef = React.useRef(0)
	local rollingRef = React.useRef(false)

	React.useEffect(function()
		if text == prevRef.current then
			return
		end
		fromRef.current = prevRef.current
		prevRef.current = text
		if reducedMotion then
			rollingRef.current = false
			return
		end
		rollingRef.current = true
		-- Capture clock at change via a one-shot join; use os.clock as fallback anchor.
		rollStartRef.current = os.clock()
	end, { text, reducedMotion } :: { any })

	local glyphCount = math.min(MAX_CHARS, math.max(#text, #fromRef.current, 8))
	local children = table.create(glyphCount)

	for i = 1, glyphCount do
		local targetChar = string.sub(text, i, i)
		if targetChar == "" then
			targetChar = " "
		end
		local fromChar = string.sub(fromRef.current, i, i)
		if fromChar == "" then
			fromChar = " "
		end
		local x = (i - 0.5) * CHAR_W + (width - glyphCount * CHAR_W) * 0.5

		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(values)
			local fade = clamp01(values.leaving)
			local elapsed = os.clock() - rollStartRef.current
			local rolling = rollingRef.current and not reducedMotion
			local amount = if rolling then easeOutCubic(elapsed / ROLL) else 1
			if rolling and amount >= 1 then
				rollingRef.current = false
			end
			local y = if rolling and fromChar ~= targetChar then (1 - amount) * height else 0
			local ghostAlpha = if rolling and fromChar ~= targetChar then (1 - amount) else 0
			return {
				y = y,
				ghost = ghostAlpha,
				fade = fade,
			}
		end)

		children[i] = React.createElement("frame", {
			key = `boot-ch-{i}`,
			Size = UDim2.fromOffset(math.ceil(CHAR_W), height),
			Position = UDim2.fromOffset(x, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 4,
		}, React.createElement("textlabel", {
			Size = UDim2.fromOffset(math.ceil(CHAR_W) + 2, height),
			Position = motion:map(function(v)
				return UDim2.fromOffset(0, v.y)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = targetChar,
			TextColor3 = color,
			TextTransparency = motion:map(function(v)
				return clamp01(0.08 + v.fade)
			end),
			TextSize = textSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 5,
		}), React.createElement("textlabel", {
			Size = UDim2.fromOffset(math.ceil(CHAR_W) + 2, height),
			Position = motion:map(function(v)
				return UDim2.fromOffset(0, v.y - height)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = fromChar,
			TextColor3 = color,
			TextTransparency = motion:map(function(v)
				return clamp01(0.15 + (1 - v.ghost) + v.fade)
			end),
			TextSize = textSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 4,
			Visible = motion:map(function(v)
				return v.ghost > 0.02 and v.fade < 0.96
			end),
		}))
	end

	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, children)
end

return {
	BootStageText = BootStageText,
}
end

-- ======================================================================
-- Module: LoadingDots   (merged from LoadingDots.luau, 96 lines)
-- ======================================================================
__defs["LoadingDots"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.CoreKit)("theme").Palette
local DOTS = { 0, 1, 2, 3 }
local CYCLE = 0.86
local COUNT = 4
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function pulse(elapsed, index)
	local travel = ((elapsed / CYCLE) % 1) * COUNT
	local delta = math.abs(travel - index)
	local wrap = math.min(delta, COUNT - delta)
	local falloff = clamp01(1 - wrap)
	return falloff * falloff * (3 - 2 * falloff)
end
local function LoadingDots(_param)
	local clock = _param.clock
	local leaving = _param.leaving
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	local width = if compact then 92 else 112
	local height = if compact then 22 else 26
	local gap = if compact then 18 else 22
	local size = if compact then 7 else 8
	local lift = if compact then 5 else 6
	local center = width / 2
	local restY = height * 0.55
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#DOTS)
	local _callback = function(index)
		local x = center + (index - 1.5) * gap
		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(_param_1)
			local elapsed = _param_1.clock
			local exit = _param_1.leaving
			local fade = clamp01(exit)
			if reducedMotion or ready then
				return {
					y = restY,
					scale = 0.72,
					alpha = 0.45,
					mix = 0,
					fade = fade,
				}
			end
			local amount = pulse(elapsed, index)
			return {
				y = restY - amount * lift,
				scale = 0.62 + amount * 0.38,
				alpha = 0.28 + amount * 0.72,
				mix = amount,
				fade = fade,
			}
		end)
		return React.createElement("frame", {
			key = `load-dot-{index}`,
			Size = motion:map(function(value)
				return UDim2.fromOffset(size * value.scale, size * value.scale)
			end),
			Position = motion:map(function(value)
				return UDim2.fromOffset(x, value.y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = motion:map(function(value)
				return Palette.cream:Lerp(Palette.cyan, value.mix)
			end),
			BackgroundTransparency = motion:map(function(value)
				return clamp01(1 - value.alpha + value.fade)
			end),
			BorderSizePixel = 0,
			ZIndex = 527,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in DOTS do
		_newValue[_k] = _callback(_v, _k - 1, DOTS)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 525,
	}, _newValue)
end
return {
	LoadingDots = LoadingDots,
}
end

-- ======================================================================
-- Module: SoftShutdownScreen   (merged from SoftShutdownScreen.luau, 180 lines)
-- ======================================================================
__defs["SoftShutdownScreen"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local LoadingDots = __load("LoadingDots").LoadingDots
local Palette = require(script.Parent.CoreKit)("theme").Palette
local function phaseName(phase)
	if phase == "Teleporting" then
		return "Teleporting"
	end
	if phase == "Waiting" then
		return "Waiting"
	end
	return "Saving"
end
local function titleFor(phase)
	if phase == "Teleporting" then
		return "JOINING NEW SERVER"
	end
	if phase == "Waiting" then
		return "RECONNECTING"
	end
	return "SAVING YOUR PROGRESS"
end
local function statusFor(phase)
	if phase == "Teleporting" then
		return "Save locked in. Moving you to the fresh server."
	end
	if phase == "Waiting" then
		return "Stay here — we'll hop you when the new server is ready."
	end
	return "Don't leave yet — writing your save to the cloud."
end
local function cueFor(phase)
	if phase == "Teleporting" then
		return "travel"
	end
	if phase == "Waiting" then
		return "systemAlert"
	end
	return "bootStart"
end
local function SoftShutdownScreen(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local phase = phaseName(state.phase)
	local teleporting = phase == "Teleporting"
	local waiting = phase == "Waiting"
	local clock, setClock = React.useBinding(0)
	local spinClock = React.useRef(0)
	local barPulse, setBarPulse = React.useBinding(0.35)
	React.useEffect(function()
		spinClock.current = 0
		setClock(0)
		if reducedMotion then
			setBarPulse(if teleporting then 1 elseif waiting then 0.55 else 0.4)
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function(dt)
			spinClock.current += dt
			setClock(spinClock.current)
			local wave = (math.sin(spinClock.current * 2.1) + 1) * 0.5
			if teleporting then
				setBarPulse(0.72 + wave * 0.28)
			elseif waiting then
				setBarPulse(0.4 + wave * 0.35)
			else
				setBarPulse(0.28 + wave * 0.32)
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { phase, reducedMotion, setClock, teleporting, waiting })
	React.useEffect(function()
		Audio:setScene("shutdown")
		Audio:play(cueFor(phase))
		return function()
			return Audio:setScene("default")
		end
	end, { phase })
	local phaseAccent = if teleporting then Palette.mint elseif waiting then Palette.mango else Palette.cyan
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Active = true,
		Selectable = false,
		ZIndex = 900,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(112, 26),
		Position = UDim2.new(0.5, 0, 0.44, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 903,
	}, React.createElement(LoadingDots, {
		clock = clock,
		ready = teleporting,
		reducedMotion = reducedMotion,
		compact = false,
	})), React.createElement("textlabel", {
		Size = UDim2.new(0, 320, 0, 24),
		Position = UDim2.new(0.5, 0, 0.44, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "ASTRAL FORGE",
		TextColor3 = Palette.cream,
		TextTransparency = 0.08,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("textlabel", {
		Size = UDim2.new(0, 360, 0, 18),
		Position = UDim2.new(0.5, 0, 0.44, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = titleFor(phase),
		TextColor3 = Color3.fromRGB(190, 174, 178),
		TextTransparency = 0.18,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(220, 4),
		Position = UDim2.new(0.5, 0, 0.44, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(46, 36, 50),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 904,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = barPulse:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.08, 1), 0, 1, 0)
		end),
		BackgroundColor3 = phaseAccent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("textlabel", {
		Size = UDim2.new(0, 420, 0, 18),
		Position = UDim2.new(0.5, 0, 1, -52),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = statusFor(phase),
		TextColor3 = Color3.fromRGB(140, 122, 128),
		TextTransparency = 0.28,
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("textlabel", {
		Size = UDim2.new(0, 420, 0, 16),
		Position = UDim2.new(0.5, 0, 1, -32),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = state.message,
		TextColor3 = Color3.fromRGB(108, 92, 100),
		TextTransparency = 0.4,
		TextSize = 10,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 904,
	}))
end
return {
	SoftShutdownScreen = SoftShutdownScreen,
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		-- The boot loader reads the member list to warm every member up front.
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
