--!strict

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))

	local ForgeEchoService = {}
	local Config = GameConfig.ForgeEchoes

	local traitById = {}
	for _, trait in Config.Traits do
		traitById[trait.Id] = trait
	end

	local patternAffinity = {
		Collect = "Industry",
		Surge = "Impulse",
		Build = "Craft",
		Explore = "Void",
	}

	local function ensure(profile)
		local echoes = profile.ForgeEchoes
		if type(echoes) ~= "table" then
			echoes = {
				Charge = 0,
				Resonance = 0,
				Captures = 0,
				NextId = 1,
				Pattern = { Collect = 0, Surge = 0, Build = 0, Explore = 0 },
				Draft = { Id = "", Choices = {} },
				Inventory = {},
				Equipped = { ["1"] = "", ["2"] = "", ["3"] = "" },
			}
			profile.ForgeEchoes = echoes
		end
		echoes.Pattern = type(echoes.Pattern) == "table" and echoes.Pattern
			or { Collect = 0, Surge = 0, Build = 0, Explore = 0 }
		echoes.Draft = type(echoes.Draft) == "table" and echoes.Draft or { Id = "", Choices = {} }
		echoes.Draft.Choices = type(echoes.Draft.Choices) == "table" and echoes.Draft.Choices or {}
		echoes.Inventory = type(echoes.Inventory) == "table" and echoes.Inventory or {}
		echoes.Equipped = type(echoes.Equipped) == "table" and echoes.Equipped
			or { ["1"] = "", ["2"] = "", ["3"] = "" }
		return echoes
	end

	local function inventoryCount(echoes): number
		local count = 0
		for _ in echoes.Inventory do count += 1 end
		return count
	end

	local function unlockedSlots(echoes): number
		local captures = math.max(0, math.floor(tonumber(echoes.Captures) or 0))
		local slots = 1
		for index, requirement in Config.SlotCaptureRequirements do
			if captures >= requirement then slots = index end
		end
		return math.clamp(slots, 1, Config.MaxSlots)
	end

	local function effectValue(instance, trait): number
		local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, Config.MaxLevel)
		local strength = math.clamp(tonumber(instance.Strength) or 1, 0.75, 1.5)
		return (trait.BaseEffect + trait.EffectPerLevel * (level - 1)) * strength
	end

	local function dominantPattern(echoes): (string, string)
		local best = "Collect"
		local value = -1
		for _, id in { "Collect", "Surge", "Build", "Explore" } do
			local score = math.max(0, tonumber(echoes.Pattern[id]) or 0)
			if score > value then
				best = id
				value = score
			end
		end
		return best, patternAffinity[best]
	end

	local function display(instance, uidOverride: string?)
		local trait = traitById[instance.TraitId]
		if not trait then return nil end
		local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, Config.MaxLevel)
		return {
			Uid = tostring(uidOverride or instance.Uid or ""),
			TraitId = trait.Id,
			Name = trait.Name,
			Description = trait.Description,
			Affinity = trait.Affinity,
			EffectKind = trait.EffectKind,
			Level = level,
			Strength = math.clamp(tonumber(instance.Strength) or 1, 0.75, 1.5),
			EffectValue = effectValue(instance, trait),
			UpgradeCost = level >= Config.MaxLevel and 0
				or math.max(1, math.floor(Config.UpgradeBaseDust * (Config.UpgradeScale ^ (level - 1)) + 0.5)),
			Color = trait.Color,
			CapturedAt = math.max(0, math.floor(tonumber(instance.CapturedAt) or 0)),
			Origin = tostring(instance.Origin or "Collect"),
		}
	end

	function ForgeEchoService.Record(profile, patternId: string, weight: number): boolean
		if (tonumber(profile.Rebirths) or 0) < GameConfig.Unlocks.Echoes.Target then return false end
		if not patternAffinity[patternId] then return false end
		local echoes = ensure(profile)
		if #(echoes.Draft.Choices) > 0 then return false end
		local safeWeight = math.clamp(tonumber(weight) or 0, 0, 14)
		if safeWeight <= 0 then return false end
		echoes.Pattern[patternId] = math.min(1e9, (tonumber(echoes.Pattern[patternId]) or 0) + safeWeight)
		echoes.Charge = math.min(Config.ChargeTarget, (tonumber(echoes.Charge) or 0) + safeWeight)
		return true
	end

	function ForgeEchoService.Capture(profile, random: Random): (boolean, string, any?)
		local echoes = ensure(profile)
		if #(echoes.Draft.Choices) > 0 then return false, "Choose one of the echoes already waiting." end
		if inventoryCount(echoes) >= Config.InventoryLimit then return false, "Your echo vault is full. Dismantle one first." end
		if (tonumber(echoes.Charge) or 0) < Config.ChargeTarget then return false, "The forge has not recorded a complete pattern yet." end
		local origin, affinity = dominantPattern(echoes)
		local pool = table.clone(Config.Traits)
		local selected = {}
		local used = {}
		local preferred = {}
		for _, trait in pool do if trait.Affinity == affinity then table.insert(preferred, trait) end end
		local first = preferred[random:NextInteger(1, #preferred)]
		table.insert(selected, first)
		used[first.Id] = true
		while #selected < 3 do
			local candidate = pool[random:NextInteger(1, #pool)]
			if not used[candidate.Id] then
				used[candidate.Id] = true
				table.insert(selected, candidate)
			end
		end
		local qualityBonus = math.min(
			Config.MaxResonanceQualityBonus,
			math.sqrt(math.max(0, tonumber(echoes.Resonance) or 0)) * 0.006
		)
		local draftId = string.format("D%d_%d", os.time(), random:NextInteger(1000, 9999))
		local choices = {}
		for index, trait in selected do
			local strength = math.clamp(0.9 + random:NextNumber() * 0.22 + qualityBonus, 0.9, 1.32)
			choices[index] = {
				Uid = draftId .. "_" .. tostring(index),
				TraitId = trait.Id,
				Level = 1,
				Strength = strength,
				CapturedAt = os.time(),
				Origin = origin,
			}
		end
		echoes.Draft = { Id = draftId, Choices = choices }
		echoes.Charge = 0
		echoes.Pattern = { Collect = 0, Surge = 0, Build = 0, Explore = 0 }
		return true, "Three echoes answered your forge pattern.", { Origin = origin }
	end

	function ForgeEchoService.Claim(profile, choiceId: any): (boolean, string, any?)
		if type(choiceId) ~= "string" then return false, "That echo is not part of this capture." end
		local echoes = ensure(profile)
		local picked = nil
		for _, choice in echoes.Draft.Choices do
			if choice.Uid == choiceId then picked = choice break end
		end
		if not picked or not traitById[picked.TraitId] then return false, "That echo is no longer available." end
		if inventoryCount(echoes) >= Config.InventoryLimit then return false, "Your echo vault is full." end
		local uid = "E" .. tostring(math.max(1, math.floor(tonumber(echoes.NextId) or 1)))
		echoes.NextId = math.max(1, math.floor(tonumber(echoes.NextId) or 1)) + 1
		picked.Uid = uid
		echoes.Inventory[uid] = picked
		echoes.Captures = math.max(0, math.floor(tonumber(echoes.Captures) or 0)) + 1
		echoes.Draft = { Id = "", Choices = {} }
		local slots = unlockedSlots(echoes)
		for slot = 1, slots do
			local key = tostring(slot)
			if not echoes.Equipped[key] or echoes.Equipped[key] == "" then
				echoes.Equipped[key] = uid
				break
			end
		end
		local shown = display(picked)
		return true, "Captured " .. (shown and shown.Name or "a forge echo") .. ".", { EchoUid = uid }
	end

	function ForgeEchoService.Equip(profile, uid: any, slot: any): (boolean, string)
		if type(uid) ~= "string" or type(slot) ~= "number" or slot ~= math.floor(slot) then return false, "Choose a valid echo slot." end
		local echoes = ensure(profile)
		if not echoes.Inventory[uid] then return false, "That echo is not in your vault." end
		if slot < 1 or slot > unlockedSlots(echoes) then return false, "That echo slot has not stabilized yet." end
		for key, equippedUid in echoes.Equipped do if equippedUid == uid then echoes.Equipped[key] = "" end end
		echoes.Equipped[tostring(slot)] = uid
		return true, "Echo linked to slot " .. tostring(slot) .. "."
	end

	function ForgeEchoService.UpgradeCost(instance): number
		local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, Config.MaxLevel)
		return math.max(1, math.floor(Config.UpgradeBaseDust * (Config.UpgradeScale ^ (level - 1)) + 0.5))
	end

	function ForgeEchoService.Upgrade(profile, uid: any): (boolean, string, any?)
		if type(uid) ~= "string" then return false, "Choose an echo to tune." end
		local echoes = ensure(profile)
		local instance = echoes.Inventory[uid]
		if not instance or not traitById[instance.TraitId] then return false, "That echo is not in your vault." end
		local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, Config.MaxLevel)
		if level >= Config.MaxLevel then return false, "That echo is already perfectly tuned." end
		local cost = ForgeEchoService.UpgradeCost(instance)
		if Economy.Lt(profile.Stardust, cost) then return false, "You need more stardust to tune that echo." end
		profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, cost))
		instance.Level = level + 1
		return true, "Echo tuned to level " .. tostring(instance.Level) .. ".", { Cost = cost, EchoUid = uid }
	end

	function ForgeEchoService.Dismantle(profile, uid: any): (boolean, string, any?)
		if type(uid) ~= "string" then return false, "Choose an echo to dismantle." end
		local echoes = ensure(profile)
		local instance = echoes.Inventory[uid]
		if not instance then return false, "That echo is not in your vault." end
		for key, equippedUid in echoes.Equipped do if equippedUid == uid then echoes.Equipped[key] = "" end end
		local level = math.max(1, math.floor(tonumber(instance.Level) or 1))
		local gained = 5 + level * Config.ResonancePerDismantleLevel
		echoes.Resonance = math.max(0, math.floor(tonumber(echoes.Resonance) or 0)) + gained
		echoes.Inventory[uid] = nil
		return true, "Echo returned " .. tostring(gained) .. " resonance.", { Resonance = gained }
	end

	function ForgeEchoService.State(profile)
		local echoes = ensure(profile)
		local inventory = {}
		for uid, instance in echoes.Inventory do
			local shown = display(instance, uid)
			if shown then table.insert(inventory, shown) end
		end
		table.sort(inventory, function(a, b)
			if a.Level == b.Level then return a.Uid < b.Uid end
			return a.Level > b.Level
		end)
		local choices = {}
		for index, choice in echoes.Draft.Choices do choices[index] = display(choice) end
		local slots = unlockedSlots(echoes)
		local equipped = {}
		local affinities = {}
		local equippedCount = 0
		for slot = 1, Config.MaxSlots do
			local uid = echoes.Equipped[tostring(slot)] or ""
			local shown = uid ~= "" and echoes.Inventory[uid] and display(echoes.Inventory[uid], uid) or nil
			equipped[slot] = { Slot = slot, Unlocked = slot <= slots, Echo = shown }
			if shown and slot <= slots then
				equippedCount += 1
				affinities[shown.Affinity] = true
			end
		end
		local affinityCount = 0
		for _ in affinities do affinityCount += 1 end
		local harmony = equippedCount >= 2 and affinityCount == equippedCount
		local origin, _ = dominantPattern(echoes)
		local nextRequirement = slots < Config.MaxSlots and Config.SlotCaptureRequirements[slots + 1] or nil
		return {
			Charge = math.clamp(tonumber(echoes.Charge) or 0, 0, Config.ChargeTarget),
			ChargeTarget = Config.ChargeTarget,
			Ready = (tonumber(echoes.Charge) or 0) >= Config.ChargeTarget,
			Resonance = math.max(0, math.floor(tonumber(echoes.Resonance) or 0)),
			Captures = math.max(0, math.floor(tonumber(echoes.Captures) or 0)),
			InventoryLimit = Config.InventoryLimit,
			MaxLevel = Config.MaxLevel,
			SlotsUnlocked = slots,
			NextSlotAt = nextRequirement,
			Harmony = harmony,
			HarmonyBonus = harmony and Config.HarmonyBonus or 0,
			DominantPattern = origin,
			Pattern = {
				Collect = math.max(0, tonumber(echoes.Pattern.Collect) or 0),
				Surge = math.max(0, tonumber(echoes.Pattern.Surge) or 0),
				Build = math.max(0, tonumber(echoes.Pattern.Build) or 0),
				Explore = math.max(0, tonumber(echoes.Pattern.Explore) or 0),
			},
			DraftId = tostring(echoes.Draft.Id or ""),
			Choices = choices,
			Inventory = inventory,
			Equipped = equipped,
		}
	end

	return table.freeze(ForgeEchoService)
end
