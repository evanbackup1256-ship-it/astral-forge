--!strict
-- Star Charts (plot constellations with Stardust) and Signal Cipher (a daily
-- four-glyph code). Pure data + math so the server, the client and Lune share it.

local SkyCharts = {}

local DAY = 86400

export type Constellation = {
	Id: string,
	Name: string,
	Lore: string,
	Color: { number },
	Stars: { { number } },
	Edges: { { number } },
	Reward: { [string]: any },
}

-- Star coordinates are hand placed on a 0..1 plate; edges index into Stars.
SkyCharts.CONSTELLATIONS = table.freeze({
	table.freeze({
		Id = "anvil",
		Name = "The Anvil",
		Lore = "The first shape every forgehand learns to find.",
		Color = table.freeze({ 255, 184, 92 }),
		Stars = table.freeze({ { 0.18, 0.38 }, { 0.42, 0.34 }, { 0.71, 0.36 }, { 0.84, 0.27 }, { 0.56, 0.58 }, { 0.38, 0.74 }, { 0.66, 0.76 } }),
		Edges = table.freeze({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 2, 5 }, { 3, 5 }, { 5, 6 }, { 5, 7 }, { 6, 7 } }),
		Reward = table.freeze({ CashMinutes = 20, Stardust = 30 }),
	}),
	table.freeze({
		Id = "lantern",
		Name = "Lantern Keeper",
		Lore = "Sailors tied their routes to its swinging light.",
		Color = table.freeze({ 132, 226, 255 }),
		Stars = table.freeze({ { 0.5, 0.14 }, { 0.5, 0.3 }, { 0.35, 0.44 }, { 0.65, 0.44 }, { 0.38, 0.7 }, { 0.62, 0.7 }, { 0.5, 0.86 } }),
		Edges = table.freeze({ { 1, 2 }, { 2, 3 }, { 2, 4 }, { 3, 5 }, { 4, 6 }, { 5, 7 }, { 6, 7 }, { 3, 4 } }),
		Reward = table.freeze({ CashMinutes = 30, FreeSpins = 1 }),
	}),
	table.freeze({
		Id = "heron",
		Name = "Glass Heron",
		Lore = "Long-legged and patient, it wades the edge of the galaxy.",
		Color = table.freeze({ 170, 255, 214 }),
		Stars = table.freeze({ { 0.22, 0.2 }, { 0.3, 0.32 }, { 0.44, 0.4 }, { 0.62, 0.42 }, { 0.78, 0.34 }, { 0.58, 0.58 }, { 0.52, 0.8 }, { 0.66, 0.84 } }),
		Edges = table.freeze({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 4, 6 }, { 6, 7 }, { 6, 8 } }),
		Reward = table.freeze({ CashMinutes = 40, Stardust = 60, Keys = table.freeze({ ForgeCrate = 2 }) }),
	}),
	table.freeze({
		Id = "twins",
		Name = "Furnace Twins",
		Lore = "Two stokers who never let the fire go out.",
		Color = table.freeze({ 255, 128, 112 }),
		Stars = table.freeze({ { 0.3, 0.16 }, { 0.66, 0.18 }, { 0.28, 0.42 }, { 0.68, 0.4 }, { 0.48, 0.5 }, { 0.24, 0.72 }, { 0.72, 0.7 }, { 0.36, 0.88 }, { 0.6, 0.88 } }),
		Edges = table.freeze({ { 1, 3 }, { 2, 4 }, { 3, 5 }, { 4, 5 }, { 3, 6 }, { 4, 7 }, { 6, 8 }, { 7, 9 } }),
		Reward = table.freeze({ CashMinutes = 55, Cores = 1, Signals = 20 }),
	}),
	table.freeze({
		Id = "orrery",
		Name = "Broken Orrery",
		Lore = "A clockwork sky that lost a gear and kept turning anyway.",
		Color = table.freeze({ 196, 160, 255 }),
		Stars = table.freeze({ { 0.5, 0.5 }, { 0.5, 0.2 }, { 0.76, 0.36 }, { 0.74, 0.66 }, { 0.48, 0.8 }, { 0.24, 0.64 }, { 0.26, 0.34 }, { 0.88, 0.16 } }),
		Edges = table.freeze({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 1, 4 }, { 1, 6 }, { 3, 8 } }),
		Reward = table.freeze({ CashMinutes = 70, Stardust = 120, Essence = 4 }),
	}),
	table.freeze({
		Id = "serpent",
		Name = "Ember Serpent",
		Lore = "It sheds a skin of sparks every hundred years.",
		Color = table.freeze({ 255, 214, 96 }),
		Stars = table.freeze({ { 0.12, 0.72 }, { 0.24, 0.6 }, { 0.36, 0.66 }, { 0.46, 0.5 }, { 0.58, 0.42 }, { 0.66, 0.54 }, { 0.78, 0.46 }, { 0.84, 0.3 }, { 0.74, 0.2 } }),
		Edges = table.freeze({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 9 } }),
		Reward = table.freeze({ CashMinutes = 90, Cores = 2, Boost = "Hyperdrive" }),
	}),
	table.freeze({
		Id = "crown",
		Name = "Drowned Crown",
		Lore = "Five points of a crown that sank below the horizon.",
		Color = table.freeze({ 255, 150, 210 }),
		Stars = table.freeze({ { 0.14, 0.32 }, { 0.3, 0.58 }, { 0.4, 0.24 }, { 0.5, 0.56 }, { 0.6, 0.24 }, { 0.7, 0.58 }, { 0.86, 0.32 }, { 0.5, 0.78 } }),
		Edges = table.freeze({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 2, 8 }, { 6, 8 } }),
		Reward = table.freeze({ CashMinutes = 120, Stardust = 220, Signals = 40 }),
	}),
	table.freeze({
		Id = "forgeheart",
		Name = "Forgeheart",
		Lore = "Chart every star and the old smiths say the sky starts humming.",
		Color = table.freeze({ 255, 236, 180 }),
		Stars = table.freeze({ { 0.5, 0.12 }, { 0.32, 0.26 }, { 0.68, 0.26 }, { 0.2, 0.48 }, { 0.8, 0.48 }, { 0.5, 0.44 }, { 0.34, 0.7 }, { 0.66, 0.7 }, { 0.5, 0.9 } }),
		Edges = table.freeze({ { 1, 2 }, { 1, 3 }, { 2, 4 }, { 3, 5 }, { 2, 6 }, { 3, 6 }, { 4, 7 }, { 5, 8 }, { 7, 9 }, { 8, 9 }, { 6, 9 } }),
		Reward = table.freeze({ CashMinutes = 180, Cores = 4, Essence = 8, Boost = "DomainSurge" }),
	}),
})

SkyCharts.STAR_BASE = 12
SkyCharts.STAR_GROWTH = 1.12
SkyCharts.CONSTELLATION_STEP = 0.75

SkyCharts.CIPHER = table.freeze({
	Glyphs = table.freeze({ "Sun", "Moon", "Comet", "Ring", "Spark", "Eye" }),
	Length = 4,
	MaxGuesses = 7,
})

local byId: { [string]: number } = {}
for index, entry in SkyCharts.CONSTELLATIONS do
	byId[entry.Id] = index
end

function SkyCharts.IndexOf(id: any): number?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function SkyCharts.StarCost(index: number, plotted: number): number
	local base = SkyCharts.STAR_BASE * (1 + SkyCharts.CONSTELLATION_STEP * (index - 1))
	return math.floor(base * SkyCharts.STAR_GROWTH ^ plotted + 0.5)
end

function SkyCharts.RemainingCost(index: number, plotted: number): number
	local entry = SkyCharts.CONSTELLATIONS[index]
	local total = 0
	for k = plotted, #entry.Stars - 1 do
		total += SkyCharts.StarCost(index, k)
	end
	return total
end

local function count(value: any, limit: number): number
	local n = tonumber(value) or 0
	if n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, limit)
end

function SkyCharts.Ensure(bag: any): any
	if type(bag) ~= "table" then
		bag = {}
	end
	if type(bag.Charts) ~= "table" then
		bag.Charts = {}
	end
	local charts = bag.Charts
	local plotted = if type(charts.Plotted) == "table" then charts.Plotted else {}
	local clean = {}
	for _, entry in SkyCharts.CONSTELLATIONS do
		local n = count(plotted[entry.Id], #entry.Stars)
		if n > 0 then
			clean[entry.Id] = n
		end
	end
	charts.Plotted = clean
	if type(bag.Cipher) ~= "table" then
		bag.Cipher = {}
	end
	local cipher = bag.Cipher
	cipher.Day = count(cipher.Day, 1e7)
	cipher.Streak = count(cipher.Streak, 1e6)
	cipher.Best = count(cipher.Best, 1e6)
	cipher.Solves = count(cipher.Solves, 1e7)
	cipher.LastSolvedDay = count(cipher.LastSolvedDay, 1e7)
	cipher.Solved = cipher.Solved == true
	cipher.Failed = cipher.Failed == true
	local guesses = {}
	if type(cipher.Guesses) == "table" then
		for _, guess in cipher.Guesses do
			if #guesses >= SkyCharts.CIPHER.MaxGuesses then
				break
			end
			if type(guess) == "table" and type(guess.Code) == "string" and #guess.Code == SkyCharts.CIPHER.Length then
				table.insert(guesses, { Code = guess.Code, Exact = count(guess.Exact, 4), Near = count(guess.Near, 4) })
			end
		end
	end
	cipher.Guesses = guesses
	return bag
end

function SkyCharts.Completed(bag: any): number
	local done = 0
	for _, entry in SkyCharts.CONSTELLATIONS do
		if (bag.Charts.Plotted[entry.Id] or 0) >= #entry.Stars then
			done += 1
		end
	end
	return done
end

-- A constellation opens once the one before it is fully charted.
function SkyCharts.IsOpen(bag: any, index: number): boolean
	if index <= 1 then
		return true
	end
	local previous = SkyCharts.CONSTELLATIONS[index - 1]
	return (bag.Charts.Plotted[previous.Id] or 0) >= #previous.Stars
end

function SkyCharts.Day(now: number): number
	return math.floor(now / DAY)
end

local MOD = 2147483647

function SkyCharts.CipherCode(day: number, userId: number): { number }
	local seed = (math.abs(math.floor(day)) * 7919 + 104729) % MOD
	seed = (seed + (math.abs(math.floor(userId)) % MOD) * 31) % MOD
	if seed == 0 then
		seed = 1
	end
	local code = {}
	for slot = 1, SkyCharts.CIPHER.Length do
		for _ = 1, 3 do
			seed = (seed * 48271) % MOD
		end
		code[slot] = (seed % #SkyCharts.CIPHER.Glyphs) + 1
	end
	return code
end

function SkyCharts.Encode(code: { number }): string
	local parts = table.create(#code)
	for index, value in code do
		parts[index] = tostring(value)
	end
	return table.concat(parts)
end

function SkyCharts.Decode(value: any): { number }?
	local glyphs = #SkyCharts.CIPHER.Glyphs
	if type(value) == "string" then
		if #value ~= SkyCharts.CIPHER.Length then
			return nil
		end
		local code = {}
		for index = 1, #value do
			local n = tonumber(string.sub(value, index, index))
			if n == nil or n < 1 or n > glyphs then
				return nil
			end
			code[index] = n
		end
		return code
	elseif type(value) == "table" then
		if #value ~= SkyCharts.CIPHER.Length then
			return nil
		end
		local code = {}
		for index = 1, SkyCharts.CIPHER.Length do
			local n = value[index]
			if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > glyphs then
				return nil
			end
			code[index] = n
		end
		return code
	end
	return nil
end

-- Exact = right glyph in the right slot; Near = right glyph, wrong slot.
function SkyCharts.Score(code: { number }, guess: { number }): (number, number)
	local exact = 0
	local leftCode: { [number]: number } = {}
	local leftGuess: { [number]: number } = {}
	for index = 1, #code do
		if code[index] == guess[index] then
			exact += 1
		else
			leftCode[code[index]] = (leftCode[code[index]] or 0) + 1
			leftGuess[guess[index]] = (leftGuess[guess[index]] or 0) + 1
		end
	end
	local near = 0
	for glyph, n in leftGuess do
		near += math.min(n, leftCode[glyph] or 0)
	end
	return exact, near
end

function SkyCharts.CipherReward(guessesUsed: number, streak: number): { [string]: any }
	local spare = math.max(0, SkyCharts.CIPHER.MaxGuesses - guessesUsed)
	local reward: { [string]: any } = {
		CashMinutes = 12 + spare * 4,
		Stardust = 8 + spare * 3 + math.min(streak, 7) * 2,
	}
	if guessesUsed <= 3 then
		reward.Signals = 10
	end
	if streak > 0 and streak % 7 == 0 then
		reward.Cores = 1
	end
	return reward
end

-- Roll the daily cipher forward; a missed day breaks the streak.
function SkyCharts.RollCipher(bag: any, day: number)
	local cipher = bag.Cipher
	if cipher.Day ~= day then
		cipher.Day = day
		cipher.Guesses = {}
		cipher.Solved = false
		cipher.Failed = false
	end
	if cipher.LastSolvedDay > 0 and cipher.LastSolvedDay < day - 1 then
		cipher.Streak = 0
	end
end

return table.freeze(SkyCharts)
