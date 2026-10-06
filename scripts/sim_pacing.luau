--!strict
-- Whole-game pacing simulator (a report, not a verify_ test: it asserts nothing
-- about balance, so pacing changes are judged on numbers instead of feel).
--
--   lune run scripts/sim_pacing              current GameConfig
--   lune run scripts/sim_pacing <path>       another GameConfig copy (before/after)
--   lune run scripts/sim_pacing <path> <gain> <tapShare> [days]
--                                            policy knobs for sensitivity runs
--
-- It reads the REAL machine, zone and economy numbers out of GameConfig.luau and
-- plays a steady, active player: always takes the best-payback purchase (a machine
-- level or the next zone), and rebirths once that would meaningfully raise its
-- core total.
--
-- Model (mirrors Economy.RawProduction / Production / PermanentMultiplier and
-- RebirthGate.PrestigeReward):
--   cost(level)    = floor(BaseCost * CostScale ^ level)
--   output/sec     = sum(BaseProduction * level * (1 + Growth * (level - 1)))
--   multiplier     = zone.Multiplier * (1 + CoreMultiplier * cores ^ CoreExponent
--                                         + rebirths * RebirthMultiplier)
--   cores gained   = max(1, floor((runCash / PrestigeRequirement) ^ PrestigeExponent))
-- A machine unlocks when its zone and rebirth gates are met AND the previous
-- machine in the chain is at PreviousLevel. Taps add TAP_SHARE of output per
-- second. NOT modelled: research, relics, boosts, Star Grid, Continuum, guild
-- bonuses, daily rewards, vault capacity -- all of which only make the real game
-- FASTER, so read the numbers as a slow-side bound for a machines-only player.
-- Only the hand-authored ladder is simulated; later machines are generated at
-- runtime (HorizonForge_N) and follow formulas, not hand-set numbers.

local fs = require("@lune/fs")
local process = require("@lune/process")

local TAP_SHARE = tonumber(process.args[3]) or (0.15 * 1.5) -- ~1.5 taps per second from an active player
local MAX_SECONDS = 60 * 60 * 24 * (tonumber(process.args[4]) or 14) -- days of continuous play
local REBIRTH_WHEN_GAIN_OF = tonumber(process.args[2]) or 0.5 -- rebirth once the reward is >= this fraction of current cores
local MIN_RUN_SECONDS = 120 -- never rebirth twice inside two minutes

local path = process.args[1] or "src/Shared/AstralForge/Shared/GameConfig.luau"
local source = fs.readFile(path)

-- Numbers as written in GameConfig: 1_500, 2.4, 1.5e20.
local NUMBER = "([%d_%.eE%+%-]+)"
local function num(text: string?): number
	return tonumber((string.gsub(text or "0", "_", ""))) or 0
end

type Machine = {
	id: string,
	cost: number,
	scale: number,
	production: number,
	growth: number,
	zone: number,
	rebirths: number,
	previousId: string?,
	previousLevel: number,
}
type Zone = { id: number, name: string, cost: number, cores: number, multiplier: number, rebirths: number }

-- The text of one `{ ... },` entry starting at `startAt` (entries are one tab-depth
-- deeper than their table, so the closing brace is the next "\n\t\t},").
local function entryFrom(startAt: number): string
	local finish = string.find(source, "\n\t\t},", startAt, true) or (startAt + 1500)
	return string.sub(source, startAt, finish)
end

local machines: { Machine } = {}
local zones: { Zone } = {}

do
	local machinesAt = string.find(source, "\n\tMachines = {", 1, true)
	assert(machinesAt, "Machines table not found")
	local machinesEnd = string.find(source, "\n\t},", machinesAt + 20, true) or #source
	local cursor = machinesAt
	while true do
		local startAt, endAt, id = string.find(source, 'Id = "(%w+)"', cursor)
		if startAt == nil or startAt > machinesEnd then
			break
		end
		local entry = entryFrom(startAt)
		if string.find(entry, "BaseProduction", 1, true) then
			table.insert(machines, {
				id = id,
				cost = num(string.match(entry, "BaseCost = " .. NUMBER)),
				scale = num(string.match(entry, "CostScale = " .. NUMBER)),
				production = num(string.match(entry, "BaseProduction = " .. NUMBER)),
				growth = num(string.match(entry, "Growth = " .. NUMBER)),
				zone = math.max(1, num(string.match(entry, "RequiredZone = (%d+)"))),
				rebirths = num(string.match(entry, "RequiredRebirths = (%d+)")),
				previousId = string.match(entry, 'PreviousId = "(%w+)"'),
				previousLevel = num(string.match(entry, "PreviousLevel = (%d+)")),
			})
		end
		cursor = endAt + 1
	end

	local zonesAt = string.find(source, "\n\tZones = {", 1, true)
	assert(zonesAt, "Zones table not found")
	local zonesEnd = string.find(source, "\n\t},", zonesAt + 20, true) or #source
	cursor = zonesAt
	while true do
		local startAt, endAt, id = string.find(source, "\n\t\t\tId = (%d+),", cursor)
		if startAt == nil or startAt > zonesEnd then
			break
		end
		local entry = entryFrom(startAt)
		table.insert(zones, {
			id = tonumber(id) :: number,
			name = string.match(entry, 'Name = "([^"]+)"') or `Zone {id}`,
			cost = num(string.match(entry, "\n\t\t\tCost = " .. NUMBER)),
			cores = num(string.match(entry, "CoreCost = " .. NUMBER)),
			multiplier = num(string.match(entry, "\n\t\t\tMultiplier = " .. NUMBER)),
			rebirths = num(string.match(entry, "RequiredRebirths = (%d+)")),
		})
		cursor = endAt + 1
	end
end
assert(#machines > 0 and #zones > 0, "could not parse machines/zones from " .. path)

local economy = {
	startingCash = num(string.match(source, "StartingCash = " .. NUMBER)),
	prestigeRequirement = num(string.match(source, "PrestigeRequirement = " .. NUMBER)),
	prestigeExponent = num(string.match(source, "PrestigeExponent = " .. NUMBER)),
	coreMultiplier = num(string.match(source, "CoreMultiplier = " .. NUMBER)),
	coreExponent = num(string.match(source, "CoreExponent = " .. NUMBER)),
	rebirthMultiplier = num(string.match(source, "\n\t\tRebirthMultiplier = " .. NUMBER)),
}

local function format(seconds: number): string
	if seconds < 90 then
		return string.format("%5.0fs", seconds)
	elseif seconds < 5400 then
		return string.format("%5.1fm", seconds / 60)
	elseif seconds < 172800 then
		return string.format("%5.1fh", seconds / 3600)
	end
	return string.format("%5.1fd", seconds / 86400)
end

local function costAt(machine: Machine, level: number): number
	return math.floor(machine.cost * machine.scale ^ level)
end
local function outputOf(machine: Machine, level: number): number
	if level <= 0 then
		return 0
	end
	return machine.production * level * (1 + machine.growth * (level - 1))
end

local levels: { [string]: number } = {}
local cash = economy.startingCash
local runCash = 0
local cores = 0
local rebirths = 0
local zoneIndex = 1 -- index into `zones` (sorted by id) the player currently works in
local now = 0
local runStart = 0

local rebirthAt: { number } = {}
local zoneAt: { [number]: number } = { [zones[1].id] = 0 }
local machineFirstBoughtAt: { [string]: number } = {}
local stalls: { { at: number, length: number, why: string } } = {}

local function multiplierFor(zone: Zone, coreCount: number, rebirthCount: number): number
	return zone.multiplier * (1 + economy.coreMultiplier * coreCount ^ economy.coreExponent + rebirthCount * economy.rebirthMultiplier)
end

local function available(machine: Machine): boolean
	if zones[zoneIndex].id < machine.zone or rebirths < machine.rebirths then
		return false
	end
	if machine.previousId ~= nil and (levels[machine.previousId] or 0) < machine.previousLevel then
		return false
	end
	return true
end

local function baseOutput(): number
	local sum = 0
	for _, machine in machines do
		sum += outputOf(machine, levels[machine.id] or 0)
	end
	return sum
end

local function prestigeReward(): number
	if runCash < economy.prestigeRequirement then
		return 0
	end
	return math.max(1, math.floor((runCash / economy.prestigeRequirement) ^ economy.prestigeExponent))
end

local guard = 0
while now < MAX_SECONDS and guard < 3_000_000 do
	guard += 1
	local zone = zones[zoneIndex]
	local multiplier = multiplierFor(zone, cores, rebirths)
	local income = baseOutput() * multiplier * (1 + TAP_SHARE)
	if income <= 0 then
		income = 1 -- the first machine comes from manual taps
	end

	-- Candidate 1: best-payback machine level (cost per extra output, in seconds).
	local machineTarget: Machine? = nil
	local machineCost = 0
	local machinePayback = math.huge
	for _, machine in machines do
		if available(machine) then
			local level = levels[machine.id] or 0
			local cost = costAt(machine, level)
			local gain = (outputOf(machine, level + 1) - outputOf(machine, level)) * multiplier * (1 + TAP_SHARE)
			if gain > 0 and cost / gain < machinePayback then
				machinePayback = cost / gain
				machineTarget = machine
				machineCost = cost
			end
		end
	end

	-- Candidate 2: the next zone, worth it when its payback beats the best machine.
	local nextZone = zones[zoneIndex + 1]
	local zoneWanted = false
	if nextZone ~= nil and rebirths >= nextZone.rebirths and cores >= nextZone.cores and nextZone.multiplier > zone.multiplier then
		local newIncome = baseOutput() * multiplierFor(nextZone, cores - nextZone.cores, rebirths) * (1 + TAP_SHARE)
		local gain = newIncome - income
		if gain > 0 and nextZone.cost / gain <= machinePayback then
			zoneWanted = true
		end
	end

	if machineTarget == nil and not zoneWanted then
		break
	end
	local targetCost = if zoneWanted then (nextZone :: Zone).cost else machineCost
	local wait = math.max(0, (targetCost - cash) / income)

	-- Rebirth instead of a long wait once it would meaningfully raise the core total.
	local reward = prestigeReward()
	if reward >= 1 and reward >= math.max(1, math.ceil(cores * REBIRTH_WHEN_GAIN_OF)) and now - runStart >= MIN_RUN_SECONDS and wait > 60 then
		cores += reward
		rebirths += 1
		table.insert(rebirthAt, now)
		table.clear(levels)
		cash = economy.startingCash
		runCash = 0
		runStart = now
		-- Zones are permanent unlocks; the player keeps working in the best one.
		continue
	end

	if wait > 900 then
		local what = if zoneWanted then `saving {string.format("%.3g", targetCost)} for {(nextZone :: Zone).name}` else `saving {string.format("%.3g", targetCost)} for {(machineTarget :: Machine).id} L{(levels[(machineTarget :: Machine).id] or 0) + 1}`
		table.insert(stalls, { at = now, length = wait, why = what })
	end
	now += wait
	local earned = wait * income
	cash += earned - targetCost
	runCash += earned
	if zoneWanted then
		cores -= (nextZone :: Zone).cores
		zoneIndex += 1
		zoneAt[zones[zoneIndex].id] = now
	else
		local machine = machineTarget :: Machine
		levels[machine.id] = (levels[machine.id] or 0) + 1
		if machineFirstBoughtAt[machine.id] == nil then
			machineFirstBoughtAt[machine.id] = now
		end
	end
end

print(`Pacing report for {path}`)
print(`{#machines} authored machines, {#zones} zones. Simulated {format(now)} of active play, {rebirths} rebirths, {string.format("%.3g", cores)} cores banked.\n`)

print("Zones (when first reached):")
for _, zone in zones do
	local at = zoneAt[zone.id]
	print(string.format("  %-2d %-18s x%-6.1f cash %-8s cores %-4d rebirths %-4d  %s", zone.id, zone.name, zone.multiplier, string.format("%.3g", zone.cost), zone.cores, zone.rebirths, if at ~= nil then format(at) else "not reached"))
end

print("\nMachines (first bought):")
for _, machine in machines do
	local bought = machineFirstBoughtAt[machine.id]
	print(string.format("  %-16s zone %-2d rebirths %-3d after %-15s L%-3d  %s", machine.id, machine.zone, machine.rebirths, machine.previousId or "-", machine.previousLevel, if bought ~= nil then format(bought) else "not reached"))
end

print("\nRebirth timeline:")
for _, mark in { 1, 2, 3, 5, 8, 12, 18, 25, 32, 40, 50, 60, 72 } do
	local at = rebirthAt[mark]
	if at ~= nil then
		local previous = rebirthAt[mark - 1] or 0
		print(string.format("  rebirth #%-3d at %s   (%s after the previous)", mark, format(at), format(at - previous)))
	end
end

table.sort(stalls, function(a, b)
	return a.length > b.length
end)
print("\nLongest saves (>15 min without a purchase):")
for index = 1, math.min(6, #stalls) do
	local stall = stalls[index]
	print(string.format("  at %s  %s  %s", format(stall.at), format(stall.length), stall.why))
end
if #stalls == 0 then
	print("  none")
end
