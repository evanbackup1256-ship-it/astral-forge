--!strict


local WEEK = 7 * 24 * 60 * 60
local EPOCH = 1_767_225_600

local Config = {
	ManifestVersion = 1,
	Season = { Id = "DEEP_SPACE_01", Name = "DEEP SPACE COMMAND" },
	Convergence = {
		Name = "FORGE CONVERGENCE",
		CycleSeconds = WEEK,
		Epoch = EPOCH,
		GlobalPhases = {
			{ Target = 500, Name = "IGNITION", ProductionMultiplier = 1.02 },
			{ Target = 2_500, Name = "TEMPERED", ProductionMultiplier = 1.05 },
			{ Target = 10_000, Name = "RESONANT", ProductionMultiplier = 1.10 },
			{ Target = 40_000, Name = "CELESTIAL", ProductionMultiplier = 1.18 },
		},
		PersonalTiers = {
			{ Required = 20, Reward = { Cash = 5_000, Stardust = 15 } },
			{ Required = 75, Reward = { Cash = 25_000, Stardust = 35, Cores = 1 } },
			{ Required = 200, Reward = { Cash = 100_000, Stardust = 75, Signals = 20 } },
			{ Required = 500, Reward = { Cash = 500_000, Stardust = 150, Cores = 3, Boost = "Hyperdrive" } },
		},
		ContributionByAction = {
			CollectVault = 1, BuyMachine = 2, BuyResearch = 3, BuyGridUpgrade = 4,
			PulseAnomaly = 1, StabilizeAnomaly = 8, ClaimLabOrder = 7,
			Rebirth = 25, DomainExpansion = 100,
		},
	},
}

function Config.CurrentConvergence(now: number?)
	local timestamp = math.max(EPOCH, math.floor(now or os.time()))
	local cycle = math.floor((timestamp - EPOCH) / WEEK)
	local startsAt = EPOCH + cycle * WEEK
	return {
		EventId = "CONVERGENCE_" .. tostring(cycle),
		Name = Config.Convergence.Name,
		StartsAt = startsAt,
		EndsAt = startsAt + WEEK,
	}
end

return table.freeze(Config)
