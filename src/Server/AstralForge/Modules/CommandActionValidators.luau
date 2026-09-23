--!strict
-- Pure command-action classifiers for the GameService request gate. No Roblox
-- services — ServerServices and Lune verify scripts share this so read-only /
-- high-value-grant / deferred-snapshot sets stay testable without Studio.
-- Action names match Protocol.Actions string values.

local CommandActionValidators = {}

-- Read-only actions skip session CheckGrant (no gen/nonce burn).
CommandActionValidators.READ_ONLY = {
	GetState = true,
	MeasureLatency = true,
	SubmitFeedback = true,
	ReportPlayer = true,
	GetPlayers = true,
	GetPlayerMirror = true,
	VisitPlot = true,
	LeavePlot = true,
	NudgeCrew = true,
	ReportPresence = true,
	GetGuild = true,
	GetGuildLeaderboard = true,
	GetLeaderboard = true,
	GetAdminState = true,
	GetTrade = true,
	TradeViewAway = true,
	ReportClientIntegrity = true,
	ReportPerformance = true,
	SetTutorialStep = true,
	ReplayTutorial = true,
}

-- Grants that also require the request to carry the session's live nonce, not
-- just a matching gen — highest-value actions get the extra check.
CommandActionValidators.HIGH_VALUE_GRANT = {
	SpinWheel = true,
	OpenItemCrate = true,
	CollectVault = true,
	Rebirth = true,
	DomainExpansion = true,
	RedeemCode = true,
	AdminExecute = true,
}

-- Successful mutations that defer the immediate state snapshot push.
CommandActionValidators.DEFERRED_SNAPSHOT = {
	Overcharge = true,
	PulseAnomaly = true,
	RouteLabPower = true,
	SetAutoForge = true,
	SetAnomalyChannel = true,
	SetAnomalyLoadout = true,
	SetSetting = true,
	SetMobileLayout = true,
	SetTutorialStep = true,
	ReplayTutorial = true,
	DismissRelease = true,
	OpenRelease = true,
	ReadStoryChapter = true,
	ReadMail = true,
	ReportPresence = true,
	SelectZone = true,
}

function CommandActionValidators.IsValidAction(action: any): boolean
	return type(action) == "string" and #action > 0
end

function CommandActionValidators.IsReadOnly(action: string): boolean
	return CommandActionValidators.READ_ONLY[action] == true
end

function CommandActionValidators.RequiresHighValueNonce(action: string): boolean
	return CommandActionValidators.HIGH_VALUE_GRANT[action] == true
end

function CommandActionValidators.IsDeferredSnapshot(action: string): boolean
	return CommandActionValidators.DEFERRED_SNAPSHOT[action] == true
end

return table.freeze(CommandActionValidators)
