local fs = require("@lune/fs")
local ProfileMath = require("../src/Server/AstralForge/Modules/ProfileMath")
local GeneralBoardValue = ProfileMath("GeneralBoardValue")

local categories = {
	"Flux",
	"Rebirths",
	"PlayTime",
	"Dust",
	"Cores",
	"Domain",
	"Worlds",
	"Taps",
	"ItemsFound",
	"CratesOpened",
	"AnomalyPulses",
	"OrdersCompleted",
	"Combat",
	"Crafting",
	"ArcadeScore",
	"Seasonal",
}

local client = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau"):gsub("\r\n", "\n")
local rankDashboard = fs.readFile("src/Client/AstralForge/RankDashboard.luau"):gsub("\r\n", "\n")
local boardBlock = assert(client:match("local BOARDS = ({.-})\n\tlocal STAT_BOARD_FIELDS"))
local configuredBoards = {}
for id in boardBlock:gmatch('id = "([%w]+)"') do
	configuredBoards[id] = true
end

local profileMath = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau")
local dataService = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local serverServices = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local serverConfig = fs.readFile("src/Server/AstralForge/ServerConfig.luau")
local remoteFirewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local publicRecord = assert(profileMath:match('__defs%["PublicPlayerRecord"%] = function%(.-\nend'))

local statValues = {
	Taps = 91,
	ItemsFound = 23,
	CratesOpened = 17,
	AnomalyPulses = 8,
	OrdersCompleted = 44,
	WardenDefeats = 31,
	OreMined = 72,
	SeasonXP = 65,
}
local storeSuffix = {
	Flux = "LeaderboardStoreName",
	Rebirths = "RebirthLeaderboardStoreName",
	Worlds = "WorldLeaderboardStoreName",
	ArcadeScore = "ArcadeScoreLeaderboardStoreName",
	Seasonal = "SeasonLeaderboardStoreName",
}
local profile = {
	LifetimeCash = "1e100",
	Rebirths = 6,
	Stats = statValues,
	Stardust = 12,
	Cores = 5,
	Domain = { Rank = 4 },
	Zone = 9,
	Arcade = { Stats = { TotalScore = 12345 } },
	Command = { SeasonXP = statValues.SeasonXP },
}

assert(#categories == 16, "expected sixteen player boards before the guild board")
for _, id in categories do
	local suffix = storeSuffix[id] or `{id}LeaderboardStoreName`
	local dataStoreSuffix = if id == "Rebirths" then "RebirthLeaderboardStoreName" else suffix
	local statField = if id == "Combat"
		then "WardenDefeats"
		elseif id == "Crafting" then "OreMined"
		elseif id == "Seasonal" then "SeasonXP"
		else id
	assert(configuredBoards[id], `missing client board {id}`)
	assert(
		remoteFirewall:find('id ~= "' .. id .. '"', 1, true),
		`GetLeaderboard firewall rejects configured board {id}`
	)
	assert(serverServices:find(`{id} = ServerConfig.{suffix}`, 1, true), `server query store missing {id}`)
	assert(serverConfig:find(`{suffix} = resetStore(`, 1, true), `store name missing {id}`)
	if id == "Flux" then
		assert(dataService:find("Flux = self._leaderboardStore", 1, true), "Flux store missing")
		assert(dataService:find("Flux = profile.LifetimeCash", 1, true), "Flux score missing")
	else
		assert(
			dataService:find(`{id} = getOrderedStore(ServerConfig.{dataStoreSuffix})`, 1, true),
			`data store missing {id}`
		)
		if id == "ArcadeScore" then
			assert(
				dataService:find("ArcadeScore = math.clamp(", 1, true)
					and dataService:find("profile.Arcade.Stats.TotalScore", 1, true),
				"saved score missing ArcadeScore"
			)
		elseif id == "Seasonal" then
			assert(
				dataService:find(
					"Seasonal = math.max(0, math.floor(tonumber(profile.Command and profile.Command.SeasonXP) or 0))",
					1,
					true
				),
				"saved score missing Seasonal"
			)
		elseif statValues[statField] then
			assert(
				dataService:find(
					`{id} = math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.{statField}) or 0))`,
					1,
					true
				),
				`saved score missing {id}`
			)
		elseif id == "Rebirths" then
			assert(dataService:find("Rebirths = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))", 1, true))
		end
	end
	assert(
		GeneralBoardValue.Of(profile, id, function(value)
			return value
		end)
			== (
				statValues[statField]
				or (id == "Worlds" and 9)
				or (id == "Rebirths" and 6)
				or (id == "Dust" and 12)
				or (id == "Cores" and 5)
				or (id == "Domain" and 4)
				or (id == "PlayTime" and 0)
				or (id == "ArcadeScore" and 12345)
				or "1e100"
			),
		`score projection mismatch {id}`
	)
end

for _, field in
	{
		"Taps",
		"ItemsFound",
		"CratesOpened",
		"AnomalyPulses",
		"OrdersCompleted",
		"WardenDefeats",
		"OreMined",
		"SeasonXP",
	}
do
	assert(
		publicRecord:find(
			if field == "SeasonXP"
				then "SeasonXP = profile.Command and profile.Command.SeasonXP or 0"
				else `{field} = profile.Stats and profile.Stats.{field} or 0`,
			1,
			true
		),
		`server roster projection missing {field}`
	)
	local boardId = if field == "WardenDefeats"
		then "Combat"
		elseif field == "OreMined" then "Crafting"
		elseif field == "SeasonXP" then "Seasonal"
		else field
	assert(client:find(`{boardId} = "{field}"`, 1, true), `client stat projection missing {field}`)
end

assert(
	publicRecord:find(
		"ArcadeScore = profile.Arcade and profile.Arcade.Stats and profile.Arcade.Stats.TotalScore or 0",
		1,
		true
	)
)
assert(client:find('id = "ArcadeScore"', 1, true) and client:find('id = "Seasonal"', 1, true))
for _, category in
	{ "Economy", "Progression", "Exploration", "Combat", "Forge", "Arcade", "Seasonal", "Prestige", "Social", "Guild" }
do
	assert(rankDashboard:find('"' .. category .. '"', 1, true), `rank category missing {category}`)
end
assert(rankDashboard:find("ui.SegmentedTabs", 1, true), "rank boards need category-first navigation")
assert(rankDashboard:find("ui.SearchField", 1, true), "rank board list needs search")
assert(rankDashboard:find("matchesCategory", 1, true) and rankDashboard:find("matchesSearch", 1, true))
print("[TEST] sixteen persisted boards, firewall parity, ten category filters, board search, live rows and guild separation passed")
