--!strict
-- Cue voicing for Astral Forge.
--
-- The whole game speaks through three sound files: a short hover blip, a click,
-- and a confirm chime. Every one of the ~176 cues aliases one of those, so
-- "purchase" and "menu click" were literally the same audio at slightly
-- different pitches. That is why the mix read as flat and repetitive.
--
-- This module gives each cue a FAMILY -- a role in the game's sound world -- and
-- each family a full voice: an EQ curve, a reverb space, optional drive, a pitch
-- offset and a decay length. Roblox applies those per Sound instance, so one
-- source file can be voiced as a dull thud, a glassy chime or a distant sweep.
-- That is where the variety comes from when new assets are not an option.
--
-- The forge fiction drives the choices. Metal and heat are low-mid and dry;
-- arcane/rift events are high, wide and reverberant; UI chrome is quiet, tight
-- and close so it never competes with the thing the player actually did.
--
-- Pure data + math: no Roblox instances are created here, so the whole voicing
-- table can be unit tested. audio.luau applies the numbers this returns.

export type Voice = {
	-- EqualizerSoundEffect gains, in dB. Valid range is -80..10.
	high: number,
	mid: number,
	low: number,
	-- ReverbSoundEffect. decay is seconds; wet 0..1 mixes the space in. A dry
	-- cue (wet 0) skips the effect entirely so close UI stays tight.
	reverbDecay: number,
	reverbWet: number,
	-- DistortionSoundEffect 0..1. Used sparingly -- a little adds weight and
	-- grit to forge impacts, a lot turns any source into noise.
	drive: number,
	-- Multiplied onto the cue's own PlaybackSpeed. This is the single biggest
	-- lever for making one file read as a different object.
	pitch: number,
	-- Multiplied onto the cue's stopAfter, so a family can ring out or be cut
	-- short without retuning every cue in it.
	decay: number,
	-- Trim in dB-ish linear terms, to balance families against each other.
	gain: number,
}

-- Layering is the other half of making three files sound like many. A cue with
-- a layer plays a second, quieter, pitch-shifted copy of a different source,
-- which reads as one richer sound rather than two sounds.
export type Layer = {
	-- Which of the three source roles to stack underneath: "hover", "click" or
	-- "confirm". Picking a different role from the cue's own is the point.
	source: string,
	pitch: number,
	volume: number,
	-- Seconds after the main hit. A few ms reads as body; too much is an echo.
	delay: number,
}

-- Declared with its shape up front: voiceFor calls familyOf, and an inferred
-- empty-table literal would not yet carry that member.
local Voicing = {} :: {
	familyOf: (string) -> string,
	voiceFor: (string) -> Voice,
	families: () -> { [string]: Voice },
	cueFamilies: () -> { [string]: string },
	clampGain: (number) -> number,
	layerFor: (string) -> Layer?,
	layers: () -> { [string]: Layer },
}

-- The families. Ordered roughly from most-frequent/quietest to rarest/loudest,
-- which is also the order they should sit in the mix.
local FAMILIES: { [string]: Voice } = {
	-- Pointer chrome. Barely there: high and thin, bone dry, short. It must
	-- survive being fired many times a second without building into a buzz.
	chrome = {
		high = 9, mid = -10, low = -24,
		reverbDecay = 0, reverbWet = 0,
		drive = 0, pitch = 1.34, decay = 0.55, gain = 0.72,
	},
	-- Committed UI: a click, a tab, a toggle. Present and mid-forward so it
	-- reads as a real press, still dry and close.
	interface = {
		high = 2, mid = 6, low = -6,
		reverbDecay = 0.4, reverbWet = 0.06,
		drive = 0, pitch = 1, decay = 1, gain = 1,
	},
	-- Panels and pages moving. Air and motion, a little space, no bottom end
	-- so it stays out of the way of gameplay sounds.
	motion = {
		high = 7, mid = -8, low = -12,
		reverbDecay = 1.1, reverbWet = 0.18,
		drive = 0, pitch = 0.94, decay = 1.35, gain = 0.88,
	},
	-- The forge itself: hammer, salvage, install. Low-mid weight plus a touch
	-- of drive so metal has grain. This is the game's signature texture.
	forge = {
		high = -6, mid = 4, low = 9,
		reverbDecay = 0.9, reverbWet = 0.14,
		drive = 0.22, pitch = 0.74, decay = 1.5, gain = 1.12,
	},
	-- Currency and value. Bright, glassy, quick -- coins and cut gems, not bells.
	currency = {
		high = 10, mid = 2, low = -14,
		reverbDecay = 0.8, reverbWet = 0.12,
		drive = 0, pitch = 1.46, decay = 0.9, gain = 1,
	},
	-- Rewards and unlocks. Full-range and open, the "yes" of the game.
	reward = {
		high = 8, mid = 5, low = -2,
		reverbDecay = 1.8, reverbWet = 0.26,
		drive = 0, pitch = 1.08, decay = 1.7, gain = 1.16,
	},
	-- Rift / domain / prestige. The biggest, widest, most reverberant voice,
	-- pitched down so it feels larger than anything else in the game.
	arcane = {
		high = 5, mid = -2, low = 6,
		reverbDecay = 3.2, reverbWet = 0.42,
		drive = 0.08, pitch = 0.66, decay = 2.2, gain = 1.2,
	},
	-- Reactor / anomaly ambience. Mid-scooped hum that sits under everything.
	reactor = {
		high = -4, mid = -6, low = 7,
		reverbDecay = 2.4, reverbWet = 0.3,
		drive = 0.12, pitch = 0.82, decay = 1.8, gain = 0.82,
	},
	-- Refusal. Dark and close with drive, so it reads as a blocked action
	-- rather than as a quieter version of success.
	denial = {
		high = -26, mid = -6, low = 8,
		reverbDecay = 0.3, reverbWet = 0.04,
		drive = 0.34, pitch = 0.58, decay = 1.2, gain = 1,
	},
	-- Warnings that are not refusals. Cuts through without being harsh.
	alert = {
		high = -10, mid = 6, low = 4,
		reverbDecay = 0.6, reverbWet = 0.1,
		drive = 0.14, pitch = 0.88, decay = 1.25, gain = 1.06,
	},
	-- Notices sliding in. Soft, airy, unobtrusive -- they interrupt, so they
	-- must not also be loud.
	notice = {
		high = 6, mid = 0, low = -8,
		reverbDecay = 1.3, reverbWet = 0.2,
		drive = 0, pitch = 1.12, decay = 1.1, gain = 0.9,
	},
	-- Boot / shutdown ceremony. Cinematic, but the forge's own ceremony: heavy
	-- and struck rather than otherworldly. Deliberately more driven and less
	-- reverberant than `arcane`, or the two read as the same event -- rift magic
	-- is wide and washed, the anvil is close and hit hard.
	ceremony = {
		high = 4, mid = 2, low = 10,
		reverbDecay = 2.2, reverbWet = 0.28,
		drive = 0.14, pitch = 0.62, decay = 2.4, gain = 1.14,
	},
	-- Spin / crate / gacha tension. Tight and mechanical, minimal tail so a
	-- fast tick sequence stays crisp.
	mechanism = {
		high = 8, mid = -4, low = -10,
		reverbDecay = 0.35, reverbWet = 0.05,
		drive = 0.06, pitch = 1.22, decay = 0.6, gain = 0.86,
	},
	-- Social: chat, crew, guild. Warm and human, mid-forward, close. Deliberately
	-- the nearest neighbour to `interface` -- a chat ping should read as a warmer
	-- cousin of a click, not as a different world -- but lifted in pitch and
	-- softened in level so it never gets mistaken for the player's own press.
	social = {
		high = 5, mid = 8, low = -6,
		reverbDecay = 0.7, reverbWet = 0.11,
		drive = 0, pitch = 1.26, decay = 0.9, gain = 0.8,
	},
}

-- Cue -> family. Anything unlisted falls back to "interface", which is the
-- safest neutral voice.
local CUE_FAMILY: { [string]: string } = {}

local function assign(family: string, cues: { string })
	for _, cue in cues do
		CUE_FAMILY[cue] = family
	end
end

assign("chrome", {
	"hover", "hoverTick", "scroll", "tick", "sliderStep", "filterPick",
	"amountChange", "cardDraw", "storyPage", "wheelTick", "crateTick",
	"navHover", "sanctuaryHover",
})

assign("interface", {
	"click", "confirm", "settings", "toggleOn", "toggleOff", "sliderCommit",
	"inputFocus", "inputClear", "claimPress", "equip", "itemLink", "itemUnlink",
	"cardBlock", "playerlistSelect", "playerlistAction", "roleChange",
	"tutorialStep", "codeSubmit", "machineInstall", "mailRead",
	"sanctuaryClick",
})

assign("motion", {
	"page", "tabSwitch", "open", "close", "modalOpen", "modalPop", "modalDismiss",
	"filterOpen", "travel", "preview", "velocitySlide", "mail", "playerlistOpen",
	"playerlistClose", "purchaseExit", "zoneSelect", "expeditionLaunch",
	"expeditionReturn", "boostOpen", "cardPlay", "gameExit",
	"waystoneTravel",
})

assign("forge", {
	"salvage", "salvageCrunch", "reset", "memberRemove", "adminArm",
	"adminExecute", "cardEndTurn", "echoDismantle", "labRoute", "autoForge",
	"oreMine", "wardenStrike", "wardenCrit",
})

assign("currency", {
	"purchase", "purchasePress", "purchaseResult", "vaultBank", "vaultDeposit",
	"guildDeposit", "guildCreate", "collect", "coin",
})

assign("reward", {
	"reward", "unlock", "successChime", "dailyClaim", "timedClaim",
	"seasonClaim", "missionClaim", "achievementClaim", "mailClaim", "codeReward",
	"tutorialFinish", "discovery", "researchUnlock", "zoneUnlock", "puzzleClear",
	"comboMilestone", "offlineCollect", "offlineOpen", "crateClaim", "crateRare",
	"wheelLand", "crateLand", "echoClaim", "oreCollect",
})

assign("arcane", {
	"prestige", "rebirthCharge", "rebirthBloom", "domainCharge", "domainCrack",
	"domainImpact", "domainReward", "domainBind", "echoCapture", "echoTune",
	"echoEquip", "cardPower", "storyReveal",
	"wardenForming", "wardenAwake", "wardenSlamCharge", "wardenSlam",
	"wardenDefeat", "wardenEscape",
})

assign("reactor", {
	"reactor", "reactorReady", "reactorPulse", "reactorChannel",
	"reactorStabilize", "reactorSurge", "cardEnergy",
})

assign("denial", {
	"error", "errorBuzz", "noticeError", "requestTimeout", "requestBlocked",
	"locked", "dangerPress",
})

assign("alert", {
	"noticeWarning", "systemAlert", "gamePause",
})

assign("notice", {
	"notification", "noticeInfo", "noticeSuccess", "noticeSpecial", "noticeClose",
	"gameResume", "boostReady", "boostActivate", "queueStart", "queueStop",
	"regionEnter",
})

assign("ceremony", {
	"boot", "bootStart", "bootIgnite", "bootTension", "bootWhoosh", "bootStrike",
	"bootClang", "bootSpark", "bootFizz", "bootRumble", "bootImpact", "bootReady",
	"bootFinaleFlip", "bootFinaleBang", "bootAnvilSplit", "bootSlamCharge",
	"bootSlamAir", "bootDebris", "bootFractureTail", "bootGravity",
	"bootAftershock", "storyOpen", "story", "storyBeat",
})

assign("mechanism", {
	"wheelStart", "wheelCharge", "wheelSlow", "wheelBrake", "crateOpen",
	"crateCharge", "crateNear", "crateBrake", "puzzleTap", "leaderboardSwitch",
})

assign("social", {
	"chatSend", "chatReceive", "invite", "crewNudge", "guildJoin", "guildLeave",
})

local NEUTRAL: Voice = FAMILIES.interface

function Voicing.familyOf(cue: string): string
	return CUE_FAMILY[cue] or "interface"
end

function Voicing.voiceFor(cue: string): Voice
	return FAMILIES[Voicing.familyOf(cue)] or NEUTRAL
end

function Voicing.families(): { [string]: Voice }
	return FAMILIES
end

function Voicing.cueFamilies(): { [string]: string }
	return CUE_FAMILY
end

-- EqualizerSoundEffect accepts -80..10. Clamp rather than trusting the table,
-- so a future edit cannot silently push a gain out of range and get ignored.
function Voicing.clampGain(value: number): number
	return math.clamp(value, -80, 10)
end

-- Only the moments that deserve weight get a layer -- layering everything just
-- doubles the voice count for no added richness.
local LAYERS: { [string]: Layer } = {
	-- Rift events get a deep body under the transient.
	domainImpact = { source = "click", pitch = 0.42, volume = 0.5, delay = 0.012 },
	domainCharge = { source = "confirm", pitch = 0.5, volume = 0.42, delay = 0.03 },
	domainReward = { source = "confirm", pitch = 1.5, volume = 0.34, delay = 0.05 },
	prestige = { source = "click", pitch = 0.46, volume = 0.46, delay = 0.015 },
	rebirthBloom = { source = "confirm", pitch = 1.42, volume = 0.38, delay = 0.045 },
	-- Big rewards get a bright shimmer on top.
	reward = { source = "hover", pitch = 1.62, volume = 0.3, delay = 0.04 },
	achievementClaim = { source = "hover", pitch = 1.55, volume = 0.3, delay = 0.045 },
	seasonClaim = { source = "hover", pitch = 1.48, volume = 0.32, delay = 0.05 },
	crateRare = { source = "hover", pitch = 1.7, volume = 0.34, delay = 0.035 },
	zoneUnlock = { source = "confirm", pitch = 1.34, volume = 0.3, delay = 0.05 },
	-- Forge work gets a low thud beneath the grain.
	salvageCrunch = { source = "click", pitch = 0.5, volume = 0.4, delay = 0.01 },
	adminExecute = { source = "click", pitch = 0.44, volume = 0.38, delay = 0.012 },
	-- Money should sound like more than one coin.
	purchaseResult = { source = "hover", pitch = 1.66, volume = 0.26, delay = 0.03 },
	vaultDeposit = { source = "hover", pitch = 1.58, volume = 0.26, delay = 0.028 },
	-- Denial lands twice: the block, then the drop.
	error = { source = "click", pitch = 0.4, volume = 0.36, delay = 0.02 },
	requestTimeout = { source = "click", pitch = 0.38, volume = 0.34, delay = 0.025 },
	-- Ceremony beats.
	bootFinaleBang = { source = "click", pitch = 0.4, volume = 0.5, delay = 0.014 },
	bootImpact = { source = "click", pitch = 0.48, volume = 0.44, delay = 0.012 },
	-- The Warden's big beats get the same weight as the rift's.
	wardenSlam = { source = "click", pitch = 0.4, volume = 0.5, delay = 0.012 },
	wardenDefeat = { source = "confirm", pitch = 1.46, volume = 0.36, delay = 0.05 },
	wardenCrit = { source = "hover", pitch = 1.6, volume = 0.28, delay = 0.03 },
}

function Voicing.layerFor(cue: string): Layer?
	return LAYERS[cue]
end

function Voicing.layers(): { [string]: Layer }
	return LAYERS
end

return Voicing
