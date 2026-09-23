--!strict
-- Wave24 offline residuals: Crew FlatList/FocusClaim/softMotion (CrewView extract owns
-- roster hosts as of wave28), Overview softMotion canon (OverviewView as of wave29;
-- effectsPaused on quietMotion only), Guild softMotion past DENSE floor.

local fs = require("@lune/fs")

local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local crew = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
local overview = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
local workshop = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
local guild = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
local readme = fs.readFile("README.md")

local CANON = "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient"

assert(string.find(workshop, CANON, 1, true), "Workshop softMotion canon")
assert(string.find(overview, "local quietMotion = softMotion or effectsPaused or antilag.skipEntrance", 1, true), "Overview quietMotion")
assert(string.find(overview, CANON, 1, true), "Overview softMotion canon")
assert(string.find(crew, 'Name = "CrewVisitClaim"', 1, true), "CrewVisitClaim")
assert(string.find(crew, 'Name = "CrewVisitConfirm"', 1, true), "CrewVisitConfirm")
assert(string.find(crew, "GamepadNavigationService.FocusClaim", 1, true), "Crew FocusClaim")
assert(string.find(crew, "createElement(FlatList", 1, true), "Crew FlatList")
assert(string.find(crew, "overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2", 1, true), "Crew overscan")
assert(string.find(crew, "virtRoster = #players >= 8", 1, true) or string.find(crew, "#players >= 8", 1, true), "Crew virt threshold")
assert(string.find(crew, CANON, 1, true), "Crew softMotion canon")

local guildSoft = 0
for _ in string.gmatch(guild, "softMotion") do
	guildSoft += 1
end
assert(guildSoft >= 8, "Guild softMotion density, got " .. tostring(guildSoft))

-- README must not ship the literal /path/to placeholder that breaks PowerShell cd.
assert(not string.find(readme, "cd /path/to/astral-forge", 1, true), "README must not use /path/to placeholder")
assert(string.find(readme, "OneDrive", 1, true), "README OneDrive git lock note")
assert(string.find(readme, "git pull origin master", 1, true), "README pull tip")

print("[INFO] [TEST] wave24 harden residuals passed")
