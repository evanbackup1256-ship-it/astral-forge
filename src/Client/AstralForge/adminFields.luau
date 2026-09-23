local ADMIN_REASONS = { {
	id = "Owner gameplay administration",
	label = "Owner gameplay administration",
}, {
	id = "Balance correction",
	label = "Balance correction",
}, {
	id = "Playtest grant",
	label = "Playtest grant",
}, {
	id = "Troll / joke",
	label = "Troll / joke",
}, {
	id = "Moderation action",
	label = "Moderation action",
}, {
	id = "Player request",
	label = "Player request",
}, {
	id = "Bug recovery",
	label = "Bug recovery",
} }
local KICK_REASONS = { {
	id = "You were kicked from this Astral Forge server by an administrator.",
	label = "Admin removal",
}, {
	id = "You were kicked for exploiting or using unauthorized software.",
	label = "Exploiting",
}, {
	id = "You were kicked for harassment or inappropriate behavior.",
	label = "Harassment",
}, {
	id = "You were kicked for spamming or disrupting other players.",
	label = "Spamming",
}, {
	id = "You were kicked for evading a previous punishment.",
	label = "Ban evasion",
}, {
	id = "You were kicked while this session is under review.",
	label = "Under review",
} }
local SERVER_BAN_REASONS = { {
	id = "You are banned from this Astral Forge server.",
	label = "Server ban",
}, {
	id = "You are banned from this server for exploiting or using unauthorized software.",
	label = "Exploiting",
}, {
	id = "You are banned from this server for harassment or inappropriate behavior.",
	label = "Harassment",
}, {
	id = "You are banned from this server for spamming or disrupting other players.",
	label = "Spamming",
}, {
	id = "You are banned from this server for evading a previous punishment.",
	label = "Ban evasion",
} }
local GLOBAL_BAN_REASONS = { {
	id = "You are banned from Astral Forge.",
	label = "Experience ban",
}, {
	id = "You are banned from Astral Forge for exploiting or using unauthorized software.",
	label = "Exploiting",
}, {
	id = "You are banned from Astral Forge for harassment or inappropriate behavior.",
	label = "Harassment",
}, {
	id = "You are banned from Astral Forge for spamming or disrupting other players.",
	label = "Spamming",
}, {
	id = "You are banned from Astral Forge for evading a previous punishment.",
	label = "Ban evasion",
} }
local function reasonsFor(command, category)
	if command == "Kick" then
		return KICK_REASONS
	end
	if command == "ServerBan" then
		return SERVER_BAN_REASONS
	end
	if command == "GlobalBan" then
		return GLOBAL_BAN_REASONS
	end
	local preferred = if category == "Troll" then "Troll / joke" elseif category == "Moderation" then "Moderation action" elseif category == "Resets" then "Owner gameplay administration" else "Playtest grant"
	local ranked = {}
	for _, entry in ADMIN_REASONS do
		if entry.id == preferred then
			table.insert(ranked, entry)
		end
	end
	for _, entry in ADMIN_REASONS do
		if entry.id ~= preferred then
			table.insert(ranked, entry)
		end
	end
	return ranked
end
local NONE = {
	amountLabel = "",
	optionLabel = "",
	amountChoices = {},
	optionChoices = {},
	defaultAmount = "1",
	defaultOption = "",
	usesAmount = false,
	usesOption = false,
	overridesTarget = false,
}
local function pick(id, label, icon)
	return if icon ~= nil then {
		id = id,
		label = label,
		icon = icon,
	} else {
		id = id,
		label = label,
	}
end
local function amountList(values, suffix, icon)
	local choices = {}
	for _, value in values do
		local _arg0 = pick(value, `{value} {suffix}`, icon)
		table.insert(choices, _arg0)
	end
	return choices
end
local function namedAmounts(entries, icon)
	local choices = {}
	for _, entry in entries do
		local _arg0 = pick(entry.id, entry.label, icon)
		table.insert(choices, _arg0)
	end
	return choices
end
local FLUX = namedAmounts({ {
	id = "1000",
	label = "1,000 flux",
}, {
	id = "10000",
	label = "10,000 flux",
}, {
	id = "100000",
	label = "100,000 flux",
}, {
	id = "1000000",
	label = "1 million flux",
}, {
	id = "1000000000",
	label = "1 billion flux",
}, {
	id = "1e12",
	label = "1 trillion flux",
}, {
	id = "1e15",
	label = "1 quadrillion flux",
}, {
	id = "1e308",
	label = "MAX flux",
} }, "Flux")
local CORES = namedAmounts({ {
	id = "1",
	label = "1 core",
}, {
	id = "10",
	label = "10 cores",
}, {
	id = "25",
	label = "25 cores",
}, {
	id = "100",
	label = "100 cores",
}, {
	id = "1000",
	label = "1,000 cores",
}, {
	id = "10000",
	label = "10,000 cores",
} }, "Core")
local DUST = namedAmounts({ {
	id = "100",
	label = "100 stardust",
}, {
	id = "1000",
	label = "1,000 stardust",
}, {
	id = "10000",
	label = "10,000 stardust",
}, {
	id = "100000",
	label = "100,000 stardust",
}, {
	id = "1000000",
	label = "1 million stardust",
} }, "Dust")
local COUNTS = amountList({ "1", "5", "10", "25", "50", "100" }, "")
local KEYS = amountList({ "1", "5", "10", "25", "50", "100" }, "keys", "Crate")
local RELICS = amountList({ "1", "2", "3", "5", "10" }, "relics", "Inventory")
local XP = namedAmounts({ {
	id = "100",
	label = "100 XP",
}, {
	id = "1000",
	label = "1,000 XP",
}, {
	id = "10000",
	label = "10,000 XP",
}, {
	id = "100000",
	label = "100,000 XP",
}, {
	id = "1000000",
	label = "1 million XP",
} }, "StarGrid")
local REBIRTHS = namedAmounts({ {
	id = "1",
	label = "1 rebirth",
}, {
	id = "5",
	label = "5 rebirths",
}, {
	id = "10",
	label = "10 rebirths",
}, {
	id = "25",
	label = "25 rebirths",
}, {
	id = "100",
	label = "100 rebirths",
}, {
	id = "1000",
	label = "1,000 rebirths",
} }, "Rebirth")
local DURATION = namedAmounts({ {
	id = "3",
	label = "3 seconds",
}, {
	id = "6",
	label = "6 seconds",
}, {
	id = "10",
	label = "10 seconds",
}, {
	id = "15",
	label = "15 seconds",
}, {
	id = "20",
	label = "20 seconds",
} }, "Timer")
local SERVER_BAN = namedAmounts({ {
	id = "0",
	label = "This server session",
}, {
	id = "600",
	label = "10 minutes",
}, {
	id = "3600",
	label = "1 hour",
}, {
	id = "21600",
	label = "6 hours",
}, {
	id = "86400",
	label = "24 hours",
}, {
	id = "604800",
	label = "7 days",
} }, "Lock")
local GLOBAL_BAN = namedAmounts({ {
	id = "86400",
	label = "1 day",
}, {
	id = "259200",
	label = "3 days",
}, {
	id = "604800",
	label = "7 days",
}, {
	id = "1209600",
	label = "14 days",
}, {
	id = "2592000",
	label = "30 days",
}, {
	id = "Permanent",
	label = "Permanent",
} }, "Lock")
local CLOWNS = { pick("CLOWN", "CLOWN"), pick("JESTER", "JESTER"), pick("HONK", "HONK"), pick("GOOFBALL", "GOOFBALL"), pick("ADMIN'S FAVORITE", "ADMIN'S FAVORITE") }
local FALLBACK_CRATES = { pick("ForgeCrate", "Forge Crate", "Crate"), pick("CrystalCrate", "Crystal Crate", "Crate"), pick("HorizonCrate", "Horizon Crate", "Crate"), pick("NebulaCrate", "Nebula Crate", "Crate"), pick("OrbitCrate", "Orbit Crate", "Crate"), pick("SingularityCrate", "Singularity Crate", "Crate"), pick("EchoCrate", "Echo Crate", "Crate") }
local FALLBACK_BOOSTS = { pick("DomainSurge", "Domain Surge", "Boost"), pick("Overdrive", "Overdrive", "Boost"), pick("Hyperdrive", "Hyperdrive", "Boost"), pick("VaultSurge", "Vault Surge", "Boost") }
local function pack(amountChoices, amountLabel, optionChoices, optionLabel, overridesTarget)
	if overridesTarget == nil then
		overridesTarget = false
	end
	local _object = {
		amountLabel = amountLabel,
	}
	local _left = "optionLabel"
	local _condition = optionLabel
	if _condition == nil then
		_condition = ""
	end
	_object[_left] = _condition
	_object.amountChoices = amountChoices
	_object.optionChoices = optionChoices or {}
	local _left_1 = "defaultAmount"
	local _result = amountChoices[1]
	if _result ~= nil then
		_result = _result.id
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = "1"
	end
	_object[_left_1] = _condition_1
	local _left_2 = "defaultOption"
	local _result_1 = optionChoices
	if _result_1 ~= nil then
		_result_1 = _result_1[1]
		if _result_1 ~= nil then
			_result_1 = _result_1.id
		end
	end
	local _condition_2 = _result_1
	if _condition_2 == nil then
		_condition_2 = ""
	end
	_object[_left_2] = _condition_2
	_object.usesAmount = #amountChoices > 0
	local _left_3 = "usesOption"
	local _result_2 = optionChoices
	if _result_2 ~= nil then
		_result_2 = #_result_2
	end
	local _condition_3 = _result_2
	if _condition_3 == nil then
		_condition_3 = 0
	end
	_object[_left_3] = _condition_3 > 0
	_object.overridesTarget = overridesTarget
	return _object
end
local function crateChoices(config)
	local _crates = config
	if _crates ~= nil then
		_crates = _crates.Items
		if _crates ~= nil then
			_crates = _crates.Crates
		end
	end
	local crates = _crates
	if crates == nil or #crates == 0 then
		return FALLBACK_CRATES
	end
	local choices = {}
	for _, crate in crates do
		local _arg0 = pick(crate.Id, crate.Name, "Crate")
		table.insert(choices, _arg0)
	end
	return choices
end
local function boostChoices(config)
	local _boosts = config
	if _boosts ~= nil then
		_boosts = _boosts.Boosts
	end
	local boosts = _boosts
	if boosts == nil then
		return FALLBACK_BOOSTS
	end
	local choices = {}
	for id, boost in pairs(boosts) do
		local _arg0 = pick(id, boost.Name, "Boost")
		table.insert(choices, _arg0)
	end
	if #choices == 0 then
		return FALLBACK_BOOSTS
	end
	return choices
end
local function relicChoices(config)
	local _definitions = config
	if _definitions ~= nil then
		_definitions = _definitions.Items
		if _definitions ~= nil then
			_definitions = _definitions.Definitions
		end
	end
	local definitions = _definitions
	if definitions == nil or #definitions == 0 then
		return { pick("IonCoupler", "Ion Coupler", "Inventory") }
	end
	local choices = {}
	for _, definition in definitions do
		local _arg0 = pick(definition.Id, definition.Name, "Inventory")
		table.insert(choices, _arg0)
	end
	return choices
end
local function zoneChoices(config)
	local _zones = config
	if _zones ~= nil then
		_zones = _zones.Zones
	end
	local zones = _zones
	if zones == nil or #zones == 0 then
		return namedAmounts({ {
			id = "1",
			label = "World 1",
		}, {
			id = "2",
			label = "World 2",
		}, {
			id = "3",
			label = "World 3",
		} }, "World")
	end
	local choices = {}
	for _, zone in zones do
		local _arg0 = pick(tostring(zone.Id), zone.Name, "World")
		table.insert(choices, _arg0)
	end
	return choices
end
local function banChoices(banned)
	local choices = {}
	for _, entry in banned do
		local window = if entry.Until < 0 then "permanent" elseif entry.Until == 0 then "this server" else "timed"
		local _arg0 = {
			id = tostring(entry.UserId),
			label = `{entry.Name}  ·  {entry.Scope} {window}`,
			icon = "Lock",
		}
		table.insert(choices, _arg0)
	end
	return choices
end
local function fieldsFor(command, config, banned)
	if command == "GrantFlux" then
		return pack(FLUX, "How much flux")
	end
	if command == "GrantCores" or command == "SetCores" then
		return pack(CORES, "How many cores")
	end
	if command == "GrantStardust" or command == "SetStardust" then
		return pack(DUST, "How much stardust")
	end
	if command == "GrantRebirths" or command == "SetRebirths" then
		return pack(REBIRTHS, "How many rebirths")
	end
	if command == "GrantDomainEssence" or command == "GrantItemEssence" or command == "GrantAnomalyFragments" or command == "GrantSignals" or command == "GrantStreakShields" or command == "GrantContinuumRanks" or command == "GrantAnomalyCharge" or command == "GrantAnomalyStabilizations" or command == "GrantFreeSpins" or command == "GrantAllCrateKeys" or command == "GrantAllBoosts" or command == "GrantSkillPoints" or command == "GrantEchoCharge" then
		return pack(COUNTS, "How many")
	end
	if command == "GrantCommandXP" or command == "GrantSeasonXP" then
		return pack(XP, "How much XP")
	end
	if command == "SetDomainRank" then
		return pack(amountList({ "0", "1", "5", "10", "25", "50" }, "rank", "Domain"), "Domain rank")
	end
	if command == "GrantEverything" then
		return pack(namedAmounts({ {
			id = "1000",
			label = "Starter owner bundle",
		}, {
			id = "1000000",
			label = "Large owner bundle",
		}, {
			id = "1e12",
			label = "Massive owner bundle",
		} }, "Gift"), "Bundle size")
	end
	if command == "GrantCrateKeys" or command == "GrantPity" then
		return pack(KEYS, "How many", crateChoices(config), "Which crate")
	end
	if command == "GrantBoost" then
		return pack(COUNTS, "How many", boostChoices(config), "Which boost")
	end
	if command == "GrantRelic" then
		return pack(RELICS, "How many", relicChoices(config), "Which relic")
	end
	if command == "SetZone" then
		return pack(zoneChoices(config), "Unlock through")
	end
	if command == "ClownTitle" then
		return pack(DURATION, "How long", CLOWNS, "Splash text")
	end
	if command == "Blind" or command == "Jumpscare" or command == "ConfettiStorm" or command == "LoadingForever" or command == "BlueScreen" or command == "LowBattery" or command == "UpdateForced" or (string.find(command, "Hud")) ~= nil or (string.find(command, "Fake")) ~= nil then
		return pack(DURATION, "How long")
	end
	if command == "Kick" then
		return NONE
	end
	if command == "ServerBan" then
		return pack(SERVER_BAN, "How long")
	end
	if command == "GlobalBan" then
		return pack(GLOBAL_BAN, "How long")
	end
	if command == "Unban" then
		local choices = banChoices(banned or {})
		return pack(choices, "Who to unban", nil, nil, true)
	end
	return NONE
end
return {
	reasonsFor = reasonsFor,
	fieldsFor = fieldsFor,
	ADMIN_REASONS = ADMIN_REASONS,
}
