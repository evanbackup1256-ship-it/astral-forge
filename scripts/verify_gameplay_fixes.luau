--!nocheck
-- Regression checks for the day-b gameplay bug hunt (batch 45+), run from the compiled TS (out/)
-- through scripts/_server_harness. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local Progression = H.load("Server/AstralForge/Services/Gameplay/Progression")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local CommandMath = H.load("Server/AstralForge/Modules/CommandMath")
local day = math.floor(os.time() / 86400)

-- daily preview matches the claim when a streak shield covers a missed day
do
	local p = DataTemplate.New()
	p.Daily.LastClaimDay = day - 2
	p.Daily.Streak = 4
	p.Command.StreakShields = 1
	local preview = Progression.DailyState(p)
	check(preview.CanClaim and preview.NextStreak == 5, "shielded preview keeps the streak (got " .. tostring(preview.NextStreak) .. ")")
	local ok = Progression.ClaimDaily(p)
	check(ok and p.Daily.Streak == preview.NextStreak, "claim lands on the previewed streak")
	check(p.Command.StreakShields == 0, "shield spent")

	local q = DataTemplate.New()
	q.Daily.LastClaimDay = day - 3
	q.Daily.Streak = 4
	q.Command.StreakShields = 0
	local reset = Progression.DailyState(q)
	check(reset.NextStreak == 1, "no shield: preview resets")
	Progression.ClaimDaily(q)
	check(q.Daily.Streak == reset.NextStreak, "no shield: claim matches preview")
end

-- batch 46: one shield per missed day; too few shields resets and spends none
do
	local p = DataTemplate.New()
	p.Daily.LastClaimDay = day - 4 -- three missed days
	p.Daily.Streak = 6
	p.Command.StreakShields = 2
	check(Progression.DailyState(p).NextStreak == 1, "two shields can't cover three missed days")
	Progression.ClaimDaily(p)
	check(p.Daily.Streak == 1 and p.Command.StreakShields == 2, "reset keeps the shields")

	local q = DataTemplate.New()
	q.Daily.LastClaimDay = day - 4
	q.Daily.Streak = 6
	q.Command.StreakShields = 5
	check(Progression.DailyState(q).NextStreak == 7, "enough shields: preview keeps the streak")
	Progression.ClaimDaily(q)
	check(q.Daily.Streak == 7 and q.Command.StreakShields == 2, "three missed days spend three shields")

	local fresh = DataTemplate.New()
	fresh.Command.StreakShields = 3
	Progression.ClaimDaily(fresh)
	check(fresh.Daily.Streak == 1 and fresh.Command.StreakShields == 3, "first ever claim spends no shields")
end

-- batch 46: Lab power only counts cells the player still owns
do
	local Lab = H.load("Server/AstralForge/Services/Gameplay/Lab")
	local LabMath = H.load("Server/AstralForge/Modules/LabOrderMath")
	local p = DataTemplate.New()
	p.Rebirths = 200
	Lab.Ensure(p, 1)
	local order = LabMath.CHANNEL_ORDER
	local power = GameConfig.Lab.Power
	p.Lab.Routing[order[1]] = power.MaxCells
	p.Rebirths = 0 -- after an ascension
	local per = power.Channels[order[1]].EffectPerCell
	check(Lab.PowerEffect(p, order[1]) == power.BaseCells * per, "routed cells above the owned count give nothing")
	for i = 2, #order do
		check(Lab.PowerEffect(p, order[i]) == 0, "later rails get no phantom cells")
	end
end

-- batch 48: trades can't push Stardust or Cores past the 1e14 save clamp
do
	local Suite = H.load("Server/AstralForge/Modules/TradeSuite")
	local Exchange, OfferMath = Suite.TradeExchange, Suite.TradeOfferMath
	local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
	local function bag(raw) return OfferMath.CopyOffer(raw, Exchange.CURRENCIES, Exchange.BOOST_IDS, Exchange.KEY_IDS) end
	local function receiver(dust, cores)
		local p = DataTemplate.New()
		p.Stardust, p.Cores = dust, cores
		return p
	end
	local now = os.time()
	local full = receiver(1e14 - 5, 0)
	check(Exchange.ApplyExchange(GameConfig, Omega, full, bag({}), bag({ Stardust = 10 }), nil, nil, now) ~= nil, "Stardust past the cap refused")
	check(full.Stardust == 1e14 - 5, "refused trade leaves Stardust alone")
	local coreFull = receiver(0, 1e14 - 1)
	check(Exchange.ApplyExchange(GameConfig, Omega, coreFull, bag({}), bag({ Cores = 2 }), nil, nil, now) ~= nil, "Cores past the cap refused")
	local fine = receiver(100, 5)
	check(Exchange.ApplyExchange(GameConfig, Omega, fine, bag({}), bag({ Stardust = 10, Cores = 1 }), nil, nil, now) == nil, "normal trade applies")
	check(fine.Stardust == 110 and fine.Cores == 6, "normal trade credits")
end

-- batch 48: Bazaar supply requests can be placed again once they expire
do
	local Bazaar = H.load("Server/AstralForge/Services/Gameplay/Bazaar")
	local BMath = H.load("Server/AstralForge/Modules/BazaarMath")
	local p = DataTemplate.New()
	p.Bazaar = BMath.Ensure(p.Bazaar)
	p.Bazaar.Counters.Deals = 1e6
	local id = BMath.CATALOG[1].Id
	local now = os.time()
	check((Bazaar.Procure(p, { Id = id }, now)), "request placed")
	check(not (Bazaar.Procure(p, { Id = id }, now)), "same open request refused")
	local later = now + (BMath.PROCURE_BUCKETS + 2) * BMath.MARKET_SECONDS
	check((Bazaar.Procure(p, { Id = id }, later)), "expired request can be placed again")
end

-- weekly targets stay fixed when the commander levels up mid-week
do
	local p = DataTemplate.New()
	p.Command.XP = 0
	Progression.EnsureWeekly(p)
	local before = Progression.WeeklyState(p)[1].Target
	p.Command.XP = 1e9
	local after = Progression.WeeklyState(p)[1].Target
	check(before == after, string.format("weekly target held mid-week (%s -> %s)", tostring(before), tostring(after)))
	check(type(p.Command.Weekly.Scale) == "number", "new week stores its scale")

	-- a week saved before Scale existed gets it backfilled, keeping old saves loadable
	local old = DataTemplate.New()
	old.Command.Weekly = { Week = p.Command.Weekly.Week, Baseline = {}, Claimed = {} }
	check(Progression.EnsureWeekly(old) == true and type(old.Command.Weekly.Scale) == "number", "old week backfills Scale")
	local ensured = CommandMath.Ensure(old.Command, GameConfig.Operations.SeasonId)
	check(type(ensured.Weekly.Scale) == "number", "CommandMath keeps Scale")
end

-- production only counts lab cells the player still owns (routing can outlive a cell drop)
do
	local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
	local p = DataTemplate.New()
	p.Rebirths = 0 -- 12 base cells
	p.Lab = p.Lab or {}
	p.Lab.Routing = { Production = 20, Storage = 0, Tap = 0 }
	local effect = Economy.LabPowerEffect(p, "Production")
	check(math.abs(effect - 12 * 0.04) < 1e-9, "lab production clamps to owned cells (got " .. tostring(effect) .. ")")
	p.Lab.Routing = { Production = 6, Storage = 10, Tap = 0 }
	check(math.abs(Economy.LabPowerEffect(p, "Storage") - 6 * 0.07) < 1e-9, "later rails get what is left")
	p.Lab.Routing = { Production = 0 / 0, Storage = 0, Tap = 0 }
	check(Economy.LabPowerEffect(p, "Production") == 0, "NaN routing gives nothing")
end

-- weekly board: scores are keyed by the week they were earned, ranks wait for late pushes
do
	local WB = H.load("Shared/AstralForge/Shared/WeeklyBoard")
	check(WB.weekFromKey(WB.pendingKey(2900)) == 2900, "pending key round trip")
	check(WB.weekFromKey(WB.pendingKey(-3)) == -3, "pending key negative week")
	check(WB.weekFromKey("Weekly") == nil and WB.weekFromKey("Rebirths@5") == nil, "other boards are not week keys")
	local ends = WB.weekEndsAt(2900)
	check(not WB.ranksSettled(2900, ends + 5), "ranks not final right after the week ends")
	check(WB.ranksSettled(2900, ends + WB.SETTLE_SECONDS), "ranks final after the settle window")
end

if #failures > 0 then
	error("gameplay fixes failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] gameplay fixes: %d checks passed", checks))
