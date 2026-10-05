--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local motion = require(script.Parent.MotionKit)("motion")
local P = require(script.Parent.CoreKit)("theme").Palette
local h = React.createElement
local function part(parent, size, color, at, shape, material)
	local value = Instance.new("Part")
	value.Anchored, value.CanCollide, value.CastShadow = true, false, false
	value.Size, value.Color, value.CFrame = size, color, at or CFrame.identity
	value.Shape = shape or Enum.PartType.Block
	value.Material = material or Enum.Material.SmoothPlastic
	value.Parent = parent
	return value
end
local function disc(parent, radius, depth, color, at)
	return part(
		parent,
		Vector3.new(depth, radius * 2, radius * 2),
		color,
		at * CFrame.Angles(0, 0, math.pi / 2),
		Enum.PartType.Cylinder,
		Enum.Material.Metal
	)
end
local function card(parent, rank, at)
	local value = part(parent, Vector3.new(1.3, 1.8, 0.08), P.cream, at)
	-- ViewportFrames cannot render SurfaceGui text; card ranks stay in the UI.
	local ink = if rank % 2 == 0 then P.pink else P.ink
	for i = 1, math.min(rank, 10) do
		local x = if rank == 1 then 0 else ((i - 1) % 2 - 0.5) * 0.5
		local y = if rank == 1 then 0 else 0.6 - math.floor((i - 1) / 2) * 0.3
		part(
			parent,
			Vector3.new(0.13, 0.13, 0.025),
			ink,
			at * CFrame.new(x, y, -0.055) * CFrame.Angles(0, 0, math.pi / 4)
		)
	end
	return value
end
local function build(world, props)
	local moving = {}
	if props.kind == "Jar" then
		table.insert(moving, { jarRig = require(script.Parent.DonationJarModel).build(world) })
	elseif props.kind == "Cards" then
		local ranks = props.cards or { props.rank or 1 }
		for i, rank in ranks do
			card(
				world,
				rank,
				CFrame.new((i - (#ranks + 1) / 2) * 0.22, (i - 1) * 0.24, -(i - 1) * 0.09)
					* CFrame.Angles(0, 0, (i - (#ranks + 1) / 2) * -0.08)
			)
		end
	elseif props.kind == "Dice" then
		local dots =
			{ { 0, 0 }, { -0.24, -0.24 }, { 0.24, 0.24 }, { -0.24, 0.24 }, { 0.24, -0.24 }, { -0.24, 0 }, { 0.24, 0 } }
		local faces = { { 1 }, { 2, 3 }, { 2, 1, 3 }, { 2, 3, 4, 5 }, { 2, 3, 4, 5, 1 }, { 2, 3, 4, 5, 6, 7 } }
		for i = 1, 2 do
			local model = Instance.new("Model")
			model.Parent = world
			part(model, Vector3.one * 0.9, P.cream, CFrame.identity)
			for _, face in
				{
					{ Enum.NormalId.Front, CFrame.new(0, 0, -0.46), props.dice and props.dice[i] or i + 2 },
					{ Enum.NormalId.Top, CFrame.new(0, 0.46, 0) * CFrame.Angles(math.pi / 2, 0, 0), 2 },
					{ Enum.NormalId.Right, CFrame.new(0.46, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 5 },
				}
			do
				for _, index in faces[face[3]] do
					local dot = dots[index]
					part(
						model,
						Vector3.new(0.105, 0.105, 0.025),
						P.ink,
						face[2] * CFrame.new(dot[1], dot[2], 0),
						Enum.PartType.Ball
					)
				end
			end
			model.WorldPivot = CFrame.identity
			table.insert(moving, { model = model, index = i })
		end
	else
		disc(world, 2.15, 0.22, P.steel, CFrame.new(0, -0.12, 0))
		disc(world, 1.95, 0.08, P.panelSoft, CFrame.new())
		for i = 0, 36 do
			local angle = i * math.tau / 37
			local color = if i == 0 then P.cyan elseif i % 2 == 0 then P.ink else P.pink
			part(
				world,
				Vector3.new(0.25, 0.05, 0.42),
				color,
				CFrame.new(math.sin(angle) * 1.64, 0.08, math.cos(angle) * 1.64) * CFrame.Angles(0, angle, 0)
			)
		end
		disc(world, 1.1, 0.08, P.steel, CFrame.new(0, 0.09, 0))
		disc(world, 0.8, 0.09, P.panelRaised, CFrame.new(0, 0.16, 0))
		part(
			world,
			Vector3.new(0.15, 0.45, 0.15),
			P.mango,
			CFrame.new(0, 0.39, 0),
			Enum.PartType.Ball,
			Enum.Material.Metal
		)
		local ball = part(world, Vector3.one * 0.16, P.cream, CFrame.new(0, 0.22, 1.64), Enum.PartType.Ball)
		table.insert(moving, { ball = ball })
	end
	return moving
end
return function(props)
	local host = React.useRef(nil)
	local soft = motion.useMotionSettings().soft == true
	React.useEffect(function()
		local viewport = host.current
		if not viewport then
			return
		end
		local world = Instance.new("WorldModel")
		world.Name, world.Parent = "CasinoScene", viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView, camera.Parent = 32, viewport
		local position = if props.kind == "Jar"
			then Vector3.new(3.4, 2.1, 7.2)
			elseif props.kind == "Cards" then Vector3.new(0, 0.5, -6)
			elseif props.kind == "Dice" then Vector3.new(3, 2.4, -6)
			else Vector3.new(0, 6.5, 5.5)
		camera.CFrame = CFrame.lookAt(position, if props.kind == "Jar" then Vector3.new(0, 0.4, 0) else Vector3.zero)
		viewport.CurrentCamera = camera
		local moving = build(world, props)
		local started = os.clock()
		local function update(t)
			for _, item in moving do
				if item.jarRig then
					item.jarRig.update(t)
				elseif item.ball then
					local angle = (props.number or 0) * math.tau / 37 + (1 - t) ^ 3 * math.tau * 5
					item.ball.CFrame = CFrame.new(math.sin(angle) * 1.64, 0.22, math.cos(angle) * 1.64)
				elseif item.model then
					item.model:PivotTo(
						CFrame.new((item.index - 1.5) * 1.4, math.sin(t * math.pi) * 0.5, 0)
							* CFrame.Angles((1 - t) * math.tau * 2, (1 - t) * math.tau, 0)
					)
				else
					local a = math.clamp(t * 2.6 - (item.index - 1) * 0.08, 0, 1)
					item.coin.Transparency = if a > 0 and a < 1 then 0 else 1
					item.coin.CFrame = CFrame.new(math.sin(a * math.pi) * 0.45, 3.5 - a * a * 4.5, 0)
						* CFrame.Angles(a * math.tau * 2, 0, math.pi / 2)
				end
			end
		end
		update(1)
		local connection
		if props.token ~= nil and not soft then
			connection = RunService.RenderStepped:Connect(function()
				local t = math.min(1, (os.clock() - started) / (if props.kind == "Jar" then 2.7 else 0.85))
				update(t)
				if t == 1 then
					connection:Disconnect()
				end
			end)
		end
		return function()
			if connection then
				connection:Disconnect()
			end
			viewport.CurrentCamera = nil
			world:Destroy()
			camera:Destroy()
		end
	end, { props.kind, props.token, props.rank, props.cards, props.number, props.dice, soft })
	return h("viewportframe", {
		Name = "CasinoViewport" .. (props.kind or "Roulette"),
		ref = host,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Ambient = Color3.fromRGB(155, 170, 195),
		LightColor = Color3.fromRGB(255, 246, 225),
		LightDirection = Vector3.new(-0.5, -1, -0.6),
		ZIndex = props.zIndex or 2,
	})
end
