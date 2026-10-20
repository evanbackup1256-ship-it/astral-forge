-- Rewrites only the Description lines of the endless machine/research rows in
-- GameConfigGenerated.ts from DescribeGenerated, leaving every other field (stats, icons) as is.
-- Run after `npx rbxtsc`: lune run scripts/refresh_generated_descriptions.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- authored worlds in GameConfig.ts; generated ones start right after
local AUTHORED_ZONES = 12
local PATH = "src/Shared/AstralForge/Shared/GameConfigGenerated.ts"
local describe = luau.load(luau.compile(fs.readFile("out/Shared/AstralForge/Shared/DescribeGenerated.luau")), { debugName = "DescribeGenerated" })()

-- must match MACHINE_PREFIX / MACHINE_CORE / RESEARCH_PREFIX / RESEARCH_NOUN in GameConfig.ts
local MP = { "Aether", "Quark", "Helix", "Nova", "Ion", "Prism", "Void", "Solar", "Lunar", "Chrono", "Pulse", "Nexus", "Flux", "Halo", "Rift", "Storm", "Ember", "Frost", "Glass", "Iron", "Myth", "Omega", "Sigma", "Delta", "Astra", "Cosmo", "Nebula", "Photon", "Grav", "Arc", "Rune", "Crystal", "Plasma", "Titan", "Echo", "Drift", "Spark", "Forge", "Star", "Night" }
local MC = { "Loom", "Anvil", "Spindle", "Kiln", "Array", "Engine", "Well", "Core", "Lattice", "Dynamo", "Press", "Sieve", "Relay", "Crown", "Gate", "Heart", "Spire", "Forge", "Drive", "Matrix" }
local RP = { "Folded", "Silent", "Bound", "Hollow", "Lucent", "Prime", "Deep", "High", "Inner", "Outer", "True", "Wild", "Keen", "Vast", "Fine", "Dark", "Bright", "Swift", "Still", "Live" }
local RN = { "Lattice", "Manifold", "Circuit", "Protocol", "Doctrine", "Axiom", "Theorem", "Pattern", "Vector", "Field", "Lens", "Codec", "Harmonic", "Ledger", "Cipher", "Orbit", "Thread", "Index" }

local function forIndex(prefixes, cores, fn, index)
	local p = (index - 1) % #prefixes
	local c = math.floor((index - 1) / #prefixes) % #cores
	local cycle = math.floor((index - 1) / (#prefixes * #cores))
	return fn(prefixes[p + 1], cores[c + 1], p, cycle)
end

local lines = string.split(fs.readFile(PATH), "\n")
local pendingDesc = nil
local changed = 0
for i, line in lines do
	if line:match("^%s*%{%s*$") then
		pendingDesc = nil
	elseif line:match("^%s*Description: ") then
		pendingDesc = i
	else
		local kind, num = line:match('^%s*Id: "(Horizon%a+)_(%d+)",')
		if pendingDesc and kind then
			local index = tonumber(num)
			local text
			if kind == "HorizonForge" then
				text = forIndex(MP, MC, describe.machine, index)
			elseif kind == "HorizonStudy" then
				text = forIndex(RP, RN, describe.research, index)
			end
			if text then
				local indent = lines[pendingDesc]:match("^(%s*)")
				lines[pendingDesc] = indent .. 'Description: "' .. text:gsub('\\', '\\\\'):gsub('"', '\\"') .. '",'
				changed += 1
			end
			pendingDesc = nil
		end
	end
end
-- generated worlds (Trait "<Layout> run NNN"): tagline, description and lore from the builder
local zoneChanged = 0
local function esc(text)
	return (text:gsub("\\", "\\\\"):gsub('"', '\\"'))
end
local blockStart = nil
for i, line in lines do
	if line:match("^%s*%{%s*$") then
		blockStart = i
	elseif blockStart and line:match('^%s*Trait: "%a+ run %d+",') then
		local fields = {}
		local feature = nil
		for k = blockStart, i do
			local key = lines[k]:match("^%s*(%a+): ")
			if key then fields[key] = k end
			if not feature and fields.Features and k > fields.Features then
				feature = lines[k]:match('^%s*"(.-) %d+",')
			end
		end
		local id = tonumber(lines[fields.Id]:match("Id: (%d+)"))
		local layout = lines[fields.Layout]:match('Layout: "(%a+)"')
		local name = lines[fields.Name]:match('Name: "(.-)",')
		local tier = id - AUTHORED_ZONES
		local indent = lines[fields.Tagline]:match("^(%s*)")
		lines[fields.Tagline] = indent .. 'Tagline: "' .. esc(describe.worldTagline(tier)) .. '",'
		lines[fields.Description] = indent .. 'Description: "' .. esc(describe.worldDescription(layout, tier)) .. '",'
		lines[fields.Lore] = indent .. 'Lore: "' .. esc(describe.worldLore(name, feature, tier)) .. '",'
		zoneChanged += 1
		blockStart = nil
	end
end
-- Star Grid rows: branch number sentence + builder line. Season tiers / reactor milestones: a Name.
local BRANCHES = { "Output", "Vault", "Charge", "Critical", "Offline", "Automation", "Throughput", "Helix", "Reservoir", "Aegis", "Pulse", "Ember", "Apex", "Nova", "Drift", "Swarm" }
local branchIndex = {}
for i, id in BRANCHES do branchIndex[id] = i end
local out = {}
local gridChanged, namedRows = 0, 0
local i = 1
while i <= #lines do
	local line = lines[i]
	if line:match("^%s*%{%s*$") then
		-- find the end of this flat row
		local j = i + 1
		local depth = 1
		local nested = false
		while j <= #lines do
			local opens = select(2, lines[j]:gsub("{", ""))
			local closes = select(2, lines[j]:gsub("}", ""))
			if lines[j]:match("^%s*%{%s*$") and depth == 1 then nested = true end
			depth += opens - closes
			if depth <= 0 then break end
			j += 1
		end
		if nested then
			-- not a flat row (a list of rows): leave it and keep scanning inside
			table.insert(out, line)
			i += 1
			continue
		end
		local block = {}
		for k = i, j do table.insert(block, lines[k]) end
		local fields = {}
		for k, l in block do
			local key = l:match("^%s*(%a+): ")
			if key then fields[key] = k end
		end
		if fields.Branch and fields.EffectKind and fields.Description and fields.Tier then
			local branch = block[fields.Branch]:match('Branch: "(%a+)"')
			local kind = block[fields.EffectKind]:match('EffectKind: "(%a+)"')
			local tier = tonumber(block[fields.Tier]:match("Tier: (%d+)"))
			local base = block[fields.Description]:match('Description: "(.-per level%.)')
			if branchIndex[branch] and base then
				local indent = block[fields.Description]:match("^(%s*)")
				block[fields.Description] = indent .. 'Description: "' .. esc(base .. " " .. describe.gridLine(kind, branchIndex[branch], tier)) .. '",'
				gridChanged += 1
			end
		elseif fields.Tier and fields.Reward and (fields.RequiredXP or fields.Required) and not fields.Name then
			local tier = tonumber(block[fields.Tier]:match("Tier: (%d+)"))
			local name = fields.RequiredXP and describe.seasonTierName(tier) or describe.milestoneName(tier)
			local anchor = fields.Required or fields.RequiredXP
			local indent = block[anchor]:match("^(%s*)")
			table.insert(block, anchor, indent .. 'Name: "' .. esc(name) .. '",')
			namedRows += 1
		end
		for _, l in block do table.insert(out, l) end
		i = j + 1
	else
		table.insert(out, line)
		i += 1
	end
end
fs.writeFile(PATH, table.concat(out, "\n"))
print(string.format("refreshed %d generated worlds, %d grid nodes, named %d tiers", zoneChanged, gridChanged, namedRows))
print(string.format("refreshed %d generated descriptions", changed))
