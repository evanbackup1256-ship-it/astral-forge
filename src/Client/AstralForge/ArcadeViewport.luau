--!strict
-- Purpose: Build a distinct, disposable 3D preview for each score-only arcade game.
-- Owner: Astral Forge presentation. Dependencies: React, MotionKit, CoreKit palette. Last-reviewed: 2026-10-07.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactTypes = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts-js"].React)
local RunService = game:GetService("RunService")
local Motion = require(script.Parent.MotionKit)("motion")
local Palette: { [string]: Color3 } = require(script.Parent.CoreKit)("theme").Palette
local CreateElement = React.createElement
type Element = ReactTypes.ReactElement<{}, string>

type Props = {
	kind: string,
	size: UDim2?,
	position: UDim2?,
	zIndex: number?,
	animate: boolean?,
}

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	frame: CFrame,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.CFrame = frame
	part.Shape = shape or Enum.PartType.Block
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function slab(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	z: number,
	color: Color3,
	depth: number?
): Part
	return makePart(parent, name, Vector3.new(x, y, depth or 0.16), color, CFrame.new(0, 0, z))
end

local function sphere(
	parent: Instance,
	name: string,
	size: number,
	color: Color3,
	x: number,
	y: number,
	z: number
): Part
	return makePart(
		parent,
		name,
		Vector3.one * size,
		color,
		CFrame.new(x, y, z),
		Enum.PartType.Ball,
		Enum.Material.Neon
	)
end

local function disk(parent: Instance, name: string, radius: number, depth: number, color: Color3, z: number): Part
	return makePart(
		parent,
		name,
		Vector3.new(depth, radius * 2, radius * 2),
		color,
		CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
		Enum.PartType.Cylinder,
		Enum.Material.Metal
	)
end

local function addLine(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	local delta = to - from
	local frame = CFrame.lookAt((from + to) * 0.5, to) * CFrame.Angles(0, math.pi / 2, 0)
	return makePart(
		parent,
		name,
		Vector3.new(delta.Magnitude, width, width),
		color,
		frame,
		Enum.PartType.Cylinder,
		Enum.Material.Neon
	)
end

local function chipStack(parent: Instance, x: number, y: number, count: number, color: Color3): ()
	for index = 1, count do
		local chip = slab(parent, `Chip_{x}_{index}`, 0.42, 0.09, 0.34 + index * 0.035, color, 0.08)
		chip.CFrame = CFrame.new(x, y + index * 0.1, 0.34 + index * 0.035)
	end
	local topper = sphere(parent, `ChipCore_{x}`, 0.12, Palette.cream, x, y + count * 0.1 + 0.08, 0.5)
	topper.Material = Enum.Material.SmoothPlastic
end

local function card(parent: Instance, name: string, x: number, y: number, z: number, tint: Color3, angle: number?): Part
	local frame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, angle or 0)
	local value = makePart(parent, name, Vector3.new(0.64, 0.9, 0.055), Palette.cream, frame)
	makePart(
		parent,
		name .. "_Pip",
		Vector3.new(0.12, 0.12, 0.025),
		tint,
		frame * CFrame.new(-0.17, 0.26, -0.045) * CFrame.Angles(0, 0, math.pi / 4)
	)
	return value
end

local function dice(parent: Instance, name: string, x: number, y: number, color: Color3, seed: number): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local cube = makePart(model, "IvoryDie", Vector3.new(0.72, 0.72, 0.72), color, CFrame.new(x, y, 0.65))
	local pipCount = math.clamp(seed, 1, 6)
	local offsets = {
		Vector2.new(0, 0),
		Vector2.new(-0.19, -0.19),
		Vector2.new(0.19, 0.19),
		Vector2.new(-0.19, 0.19),
		Vector2.new(0.19, -0.19),
		Vector2.new(-0.19, 0),
		Vector2.new(0.19, 0),
	}
	local patterns = {
		{ 1 },
		{ 2, 3 },
		{ 2, 1, 3 },
		{ 2, 3, 4, 5 },
		{ 2, 3, 4, 5, 1 },
		{ 2, 3, 4, 5, 6, 7 },
	}
	for _, index in patterns[pipCount] do
		local offset = offsets[index]
		makePart(
			model,
			"Pip",
			Vector3.new(0.105, 0.105, 0.025),
			Palette.ink,
			CFrame.new(x + offset.X, y + offset.Y, 0.28),
			Enum.PartType.Ball
		)
	end
	model.PrimaryPart = cube
	return model
end

local function buildSlots(parent: Instance): { BasePart }
	slab(parent, "ReelCabinet", 5.5, 3.7, 0, Palette.panelRaised, 0.72)
	slab(parent, "CabinetFace", 4.85, 2.75, 0.43, Palette.ink, 0.28)
	slab(parent, "ReelWindow", 4.25, 1.35, 0.68, Palette.steel, 0.24)
	local reels = {}
	for index, x in { -1.35, 0, 1.35 } do
		local drum = makePart(
			parent,
			`Reel_{index}`,
			Vector3.new(0.88, 1.12, 0.88),
			Palette.cream,
			CFrame.new(x, 0.15, 0.84),
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
		for symbolIndex = 1, 3 do
			sphere(
				parent,
				`ReelSymbol_{index}_{symbolIndex}`,
				0.24,
				({ Palette.mango, Palette.cyan, Palette.pink })[symbolIndex],
				x,
				(symbolIndex - 2) * 0.38,
				1.31
			)
		end
		table.insert(reels, drum)
	end
	slab(parent, "Marquee", 3.2, 0.38, 0.65, Palette.mango, 0.22)
	slab(parent, "Pedestal", 2.1, 0.46, -0.42, Palette.steel, 0.95)
	local lever =
		addLine(parent, "LeverArm", Vector3.new(2.35, 0.45, 0.9), Vector3.new(2.75, 1.25, 0.9), 0.14, Palette.brass)
	sphere(parent, "LeverKnob", 0.34, Palette.coral, 2.78, 1.32, 0.9)
	return { reels[1], reels[2], reels[3], lever }
end

local function buildBlackjack(parent: Instance): { BasePart }
	disk(parent, "OvalTableBase", 3.2, 0.26, Palette.brass, -0.12)
	disk(parent, "FeltTable", 2.96, 0.14, Palette.mint, 0.08)
	slab(parent, "DealerRail", 4.9, 0.22, 0.36, Palette.brass, 0.24)
	for index = 1, 5 do
		card(
			parent,
			`DealerCard_{index}`,
			(index - 3) * 0.46,
			0.44 + (index % 2) * 0.08,
			0.5,
			Palette.coral,
			(index - 3) * 0.08
		)
	end
	card(parent, "ShoeTopCard", -2.15, 0.24, 0.6, Palette.cyan, -0.08)
	slab(parent, "CardShoe", 0.82, 0.48, 0.45, Palette.steel, 0.42).CFrame = CFrame.new(-2.2, -0.1, 0.45)
		* CFrame.Angles(0, 0, -0.2)
	chipStack(parent, -1.65, -0.72, 4, Palette.coral)
	chipStack(parent, 1.45, -0.72, 3, Palette.cyan)
	return {}
end

local function buildRoulette(parent: Instance): { BasePart }
	disk(parent, "RouletteHousing", 2.65, 0.32, Palette.steel, -0.12)
	disk(parent, "WheelTrack", 2.39, 0.1, Palette.brass, 0.08)
	disk(parent, "WheelFace", 2.12, 0.12, Palette.panelRaised, 0.18)
	local rotor = Instance.new("Model")
	rotor.Name = "NumberedSectorRotor"
	rotor.Parent = parent
	for index = 0, 36 do
		local angle = index / 37 * math.tau
		local hue = if index == 0 then Palette.mint elseif index % 2 == 0 then Palette.ink else Palette.coral
		local x, y = math.cos(angle) * 1.82, math.sin(angle) * 1.82
		local pocket = makePart(
			rotor,
			`Pocket_{index}`,
			Vector3.new(0.31, 0.42, 0.08),
			hue,
			CFrame.new(x, y, 0.31) * CFrame.Angles(0, 0, angle)
		)
		pocket.Material = Enum.Material.SmoothPlastic
	end
	disk(parent, "WheelHub", 0.68, 0.35, Palette.brass, 0.46)
	sphere(parent, "WheelHubGem", 0.45, Palette.coral, 0, 0, 0.68)
	local ball = sphere(parent, "RouletteBall", 0.18, Palette.cream, 1.95, 0, 0.56)
	return { rotor.PrimaryPart or rotor:GetChildren()[1] :: BasePart, ball }
end

local function buildQuantumRoulette(parent: Instance): { BasePart }
	disk(parent, "QuantumGravityChamber", 2.72, 0.34, Palette.violet, -0.16)
	disk(parent, "QuantumPhaseRing", 2.46, 0.11, Palette.cyan, 0.08)
	disk(parent, "QuantumBoard", 2.17, 0.13, Palette.panelRaised, 0.2)
	local rotor = Instance.new("Model")
	rotor.Name = "ShiftingSectorArray"
	rotor.Parent = parent
	for index = 1, 16 do
		local angle = (index - 1) / 16 * math.tau
		local row = math.floor((index - 1) / 4)
		local radius = if row % 2 == 0 then 1.64 else 1.18
		local width = if row % 2 == 0 then 0.52 else 0.38
		local color = ({ Palette.cyan, Palette.violet, Palette.pink, Palette.mango })[(index % 4) + 1]
		local sector = makePart(
			rotor,
			`PhaseZone_{index}`,
			Vector3.new(width, 0.3, 0.09),
			color,
			CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0.34)
				* CFrame.Angles(0, 0, angle + math.pi / 2),
			Enum.PartType.Block,
			Enum.Material.Neon
		)
		sector:SetAttribute("PhaseBand", row)
	end
	disk(parent, "GravitySinkRim", 0.82, 0.26, Palette.brass, 0.46)
	local sink = sphere(parent, "GravitySink", 0.7, Palette.ink, 0, 0, 0.72)
	sink.Material = Enum.Material.Neon
	for index = 1, 5 do
		local angle = index / 5 * math.tau
		local x, y = math.cos(angle) * 1.02, math.sin(angle) * 1.02
		addLine(
			parent,
			`GravityTether_{index}`,
			Vector3.new(x * 0.48, y * 0.48, 0.56),
			Vector3.new(x, y, 0.56),
			0.045,
			Palette.cyan
		)
		sphere(parent, `PhaseAnchor_{index}`, 0.15, Palette.cream, x, y, 0.62)
	end
	for index = 1, 8 do
		local angle = index / 8 * math.tau
		local shard = sphere(
			parent,
			`OrbitShard_{index}`,
			0.12,
			Palette.pink,
			math.cos(angle) * 2.42,
			math.sin(angle) * 2.42,
			0.24
		)
		shard.Material = Enum.Material.Neon
	end
	return {}
end

local function buildPoker(parent: Instance): { BasePart }
	disk(parent, "PokerTableFrame", 3.1, 0.26, Palette.brass, -0.12)
	disk(parent, "PokerFelt", 2.88, 0.15, Palette.violet, 0.06)
	for index = 1, 5 do
		card(
			parent,
			`DrawCard_{index}`,
			(index - 3) * 0.72,
			0.15,
			0.35,
			if index % 2 == 0 then Palette.coral else Palette.ink,
			(index - 3) * 0.06
		)
	end
	chipStack(parent, -1.75, -0.77, 5, Palette.mango)
	chipStack(parent, 0, -0.88, 3, Palette.cyan)
	chipStack(parent, 1.75, -0.77, 4, Palette.pink)
	return {}
end

local function buildCrash(parent: Instance): { BasePart }
	slab(parent, "FlightDisplay", 5.7, 3.35, 0, Palette.ink, 0.38)
	for index = 1, 6 do
		local x = -2.35 + (index - 1) * 0.82
		addLine(
			parent,
			`GridVertical_{index}`,
			Vector3.new(x, -1.2, 0.4),
			Vector3.new(x, 1.2, 0.4),
			0.025,
			Palette.steel
		)
	end
	for index = 1, 4 do
		local y = -0.9 + (index - 1) * 0.62
		addLine(
			parent,
			`GridHorizontal_{index}`,
			Vector3.new(-2.55, y, 0.4),
			Vector3.new(2.55, y, 0.4),
			0.025,
			Palette.steel
		)
	end
	local points = {
		Vector3.new(-2.25, -1.05, 0.6),
		Vector3.new(-1.55, -0.88, 0.6),
		Vector3.new(-0.9, -0.54, 0.6),
		Vector3.new(-0.15, -0.2, 0.6),
		Vector3.new(0.45, 0.42, 0.6),
		Vector3.new(1.12, 0.6, 0.6),
		Vector3.new(1.7, 1.15, 0.6),
		Vector3.new(2.16, 1.28, 0.6),
	}
	for index = 1, #points - 1 do
		addLine(parent, `FlightCurve_{index}`, points[index], points[index + 1], 0.075, Palette.cyan)
	end
	local craft = sphere(parent, "FlightCraft", 0.38, Palette.mango, points[#points].X, points[#points].Y, 0.78)
	return { craft }
end

local function buildDice(parent: Instance): { BasePart }
	slab(parent, "DiceMatchPlinth", 4.2, 2.8, 0, Palette.ink, 0.5)
	slab(parent, "DiceMatchScoreRail", 3.8, 0.16, 0.32, Palette.cyan, 0.16)
	local first = dice(parent, "MatchDieA", -0.62, 0.15, Palette.cream, 3)
	local second = dice(parent, "MatchDieB", 0.62, 0.15, Palette.cream, 5)
	for index = 1, 7 do
		local x = (index - 4) * 0.42
		local peg = sphere(
			parent,
			`TargetTotal_{index + 3}`,
			0.14,
			if index == 4 then Palette.mango else Palette.steel,
			x,
			-0.88,
			0.5
		)
		peg.Material = if index == 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	return { first.PrimaryPart :: BasePart, second.PrimaryPart :: BasePart }
end

local function buildDiceTable(parent: Instance): { BasePart }
	slab(parent, "CrapsTableFrame", 5.7, 3.7, 0, Palette.brassDeep, 0.72)
	slab(parent, "CrapsFelt", 5.45, 3.45, 0.28, Palette.coral, 0.34)
	for side = -1, 1, 2 do
		addLine(
			parent,
			`CrapsLaneRail_{side}`,
			Vector3.new(-2.3, side * 1.1, 0.5),
			Vector3.new(2.3, side * 1.1, 0.5),
			0.08,
			Palette.brass
		)
	end
	local first = dice(parent, "CrapsDieOne", -0.48, 0, Palette.cream, 2)
	local second = dice(parent, "CrapsDieTwo", 0.48, 0, Palette.cream, 6)
	for index, total in { 2, 3, 4, 10, 11, 12 } do
		local x = (index - 3.5) * 0.64
		local beacon = sphere(parent, `TargetTotal_{total}`, 0.18, Palette.cyan, x, -1.12, 0.62)
		beacon.Material = Enum.Material.Neon
	end
	local throwLine = slab(parent, "ThrowLine", 4.8, 0.06, 0.48, Palette.cream, 0.1)
	throwLine.CFrame = CFrame.new(0, -0.72, 0.48)
	return { first.PrimaryPart :: BasePart, second.PrimaryPart :: BasePart }
end

local function buildCoin(parent: Instance): { BasePart }
	disk(parent, "CoinOuterRim", 1.38, 0.28, Palette.brass, 0.02)
	local face = disk(parent, "CoinFace", 1.18, 0.23, Palette.mango, 0.2)
	disk(parent, "CoinInset", 0.88, 0.06, Palette.brass, 0.36)
	for index = 1, 8 do
		local angle = index / 8 * math.tau
		sphere(
			parent,
			`CoinEngraving_{index}`,
			0.16,
			Palette.cream,
			math.cos(angle) * 0.58,
			math.sin(angle) * 0.58,
			0.43
		)
	end
	sphere(parent, "CoinSeal", 0.42, Palette.coral, 0, 0, 0.46)
	return { face }
end

local function buildKeno(parent: Instance): { BasePart }
	slab(parent, "KenoFrame", 5.6, 3.35, 0, Palette.brass, 0.48)
	slab(parent, "KenoBoard", 5.32, 3.08, 0.22, Palette.panelRaised, 0.3)
	for index = 1, 40 do
		local column = (index - 1) % 10
		local row = math.floor((index - 1) / 10)
		local x = (column - 4.5) * 0.49
		local y = 1.1 - row * 0.72
		local highlight = index == 7 or index == 14 or index == 23 or index == 35
		sphere(
			parent,
			`NumberBall_{index}`,
			highlight and 0.3 or 0.22,
			if highlight then Palette.mango else Palette.cyan,
			x,
			y,
			0.58
		)
	end
	return {}
end

local function buildMines(parent: Instance): { BasePart }
	slab(parent, "SurveyBoardFrame", 4.05, 4.05, 0, Palette.ember, 0.6)
	slab(parent, "SurveyBoard", 3.83, 3.83, 0.28, Palette.ink, 0.26)
	for index = 1, 25 do
		local column = (index - 1) % 5
		local row = math.floor((index - 1) / 5)
		local tile = makePart(
			parent,
			`SurveyTile_{index}`,
			Vector3.new(0.65, 0.65, 0.18),
			if index == 4 or index == 12 or index == 21 then Palette.coral else Palette.panelRaised,
			CFrame.new((column - 2) * 0.74, (2 - row) * 0.74, 0.54)
		)
		if index == 4 or index == 12 or index == 21 then
			sphere(parent, `HazardCore_{index}`, 0.28, Palette.mango, tile.Position.X, tile.Position.Y, 0.7)
		else
			sphere(parent, `SafeSignal_{index}`, 0.12, Palette.cyan, tile.Position.X, tile.Position.Y, 0.68)
		end
	end
	return {}
end

local function buildPlinko(parent: Instance): { BasePart }
	slab(parent, "PlinkoBackboard", 5.4, 4.2, 0, Palette.ink, 0.42)
	for row = 1, 7 do
		local count = row + 2
		for index = 1, count do
			local x = (index - (count + 1) / 2) * 0.48
			local y = 1.45 - (row - 1) * 0.42
			sphere(parent, `PlinkoPeg_{row}_{index}`, 0.13, Palette.brass, x, y, 0.48)
		end
	end
	for index = 1, 9 do
		local x = (index - 5) * 0.48
		slab(parent, `PlinkoBin_{index}`, 0.42, 0.5, 0.34, if index == 5 then Palette.mango else Palette.steel, 0.45).CFrame =
			CFrame.new(x, -1.78, 0.45)
	end
	local ball = sphere(parent, "PlinkoBall", 0.28, Palette.cyan, 0, 1.8, 0.72)
	return { ball }
end

local function buildTableRoulette(parent: Instance): { BasePart }
	slab(parent, "RouletteTableFrame", 5.8, 3.6, 0, Palette.brass, 0.5)
	slab(parent, "RouletteFelt", 5.56, 3.35, 0.24, Palette.mint, 0.3)
	local rows = 3
	local columns = 12
	local cellWidth = 0.43
	local cellHeight = 0.82
	local count = rows * columns
	for index = 1, count do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local x = (column - (columns - 1) / 2) * cellWidth
		local y = ((rows - 1) / 2 - row) * cellHeight
		local color = if index % 2 == 0 then Palette.coral else Palette.ink
		local tile = makePart(
			parent,
			`NumberZone_{index}`,
			Vector3.new(cellWidth - 0.025, cellHeight - 0.025, 0.1),
			color,
			CFrame.new(x, y, 0.45)
		)
	end
	local marker = sphere(parent, "PocketMarker", 0.26, Palette.cream, 0, 1.62, 0.62)
	return { marker }
end

local function buildCardTower(parent: Instance): { BasePart }
	slab(parent, "TowerConveyor", 5.6, 3.5, 0, Palette.steel, 0.45)
	slab(parent, "ConveyorSurface", 5.38, 3.28, 0.24, Palette.ink, 0.28)
	for column = 1, 4 do
		local x = (column - 2.5) * 1.18
		slab(
			parent,
			`TowerColumnRail_{column}`,
			0.98,
			2.55,
			0.38,
			if column % 2 == 0 then Palette.violet else Palette.cyan,
			0.14
		).CFrame =
			CFrame.new(x, -0.22, 0.4)
		for row = 1, 3 do
			card(
				parent,
				`TowerCard_{column}_{row}`,
				x,
				-1.05 + row * 0.56,
				0.52 + row * 0.03,
				if row % 2 == 0 then Palette.coral else Palette.ink,
				(column - 2.5) * 0.035
			)
		end
	end
	for index = 1, 3 do
		card(
			parent,
			`IncomingCard_{index}`,
			-0.42 + index * 0.25,
			1.55,
			0.7 + index * 0.04,
			Palette.mango,
			0.04 * index
		)
	end
	return {}
end

local BUILDERS: { [string]: (Instance) -> { BasePart } } = {
	Slots = buildSlots,
	Blackjack = buildBlackjack,
	Roulette = buildRoulette,
	Poker = buildPoker,
	Crash = buildCrash,
	Dice = buildDice,
	CoinFlip = buildCoin,
	Keno = buildKeno,
	Mines = buildMines,
	Plinko = buildPlinko,
	TableRoulette = buildTableRoulette,
	QuantumRoulette = buildQuantumRoulette,
	CardTower = buildCardTower,
	DiceTable = buildDiceTable,
}

local function buildScene(world: WorldModel, kind: string): (Model, { BasePart })
	local scene = Instance.new("Model")
	scene.Name = kind .. "ArcadeScene"
	scene.Parent = world
	local builder = BUILDERS[kind]
	assert(builder ~= nil, `ArcadeViewport: no dedicated scene builder for {kind}`)
	local moving = builder(scene)
	scene.WorldPivot = CFrame.identity
	return scene, moving
end

local function ArcadeViewport(props: Props): Element
	local host: { current: ViewportFrame? } = React.useRef(nil)
	local softMotion = Motion.useMotionSettings().soft == true
	React.useEffect(function(): (() -> ())?
		local viewport = host.current
		if viewport == nil then
			return nil
		end
		local world = Instance.new("WorldModel")
		world.Name = "ArcadePreviewWorld"
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.Name = "ArcadePreviewCamera"
		camera.FieldOfView = 34
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 10), Vector3.zero)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local scene, _moving = buildScene(world, props.kind)
		local connection: RBXScriptConnection? = nil
		if props.animate == true and not softMotion then
			connection = RunService.RenderStepped:Connect(function(): ()
				local elapsed = os.clock()
				local yaw = math.sin(elapsed * 0.7) * 0.035
				local bob = math.sin(elapsed * 1.1) * 0.035
				scene:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0))
			end)
		end
		return function(): ()
			if connection ~= nil then
				connection:Disconnect()
			end
			viewport.CurrentCamera = nil
			world:Destroy()
			camera:Destroy()
		end
	end, { props.kind, props.animate == true, softMotion })
	return CreateElement("viewportframe", {
		Name = "ArcadeViewport_" .. props.kind,
		ref = host,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Ambient = Color3.fromRGB(155, 170, 195),
		LightColor = Color3.fromRGB(255, 246, 225),
		LightDirection = Vector3.new(-0.5, -0.8, 1),
		ZIndex = props.zIndex or 2,
	})
end

return ArcadeViewport
