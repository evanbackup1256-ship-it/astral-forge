--!strict

return function(loadService: (string) -> any)


	local DataStoreService = game:GetService("DataStoreService")
	local RunService = game:GetService("RunService")

	local DataTemplate = require(script.Parent.Parent:WaitForChild("DataTemplate"))
	local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
	local LeaderboardCodec = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("LeaderboardCodec"))
	local ProfileVersionGuard = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileVersionGuard"))
	local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local OmegaMath = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
	local AtomicState = loadService("AtomicState")
	local ProfileIntegrity = loadService("ProfileIntegrity")
	local ServerTelemetry = loadService("ServerTelemetry")
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local Documents = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Documents"))
	local DocumentCommon = Documents.DocumentCommon
	local SessionDocumentStore = Documents.SessionDocumentStore
	local UnlockedDocumentStore = Documents.UnlockedDocumentStore

	local DataService = {}
	DataService.__index = DataService


	local CACHE_SYNC_INTERVAL = 1.5

	local MAX_PERSISTED_NUMBER = 1e308

	local machineById = {}
	local researchById = {}
	local gridById = {}
	local artifactById = {}
	local expeditionById = {}
	local itemById = {}
	local crateById = {}
	local anomalyProtocolById = {}
	local anomalyTypeById = {}
	local anomalyDirectiveById = {}
	local labOrderById = {}
	local storyById = {}
	local mailById = {}
	local echoTraitById = {}
	for _, item in GameConfig.Machines do
		machineById[item.Id] = item
	end
	for _, item in GameConfig.Research do
		researchById[item.Id] = item
	end
	for _, item in GameConfig.GridUpgrades do
		gridById[item.Id] = item
	end
	for _, item in GameConfig.Operations.Artifacts do
		artifactById[item.Id] = item
	end
	for _, item in GameConfig.Operations.Expeditions do
		expeditionById[item.Id] = item
	end
	for _, item in GameConfig.Items.Definitions do
		itemById[item.Id] = item
	end
	for _, crate in GameConfig.Items.Crates do
		crateById[crate.Id] = crate
	end
	for _, protocol in GameConfig.Anomalies.Protocols do
		anomalyProtocolById[protocol.Id] = protocol
	end
	for _, anomaly in GameConfig.Anomalies.Types do
		anomalyTypeById[anomaly.Id] = anomaly
	end
	for _, directive in GameConfig.Anomalies.Directives do
		anomalyDirectiveById[directive.Id] = directive
	end
	for _, order in GameConfig.Lab.Orders do
		labOrderById[order.Id] = order
	end
	for _, chapter in GameConfig.Story do
		storyById[chapter.Id] = chapter
	end
	for _, message in GameConfig.Mail do
		mailById[message.Id] = message
	end
	for _, trait in GameConfig.ForgeEchoes.Traits do
		echoTraitById[trait.Id] = trait
	end

	local function deepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, child in value do
			copy[deepCopy(key)] = deepCopy(child)
		end
		return copy
	end

	local function reconcile(target, template)
		for key, defaultValue in template do
			local currentValue = target[key]
			if type(defaultValue) == "table" and type(currentValue) == "table" then
				reconcile(currentValue, defaultValue)
			elseif currentValue == nil then
				target[key] = deepCopy(defaultValue)
			elseif type(defaultValue) == "number" and type(currentValue) == "string" then

			elseif type(defaultValue) ~= type(currentValue) then
				target[key] = deepCopy(defaultValue)
			end
		end
		return target
	end

	local function nonNegative(value): number
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return math.clamp(value, 0, MAX_PERSISTED_NUMBER)
	end

	local function sanitize(profile)
		local previousDataVersion = math.floor(nonNegative(profile.DataVersion))
		profile.DataVersion = GameConfig.Game.DataVersion
		profile.Cores = nonNegative(profile.Cores)
		profile.Stardust = nonNegative(profile.Stardust)
		profile.Rebirths = math.min(10_000_000, math.floor(nonNegative(profile.Rebirths)))
		profile.Zone = math.max(1, math.floor(nonNegative(profile.Zone)))
		profile.CurrentZone = math.max(1, math.floor(nonNegative(profile.CurrentZone)))
		for _, key in { "Cash", "Vault", "RunCash", "LifetimeCash" } do
			local persisted = OmegaMath.Persist(profile[key])
			if type(persisted) == "number" and persisted < 0 then
				persisted = 0
			end
			profile[key] = persisted
		end
		if type(profile.Domain) ~= "table" then
			profile.Domain = { Rank = 0, Essence = 0, LastExpandedAt = 0, TotalRebirthsSpent = 0, TotalCoresSpent = 0, SkillPoints = 0, Nodes = {} }
		end
		if type(profile.Domain.Nodes) ~= "table" then
			profile.Domain.Nodes = {}
		end
		profile.Domain.SkillPoints = math.floor(nonNegative(profile.Domain.SkillPoints))
		profile.Domain.Rank = math.floor(nonNegative(profile.Domain.Rank))
		profile.Domain.Essence = math.min(1_000_000, math.floor(nonNegative(tonumber(profile.Domain.Essence) or 0)))
		profile.Domain.LastExpandedAt = math.floor(nonNegative(profile.Domain.LastExpandedAt))
		profile.Domain.TotalRebirthsSpent = math.floor(nonNegative(profile.Domain.TotalRebirthsSpent))
		profile.Domain.TotalCoresSpent = math.floor(nonNegative(profile.Domain.TotalCoresSpent))
		if type(profile.Continuum) ~= "table" then
			profile.Continuum = { Rank = 0, TotalFluxSpent = 0, TotalStardustSpent = 0 }
		end
		profile.Continuum.Rank = math.clamp(
			math.floor(nonNegative(profile.Continuum.Rank)),
			0,
			GameConfig.Continuum.MaxRank
		)
		profile.Continuum.TotalFluxSpent = nonNegative(profile.Continuum.TotalFluxSpent)
		profile.Continuum.TotalStardustSpent = nonNegative(profile.Continuum.TotalStardustSpent)
		local retired = type(profile.Infinite) == "table" and profile.Infinite or nil
		if retired then
			if retired.Active == true and type(retired.Legacy) == "table" then
				local legacy = retired.Legacy
				profile.Cash = OmegaMath.Max(profile.Cash, nonNegative(legacy.Cash))
				profile.LifetimeCash = OmegaMath.Max(profile.LifetimeCash, nonNegative(legacy.LifetimeCash))
				profile.Cores = math.max(profile.Cores, nonNegative(legacy.Cores))
				profile.Stardust = math.max(profile.Stardust, nonNegative(legacy.Stardust))
				profile.Rebirths = math.max(profile.Rebirths, nonNegative(legacy.Rebirths))
				profile.Domain.Rank = math.max(profile.Domain.Rank, nonNegative(legacy.DomainRank))
				profile.Continuum.Rank = math.max(profile.Continuum.Rank, nonNegative(legacy.ContinuumRank))
				profile.Zone = math.max(nonNegative(profile.Zone), nonNegative(legacy.World), 1)
				profile.CurrentZone = math.clamp(nonNegative(profile.CurrentZone), 1, profile.Zone)
			end
			profile.Infinite = nil
		end
		-- Dungeons and Minigames were removed features; scrub any leftover fields from old
		-- saves so orphaned data doesn't silently persist forever in future writes.
		if profile.Dungeons ~= nil then profile.Dungeons = nil end
		if profile.Minigames ~= nil then profile.Minigames = nil end

		profile.Domain.Rank = math.floor(nonNegative(profile.Domain.Rank))
		profile.Continuum.Rank = math.clamp(
			math.floor(nonNegative(profile.Continuum.Rank)),
			0,
			GameConfig.Continuum.MaxRank
		)
		if type(profile.ForgeEchoes) ~= "table" then
			profile.ForgeEchoes = {
				Charge = 0,
				Resonance = 0,
				Captures = 0,
				NextId = 1,
				Pattern = { Collect = 0, Surge = 0, Build = 0, Explore = 0 },
				Draft = { Id = "", Choices = {} },
				Inventory = {},
				Equipped = { ["1"] = "", ["2"] = "", ["3"] = "" },
			}
		end
		local echoes = profile.ForgeEchoes
		echoes.Charge = math.clamp(nonNegative(echoes.Charge), 0, GameConfig.ForgeEchoes.ChargeTarget)
		echoes.Resonance = math.floor(nonNegative(echoes.Resonance))
		echoes.Captures = math.floor(nonNegative(echoes.Captures))
		echoes.NextId = math.max(1, math.floor(nonNegative(echoes.NextId)))
		if type(echoes.Pattern) ~= "table" then echoes.Pattern = {} end
		for _, id in { "Collect", "Surge", "Build", "Explore" } do
			echoes.Pattern[id] = math.clamp(nonNegative(echoes.Pattern[id]), 0, 1e9)
		end
		for id in echoes.Pattern do
			if id ~= "Collect" and id ~= "Surge" and id ~= "Build" and id ~= "Explore" then
				echoes.Pattern[id] = nil
			end
		end
		if type(echoes.Inventory) ~= "table" then echoes.Inventory = {} end
		local echoCount = 0
		for uid, instance in echoes.Inventory do
			local trait = type(instance) == "table" and echoTraitById[instance.TraitId]
			if type(uid) ~= "string" or not trait or echoCount >= GameConfig.ForgeEchoes.InventoryLimit then
				echoes.Inventory[uid] = nil
			else
				echoCount += 1
				instance.Uid = nil
				instance.Level = math.clamp(math.floor(nonNegative(instance.Level)), 1, GameConfig.ForgeEchoes.MaxLevel)
				instance.Strength = math.clamp(nonNegative(instance.Strength), 0.75, 1.5)
				instance.CapturedAt = math.floor(nonNegative(instance.CapturedAt))
				instance.Origin = type(instance.Origin) == "string" and instance.Origin or "Collect"
			end
		end
		if type(echoes.Equipped) ~= "table" then echoes.Equipped = {} end
		local equippedEchoes = {}
		for slot = 1, GameConfig.ForgeEchoes.MaxSlots do
			local key = tostring(slot)
			local uid = echoes.Equipped[key]
			if type(uid) ~= "string" or uid == "" or not echoes.Inventory[uid] or equippedEchoes[uid] then
				echoes.Equipped[key] = ""
			else
				equippedEchoes[uid] = true
			end
		end
		for key in echoes.Equipped do
			local slot = tonumber(key)
			if not slot or slot ~= math.floor(slot) or slot < 1 or slot > GameConfig.ForgeEchoes.MaxSlots then
				echoes.Equipped[key] = nil
			end
		end
		if type(echoes.Draft) ~= "table" then echoes.Draft = { Id = "", Choices = {} } end
		echoes.Draft.Id = type(echoes.Draft.Id) == "string" and echoes.Draft.Id:sub(1, 48) or ""
		if type(echoes.Draft.Choices) ~= "table" then echoes.Draft.Choices = {} end
		local safeChoices = {}
		for _, choice in echoes.Draft.Choices do
			local trait = type(choice) == "table" and echoTraitById[choice.TraitId]
			if trait and type(choice.Uid) == "string" and #safeChoices < 3 then
				choice.Uid = choice.Uid:sub(1, 56)
				choice.Level = 1
				choice.Strength = math.clamp(nonNegative(choice.Strength), 0.9, 1.32)
				choice.CapturedAt = math.floor(nonNegative(choice.CapturedAt))
				choice.Origin = type(choice.Origin) == "string" and choice.Origin or "Collect"
				table.insert(safeChoices, choice)
			end
		end
		echoes.Draft.Choices = safeChoices
		if #safeChoices == 0 then echoes.Draft.Id = "" end
		profile.Zone = math.clamp(math.floor(nonNegative(profile.Zone)), 1, GameConfig.MaxZone)
		profile.CurrentZone = math.clamp(math.floor(nonNegative(profile.CurrentZone)), 1, profile.Zone)
		for key, value in profile.Machines do
			local item = machineById[key]
			local nextValue = item and math.clamp(math.floor(nonNegative(value)), 0, item.MaxLevel) or 0
			profile.Machines[key] = nextValue > 0 and nextValue or nil
		end
		if type(profile.AutoForge) ~= "table" then
			profile.AutoForge = { Enabled = false, MachineId = "StellarCore", Reserve = 0.25, Bought = 0 }
		end
		profile.AutoForge.Enabled = profile.AutoForge.Enabled == true
		profile.AutoForge.MachineId = type(profile.AutoForge.MachineId) == "string"
			and machineById[profile.AutoForge.MachineId]
			and profile.AutoForge.MachineId
			or "StellarCore"
		profile.AutoForge.Reserve = math.clamp(nonNegative(profile.AutoForge.Reserve), 0, 0.9)
		profile.AutoForge.Bought = math.floor(nonNegative(profile.AutoForge.Bought))
		for key, value in profile.Research do
			local item = researchById[key]
			local nextValue = item and math.clamp(math.floor(nonNegative(value)), 0, item.MaxLevel) or 0
			profile.Research[key] = nextValue > 0 and nextValue or nil
		end
		for key, value in profile.GridUpgrades do
			local item = gridById[key]
			local nextValue = item and math.clamp(math.floor(nonNegative(value)), 0, item.MaxLevel) or 0
			profile.GridUpgrades[key] = nextValue > 0 and nextValue or nil
		end
		profile.Command.XP = math.floor(nonNegative(profile.Command.XP))
		profile.Command.Signals = math.floor(nonNegative(profile.Command.Signals))
		profile.Command.StreakShields = math.floor(nonNegative(profile.Command.StreakShields))
		profile.Command.ExpeditionsCompleted = math.floor(nonNegative(profile.Command.ExpeditionsCompleted))
		profile.Command.SeasonXP = math.floor(nonNegative(profile.Command.SeasonXP))
		if profile.Flags.InfiniteMoney == true then profile.Flags.UnlimitedMoney = true end
		profile.Flags.InfiniteMoney = nil
		profile.Flags.UnlimitedMoney = profile.Flags.UnlimitedMoney == true
		-- Must match TUTORIAL_STEPS.size() in src_ts/client/MainGame.tsx, the clamp in
		-- GameService:_setTutorialStep, and the firewall's SetTutorialStep validator. This was
		-- previously capped at 10 here too, which re-clobbered a correctly saved step > 10 back
		-- down to 10 on every subsequent profile load/save -- the exact same "stuck at step 10"
		-- symptom the other two fixes were meant to resolve.
		profile.Flags.TutorialStep = math.clamp(math.floor(nonNegative(profile.Flags.TutorialStep)), 1, 15)
		if profile.Flags.TutorialDone == true then
			profile.Flags.TutorialRewardClaimed = true
		end
		if type(profile.Flags.LastSeenVersion) ~= "string" then
			profile.Flags.LastSeenVersion = ""
		end
		profile.Settings.SoundVolume = math.clamp(nonNegative(profile.Settings.SoundVolume), 0, 1)
		profile.Settings.MusicVolume = math.clamp(nonNegative(profile.Settings.MusicVolume ~= nil and profile.Settings.MusicVolume or 1), 0, 1)
		profile.Settings.SfxVolume = math.clamp(nonNegative(profile.Settings.SfxVolume ~= nil and profile.Settings.SfxVolume or 1), 0, 1)
		profile.Settings.EffectsIntensity = math.clamp(nonNegative(profile.Settings.EffectsIntensity), 0, 1)
		profile.Settings.MotionIntensity = math.clamp(nonNegative(profile.Settings.MotionIntensity), 0, 1)
		profile.Settings.ViewportSpeed = math.clamp(nonNegative(profile.Settings.ViewportSpeed), 0, 1)
		profile.Settings.ToastDensity = math.clamp(nonNegative(profile.Settings.ToastDensity ~= nil and profile.Settings.ToastDensity or 0.55), 0, 1)
		profile.Settings.UiDensity = math.clamp(nonNegative(profile.Settings.UiDensity ~= nil and profile.Settings.UiDensity or 0.55), 0, 1)
		local normalizedSettingDefaults = {
			PerformanceBias = 0.5,
			BackgroundDetail = 0.8,
			ScrollSpeed = 0.65,
			MusicCrossfade = 0.62,
			SoundVariation = 0.7,
			PageStingers = 1,
			ReactorMotion = 0.8,
			OfflineRewardEffects = 1,
			HapticIntensity = 0.65,
			MobileHudScale = 0.5,
			MobileTextScale = 0.5,
			MobileHudOpacity = 0.85,
			MobileQuickScale = 0.5,
			MobileDockScale = 0.5,
			MobileToastScale = 0.5,
			MobileQuickOpacity = 0.9,
			MobileDockOpacity = 0.88,
			MobileToastOpacity = 0.9,
			MobileButtonSpacing = 0.5,
			MobileQuickReverse = 0,
			MobileQuickVisible = 1,
			MobileDockVisible = 1,
			MobileToastVisible = 1,
			MobileQuickX = 0.5,
			MobileQuickY = 0.70,
			MobileDockX = 0.5,
			MobileDockY = 0.92,
			MobileToastX = 0.84,
			MobileToastY = 0.27,
			HighContrast = 0,
			ColorblindMode = 0,
		}
		for key, defaultValue in normalizedSettingDefaults do
			profile.Settings[key] = math.clamp(nonNegative(profile.Settings[key] ~= nil and profile.Settings[key] or defaultValue), 0, 1)
		end
		profile.Settings.NotifyGuild = profile.Settings.NotifyGuild == true and 1
			or math.clamp(nonNegative(profile.Settings.NotifyGuild ~= nil and profile.Settings.NotifyGuild or 0), 0, 1)
		if type(profile.LiveOps) ~= "table" then
			profile.LiveOps = { ManifestVersion = GameConfig.Game.LiveOpsManifestVersion, Convergence = {} }
		end
		profile.LiveOps.ManifestVersion = GameConfig.Game.LiveOpsManifestVersion
		if type(profile.LiveOps.Convergence) ~= "table" then profile.LiveOps.Convergence = {} end
		local convergence = profile.LiveOps.Convergence
		convergence.EventId = type(convergence.EventId) == "string" and convergence.EventId or ""
		convergence.Contribution = math.floor(nonNegative(convergence.Contribution))
		convergence.Claimed = type(convergence.Claimed) == "table" and convergence.Claimed or {}
		if type(profile.Guild) ~= "table" then
			profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
		end
		profile.Guild.Id = type(profile.Guild.Id) == "string" and profile.Guild.Id or ""
		profile.Guild.Role = type(profile.Guild.Role) == "string" and profile.Guild.Role or ""
		profile.Guild.Tag = type(profile.Guild.Tag) == "string" and profile.Guild.Tag or ""
		profile.Guild.JoinedAt = math.floor(nonNegative(profile.Guild.JoinedAt))
		if type(profile.GuildBonuses) ~= "table" then
			profile.GuildBonuses = { Production = 0, Capacity = 0, Offline = 0, Automation = 0, Tap = 0 }
		end
		for _, key in { "Production", "Capacity", "Offline", "Automation", "Tap" } do
			profile.GuildBonuses[key] = math.clamp(nonNegative(profile.GuildBonuses[key]), 0, 1)
		end
		if type(profile.SocialBoost) ~= "table" then
			profile.SocialBoost = {
				FriendCount = 0,
				FriendLimit = GameConfig.Social.MaxBoostedFriends,
				FriendBonus = 0,
				Premium = false,
				PremiumBonus = 0,
				Multiplier = 1,
			}
		end
		profile.SocialBoost.FriendCount = math.clamp(math.floor(nonNegative(profile.SocialBoost.FriendCount)), 0, GameConfig.Social.MaxBoostedFriends)
		profile.SocialBoost.FriendLimit = GameConfig.Social.MaxBoostedFriends
		profile.SocialBoost.FriendBonus = math.clamp(nonNegative(profile.SocialBoost.FriendBonus), 0, GameConfig.Social.FriendProductionPerPlayer * GameConfig.Social.MaxBoostedFriends)
		profile.SocialBoost.Premium = profile.SocialBoost.Premium == true
		profile.SocialBoost.PremiumBonus = profile.SocialBoost.Premium and GameConfig.Social.PremiumProductionBonus or 0
		profile.SocialBoost.Multiplier = 1 + profile.SocialBoost.FriendBonus + profile.SocialBoost.PremiumBonus
		if type(profile.Trade) ~= "table" then
			profile.Trade = { Day = -1, Completed = 0, Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 } }
		end
		if type(profile.Trade.Sent) ~= "table" then
			profile.Trade.Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 }
		end
		profile.Trade.Day = math.floor(nonNegative(profile.Trade.Day))
		profile.Trade.Completed = math.floor(nonNegative(profile.Trade.Completed))
		if previousDataVersion < 5 then
			if profile.Settings.SoundEffects == false then
				profile.Settings.SoundVolume = 0
			end
			if profile.Settings.UIEffects == false then
				profile.Settings.EffectsIntensity = 0
			end
			if profile.Settings.ReducedMotion == true then
				profile.Settings.MotionIntensity = 0
			end
		end
		profile.Settings.SoundEffects = profile.Settings.SoundVolume > 0.001
		profile.Settings.UIEffects = profile.Settings.EffectsIntensity > 0.001
		profile.Settings.ReducedMotion = profile.Settings.MotionIntensity <= 0.03
		profile.Wheel.LastSpinAt = math.floor(nonNegative(profile.Wheel.LastSpinAt))
		profile.Wheel.Spins = math.floor(nonNegative(profile.Wheel.Spins))
		profile.Wheel.PityMisses = math.floor(nonNegative(profile.Wheel.PityMisses))
		profile.Wheel.FreeSpins = math.floor(nonNegative(profile.Wheel.FreeSpins))
		profile.Items.NextId = math.max(1, math.floor(nonNegative(profile.Items.NextId)))
		profile.Items.Essence = math.floor(nonNegative(profile.Items.Essence))
		profile.Items.Shop.Day = math.floor(nonNegative(profile.Items.Shop.Day))
		if type(profile.Items.Shop.Purchased) ~= "table" then
			profile.Items.Shop.Purchased = {}
		end
		if type(profile.Items.Shop.Stock) ~= "table" then
			profile.Items.Shop.Stock = {}
		end
		for offerId, purchased in profile.Items.Shop.Purchased do
			if purchased ~= true then
				profile.Items.Shop.Purchased[offerId] = nil
			end
		end
		for offerId, stock in profile.Items.Shop.Stock do
			if type(stock) ~= "number" then
				profile.Items.Shop.Stock[offerId] = nil
			else
				profile.Items.Shop.Stock[offerId] = math.max(0, math.floor(stock))
			end
		end
		for crateId in crateById do
			profile.Items.Keys[crateId] = math.floor(nonNegative(profile.Items.Keys[crateId]))
			profile.Items.Pity[crateId] = math.floor(nonNegative(profile.Items.Pity[crateId]))
		end
		for crateId in profile.Items.Keys do
			if not crateById[crateId] then
				profile.Items.Keys[crateId] = nil
			end
		end
		for crateId in profile.Items.Pity do
			if not crateById[crateId] then
				profile.Items.Pity[crateId] = nil
			end
		end
		profile.Items.AutoSalvage = type(profile.Items.AutoSalvage) == "table" and profile.Items.AutoSalvage or {}
		profile.Items.AutoSalvage.Enabled = profile.Items.AutoSalvage.Enabled == true
		profile.Items.AutoSalvage.KeepNew = profile.Items.AutoSalvage.KeepNew ~= false
		profile.Items.AutoSalvage.Rarities = type(profile.Items.AutoSalvage.Rarities) == "table"
			and profile.Items.AutoSalvage.Rarities or {}
		for rarity in profile.Items.AutoSalvage.Rarities do
			if not GameConfig.Items.Rarities[rarity] then
				profile.Items.AutoSalvage.Rarities[rarity] = nil
			else
				profile.Items.AutoSalvage.Rarities[rarity] = profile.Items.AutoSalvage.Rarities[rarity] == true
			end
		end
		profile.Items.Discovered = type(profile.Items.Discovered) == "table" and profile.Items.Discovered or {}
		for definitionId in profile.Items.Discovered do
			if not itemById[definitionId] then profile.Items.Discovered[definitionId] = nil
			else profile.Items.Discovered[definitionId] = true end
		end
		local inventoryCount = 0
		for uid, instance in profile.Items.Inventory do
			local definition = type(instance) == "table" and itemById[instance.DefinitionId]
			if type(uid) ~= "string" or not definition or inventoryCount >= GameConfig.Items.InventoryLimit then
				profile.Items.Inventory[uid] = nil
			else
				inventoryCount += 1
				profile.Items.Discovered[instance.DefinitionId] = true
				instance.Level = math.clamp(math.floor(nonNegative(instance.Level)), 1, definition.MaxLevel)
				instance.AcquiredAt = math.floor(nonNegative(instance.AcquiredAt))
				instance.Locked = instance.Locked == true
			end
		end
		local equippedItems = {}
		for target, uid in profile.Items.Equipped do
			local instance = type(uid) == "string" and profile.Items.Inventory[uid]
			local definition = instance and itemById[instance.DefinitionId]
			local slot, targetId
			if type(target) == "string" then
				slot, targetId = string.match(target, "^(%a+):([%w_]+)$")
			end
			local targetExists = (slot == "Machine" and machineById[targetId] ~= nil)
				or (slot == "Research" and researchById[targetId] ~= nil)
			local targetCompatible = definition
				and (not definition.Targets or table.find(definition.Targets, targetId) ~= nil)
			if
				not definition
				or definition.Slot ~= slot
				or not targetExists
				or not targetCompatible
				or equippedItems[uid]
			then
				profile.Items.Equipped[target] = nil
			else
				equippedItems[uid] = true
			end
		end
		profile.Anomaly.Cycle = math.floor(nonNegative(profile.Anomaly.Cycle))
		profile.Anomaly.Charge = nonNegative(profile.Anomaly.Charge)
		profile.Anomaly.Fragments = math.floor(nonNegative(profile.Anomaly.Fragments))
		profile.Anomaly.Stabilizations = math.floor(nonNegative(profile.Anomaly.Stabilizations))
		profile.Anomaly.Chain = math.floor(nonNegative(profile.Anomaly.Chain))
		profile.Anomaly.BestChain = math.floor(nonNegative(profile.Anomaly.BestChain))
		profile.Anomaly.LastActionAt = math.floor(nonNegative(profile.Anomaly.LastActionAt))
		profile.Anomaly.SurgeEndsAt = math.floor(nonNegative(profile.Anomaly.SurgeEndsAt))
		profile.Anomaly.DirectiveCycle = math.floor(nonNegative(profile.Anomaly.DirectiveCycle))
		if not GameConfig.Anomalies.Channels[profile.Anomaly.Channel] then
			profile.Anomaly.Channel = "Flux"
		end
		-- Overdrive Core: Loadout replaces the old single Channel selection. A returning player
		-- whose save predates this system has an empty Loadout (backfilled by DataTemplate's
		-- reconcile pass) but a valid legacy Channel -- seed Loadout from it once so their
		-- existing selection keeps working instead of silently going blank.
		if type(profile.Anomaly.Loadout) ~= "table" then
			profile.Anomaly.Loadout = {}
		end
		if #profile.Anomaly.Loadout == 0 and GameConfig.Anomalies.Channels[profile.Anomaly.Channel] then
			profile.Anomaly.Loadout = { profile.Anomaly.Channel }
		end
		do
			local slots = GameConfig.Anomalies.LoadoutSlots
			local seen = {}
			local sanitizedLoadout = {}
			for _, channelId in profile.Anomaly.Loadout do
				if type(channelId) == "string" and GameConfig.Anomalies.Channels[channelId] and not seen[channelId] and #sanitizedLoadout < slots then
					seen[channelId] = true
					table.insert(sanitizedLoadout, channelId)
				end
			end
			profile.Anomaly.Loadout = sanitizedLoadout
		end
		-- Keep fractional seconds: the pulse window is ~1.6s with a sub-second sweet zone.
		profile.Anomaly.PulseWindowStartedAt = nonNegative(profile.Anomaly.PulseWindowStartedAt or 0)
		profile.Anomaly.Combo = math.floor(nonNegative(profile.Anomaly.Combo or 0))
		profile.Anomaly.BestCombo = math.floor(nonNegative(profile.Anomaly.BestCombo or 0))
		profile.Anomaly.CoreTier = math.floor(nonNegative(profile.Anomaly.CoreTier or 0))
		profile.Anomaly.CoreXP = math.floor(nonNegative(profile.Anomaly.CoreXP or 0))
		for protocolId, value in profile.Anomaly.Protocols do
			local protocol = anomalyProtocolById[protocolId]
			profile.Anomaly.Protocols[protocolId] = protocol
					and math.clamp(math.floor(nonNegative(value)), 0, protocol.MaxLevel)
				or nil
		end
		for anomalyId, value in profile.Anomaly.Discoveries do
			profile.Anomaly.Discoveries[anomalyId] = anomalyTypeById[anomalyId] and math.floor(nonNegative(value))
				or nil
		end
		for key, claimed in profile.Anomaly.MilestoneClaims do
			local tier = tonumber(key)
			if type(claimed) ~= "boolean" or not tier or not GameConfig.Anomalies.Milestones[tier] then
				profile.Anomaly.MilestoneClaims[key] = nil
			end
		end
		for directiveId, value in profile.Anomaly.DirectiveProgress do
			profile.Anomaly.DirectiveProgress[directiveId] = anomalyDirectiveById[directiveId]
					and math.floor(nonNegative(value))
				or nil
		end
		for directiveId, claimed in profile.Anomaly.DirectiveClaims do
			if not anomalyDirectiveById[directiveId] or type(claimed) ~= "boolean" then
				profile.Anomaly.DirectiveClaims[directiveId] = nil
			end
		end
		-- ForgePath was the only major progression bag without a sanitize pass. Partial
		-- bags (XP without ClaimedSteps) crashed Economy.ForgePathEffect / claim paths.
		if type(profile.ForgePath) ~= "table" then
			profile.ForgePath = { ClaimedSteps = {}, XP = 0, XPDay = -1, XPEarnedToday = 0 }
		end
		if type(profile.ForgePath.ClaimedSteps) ~= "table" then
			profile.ForgePath.ClaimedSteps = {}
		end
		local forgeStepCount = GameConfig.ForgePath and GameConfig.ForgePath.StepCount
			or (GameConfig.ForgePath and #GameConfig.ForgePath.Steps)
			or 0
		for key, claimed in profile.ForgePath.ClaimedSteps do
			local stepIndex = tonumber(key)
			if
				type(claimed) ~= "boolean"
				or claimed ~= true
				or not stepIndex
				or stepIndex ~= math.floor(stepIndex)
				or stepIndex < 1
				or (forgeStepCount > 0 and stepIndex > forgeStepCount)
			then
				profile.ForgePath.ClaimedSteps[key] = nil
			elseif type(key) == "number" then
				-- Persist string keys so ClaimForgePathStep tostring lookups stay consistent.
				profile.ForgePath.ClaimedSteps[key] = nil
				profile.ForgePath.ClaimedSteps[tostring(stepIndex)] = true
			end
		end
		profile.ForgePath.XP = math.floor(nonNegative(profile.ForgePath.XP))
		profile.ForgePath.XPDay = type(profile.ForgePath.XPDay) == "number" and math.floor(profile.ForgePath.XPDay) or -1
		profile.ForgePath.XPEarnedToday = math.floor(nonNegative(profile.ForgePath.XPEarnedToday))
		profile.Lab.Day = type(profile.Lab.Day) == "number" and math.max(-1, math.floor(profile.Lab.Day)) or -1
		for index, order in profile.Lab.Orders do
			if
				type(index) ~= "number"
				or index ~= math.floor(index)
				or index < 1
				or index > GameConfig.Lab.OrderCount
				or type(order) ~= "table"
				or not labOrderById[order.Id]
			then
				profile.Lab.Orders[index] = nil
			else
				order.Progress = nonNegative(order.Progress)
				order.Target = math.max(1, nonNegative(order.Target))
				order.Claimed = order.Claimed == true
			end
		end
		local routeTotal = math.clamp(
			GameConfig.Lab.Power.BaseCells + math.floor(profile.Rebirths / GameConfig.Lab.Power.RebirthsPerCell),
			GameConfig.Lab.Power.BaseCells,
			GameConfig.Lab.Power.MaxCells
		)
		local routeUsed = 0
		for _, channelId in { "Production", "Storage", "Tap" } do
			local value = math.clamp(math.floor(nonNegative(profile.Lab.Routing[channelId])), 0, routeTotal)
			profile.Lab.Routing[channelId] = value
			routeUsed += value
		end
		if routeUsed > routeTotal then
			local overflow = routeUsed - routeTotal
			for _, channelId in { "Tap", "Storage", "Production" } do
				local removed = math.min(profile.Lab.Routing[channelId], overflow)
				profile.Lab.Routing[channelId] -= removed
				overflow -= removed
				if overflow <= 0 then
					break
				end
			end
		end
		for _, collection in { profile.Story.Read, profile.Story.Claimed } do
			for id, value in collection do
				if not storyById[id] or type(value) ~= "boolean" then
					collection[id] = nil
				end
			end
		end
		for _, collection in { profile.Mailbox.Read, profile.Mailbox.Claimed, profile.Mailbox.Deleted } do
			for id, value in collection do
				if not mailById[id] or type(value) ~= "boolean" then
					collection[id] = nil
				end
			end
		end
		for role, value in profile.Command.Crew do
			local item = GameConfig.Operations.Crew[role]
			profile.Command.Crew[role] = item and math.clamp(math.floor(nonNegative(value)), 1, item.MaxLevel)
				or nil
		end
		for id, value in profile.Command.MachineMastery do
			local nextValue = machineById[id] and math.floor(nonNegative(value)) or 0
			profile.Command.MachineMastery[id] = nextValue > 0 and nextValue or nil
		end
		for id, artifact in profile.Command.Artifacts do
			if not artifactById[id] or type(artifact) ~= "table" then
				profile.Command.Artifacts[id] = nil
			else
				artifact.Level = math.clamp(math.floor(nonNegative(artifact.Level)), 1, 10)
				artifact.Fragments = math.floor(nonNegative(artifact.Fragments))
			end
		end
		if not profile.Command.Artifacts[profile.Command.EquippedArtifact] then
			profile.Command.EquippedArtifact = ""
		end
		local active = profile.Command.ActiveExpedition
		if
			type(active.Id) ~= "string"
			or (active.Id ~= "" and not expeditionById[active.Id])
			or type(active.StartedAt) ~= "number"
			or type(active.EndsAt) ~= "number"
		then
			profile.Command.ActiveExpedition = { Id = "", StartedAt = 0, EndsAt = 0 }
		else
			active.StartedAt = math.floor(nonNegative(active.StartedAt))
			active.EndsAt = math.max(active.StartedAt, math.floor(nonNegative(active.EndsAt)))
		end
		profile.Meta.Revision = math.max(0, math.floor(nonNegative(profile.Meta.Revision)))
		ProfileIntegrity.EnsureEnvelope(profile)
		return profile
	end

	local function migrateLegacyProfile(data: any)
		ProfileVersionGuard.ReadCompatible(data, GameConfig.Game.DataVersion)
		return sanitize(reconcile(data, DataTemplate.New()))
	end

	function DataService.new()
		local self = setmetatable({}, DataService)

		local dataStore = DataStoreService:GetDataStore(ServerConfig.DataStoreName)
		local defaultProfile = DataTemplate.New()


		self._playerStore = SessionDocumentStore.new({
			dataStore = dataStore :: any,
			check = DocumentCommon.permissiveTableCheck,
			default = defaultProfile,
			migrations = {
				{

					backwardsCompatible = true,
					migrate = migrateLegacyProfile,
				},
			},
			bindToClose = false,
		})


		self._sharedStore = UnlockedDocumentStore.new({
			dataStore = DataStoreService:GetDataStore(ServerConfig.SharedDataStoreName) :: any,
			check = DocumentCommon.permissiveTableCheck,
			default = { Version = 1, Entries = {} },
			migrations = {},
			bindToClose = false,
		})

		self._leaderboardStore = DataStoreService:GetOrderedDataStore(ServerConfig.LeaderboardStoreName)
		self._leaderboardStores = {
			Flux = self._leaderboardStore,
			Rebirths = DataStoreService:GetOrderedDataStore(ServerConfig.RebirthLeaderboardStoreName),
			PlayTime = DataStoreService:GetOrderedDataStore(ServerConfig.PlayTimeLeaderboardStoreName),
			Dust = DataStoreService:GetOrderedDataStore(ServerConfig.DustLeaderboardStoreName),
			Cores = DataStoreService:GetOrderedDataStore(ServerConfig.CoresLeaderboardStoreName),
			Domain = DataStoreService:GetOrderedDataStore(ServerConfig.DomainLeaderboardStoreName),
			Worlds = DataStoreService:GetOrderedDataStore(ServerConfig.WorldLeaderboardStoreName),
		}

		self._leaderboardMirrors = {}
		self._leaderboardPending = {}
		self._leaderboardPushBusy = {}
		self._leaderboardWorkers = {}
		self._profiles = {}
		self._documents = {}
		self._dirty = {}
		self._memoryMode = {}
		self._previousLastSeen = {}
		self._atoms = {}
		self._integrityStatus = {}
		self._cacheSyncThreads = {}
		self._lastCacheSyncAt = {}
		self._saveBusy = {}
		self._releasing = {}
		self._closing = false
		self._autosaveThread = nil
		-- Optional hook the owning service can set post-construction: (player, reason) -> ().
		-- Fired when a routine (non-release) save exhausts its retries, so something can warn the
		-- still-connected player instead of the failure only ever showing up in server logs.
		self.OnSaveFailed = nil
		return self
	end

	function DataService:_key(player: Player): string
		return string.format("Player_%d", player.UserId)
	end

	function DataService:_clearPlayer(player: Player)
		local cacheThread = self._cacheSyncThreads[player]
		if cacheThread then task.cancel(cacheThread) end
		self._cacheSyncThreads[player] = nil
		self._lastCacheSyncAt[player] = nil
		ServerTelemetry.RecordPlayerLeft(player.UserId)
		self._profiles[player] = nil
		self._documents[player] = nil
		self._atoms[player] = nil
		self._dirty[player] = nil
		self._memoryMode[player] = nil
		self._previousLastSeen[player] = nil
		self._integrityStatus[player] = nil
		self._saveBusy[player] = nil
		self._releasing[player] = nil
	end

	function DataService:_queueDocumentSync(player: Player)
		if self._cacheSyncThreads[player] then return end
		local elapsed = os.clock() - (self._lastCacheSyncAt[player] or -math.huge)
		local delaySeconds = math.max(0.05, CACHE_SYNC_INTERVAL - elapsed)
		self._cacheSyncThreads[player] = task.delay(delaySeconds, function()
			self._cacheSyncThreads[player] = nil
			local profile = self._profiles[player]
			if not profile then return end
			local ok, reason = pcall(function()

				local snapshot = sanitize(deepCopy(profile))
				ProfileIntegrity.Seal(snapshot)
				self:_syncDocumentCache(player, snapshot)
			end)
			if ok then
				self._lastCacheSyncAt[player] = os.clock()
			else
				ModuleLog.Every(
					"cache-sync:" .. tostring(player.UserId),
					5,
					"Data",
					string.format("%s cache sync rejected unsafe profile data — %s", player.Name, tostring(reason))
				)
			end
		end)
	end

	function DataService:_syncDocumentCache(player: Player, snapshot)
		local document = self._documents[player]
		if not document or type(snapshot) ~= "table" or self._memoryMode[player] then
			return
		end
		if not document:IsOpen() or document:IsClosing() then
			return
		end

		document:SetCache(snapshot)
	end

	function DataService:_pushLeaderboard(player: Player, profile)

		if self._closing then
			return
		end
		local userId = player.UserId
		self._leaderboardPending[userId] = {
			Flux = profile.LifetimeCash,
			Rebirths = math.max(0, math.floor(tonumber(profile.Rebirths) or 0)),
			PlayTime = math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.PlayTime) or 0)),
			Dust = math.max(0, math.floor(tonumber(profile.Stardust) or 0)),
			Cores = math.max(0, math.floor(tonumber(profile.Cores) or 0)),
			Domain = math.max(0, math.floor(tonumber(profile.Domain and profile.Domain.Rank) or 0)),
			Worlds = math.max(1, math.floor(tonumber(profile.Zone) or 1)),
		}
		if self._leaderboardPushBusy[userId] then return end
		self._leaderboardPushBusy[userId] = true
		self._leaderboardWorkers[userId] = task.defer(function()
			local mirror = self._leaderboardMirrors[userId] or {}
			self._leaderboardMirrors[userId] = mirror
			while self._leaderboardPending[userId] do
				local values = self._leaderboardPending[userId]
				self._leaderboardPending[userId] = nil
				for id, value in values do
					local store = self._leaderboardStores[id]
					if store and mirror[id] ~= value then
						local ok = pcall(function()
							store:SetAsync(tostring(userId), LeaderboardCodec.Encode(value))
						end)
						if ok then mirror[id] = value end
					end
				end
			end
			self._leaderboardPushBusy[userId] = nil
			self._leaderboardWorkers[userId] = nil

			if self._profiles[player] == nil then
				self._leaderboardMirrors[userId] = nil
			end
		end)
	end

	function DataService:GetSharedStore()
		return self._sharedStore
	end

	function DataService:IsClosing(): boolean
		return self._closing == true
	end

	function DataService:Load(player: Player, stealLock: boolean?): (boolean, string?)
		if self._profiles[player] then
			return true
		end
		if self._closing then
			return false, "refreshing"
		end
		local loadStartedAt = os.clock()

		local key = self:_key(player)
		local now = os.time()
		local gotDocument, document = pcall(function()
			return self._playerStore:GetDocument(key)
		end)
		if not gotDocument then
			local reason = tostring(document)
			ModuleLog.Warn("Data", string.format("couldn't reserve %s's save: %s", player.Name, reason))
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
			if self._closing or string.find(string.lower(reason), "closing", 1, true) then
				return false, "refreshing"
			end
			return false, "Your save could not be opened safely. Please rejoin in a moment."
		end

		-- When the caller has decided the lock holder is stale (dead server, orphaned
		-- Studio session), Steal lets this Open bypass the other session's lock. The
		-- displaced session's next save fails closed instead of corrupting data.
		if stealLock == true then
			pcall(function()
				document:Steal()
			end)
		end

		local openCallOk, openResult = pcall(document.Open, document)
		if not openCallOk then
			ModuleLog.Warn("Data", string.format("couldn't open %s's save: %s", player.Name, tostring(openResult)))
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
			if self._closing or string.find(string.lower(tostring(openResult)), "closing", 1, true) then
				return false, "refreshing"
			end
			return false, "Your save could not be opened safely. Please rejoin in a moment."
		end

		if DocumentCommon.isOk(openResult) then
			local cached = document:GetCache()
			local function rejectUnsafeProfile(reason: string)
				pcall(function()
					if document:IsOpen() then document:Close() end
				end)
				ModuleLog.Error("Data", "profile load rejected", { UserId = player.UserId, Reason = reason })
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
				return false, "Your save could not be verified safely. Please rejoin or contact support."
			end

			local copied, candidate = pcall(deepCopy, cached)
			local integrityOk, integrityMessage
			if not copied or type(candidate) ~= "table" then
				return rejectUnsafeProfile("unreadable profile graph")
			end
			local versionOk, versionProblem = pcall(ProfileVersionGuard.ReadCompatible, candidate, GameConfig.Game.DataVersion)
			if not versionOk then
				return rejectUnsafeProfile(tostring(versionProblem))
			end
			local verifyCallOk, verified, verifyMessage = pcall(ProfileIntegrity.VerifyAndRecover, candidate)
			if not verifyCallOk then
				return rejectUnsafeProfile("unreadable integrity envelope")
			end
			integrityOk, integrityMessage = verified, verifyMessage
			if not integrityOk and string.find(tostring(integrityMessage), "no valid recovery entry", 1, true) then
				return rejectUnsafeProfile("integrity mismatch without recovery entry")
			end

			local preparedOk, prepared = pcall(function()
				local profile = sanitize(reconcile(candidate, DataTemplate.New()))
				ProfileIntegrity.Seal(profile)
				return profile
			end)
			if not preparedOk then
				return rejectUnsafeProfile("schema preparation failed: " .. tostring(prepared))
			end
			local profile = prepared
			local previousLastSeen = if type(profile.Meta) == "table" and type(profile.Meta.LastSeen) == "number"
				then profile.Meta.LastSeen
				else now

			profile.Meta.SessionJobId = game.JobId
			profile.Meta.LastSeen = now
			profile.Meta.LastSave = now
			local cacheReady, cacheProblem = pcall(function()
				ProfileIntegrity.Seal(profile)
				document:SetCache(deepCopy(profile))
			end)
			if not cacheReady then

				pcall(function()
					if document:IsOpen() then document:Close() end
				end)
				ModuleLog.Warn("Data", string.format("could not stage %s profile - %s", player.Name, tostring(cacheProblem)))
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
				return false, "Your save changed while loading. Please rejoin in a moment."
			end

			self._profiles[player] = profile
			self._documents[player] = document
			self._atoms[player] = AtomicState.new(profile)
			self._previousLastSeen[player] = previousLastSeen
			self._dirty[player] = false
			self._integrityStatus[player] = {
				Healthy = integrityOk,
				Message = integrityMessage,
				CheckedAt = now,
			}
			if not integrityOk then
				ModuleLog.Warn("Data", string.format("%s profile integrity: %s", player.Name, integrityMessage))
			end
			ModuleLog.Player(player, "save opened")
			ServerTelemetry.RecordPlayerJoined(player.UserId)
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, true)
			return true
		end

		local reason = DocumentCommon.reason(openResult) or "Unknown"
		if reason == "SessionLockedError" then
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
			return false, "Your data is still active on another server. Please wait a moment and rejoin."
		end
		if reason == "BackwardsCompatibilityError" then
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
			return false, "You joined an old server that cannot load your save. Please try a newer server."
		end

		if RunService:IsStudio() and ServerConfig.AllowStudioMemoryFallback then
			ModuleLog.Info("Data", player.Name .. " is using a temporary Studio save")
			local fallback = DataTemplate.New()
			fallback.Meta.SessionJobId = game.JobId
			self._profiles[player] = fallback
			self._atoms[player] = AtomicState.new(fallback)
			local simulatedAway = math.max(120, ServerConfig.StudioSimulatedAwaySeconds or 600)
			self._previousLastSeen[player] = now - simulatedAway
			self._dirty[player] = false
			self._memoryMode[player] = true
			ProfileIntegrity.Seal(fallback)
			self._integrityStatus[player] = { Healthy = true, Message = "temporary Studio profile", CheckedAt = now }
			ServerTelemetry.RecordPlayerJoined(player.UserId)
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, true)
			return true
		end

		ModuleLog.Warn("Data", string.format("could not load %s — %s", player.Name, reason))
		ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false)
		return false, "Your save could not be loaded safely. Please rejoin in a moment."
	end

	function DataService:Get(player: Player)
		return self._profiles[player]
	end

	function DataService:GetRevision(player: Player): number
		local atom = self._atoms[player]
		if not atom then
			return 0
		end
		local _, revision = atom:Read()
		return revision
	end

	function DataService:GetIntegrityStatus(player: Player)
		local profile = self._profiles[player]
		local status = self._integrityStatus[player] or { Healthy = true, Message = "pending", CheckedAt = 0 }
		if not profile then return status end
		local envelope = ProfileIntegrity.Status(profile)
		return {
			Healthy = status.Healthy,
			Message = status.Message,
			CheckedAt = status.CheckedAt,
			Algorithm = envelope.Algorithm,
			Hash = envelope.Hash,
			SealedRevision = envelope.SealedRevision,
			SealedAt = envelope.SealedAt,
			JournalDepth = envelope.JournalDepth,
		}
	end

	function DataService:GetPreviousLastSeen(player: Player): number
		return self._previousLastSeen[player] or os.time()
	end

	function DataService:IsBusy(player: Player): boolean
		local atom = self._atoms[player]
		return atom ~= nil and atom:IsBusy()
	end

	function DataService:AtomicUpdate(
		player: Player,
		callback,
		incrementRevision: boolean?,
		label: string?
	): (boolean, any)
		local profile = self._profiles[player]
		local atom = self._atoms[player]
		if self._releasing[player] then
			return false, "Profile session is closing"
		end
		if not profile or not atom then
			return false, "Profile is not loaded"
		end
		local transactionLabel = label or "unnamed"
		local success, result = atom:Transact(function(draft, revision)

			if self._releasing[player] then
				return { ok = false, message = "Profile session is closing" }
			end
			local callbackResult = callback(draft, revision)
			if type(callbackResult) == "table" and callbackResult.ok == false then
				return callbackResult
			end
			draft.Meta.LastSeen = os.time()

			if transactionLabel ~= "production" then
				sanitize(draft)
				ProfileIntegrity.Record(draft, transactionLabel, revision)
			end
			return callbackResult
		end, incrementRevision)
		if not success then
			ModuleLog.Every(
				"mutation:" .. tostring(player.UserId) .. ":" .. transactionLabel,
				5,
				"Data",
				string.format("%s update '%s' failed — %s", player.Name, label or "unnamed", tostring(result))
			)
			return false, result
		end
		if type(result) == "table" and result.ok == false then
			return true, result
		end
		local committed = atom:Read()
		if committed ~= profile then
			self._profiles[player] = committed
			profile = committed
		end
		self._dirty[player] = true
		if transactionLabel ~= "production" then self:_queueDocumentSync(player) end
		return true, result
	end

	function DataService:Update(player: Player, callback, incrementRevision: boolean?): (boolean, any)
		return self:AtomicUpdate(player, callback, incrementRevision, "legacy")
	end

	function DataService:MarkDirty(player: Player)
		local profile = self._profiles[player]
		if profile then

			self._dirty[player] = true
			self:_queueDocumentSync(player)
		end
	end

	function DataService:_saveUnlocked(player: Player, releaseSession: boolean?): boolean
		local saveStartedAt = os.clock()
		local profile = self._profiles[player]
		if not profile then
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, true)
			return true
		end
		local cacheThread = self._cacheSyncThreads[player]
		if cacheThread then
			task.cancel(cacheThread)
			self._cacheSyncThreads[player] = nil
		end

		if self._memoryMode[player] then
			if releaseSession then
				self:_clearPlayer(player)
			end
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, true)
			return true
		end

		local document = self._documents[player]
		if not document or not document:IsOpen() then
			ModuleLog.Warn("Data", string.format("no open document for %s", player.Name))
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false)
			return false
		end

		local now = os.time()
		local preparedOk, snapshot = pcall(function()
			local safeSnapshot = sanitize(deepCopy(profile))
			safeSnapshot.Meta.LastSeen = now
			safeSnapshot.Meta.LastSave = now
			if releaseSession then
				safeSnapshot.Meta.SessionJobId = ""
			else
				safeSnapshot.Meta.SessionJobId = game.JobId
			end
			ProfileIntegrity.Record(safeSnapshot, releaseSession and "session-release" or "save", safeSnapshot.Meta.Revision)
			ProfileIntegrity.Seal(safeSnapshot)
			return safeSnapshot
		end)
		if not preparedOk then
			ModuleLog.Warn("Data", string.format("save preparation failed for %s — %s", player.Name, tostring(snapshot)))
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false)
			return false
		end
		local cacheOk, cacheError = pcall(document.SetCache, document, snapshot)
		if not cacheOk then
			ModuleLog.Warn("Data", string.format("could not stage save for %s - %s", player.Name, tostring(cacheError)))
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false)
			return false
		end

		local saved = false
		local lastReason = "Unknown"
		for attempt = 1, ServerConfig.SaveRetries do
			local result
			if releaseSession then
				if not document:IsOpen() then

					saved = true
					break
				end
				result = document:Close()
			else
				result = document:Save()
			end
			if DocumentCommon.isOk(result) then
				saved = true
				break
			end
			lastReason = DocumentCommon.reason(result) or "Unknown"
			ModuleLog.Warn(
				"Data",
				string.format(
					"save attempt %d/%d failed for %s — %s",
					attempt,
					ServerConfig.SaveRetries,
					player.Name,
					lastReason
				)
			)
			if releaseSession and not document:IsOpen() then
				break
			end
			if attempt < ServerConfig.SaveRetries then
				task.wait(attempt)
			end
		end

		-- Only warn for a routine mid-session save -- a release-save failure means the player is
		-- already gone (nothing to show them), and that path already has its own retry-in-the-
		-- background handling at the call site in ServerServices.
		if not saved and not releaseSession and self.OnSaveFailed then
			pcall(self.OnSaveFailed, player, lastReason)
		end

		if saved then
			local current = self._profiles[player]
			local currentRevision = current and current.Meta and tonumber(current.Meta.Revision) or -1
			local snapshotRevision = tonumber(snapshot.Meta.Revision) or 0
			if current == profile and currentRevision == snapshotRevision then
				profile.Meta.LastSave = now
				profile.Meta.LastSeen = now
				profile.Meta.Transactions = deepCopy(snapshot.Meta.Transactions)
				profile.Meta.Integrity = deepCopy(snapshot.Meta.Integrity)
				self._dirty[player] = false
			else

				self._dirty[player] = true
			end
			self:_pushLeaderboard(player, current or profile)
		end

		if releaseSession and not saved then
			self._dirty[player] = true
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false)
			return false
		end

		if releaseSession then
			self:_clearPlayer(player)
			if saved then
				ModuleLog.Player(player, "save released")
			end
		elseif saved then

			profile.Meta.LastSave = now
		end
		ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, saved)
		return saved
	end

	function DataService:Save(player: Player, releaseSession: boolean?): boolean

		if releaseSession then self._releasing[player] = true end
		local deadline = os.clock() + (releaseSession and 12 or 6)
		while self._saveBusy[player] and os.clock() < deadline do task.wait() end
		if self._saveBusy[player] then
			if releaseSession then self._releasing[player] = nil end
			ModuleLog.Every("save-busy:" .. tostring(player.UserId), 5, "Data", player.Name .. " save is still in progress")
			return false
		end
		local atom = self._atoms[player]
		while releaseSession and atom and atom:IsBusy() and os.clock() < deadline do task.wait() end
		if releaseSession and atom and atom:IsBusy() then
			self._releasing[player] = nil
			ModuleLog.Every("release-busy:" .. tostring(player.UserId), 5, "Data", player.Name .. " mutation did not settle before release")
			return false
		end
		self._saveBusy[player] = true
		local ok, saved = pcall(self._saveUnlocked, self, player, releaseSession)
		self._saveBusy[player] = nil
		if not ok then
			if releaseSession then self._releasing[player] = nil end
			ModuleLog.Warn("Data", string.format("save crashed safely for %s - %s", player.Name, tostring(saved)))
			return false
		end
		if releaseSession and not saved then self._releasing[player] = nil end
		return saved
	end

	function DataService:SaveAll(releaseSessions: boolean?)
		local players = {}
		for player in self._profiles do
			table.insert(players, player)
		end
		if #players == 0 then
			return true
		end

		if releaseSessions then
			local remaining = #players
			for _, player in players do
				local target = player
				task.spawn(function()
					local ok, err = pcall(function()
						self:Save(target, true)
					end)
					if not ok then
						ModuleLog.Warn("Data", string.format("shutdown save failed for %s — %s", target.Name, tostring(err)))
					end
					remaining -= 1
				end)
			end
			local deadline = os.clock() + 22
			while remaining > 0 and os.clock() < deadline do
				task.wait()
			end
			if remaining > 0 then
				ModuleLog.Warn("Data", string.format("shutdown save deadline reached with %d profile(s) still closing", remaining))
				return false
			end
			return true
		end
		for _, player in players do
			self:Save(player, false)
		end
		return true
	end

	function DataService:StartAutosave(interval: number)
		if self._autosaveThread then
			return
		end
		self._autosaveThread = task.spawn(function()
			while not self._closing do
				task.wait(interval)
				for player in self._profiles do
					if self._dirty[player] then
						self:Save(player, false)
					end
				end
			end
		end)
	end

	function DataService:Shutdown()
		self._closing = true
		if self._autosaveThread then
			task.cancel(self._autosaveThread)
			self._autosaveThread = nil
		end

		for userId, worker in self._leaderboardWorkers do
			pcall(task.cancel, worker)
			self._leaderboardWorkers[userId] = nil
			self._leaderboardPushBusy[userId] = nil
			self._leaderboardPending[userId] = nil
		end
		local released = self:SaveAll(true)
		if not released then

			return
		end

		pcall(function()
			self._playerStore:CloseAllDocuments()
		end)
		pcall(function()
			self._sharedStore:CloseAllDocuments()
		end)
	end

	return DataService
end
