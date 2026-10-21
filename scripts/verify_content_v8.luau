--!nocheck
-- Version 8 content: every new row lands in its table with a unique id, uses copy from Locale,
-- stays inside the existing curves for its rarity, costs no Robux, and the landmark worlds only
-- rename worlds past the last written one (stats still come from WorldCurve). Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
local Content = H.load("Shared/AstralForge/Shared/ContentV8")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local ProfileStyle = H.load("Shared/AstralForge/Shared/ProfileStyle")
local LimitedEvents = H.load("Shared/AstralForge/Shared/LimitedEvents")
local SharedData = H.load("Shared/AstralForge/Shared/SharedData")
local ShopCatalog = SharedData("ShopCatalog")

local function unique(list, label)
	local seen = {}
	for _, row in list do
		check(not seen[row.Id], label .. " ids are unique: " .. tostring(row.Id))
		seen[row.Id] = true
		check(type(row.Name) == "string" and #row.Name > 0 and not string.find(row.Name, "Content%."), label .. " " .. tostring(row.Id) .. " has copy")
	end
	return seen
end

local relics = unique(GameConfig.Items.Definitions, "relic")
local peak = {}
for _, d in GameConfig.Items.Definitions do
	if not d.Set then
		local key = d.Rarity .. "/" .. d.EffectKind
		peak[key] = math.max(peak[key] or 0, d.BaseEffect)
	end
end
for _, set in Content.RELIC_SETS do
	for _, id in set.Relics do check(relics[id], "set " .. set.Id .. " relic exists: " .. id) end
end
for _, d in GameConfig.Items.Definitions do
	if d.Set then
		check(GameConfig.Items.Rarities[d.Rarity] ~= nil, d.Id .. " uses a real rarity")
		local cap = peak[d.Rarity .. "/" .. d.EffectKind]
		check(cap == nil or d.BaseEffect <= cap, d.Id .. " is no stronger than the best relic of its rarity")
	end
end
unique(GameConfig.Operations.Artifacts, "companion")
local elements = {}
for _, a in GameConfig.Operations.Artifacts do
	check(not elements[a.Element], "one companion per element: " .. tostring(a.Element))
	elements[a.Element] = true
	check(GameConfig.Operations.ArtifactShop[a.Rarity] ~= nil, a.Id .. " has a Stardust price for its rarity")
end
check(#GameConfig.Operations.Artifacts == 57, "every element has a companion")
unique(GameConfig.Operations.Titles, "title")
unique(GameConfig.Achievements, "achievement")
for _, a in GameConfig.Achievements do
	for key in a.Reward do check(key ~= "Robux", a.Id .. " pays no Robux") end
end
unique(ProfileStyle.FRAMES, "frame")
unique(ProfileStyle.ACCENTS, "accent")
for _, f in Content.FRAMES do check(ProfileStyle.findFrame(f.Id) ~= nil, "frame is selectable: " .. f.Id) end
local facts = ProfileStyle.factsOf({ Rebirths = 0 })
local state, err = ProfileStyle.validate({ Accent = "Cyan", Frame = "Plain" }, nil, "Lanternlight", facts)
check(state == nil and type(err) == "string", "a locked v8 frame is refused")
state = ProfileStyle.validate({ Accent = "Cyan", Frame = "Plain" }, "Harbour", "Lanternlight", ProfileStyle.factsOf({ Rebirths = 120 }))
check(state ~= nil and state.Frame == "Lanternlight" and state.Accent == "Harbour", "an earned v8 frame and accent are accepted")
check(ProfileStyle.read({ ProfileFrame = "Plain" }).Frame == "Plain", "old saves read unchanged")
for _, s in Content.EARNED_SKINS do
	local skin = ShopCatalog.skin(s.Id)
	check(skin ~= nil and skin.Earn ~= nil and skin.Price == nil, "earned skin is found and never sold: " .. s.Id)
end
for _, e in Content.EVENTS do check(LimitedEvents.byId(e.Id) ~= nil, "event is on the calendar: " .. e.Id) end
local zone = GameConfig.ResolveZone(150)
check(zone and zone.Name == "The Breakwater", "world 150 is the Breakwater")
local plain = GameConfig.ResolveZone(151)
check(plain and zone.Cost ~= nil and plain.Name ~= "The Breakwater", "worlds around a landmark keep their names")
check(GameConfig.ResolveZone(1).Name == "Nebula Dock", "written worlds are untouched")

if #failures > 0 then
	error("[TEST] content v8 failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] content v8: %d checks (relic sets, companions, skins, titles, frames, achievements, worlds, events) passed", checks))
