--!strict
-- Settings (SharedData#SettingsSchema):
--  * every setting the save template stores is either on the page or explicitly hidden, and every page
--    setting exists in the template with the same default (so the page shows what the save holds);
--  * switches store 0/1, choices snap to an option, sliders clamp; NaN never gets through;
--  * presets and section resets fit in one SetSetting request (the server applies at most 24 values);
--  * the server validates against the schema and the page is drawn from it.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Schema = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#SettingsSchema"), { chunkName = "SettingsSchema" })() :: any
local template = fs.readFile("src/Server/AstralForge/DataTemplate.luau")
local settingsBlock = string.match(template, "Settings = (%b{})")
assert(settingsBlock ~= nil, "could not find Settings in DataTemplate")

local stored: { [string]: number } = {}
for key, value in string.gmatch(settingsBlock, "(%w+)%s*=%s*([%d%.]+)") do
	stored[key] = tonumber(value) :: number
end
-- Positions written by the phone HUD editor and the guild opt-in have their own actions.
local OWN_ACTIONS = { MobileQuickX = true, MobileQuickY = true, MobileDockX = true, MobileDockY = true, MobileToastX = true, MobileToastY = true, NotifyGuild = true }

for key, default in stored do
	if not OWN_ACTIONS[key] then
		assert(Schema.accepts(key), "the save stores " .. key .. " but the schema neither shows nor accepts it")
	end
end
local sectionIds = {}
for _, section in Schema.SECTIONS do
	sectionIds[section.id] = true
end
for _, entry in Schema.ENTRIES do
	assert(sectionIds[entry.section], entry.key .. " is in an unknown section " .. entry.section)
	assert(type(entry.label) == "string" and entry.label ~= "" and #entry.label <= 28, entry.key .. " needs a short label")
	assert(type(entry.help) == "string" and entry.help ~= "" and #entry.help <= 64, entry.key .. " needs a one-line note (64 chars max)")
	assert(stored[entry.key] ~= nil, entry.key .. " is on the page but missing from DataTemplate")
	assert(math.abs(stored[entry.key] - entry.default) < 0.001, entry.key .. " default " .. entry.default .. " differs from the template's " .. stored[entry.key])
	if entry.kind == "choice" then
		assert(entry.choices ~= nil and #entry.choices >= 2 and #entry.choices <= 4, entry.key .. " needs 2-4 choices")
		local hit = false
		for _, option in entry.choices do
			hit = hit or math.abs(option.value - entry.default) < 0.001
		end
		assert(hit, entry.key .. "'s default must be one of its choices")
	end
end

-- normalize
assert(Schema.normalize("ShowFps", 0.7) == 1 and Schema.normalize("ShowFps", 0.2) == 0, "switches store 0 or 1")
assert(Schema.normalize("DesktopTextScale", 0.6) == 0.5 and Schema.normalize("DesktopTextScale", 0.9) == 1, "choices snap to the nearest option")
assert(Schema.normalize("MusicVolume", 1.7) == 1 and Schema.normalize("MusicVolume", -3) == 0, "sliders clamp")
assert(Schema.normalize("MusicVolume", 0 / 0) == 0, "NaN never reaches a save")
assert(not Schema.accepts("Cash") and not Schema.accepts(nil) and not Schema.accepts(42), "only settings are accepted")
assert(Schema.value({}, "UiVolume") == 0.6 and Schema.value({ UiVolume = 0.2 }, "UiVolume") == 0.2, "value falls back to the default")

-- presets and resets fit one request
for _, preset in Schema.PRESETS do
	local count = 0
	for key in preset.values do
		assert(Schema.accepts(key), "preset " .. preset.id .. " sets unknown " .. key)
		count += 1
	end
	assert(count <= 24, "preset " .. preset.id .. " sets more than one request allows")
end
for _, section in Schema.SECTIONS do
	local count = 0
	for _ in Schema.sectionDefaults(section.id) do
		count += 1
	end
	assert(count > 0 and count <= 24, section.id .. " reset must fit one request, got " .. count)
end
assert(Schema.matchingPreset({}) == nil or Schema.matchingPreset({}) ~= "", "matchingPreset answers")
local high = {}
for key, value in Schema.PRESETS[3].values do
	high[key] = value
end
assert(Schema.matchingPreset(high) == "high", "the page recognises a preset it applied")

-- wiring
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, '("SettingsSchema")', 1, true) and string.find(server, "Schema.normalize(", 1, true), "the server validates SetSetting with the schema")
local page = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau#SettingsView")
for _, needle in { '("SettingsSchema")', "Schema.ENTRIES", "Schema.PRESETS", "sectionDefaults", "SearchField", "local function Switch", "local function Choice" } do
	assert(string.find(page, needle, 1, true), "the Settings page uses " .. needle)
end

print("verify_settings_schema: ok")
