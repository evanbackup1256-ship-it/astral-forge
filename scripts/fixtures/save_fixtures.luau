--!nocheck
-- Old save shapes for verify_save_fixtures. Each fixture is what a DataStore document of that era
-- held. `transformed` lists paths that a migration converts on purpose (checked by `expect`
-- instead of by the no-data-loss rule).
local function strip(t, paths)
	for _, path in paths do
		local node, last = t, nil
		local parts = string.split(path, ".")
		for i = 1, #parts - 1 do node = node[parts[i]] if node == nil then break end end
		if node ~= nil then node[parts[#parts]] = nil end
	end
	return t
end

return function(DataTemplate, GameConfig)
	local fixtures = {}
	local function add(f) table.insert(fixtures, f) end

	-- v0: the first live saves. No DataVersion, a handful of fields, boolean-only settings.
	add({
		name = "v0 first live save",
		save = {
			Cash = 12345, Rebirths = 2, Zone = 3, CurrentZone = 2,
			Machines = { StellarCore = 14, LunarExtractor = 6 },
			Research = { Efficiency = 3 },
			Settings = { SoundEffects = false, UIEffects = false, ReducedMotion = true },
			Flags = { TutorialDone = true, InfiniteMoney = false },
			Meta = { Revision = 40 },
		},
		transformed = { ["Settings.SoundEffects"] = true, ["Settings.UIEffects"] = true, ["Settings.ReducedMotion"] = true },
		expect = {
			["Settings.SoundVolume"] = 0, ["Settings.EffectsIntensity"] = 0, ["Settings.MotionIntensity"] = 0,
			["Settings.SoundEffects"] = false, ["Settings.UIEffects"] = false, ["Settings.ReducedMotion"] = true,
			["Flags.TutorialRewardClaimed"] = true,
			["Items.Rigs.Lit"] = {},
		},
	})

	-- v4: settings still booleans, stored with an explicit (string) version as some 4.x saves were
	add({
		name = "v4 string version, boolean settings",
		save = {
			DataVersion = "4", Cash = 900, Stardust = 40,
			Settings = { SoundEffects = false, UIEffects = true, ReducedMotion = false },
		},
		transformed = { ["DataVersion"] = true, ["Settings.SoundEffects"] = true },
		expect = { ["Settings.SoundVolume"] = 0, ["Settings.SoundEffects"] = false, ["Settings.UIEffects"] = true, Stardust = 40 },
	})

	-- v5+: slider settings exist; the old booleans are derived, never re-applied
	add({
		name = "v6 slider settings",
		save = {
			DataVersion = 6, Cash = 1, Settings = { SoundEffects = false, SoundVolume = 0.4, EffectsIntensity = 0.9, MotionIntensity = 0.5 },
		},
		transformed = { ["Settings.SoundEffects"] = true },
		expect = { ["Settings.SoundVolume"] = 0.4, ["Settings.SoundEffects"] = true },
	})

	-- v9: the Domain node tree before the lattice; spent points come back as SkillPoints
	add({
		name = "v9 domain node tree",
		save = {
			DataVersion = 9, Cash = 5e6, Rebirths = 30,
			Domain = { Rank = 4, SkillPoints = 2, Nodes = { Root = 1 }, TotalRebirthsSpent = 12 },
			Flags = { InfiniteMoney = true },
		},
		transformed = { ["Domain.SkillPoints"] = true, ["Flags.InfiniteMoney"] = true },
		expect = {
			["Domain.Nodes"] = nil, ["Domain.Rank"] = 4,
			["Domain.SkillPoints"] = function(v) return type(v) == "number" and v >= 2 end,
			["Flags.InfiniteMoney"] = nil, ["Flags.UnlimitedMoney"] = true,
		},
	})

	-- v12: the retired Infinite mode with a legacy snapshot that was larger than the live run
	add({
		name = "v12 retired Infinite legacy",
		save = {
			DataVersion = 12, Cash = 100, Cores = 3, Rebirths = 1, Zone = 1,
			Infinite = { Active = true, Legacy = { Cash = 8e9, Cores = 77, Rebirths = 9, World = 6, LifetimeCash = 9e9 } },
			Dungeons = { Floor = 3 }, Minigames = {}, Encounters = {},
		},
		transformed = { Cash = true, Cores = true, Rebirths = true, Zone = true },
		expect = {
			Cash = 8e9, Cores = 77, Rebirths = 9, Zone = 6, Infinite = nil, Dungeons = nil, Minigames = nil, Encounters = nil,
		},
	})

	-- v17: Omega-string currency, relics with stars, numeric ForgePath step keys
	add({
		name = "v17 omega cash, starred relics",
		save = {
			DataVersion = 17,
			Cash = "1.500000000000e30", LifetimeCash = "2.000000000000e31", Vault = 5,
			Machines = { StellarCore = 200 },
			Items = {
				NextId = 3, Essence = 55,
				Inventory = {
					IT0000001 = { DefinitionId = "IonCoupler", Level = 7, AcquiredAt = 100, Stars = 2, Locked = true },
					IT0000002 = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 101 },
				},
				Equipped = { ["Machine:StellarCore"] = "IT0000001" },
				Keys = { ForgeCrate = 4, RetiredCrate = 9 },
			},
			ForgePath = { ClaimedSteps = { [1] = true, [2] = true }, XP = 30 },
		},
		transformed = { ["Items.Keys.RetiredCrate"] = true, ["ForgePath.ClaimedSteps"] = true },
		expect = {
			Cash = "1.500000000000e30",
			["Items.Inventory.IT0000001.Stars"] = 2,
			["Items.Inventory.IT0000001.Locked"] = true,
			["Items.Equipped.Machine:StellarCore"] = "IT0000001",
			["Items.Keys.RetiredCrate"] = nil,
			["ForgePath.ClaimedSteps"] = { ["1"] = true, ["2"] = true },
		},
	})

	-- v20 pre-rigs: the full previous-release shape, without Items.Rigs or the rebirth ledger
	do
		local save = DataTemplate.New()
		save.DataVersion = 20
		save.Cash = 777777
		save.Rebirths = 14
		save.Items.Inventory = { IT0000009 = { DefinitionId = "IonCoupler", Level = 4, AcquiredAt = 5 } }
		save.Items.NextId = 10
		save.Machines = { StellarCore = 50 }
		strip(save, { "Items.Rigs", "Rebirth", "Foundry", "Ascension" })
		add({
			name = "v20 pre-rigs release save",
			save = save,
			expect = {
				["Items.Rigs.Lit"] = {},
				["Items.Inventory.IT0000009.Level"] = 4,
				Rebirth = function(v) return type(v) == "table" end,
				Rebirths = 14,
			},
		})
	end

	-- v21 current with a damaged rigs ledger: unknown rigs and non-true values are dropped
	do
		local save = DataTemplate.New()
		save.Items.Rigs = { Lit = { Dock = true, NotARig = true, Shelf = "yes" } }
		add({
			name = "v21 damaged rig ledger",
			save = save,
			transformed = { ["Items.Rigs.Lit.NotARig"] = true },
			expect = { ["Items.Rigs.Lit"] = { Dock = true } },
		})
	end

	-- v21 junk: wrong types everywhere fall back to defaults instead of erroring
	add({
		name = "v21 wrong-typed fields",
		save = {
			DataVersion = 21, Cash = "not a number", Stardust = -50, Cores = 0 / 0, Items = "x", Settings = 5,
			Machines = { StellarCore = -3, Nope = 4 }, Trade = { Sent = "x" },
		},
		transformed = { Machines = true, Stardust = true, Cores = true },
		expect = { ["Machines.StellarCore"] = 1, Stardust = 0, Cores = 0, ["Items.Rigs.Lit"] = {}, ["Machines.Nope"] = nil },
	})

	-- v21 a pristine new profile round-trips unchanged apart from load-time stamps
	add({ name = "v21 fresh template", save = DataTemplate.New() })
	return fixtures
end
