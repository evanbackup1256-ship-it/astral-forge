--!strict
-- Purpose: Table, wheel, and card arcade preview scenes arcade preview scenes.
-- Owner: Astral Forge presentation. Dependencies: ArcadeViewportParts and CoreKit palette. Last-reviewed: 2026-10-07.

local Parts = require(script.Parent.ArcadeViewportParts)
local Palette: { [string]: Color3 } = require(script.Parent.CoreKit)("theme").Palette

local function buildBlackjack(parent: Instance): { BasePart }
	Parts.disk(parent, "OvalTableBase", 3.2, 0.26, Palette.brass, -0.12)
	Parts.disk(parent, "FeltTable", 2.96, 0.14, Palette.mint, 0.08)
	Parts.slab(parent, "DealerRail", 4.9, 0.22, 0.36, Palette.brass, 0.24)
	for index = 1, 5 do
		Parts.card(
			parent,
			`DealerCard_{index}`,
			(index - 3) * 0.46,
			0.44 + (index % 2) * 0.08,
			0.5,
			Palette.coral,
			(index - 3) * 0.08
		)
	end
	Parts.card(parent, "ShoeTopCard", -2.15, 0.24, 0.6, Palette.cyan, -0.08)
	Parts.slab(parent, "CardShoe", 0.82, 0.48, 0.45, Palette.steel, 0.42).CFrame = CFrame.new(-2.2, -0.1, 0.45)
		* CFrame.Angles(0, 0, -0.2)
	Parts.chipStack(parent, -1.65, -0.72, 4, Palette.coral)
	Parts.chipStack(parent, 1.45, -0.72, 3, Palette.cyan)
	return {}
end

local function buildRoulette(parent: Instance): { BasePart }
	Parts.disk(parent, "RouletteHousing", 2.65, 0.32, Palette.steel, -0.12)
	Parts.disk(parent, "WheelTrack", 2.39, 0.1, Palette.brass, 0.08)
	Parts.disk(parent, "WheelFace", 2.12, 0.12, Palette.panelRaised, 0.18)
	local rotor = Instance.new("Model")
	rotor.Name = "NumberedSectorRotor"
	rotor.Parent = parent
	for index = 0, 36 do
		local angle = index / 37 * math.tau
		local hue = if index == 0 then Palette.mint elseif index % 2 == 0 then Palette.ink else Palette.coral
		local x, y = math.cos(angle) * 1.82, math.sin(angle) * 1.82
		local pocket = Parts.makePart(
			rotor,
			`Pocket_{index}`,
			Vector3.new(0.31, 0.42, 0.08),
			hue,
			CFrame.new(x, y, 0.31) * CFrame.Angles(0, 0, angle)
		)
		pocket.Material = Enum.Material.SmoothPlastic
	end
	Parts.disk(parent, "WheelHub", 0.68, 0.35, Palette.brass, 0.46)
	Parts.sphere(parent, "WheelHubGem", 0.45, Palette.coral, 0, 0, 0.68)
	local ball = Parts.sphere(parent, "RouletteBall", 0.18, Palette.cream, 1.95, 0, 0.56)
	return { rotor.PrimaryPart or rotor:GetChildren()[1] :: BasePart, ball }
end

local function buildQuantumRoulette(parent: Instance): { BasePart }
	Parts.disk(parent, "QuantumGravityChamber", 2.72, 0.34, Palette.violet, -0.16)
	Parts.disk(parent, "QuantumPhaseRing", 2.46, 0.11, Palette.cyan, 0.08)
	Parts.disk(parent, "QuantumBoard", 2.17, 0.13, Palette.panelRaised, 0.2)
	local rotor = Instance.new("Model")
	rotor.Name = "ShiftingSectorArray"
	rotor.Parent = parent
	for index = 1, 16 do
		local angle = (index - 1) / 16 * math.tau
		local row = math.floor((index - 1) / 4)
		local radius = if row % 2 == 0 then 1.64 else 1.18
		local width = if row % 2 == 0 then 0.52 else 0.38
		local color = ({ Palette.cyan, Palette.violet, Palette.pink, Palette.mango })[(index % 4) + 1]
		local sector = Parts.makePart(
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
	Parts.disk(parent, "GravitySinkRim", 0.82, 0.26, Palette.brass, 0.46)
	local sink = Parts.sphere(parent, "GravitySink", 0.7, Palette.ink, 0, 0, 0.72)
	sink.Material = Enum.Material.Neon
	for index = 1, 5 do
		local angle = index / 5 * math.tau
		local x, y = math.cos(angle) * 1.02, math.sin(angle) * 1.02
		Parts.addLine(
			parent,
			`GravityTether_{index}`,
			Vector3.new(x * 0.48, y * 0.48, 0.56),
			Vector3.new(x, y, 0.56),
			0.045,
			Palette.cyan
		)
		Parts.sphere(parent, `PhaseAnchor_{index}`, 0.15, Palette.cream, x, y, 0.62)
	end
	for index = 1, 8 do
		local angle = index / 8 * math.tau
		local shard = Parts.sphere(
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
	Parts.disk(parent, "PokerTableFrame", 3.1, 0.26, Palette.brass, -0.12)
	Parts.disk(parent, "PokerFelt", 2.88, 0.15, Palette.violet, 0.06)
	for index = 1, 5 do
		Parts.card(
			parent,
			`DrawCard_{index}`,
			(index - 3) * 0.72,
			0.15,
			0.35,
			if index % 2 == 0 then Palette.coral else Palette.ink,
			(index - 3) * 0.06
		)
	end
	Parts.chipStack(parent, -1.75, -0.77, 5, Palette.mango)
	Parts.chipStack(parent, 0, -0.88, 3, Palette.cyan)
	Parts.chipStack(parent, 1.75, -0.77, 4, Palette.pink)
	return {}
end

local function buildDiceTable(parent: Instance): { BasePart }
	Parts.slab(parent, "CrapsTableFrame", 5.7, 3.7, 0, Palette.brassDeep, 0.72)
	Parts.slab(parent, "CrapsFelt", 5.45, 3.45, 0.28, Palette.coral, 0.34)
	for side = -1, 1, 2 do
		Parts.addLine(
			parent,
			`CrapsLaneRail_{side}`,
			Vector3.new(-2.3, side * 1.1, 0.5),
			Vector3.new(2.3, side * 1.1, 0.5),
			0.08,
			Palette.brass
		)
	end
	local first = Parts.dice(parent, "CrapsDieOne", -0.48, 0, Palette.cream, 2)
	local second = Parts.dice(parent, "CrapsDieTwo", 0.48, 0, Palette.cream, 6)
	for index, total in { 2, 3, 4, 10, 11, 12 } do
		local x = (index - 3.5) * 0.64
		local beacon = Parts.sphere(parent, `TargetTotal_{total}`, 0.18, Palette.cyan, x, -1.12, 0.62)
		beacon.Material = Enum.Material.Neon
	end
	local throwLine = Parts.slab(parent, "ThrowLine", 4.8, 0.06, 0.48, Palette.cream, 0.1)
	throwLine.CFrame = CFrame.new(0, -0.72, 0.48)
	return { first.PrimaryPart :: BasePart, second.PrimaryPart :: BasePart }
end

local function buildTableRoulette(parent: Instance): { BasePart }
	Parts.slab(parent, "RouletteTableFrame", 5.8, 3.6, 0, Palette.brass, 0.5)
	Parts.slab(parent, "RouletteFelt", 5.56, 3.35, 0.24, Palette.mint, 0.3)
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
		local tile = Parts.makePart(
			parent,
			`NumberZone_{index}`,
			Vector3.new(cellWidth - 0.025, cellHeight - 0.025, 0.1),
			color,
			CFrame.new(x, y, 0.45)
		)
	end
	local marker = Parts.sphere(parent, "PocketMarker", 0.26, Palette.cream, 0, 1.62, 0.62)
	return { marker }
end

local function buildCardTower(parent: Instance): { BasePart }
	Parts.slab(parent, "TowerConveyor", 5.6, 3.5, 0, Palette.steel, 0.45)
	Parts.slab(parent, "ConveyorSurface", 5.38, 3.28, 0.24, Palette.ink, 0.28)
	for column = 1, 4 do
		local x = (column - 2.5) * 1.18
		Parts.slab(
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
			Parts.card(
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
		Parts.card(
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


return table.freeze({
	Blackjack = buildBlackjack,
	Roulette = buildRoulette,
	QuantumRoulette = buildQuantumRoulette,
	Poker = buildPoker,
	DiceTable = buildDiceTable,
	TableRoulette = buildTableRoulette,
	CardTower = buildCardTower,
})
