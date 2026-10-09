--!nocheck
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local P = require(script.Parent.CoreKit)("theme").Palette
local h = React.createElement

local function piece(parent, name, position, size, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = position
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end

local function line(parent, a, b, thickness, color)
	local part = piece(parent, "Stroke", (a + b) / 2, Vector3.new(thickness, thickness, (b - a).Magnitude), color)
	part.CFrame = CFrame.lookAt((a + b) / 2, b, Vector3.zAxis)
	part.Material = Enum.Material.Metal
	return part
end

local function glyphModel(parent, value, color)
	local model = Instance.new("Model")
	local function dot(position, size)
		return piece(model, "Core", position, Vector3.one * size, color, Enum.PartType.Ball)
	end
	local function arc(radius, startAngle, endAngle, count, squash)
		local previous = Vector3.new(math.cos(startAngle) * radius, math.sin(startAngle) * radius * squash, 0)
		for index = 1, count do
			local angle = startAngle + (endAngle - startAngle) * index / count
			local nextPoint = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * squash, 0)
			line(model, previous, nextPoint, 0.14, color)
			previous = nextPoint
		end
	end
	if value == 1 then
		dot(Vector3.zero, 0.85)
		for index = 0, 7 do
			local direction = Vector3.new(math.cos(index * math.pi / 4), math.sin(index * math.pi / 4), 0)
			line(model, direction * 0.72, direction * 1.05, 0.12, color)
		end
	elseif value == 2 then
		arc(0.85, math.pi / 3, math.pi * 5 / 3, 10, 1)
	elseif value == 3 then
		dot(Vector3.new(0.5, 0.25, 0), 0.65)
		for index = 0, 2 do
			line(model, Vector3.new(-0.85, -0.5 + index * 0.2, 0), Vector3.new(0.3, 0.15 + index * 0.12, 0), 0.12 - index * 0.02, color)
		end
	elseif value == 4 then
		arc(0.85, 0, math.pi * 2, 12, 1)
		dot(Vector3.zero, 0.23)
	elseif value == 5 then
		line(model, Vector3.new(-0.65, -0.65, 0), Vector3.new(0.65, 0.65, 0), 0.24, color)
		line(model, Vector3.new(-0.65, 0.65, 0), Vector3.new(0.65, -0.65, 0), 0.24, color)
	elseif value == 6 then
		arc(0.95, 0, math.pi * 2, 12, 0.5)
		dot(Vector3.zero, 0.45)
	else
		arc(0.75, 0, math.pi * 2, 12, 1)
	end
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	return model
end

local function SkyViewport(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		local viewport = ref.current
		if not viewport then return end
		local world = Instance.new("WorldModel")
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 38
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local scene = Instance.new("Model")
		scene.Name = if props.entry then "Constellation" else "CipherReceiver"
		scene.Parent = world
		local movers = {}
		local width, height = 14, 14
		if props.entry then
			local points = {}
			for index, star in props.entry.Stars do
				local position = Vector3.new((star[1] - 0.5) * 12, (0.5 - star[2]) * 12, 0)
				points[index] = position
				local lit = index <= props.plotted
				local nextStar = index == props.plotted + 1
				local starPart = piece(scene, "Star" .. index, position, Vector3.one * (if lit then 0.24 elseif nextStar then 0.22 else 0.14), if lit or nextStar then props.accent else P.muted, Enum.PartType.Ball)
				starPart.Material = if lit or nextStar then Enum.Material.Neon else Enum.Material.SmoothPlastic
				if nextStar then
					table.insert(movers, { part = starPart, nextStar = true })
				end
			end
			for _, edge in props.entry.Edges do
				local a, b = points[edge[1]], points[edge[2]]
				if a and b then
					local lit = edge[1] <= props.plotted and edge[2] <= props.plotted
					local link = line(scene, a, b, 0.035, if lit then props.accent else P.lineSoft)
					link.Transparency = if lit then 0.12 else 0.48
				end
			end
			local random = Random.new(#props.entry.Id * 977)
			for _ = 1, 32 do
				piece(scene, "DistantStar", Vector3.new(random:NextNumber(-7, 7), random:NextNumber(-7, 7), -1.4), Vector3.one * 0.035, P.creamSoft, Enum.PartType.Ball)
			end
		else
			width, height = 15, 5
			for index = 1, 4 do
				local value = props.glyphs[index]
				local color = if value then props.colors[value] or props.accent else P.lineSoft
				local position = Vector3.new((index - 2.5) * 3.2, 0, 0)
				local model = glyphModel(scene, value, color)
				model.Name = "Signal" .. index
				model:PivotTo(CFrame.new(position))
				table.insert(movers, { model = model, base = CFrame.new(position), phase = index * 0.8 })
				piece(scene, "Socket" .. index, position + Vector3.new(0, -1.6, 0), Vector3.new(2.3, 0.16, 2.3), P.graphite)
				local rim = piece(scene, "SignalLight" .. index, position + Vector3.new(0, -1.48, 0), Vector3.new(1.8, 0.05, 1.8), color)
				rim.Material = Enum.Material.Neon
			end
		end
		scene.WorldPivot = CFrame.identity
		local function fit()
			local aspect = math.max(viewport.AbsoluteSize.X, 1) / math.max(viewport.AbsoluteSize.Y, 1)
			local distance = math.max(height, width / math.max(aspect, 0.1)) * 0.55 / math.tan(math.rad(camera.FieldOfView / 2)) + 2
			camera.CFrame = CFrame.lookAt(Vector3.new(0, if props.entry then 0 else 2, distance), Vector3.zero)
		end
		fit()
		local resize = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		local time = 0
		local animation
		if not props.reducedMotion then
			animation = RunService.RenderStepped:Connect(function(dt)
				time += math.min(dt, 0.1)
				for _, item in movers do
					if item.nextStar then
						item.part.Size = Vector3.one * (0.22 + 0.03 * math.sin(time * 2.8))
					else
						item.model:PivotTo(item.base * CFrame.new(0, math.sin(time * 1.4 + item.phase) * 0.12, 0) * CFrame.Angles(0.12, math.sin(time * 0.45 + item.phase) * 0.5, 0.15))
					end
				end
				if props.entry then
					scene:PivotTo(CFrame.Angles(0, math.sin(time * 0.22) * 0.04, math.sin(time * 0.18) * 0.02))
				end
			end)
		end
		return function()
			if animation then animation:Disconnect() end
			resize:Disconnect()
			viewport.CurrentCamera = nil
			world:Destroy()
			camera:Destroy()
		end
	end, { props.entry, props.plotted, props.glyphs, props.colors, props.reducedMotion, props.accent })
	return h("viewportframe", {
		Name = if props.entry then "ConstellationViewport" else "CipherViewport",
		ref = ref,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundColor3 = P.ink,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(150, 165, 185),
		LightColor = Color3.fromRGB(215, 235, 255),
		LightDirection = Vector3.new(-1, -1, -2),
	}, {
		Corner = h("uicorner", { CornerRadius = UDim.new(0, 12) }),
	})
end

return SkyViewport
