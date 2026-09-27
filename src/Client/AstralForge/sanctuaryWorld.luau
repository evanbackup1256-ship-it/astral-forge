--!strict
-- The sanctuary, as the client sees it.
--
--   * Scenery tagged AF_Spin / AF_Bob / AF_Pulse is animated here in one
--     batched update (BulkMoveTo), only near the camera.
--   * Ore outcrops are drawn per player: a node you mined sinks and dims, then
--     grows back when its regrow time passes. Holding the mining prompt makes
--     its crystals tremble.
--   * The Rift Warden's body is built and animated entirely on the client from
--     the server's anchor (phase, health, timing attributes): it forms out of
--     the rift, reacts to hits, winds up and slams, shatters when defeated and
--     folds away if it escapes.
--   * Slam telegraphs, shockwaves and staggers.
--   * Which region the player stands in, and waystone use.
--
-- Nothing here is authoritative: the server decides every outcome. All client
-- parts are CanQuery = false so the camera's collision probe ignores them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.audio).Audio
local Signals = require(script.Parent.sanctuarySignals)
local Controls = require(script.Parent.sanctuaryControls)
local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("SanctuaryLayout"))
local SanctuaryConfig = require(Shared:WaitForChild("SanctuaryConfig"))

local World = {}

local TAU = math.pi * 2
local ANIMATE_RANGE = 420
local ORIGIN = Vector3.new(Layout.ORIGIN.X, Layout.ORIGIN.Y, Layout.ORIGIN.Z)
local RIFT = Color3.fromRGB(128, 92, 255)
local RIFT_HOT = Color3.fromRGB(214, 196, 255)
local SLAM = Color3.fromRGB(255, 84, 120)
local DEPLETED = 0.26

type AnimEntry = {
	base: CFrame,
	spin: number,
	amplitude: number,
	period: number,
	phase: number,
	pulse: number?,
	light: PointLight?,
	lightBase: number,
	transparencyBase: number,
}

type Crystal = { part: BasePart, restCFrame: CFrame, restSize: Vector3, restTransparency: number }

type NodeEntry = {
	id: string,
	ore: string,
	crystals: { Crystal },
	light: PointLight?,
	lightBase: number,
	sparkle: ParticleEmitter?,
	prompt: ProximityPrompt?,
	fill: number,
	ready: boolean,
	trembling: boolean,
}

local active = false
local connections: { RBXScriptConnection } = {}
local unsubscribers: { () -> () } = {}
local animated: { [BasePart]: AnimEntry } = {}
local nodes: { [Model]: NodeEntry } = {}
local readyAt: { [string]: number } = {}
local clientFolder: Folder? = nil
local currentRegion: string? = nil
local regionClock = 0

local function track(connection: RBXScriptConnection)
	table.insert(connections, connection)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function oreColor(oreId: string): (Color3, Color3)
	for _, ore in SanctuaryConfig.Ore.Types do
		if ore.Id == oreId then
			return rgb(ore.Color), rgb(ore.Glow)
		end
	end
	return Color3.new(1, 1, 1), Color3.new(1, 1, 1)
end

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- A client-only part: never collides, never blocks the camera probe.
local function vfxPart(name: string, shape: Enum.PartType?, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape ~= nil then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = clientFolder
	return p
end

------------------------------------------------------------------------
-- Scenery animation
------------------------------------------------------------------------

local function entryFor(part: BasePart): AnimEntry
	local entry = animated[part]
	if entry == nil then
		local light = part:FindFirstChildOfClass("PointLight")
		entry = {
			base = part.CFrame,
			spin = 0,
			amplitude = 0,
			period = 4,
			phase = (part.Position.X * 0.37 + part.Position.Z * 0.21) % 10,
			pulse = nil,
			light = light,
			lightBase = if light ~= nil then light.Brightness else 0,
			transparencyBase = part.Transparency,
		}
		animated[part] = entry
	end
	return entry :: AnimEntry
end

local function registerTagged(tag: string, instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local entry = entryFor(instance)
	if tag == "AF_Spin" then
		entry.spin = tonumber(instance:GetAttribute("Speed")) or 30
	elseif tag == "AF_Bob" then
		entry.amplitude = tonumber(instance:GetAttribute("Amplitude")) or 1
		entry.period = math.max(0.5, tonumber(instance:GetAttribute("Period")) or 4)
	elseif tag == "AF_Pulse" then
		entry.pulse = math.max(0.5, tonumber(instance:GetAttribute("Period")) or 3)
	end
end

local function restoreAnimated()
	for part, entry in animated do
		if part.Parent ~= nil then
			part.CFrame = entry.base
			part.Transparency = entry.transparencyBase
			if entry.light ~= nil then
				entry.light.Brightness = entry.lightBase
			end
		end
	end
	table.clear(animated)
end

local function stepScenery(t: number, cameraPosition: Vector3)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for part, entry in animated do
		if part.Parent == nil then
			animated[part] = nil
			continue
		end
		if (entry.base.Position - cameraPosition).Magnitude > ANIMATE_RANGE then
			continue
		end
		if entry.spin ~= 0 or entry.amplitude ~= 0 then
			local frame = entry.base
			if entry.amplitude ~= 0 then
				frame += Vector3.new(0, math.sin((t + entry.phase) * TAU / entry.period) * entry.amplitude, 0)
			end
			if entry.spin ~= 0 then
				frame *= CFrame.Angles(0, math.rad(entry.spin * t) % TAU, 0)
			end
			table.insert(parts, part)
			table.insert(frames, frame)
		end
		local pulse = entry.pulse
		if pulse ~= nil then
			local wave = 0.5 + 0.5 * math.sin((t + entry.phase) * TAU / pulse)
			if entry.light ~= nil then
				entry.light.Brightness = entry.lightBase * (0.7 + 0.3 * wave)
			end
			part.Transparency = math.clamp(entry.transparencyBase + 0.14 * (1 - wave), 0, 1)
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

------------------------------------------------------------------------
-- Ore outcrops
------------------------------------------------------------------------

local function registerNode(model: Instance)
	if not model:IsA("Model") or nodes[model] ~= nil then
		return
	end
	local id = model:GetAttribute("NodeId")
	local ore = model:GetAttribute("Ore")
	if type(id) ~= "string" or type(ore) ~= "string" then
		return
	end
	local crystals: { Crystal } = {}
	local light: PointLight? = nil
	local sparkle: ParticleEmitter? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Crystal" or child.Name == "Core") then
			local rest = child:GetAttribute("RestSize")
			table.insert(crystals, {
				part = child,
				restCFrame = child.CFrame,
				restSize = if typeof(rest) == "Vector3" then rest else child.Size,
				restTransparency = child.Transparency,
			})
			light = light or child:FindFirstChild("Glow") :: PointLight?
			sparkle = sparkle or child:FindFirstChild("Sparkle") :: ParticleEmitter?
		end
	end
	local seat = model:FindFirstChild("Seat")
	local prompt = seat and seat:FindFirstChild("MinePrompt")
	nodes[model] = {
		id = id,
		ore = ore,
		crystals = crystals,
		light = light,
		lightBase = if light ~= nil then light.Brightness else 0,
		sparkle = sparkle,
		prompt = if prompt ~= nil and prompt:IsA("ProximityPrompt") then prompt else nil,
		fill = 1,
		ready = true,
		trembling = false,
	}
end

local function applyFill(entry: NodeEntry, t: number)
	local scale = DEPLETED + (1 - DEPLETED) * entry.fill
	local tremble = if entry.trembling then math.sin(t * 60) * 0.05 else 0
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, crystal in entry.crystals do
		local size = crystal.restSize * scale
		local foot = crystal.restCFrame * CFrame.new(0, -crystal.restSize.Y / 2, 0)
		crystal.part.Size = size
		table.insert(parts, crystal.part)
		table.insert(frames, foot * CFrame.new(tremble, size.Y / 2, 0))
		crystal.part.Transparency = math.clamp(crystal.restTransparency + (1 - entry.fill) * 0.45, 0, 1)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if entry.light ~= nil then
		entry.light.Brightness = entry.lightBase * entry.fill
	end
	if entry.sparkle ~= nil then
		entry.sparkle.Enabled = entry.fill > 0.9
	end
end

local function stepNodes(dt: number, t: number)
	local now = serverNow()
	for model, entry in nodes do
		if model.Parent == nil then
			nodes[model] = nil
			continue
		end
		local ready = (readyAt[entry.id] or 0) <= now
		if ready ~= entry.ready then
			entry.ready = ready
			if entry.prompt ~= nil then
				entry.prompt.Enabled = ready
			end
		end
		local target = if ready then 1 else 0
		if entry.fill ~= target or entry.trembling then
			-- Sinks quickly when mined, grows back gently.
			local rate = if target > entry.fill then 1.4 else 5
			if target > entry.fill then
				entry.fill = math.min(target, entry.fill + rate * dt)
			else
				entry.fill = math.max(target, entry.fill - rate * dt)
			end
			applyFill(entry, t)
		end
	end
end

local function nodeById(id: string): (Model?, NodeEntry?)
	for model, entry in nodes do
		if entry.id == id then
			return model, entry
		end
	end
	return nil, nil
end

-- Floating "+4 Emberite" over a node, rising and fading.
local function floatText(at: Vector3, text: string, color: Color3)
	local anchor = vfxPart("FloatAnchor", nil, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(at)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(180, 40)
	board.StudsOffset = Vector3.new(0, 0, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	label.Parent = board
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / 1.3, 0, 1)
		board.StudsOffset = Vector3.new(0, 1 + k * 3.5, 0)
		label.TextTransparency = k * k
		label.TextStrokeTransparency = 0.4 + 0.6 * k * k
		if k >= 1 and connection ~= nil then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
end

local function burst(at: Vector3, color: Color3, count: number, speed: number)
	local holder = vfxPart("Burst", nil, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(at)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Range = 16
	flash.Brightness = 4
	flash.Parent = holder
	task.delay(0.12, function()
		flash.Brightness = 1.5
	end)
	task.delay(0.3, function()
		flash.Enabled = false
	end)
	task.delay(1.4, function()
		holder:Destroy()
	end)
end

local function onOreMined(payload)
	if type(payload) ~= "table" or type(payload.NodeId) ~= "string" then
		return
	end
	if type(payload.ReadyAt) == "number" then
		readyAt[payload.NodeId] = payload.ReadyAt
	end
	local model = nodeById(payload.NodeId)
	local color, glowColor = oreColor(tostring(payload.Ore))
	Audio:play("oreMine")
	task.delay(0.14, function()
		Audio:play("oreCollect")
	end)
	if model ~= nil and model.PrimaryPart ~= nil then
		local at = model.PrimaryPart.Position + Vector3.new(0, 3, 0)
		burst(at, glowColor, 26, 16)
		floatText(at + Vector3.new(0, 2, 0), `+{tonumber(payload.Amount) or 0} {tostring(payload.Ore)}`, color:Lerp(Color3.new(1, 1, 1), 0.35))
	end
end

local function onOreCooldowns(payload)
	if type(payload) ~= "table" or type(payload.Nodes) ~= "table" then
		return
	end
	for id, at in payload.Nodes do
		if type(id) == "string" and type(at) == "number" then
			readyAt[id] = at
		end
	end
end

------------------------------------------------------------------------
-- The Rift Warden
------------------------------------------------------------------------

type Piece = { part: BasePart, base: Vector3, spin: Vector3, velocity: Vector3?, tilt: CFrame, transparency: number }

type Boss = {
	anchor: BasePart,
	model: Model,
	core: Part,
	shell: Part,
	eye: Part,
	coreLight: PointLight,
	aura: ParticleEmitter,
	rings: { Piece },
	plates: { Piece },
	shards: { Piece },
	lastHealth: number,
	flash: number,
	lastPhase: string,
	outroStarted: number,
	slamLift: number,
	slamUntil: number,
	visible: number,
}

local boss: Boss? = nil

local function findWarden(): Model?
	local worldFolder = Workspace:FindFirstChild("AstralForgeWorld")
	local expanse = worldFolder and worldFolder:FindFirstChild("SanctuaryWorld")
	local model = expanse and expanse:FindFirstChild("RiftWarden")
	if model ~= nil and model:IsA("Model") and model.PrimaryPart ~= nil then
		return model
	end
	return nil
end

local function buildBoss(model: Model): Boss
	local anchor = model.PrimaryPart :: BasePart
	local core = vfxPart("WardenCore", Enum.PartType.Ball, Vector3.new(9, 9, 9), RIFT, Enum.Material.Neon)
	local shell = vfxPart("WardenShell", Enum.PartType.Ball, Vector3.new(11.5, 11.5, 11.5), RIFT_HOT, Enum.Material.Glass)
	shell.Transparency = 0.6
	local eye = vfxPart("WardenEye", Enum.PartType.Ball, Vector3.new(2.3, 2.3, 2.3), Color3.fromRGB(240, 250, 255), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = RIFT
	light.Range = 70
	light.Brightness = 3
	light.Shadows = false
	light.Parent = core
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(RIFT_HOT)
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.Lifetime = NumberRange.new(1.8, 3)
	aura.Rate = 22
	aura.Speed = NumberRange.new(2, 5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = core

	local rings: { Piece } = {}
	local ringSpecs = {
		{ diameter = 17, tilt = CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 40, 0) },
		{ diameter = 22, tilt = CFrame.Angles(math.rad(62), math.rad(30), 0), spin = Vector3.new(0, -28, 0) },
		{ diameter = 28, tilt = CFrame.Angles(math.rad(110), math.rad(-40), 0), spin = Vector3.new(0, 18, 0) },
	}
	for index, spec in ringSpecs do
		local ring = vfxPart(`WardenRing{index}`, Enum.PartType.Cylinder, Vector3.new(0.35, spec.diameter, spec.diameter), RIFT_HOT, Enum.Material.Neon)
		ring.Transparency = 0.5
		local piece: Piece = { part = ring, base = Vector3.zero, spin = spec.spin, velocity = nil, tilt = spec.tilt, transparency = 0.5 }
		table.insert(rings, piece)
	end

	local plates: { Piece } = {}
	for index = 1, 6 do
		local plate = vfxPart(`WardenPlate{index}`, nil, Vector3.new(5, 7, 1.2), Color3.fromRGB(34, 32, 46), Enum.Material.Basalt)
		plate.CastShadow = true
		local seam = vfxPart(`WardenSeam{index}`, nil, Vector3.new(0.4, 6, 0.4), RIFT, Enum.Material.Neon)
		seam.Parent = plate
		local piece: Piece = { part = plate, base = Vector3.zero, spin = Vector3.new(0, index, 0), velocity = nil, tilt = CFrame.identity, transparency = 0 }
		table.insert(plates, piece)
	end

	local shards: { Piece } = {}
	for index = 1, 8 do
		local shard = vfxPart(`WardenShard{index}`, nil, Vector3.new(1, 6.5, 1), RIFT_HOT, Enum.Material.Neon)
		shard.Transparency = 0.15
		local piece: Piece = { part = shard, base = Vector3.zero, spin = Vector3.new(0, index, 0), velocity = nil, tilt = CFrame.identity, transparency = 0.15 }
		table.insert(shards, piece)
	end

	return {
		anchor = anchor,
		model = model,
		core = core,
		shell = shell,
		eye = eye,
		coreLight = light,
		aura = aura,
		rings = rings,
		plates = plates,
		shards = shards,
		lastHealth = tonumber(model:GetAttribute("Health")) or 0,
		flash = 0,
		lastPhase = tostring(model:GetAttribute("Phase") or "Dormant"),
		outroStarted = 0,
		slamLift = 0,
		slamUntil = 0,
		visible = 0,
	}
end

local function destroyBoss()
	local current = boss
	boss = nil
	if current == nil then
		return
	end
	for _, part in { current.core, current.shell, current.eye } do
		part:Destroy()
	end
	for _, list in { current.rings, current.plates, current.shards } do
		for _, piece in list do
			piece.part:Destroy()
		end
	end
end

local function setBossTransparency(current: Boss, visible: number)
	local hide = 1 - math.clamp(visible, 0, 1)
	current.core.Transparency = hide
	current.shell.Transparency = 0.6 + 0.4 * hide
	current.eye.Transparency = hide
	current.coreLight.Enabled = visible > 0.02
	current.aura.Enabled = visible > 0.2
	for _, list in { current.rings, current.plates, current.shards } do
		for _, piece in list do
			piece.part.Transparency = piece.transparency + (1 - piece.transparency) * hide
			for _, child in piece.part:GetChildren() do
				if child:IsA("BasePart") then
					child.Transparency = hide
				end
			end
		end
	end
end

local function stepBoss(dt: number, t: number)
	if boss == nil then
		local model = findWarden()
		if model == nil then
			return
		end
		boss = buildBoss(model)
	end
	local current = boss :: Boss
	if current.model.Parent == nil then
		destroyBoss()
		return
	end
	local config = SanctuaryConfig.RiftBoss
	local phase = tostring(current.model:GetAttribute("Phase") or "Dormant")
	local endsAt = tonumber(current.model:GetAttribute("EndsAt")) or 0
	local health = tonumber(current.model:GetAttribute("Health")) or 0
	local now = serverNow()

	-- Phase changes: sounds and one-off moments.
	if phase ~= current.lastPhase then
		if phase == "Forming" then
			Audio:play("wardenForming")
		elseif phase == "Active" then
			Audio:play("wardenAwake")
			Controls.shake(0.5)
		elseif phase == "Defeated" then
			Audio:play("wardenDefeat")
			current.outroStarted = t
			for _, list in { current.rings, current.plates, current.shards } do
				for _, piece in list do
					local away = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
					piece.velocity = (if away.Magnitude > 0.05 then away.Unit else Vector3.yAxis) * (24 + math.random() * 30)
				end
			end
			local root = localRoot()
			if root ~= nil and (root.Position - current.anchor.Position).Magnitude < 160 then
				Controls.shake(1)
			end
		elseif phase == "Escaped" then
			Audio:play("wardenEscape")
			current.outroStarted = t
		elseif phase == "Dormant" then
			for _, list in { current.rings, current.plates, current.shards } do
				for _, piece in list do
					piece.velocity = nil
				end
			end
		end
		current.lastPhase = phase
	end

	-- Hit reaction: a flash whenever health drops.
	if health < current.lastHealth - 0.01 then
		current.flash = 1
	end
	current.lastHealth = health
	current.flash = math.max(0, current.flash - dt * 5)

	-- How present the Warden is.
	local visible = 0
	if phase == "Forming" then
		visible = math.clamp(1 - (endsAt - now) / config.FormingSeconds, 0, 1)
	elseif phase == "Active" then
		visible = 1
	elseif phase == "Defeated" or phase == "Escaped" then
		visible = math.clamp(1 - (t - current.outroStarted) / 2.2, 0, 1)
	end
	current.visible += (visible - current.visible) * (1 - math.exp(-8 * dt))
	if current.visible < 0.005 and visible == 0 then
		setBossTransparency(current, 0)
		return
	end
	setBossTransparency(current, current.visible)

	-- Slam wind-up lifts the Warden; the landing drops it.
	local lift = 0
	if current.slamUntil > now then
		local total = config.SlamTelegraphSeconds
		local k = math.clamp(1 - (current.slamUntil - now) / total, 0, 1)
		lift = math.sin(k * math.pi * 0.5) * 5
	end
	current.slamLift += (lift - current.slamLift) * (1 - math.exp(-12 * dt))

	local escaping = phase == "Escaped"
	local collapse = if escaping then math.clamp((t - current.outroStarted) / 1.4, 0, 1) else 0
	local hover = current.anchor.Position + Vector3.new(0, math.sin(t * 0.9) * 1.4 + current.slamLift, 0)
	local coreScale = 1 + current.flash * 0.12 + (if phase == "Defeated" then math.clamp((t - current.outroStarted) * 0.8, 0, 1.2) else 0)
	coreScale *= (1 - collapse * 0.95)
	current.core.Size = Vector3.new(9, 9, 9) * coreScale
	current.core.Color = RIFT:Lerp(Color3.new(1, 1, 1), current.flash * 0.7)
	current.shell.Size = Vector3.new(11.5, 11.5, 11.5) * coreScale
	current.coreLight.Brightness = 3 + current.flash * 6

	local parts: { BasePart } = { current.core, current.shell }
	local frames: { CFrame } = { CFrame.new(hover), CFrame.new(hover) }

	-- The eye turns toward the local player.
	local root = localRoot()
	local lookDir = if root ~= nil then (root.Position - hover) else Vector3.new(0, 0, 1)
	lookDir = if lookDir.Magnitude > 0.5 then lookDir.Unit else Vector3.new(0, 0, 1)
	table.insert(parts, current.eye)
	table.insert(frames, CFrame.new(hover + lookDir * 5.2 * coreScale))

	local outro = if phase == "Defeated" then t - current.outroStarted else 0
	local function place(piece: Piece, frame: CFrame)
		if piece.velocity ~= nil and outro > 0 then
			local drift = piece.velocity * outro + Vector3.new(0, -9 * outro * outro, 0)
			frame = CFrame.new(frame.Position + drift) * CFrame.Angles(outro * 3, outro * 2, 0) * frame.Rotation
		end
		if collapse > 0 then
			frame = CFrame.new(frame.Position:Lerp(hover, collapse)) * frame.Rotation
		end
		table.insert(parts, piece.part)
		table.insert(frames, frame)
		for _, child in piece.part:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
				table.insert(frames, frame * CFrame.new(0, 0, -0.5))
			end
		end
	end

	for _, ring in current.rings do
		local spin = CFrame.Angles(0, math.rad(ring.spin.Y * t) % TAU, 0)
		place(ring, CFrame.new(hover) * spin * ring.tilt)
	end
	for index, plate in current.plates do
		local angle = (index / #current.plates) * TAU + t * 0.35
		local jolt = current.flash * 0.9
		local radius = 9.5 + jolt + math.sin(t * 1.3 + index) * 0.4
		local position = hover + Vector3.new(math.cos(angle) * radius, math.sin(t * 1.1 + index * 0.8) * 1.2, math.sin(angle) * radius)
		place(plate, CFrame.lookAt(position, hover) * CFrame.Angles(0, math.pi, 0))
	end
	for index, shard in current.shards do
		local side = if index <= 4 then -1 else 1
		local k = ((index - 1) % 4) / 3
		local sway = math.sin(t * 1.6 + index) * 0.12
		local offset = Vector3.new(side * (8 + k * 5), 3 - k * 5, 4 + k * 2)
		local position = hover + offset
		place(shard, CFrame.new(position) * CFrame.Angles(0, 0, side * (0.5 + k * 0.4 + sway)))
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

------------------------------------------------------------------------
-- Slams
------------------------------------------------------------------------

local function ringAdornment(anchor: BasePart, radius: number, inner: number, color: Color3, transparency: number): CylinderHandleAdornment
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	ring.AlwaysOnTop = false
	ring.ZIndex = 1
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	ring.Height = 0.25
	ring.Radius = math.max(0.05, radius)
	ring.InnerRadius = math.clamp(inner, 0, math.max(0, radius - 0.05))
	ring.Color3 = color
	ring.Transparency = transparency
	ring.Parent = anchor
	return ring
end

local function worldPoint(p: any): Vector3
	return Vector3.new(tonumber(p and p.X) or 0, tonumber(p and p.Y) or 0, tonumber(p and p.Z) or 0)
end

local function onSlam(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.2, 0)
	local radius = tonumber(payload.Radius) or 24
	local detonateAt = tonumber(payload.DetonateAt) or (serverNow() + 1.5)
	if boss ~= nil then
		boss.slamUntil = detonateAt
	end
	Audio:play("wardenSlamCharge")
	local anchor = vfxPart("SlamAnchor", nil, Vector3.new(0.2, 0.2, 0.2), SLAM, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local fill = ringAdornment(anchor, 0.1, 0, SLAM, 0.85)
	local edge = ringAdornment(anchor, radius, radius - 0.9, SLAM, 0.35)
	local started = serverNow()
	local total = math.max(0.2, detonateAt - started)
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((serverNow() - started) / total, 0, 1)
		fill.Radius = math.max(0.1, radius * k)
		fill.Transparency = 0.85 - 0.3 * k
		edge.Transparency = 0.35 - 0.2 * math.abs(math.sin(k * math.pi * 6))
		if k >= 1 and connection ~= nil then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
end

local function onSlamLand(payload)
	if type(payload) ~= "table" then
		return
	end
	local center = worldPoint(payload.Center) + Vector3.new(0, 0.3, 0)
	local radius = tonumber(payload.Radius) or 24
	Audio:play("wardenSlam")
	burst(center + Vector3.new(0, 1, 0), RIFT_HOT, 40, 28)
	local anchor = vfxPart("ShockAnchor", nil, Vector3.new(0.2, 0.2, 0.2), SLAM, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(center)
	local wave = ringAdornment(anchor, radius, radius - 2, RIFT_HOT, 0.1)
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / 0.55, 0, 1)
		local r = radius * (1 + 0.8 * k)
		wave.Radius = r
		wave.InnerRadius = math.max(0, r - 2 - 3 * k)
		wave.Transparency = 0.1 + 0.9 * k
		if k >= 1 and connection ~= nil then
			connection:Disconnect()
			anchor:Destroy()
		end
	end)
	local root = localRoot()
	if root ~= nil then
		local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
		if distance < radius + 30 then
			Controls.shake(math.clamp(1.2 - distance / (radius + 30), 0.25, 1.1))
		end
	end
end

local function onStagger(payload)
	local center = worldPoint(type(payload) == "table" and payload.Center or nil)
	Controls.knockback(center, 58)
	Controls.shake(1.3)
end

------------------------------------------------------------------------
-- Regions and waystones
------------------------------------------------------------------------

local function stepRegion(dt: number)
	regionClock += dt
	if regionClock < 0.4 then
		return
	end
	regionClock = 0
	local root = localRoot()
	if root == nil then
		return
	end
	local here = root.Position - ORIGIN
	local region = Layout.regionAt({ X = here.X, Y = here.Y, Z = here.Z })
	local id = if region ~= nil then region.Id else "Bridge"
	if id ~= currentRegion then
		local first = currentRegion == nil
		currentRegion = id
		Signals.fire("RegionChanged", { Id = id, Name = if region ~= nil then region.Name else "Sky road" })
		if region ~= nil and not first then
			Audio:play("regionEnter")
		end
	end
end

-- After a waystone jump, hold the character still until the ground under
-- the destination has streamed in, so nobody falls through a region that is
-- still loading.
local function onArrived(payload)
	Audio:play("waystoneTravel")
	local root = localRoot()
	if root == nil then
		return
	end
	root.Anchored = true
	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local character = Players.LocalPlayer.Character
		params.FilterDescendantsInstances = if character ~= nil then { character } else {}
		local deadline = os.clock() + 2.5
		while os.clock() < deadline and root.Parent ~= nil do
			if Workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params) ~= nil then
				break
			end
			task.wait(0.05)
		end
		if root.Parent ~= nil then
			root.Anchored = false
		end
	end)
	Signals.fire("Arrived", payload)
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

function World.start()
	if active then
		return
	end
	active = true
	currentRegion = nil
	regionClock = 1
	local folder = Instance.new("Folder")
	folder.Name = "SanctuaryClientFx"
	folder.Parent = Workspace
	clientFolder = folder

	for _, tagName in { "AF_Spin", "AF_Bob", "AF_Pulse" } do
		for _, instance in CollectionService:GetTagged(tagName) do
			registerTagged(tagName, instance)
		end
		track(CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
			registerTagged(tagName, instance)
		end))
	end
	for _, model in CollectionService:GetTagged("AF_OreNode") do
		registerNode(model)
	end
	track(CollectionService:GetInstanceAddedSignal("AF_OreNode"):Connect(registerNode))

	track(ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "WaystonePrompt" then
			Signals.fire("WaystoneOpen", { From = prompt:GetAttribute("WaystoneId") })
		end
	end))
	track(ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "MinePrompt" then
			return
		end
		local _, entry = nodeById(tostring(prompt:GetAttribute("NodeId")))
		if entry ~= nil then
			entry.trembling = true
		end
	end))
	track(ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "MinePrompt" then
			return
		end
		local _, entry = nodeById(tostring(prompt:GetAttribute("NodeId")))
		if entry ~= nil then
			entry.trembling = false
		end
	end))

	table.insert(unsubscribers, Signals.on("OreMined", onOreMined))
	table.insert(unsubscribers, Signals.on("OreCooldowns", onOreCooldowns))
	table.insert(unsubscribers, Signals.on("RiftBossSlam", onSlam))
	table.insert(unsubscribers, Signals.on("RiftBossSlamLand", onSlamLand))
	table.insert(unsubscribers, Signals.on("RiftBossStagger", onStagger))
	table.insert(unsubscribers, Signals.on("WaystoneArrived", onArrived))

	track(RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera ~= nil then camera.CFrame.Position else ORIGIN
		stepScenery(t, cameraPosition)
		stepNodes(dt, t)
		local ok, problem = pcall(stepBoss :: (number, number) -> any, dt, t)
		if not ok then
			warn(`[sanctuary] warden visuals: {problem}`)
			destroyBoss()
		end
		stepRegion(dt)
	end))
end

function World.stop()
	if not active then
		return
	end
	active = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, unsubscribe in unsubscribers do
		unsubscribe()
	end
	table.clear(unsubscribers)
	destroyBoss()
	restoreAnimated()
	-- Put every outcrop back to full so nothing is left half-drawn. Outcrops
	-- that streamed out are gone already and come back fresh.
	for model, entry in nodes do
		if model.Parent == nil then
			continue
		end
		entry.fill = 1
		entry.trembling = false
		pcall(applyFill, entry, 0)
		if entry.prompt ~= nil then
			entry.prompt.Enabled = true
		end
	end
	table.clear(nodes)
	if clientFolder ~= nil then
		clientFolder:Destroy()
		clientFolder = nil
	end
	currentRegion = nil
end

function World.region(): string?
	return currentRegion
end

return World
