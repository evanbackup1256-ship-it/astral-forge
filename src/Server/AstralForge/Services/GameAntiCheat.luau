--!strict

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))

	local AntiCheat = {}
	AntiCheat.__index = AntiCheat

	type PlayerState = {
		LastCash: any,
		LastSeen: number,
		BaselineReady: boolean,
		LastRepairAt: number,
		LastRepairAction: string,
		LastRepairCount: number,
		LastAction: string,
		LastActionAt: number,
	}

	local MAX_SAFE = 1e308
	local ROOT_CURRENCIES = { "Cash", "Vault", "Cores", "Stardust", "Rebirths", "RunCash", "LifetimeCash" }
	local ITEM_DEFINITIONS = {}
	for _, definition in GameConfig.Items.Definitions do
		ITEM_DEFINITIONS[definition.Id] = definition
	end
	local MACHINE_LEVELS = {}
	for _, definition in GameConfig.Machines do
		MACHINE_LEVELS[definition.Id] = definition
	end
	local RESEARCH_LEVELS = {}
	for _, definition in GameConfig.Research do
		RESEARCH_LEVELS[definition.Id] = definition
	end
	local GRID_LEVELS = {}
	for _, definition in GameConfig.GridUpgrades do
		GRID_LEVELS[definition.Id] = definition
	end

	local function finite(value: any): boolean
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	local function clampNumber(value: any, minimum: number, maximum: number): (number, boolean)
		local nextValue = finite(value) and value or minimum
		local clamped = math.clamp(nextValue, minimum, maximum)
		return clamped, clamped ~= value
	end

	local function clampSparseLevels(map: any, byId: any): number
		if type(map) ~= "table" then
			return 1
		end
		local repairs = 0
		for key, value in map do
			local definition = byId[key]
			if definition == nil then
				map[key] = nil
				repairs += 1
			else
				local current, changed = clampNumber(value, 0, definition.MaxLevel)
				if current <= 0 then
					if value ~= nil then
						map[key] = nil
						repairs += 1
					end
				elseif changed then
					map[key] = math.floor(current)
					repairs += 1
				end
			end
		end
		return repairs
	end

	local function stateOf(self, player: Player): PlayerState
		local state = self._players[player]
		if state then
			return state
		end
		state = {
			LastCash = 0,
			LastSeen = os.clock(),
			BaselineReady = false,
			LastRepairAt = -math.huge,
			LastRepairAction = "",
			LastRepairCount = 0,
			LastAction = "",
			LastActionAt = 0,
		}
		self._players[player] = state
		return state
	end

	function AntiCheat.new()
		local self = setmetatable({}, AntiCheat)
		self._players = {} :: { [Player]: PlayerState }
		return self
	end

	function AntiCheat:Observe(player: Player, action: string, profile): boolean
		if type(profile) ~= "table" then
			return false
		end
		local state = stateOf(self, player)
		local now = os.clock()
		if state.LastAction == action and now - state.LastActionAt < 0.2 then
			state.LastActionAt = now
			return true
		end
		state.LastAction = action
		state.LastActionAt = now
		local repairs = 0
		local persistKeys = { Cash = true, Vault = true, RunCash = true, LifetimeCash = true }
		for _, key in ROOT_CURRENCIES do
			if persistKeys[key] then
				local persisted = Economy.Persist(profile[key])
				if type(persisted) == "number" and persisted < 0 then
					persisted = 0
				end
				if persisted ~= profile[key] then
					profile[key] = persisted
					repairs += 1
				end
			else
				local value, changed = clampNumber(profile[key], 0, MAX_SAFE)
				if changed then
					profile[key] = value
					repairs += 1
				end
			end
		end
		if type(profile.Machines) ~= "table" then
			profile.Machines = {}
			repairs += 1
		end
		if type(profile.Research) ~= "table" then
			profile.Research = {}
			repairs += 1
		end
		if type(profile.GridUpgrades) ~= "table" then
			profile.GridUpgrades = {}
			repairs += 1
		end
		repairs += clampSparseLevels(profile.Machines, MACHINE_LEVELS)
		repairs += clampSparseLevels(profile.Research, RESEARCH_LEVELS)
		repairs += clampSparseLevels(profile.GridUpgrades, GRID_LEVELS)

		local capacityOk, capacityResult = pcall(Economy.Capacity, profile, os.time())
		if capacityOk then
			local nextVault = Economy.Min(profile.Vault, capacityResult)
			if nextVault ~= profile.Vault then
				profile.Vault = nextVault
				repairs += 1
			end
		end

		local boostValid = type(profile.ActiveBoost) == "table"
			and (profile.ActiveBoost.Id == "" or GameConfig.Boosts[profile.ActiveBoost.Id] ~= nil)
		if not boostValid then
			profile.ActiveBoost = { Id = "", EndsAt = 0 }
			repairs += 1
		else
			local endsAt, endsChanged = clampNumber(profile.ActiveBoost.EndsAt, 0, 4_000_000_000)
			if endsChanged then
				profile.ActiveBoost.EndsAt = math.floor(endsAt)
				repairs += 1
			end
		end

		if type(profile.Items) ~= "table" then
			profile.Items = {
				Inventory = {}, Discovered = {}, Equipped = {}, Essence = 0, Keys = {}, Pity = {}, Shop = {},
				AutoSalvage = { Enabled = false, KeepNew = true, Rarities = {} },
			}
			repairs += 1
		else
			local essence, essenceChanged = clampNumber(profile.Items.Essence, 0, MAX_SAFE)
			if essenceChanged then
				profile.Items.Essence = essence
				repairs += 1
			end
			if type(profile.Items.Inventory) ~= "table" then
				profile.Items.Inventory = {}
				repairs += 1
			end
			if type(profile.Items.Equipped) ~= "table" then
				profile.Items.Equipped = {}
				repairs += 1
			end
			for uid, item in profile.Items.Inventory do
				local definition = type(item) == "table" and ITEM_DEFINITIONS[item.DefinitionId]
				if type(uid) ~= "string" or not definition then
					profile.Items.Inventory[uid] = nil
					repairs += 1
				else
					local level, levelChanged = clampNumber(item.Level, 1, definition.MaxLevel)
					if levelChanged then
						item.Level = math.floor(level)
						repairs += 1
					end
				end
			end
			for target, uid in profile.Items.Equipped do
				if type(target) ~= "string" or type(uid) ~= "string" or not profile.Items.Inventory[uid] then
					profile.Items.Equipped[target] = nil
					repairs += 1
				end
			end
		end

		if type(profile.Anomaly) ~= "table" then
			profile.Anomaly = { Charge = 0, Fragments = 0, Stabilizations = 0, Chain = 0, BestChain = 0 }
			repairs += 1
		else
			-- Highest possible target ceiling across all CoreTiers, not just the base
			-- MaximumTarget -- a legitimate high-CoreTier player's Charge can exceed the base
			-- ceiling by design (see GameConfig.Anomalies.CoreTiers[].MaximumTargetBonus), so
			-- clamping against the un-bonused ceiling here would repeatedly "repair" (clamp
			-- down) a real player's correctly-earned charge every anti-cheat pass.
			local maxTargetBonus = 0
			for _, tierConfig in GameConfig.Anomalies.CoreTiers do
				maxTargetBonus = math.max(maxTargetBonus, tierConfig.MaximumTargetBonus)
			end
			local charge, chargeChanged =
				clampNumber(profile.Anomaly.Charge, 0, (GameConfig.Anomalies.MaximumTarget + maxTargetBonus) * 1.5)
			local fragments, fragmentsChanged = clampNumber(profile.Anomaly.Fragments, 0, MAX_SAFE)
			if chargeChanged then
				profile.Anomaly.Charge = charge
				repairs += 1
			end
			if fragmentsChanged then
				profile.Anomaly.Fragments = math.floor(fragments)
				repairs += 1
			end

			local maxCoreTier = #GameConfig.Anomalies.CoreTiers
			local coreTier, coreTierChanged = clampNumber(profile.Anomaly.CoreTier or 0, 0, maxCoreTier)
			local coreXP, coreXPChanged = clampNumber(profile.Anomaly.CoreXP or 0, 0, MAX_SAFE)
			local combo, comboChanged = clampNumber(profile.Anomaly.Combo or 0, 0, GameConfig.Anomalies.PulseComboMax)
			local bestCombo, bestComboChanged =
				clampNumber(profile.Anomaly.BestCombo or 0, 0, GameConfig.Anomalies.PulseComboMax)
			if coreTierChanged then
				profile.Anomaly.CoreTier = math.floor(coreTier)
				repairs += 1
			end
			if coreXPChanged then
				profile.Anomaly.CoreXP = coreXP
				repairs += 1
			end
			if comboChanged then
				profile.Anomaly.Combo = math.floor(combo)
				repairs += 1
			end
			if bestComboChanged then
				profile.Anomaly.BestCombo = math.floor(bestCombo)
				repairs += 1
			end
			if type(profile.Anomaly.Loadout) ~= "table" then
				profile.Anomaly.Loadout = {}
				repairs += 1
			elseif #profile.Anomaly.Loadout > GameConfig.Anomalies.LoadoutSlots then
				local trimmed = {}
				for index = 1, GameConfig.Anomalies.LoadoutSlots do
					trimmed[index] = profile.Anomaly.Loadout[index]
				end
				profile.Anomaly.Loadout = trimmed
				repairs += 1
			end
		end

		if type(profile.Flags) ~= "table" then
			profile.Flags = {
				TutorialDone = false,
				TutorialStep = 1,
				TutorialRewardClaimed = false,
				LastSeenVersion = "",
				UnlimitedMoney = false,
			}
			repairs += 1
		elseif not RunService:IsStudio() and profile.Flags.UnlimitedMoney then
			profile.Flags.UnlimitedMoney = false
			repairs += 1
		end
		if type(profile.Stats) == "table" then
			if profile.Stats.Collected ~= nil then
				local persisted = Economy.Persist(profile.Stats.Collected)
				if type(persisted) == "number" and persisted < 0 then
					persisted = 0
				end
				if persisted ~= profile.Stats.Collected then
					profile.Stats.Collected = persisted
					repairs += 1
				end
			end
			for _, key in
				{
					"PlayTime",
					"Taps",
					"MachinesBought",
					"ResearchBought",
					"CratesOpened",
					"ItemsFound",
					"ItemsSalvaged",
					"ShopPurchases",
					"AnomalyPulses",
					"AnomalyStabilizations",
					"AnomalyProtocols",
					"AnomalyDirectives",
					"OrdersCompleted",
					"PowerMoves",
					"ContinuumUpgrades",
					"Joins",
				}
			do
				local value, changed = clampNumber(profile.Stats[key], 0, MAX_SAFE)
				if changed then
					profile.Stats[key] = value
					repairs += 1
				end
			end
		end
		if type(profile.Meta) == "table" then
			local revision, revisionChanged = clampNumber(profile.Meta.Revision, 0, MAX_SAFE)
			if revisionChanged then
				profile.Meta.Revision = math.floor(revision)
				repairs += 1
			end
		end

		if repairs > 0 then

			local now2 = os.clock()
			if
				state.LastRepairAction ~= action
				or state.LastRepairCount ~= repairs
				or now2 - state.LastRepairAt >= 30
			then
				state.LastRepairAction = action
				state.LastRepairCount = repairs
				state.LastRepairAt = now2
				player:SetAttribute("AF_LastRepair", action)
			end
		end

		-- Cash velocity: observation only, never a correction. Load / Production / AutoForge /
		-- Maintenance apply server-authoritative lump sums (offline payout, vault auto-collect)
		-- that dwarf production*elapsed, and Studio test grants do the same. Logging those as
		-- "cash jump" spam is a false positive. Only telemetry live games after a baseline,
		-- and never touch the profile.
		local skipVelocity = not state.BaselineReady
			or RunService:IsStudio()
			or action == "Load"
			or action == "Production"
			or action == "AutoForge"
			or action == "Maintenance"
		if not skipVelocity then
			local elapsed = math.max(0, os.clock() - state.LastSeen)
			if elapsed > 0.05 and elapsed < 3600 then
				local delta = Economy.Sub(profile.Cash, state.LastCash)
				if Economy.Gt(delta, 0) then
					local productionOk, productionRate = pcall(Economy.Production, profile, os.time())
					if productionOk then
						local offlineOk, offlineHours = pcall(Economy.OfflineHours, profile)
						local offlineSeconds = 86400
						if offlineOk and type(offlineHours) == "number" then
							offlineSeconds = offlineHours * 3600
						end
						local burstSeconds = elapsed + offlineSeconds
						local CEILING_MULTIPLIER = 12
						local ceiling = Economy.Mul(Economy.Mul(productionRate, burstSeconds), CEILING_MULTIPLIER)
						local ceilingFloor = Economy.Max(ceiling, 10_000)
						if Economy.Gt(delta, ceilingFloor) then
							ModuleLog.Every(
								string.format("velocity:%d", player.UserId),
								30,
								"Security",
								string.format("u=%d Cash jump exceeded production ceiling (observed only, not corrected)", player.UserId)
							)
						end
					end
				end
			end
		end

		state.LastCash = profile.Cash
		state.LastSeen = os.clock()
		state.BaselineReady = true
		return repairs == 0
	end

	-- Call after any server-computed lump-sum grant that is not itself paced by the player's
	-- current production rate (offline earnings being the main one -- a player away for hours
	-- can legitimately return to a Cash jump the velocity check's production-rate*elapsed
	-- ceiling was never meant to evaluate, since that formula only covers earning while online
	-- and active). Re-seeds the velocity baseline to the post-grant balance so the next Observe
	-- measures real gameplay activity from here, not the grant itself.
	function AntiCheat:SyncBaseline(player: Player, profile): ()
		if type(profile) ~= "table" then
			return
		end
		local state = stateOf(self, player)
		state.LastCash = profile.Cash
		state.LastSeen = os.clock()
		state.BaselineReady = true
	end

	function AntiCheat:Forget(player: Player): ()
		self._players[player] = nil
	end

	return AntiCheat
end
