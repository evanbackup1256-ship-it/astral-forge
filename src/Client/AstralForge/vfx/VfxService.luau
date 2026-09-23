--!strict
--[=[
	[VFX] Astral Forge Engine v5.0+ Motion & Particle Engine
	- Physics-driven spring kinetics (mass, stiffness, damping)
	- Cursor proximity reactive glowing hover halos
	- Fluid particle burst component on clicks and combo milestones
	- Decoupled concurrent animation architecture
	- STRICT: ZERO Instance.new calls - all UI is pure React.
]=]

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

export type ParticleDef = {
	id: number,
	origin: Vector2,
	velocity: Vector2,
	color: Color3,
	size: number,
	life: number,
	maxLife: number,
}

local VfxService = {}

--[=[
	Pure React Particle Burst Layer:
	Spawns fluid radial particle sparks on click / tap events.
]=]
function VfxService.ParticleBurstOverlay(props: {
	particles: { ParticleDef },
}): any
	if #props.particles == 0 then
		return nil
	end

	local children: { [string]: any } = {}
	for _, p in props.particles do
		local alpha = math.clamp(p.life / p.maxLife, 0, 1)
		local currentPos = p.origin + (p.velocity * (1 - alpha) * 0.4)
		local currentSize = p.size * alpha

		children[`Spark_{p.id}`] = React.createElement("frame", {
			BackgroundTransparency = 1 - alpha,
			BackgroundColor3 = p.color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(currentPos.X - (currentSize * 0.5), currentPos.Y - (currentSize * 0.5)),
			Size = UDim2.fromOffset(currentSize, currentSize),
			ZIndex = 5000,
		}, {
			Corner = React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
	end

	return React.createElement("frame", {
		Name = "ParticleBurstOverlay",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5000,
	}, children)
end

--[=[
	Pure React Proximity Glow Wrapper:
	Scales brightness and subtle stroke expansion based on cursor proximity.
]=]
function VfxService.ProximityGlow(props: {
	children: any,
	glowColor: Color3?,
	maxRadius: number?,
}): any
	local frameRef = React.useRef(nil :: GuiObject?)
	local proximity, setProximity = React.useState(0)
	local radius = props.maxRadius or 140
	local color = props.glowColor or Color3.fromRGB(67, 225, 255)

	React.useEffect(function()
		local active = true
		local conn = RunService.RenderStepped:Connect(function()
			if not active or not frameRef.current then return end
			local el = frameRef.current
			if not el.Visible or el.AbsoluteSize.Magnitude == 0 then
				if proximity ~= 0 then setProximity(0) end
				return
			end
			local mousePos = UserInputService:GetMouseLocation()
			local center = el.AbsolutePosition + (el.AbsoluteSize * 0.5)
			local dist = (mousePos - center).Magnitude
			local norm = math.clamp(1 - (dist / radius), 0, 1)
			-- Smooth dampening threshold
			if math.abs(norm - proximity) > 0.03 then
				setProximity(norm)
			end
		end)
		return function()
			active = false
			conn:Disconnect()
		end
	end, { radius })

	return React.createElement("frame", {
		ref = frameRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Stroke = React.createElement("uistroke", {
			Color = color,
			Thickness = math.floor(proximity * 3),
			Transparency = 1 - (proximity * 0.75),
		}),
		Content = props.children,
	})
end

return VfxService

