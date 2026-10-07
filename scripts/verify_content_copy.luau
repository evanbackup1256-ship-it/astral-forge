local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Roblox = require("@lune/roblox")
local Expansion = require("../src/Shared/AstralForge/Shared/CrateExpansion")
local Shared = require("../src/Shared/AstralForge/Shared/SharedData")
local path = "src/Shared/AstralForge/Shared/GameConfig.luau"
local previous = process.exec("git", { "show", "HEAD:" .. path })
assert(previous.ok, "Cannot read content baseline")
local function config(source)
	return luau.load(source, {
		environment = setmetatable({
			Color3 = Roblox.Color3,
			script = {
				Parent = {
					CrateExpansion = "CrateExpansion",
					WaitForChild = function(_, name)
						return name
					end,
				},
			},
			require = function(name)
				if name == "CrateExpansion" then
					return Expansion
				end
				if name == "SharedData" then
					return Shared
				end
				if name == "GameConfigGenerated" then
					return {}
				end
				error("Unexpected dependency " .. tostring(name))
			end,
		}, { __index = getfenv(0) }),
	})()
end
local before, after = config(previous.stdout), config(fs.readFile(path))
local copyFields = {}
for _, key in
	{
		"Name",
		"Description",
		"Title",
		"Subject",
		"Chapter",
		"Summary",
		"Body",
		"Preview",
		"Sender",
		"Tagline",
		"Lore",
		"Features",
		"Notes",
		"Highlights",
		"Announcement",
	}
do
	copyFields[key] = true
end
local checked = 0
local hiddenAchievementIds = {
	EventHorizon = true,
	ForgeApex = true,
	StoryArchivist = true,
}
local function compare(left, right, location)
	assert(typeof(left) == typeof(right), location .. ": type changed")
	if type(left) == "function" then
		return
	end
	if type(left) ~= "table" then
		if
			type(left) == "string"
			and (
				string.sub(location, 1, #"GameConfig.ClientPageGuides.") == "GameConfig.ClientPageGuides."
				or location == "GameConfig.Game.Update.Subtitle"
			)
		then
			return
		end
		assert(left == right, location .. ": gameplay value changed")
		checked += 1
		return
	end
	for key, value in left do
		if not copyFields[key] then
			compare(value, right[key], location .. "." .. tostring(key))
		end
	end
	for key in right do
		local hiddenAchievementMetadata =
			key == "Hidden"
			and left[key] == nil
			and right[key] == true
			and string.sub(location, 1, #"GameConfig.Achievements.") == "GameConfig.Achievements."
			and hiddenAchievementIds[right.Id] == true
		local crateAddition = (
			location == "GameConfig.Items.Crates"
			and type(key) == "number"
			and key > 9
			and key <= 21
		)
		local keyAddition = (
			location == "GameConfig.Items.ShopOffers"
			and type(key) == "number"
			and key > 16
			and key <= 28
		)
		local ascensionConfigAddition =
			location == "GameConfig.Domain" and (key == "TreeSchemaVersion" or key == "TreeRespec")
		local expeditionPlannerConfigAddition =
			location == "GameConfig.Operations"
			and (key == "ExpeditionPlanVersion" or key == "ExpeditionPlanOrder" or key == "ExpeditionPlans")
		assert(
			left[key] ~= nil
				or copyFields[key]
				or crateAddition
				or keyAddition
				or hiddenAchievementMetadata
				or ascensionConfigAddition
				or expeditionPlannerConfigAddition,
			location .. ": field added " .. tostring(key)
		)
	end
end
compare(before, after, "GameConfig")
print(`[TEST] copy compatibility: {checked} gameplay values unchanged against HEAD`)
