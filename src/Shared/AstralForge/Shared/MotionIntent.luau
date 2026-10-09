--!strict
-- Decides *how* something should move from *what* it is.
-- Callers describe the element (role, rarity, tone, emphasis) and the
-- device budget; the resolver returns one coherent motion plan so every
-- surface of the same kind feels the same without hand-tuned springs.

export type Spring = { stiffness: number, damping: number }

export type Plan = {
	role: string,
	style: string,
	enter: Spring,
	exit: Spring,
	hover: Spring,
	press: Spring,
	travel: number,
	scaleFrom: number,
	overshoot: number,
	stagger: number,
	flashSeconds: number,
	shake: number,
	particles: number,
	glow: number,
	cue: string?,
	celebrate: boolean,
	weight: number,
	reduced: boolean,
}

export type Request = {
	role: string?,
	name: string?,
	rarity: string?,
	tone: string?,
	emphasis: number?,
	reduced: boolean?,
	tier: number?,
	particleBudget: number?,
	glowScale: number?,
	allowConfetti: boolean?,
}

type RoleSpec = {
	style: string,
	enter: Spring,
	exit: Spring,
	hover: Spring,
	press: Spring,
	travel: number,
	scaleFrom: number,
	overshoot: number,
	stagger: number,
	flash: number,
	shake: number,
	particles: number,
	glow: number,
	cue: string?,
}

local MotionIntent = {}

local ROLES: { [string]: RoleSpec } = {
	button = {
		style = "press", enter = { stiffness = 520, damping = 34 }, exit = { stiffness = 760, damping = 44 },
		hover = { stiffness = 640, damping = 38 }, press = { stiffness = 900, damping = 46 },
		travel = 0, scaleFrom = 0.96, overshoot = 0.02, stagger = 0.03, flash = 0.18, shake = 0, particles = 0, glow = 0.25,
	},
	primaryButton = {
		style = "press", enter = { stiffness = 480, damping = 30 }, exit = { stiffness = 760, damping = 44 },
		hover = { stiffness = 600, damping = 34 }, press = { stiffness = 940, damping = 44 },
		travel = 0, scaleFrom = 0.94, overshoot = 0.04, stagger = 0.04, flash = 0.24, shake = 0, particles = 0, glow = 0.45,
	},
	dangerButton = {
		style = "press", enter = { stiffness = 560, damping = 40 }, exit = { stiffness = 820, damping = 48 },
		hover = { stiffness = 700, damping = 44 }, press = { stiffness = 980, damping = 52 },
		travel = 0, scaleFrom = 0.97, overshoot = 0, stagger = 0.03, flash = 0.14, shake = 0.6, particles = 0, glow = 0.2,
	},
	toast = {
		style = "slide", enter = { stiffness = 460, damping = 32 }, exit = { stiffness = 820, damping = 42 },
		hover = { stiffness = 640, damping = 38 }, press = { stiffness = 860, damping = 44 },
		travel = 28, scaleFrom = 0.98, overshoot = 0.02, stagger = 0.06, flash = 0.32, shake = 0, particles = 0, glow = 0.3,
	},
	modal = {
		style = "rise", enter = { stiffness = 380, damping = 30 }, exit = { stiffness = 640, damping = 40 },
		hover = { stiffness = 560, damping = 36 }, press = { stiffness = 820, damping = 44 },
		travel = 18, scaleFrom = 0.95, overshoot = 0.015, stagger = 0.05, flash = 0.3, shake = 0, particles = 0, glow = 0.35,
	},
	page = {
		style = "fade", enter = { stiffness = 420, damping = 36 }, exit = { stiffness = 700, damping = 44 },
		hover = { stiffness = 560, damping = 36 }, press = { stiffness = 820, damping = 44 },
		travel = 10, scaleFrom = 0.985, overshoot = 0, stagger = 0.035, flash = 0.2, shake = 0, particles = 0, glow = 0.15,
	},
	card = {
		style = "rise", enter = { stiffness = 440, damping = 32 }, exit = { stiffness = 700, damping = 42 },
		hover = { stiffness = 600, damping = 36 }, press = { stiffness = 880, damping = 46 },
		travel = 12, scaleFrom = 0.97, overshoot = 0.02, stagger = 0.045, flash = 0.24, shake = 0, particles = 0, glow = 0.3,
	},
	listRow = {
		style = "slide", enter = { stiffness = 520, damping = 38 }, exit = { stiffness = 760, damping = 46 },
		hover = { stiffness = 640, damping = 40 }, press = { stiffness = 880, damping = 46 },
		travel = 8, scaleFrom = 1, overshoot = 0, stagger = 0.025, flash = 0.16, shake = 0, particles = 0, glow = 0.12,
	},
	tooltip = {
		style = "fade", enter = { stiffness = 700, damping = 44 }, exit = { stiffness = 900, damping = 50 },
		hover = { stiffness = 700, damping = 44 }, press = { stiffness = 900, damping = 50 },
		travel = 4, scaleFrom = 0.98, overshoot = 0, stagger = 0, flash = 0, shake = 0, particles = 0, glow = 0,
	},
	badge = {
		style = "pop", enter = { stiffness = 520, damping = 22 }, exit = { stiffness = 760, damping = 42 },
		hover = { stiffness = 600, damping = 30 }, press = { stiffness = 880, damping = 40 },
		travel = 0, scaleFrom = 0.6, overshoot = 0.12, stagger = 0.06, flash = 0.4, shake = 0, particles = 3, glow = 0.55,
		cue = "badgeEarn",
	},
	counter = {
		style = "tick", enter = { stiffness = 600, damping = 30 }, exit = { stiffness = 760, damping = 42 },
		hover = { stiffness = 600, damping = 36 }, press = { stiffness = 880, damping = 44 },
		travel = 6, scaleFrom = 0.9, overshoot = 0.06, stagger = 0, flash = 0.22, shake = 0, particles = 0, glow = 0.3,
		cue = "countTick",
	},
	reward = {
		style = "bloom", enter = { stiffness = 360, damping = 22 }, exit = { stiffness = 640, damping = 40 },
		hover = { stiffness = 560, damping = 32 }, press = { stiffness = 860, damping = 42 },
		travel = 14, scaleFrom = 0.7, overshoot = 0.1, stagger = 0.08, flash = 0.5, shake = 0, particles = 6, glow = 0.7,
		cue = "reward",
	},
	reveal = {
		style = "bloom", enter = { stiffness = 300, damping = 20 }, exit = { stiffness = 600, damping = 38 },
		hover = { stiffness = 520, damping = 30 }, press = { stiffness = 820, damping = 40 },
		travel = 20, scaleFrom = 0.62, overshoot = 0.14, stagger = 0.1, flash = 0.62, shake = 1.2, particles = 10, glow = 0.85,
		cue = "crateReveal",
	},
	ceremony = {
		style = "ascend", enter = { stiffness = 220, damping = 18 }, exit = { stiffness = 520, damping = 34 },
		hover = { stiffness = 480, damping = 30 }, press = { stiffness = 800, damping = 40 },
		travel = 36, scaleFrom = 0.55, overshoot = 0.16, stagger = 0.12, flash = 0.9, shake = 2.4, particles = 14, glow = 1,
		cue = "rebirthAscend",
	},
	drag = {
		style = "lift", enter = { stiffness = 760, damping = 40 }, exit = { stiffness = 820, damping = 46 },
		hover = { stiffness = 700, damping = 40 }, press = { stiffness = 940, damping = 48 },
		travel = 0, scaleFrom = 1.04, overshoot = 0.03, stagger = 0, flash = 0.12, shake = 0, particles = 0, glow = 0.4,
	},
}

-- Name fragments (checked in order) used when a caller only knows the instance name.
local NAME_HINTS: { { string } } = {
	{ "rebirth", "ceremony" }, { "ascend", "ceremony" }, { "prestige", "ceremony" },
	{ "reveal", "reveal" }, { "crate", "reveal" }, { "unbox", "reveal" },
	{ "reward", "reward" }, { "claim", "primaryButton" }, { "loot", "reward" },
	{ "delete", "dangerButton" }, { "remove", "dangerButton" }, { "kick", "dangerButton" }, { "ban", "dangerButton" },
	{ "confirm", "primaryButton" }, { "buy", "primaryButton" }, { "purchase", "primaryButton" }, { "submit", "primaryButton" },
	{ "toast", "toast" }, { "notice", "toast" }, { "notif", "toast" },
	{ "modal", "modal" }, { "dialog", "modal" }, { "popup", "modal" }, { "sheet", "modal" },
	{ "tooltip", "tooltip" }, { "hint", "tooltip" },
	{ "badge", "badge" }, { "achievement", "badge" }, { "title", "badge" },
	{ "count", "counter" }, { "balance", "counter" }, { "currency", "counter" }, { "stat", "counter" },
	{ "row", "listRow" }, { "entry", "listRow" }, { "item", "listRow" },
	{ "card", "card" }, { "tile", "card" }, { "slot", "card" },
	{ "page", "page" }, { "tab", "page" },
	{ "drag", "drag" }, { "handle", "drag" },
	{ "button", "button" }, { "btn", "button" },
}

local RARITY_WEIGHT: { [string]: number } = {
	Common = 0, Uncommon = 0.12, Rare = 0.26, Epic = 0.42,
	Legendary = 0.6, Mythic = 0.78, Celestial = 0.9, Astral = 1,
}

local TONE_CUE: { [string]: string } = {
	Success = "noticeSuccess", Warning = "noticeWarning", Error = "noticeError",
	Special = "noticeSpecial", Info = "noticeInfo",
}

local RARITY_CUE: { [string]: string } = {
	Epic = "crateRevealEpic", Legendary = "crateRevealEpic",
	Mythic = "crateRevealMythic", Celestial = "crateRevealMythic", Astral = "crateRevealMythic",
}

function MotionIntent.roles(): { string }
	local list = {}
	for name in ROLES do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

function MotionIntent.classify(name: string?): string
	if type(name) ~= "string" or name == "" then
		return "card"
	end
	local lower = string.lower(name)
	for _, hint in NAME_HINTS do
		if string.find(lower, hint[1], 1, true) then
			return hint[2]
		end
	end
	return "card"
end

function MotionIntent.rarityWeight(rarity: string?): number
	return if rarity then RARITY_WEIGHT[rarity] or 0 else 0
end

local function scaleSpring(spring: Spring, energy: number): Spring
	-- More energy = looser, bouncier spring; damping ratio drops gently.
	local k = spring.stiffness * (1 - 0.18 * energy)
	local c = spring.damping * (1 - 0.32 * energy)
	return { stiffness = math.max(120, k), damping = math.max(12, c) }
end

local function critical(spring: Spring): Spring
	-- Reduced motion: critically damped and quick so nothing bounces.
	local k = math.max(spring.stiffness, 600)
	return { stiffness = k, damping = 2 * math.sqrt(k) }
end

function MotionIntent.resolve(request: Request): Plan
	local role = request.role
	if role == nil or ROLES[role] == nil then
		role = MotionIntent.classify(request.name)
	end
	local spec = ROLES[role :: string]
	local rarity = MotionIntent.rarityWeight(request.rarity)
	local emphasis = math.clamp(request.emphasis or 0, 0, 1)
	local energy = math.clamp(math.max(rarity, emphasis), 0, 1)
	local tier = math.clamp(request.tier or 3, 0, 3)
	local tierScale = ({ 0.15, 0.45, 0.75, 1 })[tier + 1]
	local reduced = request.reduced == true
	local budget = request.particleBudget or 14
	local glowScale = request.glowScale or 1

	local style = spec.style
	if role == "reward" and energy >= 0.6 then
		style = "burst"
	end

	local cue = spec.cue
	if (role == "reveal" or role == "reward") and request.rarity and RARITY_CUE[request.rarity] then
		cue = RARITY_CUE[request.rarity]
	elseif role == "toast" and request.tone then
		cue = TONE_CUE[request.tone] or "noticeInfo"
	end

	local plan: Plan = {
		role = role :: string,
		style = if reduced then "fade" else style,
		enter = scaleSpring(spec.enter, energy),
		exit = spec.exit,
		hover = spec.hover,
		press = spec.press,
		travel = spec.travel * (1 + 0.5 * energy),
		scaleFrom = spec.scaleFrom - (1 - spec.scaleFrom) * 0.35 * energy,
		overshoot = spec.overshoot * (1 + energy),
		stagger = spec.stagger,
		flashSeconds = spec.flash * (1 + 0.6 * energy),
		shake = spec.shake * energy * tierScale,
		particles = math.min(budget, math.floor(spec.particles * (1 + 1.4 * energy) * tierScale + 0.5)),
		glow = math.clamp(spec.glow * (0.7 + 0.6 * energy) * glowScale, 0, 1),
		cue = cue,
		celebrate = energy >= 0.9 and (role == "reveal" or role == "reward" or role == "ceremony") and request.allowConfetti ~= false,
		weight = energy,
		reduced = reduced,
	}

	if reduced then
		plan.enter = critical(plan.enter)
		plan.exit = critical(plan.exit)
		plan.hover = critical(plan.hover)
		plan.press = critical(plan.press)
		plan.travel = 0
		plan.scaleFrom = 1
		plan.overshoot = 0
		plan.stagger = 0
		plan.shake = 0
		plan.particles = 0
		plan.flashSeconds = math.min(plan.flashSeconds, 0.12)
	elseif tier <= 1 then
		plan.stagger *= 0.5
		plan.overshoot *= 0.5
	end
	return plan
end

-- Stagger delay that compresses for long lists so the last item never waits forever.
function MotionIntent.delay(plan: Plan, index: number): number
	if plan.stagger <= 0 or index <= 0 then
		return 0
	end
	local cap = 0.42
	return math.min(cap, plan.stagger * index / (1 + index * plan.stagger / cap))
end

return MotionIntent
