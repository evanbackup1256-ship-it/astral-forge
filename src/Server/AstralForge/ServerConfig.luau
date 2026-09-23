--!strict

local DATA_RESET_EPOCH = "r20260816_1"

local function resetStore(name: string): string
	return name .. "_" .. DATA_RESET_EPOCH
end

return {
	DataResetEpoch = DATA_RESET_EPOCH,

	DataStoreName = resetStore("AstralForge_PlayerData_v1"),

	SharedDataStoreName = resetStore("AstralForge_Shared_v1"),

	LeaderboardStoreName = resetStore("AstralForge_Lifetime_v2"),
	RebirthLeaderboardStoreName = resetStore("AstralForge_Rebirths_v2"),
	PlayTimeLeaderboardStoreName = resetStore("AstralForge_PlayTime_v2"),
	DustLeaderboardStoreName = resetStore("AstralForge_Dust_v2"),
	CoresLeaderboardStoreName = resetStore("AstralForge_Cores_v2"),
	DomainLeaderboardStoreName = resetStore("AstralForge_Domain_v2"),
	WorldLeaderboardStoreName = resetStore("AstralForge_World_v2"),
	AdminAuditStoreName = "AstralForge_AdminAudit_v1",
	DiscordModQueueStoreName = "AstralForge_DiscordModQueue_v1",
	GuildStoreName = resetStore("AstralForge_Guilds_v1"),

	GuildLeaderboardStoreName = resetStore("AstralForge_GuildLB_v2"),

	SessionLockSeconds = 180,
	SaveRetries = 3,
	AllowStudioMemoryFallback = true,

	StudioSimulatedAwaySeconds = 600,

	AdminUserIds = {
		[10916707683] = "Owner",
	},
	AllowStudioAdmins = true,

	FeedbackWebhookAttribute = "AstralForgeFeedbackWebhook",
	ReportWebhookAttribute = "AstralForgeReportWebhook",
	FollowVerificationEndpointAttribute = "AstralForgeFollowVerificationEndpoint",
	FollowVerificationSecretAttribute = "AstralForgeFollowVerificationSecret",
	CreatorUserId = 10916707683,
	CreatorUsername = "usingINales",
	AllowStudioFollowVerification = true,
	FollowReward = { CashMinutes = 12, Stardust = 35, Signals = 10 },

	-- The Discord bot writes pending kick/ban/unban requests into the
	-- DiscordModQueueStoreName DataStore via Roblox Open Cloud (it never talks
	-- to a live server directly). One server per universe polls this queue on
	-- an interval and drains it; see AdminService:_pollDiscordQueue.
	DiscordModQueuePollSeconds = 20,
	DiscordModQueuePrefix = "DiscordMod_",


	Codes = {
		RELEASE = {
			Description = "Launch celebration",
			Reward = { Cash = 5_000, Stardust = 25, Boost = "Overdrive" },
		},
		STARBOUND = {
			Description = "Community reward",
			Reward = { Cash = 25_000, Stardust = 15 },
		},
		AFKFORGE = {
			Description = "Idle specialist pack",
			Reward = { Stardust = 10, Boost = "VaultSurge" },
		},
		SUPPLYDOCK = {
			Description = "Supply dock opening",
			Reward = { Cash = 10_000, Stardust = 40, Signals = 5 },
		},
		SMOOTHFORGE = {
			Description = "Performance refit celebration",
			Reward = { Cash = 40_000, Stardust = 35, Boost = "Overdrive" },
		},
		TOUCHREADY = {
			Description = "Mobile control-deck pack",
			Reward = { Cash = 20_000, Stardust = 30, Signals = 12 },
		},
	},


	Gamepasses = {
		DoubleProduction = 0,
		DoubleCapacity = 0,
		VIP = 0,
	},
}
