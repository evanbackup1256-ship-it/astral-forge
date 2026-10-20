-- Rewrites only the Description lines of the endless machine/research rows in
-- GameConfigGenerated.ts from DescribeGenerated, leaving every other field (stats, icons) as is.
-- Run after `npx rbxtsc`: lune run scripts/refresh_generated_descriptions.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")

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
fs.writeFile(PATH, table.concat(lines, "\n"))
print(string.format("refreshed %d generated descriptions", changed))
