--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local GameConfig = require(shared:WaitForChild("GameConfig"))
local SharedData = require(shared:WaitForChild("SharedData"))

local StoryFixture = {}

local function server(path: { string })
	local node = ServerScriptService:FindFirstChild("AstralForge")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function try(label, fn, fallback)
	local ok, value = pcall(fn)
	if ok and value ~= nil then
		return value
	end
	if not ok then
		warn(`[StoryFixture] {label}: {value}`)
	end
	return fallback
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local PRESETS = {
	["New player"] = { cash = 120, lifetime = 400, stardust = 0, cores = 0, rebirths = 0, levels = 1, relics = 0, keys = 1 },
	["Mid game"] = { cash = 2.4e6, lifetime = 9.6e7, stardust = 640, cores = 22, rebirths = 4, levels = 18, relics = 9, keys = 6 },
	["Late game"] = { cash = 8.1e14, lifetime = 3.3e16, stardust = 48000, cores = 940, rebirths = 37, levels = 60, relics = 40, keys = 30 },
}

local function profileFor(save)
	local preset = PRESETS[save] or PRESETS["Mid game"]
	local template = server({ "DataTemplate" })
	local profile = try("template", function()
		return require(template).New()
	end, {})
	profile.Cash = preset.cash
	profile.RunCash = preset.cash * 0.6
	profile.LifetimeCash = preset.lifetime
	profile.Stardust = preset.stardust
	profile.Cores = preset.cores
	profile.Rebirths = preset.rebirths
	profile.Machines = profile.Machines or {}
	for index, machine in GameConfig.Machines or {} do
		if index <= math.max(1, math.floor(preset.levels / 6)) then
			profile.Machines[machine.Id] = math.max(1, preset.levels - index * 3)
		end
	end
	profile.Stats = profile.Stats or {}
	profile.Stats.MachinesBought = preset.levels * 4
	profile.Items = profile.Items or {}
	profile.Items.Inventory = {}
	profile.Items.Keys = {}
	profile.Items.Discovered = {}
	profile.Items.Equipped = {}
	local definitions = GameConfig.Items and GameConfig.Items.Definitions or {}
	for index = 1, math.min(preset.relics, #definitions) do
		local definition = definitions[(index * 7) % #definitions + 1]
		local uid = string.format("story%04d", index)
		profile.Items.Inventory[uid] = { DefinitionId = definition.Id, Level = 1 + index % 6, Stars = if index % 5 == 0 then index % 4 else nil, Locked = index % 9 == 0 }
		profile.Items.Discovered[definition.Id] = true
	end
	for _, crate in GameConfig.Items and GameConfig.Items.Crates or {} do
		profile.Items.Keys[crate.Id] = preset.keys
	end
	profile.Items.Essence = preset.relics * 35
	return profile, preset
end

function StoryFixture.build(save: string?)
	local profile, preset = profileFor(save or "Mid game")
	local now = os.time()
	local EconomyMath = server({ "Modules", "EconomyMath" })
	local economy = EconomyMath and try("economy", function()
		return require(EconomyMath)
	end, nil)
	local function member(name)
		return economy and try(name, function()
			return economy(name)
		end, nil)
	end
	local Economy = member("Economy")
	local Gate = member("ProgressionGate")
	local WheelMath = member("WheelMath")
	local Schema = SharedData("SettingsSchema")
	local ShopCatalog = SharedData("ShopCatalog")

	local settings = {}
	for _, entry in Schema.ENTRIES do
		settings[entry.key] = Schema.value({}, entry.key)
	end
	for key, value in profile.Settings or {} do
		settings[key] = value
	end

	local features = Gate and try("features", function()
		return Gate.FeatureStates(profile)
	end, {}) or {}
	if save == "Late game" then
		for _, entry in features do
			entry.Unlocked = true
		end
	end

	local state = {
		Game = { Name = GameConfig.Game.Name, Version = GameConfig.Game.Version, Update = GameConfig.Game.Update },
		Cash = profile.Cash,
		Vault = preset.cash * 0.25,
		Cores = profile.Cores,
		Stardust = profile.Stardust,
		Rebirths = profile.Rebirths,
		RunCash = profile.RunCash,
		LifetimeCash = profile.LifetimeCash,
		Zone = math.max(1, math.floor(preset.levels / 12)),
		CurrentZone = math.max(1, math.floor(preset.levels / 12)),
		Machines = deepCopy(profile.Machines),
		Research = deepCopy(profile.Research or {}),
		GridUpgrades = deepCopy(profile.GridUpgrades or {}),
		BoostInventory = { Overdrive = 2, Hyperdrive = 1, DomainSurge = 1, VaultSurge = 0 },
		ActiveBoost = { Id = "", EndsAt = 0 },
		Settings = settings,
		Flags = deepCopy(profile.Flags or {}),
		FeatureUnlocks = features,
		Level = Gate and try("level", function()
			return Gate.LevelState(profile)
		end, nil),
		Production = Economy and try("production", function()
			return Economy.Production(profile, now)
		end, 120) or 120,
		RawProduction = 120,
		Capacity = Economy and try("capacity", function()
			return Economy.Capacity(profile, now)
		end, 1e6) or 1e6,
		PrestigeReward = Economy and try("prestige", function()
			return Economy.PrestigeReward(profile.RunCash)
		end, 0) or 0,
		PermanentMultiplier = 1 + preset.rebirths * 0.25,
		NextPrestigeTarget = preset.cash * 4,
		Offline = { Pending = 0, Hours = 0 },
		OfflineHours = 8,
		OfflineEfficiency = 0.5,
		Wheel = WheelMath and try("wheel", function()
			return WheelMath.Snapshot(now, profile.Wheel or { LastSpinAt = 0, Spins = 0, PityMisses = 0, FreeSpins = 1 }, GameConfig.Wheel.CooldownSeconds, GameConfig.Wheel.PityAfter)
		end, nil) or { CanSpin = true, ReadyAt = now, Spins = 3, FreeSpins = 1, PityMisses = 2, PityAfter = 8, PityArmed = false },
		Items = {
			Inventory = profile.Items.Inventory,
			Equipped = profile.Items.Equipped,
			Essence = profile.Items.Essence,
			Keys = profile.Items.Keys,
			Pity = {},
			InventoryLimit = GameConfig.Items.InventoryLimit,
			Shop = {},
			ShopRefreshAt = now + 3600,
			AutoSalvage = { Enabled = false, KeepNew = true, Rarities = {} },
			Effects = {},
			Discovered = profile.Items.Discovered,
			CodexBonus = 0.01,
		},
		DailyShop = { Day = ShopCatalog.day(now), Bought = { ["2"] = 1 } },
		Cosmetics = { CrateSkins = { Classic = true, Crystal = true, Molten = save == "Late game" }, CrateSkin = "Crystal" },
		Shop = { OwnedPasses = {} },
		SocialRewards = { CreatorFollowClaimed = false, CreatorName = "usingINales" },
		Quests = {},
		Achievements = {},
		Stats = deepCopy(profile.Stats),
		Domain = { Rank = 0, Essence = 0 },
		Continuum = { Rank = 0 },
		GuildBonuses = {},
		Guild = { Id = "" },
		Trade = { Locked = true },
		Mailbox = { Items = {}, Unread = 0 },
		Story = { Chapters = {} },
		Visitors = {},
	}
	if Economy then
		local Specializations = require(shared:WaitForChild("Specializations"))
		state.Specialization = Specializations.Snapshot(profile, Economy, now)
	end
	return state
end

return StoryFixture
