--!strict
-- Pure action → feature / anomaly charge / signal maps for GameService.
-- No Roblox services — ServerServices and Lune verify scripts share this so
-- routing tables stay testable without Studio. Keys match Protocol.Actions.

local ActionFeatureMaps = {}

ActionFeatureMaps.ANOMALY_CHARGE = {
	CollectVault = 8,
	Overcharge = 3,
	BuyMachine = 5,
	BuyResearch = 5,
	BuyGridUpgrade = 6,
	UpgradeContinuum = 18,
	UpgradeArtifact = 6,
	UpgradeCrew = 5,
	UnlockZone = 16,
	Rebirth = 24,
	ClaimQuest = 7,
	ClaimAchievement = 12,
	ClaimDaily = 14,
	ClaimTimedReward = 9,
	SpinWheel = 12,
	ClaimExpedition = 20,
	ClaimCommanderReward = 8,
	ClaimWeeklyDirective = 16,
	ClaimSeasonTier = 12,
	OpenItemCrate = 14,
	UpgradeItem = 7,
	EquipBestItems = 10,
	BulkSalvageItems = 10,
}

ActionFeatureMaps.ANOMALY_SIGNAL = {
	CollectVault = "Collect",
	BuyMachine = "Upgrade",
	BuyResearch = "Upgrade",
	BuyGridUpgrade = "Upgrade",
	UpgradeContinuum = "Upgrade",
	UpgradeItem = "Upgrade",
	EquipBestItems = "Upgrade",
	UpgradeArtifact = "Upgrade",
	UpgradeCrew = "Upgrade",
	ClaimQuest = "Reward",
	ClaimAchievement = "Reward",
	ClaimDaily = "Reward",
	ClaimTimedReward = "Reward",
	ClaimExpedition = "Reward",
	ClaimCommanderReward = "Reward",
	ClaimWeeklyDirective = "Reward",
	ClaimSeasonTier = "Reward",
	ClaimForgePathStep = "Reward",
}

ActionFeatureMaps.FEATURE = {
	VisitPlot = "Crew",
	LeavePlot = "Crew",
	NudgeCrew = "Crew",
	BuyResearch = "Research",
	BuyGridUpgrade = "StarGrid",
	UnlockZone = "Worlds",
	SelectZone = "Worlds",
	Rebirth = "Rebirth",
	DomainExpansion = "Domain",
	UnlockDomainNode = "Domain",
	UpgradeContinuum = "Continuum",
	CaptureEcho = "Echoes",
	ClaimEcho = "Echoes",
	EquipEcho = "Echoes",
	UpgradeEcho = "Echoes",
	DismantleEcho = "Echoes",
	ClaimQuest = "Missions",
	ClaimAchievement = "Milestones",
	SpinWheel = "Wheel",
	ClaimDaily = "Rewards",
	ClaimTimedReward = "Rewards",
	ActivateBoost = "Rewards",
	LaunchExpedition = "Command",
	ClaimExpedition = "Command",
	EquipArtifact = "Command",
	UpgradeArtifact = "Command",
	UpgradeCrew = "Command",
	ClaimCommanderReward = "Command",
	ClaimWeeklyDirective = "Command",
	ClaimSeasonTier = "Command",
	BuySignalOffer = "Command",
	EquipTitle = "Command",
	RedeemCode = "Shop",
	VerifyCreatorFollow = "Shop",
	BuyItemOffer = "Inventory",
	OpenItemCrate = "Inventory",
	EquipItem = "Inventory",
	UnequipItem = "Inventory",
	UpgradeItem = "Inventory",
	SalvageItem = "Inventory",
	BulkSalvageItems = "Inventory",
	EquipBestItems = "Inventory",
	ToggleItemLock = "Inventory",
	SetItemAutoSalvage = "Inventory",
	PulseAnomaly = "Anomaly",
	StabilizeAnomaly = "Anomaly",
	BuyAnomalyProtocol = "Anomaly",
	ActivateAnomalySurge = "Anomaly",
	SetAnomalyChannel = "Anomaly",
	SetAnomalyLoadout = "Anomaly",
	ClaimAnomalyMilestone = "Anomaly",
	ClaimAnomalyDirective = "Anomaly",
	ClaimLabOrder = "Lab",
	RouteLabPower = "Lab",
	ReadStoryChapter = "Story",
	ClaimStoryChapter = "Story",
	ReadMail = "Mail",
	ClaimMail = "Mail",
	ClaimAllMail = "Mail",
	DeleteMail = "Mail",
	GetLeaderboard = "Leaderboards",
	ClaimConvergenceReward = "Convergence",
}

function ActionFeatureMaps.AnomalyCharge(action: string): number?
	return ActionFeatureMaps.ANOMALY_CHARGE[action]
end

function ActionFeatureMaps.AnomalySignal(action: string): string?
	return ActionFeatureMaps.ANOMALY_SIGNAL[action]
end

function ActionFeatureMaps.FeatureId(action: string): string?
	return ActionFeatureMaps.FEATURE[action]
end

return table.freeze(ActionFeatureMaps)
