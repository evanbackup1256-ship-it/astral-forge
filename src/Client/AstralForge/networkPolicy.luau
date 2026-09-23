--!strict
-- Pure MainGame remote dispatch policy: cooldowns, timeouts, pipeline /
-- optimistic allowlists. No Roblox services — MainGame and Lune verify scripts
-- share this so client request gating stays testable without Studio.

local NetworkPolicy = {}

NetworkPolicy.DEFAULT_COOLDOWN = 0.1
NetworkPolicy.DEFAULT_TIMEOUT = 15
NetworkPolicy.MAX_PHYSICAL_REQUESTS = 12
NetworkPolicy.PIPELINE_REQUEST_LIMIT = 4
NetworkPolicy.SERIAL_REQUEST_LIMIT = 2

NetworkPolicy.ACTION_COOLDOWNS = {
	GetState = 0.24,
	GetPlayers = 0.28,
	GetPlayerMirror = 0.28,
	VisitPlot = 0.52,
	LeavePlot = 0.35,
	NudgeCrew = 2.7,
	ReportPresence = 1.6,
	CollectVault = 0.04,
	Overcharge = 0.05,
	PulseAnomaly = 0.05,
	SpinWheel = 1.4,
	OpenItemCrate = 0.24,
	UpgradeContinuum = 0.4,
	CaptureEcho = 1.2,
	ClaimEcho = 0.48,
	EquipEcho = 0.24,
	UpgradeEcho = 0.3,
	DismantleEcho = 0.6,
	SetAutoForge = 0.28,
	SetItemAutoSalvage = 0.2,
	BulkSalvageItems = 0.35,
	SetSetting = 0.18,
	SetMobileLayout = 0.35,
	SetTutorialStep = 0.18,
	ClaimLabOrder = 0.18,
	RouteLabPower = 0.12,
	ReadStoryChapter = 0.18,
	ClaimStoryChapter = 0.18,
	ReadMail = 0.18,
	ClaimMail = 0.18,
	ClaimAllMail = 0.75,
	DeleteMail = 0.18,
	RedeemCode = 1.5,
	SyncShop = 1.3,
	StudioGrantProduct = 0.45,
	GetTrade = 0.2,
	InviteTrade = 0.7,
	RespondTrade = 0.28,
	UpdateTradeOffer = 0.08,
	SetTradeReady = 0.12,
	ConfirmTrade = 0.28,
	CancelTrade = 0.2,
	TradeViewAway = 0.2,
	DomainExpansion = 5.2,
	ClaimConvergenceReward = 0.45,
	GetLeaderboard = 1.1,
	GetGuildLeaderboard = 1.1,
	GetAdminState = 0.9,
	ReportClientIntegrity = 30.5,
	AdminExecute = 0.9,
	CreateGuild = 2.1,
	JoinGuild = 1.1,
	GetGuild = 0.32,
	KickGuildMember = 0.6,
	SetGuildRole = 0.6,
	ContributeGuild = 0.45,
	BuyGuildUpgrade = 0.8,
	LeaveGuild = 1.1,
}

NetworkPolicy.REQUEST_TIMEOUTS = {
	GetState = 8,
	GetPlayers = 8,
	GetPlayerMirror = 8,
	GetGuild = 8,
	GetGuildLeaderboard = 8,
	GetLeaderboard = 8,
	GetAdminState = 8,
}

NetworkPolicy.PIPELINED_ACTIONS = {
	["Overcharge"] = true,
	["PulseAnomaly"] = true,
	["CollectVault"] = true,
	["RouteLabPower"] = true,
	["SetAutoForge"] = true,
	["SetAnomalyChannel"] = true,
	["SetSetting"] = true,
	["SetMobileLayout"] = true,
	["SetTutorialStep"] = true,
	["ReplayTutorial"] = true,
	["DismissRelease"] = true,
	["OpenRelease"] = true,
	["ReadStoryChapter"] = true,
	["ReadMail"] = true,
	["SelectZone"] = true,
	["UpdateTradeOffer"] = true,
	["SetTradeReady"] = true,
	["ConfirmTrade"] = true,
	["CancelTrade"] = true,
	["RespondTrade"] = true,
	["TradeViewAway"] = true,
	["SetItemAutoSalvage"] = true,
	["ReportPresence"] = true,
}

NetworkPolicy.OPTIMISTIC_ACTIONS = {
	["CollectVault"] = true,
	["Overcharge"] = true,
	["RouteLabPower"] = true,
	["SetAutoForge"] = true,
	["SetAnomalyChannel"] = true,
	["SetSetting"] = true,
	["SetMobileLayout"] = true,
	["SetTutorialStep"] = true,
	["CompleteTutorial"] = true,
	["ReplayTutorial"] = true,
	["DismissRelease"] = true,
	["OpenRelease"] = true,
	["ReadStoryChapter"] = true,
	["ReadMail"] = true,
	["SelectZone"] = true,
	["EquipTitle"] = true,
	["ReportPresence"] = true,
}

function NetworkPolicy.Cooldown(action: any): number
	if type(action) ~= "string" then
		return NetworkPolicy.DEFAULT_COOLDOWN
	end
	local value = NetworkPolicy.ACTION_COOLDOWNS[action]
	return if type(value) == "number" then value else NetworkPolicy.DEFAULT_COOLDOWN
end

function NetworkPolicy.Timeout(action: any): number
	if type(action) ~= "string" then
		return NetworkPolicy.DEFAULT_TIMEOUT
	end
	local value = NetworkPolicy.REQUEST_TIMEOUTS[action]
	return if type(value) == "number" then value else NetworkPolicy.DEFAULT_TIMEOUT
end

function NetworkPolicy.IsPipelined(action: any): boolean
	return type(action) == "string" and NetworkPolicy.PIPELINED_ACTIONS[action] == true
end

function NetworkPolicy.IsOptimistic(action: any): boolean
	return type(action) == "string" and NetworkPolicy.OPTIMISTIC_ACTIONS[action] == true
end

function NetworkPolicy.RequestLimit(pipelined: boolean?): number
	return if pipelined then NetworkPolicy.PIPELINE_REQUEST_LIMIT else NetworkPolicy.SERIAL_REQUEST_LIMIT
end

-- True when `now - previous` is still inside the cooldown window.
function NetworkPolicy.IsCoolingDown(now: any, previous: any, cooldown: any): boolean
	local clock = tonumber(now)
	local last = tonumber(previous)
	local window = tonumber(cooldown)
	if clock == nil or last == nil or window == nil then
		return false
	end
	return clock - last < window
end

return table.freeze(NetworkPolicy)
