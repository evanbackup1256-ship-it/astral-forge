const CreditsConfig = {
	Title: "Astral Forge",
	Eyebrow: "CREDITS",
	Tagline: "",
	ShowVersion: true,
	Accent: "violet",

	CategoryTabs: true,
	DefaultCategory: "All",
	ShowCategoryCounts: true,
	SearchBar: true,
	SearchMinMembers: 6,

	CardStyle: "Card",
	ShowAvatars: true,
	AvatarShape: "Rounded",
	AvatarSize: 64,
	ShowUsernames: true,
	ShowRoles: true,
	ShowNotes: true,
	FetchNames: true,
	MaxColumns: 3,
	CardMinWidth: 220,
	CardHoverLift: true,

	HideEmptyCategories: true, // no tabs or sections for roles nobody holds yet
	DefaultEmptyText: "To be announced.",

	EntranceStagger: true,
	StaggerStep: 0.035,

	Categories: [
		{
			Id: "Owner",
			Label: "Owner",
			Description: "",
			Accent: "mango",
			Icon: "Admin.4",
			Members: [
				{ Name: "usingINales", UserId: 10916707683, Role: "Founder", Note: "Design, code, worlds and story." },
			],
		},
		{
			Id: "Developers",
			Label: "Developers",
			Description: "",
			Accent: "cyan",
			Icon: "Forge.30",
			Members: [
				{ Name: "usingINales", UserId: 10916707683, Role: "Lead developer", Note: "Client, server and economy." },
			],
		},
		{
			Id: "Moderators",
			Label: "Moderators",
			Description: "",
			Accent: "mint",
			Icon: "Check.30",
			Members: {},
		},
		{
			Id: "Testers",
			Label: "Testers",
			Description: "",
			Accent: "pink",
			Icon: "Guide.2",
			Members: {},
		},
		{
			Id: "Thanks",
			Label: "Special thanks",
			Description: "",
			Accent: "violet",
			Icon: "Gift.19",
			Members: [
				{ Name: "You", Role: "Player", Note: "Thanks for playing." },
			],
		},
	],

	Acknowledgements: [
		"Interface icons by Flaticon / Freepik Company",
	],
	Footer: "",
}

export = CreditsConfig;
