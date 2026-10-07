--!strict
-- Purpose: Idempotently refund unfinished legacy stakes when moving to the score-only public arcade.
-- Owner: Astral Forge persistence. Dependencies: injected big-number math. Last-reviewed: 2026-10-05.
export type Money = number | string
export type LegacyRound = { Active: boolean?, Stake: Money? }
export type LegacyCasino = { Flip: LegacyRound?, HighLow: LegacyRound? }
export type Record = { Schema: number, At: number, Refunded: Money, Rounds: number }
export type Profile = { Cash: Money, Casino: LegacyCasino?, ArcadeMigration: Record? }
export type MathProvider = { Add: (Money, Money) -> Money, Persist: (Money) -> Money }
export type API = { apply: (profile: Profile, mathProvider: MathProvider, now: number) -> Record }

local function valid(value: Money?): Money
	if type(value) == "number" then
		return if value == value and value >= 0 and value < math.huge then value else 0
	elseif type(value) == "string" and #value <= 40 and value:match("^[%d%.eE%+]+$") then
		local numeric = tonumber(value)
		return if numeric and numeric == numeric and numeric >= 0 then value else 0
	end
	return 0
end

local function apply(profile: Profile, mathProvider: MathProvider, now: number): Record
	local previous = profile.ArcadeMigration
	if previous and previous.Schema >= 1 then
		return table.clone(previous)
	end
	local refund: Money = 0
	local rounds = 0
	local casino = profile.Casino
	if casino then
		for _, round in { casino.Flip, casino.HighLow } do
			if round and round.Active then
				refund = mathProvider.Add(refund, valid(round.Stake))
				rounds += 1
			end
		end
	end
	-- Calculate all values before changing the profile. Existing statistics and earned balances are preserved.
	local credited = mathProvider.Add(profile.Cash, refund)
	local record: Record = { Schema = 1, At = now, Refunded = mathProvider.Persist(refund), Rounds = rounds }
	profile.Cash = credited
	profile.ArcadeMigration = record
	if casino then
		if casino.Flip then
			casino.Flip.Active, casino.Flip.Stake = false, 0
		end
		if casino.HighLow then
			casino.HighLow.Active, casino.HighLow.Stake = false, 0
		end
	end
	return table.clone(record)
end

local api: API = { apply = apply }
return table.freeze(api)
