--!nocheck
-- Headless playthrough of the live economy. Drives the real compiled EconomyMath, GameConfig,
-- RebirthMath and ForgePath rules (out/, loaded through _server_harness) with a simple player
-- policy, so pacing regressions show up as a moved milestone. Run `npx rbxtsc` first.
--
-- Policy: two active sessions a day (taps ~4/s with a held combo, banks whenever the vault is
-- 80% full, buys the best payback upgrade, unlocks worlds as soon as they're open), offline for
-- the rest of the day through the real OfflineEarnings, one lab order per 8 active minutes, the
-- daily login track, Forge Path XP from banking with its daily soft cap, Stardust into the star
-- grid, and a rebirth when the payout would at least add half the cores already held or the run
-- has stalled. Not modelled: relics/crate drops (no Robux-free crate source to model), guilds,
-- trades, anomalies, live events (multiplier left at 1), domains, continuum. v8 features: TODO.
local H = require("./_server_harness")
local Kit = H.load("Server/AstralForge/Modules/EconomyMath")
local Economy = Kit("Economy")
local Gate = Kit("ProgressionGate")
local ForgePathClaim = Kit("ForgePathClaim")
local G = H.load("Shared/AstralForge/Shared/GameConfig")
local RebirthMath = H.load("Shared/AstralForge/Shared/RebirthMath")

local N = Economy.AsNumber
local Sim = {}

-- the roster is ~2,800 machines; only the ones whose world is open can ever be bought
local MACHINES = {}
for _, m in G.Machines do table.insert(MACHINES, m) end
table.sort(MACHINES, function(a, b) return (a.RequiredZone or 1) < (b.RequiredZone or 1) end)
local CORE_RESEARCH = { "Efficiency", "Storage", "Offline", "Overcharge", "Critical", "Automation", "Insight", "Impact" }
local RESEARCH_GAIN = { Efficiency = true, Storage = true, Automation = true, Insight = true, Offline = true }

local function newProfile(t0)
	return {
		Cash = G.Economy.StartingCash, Vault = 0, RunCash = 0, LifetimeCash = 0,
		Cores = 0, Stardust = 0, Rebirths = 0, Zone = 1, CurrentZone = 1,
		Machines = { StellarCore = 1 }, Research = {}, GridUpgrades = {},
		ForgePath = { ClaimedSteps = {}, XP = 0, XPDay = -1, XPEarnedToday = 0 },
		Stats = { MachinesBought = 0, ResearchBought = 0 },
		ActiveBoost = { Id = "", EndsAt = 0 },
	}
end

-- income per second for an active player at this moment (production + taps, before vault caps)
local function income(p, now, tapsPerSecond)
	local prod = N(Economy.Production(p, now))
	local tap = N(Economy.TapPower(p, now))
	local crit = math.clamp(Economy.CriticalChance(p), 0, 1)
	local critMul = Economy.CriticalMultiplier(p)
	local combo = 1 + G.Overcharge.ComboBonusPerStack * G.Overcharge.ComboMax
	return prod + tap * tapsPerSecond * combo * (1 + crit * (critMul - 1)), prod
end

local function gated(p, def, levels)
	return Gate.UpgradeReason(p, def, levels) ~= nil
end

-- best payback purchase among machines and the core research lines; returns kind, id, cost
local function bestPurchase(p, now, tapsPerSecond)
	local base = income(p, now, tapsPerSecond)
	local best, bestScore
	local function consider(kind, id, cost, gain)
		if cost == math.huge or cost ~= cost or cost <= 0 then return end
		local score
		if gain and gain > 0 then score = cost / gain else return end
		if bestScore == nil or score < bestScore then best, bestScore = { kind, id, cost }, score end
	end
	for _, m in MACHINES do
		if (m.RequiredZone or 1) > p.Zone then break end
		if (m.RequiredRebirths or 0) <= p.Rebirths and not gated(p, m, p.Machines) then
			local lv = p.Machines[m.Id] or 0
			local cost = N(Economy.MachineCost(m.Id, lv))
			if cost <= N(p.Cash) * 50 then
				p.Machines[m.Id] = lv + 1
				local after = income(p, now, tapsPerSecond)
				p.Machines[m.Id] = lv > 0 and lv or nil
				consider("Machine", m.Id, cost, after - base)
			end
		end
	end
	for _, id in CORE_RESEARCH do
		local def = Economy.GetResearch(id)
		if def and not gated(p, def, p.Research) then
			local lv = p.Research[id] or 0
			local cost = N(Economy.ResearchCost(id, lv))
			if cost <= N(p.Cash) * 50 then
				local gain
				if id == "Storage" or id == "Automation" or id == "Offline" then
					-- utility lines: value them as a slice of income so they get bought steadily
					gain = base * (lv < 10 and 0.08 or 0.03)
				else
					p.Research[id] = lv + 1
					gain = income(p, now, tapsPerSecond) - base
					p.Research[id] = lv > 0 and lv or nil
					if id == "Insight" then gain = base * 0.02 end
				end
				consider("Research", id, cost, gain)
			end
		end
	end
	return best
end

local function buy(p, pick, log)
	local kind, id, cost = pick[1], pick[2], pick[3]
	if N(p.Cash) < cost then return false end
	p.Cash = N(p.Cash) - cost
	if kind == "Machine" then
		p.Machines[id] = (p.Machines[id] or 0) + 1
		p.Stats.MachinesBought += 1
		if (p.Machines[id] == 1) and log then log("machine", id) end
	else
		p.Research[id] = (p.Research[id] or 0) + 1
		p.Stats.ResearchBought += 1
	end
	return true
end

local function tryZone(p, log)
	local nextZone = Economy.GetZone(p.Zone + 1)
	if nextZone == nil then return false end
	if p.Rebirths >= (nextZone.RequiredRebirths or 0) and N(p.Cores) >= (nextZone.CoreCost or 0) and N(p.Cash) >= N(nextZone.Cost) then
		p.Cash = N(p.Cash) - N(nextZone.Cost)
		p.Zone += 1
		p.CurrentZone = p.Zone
		if log then log("zone", p.Zone) end
		return true
	end
	return false
end

-- spend Stardust on the cheapest open grid node (a frontier walk: a node opens once its parent
-- reaches the level the real gate asks for, so only open nodes are priced)
local GRID_ROOTS, GRID_CHILDREN = {}, {}
for _, g in G.GridUpgrades do
	if g.PreviousId == nil then
		table.insert(GRID_ROOTS, g)
	else
		GRID_CHILDREN[g.PreviousId] = GRID_CHILDREN[g.PreviousId] or {}
		table.insert(GRID_CHILDREN[g.PreviousId], g)
	end
end
local function spendGrid(p, stats)
	local open, seen = {}, {}
	local function visit(g)
		if seen[g.Id] or (g.RequiredRebirths or 0) > p.Rebirths then return end
		if gated(p, g, p.GridUpgrades) then return end
		seen[g.Id] = true
		table.insert(open, g)
		if (p.GridUpgrades[g.Id] or 0) > 0 then
			for _, child in GRID_CHILDREN[g.Id] or {} do visit(child) end
		end
	end
	for _, g in GRID_ROOTS do visit(g) end
	for _ = 1, 2000 do
		local best, bestCost
		for _, g in open do
			local lv = p.GridUpgrades[g.Id] or 0
			if lv < (g.MaxLevel or math.huge) then
				local cost = N(Economy.GridUpgradeCost(g.Id, lv))
				if bestCost == nil or cost < bestCost then best, bestCost = g, cost end
			end
		end
		if best == nil or bestCost > p.Stardust then break end
		p.Stardust -= bestCost
		p.GridUpgrades[best.Id] = (p.GridUpgrades[best.Id] or 0) + 1
		stats.StardustSpent += bestCost
		for _, child in GRID_CHILDREN[best.Id] or {} do visit(child) end
	end
end

local function grant(p, reward, prod, stats)
	if reward.Cash then p.Cash = N(p.Cash) + reward.Cash; p.RunCash = N(p.RunCash) + reward.Cash end
	if reward.CashMinutes then
		local c = reward.CashMinutes * 60 * prod
		p.Cash = N(p.Cash) + c; p.RunCash = N(p.RunCash) + c
	end
	if reward.Stardust then p.Stardust += reward.Stardust; stats.StardustEarned += reward.Stardust end
	if reward.Cores then p.Cores = N(p.Cores) + reward.Cores; stats.BonusCores += reward.Cores end
	if reward.Boost and G.Boosts[reward.Boost] then stats.Boosts += 1 end
end

local function forgePathXP(p, amount, day)
	local fp = p.ForgePath
	if fp.XPDay ~= day then fp.XPDay = day; fp.XPEarnedToday = 0 end
	local v = ForgePathClaim.XpFromBankedAmount(amount, G.Economy.ForgePathXP)
	if fp.XPEarnedToday >= G.Economy.ForgePathXP.DailySoftCap then v = math.floor(v * G.Economy.ForgePathXP.SoftCapScale) end
	fp.XPEarnedToday += v
	fp.XP += v
end

local function claimForgePath(p, prod, stats, log)
	local fp = p.ForgePath
	local steps = G.ForgePath.Steps
	for _, s in steps do
		if not fp.ClaimedSteps[tostring(s.Step)] then
			if fp.XP < s.XPCost then break end
			local ok = ForgePathClaim.TryClaim(fp, s.Step, steps)
			if not ok then break end
			grant(p, s.Reward, prod, stats)
			stats.ForgePathStep = s.Step
			if log and s.Step % 10 == 0 then log("forgepath", s.Step) end
		end
	end
end

function Sim.run(opts)
	opts = opts or {}
	local days = opts.Days or 14
	local sessions = opts.Sessions or { { Start = 18 * 3600, Length = 3600 }, { Start = 8 * 3600, Length = 2700 } }
	local taps = opts.TapsPerSecond or 4
	local dt = opts.Step or 2
	local t0 = 1_800_000_000
	local p = newProfile(t0)
	local ledger = RebirthMath.ensure(nil, t0, 0)
	local stats = { StardustEarned = 0, StardustSpent = 0, BonusCores = 0, PrestigeCores = 0, Boosts = 0, ForgePathStep = 0, OfflineCash = 0, ActiveCash = 0, Rebirths = {} }
	local events = {}
	local now = t0
	local activeSeconds = 0
	local function log(kind, value)
		table.insert(events, { Kind = kind, Value = value, At = now - t0, Active = activeSeconds, Rebirths = p.Rebirths })
	end
	local lastPurchaseAt = now
	local orderTimer = 0
	local lastSeen = now
	local todayLogin = -1
	local streak = 0

	local function rebirthIfWorth()
		local bank = N(p.RunCash) + N(p.Vault)
		local reward = N(Economy.PrestigeReward(bank))
		if reward < 1 then return false end
		local stalled = now - lastPurchaseAt > (opts.StallSeconds or 900)
		local worth = reward >= math.max(1, N(p.Cores) * (opts.RebirthGain or 0.5))
		if opts.SpamRebirth then
			-- farm the rebirth count once the next world's rebirth gate is what blocks progress
			local nextZone = Economy.GetZone(p.Zone + 1)
			if nextZone and p.Rebirths < (nextZone.RequiredRebirths or 0) then worth = true end
		end
		if not (worth or stalled) then return false end
		local dust = math.clamp(math.max(G.Economy.Rebirth.StardustMinimum, math.floor(math.sqrt(reward) * G.Economy.Rebirth.StardustSqrtScale)), 0, 1e14)
		local run = { Seconds = now - ledger.RunStartedAt, Zone = p.Zone, MachineKinds = 0, Ratio = bank / G.Economy.PrestigeRequirement }
		local q = RebirthMath.quote(ledger, { Cores = reward, Stardust = dust }, run)
		local cores = math.max(1, math.floor(reward * q.CoreMultiplier))
		p.Cores = N(p.Cores) + cores
		p.Stardust += q.Stardust
		stats.StardustEarned += q.Stardust
		stats.PrestigeCores += cores
		local carried = RebirthMath.carry(ledger, p.Machines, N(p.Vault), G.Economy.StartingCash, function(id)
			local m = Economy.GetMachine(id)
			return m ~= nil and (m.RequiredZone or 1) <= 1 and (m.RequiredRebirths or 0) <= p.Rebirths + 1
		end)
		RebirthMath.close(ledger, q, now, nil, nil)
		p.Rebirths += 1
		p.Cash = carried.Cash; p.Vault = 0; p.RunCash = 0; p.Zone = 1; p.CurrentZone = 1
		p.Machines = carried.Machines
		local mlv = 0 for _, l in p.Machines do mlv += l end
		table.insert(stats.Rebirths, { N = p.Rebirths, At = now - t0, Active = activeSeconds, Cores = cores, Stardust = q.Stardust, TotalCores = p.Cores, Bank = bank, Zone = run.Zone, Grid = Economy.GridEffect(p, "GridProduction"), Eff = p.Research.Efficiency or 0, Over = p.Research.Overcharge or 0, CoreMult = q.CoreMultiplier, Seconds = run.Seconds, Kept = mlv })
		lastPurchaseAt = now
		spendGrid(p, stats)
		return true
	end

	for day = 0, days - 1 do
		local dayStart = t0 + day * 86400
		local ordered = table.clone(sessions)
		table.sort(ordered, function(a, b) return a.Start < b.Start end)
		for _, s in ordered do
			local sStart = dayStart + s.Start
			-- offline stretch up to this session, through the real offline projection
			if sStart > lastSeen then
				local reward = N((Economy.OfflineEarnings(p, lastSeen, sStart)))
				if reward > 0 then
					p.Cash = N(p.Cash) + reward; p.RunCash = N(p.RunCash) + reward; p.LifetimeCash = N(p.LifetimeCash) + reward
					stats.OfflineCash += reward
				end
			end
			now = sStart
			-- daily login track
			if todayLogin ~= day then
				todayLogin = day
				streak += 1
				local track = G.DailyRewards
				local _, prod = income(p, now, 0)
				grant(p, track[((streak - 1) % #track) + 1], prod, stats)
			end
			spendGrid(p, stats)
			local sEnd = sStart + s.Length
			local bankTimer = 0
			while now < sEnd do
				local inc, prod = income(p, now, taps)
				local cap = N(Economy.Capacity(p, now))
				local tapPart = inc - prod
				-- production and taps fill the vault; taps stop when full
				local vault = math.min(cap, N(p.Vault) + inc * dt)
				local auto = Economy.AutoCollectRate(p)
				local collected = 0
				if auto > 0 then
					collected = math.min(vault, math.max(vault * auto * dt, prod * dt * auto))
					vault -= collected
				end
				bankTimer += dt
				if vault >= cap * 0.8 or bankTimer >= 10 then
					collected += vault
					if vault > 0 then forgePathXP(p, vault, day) end
					vault = 0
					bankTimer = 0
				end
				p.Vault = vault
				p.Cash = N(p.Cash) + collected; p.RunCash = N(p.RunCash) + collected; p.LifetimeCash = N(p.LifetimeCash) + collected
				stats.ActiveCash += collected
				orderTimer += dt
				if orderTimer >= 480 then
					orderTimer = 0
					local orders = G.Lab.Orders
					local o = orders[(math.floor(now / 480) % #orders) + 1]
					grant(p, o.Reward, prod, stats)
				end
				claimForgePath(p, prod, stats, log)
				local guard = 0
				while guard < (opts.BuysPerStep or 6) do
					guard += 1
					if tryZone(p, log) then lastPurchaseAt = now continue end
					local pick = bestPurchase(p, now, taps)
					if pick == nil or not buy(p, pick, log) then break end
					lastPurchaseAt = now
				end
				if rebirthIfWorth() then log("rebirth", p.Rebirths) end
				now += dt
				activeSeconds += dt
			end
			lastSeen = now
		end
	end
	return {
		Profile = p, Stats = stats, Events = events, ActiveSeconds = activeSeconds,
		Production = N(Economy.Production(p, now)), Multiplier = N(Economy.PermanentMultiplier(p)),
	}
end

return Sim
