--!strict
-- The Domain Lattice (Shared/DomainLattice): the figure, the etching rules, bonuses, facets,
-- sanitising, the old tree's refund, and the server/client wiring around it.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local L = luau.load(fs.readFile("src/Shared/AstralForge/Shared/DomainLattice.luau"), { chunkName = "DomainLattice" })() :: any

-- the figure
assert(#L.ANCHORS == 13, "thirteen anchors")
assert(#L.EDGES == 30, "thirty links, got " .. #L.EDGES)
assert(#L.TRIANGLES == 18, "eighteen triangles, got " .. #L.TRIANGLES)
assert(L.maxDegree(L.HEARTH) == 6, "the Hearth takes six links")
for index = 2, 7 do
	assert(L.maxDegree(index) == 5, "inner anchors take five")
end
for index = 8, 13 do
	assert(L.maxDegree(index) == 4, "outer anchors take four")
end
local kinds = {}
for _, anchor in L.ANCHORS do
	assert(not kinds[anchor.kind], "one anchor per bonus: " .. anchor.kind)
	kinds[anchor.kind] = true
	assert(type(anchor.name) == "string" and #anchor.name <= 12, "short plain names")
end
for _, t in L.TRIANGLES do
	assert(L.isEdge(t[1], t[2]) and L.isEdge(t[2], t[3]) and L.isEdge(t[1], t[3]), "every triangle is three real links")
end
assert(L.key(5, 2) == "2-5" and L.key(2, 5) == "2-5", "keys are order-free")
local x, y = L.position(L.HEARTH)
assert(x == 0 and y == 0, "the Hearth sits in the middle")
for index = 2, 13 do
	local px, py = L.position(index)
	local r = math.sqrt(px * px + py * py)
	assert(r > 0.9 and r < 2, "anchors sit on their rings")
end

-- etching
local links = {}
assert(not L.canEtch(links, 2, 3, 10), "links grow out of the Hearth")
assert(not L.canEtch(links, 1, 9, 10), "only real links")
assert(not L.canEtch(links, 1, 2, 0), "it costs points")
assert(L.canEtch(links, 1, 2, 1), "the first link from the Hearth")
links[L.key(1, 2)] = true
assert(L.canEtch(links, 2, 3, 1), "and then outward from anything etched")
assert(not L.canEtch(links, 1, 2, 5), "never twice")
assert(L.linkCost(0) == 1 and L.linkCost(5) == 1 and L.linkCost(6) == 2 and L.linkCost(12) == 3, "costs climb every six links")
assert(L.spent(0) == 0 and L.spent(6) == 6 and L.spent(7) == 8, "spent sums the costs")
assert(L.spent(30) == 90, "the whole lattice costs 90 points")

-- bonuses fill with links and facets add production
links = {}
assert(L.bonus(links, "Capacity") == 0 and L.bonus(nil, "Production") == 0, "an empty lattice gives nothing")
links[L.key(1, 2)] = true
local capacityOne = L.bonus(links, "Capacity")
assert(math.abs(capacityOne - 0.36 / 5) < 1e-9, "one link fills a fifth of an inner anchor")
links[L.key(1, 3)] = true
assert(#L.facets(links) == 0, "two sides are not a facet")
local before = L.bonus(links, "Production")
links[L.key(2, 3)] = true
assert(#L.facets(links) == 1, "three sides close a facet")
assert(math.abs(L.bonus(links, "Production") - before - L.FACET_PRODUCTION) < 1e-9, "a facet adds production")
local all = {}
for _, e in L.EDGES do
	all[e.key] = true
end
assert(#L.facets(all) == 18, "a full lattice closes every facet")
for _, anchor in L.ANCHORS do
	local expected = anchor.full + (if anchor.kind == "Production" then 18 * L.FACET_PRODUCTION else 0)
	assert(math.abs(L.bonus(all, anchor.kind) - expected) < 1e-9, "a full anchor gives its full bonus: " .. anchor.kind)
end
assert(L.describe("Capacity", 0.36) == "+36% vault capacity", L.describe("Capacity", 0.36))
assert(L.describe("Critical", 0.04) == "+4% critical strike chance", L.describe("Critical", 0.04))
assert(L.describe("Luck", 0.016) == "+1.6% crate and market luck", L.describe("Luck", 0.016))
assert(L.describe("EssenceGain", 2) == "+2 essence per expansion", L.describe("EssenceGain", 2))

-- sanitising keeps only what reaches the Hearth and refunds the rest
local messy = { [L.key(1, 2)] = true, [L.key(9, 10)] = true, ["1-99"] = true, nonsense = true }
local clean, refund = L.sanitize(messy)
assert(clean[L.key(1, 2)] and not clean[L.key(9, 10)] and not clean["1-99"], "stray links dropped")
assert(L.count(clean) == 1 and refund == L.spent(2) - L.spent(1), "dropped real links are refunded")
local same, none = L.sanitize(all)
assert(L.count(same) == 30 and none == 0, "a connected lattice is untouched")

-- the old tree comes back as points
assert(L.oldTreeRefund({ FluxVein = true, AstralCrown = 1, Mystery = true }) == 9, "old nodes refund their cost")
assert(L.oldTreeRefund(nil) == 0)

-- wiring
local economy = fs.readFile("src/Server/AstralForge/Modules/EconomyMath.luau")
assert(economy:find("return DomainLattice.bonus(domain and domain.Links, field)", 1, true), "every domain bonus comes from the lattice")
assert(not economy:find("GameConfig.Domain.Tree", 1, true), "the old tree is gone from the economy")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(server:find("function GameService:_domainLattice(", 1, true) and not server:find("_unlockDomainNode", 1, true), "etch/clear replace node unlocks")
assert(server:find("(tonumber(domain.LatticeClearedAtRank) or 0) >= domain.Rank", 1, true), "clearing is once per rank")
local data = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
assert(data:find("DomainLattice.oldTreeRefund(profile.Domain.Nodes)", 1, true), "old saves are refunded")
assert(data:find("DomainLattice.sanitize(profile.Domain.Links)", 1, true), "saved links are sanitised")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(firewall:find("[Protocol.Actions.DomainLattice]", 1, true) and firewall:find('"invalid lattice anchors"', 1, true), "the firewall knows the action")
local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(not config:find('Id = "FluxVein"', 1, true), "the old tree is gone from the config")
local overlays = fs.readFile("src/Client/AstralForge/UiOverlays.luau")
assert(overlays:find('__defs["DomainChamber"]', 1, true), "the chamber replaces both old overlays")
assert(not overlays:find("DomainSkillTree", 1, true) and not overlays:find("DomainExpansionOverlay", 1, true), "no old overlay is left")
assert(overlays:find('props.dispatch("DomainLattice", { Op = "Etch", A = a, B = b }', 1, true), "etching is server-authoritative")
assert(overlays:find("local HOLD_SECONDS = 1.1", 1, true), "expanding still needs a hold")
for _, gone in { "DomainConstellation.luau", "DomainConstellationMath.luau", "DomainHexStage.luau" } do
	assert(not fs.isFile("src/Client/AstralForge/" .. gone), gone .. " is deleted")
end
print("[TEST] domain lattice: figure, etching, costs, bonuses, facets, sanitising, refund and wiring passed")
