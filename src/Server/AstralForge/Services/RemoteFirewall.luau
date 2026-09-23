--!strict

return function(loadService: (string) -> any)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Protocol = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("Protocol"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local RemoteFirewallMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RemoteFirewallMath"))
	local ServerTelemetry = loadService("ServerTelemetry")

	type Rule = {
		Cost: number,
		Cooldown: number,
	}

	type Bucket = {
		Tokens: number,
		LastRefill: number,
		LastAction: { [string]: number },
		LastActionCount: number,
		Strikes: number,
		LastStrike: number,
		QuarantineUntil: number,
		WindowStart: number,
		WindowCount: number,
		LastRejectedAction: string?,
	}

	type ClientIntegrityState = {
		Count: number,
		LastAt: number,
		Kinds: { [string]: number },
	}

	type ConfirmedProof = {
		ServerConfirmed: boolean,
		CorroboratedSignals: number,
		Rule: string,
	}

	local Firewall = {}
	Firewall.__index = Firewall

	local ACTIONS: { [string]: boolean } = {}
	for _, action in Protocol.Actions do
		ACTIONS[action] = true
	end

	local CLIENT_SIGNAL_RULES: { [string]: { [string]: boolean } } = {
		MEMORY_INTEGRITY_VIOLATION = {
			GC_WEAK_VALUE_RETAINED_V1 = true,
		},
		ENVIRONMENT_HOOK_VIOLATION = {
			GETFENV_TIMING_PROXY_V1 = true,
		},
		PHYSICS_INTEGRITY_VIOLATION = {
			CLIENT_MOTION_ENVELOPE_V1 = true,
		},
	}
	local CLIENT_INTEGRITY_REPORTS: { [Player]: ClientIntegrityState } = {}

	local DEFAULT_RULE: Rule = { Cost = 1, Cooldown = 0.06 }


	local COOLDOWN_KEY_FIELDS = RemoteFirewallMath.COOLDOWN_KEY_FIELDS

	local function cooldownKey(action: string, payload: any): string
		return RemoteFirewallMath.CooldownKey(action, payload, COOLDOWN_KEY_FIELDS)
	end

	local RULES: { [string]: Rule } = {
		[Protocol.Actions.GetState] = { Cost = 0.35, Cooldown = 0.18 },
		[Protocol.Actions.MeasureLatency] = { Cost = 0.05, Cooldown = 1.5 },
		[Protocol.Actions.GetPlayers] = { Cost = 0.35, Cooldown = 0.2 },
		[Protocol.Actions.SubmitFeedback] = { Cost = 4, Cooldown = 45 },
		[Protocol.Actions.ReportPlayer] = { Cost = 4, Cooldown = 60 },
		[Protocol.Actions.GetPlayerMirror] = { Cost = 0.6, Cooldown = 0.2 },
		[Protocol.Actions.VisitPlot] = { Cost = 0.7, Cooldown = 0.45 },
		[Protocol.Actions.LeavePlot] = { Cost = 0.35, Cooldown = 0.2 },
		[Protocol.Actions.NudgeCrew] = { Cost = 0.5, Cooldown = 2.5 },
		[Protocol.Actions.ReportPresence] = { Cost = 0.05, Cooldown = 1.5 },
		[Protocol.Actions.CollectVault] = { Cost = 1, Cooldown = 0.08 },
		[Protocol.Actions.Overcharge] = { Cost = 0.5, Cooldown = 0.06 },
		[Protocol.Actions.PulseAnomaly] = { Cost = 1, Cooldown = 0.08 },
		[Protocol.Actions.SpinWheel] = { Cost = 2, Cooldown = 1.2 },
		[Protocol.Actions.OpenItemCrate] = { Cost = 2, Cooldown = 0.18 },
		[Protocol.Actions.BulkSalvageItems] = { Cost = 2, Cooldown = 0.8 },
		[Protocol.Actions.EquipBestItems] = { Cost = 1.5, Cooldown = 0.7 },
		[Protocol.Actions.ToggleItemLock] = { Cost = 0.5, Cooldown = 0.12 },
		[Protocol.Actions.SetItemAutoSalvage] = { Cost = 0.75, Cooldown = 0.3 },
		[Protocol.Actions.SetAnomalyLoadout] = { Cost = 0.75, Cooldown = 0.3 },
		[Protocol.Actions.SetAutoForge] = { Cost = 0.75, Cooldown = 0.22 },
		[Protocol.Actions.SetSetting] = { Cost = 0.5, Cooldown = 0.12 },
		[Protocol.Actions.SetMobileLayout] = { Cost = 0.75, Cooldown = 0.3 },
		[Protocol.Actions.SetTutorialStep] = { Cost = 0.5, Cooldown = 0.12 },
		[Protocol.Actions.RedeemCode] = { Cost = 2, Cooldown = 1.4 },
		[Protocol.Actions.VerifyCreatorFollow] = { Cost = 1, Cooldown = 0.8 },
		[Protocol.Actions.SyncShop] = { Cost = 1, Cooldown = 1.2 },
		[Protocol.Actions.StudioGrantProduct] = { Cost = 1, Cooldown = 0.4 },
		[Protocol.Actions.GetGuild] = { Cost = 0.4, Cooldown = 0.25 },
		[Protocol.Actions.GetGuildLeaderboard] = { Cost = 0.7, Cooldown = 1 },
		[Protocol.Actions.GetLeaderboard] = { Cost = 0.8, Cooldown = 1 },
		[Protocol.Actions.GetAdminState] = { Cost = 0.5, Cooldown = 0.8 },
		[Protocol.Actions.AdminExecute] = { Cost = 4, Cooldown = 0.8 },
		[Protocol.Actions.CreateGuild] = { Cost = 2, Cooldown = 2 },
		[Protocol.Actions.JoinGuild] = { Cost = 1.5, Cooldown = 1 },
		[Protocol.Actions.LeaveGuild] = { Cost = 1, Cooldown = 1 },
		[Protocol.Actions.DisbandGuild] = { Cost = 2, Cooldown = 2 },
		[Protocol.Actions.KickGuildMember] = { Cost = 1.5, Cooldown = 0.5 },
		[Protocol.Actions.SetGuildRole] = { Cost = 1.5, Cooldown = 0.5 },
		[Protocol.Actions.ContributeGuild] = { Cost = 1, Cooldown = 0.25 },
		[Protocol.Actions.BuyGuildUpgrade] = { Cost = 1.5, Cooldown = 0.7 },
		[Protocol.Actions.ClaimGuildGoal] = { Cost = 1.5, Cooldown = 0.4 },
		[Protocol.Actions.DomainExpansion] = { Cost = 5, Cooldown = 5 },
		[Protocol.Actions.UnlockDomainNode] = { Cost = 1, Cooldown = 0.2 },
		[Protocol.Actions.UpgradeContinuum] = { Cost = 1.5, Cooldown = 0.35 },
		[Protocol.Actions.CaptureEcho] = { Cost = 2, Cooldown = 1.1 },
		[Protocol.Actions.ClaimEcho] = { Cost = 1.5, Cooldown = 0.4 },
		[Protocol.Actions.EquipEcho] = { Cost = 0.75, Cooldown = 0.18 },
		[Protocol.Actions.UpgradeEcho] = { Cost = 1, Cooldown = 0.24 },
		[Protocol.Actions.DismantleEcho] = { Cost = 1.5, Cooldown = 0.5 },
		[Protocol.Actions.ReportClientIntegrity] = { Cost = 0.25, Cooldown = 30 },
		[Protocol.Actions.ReportPerformance] = { Cost = 0.1, Cooldown = 45 },
		[Protocol.Actions.ClaimConvergenceReward] = { Cost = 1, Cooldown = 0.35 },
		[Protocol.Actions.GetTrade] = { Cost = 0.25, Cooldown = 0.15 },
		[Protocol.Actions.InviteTrade] = { Cost = 0.8, Cooldown = 0.55 },
		[Protocol.Actions.RespondTrade] = { Cost = 0.7, Cooldown = 0.22 },
		[Protocol.Actions.UpdateTradeOffer] = { Cost = 0.35, Cooldown = 0.07 },
		[Protocol.Actions.SetTradeReady] = { Cost = 0.45, Cooldown = 0.12 },
		[Protocol.Actions.ConfirmTrade] = { Cost = 1.1, Cooldown = 0.22 },
		[Protocol.Actions.CancelTrade] = { Cost = 0.45, Cooldown = 0.18 },
		[Protocol.Actions.TradeViewAway] = { Cost = 0.2, Cooldown = 0.35 },
	}

	local EXEMPT_ACTIONS: { [string]: boolean } = {
		[Protocol.Actions.GetState] = true,
		[Protocol.Actions.GetTrade] = true,
		[Protocol.Actions.ConfirmTrade] = true,
		[Protocol.Actions.CancelTrade] = true,
		[Protocol.Actions.TradeViewAway] = true,
		[Protocol.Actions.CollectVault] = true,
		[Protocol.Actions.Overcharge] = true,
		[Protocol.Actions.Rebirth] = true,
		[Protocol.Actions.ClaimDaily] = true,
		[Protocol.Actions.ClaimAllMail] = true,
		[Protocol.Actions.VerifyCreatorFollow] = true,
	}

	local function applyFirewallOverrides()
		local overrides = GameConfig.RemoteFirewall and GameConfig.RemoteFirewall.Overrides
		if type(overrides) ~= "table" then return end
		for action, rule in overrides do
			if type(action) == "string" and type(rule) == "table" and type(rule.Cost) == "number" and type(rule.Cooldown) == "number" then
				RULES[action] = { Cost = rule.Cost, Cooldown = rule.Cooldown }
			end
		end
	end

	applyFirewallOverrides()

	local NO_PAYLOAD_ACTIONS: { [string]: boolean } = {
		[Protocol.Actions.GetState] = true,
		[Protocol.Actions.MeasureLatency] = true,
		[Protocol.Actions.GetPlayers] = true,
		[Protocol.Actions.GetTrade] = true,
		[Protocol.Actions.ConfirmTrade] = true,
		[Protocol.Actions.CancelTrade] = true,
		[Protocol.Actions.GetAdminState] = true,
		[Protocol.Actions.CollectVault] = true,
		[Protocol.Actions.Overcharge] = true,
		[Protocol.Actions.Rebirth] = true,
		[Protocol.Actions.DomainExpansion] = true,
		[Protocol.Actions.UpgradeContinuum] = true,
		[Protocol.Actions.CaptureEcho] = true,
		[Protocol.Actions.ClaimDaily] = true,
		[Protocol.Actions.SpinWheel] = true,
		[Protocol.Actions.ClaimExpedition] = true,
		[Protocol.Actions.CompleteTutorial] = true,
		[Protocol.Actions.ReplayTutorial] = true,
		[Protocol.Actions.DismissRelease] = true,
		[Protocol.Actions.OpenRelease] = true,
		[Protocol.Actions.PulseAnomaly] = true,
		[Protocol.Actions.StabilizeAnomaly] = true,
		[Protocol.Actions.ActivateAnomalySurge] = true,
		[Protocol.Actions.SyncShop] = true,
		[Protocol.Actions.LeavePlot] = true,
		[Protocol.Actions.GetGuild] = true,
		[Protocol.Actions.LeaveGuild] = true,
		[Protocol.Actions.DisbandGuild] = true,
		[Protocol.Actions.ClaimGuildGoal] = true,
		[Protocol.Actions.EquipBestItems] = true,
		[Protocol.Actions.ClaimAllMail] = true,
		[Protocol.Actions.VerifyCreatorFollow] = true,
	}

	local function integer(value: any): boolean
		return RemoteFirewallMath.Integer(value)
	end

	local function safeNumber(value: any): boolean
		return RemoteFirewallMath.SafeNumber(value)
	end

	local function inspect(
		value: any,
		depth: number,
		seen: { [any]: boolean },
		budget: { Value: number }
	): (boolean, string?)
		return RemoteFirewallMath.Inspect(value, depth, seen, budget)
	end

	local function stringField(payload: { [any]: any }, key: string, minimum: number, maximum: number): boolean
		return RemoteFirewallMath.StringField(payload, key, minimum, maximum)
	end

	-- Bounds the array itself (max entry count) and every entry's own length, rejecting anything
	-- malformed outright rather than truncating/coercing it -- a mismatched size here is a sign
	-- of a hand-crafted payload, not a legitimate client miscount.
	local function stringArrayField(payload: { [any]: any }, key: string, maxEntries: number, entryMinLen: number, entryMaxLen: number): boolean
		return RemoteFirewallMath.StringArrayField(payload, key, maxEntries, entryMinLen, entryMaxLen)
	end

	local function numberField(
		payload: { [any]: any },
		key: string,
		minimum: number,
		maximum: number,
		mustBeInteger: boolean?
	): boolean
		return RemoteFirewallMath.NumberField(payload, key, minimum, maximum, mustBeInteger)
	end

	local function coerceUserId(raw: any): number?
		local value = raw
		if typeof(value) == "Instance" and value:IsA("Player") then
			value = value.UserId
		end
		return RemoteFirewallMath.CoerceUserId(value, RunService:IsStudio())
	end

	local function extractUserId(payload: any): any
		if typeof(payload) == "Instance" and payload:IsA("Player") then
			return payload.UserId
		end
		return RemoteFirewallMath.ExtractUserId(payload)
	end

	local function userIdField(payload: any): boolean
		return coerceUserId(extractUserId(payload)) ~= nil
	end

	Firewall.CoerceUserId = coerceUserId
	Firewall.ExtractUserId = extractUserId

	local function validateActionPayload(action: string, payload: any): (boolean, string?)
		if payload == nil then
			if NO_PAYLOAD_ACTIONS[action] then
				return true
			end
			return false, "payload is required"
		end
		if type(payload) ~= "table" then
			return false, "payload must be a table"
		end
		local ok, reason = inspect(payload, 0, {}, { Value = 0 })
		if not ok then
			return false, reason
		end
		-- Grant actions attach live session fields (Gen/N). Those are auth, not an
		-- action payload — rejecting them trapped players in the changelog overlay
		-- (DismissRelease) and would also break CollectVault/Overcharge/Rebirth.
		if NO_PAYLOAD_ACTIONS[action] then
			local SESSION_KEYS = { Gen = true, N = true, Auth = true, Txn = true, TxnId = true }
			for key in payload do
				if not SESSION_KEYS[key] then
					return false, "this action does not accept a payload"
				end
			end
		end

		if action == Protocol.Actions.SubmitFeedback then
			if not stringField(payload, "Category", 3, 16) or not stringField(payload, "Message", 8, 600) then
				return false, "invalid feedback"
			end
			local category = payload.Category
			if category ~= "Bug" and category ~= "Suggestion" and category ~= "Balance" and category ~= "Other" then
				return false, "invalid feedback category"
			end
		elseif action == Protocol.Actions.ReportPlayer then
			if not stringField(payload, "Reason", 3, 16) or not userIdField(payload) then
				return false, "invalid report payload"
			end
			if payload.Details ~= nil and not stringField(payload, "Details", 0, 400) then
				return false, "invalid report details"
			end
		elseif action == Protocol.Actions.SetSetting then
			if type(payload.Values) == "table" then
				local count = 0
				for key, _ in payload.Values do
					count += 1
					if count > 24 or type(key) ~= "string" or not numberField(payload.Values, key, 0, 1) then
						return false, "invalid setting payload"
					end
				end
				if count == 0 then
					return false, "invalid setting payload"
				end
				if payload.Label ~= nil and not stringField(payload, "Label", 1, 80) then
					return false, "invalid setting payload"
				end
			elseif not stringField(payload, "Key", 1, 40) or not numberField(payload, "Value", 0, 1) then
				return false, "invalid setting payload"
			end

		elseif action == Protocol.Actions.SetMobileLayout then
			if type(payload.Values) ~= "table" then
				return false, "mobile layout values are missing"
			end
			local allowedLayout = {
				MobileQuickX = true,
				MobileQuickY = true,
				MobileDockX = true,
				MobileDockY = true,
				MobileToastX = true,
				MobileToastY = true,
			}
			local count = 0
			for key, _ in payload.Values do
				count += 1
				if not allowedLayout[key] or not numberField(payload.Values, key, 0, 1) then
					return false, "invalid mobile layout value"
				end
			end
			if count < 1 or count > 6 then
				return false, "invalid mobile layout size"
			end
		elseif action == Protocol.Actions.RedeemCode then
			if not stringField(payload, "Code", 1, 32) then
				return false, "invalid code payload"
			end
		elseif action == Protocol.Actions.VerifyCreatorFollow then
			if payload ~= nil and type(payload) ~= "table" then
				return false, "invalid follow verification payload"
			end
		elseif action == Protocol.Actions.StudioGrantProduct then
			if not stringField(payload, "Id", 1, 64) then
				return false, "invalid studio product payload"
			end
		elseif action == Protocol.Actions.OpenItemCrate then
			if not stringField(payload, "Id", 1, 48) or not numberField(payload, "Count", 1, 5, true) then
				return false, "invalid crate payload"
			end
		elseif action == Protocol.Actions.EquipItem then
			if not stringField(payload, "Uid", 1, 48) or not stringField(payload, "Target", 1, 96) then
				return false, "invalid socket payload"
			end
		elseif action == Protocol.Actions.UnequipItem then
			if not stringField(payload, "Target", 1, 96) then
				return false, "invalid socket payload"
			end
		elseif action == Protocol.Actions.UpgradeItem or action == Protocol.Actions.SalvageItem then
			if not stringField(payload, "Uid", 1, 48) then
				return false, "invalid item payload"
			end
		elseif action == Protocol.Actions.ToggleItemLock then
			if not stringField(payload, "Uid", 1, 48) then
				return false, "invalid relic lock payload"
			end
		elseif action == Protocol.Actions.BulkSalvageItems then
			if type(payload.Uids) ~= "table" then
				return false, "bulk salvage selection is missing"
			end
			local count = 0
			for _, uid in payload.Uids do
				count += 1
				if count > 25 or type(uid) ~= "string" or #uid < 1 or #uid > 48 then
					return false, "invalid bulk salvage selection"
				end
			end
			if count < 1 then return false, "bulk salvage selection is empty" end
		elseif action == Protocol.Actions.SetItemAutoSalvage then
			if type(payload.Enabled) ~= "boolean" or type(payload.KeepNew) ~= "boolean" or type(payload.Rarities) ~= "table" then
				return false, "invalid auto-salvage payload"
			end
			local count = 0
			for _, rarity in payload.Rarities do
				count += 1
				if count > 6 or type(rarity) ~= "string" or #rarity < 3 or #rarity > 16 then
					return false, "invalid auto-salvage rarity"
				end
			end
		elseif
			action == Protocol.Actions.LaunchExpedition
			or action == Protocol.Actions.EquipArtifact
			or action == Protocol.Actions.UpgradeArtifact
			or action == Protocol.Actions.BuySignalOffer
			or action == Protocol.Actions.EquipTitle
			or action == Protocol.Actions.ActivateBoost
			or action == Protocol.Actions.BuyItemOffer
			or action == Protocol.Actions.BuyAnomalyProtocol
			or action == Protocol.Actions.SetAnomalyChannel
			or action == Protocol.Actions.ReadStoryChapter
			or action == Protocol.Actions.ClaimStoryChapter
			or action == Protocol.Actions.ReadMail
			or action == Protocol.Actions.ClaimMail
			or action == Protocol.Actions.DeleteMail
		then
			if not stringField(payload, "Id", 1, 96) then
				if action == Protocol.Actions.LaunchExpedition then
					return false, "invalid expedition"
				elseif action == Protocol.Actions.EquipArtifact or action == Protocol.Actions.UpgradeArtifact then
					return false, "invalid artifact"
				elseif action == Protocol.Actions.BuySignalOffer then
					return false, "invalid signal offer"
				elseif action == Protocol.Actions.EquipTitle then
					return false, "invalid title selection"
				elseif action == Protocol.Actions.ActivateBoost then
					return false, "invalid boost selection"
				elseif action == Protocol.Actions.BuyItemOffer then
					return false, "invalid shop offer"
				elseif action == Protocol.Actions.BuyAnomalyProtocol then
					return false, "invalid protocol"
				elseif action == Protocol.Actions.SetAnomalyChannel then
					return false, "invalid reactor channel"
				elseif action == Protocol.Actions.ReadStoryChapter or action == Protocol.Actions.ClaimStoryChapter then
					return false, "invalid story chapter"
				elseif
					action == Protocol.Actions.ReadMail
					or action == Protocol.Actions.ClaimMail
					or action == Protocol.Actions.DeleteMail
				then
					return false, "invalid mail"
				end
				return false, "invalid action payload"
			end
		elseif action == Protocol.Actions.SetAnomalyLoadout then
			if not stringArrayField(payload, "Loadout", GameConfig.Anomalies.LoadoutSlots, 1, 32) then
				return false, "invalid reactor loadout payload"
			end
		elseif action == Protocol.Actions.ClaimForgePathStep then
			if not numberField(payload, "Step", 1, 10_000, true) then
				return false, "invalid forge path payload"
			end
		elseif action == Protocol.Actions.UpgradeCrew then
			if not stringField(payload, "Role", 1, 64) then
				return false, "invalid crew payload"
			end
		elseif action == Protocol.Actions.SetAutoForge then
			if
				type(payload.Enabled) ~= "boolean"
				or not stringField(payload, "MachineId", 1, 64)
				or not numberField(payload, "Reserve", 0, 0.9)
			then
				return false, "invalid auto-forge payload"
			end
		elseif action == Protocol.Actions.ClaimEcho then
			if not stringField(payload, "ChoiceId", 1, 56) then
				return false, "invalid echo choice"
			end
		elseif action == Protocol.Actions.EquipEcho then
			if not stringField(payload, "Uid", 1, 48) or not numberField(payload, "Slot", 1, 3, true) then
				return false, "invalid echo slot"
			end
		elseif action == Protocol.Actions.UpgradeEcho or action == Protocol.Actions.DismantleEcho then
			if not stringField(payload, "Uid", 1, 48) then
				return false, "invalid echo payload"
			end
		elseif
			action == Protocol.Actions.BuyMachine
			or action == Protocol.Actions.BuyResearch
			or action == Protocol.Actions.BuyGridUpgrade
		then
			local requestedAmount = payload.Amount
			local validAmount = requestedAmount == "Max" or numberField(payload, "Amount", 1, 1e4, true)
			if not stringField(payload, "Id", 1, 64) or not validAmount then
				return false, "invalid upgrade payload"
			end
		elseif action == Protocol.Actions.SetTutorialStep then
			-- Must match TUTORIAL_STEPS.size() in src_ts/client/MainGame.tsx and the clamp in
			-- GameService:_setTutorialStep. This was previously capped at 10, silently rejecting
			-- every SetTutorialStep request past step 10 as "invalid guide payload" -- the
			-- client's local step display would still advance (client-only React state), but the
			-- server never received or saved it, so a page refresh / rejoin snapped the player
			-- back to step 10, making the tutorial appear permanently stuck there.
			if not numberField(payload, "Step", 1, 15, true) then
				return false, "invalid guide payload"
			end
		elseif action == Protocol.Actions.ClaimConvergenceReward then
			if not numberField(payload, "Tier", 1, 10, true) then return false, "invalid convergence payload" end
		elseif action == Protocol.Actions.ReportPerformance then
			if not numberField(payload, "FPS", 0, 360)
				or not numberField(payload, "P95Ms", 0, 1000)
				or not numberField(payload, "JankPct", 0, 1)
				or not numberField(payload, "PingMs", 0, 10_000)
				or not numberField(payload, "Width", 1, 16_384)
				or not numberField(payload, "Height", 1, 16_384)
				or not numberField(payload, "BootMs", 0, 120_000)
				or not stringField(payload, "Input", 1, 16)
			then return false, "invalid performance payload" end
		elseif action == Protocol.Actions.ClaimTimedReward then
			if not numberField(payload, "Index", 1, 100, true) then
				return false, "invalid reward payload"
			end
		elseif action == Protocol.Actions.ReportPresence then
			if payload.Page ~= nil and not stringField(payload, "Page", 1, 32) then
				return false, "invalid presence payload"
			end
			-- Gen omitted entirely is the hello case (client hasn't been issued a nonce yet).
			-- Once Gen is present the beat fields must all be present and well-formed together.
			if payload.Gen ~= nil then
				if
					not numberField(payload, "Gen", 1, 1e12, true)
					or not numberField(payload, "Id", 1, 1e15, true)
					or not stringField(payload, "N", 8, 80)
				then
					return false, "invalid beat payload"
				end
			end
		elseif
			action == Protocol.Actions.GetPlayerMirror
			or action == Protocol.Actions.VisitPlot
			or action == Protocol.Actions.NudgeCrew
		then
			if not userIdField(payload) then
				local raw = extractUserId(payload)

				ModuleLog.Every(
					string.format("bad-userid:%s", action),
					12,
					"Requests",
					string.format(
						"%s payload UserId type=%s value=%s",
						action,
						typeof(raw),
						tostring(raw)
					)
				)
				return false, "invalid player id"
			end
		elseif action == Protocol.Actions.LeavePlot then

		elseif action == Protocol.Actions.ClaimCommanderReward or action == Protocol.Actions.ClaimSeasonTier then
			local key = action == Protocol.Actions.ClaimCommanderReward and "Level" or "Tier"
			if not numberField(payload, key, 1, 10_000, true) then
				return false, "invalid progression payload"
			end
		elseif action == Protocol.Actions.UnlockZone or action == Protocol.Actions.SelectZone then
			local rawId = payload.Id
			if type(rawId) == "string" then
				rawId = tonumber(rawId)
				payload.Id = rawId
			end
			if type(rawId) == "number" and math.abs(rawId - math.floor(rawId)) < 1e-6 then
				payload.Id = math.floor(rawId)
			end
			if not numberField(payload, "Id", 1, 10_000, true) then
				return false, "invalid world payload"
			end
		elseif
			action == Protocol.Actions.ClaimQuest
			or action == Protocol.Actions.ClaimAchievement
			or action == Protocol.Actions.ClaimWeeklyDirective
			or action == Protocol.Actions.ClaimAnomalyDirective
			or action == Protocol.Actions.ClaimLabOrder
		then
			if not stringField(payload, "Id", 1, 96) and not numberField(payload, "Id", 1, 10_000, true) then
				return false, "invalid claim payload"
			end
		elseif action == Protocol.Actions.ClaimAnomalyMilestone then
			if not numberField(payload, "Tier", 1, 10_000, true) then
				return false, "invalid anomaly payload"
			end
		elseif action == Protocol.Actions.RouteLabPower then
			if
				not stringField(payload, "Channel", 1, 24)
				or not numberField(payload, "Delta", -1, 1, true)
				or payload.Delta == 0
			then
				return false, "invalid power route payload"
			end
		elseif action == Protocol.Actions.CreateGuild then
			if type(payload) == "table" then
				if type(payload.Name) == "string" then
					payload.Name = payload.Name:gsub("^%s+", ""):gsub("%s+$", "")
				end
				if type(payload.Tag) == "string" then
					payload.Tag = string.upper((payload.Tag:gsub("%s+", "")))
				end
			end
			if not stringField(payload, "Name", 3, 28) or not stringField(payload, "Tag", 3, 4) then return false, "invalid guild charter payload" end
		elseif action == Protocol.Actions.JoinGuild then
			if type(payload) == "table" and type(payload.Tag) == "string" then
				payload.Tag = string.upper((payload.Tag:gsub("%s+", "")))
			end
			if not stringField(payload, "Tag", 3, 4) then return false, "invalid guild tag" end
		elseif action == Protocol.Actions.KickGuildMember then
			if not userIdField(payload) then return false, "invalid guild member" end
		elseif action == Protocol.Actions.SetGuildRole then
			if not userIdField(payload) or (payload.Role ~= "Officer" and payload.Role ~= "Member") then return false, "invalid guild role" end
		elseif action == Protocol.Actions.ContributeGuild then
			local hasAmount = payload.Amount ~= nil
			local hasFraction = payload.Fraction ~= nil
			if
				hasAmount == hasFraction
				or (hasAmount and not numberField(payload, "Amount", 1, 1e15))
				or (hasFraction and not numberField(payload, "Fraction", 0.0001, 0.25))
				or (payload.Currency ~= "Cash" and payload.Currency ~= "Dust")
			then
				return false, "invalid guild contribution"
			end
		elseif action == Protocol.Actions.BuyGuildUpgrade then
			if not stringField(payload, "Id", 1, 48) then return false, "invalid guild upgrade" end
		elseif action == Protocol.Actions.GetGuildLeaderboard then
			if payload.Page ~= nil and not numberField(payload, "Page", 1, 100, true) then
				return false, "invalid guild leaderboard page"
			end
		elseif action == Protocol.Actions.GetLeaderboard then
			local id = type(payload) == "table" and payload.Id or nil
			if id ~= "Flux"
				and id ~= "Rebirths"
				and id ~= "PlayTime"
				and id ~= "Dust"
				and id ~= "Cores"
				and id ~= "Domain"
				and id ~= "Worlds"
			then
				return false, "invalid leaderboard"
			end
		elseif action == Protocol.Actions.AdminExecute then
			if
				not numberField(payload, "TargetUserId", -9007199254740991, 9007199254740991, true)
				or not stringField(payload, "Command", 1, 48)
				or not stringField(payload, "Amount", 1, 32)
				or not stringField(payload, "Nonce", 8, 80)
				or not stringField(payload, "Reason", 3, 96)
			then
				return false, "invalid admin command envelope"
			end
			if payload.Option ~= nil and not stringField(payload, "Option", 0, 64) then
				return false, "invalid admin command option"
			end
		elseif action == Protocol.Actions.ReportClientIntegrity then
			if
				not stringField(payload, "ActionType", 1, 48)
				or not stringField(payload, "PenaltyCode", 1, 48)
			then
				return false, "invalid integrity envelope"
			end
		end
		return true
	end


	local function processFirewallViolation(
		player: Player,
		actionType: any,
		penaltyCode: any
	): (boolean, string?)
		if player.Parent ~= Players then
			return false, "player is not active"
		end
		if type(actionType) ~= "string" or type(penaltyCode) ~= "string" then
			return false, "malformed integrity report"
		end
		local allowedPenalties = CLIENT_SIGNAL_RULES[actionType]
		if not allowedPenalties or allowedPenalties[penaltyCode] ~= true then
			return false, "unknown integrity signature"
		end

		local now = os.clock()
		local record = CLIENT_INTEGRITY_REPORTS[player]
		if not record then
			record = { Count = 0, LastAt = 0, Kinds = {} }
			CLIENT_INTEGRITY_REPORTS[player] = record
		end
		if now - record.LastAt < 25 then
			return false, "integrity report rate exceeded"
		end

		record.LastAt = now
		record.Count += 1
		record.Kinds[penaltyCode] = (record.Kinds[penaltyCode] or 0) + 1
		ServerTelemetry.RecordIntegrityReport()
		player:SetAttribute("AF_ClientIntegritySignals", record.Count)
		player:SetAttribute("AF_LastIntegritySignal", penaltyCode)
		ModuleLog.Every(
			string.format("integrity:%d", player.UserId),
			30,
			"Security",
			string.format(
				"%s reported client integrity telemetry %s/%s (%d)",
				player.Name,
				actionType,
				penaltyCode,
				record.Count
			)
		)
		return true, nil
	end


	local function enforceConfirmedBan(player: Player, proof: ConfirmedProof): (boolean, string?)
		if
			type(proof) ~= "table"
			or proof.ServerConfirmed ~= true
			or type(proof.CorroboratedSignals) ~= "number"
			or proof.CorroboratedSignals < 2
		then
			return false, "insufficient server evidence"
		end
		if type(proof.Rule) ~= "string" or proof.Rule == "" then
			return false, "missing enforcement rule"
		end

		local privateReason = string.sub(
			string.format(
				"AF security rule %s; signals=%d; user=%d",
				proof.Rule,
				proof.CorroboratedSignals,
				player.UserId
			),
			1,
			1000
		)
		local banConfig: { [string]: any } = {
			UserIds = { player.UserId },
			Duration = -1,
			DisplayReason = "Your account was removed for confirmed exploitation.",
			PrivateReason = privateReason,
			ExcludeAltAccounts = false,
			ApplyToUniverse = true,
			ApplyDeviceBlock = true,
		}
		local success, banError = pcall(function()
			Players:BanAsync(banConfig)
		end)
		if not success then

			banConfig.ApplyDeviceBlock = nil
			success, banError = pcall(function()
				Players:BanAsync(banConfig)
			end)
		end
		if success then
			return true, nil
		end

		ModuleLog.Every(
			string.format("ban-failure:%d", player.UserId),
			30,
			"Security",
			string.format("Ban service failed for %s: %s", player.Name, tostring(banError))
		)
		if player.Parent == Players then
			player:Kick("Astral Forge rejected confirmed exploit activity.")
		end
		return false, tostring(banError)
	end

	Firewall.processFirewallViolation = processFirewallViolation
	Firewall.EnforceConfirmedBan = enforceConfirmedBan

	local function newBucket(now: number): Bucket
		return {
			Tokens = 30,
			LastRefill = now,
			LastAction = {},
			LastActionCount = 0,
			Strikes = 0,
			LastStrike = now,
			QuarantineUntil = 0,
			WindowStart = now,
			WindowCount = 0,
			LastRejectedAction = nil,
		}
	end

	function Firewall.new()
		local self = setmetatable({}, Firewall)
		self._states = {} :: { [Player]: Bucket }
		return self
	end

	function Firewall:_strike(player: Player, state: Bucket, reason: string, severity: number): ()
		ServerTelemetry.RecordRemote(false, reason)
		local now = os.clock()
		if now - state.LastStrike > 18 then
			state.Strikes = math.max(0, state.Strikes - math.floor((now - state.LastStrike) / 18))
		end
		state.LastStrike = now
		state.Strikes += severity
		if state.Strikes >= 4 then
			state.QuarantineUntil =
				math.max(state.QuarantineUntil, now + math.min(60, 2 ^ math.floor(state.Strikes - 4)))
		end
		player:SetAttribute("AF_RemoteScore", math.floor(state.Strikes))
		if severity >= 1 or math.floor(state.Strikes) % 3 == 0 then
			local actionLabel = state.LastRejectedAction or "?"
			ModuleLog.Every(
				string.format("request:%d:%s", player.UserId, reason),
				8,
				"Requests",
				string.format("%s · %s rejected — %s (score %.1f)", player.Name, tostring(actionLabel), reason, state.Strikes)
			)
		end
		-- Raised from 14: a legitimate fast player spam-tapping through several different
		-- buttons in a row can genuinely drain the token bucket faster than it refills for a
		-- few seconds without doing anything wrong, and each of those hits severity 0.5 (see
		-- "token budget" below) -- 14 was reachable by real play, not just a dumped remote.
		-- Unknown-action and invalid-payload strikes (severity 1-2, only ever hit by a
		-- malformed/malicious request) still dominate this total quickly for an actual attack.
		if state.Strikes >= 24 and player.Parent == Players then
			player:Kick("Astral Forge rejected suspicious remote traffic.")
		end
	end

	function Firewall:Check(player: Player, action: any, payload: any): (boolean, string?)
		if RunService:IsStudio() then
			return true
		end
		if player.Parent ~= Players then
			return false, "Player is not active."
		end
		local now = os.clock()
		local state = self._states[player]
		if not state then
			state = newBucket(now)
			self._states[player] = state
		end
		if type(action) ~= "string" or not ACTIONS[action] then
			state.LastRejectedAction = tostring(action)
			self:_strike(player, state, "unknown action", 2)
			return false, "Unknown forge command."
		end
		if state.QuarantineUntil > now and action ~= Protocol.Actions.GetState then
			ServerTelemetry.RecordRemote(false, "quarantine")
			return false, "Remote traffic paused briefly. Please try again."
		end
		local payloadOk, payloadReason = validateActionPayload(action, payload)
		if not payloadOk then
			state.LastRejectedAction = action
			self:_strike(player, state, payloadReason or "invalid payload", 1)
			return false, payloadReason or "That request could not be validated."
		end
		if EXEMPT_ACTIONS[action] then
			ServerTelemetry.RecordRemote(true)
			return true
		end
		if now - state.WindowStart >= 2 then
			state.WindowStart = now
			state.WindowCount = 0
		end
		state.WindowCount += 1
		if state.WindowCount > 48 then
			self:_strike(player, state, "request burst", 1)
			return false, "Please slow down for a moment."
		end
		local rule = RULES[action] or DEFAULT_RULE
		local elapsed = math.max(0, now - state.LastRefill)
		state.LastRefill = now
		state.Tokens = math.min(30, state.Tokens + elapsed * 14)
		local actionKey = cooldownKey(action, payload)
		local previous = state.LastAction[actionKey] or -math.huge
		if now - previous < rule.Cooldown then

			ServerTelemetry.RecordRemote(false, "action cooldown")
			return false, "That action is still cooling down."
		end
		if state.Tokens < rule.Cost then
			self:_strike(player, state, "token budget", 0.5)
			return false, "Please slow down for a moment."
		end
		state.Tokens -= rule.Cost
		if state.LastAction[actionKey] == nil then
			state.LastActionCount += 1
		end
		state.LastAction[actionKey] = now

		if state.LastActionCount > 256 then
			local retained = {}
			for key, timestamp in state.LastAction do
				if now - timestamp <= 120 then
					table.insert(retained, { Key = key, At = timestamp })
				else
					state.LastAction[key] = nil
				end
			end
			if #retained > 256 then
				table.sort(retained, function(left, right) return left.At > right.At end)
				for index = 257, #retained do state.LastAction[retained[index].Key] = nil end
			end
			state.LastActionCount = math.min(#retained, 256)
		end
		ServerTelemetry.RecordRemote(true)
		return true
	end

	function Firewall:Forget(player: Player): ()
		self._states[player] = nil
		CLIENT_INTEGRITY_REPORTS[player] = nil
	end

	return Firewall
end
