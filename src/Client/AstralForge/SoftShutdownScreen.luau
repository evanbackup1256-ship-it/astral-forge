local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.audio).Audio
local LoadingDots = require(script.Parent.LoadingDots).LoadingDots
local Palette = require(script.Parent.theme).Palette
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
		TextColor3 = Color3.fromRGB(170, 176, 186),
		TextTransparency = 0.18,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(220, 4),
		Position = UDim2.new(0.5, 0, 0.44, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(36, 40, 48),
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
		TextColor3 = Color3.fromRGB(120, 124, 132),
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
		TextColor3 = Color3.fromRGB(90, 94, 102),
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
