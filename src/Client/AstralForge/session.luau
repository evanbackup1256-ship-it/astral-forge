local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ClientLog = require(script.Parent.log).ClientLog
local BEAT_INTERVAL_MIN = 8
local BEAT_INTERVAL_MAX = 12
-- Actions that mutate player-owned state and require an authenticated session (matching gen)
-- before the server will run them. Kept as its own set instead of leaning on the server's
-- internal read/write split so a hole here is visible in review rather than inherited silently.
local GRANT_ACTIONS = {
	["CollectVault"] = true,
	["Overcharge"] = true,
	["BuyMachine"] = true,
	["BuyResearch"] = true,
	["BuyGridUpgrade"] = true,
	["UnlockZone"] = true,
	["SelectZone"] = true,
	["Rebirth"] = true,
	["DomainExpansion"] = true,
	["UnlockDomainNode"] = true,
	["UpgradeContinuum"] = true,
	["CaptureEcho"] = true,
	["ClaimEcho"] = true,
	["EquipEcho"] = true,
	["UpgradeEcho"] = true,
	["DismantleEcho"] = true,
	["ClaimQuest"] = true,
	["ClaimAchievement"] = true,
	["ClaimDaily"] = true,
	["ClaimTimedReward"] = true,
	["SpinWheel"] = true,
	["LaunchExpedition"] = true,
	["ClaimExpedition"] = true,
	["EquipArtifact"] = true,
	["UpgradeArtifact"] = true,
	["UpgradeCrew"] = true,
	["ClaimCommanderReward"] = true,
	["ClaimWeeklyDirective"] = true,
	["ClaimSeasonTier"] = true,
	["ClaimForgePathStep"] = true,
	["BuySignalOffer"] = true,
	["RedeemCode"] = true,
	["VerifyCreatorFollow"] = true,
	["StudioGrantProduct"] = true,
	["ActivateBoost"] = true,
	["BuyItemOffer"] = true,
	["OpenItemCrate"] = true,
	["EquipItem"] = true,
	["UnequipItem"] = true,
	["UpgradeItem"] = true,
	["SalvageItem"] = true,
	["BulkSalvageItems"] = true,
	["EquipBestItems"] = true,
	["ClaimStoryChapter"] = true,
	["ClaimMail"] = true,
	["ClaimAllMail"] = true,
	["PulseAnomaly"] = true,
	["StabilizeAnomaly"] = true,
	["BuyAnomalyProtocol"] = true,
	["ActivateAnomalySurge"] = true,
	["ClaimAnomalyMilestone"] = true,
	["ClaimAnomalyDirective"] = true,
	["ClaimLabOrder"] = true,
	["RouteLabPower"] = true,
	["CreateGuild"] = true,
	["JoinGuild"] = true,
	["LeaveGuild"] = true,
	["DisbandGuild"] = true,
	["KickGuildMember"] = true,
	["SetGuildRole"] = true,
	["ContributeGuild"] = true,
	["BuyGuildUpgrade"] = true,
	["ClaimGuildGoal"] = true,
	["AdminExecute"] = true,
	["ClaimConvergenceReward"] = true,
	["ConfirmTrade"] = true,
	["UpdateTradeOffer"] = true,
	["InviteTrade"] = true,
	["RespondTrade"] = true,
	["SetTradeReady"] = true,
	["CancelTrade"] = true,
	["CompleteTutorial"] = true,
	["DeleteMail"] = true,
	["DismissRelease"] = true,
	["EquipTitle"] = true,
	["OpenRelease"] = true,
	["ReadMail"] = true,
	["ReadStoryChapter"] = true,
	["SetAnomalyChannel"] = true,
	["SetAnomalyLoadout"] = true,
	["SetAutoForge"] = true,
	["SetItemAutoSalvage"] = true,
	["SetMobileLayout"] = true,
	["SetSetting"] = true,
	["SyncShop"] = true,
	["ToggleItemLock"] = true,
}
local gen = 0
local nonce = ""
local auth = RunService:IsStudio()
local helloDone = false
local nextBeatId = 1
local stopped = true
local presencePage = "Overview"
local lastPresenceAt = -1e9
local authWaiters = {}
local function setPresencePage(page)
	presencePage = page
end
local function flushAuthWaiters()
	if not auth then
		return nil
	end
	local queued = {}
	for _, waiter in authWaiters do
		table.insert(queued, waiter)
	end
	while #authWaiters > 0 do
		authWaiters[#authWaiters] = nil
	end
	for _, waiter in queued do
		waiter()
	end
end
local function whenAuthed(run)
	if auth then
		run()
		return nil
	end
	local _run = run
	table.insert(authWaiters, _run)
end
local function isAuthed()
	return auth
end
-- Grant payloads attach these two fields so the server's SessionGate can verify the request
-- carries the live gen (and, for high-value actions, the live nonce) instead of trusting the
-- action name alone.
local function attachGrantFields(payload)
	payload.Gen = gen
	payload.N = nonce
	return payload
end
local function adopt(response)
	if response.Gen == nil or response.Gen < gen then
		return nil
	end
	if response.N == nil then
		return nil
	end
	gen = response.Gen
	nonce = response.N
	if response.Auth ~= nil then
		auth = response.Auth
	end
end
local function startSession(remotes)
	stopped = false
	helloDone = false
	lastPresenceAt = -1e9
	local worker
	local beatOnce = function(force)
		local now = os.clock()
		if not force and now - lastPresenceAt < 1.7 then
			return nil
		end
		lastPresenceAt = now
		local payload = {
			Page = presencePage,
		}
		if helloDone then
			payload.Gen = gen
			payload.Id = nextBeatId
			payload.N = nonce
			nextBeatId += 1
		end
		local ok, raw = pcall(function()
			return remotes.Request:InvokeServer("ReportPresence", payload)
		end)
		if not ok or not (type(raw) == "table") then
			return nil
		end
		local response = raw
		if response.ok ~= true then
			return nil
		end
		local wasAuthed = auth
		adopt(response)
		if not helloDone then
			helloDone = true
			ClientLog:debug("auth", `hello ok gen={gen}`)
		elseif not wasAuthed and auth then
			ClientLog:debug("auth", `beat ok gen={gen}`)
		end
		if auth then
			flushAuthWaiters()
		end
	end
	worker = task.spawn(function()
		beatOnce(true)
		if not stopped then
			beatOnce(true)
		end
		while not stopped do
			-- While unauthenticated beat every ~2s so a lost or rejected first beat
			-- recovers fast instead of leaving queued actions waiting a full interval.
			local interval = if auth then BEAT_INTERVAL_MIN + math.random() * (BEAT_INTERVAL_MAX - BEAT_INTERVAL_MIN) else 2
			task.wait(interval)
			if stopped then
				break
			end
			beatOnce(false)
		end
	end)
	return function()
		stopped = true
		if worker ~= nil then
			pcall(function()
				return task.cancel(worker)
			end)
			worker = nil
		end
	end
end
local function makeTxnId()
	return string.sub(HttpService:GenerateGUID(false), 1, 40)
end
return {
	setPresencePage = setPresencePage,
	whenAuthed = whenAuthed,
	isAuthed = isAuthed,
	attachGrantFields = attachGrantFields,
	adopt = adopt,
	startSession = startSession,
	makeTxnId = makeTxnId,
	GRANT_ACTIONS = GRANT_ACTIONS,
}
