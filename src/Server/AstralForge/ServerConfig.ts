const DATA_RESET_EPOCH = "r20260816_1";

function resetStore(name: string): string {
	return name + "_" + DATA_RESET_EPOCH;
}

export = table.freeze({
	DataResetEpoch: DATA_RESET_EPOCH,

	DataStoreName: resetStore("AstralForge_PlayerData_v1"),

	SharedDataStoreName: resetStore("AstralForge_Shared_v1"),

	LeaderboardStoreName: resetStore("AstralForge_Lifetime_v2"),
	RebirthLeaderboardStoreName: resetStore("AstralForge_Rebirths_v2"),
	PlayTimeLeaderboardStoreName: resetStore("AstralForge_PlayTime_v2"),
	DustLeaderboardStoreName: resetStore("AstralForge_Dust_v2"),
	CoresLeaderboardStoreName: resetStore("AstralForge_Cores_v2"),
	DomainLeaderboardStoreName: resetStore("AstralForge_Domain_v2"),
	WorldLeaderboardStoreName: resetStore("AstralForge_World_v2"),
	CratesLeaderboardStoreName: resetStore("AstralForge_Crates_v2"),
	FindsLeaderboardStoreName: resetStore("AstralForge_Finds_v2"),
	OreLeaderboardStoreName: resetStore("AstralForge_Ore_v2"),
	WardensLeaderboardStoreName: resetStore("AstralForge_Wardens_v2"),
	OrdersLeaderboardStoreName: resetStore("AstralForge_Orders_v2"),
	StarsLeaderboardStoreName: resetStore("AstralForge_Stars_v2"),
	CipherLeaderboardStoreName: resetStore("AstralForge_Cipher_v2"),
	// one ordered store per week: <name>_W<week>
	WeeklyLeaderboardStoreName: resetStore("AstralForge_WeeklyFlux_v1"),
	AdminAuditStoreName: "AstralForge_AdminAudit_v1",
	DiscordModQueueStoreName: "AstralForge_DiscordModQueue_v1",
	GuildStoreName: resetStore("AstralForge_Guilds_v1"),

	GuildLeaderboardStoreName: resetStore("AstralForge_GuildLB_v2"),

	// Must stay in sync with DocumentService/Document.luau SESSION_EXPIRE_TIME.
	SessionLockSeconds: 600,
	SaveRetries: 3,
	AllowStudioMemoryFallback: true,

	StudioSimulatedAwaySeconds: 600,

	AdminUserIds: table.freeze({
		[10916707683]: "Owner",
	}),
	AllowStudioAdmins: true,

	FeedbackWebhookAttribute: "AstralForgeFeedbackWebhook",
	ReportWebhookAttribute: "AstralForgeReportWebhook",
	FollowVerificationEndpointAttribute: "AstralForgeFollowVerificationEndpoint",
	FollowVerificationSecretAttribute: "AstralForgeFollowVerificationSecret",
	CreatorUserId: 10916707683,
	CreatorUsername: "usingINales",
	AllowStudioFollowVerification: true,
	FollowReward: table.freeze({ CashMinutes: 12, Stardust: 35, Signals: 10 }),

	// Community rewards (Rewards page). Amounts are balance choices; keep them below the follow reward
	// scale so none of these outweighs a session of play.
	// Group: 0 hides the card. Membership is checked on the server with Player:IsInGroup.
	CommunityGroupId: 0,
	CommunityGroupName: "Astral Forge",
	GroupReward: table.freeze({ CashMinutes: 15, Stardust: 40, Signals: 15 }),
	// Like goals: Roblox gives the game no live like count, so this is the count shown on the experience
	// page, updated by hand with each release. Every player can claim each goal once the count reaches it.
	CommunityLikes: 0,
	LikeGoals: table.freeze([
		table.freeze({ Likes: 100, Reward: table.freeze({ CashMinutes: 8, Stardust: 15 }) }),
		table.freeze({ Likes: 500, Reward: table.freeze({ CashMinutes: 12, Stardust: 25, Boost: "Overdrive" }) }),
		table.freeze({ Likes: 1000, Reward: table.freeze({ CashMinutes: 18, Stardust: 35, FreeSpins: 1 }) }),
		table.freeze({ Likes: 5000, Reward: table.freeze({ CashMinutes: 30, Stardust: 60, Cores: 1 }) }),
	]),
	// Notification opt-in: the prompt is always offered (13+, via ExperienceNotificationService), but the
	// game can't confirm someone actually opted in, so the reward stays off until you decide to trust it.
	NotifyOptInRewardEnabled: false,
	NotifyReward: table.freeze({ CashMinutes: 5, Stardust: 15 }),

	// Enforcement stays opt-in for Studio QA, but protects live economy mutations by default.
	GameAntiCheat: table.freeze({ EnforcementEnabled: !game.GetService("RunService").IsStudio() }),

	DiscordModQueuePollSeconds: 20,
	DiscordModQueuePrefix: "DiscordMod_",

	Codes: table.freeze({
		RELEASE: table.freeze({
			Description: "Launch celebration",
			Reward: table.freeze({ Cash: 5_000, Stardust: 25, Boost: "Overdrive" }),
		}),
		STARBOUND: table.freeze({
			Description: "Community reward",
			Reward: table.freeze({ Cash: 25_000, Stardust: 15 }),
		}),
		AFKFORGE: table.freeze({
			Description: "Idle specialist pack",
			Reward: table.freeze({ Stardust: 10, Boost: "VaultSurge" }),
		}),
		SUPPLYDOCK: table.freeze({
			Description: "Supply dock opening",
			Reward: table.freeze({ Cash: 10_000, Stardust: 40, Signals: 5 }),
		}),
		SMOOTHFORGE: table.freeze({
			Description: "Performance refit celebration",
			Reward: table.freeze({ Cash: 40_000, Stardust: 35, Boost: "Overdrive" }),
		}),
		TOUCHREADY: table.freeze({
			Description: "Mobile control-deck pack",
			Reward: table.freeze({ Cash: 20_000, Stardust: 30, Signals: 12 }),
		}),
	}),

	Gamepasses: table.freeze({
		DoubleProduction: 0,
		DoubleCapacity: 0,
		VIP: 0,
	}),
});
