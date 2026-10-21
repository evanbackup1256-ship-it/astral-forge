--!strict
-- Credits: SharedData#CreditsConfig drives the screen through CreditsModel.
--  * the shipped config is valid and covers owner / developers / moderators / testers,
--  * normalize() fills defaults, clamps numbers and drops bad entries,
--  * tabs, search, empty categories and the column math behave.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local function load(member: string): any
	local source = fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#" .. member)
	return luau.load(source, { chunkName = member })()
end

local Model = load("CreditsModel")
local config = load("CreditsConfig")

-- The shipped config
local model = Model.normalize(config)
local ids = {}
for _, category in model.Categories do
	ids[category.Id] = category
end
for _, id in { "Owner", "Developers", "Moderators", "Testers" } do
	assert(ids[id] ~= nil, "credits need a " .. id .. " category")
end
assert(#ids.Owner.Members >= 1, "the owner is listed")
assert(ids.Owner.Members[1].UserId ~= nil, "the owner shows an avatar")
assert(#model.Categories == #config.Categories, "every shipped category survives normalize")

-- Defaults, clamps and bad entries
local messy = Model.normalize({
	AvatarSize = 500,
	MaxColumns = 0,
	StaggerStep = -1,
	CardStyle = "Huge",
	AvatarShape = "Star",
	DefaultCategory = "Nope",
	Categories = {
		{ Id = "A", Members = { { Name = "Ann", Role = "Mod" }, { Role = "no name" }, "junk" } },
		{ Id = "A", Members = { { Name = "Dup" } } },
		{ Label = "no id" },
		{ Id = "All", Members = { { Name = "reserved" } } },
		{ Id = "Empty", Members = {} },
	},
})
assert(messy.AvatarSize == 96 and messy.MaxColumns == 1 and messy.StaggerStep == 0, "numbers clamp")
assert(messy.CardStyle == "Card" and messy.AvatarShape == "Rounded", "unknown styles fall back")
assert(messy.DefaultCategory == "All", "an unknown default tab falls back to All")
assert(#messy.Categories == 2, "duplicate, id-less and reserved categories drop")
assert(#messy.Categories[1].Members == 1 and messy.Categories[1].Members[1].DisplayName == "Ann", "nameless members drop")
assert(Model.normalize(nil).Title ~= "", "a missing config still renders")

-- Tabs, search and empty categories
assert(messy.HideEmptyCategories == true, "roles nobody holds are hidden by default")
messy.HideEmptyCategories = false
local tabs = Model.tabs(messy)
assert(tabs[1].id == "All" and tabs[1].count == 1, "All tab counts everyone")
assert(#tabs == 3, "empty categories get a tab when shown")
assert(#Model.visible(messy, "All", "") == 2, "empty category shows its placeholder")
assert(#Model.visible(messy, "All", "ann") == 1, "search narrows and hides empty categories")
assert(#Model.visible(messy, "All", "  MOD ") == 1, "search matches roles, trimmed and case-insensitive")
assert(#Model.visible(messy, "All", "zzz") == 0, "no matches")
assert(#Model.visible(messy, "Empty", "") == 1, "a single tab shows only that category")
messy.HideEmptyCategories = true
assert(#Model.tabs(messy) == 2 and #Model.visible(messy, "All", "") == 1, "HideEmptyCategories hides tab and section")

-- Columns and card heights
local wide = Model.normalize({ MaxColumns = 3, CardMinWidth = 220 })
assert(Model.columns(wide, 900, 10) == 3, "wide panel: three columns")
assert(Model.columns(wide, 460, 10) == 2, "medium: two")
assert(Model.columns(wide, 200, 10) == 1, "narrow: one, never zero")
assert(Model.columns(Model.normalize({ CardStyle = "Compact" }), 900, 10) == 1, "compact rows are one column")
assert(Model.cardHeight(wide) >= wide.AvatarSize + 24, "cards fit the avatar")

-- The screen reads the config instead of hard-coding people.
local view = fs.readFile("src/Client/AstralForge/UiCore.luau#CreditsView")
assert(string.find(view, 'SharedData("CreditsConfig")', 1, true), "Credits reads CreditsConfig")
assert(not string.find(view, "DEV_USER_ID", 1, true), "no hard-coded developer")
assert(string.find(view, 'key = "CreditsClaimActions"', 1, true), "gamepad host keeps its name (React sets Name from key)")
assert(string.find(view, "useSurfaceEnter", 1, true) and string.find(view, "useSurfaceSpring", 1, true), "credits rows arrive and respond on the shared surface spring")
assert(string.find(view, "Text = initial", 1, true) and string.find(view, "rbxthumb://type=AvatarHeadShot", 1, true), "credits avatars keep initials behind live headshots")

print("verify_credits: ok")
