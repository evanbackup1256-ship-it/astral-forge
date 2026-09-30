--!strict
-- Guards for the sanctuary rift curtain and the sanctuary map.
--
-- What these lock in:
--   1. LayoutGuardIgnore is an attribute, not a property. Passing it as a React
--      prop makes the renderer assign a real member and throw at mount.
--   2. The curtain has no delay. It opens on the press itself (not after the
--      server round-trip), nothing in it waits on a timer, and the halves are
--      visibly moving on the very first frame.
--   3. Both halves ride one spring, clear the screen completely, and move
--      monotonically, so nothing snaps backwards or parks on screen.
--   4. The shatter transition is gone for good.
--   5. Every walkable surface of the forge deck lies inside the arrival radius,
--      so a player placed anywhere on it counts as arrived; beyond the deck,
--      the controls follow anywhere inside SanctuaryLayout's world bounds
--      (scripts/verify_sanctuary_world.luau covers the wider map).
--
-- HARD: pure math and string checks -- no Roblox instances, no vendor requires.

local fs = require("./_memberfs")(require("@lune/fs"))

local Curtain = require("../src/Client/AstralForge/SanctuaryKit")("curtainTransition")

-- Normalise line endings: the sources are checked out with CRLF on Windows and
-- the function-isolating patterns below anchor on "\n".
local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local uiSource = readSource("src/Client/AstralForge/UiCore.luau#ui")
local chromeSource = readSource("src/Client/AstralForge/UiCore.luau#sanctuaryChrome")
local shellSource = readSource("src/Client/AstralForge/UiCore.luau#AppShellChrome")
local presenceSource = readSource("src/Client/AstralForge/SanctuaryKit.luau#sanctuaryPresence")
local worldSource = readSource("src/Server/AstralForge/Services/WorldServices.luau#WorldService")

------------------------------------------------------------------------
-- 1. LayoutGuardIgnore must never be a React prop
------------------------------------------------------------------------
assert(
	not string.find(uiSource, "\n\t\tLayoutGuardIgnore = ", 1, true),
	"LayoutGuardIgnore passed as a React prop -- it is an attribute, set it via a ref"
)
assert(
	string.find(uiSource, "pinLayoutGuardIgnore", 1, true),
	"the ref helper that sets the LayoutGuardIgnore attribute is missing"
)
assert(
	string.find(uiSource, 'instance:SetAttribute("LayoutGuardIgnore", true)', 1, true),
	"LayoutGuardIgnore must be applied with SetAttribute"
)

------------------------------------------------------------------------
-- 2. No delay: the curtain answers the press, and nothing in it waits
------------------------------------------------------------------------
-- `riftOpen` only turns true after EnterSanctuary round-trips, the area streams
-- in and the character lands on the deck. Driving the curtain from it is what
-- made opening feel late; it may only lift the veil.
assert(string.find(shellSource, "open = sanctuaryOpen,", 1, true), "the curtain must open on sanctuaryOpen (the press)")
assert(string.find(shellSource, "ready = riftOpen,", 1, true), "riftOpen must only drive the veil (`ready`)")
assert(not string.find(shellSource, "open = riftOpen", 1, true), "the curtain must not wait for the world to load")

local curtainBody = string.match(chromeSource, "local function SplitCurtain%(props%)(.-)\nend\n")
assert(curtainBody ~= nil, "could not isolate SplitCurtain")
for _, waiter in { "task.delay", "task.wait", "task.defer", "task.spawn" } do
	assert(
		not string.find(curtainBody :: string, waiter, 1, true),
		"SplitCurtain must not schedule its motion (" .. waiter .. ") -- the curtain has no hold"
	)
end
-- `split` is derived in render, so the halves exist on the frame `open` flips.
assert(string.find(curtainBody :: string, "local split = open or not closedAtRest", 1, true), "split must be derived in render")
-- Motion is a render-synced tween started straight from the layout effect.
assert(string.find(chromeSource, "RunService.RenderStepped:Connect", 1, true), "the curtain must be driven on RenderStepped")
assert(string.find(curtainBody :: string, "useCurtainTravel(open", 1, true), "the halves must ride the curtain tween")
assert(not string.find(chromeSource, "Opening the rift", 1, true), "the veil must stay plain -- no leftover text behind the halves")

------------------------------------------------------------------------
-- 3. One tween, both halves, full clearance, no overshoot
------------------------------------------------------------------------
assert(
	not string.find(curtainBody :: string, "leftTravel", 1, true) and not string.find(curtainBody :: string, "rightTravel", 1, true),
	"both halves must ride one travel value -- no per-side motion, no stagger"
)
local _, travelMaps = string.gsub(curtainBody :: string, "travel:map%(function%(value%)\n\t\treturn UDim2.fromScale%(", "")
assert(travelMaps == 2, "left and right halves must both map the same travel binding, got " .. tostring(travelMaps))
assert(string.find(curtainBody :: string, "muteClone(copy)", 1, true), "the right-half snapshot must be muted")

-- Curves.
assert(Curtain.shift(0) == 0, "a closed curtain must not be offset")
assert(Curtain.shift(1) >= 0.5, "each half must travel at least its own width to clear the screen")
local previous = -1
for step = 0, 50 do
	local value = Curtain.shift(step / 50)
	assert(value >= previous, "curtain travel must be monotonic")
	previous = value
end
assert(Curtain.shift(1.4) == Curtain.shift(1), "travel past 1 must not push the halves further")
assert(Curtain.shift(-0.2) == 0, "travel below 0 must not cross the halves over")
assert(Curtain.rimTransparency(0) < 0.5, "the rim must be lit as the seam parts")
assert(Curtain.rimTransparency(1) >= 0.99, "the rim must be gone once the halves are away")
assert(Curtain.shadeTransparency(0) == 1, "a shut curtain must not be dimmed")
assert(Curtain.veilTransparency(1) == 0, "the veil must fully cover the world while the sanctuary loads")
assert(Curtain.veilTransparency(0) == 1, "the veil must fully clear once the sanctuary is ready")

-- Easing: exact endpoints, never past them, always forward.
for _, ease in { Curtain.easeOpen, Curtain.easeClose } do
	assert(ease(0) == 0 and ease(1) == 1, "easing must span exactly 0..1")
	local last = 0
	for step = 1, 200 do
		local value = ease(step / 200)
		assert(value >= last - 1e-12 and value <= 1, "easing must be monotonic and never overshoot")
		last = value
	end
end

-- Timing model: sample the tween at 60 fps exactly as the RenderStepped driver does.
local FRAME = 1 / 60
local function simulate(from: number, to: number, reduced: boolean): (number, number, number)
	local seconds = Curtain.duration(to > from, math.abs(to - from), reduced)
	local firstFrameShift = math.abs(Curtain.shift(Curtain.sample(from, to, FRAME, seconds)) - Curtain.shift(from))
	local clearAt = math.huge
	local frame = 0
	while frame * FRAME < seconds + FRAME do
		frame += 1
		local shift = Curtain.shift(Curtain.sample(from, to, frame * FRAME, seconds))
		if to > from and shift >= 0.5 and clearAt == math.huge then
			clearAt = frame * FRAME
		end
	end
	return firstFrameShift, clearAt, seconds
end

local firstShift, clearSeconds, openSeconds = simulate(0, 1, false)
-- 1% of the screen width is ~19px at 1080p: visible motion on the first frame.
assert(firstShift >= 0.01, string.format("the halves must visibly move on the first frame (moved %.4f)", firstShift))
assert(clearSeconds <= 0.35, string.format("the halves must clear the screen within 0.35s (took %.3fs)", clearSeconds))
assert(Curtain.sample(0, 1, openSeconds, openSeconds) == 1, "an open run must land exactly on 1")
local reducedFirst, reducedClear = simulate(0, 1, true)
assert(reducedClear <= clearSeconds, "reduced motion must not be slower than the full curtain")
assert(reducedFirst >= firstShift, "reduced motion must not start slower than the full curtain")

-- Closing meets softly: the last frame of travel is a small fraction of the first half-second's.
local closeSeconds = Curtain.duration(false, 1, false)
local lastStep = Curtain.sample(1, 0, closeSeconds - FRAME, closeSeconds) - Curtain.sample(1, 0, closeSeconds, closeSeconds)
assert(Curtain.sample(1, 0, closeSeconds, closeSeconds) == 0, "a close run must land exactly on 0")
assert(lastStep < 0.01, string.format("the halves must meet softly (last frame moved %.4f)", lastStep))

-- A stalled frame never leaps: a 150 ms hitch on the second frame advances the
-- curtain no further than a normal (capped) frame would.
do
	local seconds = Curtain.duration(true, 1, false)
	local steady = Curtain.advance(0, 1 / 60)
	local hitched = Curtain.advance(0, 0.15)
	assert(hitched <= Curtain.MAX_FRAME_STEP + 1e-9, "a long frame is capped")
	local jump = Curtain.shift(Curtain.sample(0, 1, hitched, seconds))
	assert(jump <= 0.09, string.format("a hitch at the start moves the halves at most %.3f of the screen (was %.3f)", 0.09, jump))
	assert(steady <= hitched, "normal frames advance normally")
	local body = string.match(chromeSource, "local function useCurtainTravel(.-)\nend\n") or ""
	assert(string.find(body, "Curtain.advance(elapsed :: number, dt)", 1, true), "the curtain clock advances by capped frame deltas")
	assert(not string.find(body, "os.clock()", 1, true), "the curtain no longer samples the wall clock")
end
-- While the veil covers the world, 3D isn't drawn; it always comes back.
assert(string.find(curtainBody :: string, "local coverWorld = split and not (open and ready)", 1, true), "3D pauses only while the veil covers the world")
assert(string.find(curtainBody :: string, "RunService:Set3dRenderingEnabled(not coverWorld)", 1, true), "the curtain pauses 3D rendering under the veil")
assert(string.find(curtainBody :: string, "RunService:Set3dRenderingEnabled(true)", 1, true), "3D rendering is restored when the curtain goes")
-- The sanctuary's loading starts after the halves have their head start.
assert(string.find(shellSource, "SanctuaryPresence.enterSoon(call", 1, true), "the shell enters the sanctuary behind the curtain")
assert(string.find(presenceSource, "task.delay(Curtain.LOAD_HEAD_START", 1, true), "entry waits for the curtain's head start")
assert(Curtain.LOAD_HEAD_START < Curtain.OPEN_SECONDS, "loading still begins before the curtain finishes")
-- Reversing mid-run continues from where the halves are: no jump.
local midway = Curtain.sample(0, 1, 0.1, openSeconds)
local reverseSeconds = Curtain.duration(false, midway, false)
assert(Curtain.sample(midway, 0, 0, reverseSeconds) == midway, "a reversal must start from the current travel")
------------------------------------------------------------------------
-- 4. The shatter transition is gone
------------------------------------------------------------------------
assert(not fs.isFile("src/Client/AstralForge/shatterTransition.luau"), "shatterTransition.luau should be deleted")
for _, leftover in { "Shatter", "shatterTransition", "shardHost", "impactFlash", "IMPACT_SECONDS" } do
	assert(not string.find(chromeSource, leftover, 1, true), "shatter leftover in sanctuaryChrome: " .. leftover)
end

------------------------------------------------------------------------
-- 5. The forge deck fits inside the arrival radius
------------------------------------------------------------------------
local radiusText = string.match(presenceSource, "local DECK_RADIUS = (%d+)")
assert(radiusText ~= nil, "DECK_RADIUS not found in sanctuaryPresence")
local deckRadius = tonumber(radiusText) :: number

-- Spawn sits on the first causeway slab; these mirror buildSanctuary's literals.
local spawnX, spawnY, spawnZ = 0, 3.3, 30
local walkable = {
	{ "CausewayStart", 0, 0, 30 },
	{ "CausewayC", -1.4, 0.85, 8 },
	{ "Terrace", 0, 1.2, -3 },
	{ "TerraceWest", -20, 1.2, -2 },
	{ "TerraceEast", 20, 1.2, -4 },
	{ "OverlookWest", -28.5, 0.9, 2 },
	{ "OverlookEast", 28, 0.9, -9 },
	{ "Dais", 0, 4.2, -16 },
	{ "Altar", 0, 6.7, -17 },
	{ "StoneRingFar", 0.5, 13.7, -22.8 },
	{ "DriftEast", 11.5, -1.2, 18 },
	{ "DriftWest", -11.8, -2.4, 12.5 },
}
local furthest = 0
for _, entry in walkable do
	local dx = (entry[2] :: number) - spawnX
	local dy = (entry[3] :: number) - spawnY
	local dz = (entry[4] :: number) - spawnZ
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	furthest = math.max(furthest, distance)
	assert(
		distance <= deckRadius,
		string.format(
			"%s sits %.1f studs from spawn, outside DECK_RADIUS %d -- arriving there would not count",
			tostring(entry[1]),
			distance,
			deckRadius
		)
	)
end
-- Keep real headroom rather than hugging the limit, so a later tweak to the map
-- does not silently push a corner outside the radius.
assert(
	deckRadius - furthest >= 8,
	string.format("only %.1f studs of arrival headroom left", deckRadius - furthest)
)

-- Once walking, following is bounded by the world, not the deck.
assert(string.find(presenceSource, "SanctuaryLayout.inBounds(", 1, true), "re-following must use the world bounds")

-- The contract sanctuaryPresence and WorldService rely on must survive.
assert(string.find(worldSource, '"Sanctuary"', 1, true), "the Sanctuary model name must not change")
assert(
	string.find(worldSource, '"SpawnLocation", "Spawn"', 1, true),
	"the Spawn part must stay a SpawnLocation named Spawn"
)
assert(
	string.find(worldSource, 'prompt.Name = "SanctuaryClose"', 1, true),
	"the SanctuaryClose prompt is how the player leaves"
)
assert(
	string.find(worldSource, "return spawn.CFrame, SANCTUARY_ORIGIN.Y", 1, true),
	"buildSanctuary must still return (spawn CFrame, origin Y)"
)

print(
	string.format(
		"[INFO] [TEST] curtain + sanctuary guards passed | first frame moves %.1f%% of the screen, clear in %.0fms (reduced %.0fms), map furthest=%.1f/%d studs",
		firstShift * 100,
		clearSeconds * 1000,
		reducedClear * 1000,
		furthest,
		deckRadius
	)
)
