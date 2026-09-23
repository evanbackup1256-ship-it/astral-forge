local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.audio).Audio
local LoadingDots = require(script.Parent.LoadingDots).LoadingDots
local Palette = require(script.Parent.theme).Palette
local BOOT_MODULE_TIMEOUT = 9
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
local LOADING_TIPS = { "Tap machines to overcharge them for bonus flux.", "Research is permanent — it survives rebirths.", "Complete daily lab orders for stardust rewards.", "Build your guild hall and recruit forgemasters.", "Check the Star Grid for permanent passive boosts.", "Stabilize anomalies to charge the reactor faster.", "Trade with other players to complete your collection.", "Activate boosts before a long session for max gains.", "Rebirth at the right moment to multiply your output.", "Equip relics to specialize your forge style.", "Claim mail rewards daily for free resources.", "Unlock new worlds to access rare machines.", "Join a guild goal — everyone's contribution counts.", "Weekly directives reset every Monday with fresh rewards.", "Spin the wheel daily — pity guarantees a rare eventually.", "Command XP unlocks crew upgrades and expedition slots.", "Forge echoes stack traits — chase a matching affinity set.", "Convergence events reward a shared production boost.", "Auto-forge keeps your best machine buying while you're away.", "Milestones track lifetime stats — they never reset.", "Season tiers bank XP even before you claim a reward.", "Salvage unwanted relics for essence to reroll better ones.", "Signal shop offers rotate daily — check back often.", "Streak shields protect your daily login streak once." }
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
local function progressFor(marks, assetsLoaded, assetsTotal)
	local complete = 0
	for _, key in SYSTEMS do
		if marks[key] then
			complete += 1
		end
	end
	local partial = 0
	if not marks.assets and assetsTotal ~= nil and assetsTotal > 0 and assetsLoaded ~= nil then
		partial = math.clamp(assetsLoaded / assetsTotal, 0, 1) * 0.8
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
local function bootProgress(marks, assetsLoaded, assetsTotal)
	return progressFor(marks, assetsLoaded, assetsTotal)
end
local function BootScreen(_param)
	local marks = _param.marks
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local startedAt = _param.startedAt
	local assetsLoaded = _param.assetsLoaded
	local assetsTotal = _param.assetsTotal
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
		local current = tipIndex
		local token = task.delay(2.8, function()
			return setTipIndex((current + 1) % #LOADING_TIPS)
		end)
		return function()
			return task.cancel(token)
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
			return task.cancel(token)
		end
	end, { ready })
	React.useEffect(function()
		if ready and not exiting and not finished.current then
			finished.current = true
			exitClock.current = 0
			setExiting(true)
			Audio:play("bootReady")
		elseif not exiting and not finished.current then
			local timeout = if RunService:IsStudio() then 8 else 20
			local token = task.delay(timeout, function()
				if not finished.current then
					finished.current = true
					exitClock.current = 0
					setExiting(true)
				end
			end)
			return function()
				task.cancel(token)
			end
		end
	end, { exiting, ready })
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			if not exiting then
				spinClock.current += dt
				setClock(spinClock.current)
			end
			if not exiting then
				return nil
			end
			exitClock.current += dt
			local elapsed = exitClock.current
			setSpinFade(clamp01(elapsed / EXIT_SPIN_SECONDS))
			setVeilFade(clamp01((elapsed - EXIT_SPIN_SECONDS) / EXIT_VEIL_SECONDS))
		end)
		return function()
			return connection:Disconnect()
		end
	end, { exiting, reducedMotion, setClock, setSpinFade, setVeilFade })
	React.useEffect(function()
		if not exiting then
			return nil
		end
		local token = task.delay(EXIT_SPIN_SECONDS + EXIT_VEIL_SECONDS + 0.05, function()
			setGone(true)
			onExitDone()
		end)
		return function()
			return task.cancel(token)
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
	local spinHide = spinFade:map(function(amount)
		return amount
	end)
	local veilHide = veilFade:map(function(amount)
		return amount
	end)
	local _condition_1 = LOADING_TIPS[tipIndex + 1]
	if _condition_1 == nil then
		_condition_1 = ""
	end
	local tipText = _condition_1
	-- Only worth showing once the preloader has reported a real total — before that
	-- the counter would just read "0 / 0" while other boot phases (bridge/state/fonts)
	-- are still running and assetsTotal hasn't been measured yet.
	local _result
	if not ready and assetsTotal ~= nil and assetsTotal > 0 then
		local _condition_2 = assetsLoaded
		if _condition_2 == nil then
			_condition_2 = 0
		end
		_result = `{math.min(_condition_2, assetsTotal)} / {assetsTotal} assets`
	else
		_result = ""
	end
	local assetCountText = _result
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = veilHide,
		BorderSizePixel = 0,
		Active = not exiting and not gone,
		ClipsDescendants = true,
		ZIndex = 420,
		Visible = veilFade:map(function(amount)
			return amount < 0.995
		end),
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(112, 26),
		Position = UDim2.new(0.5, 0, 0.44, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Visible = spinFade:map(function(amount)
			return amount < 0.98
		end),
	}, React.createElement(LoadingDots, {
		clock = clock,
		leaving = spinHide,
		ready = ready,
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
		TextTransparency = spinHide:map(function(amount)
			return 0.08 + amount
		end),
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Visible = spinFade:map(function(amount)
			return amount < 0.98
		end),
	}), React.createElement("textlabel", {
		Size = UDim2.new(0, 320, 0, 18),
		Position = UDim2.new(0.5, 0, 0.44, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = status,
		TextColor3 = Color3.fromRGB(170, 176, 186),
		TextTransparency = spinHide:map(function(amount)
			return 0.18 + amount
		end),
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Visible = spinFade:map(function(amount)
			return amount < 0.98
		end),
	}), React.createElement("textlabel", {
		Size = UDim2.new(0, 420, 0, 16),
		Position = UDim2.new(0.5, 0, 1, -52),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = if stalled then "Taking longer than expected..." else tipText,
		TextColor3 = if stalled then Palette.mango else Color3.fromRGB(120, 124, 132),
		TextTransparency = spinHide:map(function(amount)
			return 0.28 + amount
		end),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Visible = spinFade:map(function(amount)
			return amount < 0.98
		end),
	}), React.createElement("textlabel", {
		Size = UDim2.new(0, 320, 0, 14),
		Position = UDim2.new(0.5, 0, 1, -32),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = assetCountText,
		TextColor3 = Color3.fromRGB(90, 94, 102),
		TextTransparency = spinHide:map(function(amount)
			return 0.4 + amount
		end),
		TextSize = 10,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Visible = spinFade:map(function(amount)
			return amount < 0.98
		end),
	}))
end
return {
	bootChecklistReady = bootChecklistReady,
	bootProgress = bootProgress,
	BootScreen = BootScreen,
	BOOT_MODULE_TIMEOUT = BOOT_MODULE_TIMEOUT,
	BOOT_MOTION = BOOT_MOTION,
}
