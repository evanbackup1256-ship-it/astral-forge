--!strict
-- Rebirth. A run ends when you trade its flux for cores; what you do around that trade is yours
-- to shape. Before a run you can swear a vow (finish fast, build lean, never leave the first
-- world, overflow the requirement); keep it and the payout grows, and every few kept vows make
-- that vow stronger. From the third rebirth you can carry keepsakes: a machine comes with you at a
-- share of its level. Milestone rebirths light a star, and each star is a choice between two
-- permanent perks. Every run is logged with its time, payout and a grade against your best.
-- Pure: the server's rules and the screen's previews agree.

local RebirthMath = {}

RebirthMath.VERSION = 1
RebirthMath.LOG_LIMIT = 10
RebirthMath.VOW_GRACE = 180
RebirthMath.KEEP_SHARE = 0.2
RebirthMath.KEEP_CAP = 60
RebirthMath.KEEP_SLOTS_AT = { 3, 12, 30 }
RebirthMath.MASTERY_EVERY = 5
RebirthMath.MASTERY_STEP = 0.05
RebirthMath.MASTERY_MAX = 5
RebirthMath.GRADE_BONUS = { S = 0.25, A = 0.1, B = 0, C = 0 }

-- each vow is checked at the moment you rebirth, against the run it was sworn for
RebirthMath.VOWS = table.freeze({
	{ Id = "Swift", Name = "Swift", Pays = "Cores", Multiplier = 1.3, Line = "Rebirth within 12 minutes.", Seconds = 12 * 60 },
	{ Id = "Lean", Name = "Lean", Pays = "Cores", Multiplier = 1.45, Line = "Own at most 3 kinds of machine.", Machines = 3 },
	{ Id = "Homebound", Name = "Homebound", Pays = "Cores", Multiplier = 1.6, Line = "Never unlock a second world." },
	{ Id = "Overflow", Name = "Overflow", Pays = "Stardust", Multiplier = 1.5, Line = "Bank 8x the flux a rebirth needs.", Ratio = 8 },
})
local vowById: { [string]: any } = {}
for _, vow in RebirthMath.VOWS do
	vowById[vow.Id] = vow
end
function RebirthMath.vow(id: string?): any
	return if type(id) == "string" then vowById[id] else nil
end

RebirthMath.PERKS = table.freeze({
	HeadStart = { Name = "Head Start", Line = "Stellar Core starts 5 levels higher.", Step = 5 },
	StartCash = { Name = "Seed Flux", Line = "Start each run with 4x the flux.", Step = 3 },
	CoreYield = { Name = "Dense Cores", Line = "+6% cores from every rebirth.", Step = 0.06 },
	DustYield = { Name = "Star Sift", Line = "+10% stardust from every rebirth.", Step = 0.1 },
	VowPower = { Name = "Iron Word", Line = "Kept vows pay 8% more.", Step = 0.08 },
	KeepShare = { Name = "Long Memory", Line = "Keepsakes keep 5% more of their level.", Step = 0.05 },
	VaultCarry = { Name = "Ember Purse", Line = "3% of your vault carries into the next run.", Step = 0.03 },
})
-- lifetime rebirth counts that light a star, and the pair offered at each (cycling)
RebirthMath.STARS = { 1, 3, 5, 8, 12, 16, 20, 25, 30, 40, 50, 65, 80, 100 }
RebirthMath.PAIRS = {
	{ "HeadStart", "StartCash" },
	{ "CoreYield", "DustYield" },
	{ "VowPower", "KeepShare" },
	{ "VaultCarry", "CoreYield" },
	{ "DustYield", "HeadStart" },
	{ "StartCash", "VowPower" },
	{ "KeepShare", "VaultCarry" },
}
function RebirthMath.pair(index: number): { string }
	return RebirthMath.PAIRS[(index - 1) % #RebirthMath.PAIRS + 1]
end

local function int(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

local function num(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n then
		return 0
	end
	return math.max(0, n)
end

-- builds or repairs the ledger; `lifetime` seeds the star count for saves from before the ledger
function RebirthMath.ensure(bag: any, now: number, lifetime: number?): any
	if type(bag) ~= "table" then
		bag = {}
	end
	bag.Version = RebirthMath.VERSION
	bag.Lifetime = math.max(int(bag.Lifetime), int(lifetime))
	bag.RunStartedAt = if int(bag.RunStartedAt) > 0 then int(bag.RunStartedAt) else int(now)
	if type(bag.Vow) ~= "string" or vowById[bag.Vow] == nil then
		bag.Vow = ""
	end
	bag.VowSince = int(bag.VowSince)
	if type(bag.Kept) ~= "table" then
		bag.Kept = {}
	end
	for id in bag.Kept do
		if vowById[id] == nil then
			bag.Kept[id] = nil
		else
			bag.Kept[id] = int(bag.Kept[id])
		end
	end
	if type(bag.Stars) ~= "table" then
		bag.Stars = {}
	end
	for key, perk in bag.Stars do
		local index = tonumber(key)
		local pair = index and RebirthMath.STARS[index] and RebirthMath.pair(index)
		if not pair or (perk ~= pair[1] and perk ~= pair[2]) then
			bag.Stars[key] = nil
		end
	end
	if type(bag.Keep) ~= "table" then
		bag.Keep = {}
	end
	local keep = {}
	for _, id in bag.Keep do
		if type(id) == "string" and #keep < #RebirthMath.KEEP_SLOTS_AT then
			table.insert(keep, id)
		end
	end
	bag.Keep = keep
	if type(bag.Runs) ~= "table" then
		bag.Runs = {}
	end
	while #bag.Runs > RebirthMath.LOG_LIMIT do
		table.remove(bag.Runs, 1)
	end
	bag.BestCores = num(bag.BestCores)
	bag.FastestSeconds = int(bag.FastestSeconds)
	return bag
end

-- how many keepsake slots a lifetime count opens
function RebirthMath.keepSlots(lifetime: number): number
	local slots = 0
	for _, at in RebirthMath.KEEP_SLOTS_AT do
		if lifetime >= at then
			slots += 1
		end
	end
	return slots
end

-- stars lit but not yet chosen, in order
function RebirthMath.pendingStars(bag: any): { number }
	local list = {}
	for index, at in RebirthMath.STARS do
		if int(bag.Lifetime) >= at and bag.Stars[tostring(index)] == nil then
			table.insert(list, index)
		end
	end
	return list
end

function RebirthMath.nextStar(bag: any): (number?, number?)
	for index, at in RebirthMath.STARS do
		if int(bag.Lifetime) < at then
			return index, at
		end
	end
	return nil, nil
end

function RebirthMath.pickStar(bag: any, index: number, pick: number): (boolean, string?)
	local at = RebirthMath.STARS[index]
	if at == nil then
		return false, "That star doesn't exist."
	end
	if int(bag.Lifetime) < at then
		return false, `That star lights at rebirth {at}.`
	end
	if bag.Stars[tostring(index)] ~= nil then
		return false, "You already chose that star."
	end
	local perk = RebirthMath.pair(index)[pick]
	if perk == nil then
		return false, "Pick one of the two."
	end
	bag.Stars[tostring(index)] = perk
	return true, RebirthMath.PERKS[perk].Name
end

-- summed perks from every chosen star
function RebirthMath.effects(bag: any): { [string]: number }
	local out = {}
	for kind in RebirthMath.PERKS do
		out[kind] = 0
	end
	if type(bag) == "table" and type(bag.Stars) == "table" then
		for _, perk in bag.Stars do
			local def = RebirthMath.PERKS[perk]
			if def then
				out[perk] += def.Step
			end
		end
	end
	return out
end

-- a vow grows by MASTERY_STEP for every MASTERY_EVERY times it has been kept
function RebirthMath.mastery(bag: any, id: string): number
	local kept = if type(bag) == "table" and type(bag.Kept) == "table" then int(bag.Kept[id]) else 0
	return math.min(RebirthMath.MASTERY_MAX, math.floor(kept / RebirthMath.MASTERY_EVERY))
end

function RebirthMath.vowMultiplier(bag: any, id: string): number
	local vow = vowById[id]
	if vow == nil then
		return 1
	end
	local extra = (vow.Multiplier - 1) * (1 + RebirthMath.effects(bag).VowPower)
	return 1 + extra + RebirthMath.mastery(bag, id) * RebirthMath.MASTERY_STEP
end

-- whether the sworn vow holds right now. run = { Seconds, Zone, MachineKinds, Ratio }
function RebirthMath.vowHolds(bag: any, run: any): (boolean, string)
	local vow = vowById[bag.Vow]
	if vow == nil then
		return false, ""
	end
	if bag.VowSince > bag.RunStartedAt + RebirthMath.VOW_GRACE then
		return false, "Sworn too late in the run."
	end
	if vow.Id == "Swift" then
		local left = vow.Seconds - int(run.Seconds)
		return left >= 0, if left >= 0 then `{math.floor(left / 60)}:{string.format("%02d", left % 60)} left` else "Too slow this time."
	elseif vow.Id == "Lean" then
		local kinds = int(run.MachineKinds)
		return kinds <= vow.Machines, `{kinds} of {vow.Machines} machine kinds`
	elseif vow.Id == "Homebound" then
		return int(run.Zone) <= 1, if int(run.Zone) <= 1 then "Still in the first world." else "You left the first world."
	elseif vow.Id == "Overflow" then
		local ratio = num(run.Ratio)
		return ratio >= vow.Ratio, `{math.floor(ratio * 10) / 10}x of {vow.Ratio}x`
	end
	return false, ""
end

-- a run's grade: S = a new best with a kept vow, A = either one, B = at least half your best
function RebirthMath.grade(bag: any, cores: number, kept: boolean): string
	local best = num(bag.BestCores)
	local newBest = cores > best
	if newBest and kept then
		return "S"
	elseif newBest or kept then
		return "A"
	elseif cores >= best * 0.5 then
		return "B"
	end
	return "C"
end

-- what a rebirth pays right now. base = { Cores, Stardust } before the ledger; run as in vowHolds
function RebirthMath.quote(bag: any, base: any, run: any): any
	local fx = RebirthMath.effects(bag)
	local kept = false
	local vow = vowById[bag.Vow]
	if vow then
		kept = (RebirthMath.vowHolds(bag, run))
	end
	local coreMult = 1 + fx.CoreYield
	local dustMult = 1 + fx.DustYield
	if kept and vow then
		if vow.Pays == "Cores" then
			coreMult *= RebirthMath.vowMultiplier(bag, vow.Id)
		else
			dustMult *= RebirthMath.vowMultiplier(bag, vow.Id)
		end
	end
	local cores = math.max(1, math.floor(num(base.Cores) * coreMult))
	local grade = RebirthMath.grade(bag, cores, kept)
	dustMult *= 1 + RebirthMath.GRADE_BONUS[grade]
	return {
		Cores = cores,
		CoreMultiplier = coreMult,
		Stardust = math.floor(num(base.Stardust) * dustMult),
		StardustMultiplier = dustMult,
		Vow = if vow then vow.Id else "",
		Kept = kept,
		Grade = grade,
	}
end

-- what the next run starts with: { Cash, StellarCore, Machines = { [id] = level }, VaultCash }
function RebirthMath.carry(bag: any, machines: any, vault: number, startingCash: number, allowed: (string) -> boolean): any
	local fx = RebirthMath.effects(bag)
	local share = RebirthMath.KEEP_SHARE + fx.KeepShare
	local slots = RebirthMath.keepSlots(int(bag.Lifetime))
	local kept = {}
	local used = 0
	for _, id in bag.Keep do
		if used >= slots then
			break
		end
		local level = int(type(machines) == "table" and machines[id])
		if level > 0 and allowed(id) and kept[id] == nil then
			kept[id] = math.clamp(math.floor(level * share), 1, RebirthMath.KEEP_CAP)
			used += 1
		end
	end
	local core = 1 + int(fx.HeadStart)
	kept.StellarCore = math.max(kept.StellarCore or 0, core)
	return {
		Cash = math.floor(startingCash * (1 + fx.StartCash) + num(vault) * fx.VaultCarry),
		Machines = kept,
	}
end

-- closes the run: logs it, counts the kept vow, sets the next vow and keepsakes, starts the clock
function RebirthMath.close(bag: any, quote: any, now: number, nextVow: string?, nextKeep: { string }?): any
	local seconds = math.max(0, int(now) - int(bag.RunStartedAt))
	local entry = {
		N = int(bag.Lifetime) + 1,
		At = int(now),
		Seconds = seconds,
		Cores = quote.Cores,
		Stardust = quote.Stardust,
		Vow = quote.Vow,
		Kept = quote.Kept,
		Grade = quote.Grade,
	}
	table.insert(bag.Runs, entry)
	while #bag.Runs > RebirthMath.LOG_LIMIT do
		table.remove(bag.Runs, 1)
	end
	if quote.Kept and quote.Vow ~= "" then
		bag.Kept[quote.Vow] = int(bag.Kept[quote.Vow]) + 1
	end
	bag.BestCores = math.max(num(bag.BestCores), quote.Cores)
	if bag.FastestSeconds == 0 or seconds < bag.FastestSeconds then
		bag.FastestSeconds = seconds
	end
	bag.Lifetime = int(bag.Lifetime) + 1
	bag.RunStartedAt = int(now)
	bag.Vow = if nextVow and vowById[nextVow] then nextVow else ""
	bag.VowSince = int(now)
	if type(nextKeep) == "table" then
		local keep = {}
		for _, id in nextKeep do
			if type(id) == "string" and #keep < #RebirthMath.KEEP_SLOTS_AT and not table.find(keep, id) then
				table.insert(keep, id)
			end
		end
		bag.Keep = keep
	end
	return entry
end

-- swear (or drop, with "") a vow mid-run; swearing only counts in the run's first few minutes
function RebirthMath.swear(bag: any, id: string, now: number): (boolean, string?)
	if id == "" then
		bag.Vow = ""
		return true, "Vow dropped."
	end
	local vow = vowById[id]
	if vow == nil then
		return false, "That vow doesn't exist."
	end
	if int(now) > int(bag.RunStartedAt) + RebirthMath.VOW_GRACE then
		return false, "Vows are sworn at the start of a run. Choose one for the next run when you rebirth."
	end
	bag.Vow = id
	bag.VowSince = int(now)
	return true, `Sworn: {vow.Name}.`
end

function RebirthMath.setKeep(bag: any, ids: any): boolean
	if type(ids) ~= "table" then
		return false
	end
	local keep = {}
	for _, id in ids do
		if type(id) == "string" and #id <= 48 and #keep < RebirthMath.keepSlots(int(bag.Lifetime)) and not table.find(keep, id) then
			table.insert(keep, id)
		end
	end
	bag.Keep = keep
	return true
end

return table.freeze(RebirthMath)
