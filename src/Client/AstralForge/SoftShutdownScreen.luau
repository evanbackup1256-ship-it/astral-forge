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
		return "Your save is stored. Hopping you over now."
	end
	if phase == "Waiting" then
		return "Stay here. We'll move you when the new server is up."
	end
	return "Don't leave yet — we're writing your save."
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
	local clock, setClock = React.useBinding(0)
	local spinClock = React.useRef(0)
	React.useEffect(function()
		spinClock.current = 0
		setClock(0)
		if reducedMotion then
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function(dt)
			spinClock.current += dt
			setClock(spinClock.current)
		end)
		return function()
			return connection:Disconnect()
		end
	end, { phase, reducedMotion, setClock })
	React.useEffect(function()
		Audio:setScene("boot")
		Audio:play(cueFor(phase))
		return function()
			return Audio:setScene("default")
		end
	end, { phase })
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
	}), React.createElement("textlabel", {
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
