--!strict
-- Purpose: Instant and action arcade preview scenes.
-- Owner: Astral Forge presentation. Dependencies: ArcadeViewportParts and CoreKit palette. Last-reviewed: 2026-10-07.

local Parts = require(script.Parent.ArcadeViewportParts)
local Palette: { [string]: Color3 } = require(script.Parent.CoreKit)("theme").Palette

local function buildSlots(parent: Instance): { BasePart }
	Parts.slab(parent, "ReelCabinet", 5.5, 3.7, 0, Palette.panelRaised, 0.72)
	Parts.slab(parent, "CabinetFace", 4.85, 2.75, 0.43, Palette.ink, 0.28)
	Parts.slab(parent, "ReelWindow", 4.25, 1.35, 0.68, Palette.steel, 0.24)
	local reels = {}
	for index, x in { -1.35, 0, 1.35 } do
		local drum = Parts.makePart(
			parent,
			`Reel_{index}`,
			Vector3.new(0.88, 1.12, 0.88),
			Palette.cream,
			CFrame.new(x, 0.15, 0.84),
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
		for symbolIndex = 1, 3 do
			Parts.sphere(
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
	Parts.slab(parent, "Marquee", 3.2, 0.38, 0.65, Palette.mango, 0.22)
	Parts.slab(parent, "Pedestal", 2.1, 0.46, -0.42, Palette.steel, 0.95)
	local lever =
		Parts.addLine(parent, "LeverArm", Vector3.new(2.35, 0.45, 0.9), Vector3.new(2.75, 1.25, 0.9), 0.14, Palette.brass)
	Parts.sphere(parent, "LeverKnob", 0.34, Palette.coral, 2.78, 1.32, 0.9)
	return { reels[1], reels[2], reels[3], lever }
end

local function buildCrash(parent: Instance): { BasePart }
	Parts.slab(parent, "FlightDisplay", 5.7, 3.35, 0, Palette.ink, 0.38)
	for index = 1, 6 do
		local x = -2.35 + (index - 1) * 0.82
		Parts.addLine(
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
		Parts.addLine(
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
		Parts.addLine(parent, `FlightCurve_{index}`, points[index], points[index + 1], 0.075, Palette.cyan)
	end
	local craft = Parts.sphere(parent, "FlightCraft", 0.38, Palette.mango, points[#points].X, points[#points].Y, 0.78)
	return { craft }
end

local function buildDice(parent: Instance): { BasePart }
	Parts.slab(parent, "DiceMatchPlinth", 4.2, 2.8, 0, Palette.ink, 0.5)
	Parts.slab(parent, "DiceMatchScoreRail", 3.8, 0.16, 0.32, Palette.cyan, 0.16)
	local first = Parts.dice(parent, "MatchDieA", -0.62, 0.15, Palette.cream, 3)
	local second = Parts.dice(parent, "MatchDieB", 0.62, 0.15, Palette.cream, 5)
	for index = 1, 7 do
		local x = (index - 4) * 0.42
		local peg = Parts.sphere(
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

local function buildCoin(parent: Instance): { BasePart }
	Parts.disk(parent, "CoinOuterRim", 1.38, 0.28, Palette.brass, 0.02)
	local face = Parts.disk(parent, "CoinFace", 1.18, 0.23, Palette.mango, 0.2)
	Parts.disk(parent, "CoinInset", 0.88, 0.06, Palette.brass, 0.36)
	for index = 1, 8 do
		local angle = index / 8 * math.tau
		Parts.sphere(
			parent,
			`CoinEngraving_{index}`,
			0.16,
			Palette.cream,
			math.cos(angle) * 0.58,
			math.sin(angle) * 0.58,
			0.43
		)
	end
	Parts.sphere(parent, "CoinSeal", 0.42, Palette.coral, 0, 0, 0.46)
	return { face }
end

local function buildKeno(parent: Instance): { BasePart }
	Parts.slab(parent, "KenoFrame", 5.6, 3.35, 0, Palette.brass, 0.48)
	Parts.slab(parent, "KenoBoard", 5.32, 3.08, 0.22, Palette.panelRaised, 0.3)
	for index = 1, 40 do
		local column = (index - 1) % 10
		local row = math.floor((index - 1) / 10)
		local x = (column - 4.5) * 0.49
		local y = 1.1 - row * 0.72
		local highlight = index == 7 or index == 14 or index == 23 or index == 35
		Parts.sphere(
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
	Parts.slab(parent, "SurveyBoardFrame", 4.05, 4.05, 0, Palette.ember, 0.6)
	Parts.slab(parent, "SurveyBoard", 3.83, 3.83, 0.28, Palette.ink, 0.26)
	for index = 1, 25 do
		local column = (index - 1) % 5
		local row = math.floor((index - 1) / 5)
		local tile = Parts.makePart(
			parent,
			`SurveyTile_{index}`,
			Vector3.new(0.65, 0.65, 0.18),
			if index == 4 or index == 12 or index == 21 then Palette.coral else Palette.panelRaised,
			CFrame.new((column - 2) * 0.74, (2 - row) * 0.74, 0.54)
		)
		if index == 4 or index == 12 or index == 21 then
			Parts.sphere(parent, `HazardCore_{index}`, 0.28, Palette.mango, tile.Position.X, tile.Position.Y, 0.7)
		else
			Parts.sphere(parent, `SafeSignal_{index}`, 0.12, Palette.cyan, tile.Position.X, tile.Position.Y, 0.68)
		end
	end
	return {}
end

local function buildPlinko(parent: Instance): { BasePart }
	Parts.slab(parent, "PlinkoBackboard", 5.4, 4.2, 0, Palette.ink, 0.42)
	for row = 1, 7 do
		local count = row + 2
		for index = 1, count do
			local x = (index - (count + 1) / 2) * 0.48
			local y = 1.45 - (row - 1) * 0.42
			Parts.sphere(parent, `PlinkoPeg_{row}_{index}`, 0.13, Palette.brass, x, y, 0.48)
		end
	end
	for index = 1, 9 do
		local x = (index - 5) * 0.48
		Parts.slab(parent, `PlinkoBin_{index}`, 0.42, 0.5, 0.34, if index == 5 then Palette.mango else Palette.steel, 0.45).CFrame =
			CFrame.new(x, -1.78, 0.45)
	end
	local ball = Parts.sphere(parent, "PlinkoBall", 0.28, Palette.cyan, 0, 1.8, 0.72)
	return { ball }
end


return table.freeze({
	Slots = buildSlots,
	Crash = buildCrash,
	Dice = buildDice,
	CoinFlip = buildCoin,
	Keno = buildKeno,
	Mines = buildMines,
	Plinko = buildPlinko,
})
