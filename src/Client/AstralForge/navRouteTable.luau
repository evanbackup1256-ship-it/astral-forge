--!strict
-- Pure nav route tables (ids / labels / icons). Accent colors stay in appNav
-- so this module has no theme / Color3 dependency and can be required under
-- Lune. PRIMARY + MORE match the shell rail; PAGE_ROUTES are the PageRouter
-- dispatch keys (Credits is nav-only / special chrome).

local NavRouteTable = {}

export type RouteDef = {
	id: string,
	label: string,
	eyebrow: string,
	icon: string,
	accentKey: string,
}

local PRIMARY_ROUTES: { RouteDef } = {
	{ id = "Overview", label = "Overview", eyebrow = "Your vault", icon = "Overview", accentKey = "green" },
	{ id = "Workshop", label = "Workshop", eyebrow = "Buy machines", icon = "Forge", accentKey = "coral" },
	{ id = "Inventory", label = "Inventory", eyebrow = "Relics", icon = "Inventory", accentKey = "violet" },
	{ id = "Research", label = "Research", eyebrow = "Permanent bonuses", icon = "Research", accentKey = "cyan" },
	{ id = "Shop", label = "Shop", eyebrow = "Packs", icon = "Shop", accentKey = "mango" },
	{ id = "Settings", label = "Settings", eyebrow = "Options", icon = "Settings", accentKey = "violet" },
}

local MORE_ROUTES: { RouteDef } = {
	{ id = "Worlds", label = "Worlds", eyebrow = "Zones", icon = "World", accentKey = "mint" },
	{ id = "Missions", label = "Missions", eyebrow = "Jobs", icon = "Mission", accentKey = "cyan" },
	{ id = "Rewards", label = "Rewards", eyebrow = "Dailies", icon = "Rewards", accentKey = "pink" },
	{ id = "Boosts", label = "Boosts", eyebrow = "Power up", icon = "Boost", accentKey = "pink" },
	{ id = "StarGrid", label = "Star Grid", eyebrow = "Dust", icon = "StarGrid", accentKey = "mango" },
	{ id = "Echoes", label = "Echoes", eyebrow = "Keep", icon = "Wave", accentKey = "cyan" },
	{ id = "Continuum", label = "Next Rank", eyebrow = "Plan", icon = "Continuum", accentKey = "pink" },
	{ id = "Lab", label = "Lab", eyebrow = "Orders", icon = "Lab", accentKey = "mint" },
	{ id = "Anomaly", label = "Shift Plan", eyebrow = "Do this", icon = "Reactor", accentKey = "pink" },
	{ id = "Wheel", label = "Wheel", eyebrow = "Spin", icon = "Wheel", accentKey = "mango" },
	{ id = "Command", label = "Command", eyebrow = "Crew", icon = "Command", accentKey = "cyan" },
	{ id = "Story", label = "Story", eyebrow = "Read", icon = "Story", accentKey = "mint" },
	{ id = "Mail", label = "Mail", eyebrow = "Inbox", icon = "Mail", accentKey = "cyan" },
	{ id = "Chat", label = "Chat", eyebrow = "Talk", icon = "Chat", accentKey = "mint" },
	{ id = "Crew", label = "Crew", eyebrow = "Online", icon = "Crew", accentKey = "blue" },
	{ id = "Milestones", label = "Milestones", eyebrow = "Goals", icon = "Milestone", accentKey = "mango" },
	{ id = "Convergence", label = "Converge", eyebrow = "Co-op", icon = "Domain", accentKey = "mango" },
	{ id = "Guild", label = "Guild", eyebrow = "Hall", icon = "Crew", accentKey = "violet" },
	{ id = "Leaderboards", label = "Ranks", eyebrow = "Top 25", icon = "Leaderboard", accentKey = "cyan" },
	{ id = "Trade", label = "Trade", eyebrow = "Swap", icon = "Send", accentKey = "mint" },
	{ id = "Credits", label = "Credits", eyebrow = "About", icon = "Credits", accentKey = "violet" },
	{ id = "Admin", label = "Admin", eyebrow = "Owner", icon = "Admin", accentKey = "coral" },
	{ id = "ForgePath", label = "Forge Path", eyebrow = "Upgrades", icon = "Forge", accentKey = "violet" },
}

-- PageRouter PageContentInner dispatch keys (Credits / Chat / Admin use special chrome).
local PAGE_ROUTES: { string } = {
	"Overview",
	"Workshop",
	"Research",
	"StarGrid",
	"Echoes",
	"Continuum",
	"Convergence",
	"Lab",
	"Anomaly",
	"Worlds",
	"Missions",
	"Milestones",
	"Wheel",
	"Rewards",
	"Boosts",
	"Command",
	"Story",
	"Mail",
	"Chat",
	"Crew",
	"Guild",
	"Leaderboards",
	"Shop",
	"Inventory",
	"Trade",
	"Settings",
	"Admin",
	"ForgePath",
}

local function indexById(routes: { RouteDef }): { [string]: RouteDef }
	local map = {}
	for _, route in routes do
		map[route.id] = route
	end
	return map
end

local PRIMARY_BY_ID = indexById(PRIMARY_ROUTES)
local MORE_BY_ID = indexById(MORE_ROUTES)
local ALL_BY_ID: { [string]: RouteDef } = {}
for id, route in PRIMARY_BY_ID do
	ALL_BY_ID[id] = route
end
for id, route in MORE_BY_ID do
	ALL_BY_ID[id] = route
end

local PAGE_SET: { [string]: boolean } = {}
for _, id in PAGE_ROUTES do
	PAGE_SET[id] = true
end

NavRouteTable.PRIMARY_ROUTES = table.freeze(PRIMARY_ROUTES)
NavRouteTable.MORE_ROUTES = table.freeze(MORE_ROUTES)
NavRouteTable.PAGE_ROUTES = table.freeze(PAGE_ROUTES)

function NavRouteTable.find(pageId: string): RouteDef?
	return ALL_BY_ID[pageId]
end

function NavRouteTable.isNavRoute(pageId: string): boolean
	return ALL_BY_ID[pageId] ~= nil
end

function NavRouteTable.isPageRoute(pageId: string): boolean
	return PAGE_SET[pageId] == true
end

function NavRouteTable.allNavIds(): { string }
	local ids = table.create(#PRIMARY_ROUTES + #MORE_ROUTES)
	for _, route in PRIMARY_ROUTES do
		table.insert(ids, route.id)
	end
	for _, route in MORE_ROUTES do
		table.insert(ids, route.id)
	end
	return ids
end

return table.freeze(NavRouteTable)
