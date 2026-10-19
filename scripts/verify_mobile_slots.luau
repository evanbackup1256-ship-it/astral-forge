-- Mobile HUD editor memory slots persist as a versioned, bounded profile string.
local fs = require("./_memberfs")(require("@lune/fs"))

local Slots = require("../out/Shared/AstralForge/Shared/MobileLayoutSlots")

assert(next(Slots.Decode(nil)) == nil, "nil decodes empty")
assert(next(Slots.Decode("")) == nil, "empty string decodes empty")
assert(next(Slots.Decode("v0|quick:0.5:0.5||")) == nil, "unknown version ignored")
assert(next(Slots.Decode(string.rep("x", 600))) == nil, "oversized ignored")

local encoded = Slots.Encode({
	[1] = { quick = { x = 0.25, y = 0.7 }, dock = { x = 0.5, y = 2 } },
	[3] = { toasts = { x = -1, y = 0.3333 }, ["bad id!"] = { x = 0.1, y = 0.1 } },
})
assert(string.sub(encoded, 1, 3) == "v1|", "version prefix")
assert(#encoded <= Slots.MAX_LENGTH, "bounded")
local decoded = Slots.Decode(encoded)
assert(decoded[1].quick.x == 0.25 and decoded[1].quick.y == 0.7, "slot 1 quick")
assert(decoded[1].dock.y == 1, "clamped high")
assert(decoded[2] == nil, "empty slot stays empty")
assert(decoded[3].toasts.x == 0 and math.abs(decoded[3].toasts.y - 0.333) < 1e-9, "clamped low and rounded")
assert(decoded[3]["bad id!"] == nil, "invalid ids dropped")
assert(Slots.Encode(decoded) == encoded, "round trip stable")

assert(Slots.Normalize("garbage") == nil, "normalize rejects non-versioned")
assert(Slots.Normalize("v1|quick:0.5:0.5|junk|") == "v1|quick:0.500:0.500||", "normalize drops junk")

local big = {}
for i = 1, 20 do
	big["slot" .. string.char(96 + i)] = { x = 0.123456, y = 0.654321 }
end
local bigEncoded = Slots.Encode({ big, big, big })
assert(#bigEncoded <= Slots.MAX_LENGTH, "max entries keep string under cap: " .. #bigEncoded)

local function read(path)
	return fs.readFile(path)
end
local server = read("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "MobileLayoutSlots.Normalize(payload.Slots)", 1, true), "server normalizes slots")
assert(string.find(server, "profile.Flags.MobileLayoutSlots = normalized", 1, true), "server saves slots to flags")
local data = read("src/Server/AstralForge/Services/DataService.luau")
assert(string.find(data, "profile.Flags.MobileLayoutSlots = \"\"", 1, true), "data service sanitizes slots")
local firewall = read("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(string.find(firewall, "stringField(payload, \"Slots\", 0, 512)", 1, true), "firewall bounds slots")
local overlays = read("src/Client/AstralForge/UiOverlays.luau")
assert(string.find(overlays, "MobileLayoutSlots.Decode(_param.savedSlots)", 1, true), "client seeds memory")
assert(string.find(overlays, "Slots = MobileLayoutSlots.Encode(MOBILE_LAYOUT_MEMORY)", 1, true), "client persists on store")
local system = read("src/Client/AstralForge/pages/PagesSystem.luau")
assert(string.find(system, "savedSlots = (state.Flags or {}).MobileLayoutSlots", 1, true), "settings passes saved slots")

print("verify_mobile_slots OK")
