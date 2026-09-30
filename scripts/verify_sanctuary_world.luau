--!strict
-- Guards for the expanded sanctuary: the map, ore outcrops and the Rift Warden.
--
--   1. Map shape: regions fit the world, never overlap, and grow the ore the
--      config says they do.
--   2. Bridges join the hub rim to each plateau, continuously and at a
--      walkable grade, without cutting through another region.
--   3. Waystones: one per region, on its plateau, clear of the bridge landing.
--   4. Ore sites: on the plateau, spaced apart, clear of the landing corridor
--      and the waystone.
--   5. The arena contains the strike range and the slam.
--   6. OreMath: sanitising, costs, purchases, effects, yield.
--   7. RiftBossMath: the phase machine, damage, rewards, slams -- and the
--      Warden can be beaten by one level-1 player even while being slammed.
--   8. Wiring: every effect the server fires reaches the client bus, every
--      action is registered end to end, and the client controllers are used.
--
-- HARD: pure checks -- no Roblox instances.

local fs = require("./_memberfs")(require("@lune/fs"))

local Layout = require("../src/Shared/AstralForge/Shared/SharedData")("SanctuaryLayout")
local SanctuaryConfig = require("../src/Shared/AstralForge/Shared/SharedData")("SanctuaryConfig")
local OreMath = require("../src/Server/AstralForge/Modules/OreMath")
local RiftBossMath = require("../src/Server/AstralForge/Modules/EconomyMath")("RiftBossMath")
local Signals = require("../src/Client/AstralForge/SanctuaryKit")("sanctuarySignals")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local function flat(a, b): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local OreConfig = SanctuaryConfig.Ore
local Boss = SanctuaryConfig.RiftBoss
local regions = Layout.regions()
local hub = regions[1]

------------------------------------------------------------------------
-- 1. Map shape
------------------------------------------------------------------------
assert(hub.Id == "Heart", "the hub must be the first region")
assert(hub.Center.X == 0 and hub.Center.Z == 0, "the hub sits on the origin")
assert(#regions == 5, "the sanctuary has the hub and four outer regions")
local seenRegion: { [string]: boolean } = {}
for _, region in regions do
	assert(not seenRegion[region.Id], "duplicate region " .. region.Id)
	seenRegion[region.Id] = true
	assert(flat(region.Center, hub.Center) + region.Radius <= Layout.WORLD_RADIUS, region.Id .. " spills past WORLD_RADIUS")
	assert(Layout.inBounds(region.Center), region.Id .. " centre must be in bounds")
	assert(Layout.region(region.Id) == region, "Layout.region must find " .. region.Id)
	assert(Layout.regionAt(region.Center) == region, "regionAt(centre) must return " .. region.Id)
end
for i = 1, #regions do
	for j = i + 1, #regions do
		local a, b = regions[i], regions[j]
		local clearance = flat(a.Center, b.Center) - a.Radius - b.Radius
		assert(clearance >= 60, `{a.Id} and {b.Id} are too close ({math.floor(clearance)} studs of open sky)`)
	end
end
local oreRegions: { [string]: string } = {}
for _, region in regions do
	if region.Ore ~= nil then
		oreRegions[region.Ore] = region.Id
		assert(region.OreSites > 0, region.Id .. " grows ore but has no sites")
	else
		assert(region.OreSites == 0, region.Id .. " has sites but no ore")
	end
end
for _, ore in OreConfig.Types do
	assert(oreRegions[ore.Id] == ore.Region, `{ore.Id} must grow in {ore.Region}`)
end
assert(not Layout.inBounds({ X = 0, Y = -Layout.KILL_DEPTH - 1, Z = 0 }), "below the kill depth is out of bounds")
assert(not Layout.inBounds({ X = Layout.WORLD_RADIUS + 1, Y = 0, Z = 0 }), "past the world radius is out of bounds")

------------------------------------------------------------------------
-- 2. Bridges
------------------------------------------------------------------------
local bridges = Layout.bridges()
assert(#bridges == #regions - 1, "one bridge per outer region")
local bridgeFor: { [string]: boolean } = {}
for _, bridge in bridges do
	local target = Layout.region(bridge.Region)
	assert(target ~= nil and target.Id ~= "Heart", "bridge to unknown region " .. bridge.Region)
	assert(not bridgeFor[bridge.Region], "two bridges to " .. bridge.Region)
	bridgeFor[bridge.Region] = true
	assert(flat(bridge.From, hub.Center) <= Layout.HUB_RADIUS, bridge.Region .. " bridge must leave from the hub rim")
	assert(flat(bridge.To, target.Center) <= target.Radius, bridge.Region .. " bridge must land on the plateau")
	assert(bridge.Width >= 12, bridge.Region .. " bridge is too narrow to walk comfortably")
	local spacing = 6
	local points = Layout.bridgePoints(bridge, spacing)
	assert(#points >= 10, bridge.Region .. " bridge has too few points")
	assert(points[1].X == bridge.From.X and points[1].Z == bridge.From.Z, "bridge starts at From")
	local last = points[#points]
	assert(math.abs(last.X - bridge.To.X) < 1e-6 and math.abs(last.Z - bridge.To.Z) < 1e-6, "bridge ends at To")
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		local run = flat(a, b)
		assert(run <= spacing * 1.8, `{bridge.Region} bridge has a gap of {run} studs at point {index}`)
		local grade = math.abs(b.Y - a.Y) / math.max(run, 1e-3)
		assert(grade <= 0.36, `{bridge.Region} bridge is too steep at point {index} (grade {grade})`)
		assert(Layout.inBounds(b), `{bridge.Region} bridge leaves the world at point {index}`)
		-- The span never cuts across a third region.
		local over = Layout.regionAt(b)
		assert(over == nil or over.Id == "Heart" or over.Id == bridge.Region, `{bridge.Region} bridge crosses {over and over.Id}`)
	end
	-- Somewhere in the middle, it is open sky (so the bridge reads as a bridge).
	local middle = points[math.floor(#points / 2)]
	assert(Layout.regionAt(middle) == nil, bridge.Region .. " bridge midpoint should be over open sky")
end

------------------------------------------------------------------------
-- 3. Waystones
------------------------------------------------------------------------
local stones = Layout.waystones()
assert(#stones == #regions, "one waystone per region")
local stoneByRegion: { [string]: any } = {}
for _, stone in stones do
	local region = Layout.region(stone.Region)
	assert(region ~= nil, "waystone in unknown region " .. stone.Region)
	assert(stone.Id == region.Id, "waystone ids match their region")
	assert(stoneByRegion[stone.Region] == nil, "two waystones in " .. stone.Region)
	stoneByRegion[stone.Region] = stone
	assert(flat(stone.Position, region.Center) <= region.Radius - 6, stone.Id .. " waystone must stand on its plateau")
	assert(Layout.waystone(stone.Id) == stone or (Layout.waystone(stone.Id) :: any).Id == stone.Id, "Layout.waystone finds " .. stone.Id)
	assert(Layout.regionAt(stone.Position) == region, stone.Id .. " waystone must read as inside its region")
	if region.Id ~= "Heart" then
		local landing = Layout.landing(region)
		assert(flat(stone.Position, landing) >= 16, stone.Id .. " waystone blocks the bridge landing")
	end
	assert(Layout.nearestWaystone(region.Center).Id == region.Id, "nearest waystone to " .. region.Id .. " must be its own")
end

------------------------------------------------------------------------
-- 4. Ore sites
------------------------------------------------------------------------
local sites = Layout.oreSites()
local siteCount: { [string]: number } = {}
local siteIds: { [string]: boolean } = {}
for _, site in sites do
	local region = Layout.region(site.Region) :: any
	assert(region ~= nil and region.Ore == site.Ore, site.Id .. " grows the wrong ore")
	assert(not siteIds[site.Id], "duplicate ore site " .. site.Id)
	siteIds[site.Id] = true
	siteCount[site.Region] = (siteCount[site.Region] or 0) + 1
	assert(flat(site.Position, region.Center) <= region.Radius - 8, site.Id .. " sits too close to the plateau edge")
	local landing = Layout.landing(region)
	assert(flat(site.Position, landing) >= 20, site.Id .. " sits in the bridge landing corridor")
	local stone = stoneByRegion[site.Region]
	assert(flat(site.Position, stone.Position) >= 12, site.Id .. " crowds the waystone")
end
for _, region in regions do
	assert((siteCount[region.Id] or 0) == region.OreSites, `{region.Id} should have {region.OreSites} ore sites, got {siteCount[region.Id] or 0}`)
end
for i = 1, #sites do
	for j = i + 1, #sites do
		local a, b = sites[i], sites[j]
		if a.Region == b.Region then
			assert(flat(a.Position, b.Position) >= 14, `{a.Id} and {b.Id} overlap`)
		end
	end
end

------------------------------------------------------------------------
-- 5. Arena
------------------------------------------------------------------------
local arena = Layout.arena()
local maw = Layout.region("Riftmaw") :: any
assert(arena.Center == maw.Center, "the arena is centred in the Riftmaw")
assert(arena.Radius < maw.Radius, "the arena fits inside the Riftmaw")
assert(Boss.StrikeRange <= arena.Radius, "strike range must stay inside the arena")
assert(Boss.SlamRadius * 2 < arena.Radius * 2 * 0.7, "a slam must leave most of the arena safe")
assert(arena.Hover.Y > arena.Center.Y + 10, "the Warden hovers well above the floor")

------------------------------------------------------------------------
-- 6. OreMath
------------------------------------------------------------------------
do
	local clean = OreMath.SanitizeBalances({ Emberite = 3.7, Voidglass = -4, Starsteel = 0 / 0, Bogus = 99 }, OreConfig)
	assert(clean.Emberite == 3 and clean.Voidglass == 0 and clean.Starsteel == 0, "balances floor to whole, non-negative numbers")
	assert(clean.Bogus == nil, "unknown ores are dropped")
	local levels = OreMath.SanitizeLevels({ TemperedCores = 999, DeepVault = -2, Nope = 3 }, OreConfig)
	assert(levels.TemperedCores == 30, "levels clamp to MaxLevel")
	assert(levels.DeepVault == nil and levels.Nope == nil, "bad levels are dropped")
	assert(OreMath.SanitizeBalances(nil, OreConfig).Emberite == 0, "a missing bag becomes zeroes")

	local effects = { Production = true, Capacity = true, Tap = true, BossDamage = true, OreYield = true }
	for _, upgrade in OreConfig.Upgrades do
		assert(effects[upgrade.Effect], upgrade.Id .. " has an unknown effect " .. upgrade.Effect)
		assert(upgrade.Description ~= "", upgrade.Id .. " needs a description")
		local previous = 0
		for level = 0, upgrade.MaxLevel - 1 do
			local cost = OreMath.Cost(upgrade, level)
			local total = 0
			for oreId, amount in cost do
				assert(oreRegions[oreId] ~= nil, upgrade.Id .. " costs an unknown ore " .. oreId)
				assert(amount >= 1 and amount == math.floor(amount), upgrade.Id .. " costs must be whole")
				total += amount
			end
			assert(total >= previous, upgrade.Id .. " cost must never drop as levels rise")
			previous = total
		end
	end

	-- Buying.
	local balances: { [string]: number } = { Emberite = 100, Voidglass = 0, Starsteel = 0 }
	local owned: { [string]: number } = {}
	local ok, message = OreMath.Purchase(OreConfig, balances, owned, "TemperedCores")
	assert(ok and owned.TemperedCores == 1 and balances.Emberite == 94, "first Tempered Cores level costs 6 Emberite: " .. message)
	local ok2 = OreMath.Purchase(OreConfig, balances, owned, "DeepVault")
	assert(not ok2 and owned.DeepVault == nil and balances.Voidglass == 0, "can't buy without the ore")
	local ok3 = OreMath.Purchase(OreConfig, balances, owned, "Nope")
	assert(not ok3, "unknown upgrades are refused")
	local maxed = { ProspectorsEye = 10 }
	local rich = { Emberite = 1e9, Voidglass = 1e9, Starsteel = 1e9 }
	local ok4 = OreMath.Purchase(OreConfig, rich, maxed, "ProspectorsEye")
	assert(not ok4 and maxed.ProspectorsEye == 10, "maxed upgrades are refused")

	-- Effects and yield.
	assert(math.abs(OreMath.Effect({ TemperedCores = 10 }, "Production", OreConfig) - 0.3) < 1e-9, "10 Tempered Cores = +30% production")
	assert(OreMath.Effect(nil, "Production", OreConfig) == 0, "no upgrades, no effect")
	for _, ore in OreConfig.Types do
		local low = OreMath.Yield(OreConfig, ore.Id, 0, function(a, _b)
			return a
		end)
		local high = OreMath.Yield(OreConfig, ore.Id, 0.6, function(_a, b)
			return b
		end)
		assert(low == ore.YieldMin, ore.Id .. " minimum yield")
		assert(high == math.floor(ore.YieldMax * 1.6 + 0.5), ore.Id .. " yield scales with Prospector's Eye")
	end
	local public = OreMath.PublicState({ Emberite = 8 }, { TemperedCores = 1 }, OreConfig)
	assert(#public.Types == #OreConfig.Types and #public.Upgrades == #OreConfig.Upgrades, "public state lists every ore and upgrade")
	assert(public.Balances.Emberite == 8, "public balances")
	assert(public.Upgrades[1].Level == 1 and public.Upgrades[1].Affordable == true, "8 Emberite affords Tempered Cores level 2 (ceil(6 x 1.24))")
	local short = OreMath.PublicState({ Emberite = 7 }, { TemperedCores = 1 }, OreConfig)
	assert(short.Upgrades[1].Affordable == false, "7 Emberite is one short")
end

------------------------------------------------------------------------
-- 7. RiftBossMath
------------------------------------------------------------------------
do
	local t = 1000
	local state = RiftBossMath.Initial(t, Boss)
	assert(state.Phase == "Dormant" and state.EndsAt == t + Boss.FirstDelaySeconds, "starts dormant")
	local same, entered = RiftBossMath.Step(state, t + 1, 3, Boss)
	assert(same == state and entered == nil, "nothing happens before the timer")
	state, entered = RiftBossMath.Step(state, state.EndsAt, 3, Boss)
	assert(state.Phase == "Forming" and entered == "Forming", "dormant -> forming")
	state, entered = RiftBossMath.Step(state, state.EndsAt, 3, Boss)
	assert(state.Phase == "Active" and entered == "Active", "forming -> active")
	assert(state.Health == RiftBossMath.MaxHealth(3, Boss) and state.MaxHealth == state.Health, "health scales with fighters")
	assert(RiftBossMath.MaxHealth(0, Boss) == RiftBossMath.MaxHealth(1, Boss), "never less than one fighter's worth")

	-- Defeat ends the fight at once, even with time left.
	local beaten = RiftBossMath.Hit(state, state.Health + 500)
	assert(beaten.Health == 0, "health floors at zero")
	local after, outcome = RiftBossMath.Step(beaten, t + 1, 3, Boss)
	assert(after.Phase == "Defeated" and outcome == "Defeated", "zero health -> defeated immediately")
	local back = RiftBossMath.Step(after, after.EndsAt, 3, Boss)
	assert(back.Phase == "Dormant" and back.EndsAt == after.EndsAt + Boss.IntervalSeconds, "outro -> dormant for the interval")

	-- Running out of time.
	local escaped, how = RiftBossMath.Step(state, state.EndsAt, 3, Boss)
	assert(escaped.Phase == "Escaped" and how == "Escaped", "time out -> escaped")

	-- Damage.
	local plain, crit = RiftBossMath.StrikeDamage(1, 0, 0.99, Boss)
	assert(not crit and plain == math.floor(Boss.BaseDamage + Boss.DamagePerLevel + 0.5), "level 1 strike")
	local critical, wasCrit = RiftBossMath.StrikeDamage(1, 0, 0, Boss)
	assert(wasCrit and critical >= plain * Boss.CritMultiplier - 1, "crits multiply")
	local boosted = RiftBossMath.StrikeDamage(1, 0.8, 0.99, Boss)
	assert(boosted > plain, "Starsteel Edge raises damage")
	assert(RiftBossMath.StrikeDamage(0, -5, 0.99, Boss) >= 1, "a strike always does something")

	-- Slams.
	local hits = RiftBossMath.SlamHits(0, 0, 10, { a = { X = 3, Z = 4 }, b = { X = 10, Z = 0 }, c = { X = 11, Z = 0 } })
	table.sort(hits)
	assert(#hits == 2 and hits[1] == "a" and hits[2] == "b", "slams catch fighters inside the ring (edge included)")
	local delay = RiftBossMath.SlamDelay(0.5, Boss)
	assert(delay >= Boss.SlamIntervalMin and delay <= Boss.SlamIntervalMax, "slam delay in range")
	assert(Boss.SlamTelegraphSeconds >= 1.2, "slams must be readable before they land")
	assert(Boss.SlamIntervalMin > Boss.SlamTelegraphSeconds + Boss.DazeSeconds, "slams can't chain into each other")

	-- Rewards.
	local rewards = RiftBossMath.Rewards({ solo = 900, tourist = 50 }, { solo = 60, tourist = 1 }, Boss)
	assert(rewards.tourist == nil, "a player who barely struck gets nothing")
	assert(rewards.solo ~= nil and rewards.solo.Share == 1, "the only real fighter takes the whole share")
	for currency, rule in Boss.Rewards do
		assert(rewards.solo[currency] == math.floor(rule.Base + rule.Share + 0.5), "solo reward for " .. currency)
	end
	local split = RiftBossMath.Rewards({ a = 300, b = 100 }, { a = 10, b = 10 }, Boss)
	assert(math.abs(split.a.Share + split.b.Share - 1) < 1e-9, "shares add up to one")
	assert(split.a.Stardust > split.b.Stardust, "more damage, more reward")
	assert(next(RiftBossMath.Rewards({}, {}, Boss)) == nil, "no fighters, no rewards")

	-- Balance: n level-1 players, each losing the worst-case daze to every
	-- slam, still beat the Warden with time to spare.
	local expected = (Boss.BaseDamage + Boss.DamagePerLevel) * (1 + Boss.CritChance * (Boss.CritMultiplier - 1))
	local perSecond = expected / Boss.StrikeCooldown
	local downtime = Boss.DazeSeconds / Boss.SlamIntervalMin
	for fighters = 1, 12 do
		local health = RiftBossMath.MaxHealth(fighters, Boss)
		local seconds = health / (perSecond * fighters * (1 - downtime))
		assert(seconds <= Boss.ActiveSeconds * 0.6, `{fighters} level-1 fighters need {math.floor(seconds)}s -- too long for a {Boss.ActiveSeconds}s window`)
	end
	-- ...and it isn't a one-strike pushover for a crowd.
	assert(RiftBossMath.MaxHealth(12, Boss) / (perSecond * 12) >= 8, "a full server should still need a real fight")
	assert(Boss.FormingSeconds >= 20, "players need warning to reach the Riftmaw")
end

------------------------------------------------------------------------
-- 8. Wiring
------------------------------------------------------------------------
do
	-- Every effect the sanctuary services fire is forwarded by the client bus,
	-- and every forwarded kind is fired by someone.
	local serverFiles = {
		"src/Server/AstralForge/Services/WorldServices.luau#OreService",
		"src/Server/AstralForge/Services/WorldServices.luau#RiftBossService",
		"src/Server/AstralForge/Services/WorldServices.luau#SanctuaryFeatures",
	}
	local fired: { [string]: boolean } = {}
	for _, path in serverFiles do
		local source = readSource(path)
		for kind in string.gmatch(source, 'Type = "(%w+)"') do
			fired[kind] = true
			assert(Signals.handles(kind), `{path} fires {kind}, which the client bus drops`)
		end
	end
	for kind in Signals.SERVER_KINDS do
		assert(fired[kind], `the client bus forwards {kind}, which no server service fires`)
	end

	-- The bus delivers, and unsubscribing stops delivery.
	local got = 0
	local stop = Signals.on("OreMined", function(payload)
		got += payload.Amount
	end)
	Signals.fire("OreMined", { Amount = 3 })
	stop()
	Signals.fire("OreMined", { Amount = 5 })
	assert(got == 3, "Signals.on / unsubscribe")

	-- Actions: protocol, firewall, session grants, validators, handler.
	local protocol = readSource("src/Shared/AstralForge/Shared/Protocol.luau")
	local firewall = readSource("src/Server/AstralForge/Services/RemoteFirewall.luau")
	local session = readSource("src/Client/AstralForge/CoreKit.luau#session")
	local validators = readSource("src/Server/AstralForge/Modules/ProfileMath.luau#CommandActionValidators")
	local features = readSource("src/Server/AstralForge/Services/WorldServices.luau#SanctuaryFeatures")
	for _, action in { "BuyOreUpgrade", "StrikeRiftBoss", "TravelWaystone" } do
		assert(string.find(protocol, action, 1, true), action .. " missing from Protocol")
		assert(string.find(firewall, action, 1, true), action .. " missing from RemoteFirewall")
		assert(string.find(session, action, 1, true), action .. " missing from the session grant list")
		assert(string.find(features, `Protocol.Actions.{action} then`, 1, true), action .. " has no handler in SanctuaryFeatures")
	end
	assert(string.find(validators, "StrikeRiftBoss", 1, true) and string.find(validators, "TravelWaystone", 1, true), "strike and travel are deferred-snapshot actions")

	-- Server services.
	local services = readSource("src/Server/AstralForge/Services/ServerServices.luau")
	assert(string.find(services, "SanctuaryFeatures.new(self)", 1, true), "GameService must build SanctuaryFeatures")
	assert(string.find(services, "_sanctuaryFeatures:Handle(", 1, true), "GameService must route sanctuary actions")
	assert(string.find(services, "_sanctuaryFeatures:OreState(", 1, true), "the snapshot must carry ore state")
	-- The service registry calls every entry. A module registered with a bare
	-- require must itself return a factory function; SanctuaryFeatures returns
	-- its class table, so it must be wrapped (it once wasn't, and the server
	-- died at boot with "attempt to call a table value").
	local registered = 0
	for moduleName, rest in string.gmatch(services, 'serviceFactories%["%w+"%] = require%(script%.Parent:WaitForChild%("(%w+)"%)%)([^\n]*)') do
		-- Merged service suites are called with the member name: require(suite)("Member")
		local member = string.match(rest, '^%("(%w+)"%)')
		local path = "src/Server/AstralForge/Services/" .. moduleName .. ".luau"
		if not fs.isFile(path) then
			path = "src/Server/AstralForge/Services/" .. moduleName .. ".lua"
		end
		if member then
			path = path .. "#" .. member
			moduleName = member
		end
		local body = readSource(path)
		assert(string.find(body, "^return function") or string.find(body, "\nreturn function"), moduleName .. " is registered as a factory but doesn't return one")
		registered += 1
	end
	assert(registered >= 10, "the registry scan found too few entries -- did the pattern drift?")
	assert(
		string.find(services, 'serviceFactories["SanctuaryFeatures"] = function()\n\treturn require(script.Parent:WaitForChild("WorldServices"))("SanctuaryFeatures")\nend', 1, true),
		"SanctuaryFeatures must be registered through a factory wrapper"
	)

	local world = readSource("src/Server/AstralForge/Services/WorldServices.luau#WorldService")
	assert(string.find(world, "SanctuaryBuilder.Build(expanse)", 1, true), "WorldService must build the expanse")
	assert(string.find(world, "SanctuaryLayout.KILL_DEPTH", 1, true), "falls are measured against the shared kill depth")

	-- The terrain builder: every underside fill stays below the plateau (the
	-- first version centred a 100-stud ball 10 studs down, capping each region
	-- -- and the forge deck -- under a rock dome), rim rocks and rim scenery
	-- leave the bridge landings open, and one failed step can't stop the rest.
	local builder = readSource("src/Server/AstralForge/Services/WorldServices.luau#SanctuaryBuilder")
	assert(not string.find(builder, "-(10 + k * radius * 0.3)", 1, true), "the domed underside is gone")
	assert(string.find(builder, "-4 - rock)", 1, true), "underside rocks keep their tops under the surface")
	assert(string.find(builder, "local layerTop = -PLATEAU_DEPTH + 4 - k * LAYER_STEP", 1, true), "underside layers start below the plateau")
	local _, landingChecks = string.gsub(builder, "nearLanding%(angle, landings%)", "")
	assert(landingChecks >= 4, "rim rocks, lava, spires and crystals must all keep the landings open")
	assert(string.find(builder, "pcall(step.run, folder)", 1, true), "each build step is guarded")
	do
		-- Mirror the underside maths: nothing may rise above the surface.
		local plateauDepth, layerStep, layers = 12, 11, 6
		for k = 0, layers - 1 do
			local layerTop = -plateauDepth + 4 - k * layerStep
			assert(layerTop < 0, "underside layer " .. k .. " breaks the surface")
		end
		for _, region in regions do
			if region.Id == "Spire" then
				for k = 1, 6 do
					local r = region.Radius * (0.5 - 0.055 * k)
					assert(-plateauDepth - r - k * 14 + r < 0, "the Spire stem breaks the surface")
				end
			end
		end
	end

	-- Client.
	local main = readSource("src/Client/AstralForge/UiCore.luau#MainGame")
	assert(string.find(main, "sanctuarySignals.handles(kind)", 1, true), "MainGame must forward sanctuary effects to the bus")
	local presence = readSource("src/Client/AstralForge/SanctuaryKit.luau#sanctuaryPresence")
	assert(string.find(presence, "Controls.step(dt)", 1, true), "walking must run through sanctuaryControls")
	assert(string.find(presence, "World.start()", 1, true) and string.find(presence, "World.stop()", 1, true), "the world controller starts and stops with the visit")
	assert(string.find(presence, "Controls.stop()", 1, true), "leaving must release the controls")
	assert(not string.find(presence, "IsKeyDown(Enum.KeyCode.W)", 1, true), "the old WASD-only walker is gone")
	assert(string.find(presence, "effect:Destroy()", 1, true), "sanctuary post effects are removed on leave")
	local chrome = readSource("src/Client/AstralForge/UiCore.luau#sanctuaryChrome")
	assert(string.find(chrome, "createElement(SanctuaryHud", 1, true), "the curtain mounts the sanctuary HUD")
	local router = readSource("src/Client/AstralForge/pages/PageRouter.luau")
	local nav = readSource("src/Client/AstralForge/CoreKit.luau#navRouteTable")
	assert(string.find(router, 'lazyView("FoundryView", "FoundryView")', 1, true), "the Foundry page is routed")
	assert(string.find(nav, 'id = "Foundry"', 1, true) and string.find(nav, '"Foundry",', 1, true), "the Foundry is in the nav and the page table")

	-- Every sanctuary sound the client plays is a real cue.
	local audio = readSource("src/Client/AstralForge/AudioKit.luau#audio")
	local clientFiles = {
		"src/Client/AstralForge/SanctuaryKit.luau#sanctuaryWorld",
		"src/Client/AstralForge/SanctuaryKit.luau#sanctuaryHud",
	}
	for _, path in clientFiles do
		local source = readSource(path)
		for cue in string.gmatch(source, 'Audio:play%("(%w+)"%)') do
			assert(string.find(audio, "\t" .. cue .. " = ", 1, true) or string.find(audio, "\t[\"" .. cue .. "\"] = ", 1, true), `{path} plays unknown cue {cue}`)
		end
	end
end

print(
	string.format(
		"[INFO] [TEST] sanctuary world guards passed | %d regions, %d bridges, %d waystones, %d ore sites, %d upgrades",
		#regions,
		#bridges,
		#stones,
		#sites,
		#OreConfig.Upgrades
	)
)
