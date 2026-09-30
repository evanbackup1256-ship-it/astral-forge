--!strict
-- Audio voice-management guards.
--
-- Evidence this locks in, in the order the bugs bite:
--   1. A channel is reserved the instant it starts. Roblox does not flip
--      Sound.IsPlaying synchronously on :Play(), and busyUntil is only filled in
--      later by the release pump (it needs TimeLength, which is 0 until the asset
--      loads). Without a claim, two cues in one frame both saw the channel idle
--      and the second restarted the first -- the doubled attack players heard as
--      "stacking".
--   2. The voice cap applies to more than "hover". It used to read
--      `liveVoices >= VOICE_CAP and cue == "hover"`, so every other cue stacked
--      without limit.
--   3. The UI overlap cap drains to the cap instead of silencing one voice.
--   4. Cue table hygiene: no duplicate keys (a duplicate silently wins and the
--      earlier tuning is dead), and every cue's asset is a real manifest entry.
--
-- HARD: pure string/model checks only -- no Roblox instances, no vendor requires.

local fs = require("./_memberfs")(require("@lune/fs"))

local audioSource = fs.readFile("src/Client/AstralForge/AudioKit.luau#audio")
local musicSource = fs.readFile("src/Client/AstralForge/AudioKit.luau#musicDirector")

------------------------------------------------------------------------
-- 0. Roblox attributes must never be passed as React props
--
-- The React renderer assigns every key in a props table as a real Instance
-- member, so an attribute name there throws at mount. This shipped twice --
-- LayoutGuardIgnore on a dock ImageButton, LayoutGuardAllowDisabledScroll on
-- the virtualized list's ScrollingFrame -- each spamming the console on every
-- mount. Attributes go through a ref that calls SetAttribute.
------------------------------------------------------------------------
do
	local ATTRIBUTE_NAMES = { "LayoutGuardIgnore", "LayoutGuardAllowDisabledScroll" }
	local clientFiles = {
		"src/Client/AstralForge/UiCore.luau#ui",
		"src/Client/AstralForge/LayoutKit.luau#virtualizedList",
		"src/Client/AstralForge/UiCore.luau#sanctuaryChrome",
		"src/Client/AstralForge/LayoutKit.luau#pageScaffold",
		"src/Client/AstralForge/LayoutKit.luau#scrolling",
	}
	for _, path in clientFiles do
		if not fs.isFile(path) then
			continue
		end
		local body = fs.readFile(path)
		for _, attribute in ATTRIBUTE_NAMES do
			-- A props-table entry looks like `\n\t\tName = true,` or
			-- `_attributes.Name = true`. A ref-based SetAttribute never does.
			assert(
				not string.find(body, "\n\t\t" .. attribute .. " = ", 1, true)
					and not string.find(body, "_attributes." .. attribute .. " = ", 1, true),
				path
					.. " passes "
					.. attribute
					.. " as a React prop -- it is an attribute, set it with SetAttribute in a ref"
			)
		end
	end
	-- The virtualized list's embedded frame still has to opt out of the guard's
	-- disabled-scroll repair, just through the ref rather than a prop.
	local listSource = fs.readFile("src/Client/AstralForge/LayoutKit.luau#virtualizedList")
	assert(
		string.find(listSource, 'SetAttribute("LayoutGuardAllowDisabledScroll"', 1, true),
		"the embedded list must still mark its disabled scroll as deliberate"
	)
end

------------------------------------------------------------------------
-- 1. Channel claim exists and is wired at play time
------------------------------------------------------------------------
assert(
	string.find(audioSource, "CHANNEL_CLAIM_SECONDS", 1, true),
	"CHANNEL_CLAIM_SECONDS constant missing"
)
assert(
	string.find(audioSource, "self.claimedUntil[channel] = now + CHANNEL_CLAIM_SECONDS", 1, true),
	"channel must be claimed immediately after a successful :Play()"
)
assert(
	string.find(audioSource, "self.claimedUntil = {}", 1, true),
	"claimedUntil must be initialised in the constructor"
)
assert(
	string.find(audioSource, "table.clear(self.claimedUntil)", 1, true),
	"claimedUntil must be cleared on dispose"
)
-- acquireChannel must consult the claim, not IsPlaying/busyUntil alone.
assert(
	string.find(audioSource, "and busyUntil <= now and claimedUntil <= now then", 1, true),
	"acquireChannel must treat a claimed channel as unavailable"
)

------------------------------------------------------------------------
-- 2. The voice cap is no longer hover-only
------------------------------------------------------------------------
assert(
	not string.find(audioSource, 'liveVoices >= VOICE_CAP and cue == "hover"', 1, true),
	"voice cap must not be restricted to the hover cue"
)
assert(
	string.find(audioSource, "if liveVoices >= VOICE_CAP and not bypassCooldown then", 1, true),
	"voice cap must apply to decorative cues generally"
)

------------------------------------------------------------------------
-- 3. UI overlap drains to the cap
------------------------------------------------------------------------
assert(
	string.find(audioSource, "while self:countPlayingUi() >= UI_OVERLAP_CAP", 1, true),
	"UI overlap must drain down to the cap, not silence a single voice"
)

------------------------------------------------------------------------
-- 4. Duplicate-cue (flam) guard
------------------------------------------------------------------------
assert(
	string.find(audioSource, "DUPLICATE_CUE_SECONDS", 1, true),
	"DUPLICATE_CUE_SECONDS guard missing"
)
-- The guard is global (keyed on the cue's own last-played stamp), not per
-- channel: with a deep pool, simultaneous identical cues would otherwise land on
-- different channels and still stack.
assert(
	string.find(audioSource, "if not bypassCooldown and now - previous < DUPLICATE_CUE_SECONDS then", 1, true),
	"identical cues fired in the same instant must be coalesced"
)
-- Deliberate layering must stay exempt, or celebrations would lose voices.
assert(
	string.find(audioSource, "firedFirst = self:playChannel(cue, true, pitchLift)", 1, true),
	"playCelebration's lead cue must bypass the coalesce window"
)
assert(
	string.find(audioSource, "self:playChannel(item.cue, true, item.pitch)", 1, true),
	"queued celebration cues must bypass the coalesce window"
)

------------------------------------------------------------------------
-- 5. Cue table hygiene: unique keys, real assets
------------------------------------------------------------------------
local cueBlock = string.match(audioSource, "local CUES = {(.-)\nlocal UI_CUES")
assert(cueBlock ~= nil, "could not isolate the CUES table")

local seen: { [string]: boolean } = {}
local cueCount = 0
for key in string.gmatch(cueBlock :: string, "\n\t([%a][%w]*) = {") do
	assert(not seen[key], "duplicate cue key: " .. key .. " (the later copy silently wins)")
	seen[key] = true
	cueCount += 1
end
assert(cueCount > 150, "expected the full cue table, got " .. tostring(cueCount))
assert(seen.tabSwitch, "tabSwitch cue should still exist")
assert(seen.click and seen.hover and seen.confirm, "core cues missing")

-- Every cue's asset must resolve to one of the declared aliases.
local aliases: { [string]: boolean } = {}
for name in string.gmatch(audioSource, "\nlocal (UI_[%u_]+) = ") do
	aliases[name] = true
end
for name in string.gmatch(audioSource, "\nlocal (SFX_[%u%d_]+) = ") do
	aliases[name] = true
end
local assetRefs = 0
for asset in string.gmatch(cueBlock :: string, "asset = ([%u][%w_]*)") do
	assert(aliases[asset], "cue references unknown asset alias: " .. asset)
	assetRefs += 1
end
assert(assetRefs == cueCount, "every cue must declare an asset: " .. tostring(assetRefs) .. "/" .. tostring(cueCount))

------------------------------------------------------------------------
-- 6. Music sequencing (one soundtrack, no per-view beds) is covered by
--    scripts/verify_soundtrack.luau. The old guard here -- a superseded deck
--    restarting under the live one -- cannot happen any more: a single worker
--    thread owns which track plays on which deck.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- 7. Music must be audible at startup
--
-- Settings load before the mixer starts, so masterLinear / musicEnabled can
-- already differ from the director's constructor defaults. start() only called
-- director:setMix(musicMix), which no-ops when musicMix is still 1 (the
-- director also starts at 1) -- so setAudible never ran and the music could
-- stay silent, or claim to be audible while the master was muted.
------------------------------------------------------------------------
do
	local startBody = string.match(audioSource, "function Mixer:start%(%)(.-)\n\tend")
	assert(startBody ~= nil, "could not isolate Mixer:start")
	assert(
		string.find(startBody :: string, "self:syncMusicState()", 1, true),
		"Mixer:start must push live music state to the director once it exists"
	)
	-- Ordering matters: the director has to exist before the sync.
	local assignAt = string.find(startBody :: string, "self.musicDirector = musicDirector", 1, true)
	local syncAt = string.find(startBody :: string, "self:syncMusicState()", 1, true)
	assert(assignAt ~= nil and syncAt ~= nil, "start must assign the director and sync")
	assert(
		(syncAt :: number) > (assignAt :: number),
		"syncMusicState must run after self.musicDirector is assigned, or it no-ops"
	)
end

-- The no-op that made the bug invisible: a same-value setMix returns early.
assert(
	string.find(musicSource, "if math.abs(nextMix - self.mix) <= 0.0005 then", 1, true),
	"setMix's same-value guard is what makes the startup sync necessary"
)

-- Behavioural model of that startup ordering.
do
	local function simulateStart(syncAfterStart: boolean, masterLinear: number): (boolean, boolean)
		-- The director as constructed: mix 1, duck 1, audible true.
		local mix, duck, audible = 1, 1, true
		local musicMix, musicEnabled = 1, true
		-- start() only ever called setMix(musicMix), which no-ops at the same value.
		if math.abs(musicMix - mix) > 0.0005 then
			mix = musicMix
		end
		if syncAfterStart then
			audible = musicEnabled and masterLinear > 0.001 and musicMix > 0.001
		end
		return audible, (audible and mix * duck > 0.001) == true
	end

	-- Muted master: the old path wrongly reported audible.
	local staleAudible = simulateStart(false, 0)
	local syncedAudible = simulateStart(true, 0)
	assert(staleAudible == true, "the model must reproduce the stale audible flag")
	assert(syncedAudible == false, "syncing must apply the real audibility")

	-- Normal case: master and music both up, the beds must actually play.
	local _, playing = simulateStart(true, 0.75)
	assert(playing, "music must play when master and music volume are both up")
end

------------------------------------------------------------------------
-- Behavioural model: the same-frame double-acquire that caused stacking.
-- Mirrors acquireChannel's free-channel scan against a Sound whose IsPlaying
-- lags a frame behind :Play(), which is what Roblox actually does.
------------------------------------------------------------------------
type Channel = { isPlaying: boolean, starts: number }

local function simulate(useClaim: boolean): (number, number)
	local now = 0
	local pool: { Channel } = {}
	local busyUntil: { [number]: number } = {}
	local claimedUntil: { [number]: number } = {}
	for i = 1, 4 do
		pool[i] = { isPlaying = false, starts = 0 }
		busyUntil[i] = 0
		claimedUntil[i] = 0
	end

	local function acquire(): number?
		for i, channel in pool do
			local claimed = if useClaim then claimedUntil[i] > now else false
			if not channel.isPlaying and busyUntil[i] <= now and not claimed then
				return i
			end
		end
		return nil
	end

	local restarts = 0
	local distinct: { [number]: boolean } = {}
	-- Four cues fired inside one frame, before any IsPlaying has flipped.
	for _ = 1, 4 do
		local index = acquire()
		if index ~= nil then
			local channel = pool[index]
			if channel.starts > 0 then
				-- Re-grabbing a channel already started this frame restarts it on
				-- top of itself: the audible "stack".
				restarts += 1
			end
			channel.starts += 1
			distinct[index] = true
			claimedUntil[index] = now + 0.05
		end
	end
	local used = 0
	for _ in distinct do
		used += 1
	end
	return restarts, used
end

local oldRestarts, oldUsed = simulate(false)
local newRestarts, newUsed = simulate(true)

assert(oldRestarts > 0, "the model must reproduce the old same-frame restart bug")
assert(oldUsed == 1, "without a claim every cue lands on channel 1, got " .. tostring(oldUsed))
assert(newRestarts == 0, "with the claim no channel is restarted on top of itself")
assert(newUsed == 4, "with the claim the burst spreads across the pool, got " .. tostring(newUsed))

------------------------------------------------------------------------
-- Behavioural model: the notice pile-up. Several notice cards mounting from a
-- single server update each play their tone cue in the same instant.
------------------------------------------------------------------------
local DUPLICATE_WINDOW = 0.035

local function coalesce(times: { number }, bypass: boolean): number
	local lastPlayed: number? = nil
	local voices = 0
	for _, at in times do
		local previous = lastPlayed
		if not bypass and previous ~= nil and at - previous < DUPLICATE_WINDOW then
			continue
		end
		lastPlayed = at
		voices += 1
	end
	return voices
end

-- Five notices mounting in one frame: one voice, not five stacked copies.
local burst = { 0, 0.0005, 0.001, 0.0015, 0.002 }
assert(coalesce(burst, false) == 1, "a same-frame notice burst must collapse to one voice")
assert(coalesce(burst, true) == 5, "bypass must keep every voice")

-- Cues spaced beyond the window are distinct feedback and must all play.
local spaced = { 0, 0.07, 0.14, 0.21 }
assert(coalesce(spaced, false) == 4, "deliberately spaced cues must not be coalesced")

-- A celebration's stagger (0.07s) sits above the window either way.
local celebration = { 0, 0.07, 0.14 }
assert(coalesce(celebration, false) == 3, "celebration stagger must clear the window")

print(
	string.format(
		"[INFO] [TEST] audio voice guards passed | cues=%d unique, same-frame burst: restarts %d->%d, voices %d->%d, notice pile-up 5->%d",
		cueCount,
		oldRestarts,
		newRestarts,
		oldUsed,
		newUsed,
		coalesce(burst, false)
	)
)
