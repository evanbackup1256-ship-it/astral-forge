--!strict
-- Relic rigs. The bonus is only while every piece is socketed on something you still own.
-- Lighting a rig is remembered, so the milestone pays once.

local fs = require("@lune/fs")
local Rigs = require("../out/Shared/AstralForge/Shared/RelicRigs")

local function profile(sockets: { { Id: string, Slot: string, Target: string, Level: number? } }, lit: { [string]: any }?)
	local equipped: { [string]: string } = {}
	local inventory: { [string]: { DefinitionId: string } } = {}
	local machines: { [string]: number } = {}
	local research: { [string]: number } = {}
	for index, socket in sockets do
		local uid = "u" .. index
		inventory[uid] = { DefinitionId = socket.Id }
		equipped[socket.Slot .. ":" .. socket.Target] = uid
		local level = if socket.Level == nil then 1 else socket.Level
		if socket.Slot == "Machine" then
			machines[socket.Target] = level
		else
			research[socket.Target] = level
		end
	end
	return {
		Items = {
			Equipped = equipped,
			Inventory = inventory,
			Rigs = { Lit = if lit == nil then {} else lit },
		},
		Machines = machines,
		Research = research,
	}
end

assert(Rigs.COUNT == 8 and #Rigs.RIGS == 8, "eight rigs")

local seen: { [string]: boolean } = {}
local productionIfSeparate = 0
for _, rig in Rigs.RIGS do
	assert(not seen[rig.Id], "rig ids are unique")
	seen[rig.Id] = true
	assert(math.abs(rig.Amount * 100 - rig.Percent) < 1e-9, rig.Id .. " percent matches the bonus")
	assert(rig.Amount > 0 and rig.Amount <= 0.04, rig.Id .. " stays a small bonus")
	assert(type(rig.Reward.Stardust) == "number" and rig.Reward.Stardust > 0, rig.Id .. " pays stardust once")
	assert(#rig.Members >= 2, rig.Id .. " needs more than one relic")
	local used: { [string]: boolean } = {}
	for _, member in rig.Members do
		local key = member.Slot .. ":" .. (member.Target or "*")
		assert(not used[key], rig.Id .. " puts two relics on " .. key)
		used[key] = true
	end
	if rig.Kind == "Production" then
		productionIfSeparate += rig.Amount
	end
	assert(Rigs.effectText(rig) == string.format("+%s%% %s", tostring(rig.Percent):gsub("%.0$", ""), Rigs.KIND_WORD[rig.Kind]), rig.Id .. " effect line")
end
assert(productionIfSeparate <= 0.16, "even added separately, production rigs stay under +16%")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.ts")
for _, rig in Rigs.RIGS do
	for _, member in rig.Members do
		assert(string.find(config, '\t\t\t\tId: "' .. member.Id .. '"', 1, true), member.Id .. " is a real relic")
	end
end
assert(string.find(config, 'Id: "FirstRig"', 1, true) and string.find(config, 'Id: "AllRigs"', 1, true), "rig goals are in the achievement list")
assert(string.find(config, 'Kind: "RigsLit"', 1, true), "rig goals count rigs lit")
local template = fs.readFile("src/Server/AstralForge/DataTemplate.ts")
assert(string.find(template, "Rigs: { Lit: {} }", 1, true), "new saves start with an empty rig ledger")

-- nothing socketed
local empty = profile({})
assert(Rigs.bonus(empty, "Production") == 0 and Rigs.bonus(empty, "Tap") == 0, "no relics, no bonus")
assert(Rigs.bonus(nil, "Production") == 0 and Rigs.litCount(nil) == 0, "garbage in, zero out")
assert(#Rigs.pending(empty, empty.Items.Rigs) == 0, "an empty bench lights nothing")

-- the dock pair, and only that
local dock = profile({
	{ Id = "IonCoupler", Slot = "Machine", Target = "StellarCore" },
	{ Id = "FluxLens", Slot = "Research", Target = "Efficiency" },
})
assert(Rigs.bonus(dock, "Production") == 0.015, "dock rig is +1.5% production")
assert(Rigs.bonus(dock, "Capacity") == 0 and Rigs.bonus(dock, "Tap") == 0 and Rigs.bonus(dock, "Offline") == 0, "dock does not leak into other stats")
assert(Rigs.effectText(Rigs.rig("Dock")) == "+1.5% production", "dock line")
local fresh = Rigs.pending(dock, dock.Items.Rigs)
assert(#fresh == 1 and fresh[1].Id == "Dock" and fresh[1].Reward.Stardust == 12, "dock lights once")
dock.Items.Rigs.Lit.Dock = true
assert(#Rigs.pending(dock, dock.Items.Rigs) == 0, "a lit rig is not paid again")
assert(Rigs.litCount(dock.Items.Rigs) == 1, "the ledger counts it")
assert(Rigs.bonus(dock, "Production") == 0.015, "the bonus stays while the relics stay socketed")

-- one piece, or the right relic on the wrong socket, does not light
local half = profile({ { Id = "IonCoupler", Slot = "Machine", Target = "StellarCore" } })
assert(Rigs.bonus(half, "Production") == 0 and #Rigs.pending(half, half.Items.Rigs) == 0, "half a rig is nothing")
local wrong = profile({
	{ Id = "IonCoupler", Slot = "Machine", Target = "StellarCore" },
	{ Id = "FluxLens", Slot = "Research", Target = "Storage" },
})
assert(Rigs.bonus(wrong, "Production") == 0, "Flux Lens on Storage is not the dock rig")
local unwound = profile({
	{ Id = "IonCoupler", Slot = "Machine", Target = "StellarCore", Level = 0 },
	{ Id = "FluxLens", Slot = "Research", Target = "Efficiency" },
})
assert(Rigs.bonus(unwound, "Production") == 0, "a relic on a machine you no longer own does not count")

-- named machines have to be the machines named
local press = profile({
	{ Id = "HelixCoupler", Slot = "Machine", Target = "HelixColliders" },
	{ Id = "LoomSpindle", Slot = "Machine", Target = "AstralLoom" },
	{ Id = "AnvilStamp", Slot = "Machine", Target = "OmegaAnvil" },
	{ Id = "OriginShard", Slot = "Machine", Target = "OriginPress" },
})
assert(math.abs(Rigs.bonus(press, "Production") - 0.055) < 1e-9, "press rig and last press stack")
local misplaced = profile({
	{ Id = "HelixCoupler", Slot = "Machine", Target = "StellarCore" },
	{ Id = "LoomSpindle", Slot = "Machine", Target = "AstralLoom" },
})
assert(Rigs.bonus(misplaced, "Production") == 0, "Helix Coupler only counts on the Helix Colliders")

-- Dock and First Fire share Efficiency, so a loadout can hold one of them
local fire = profile({
	{ Id = "HaloOfFirstForge", Slot = "Machine", Target = "StellarCore" },
	{ Id = "AuroraLoom", Slot = "Research", Target = "Efficiency" },
	{ Id = "IonCoupler", Slot = "Machine", Target = "LunarExtractor" },
})
assert(Rigs.bonus(fire, "Production") == 0.035, "first fire replaces the dock rig on Efficiency")
assert(Rigs.active(fire).FirstFire == true and Rigs.active(fire).Dock ~= true, "dock is off while aurora loom sits on efficiency")

-- the late four production rigs, plus night, is the cap while they are all socketed
local late = profile({
	{ Id = "HelixCoupler", Slot = "Machine", Target = "HelixColliders" },
	{ Id = "LoomSpindle", Slot = "Machine", Target = "AstralLoom" },
	{ Id = "AnvilStamp", Slot = "Machine", Target = "OmegaAnvil" },
	{ Id = "OriginShard", Slot = "Machine", Target = "OriginPress" },
	{ Id = "HaloOfFirstForge", Slot = "Machine", Target = "StellarCore" },
	{ Id = "AuroraLoom", Slot = "Research", Target = "Efficiency" },
	{ Id = "HeartOfAstraeon", Slot = "Machine", Target = "LunarExtractor" },
	{ Id = "CrownOfNineSuns", Slot = "Research", Target = "Insight" },
	{ Id = "ChronoSeal", Slot = "Research", Target = "Offline" },
	{ Id = "StarDrive", Slot = "Machine", Target = "PrismRefinery" },
})
assert(math.abs(Rigs.bonus(late, "Production") - 0.13) < 1e-9, "late production rigs cap at +13%")
assert(Rigs.bonus(late, "Offline") == 0.02, "night rig is +2% offline efficiency")
assert(Rigs.bonus(late, "Capacity") == 0 and Rigs.bonus(late, "Tap") == 0, "that loadout is not the shelf or the strike rig")
local lateFresh = Rigs.pending(late, late.Items.Rigs)
assert(#lateFresh == 5, "five rigs light together on that bench, got " .. #lateFresh)

-- shelf and strike cannot both sit on Overcharge
local shelf = profile({
	{ Id = "CapacityCoil", Slot = "Research", Target = "Storage" },
	{ Id = "PulseInjector", Slot = "Research", Target = "Overcharge" },
	{ Id = "CriticalPrism", Slot = "Research", Target = "Critical" },
})
assert(Rigs.bonus(shelf, "Capacity") == 0.025 and Rigs.bonus(shelf, "Tap") == 0, "shelf is vault time, and it occupies overcharge")
local strike = profile({
	{ Id = "CoilBrace", Slot = "Research", Target = "Overcharge" },
	{ Id = "CriticalPrism", Slot = "Research", Target = "Critical" },
})
assert(Rigs.bonus(strike, "Tap") == 0.03 and Rigs.bonus(strike, "Capacity") == 0, "strike is +3% overcharge")
assert(Rigs.rig("Strike").Reward.Signals == 10, "strike's first light pays signals")
assert(Rigs.rig("Press").Reward.Keys.CrystalCrate == 1, "press rig pays a crystal key")
assert(Rigs.rig("LastPress").Reward.Cores == 1 and Rigs.rig("NineSuns").Reward.Cores == 3, "the late rigs pay cores")

-- the ledger keeps real rigs, drops junk, and does not forget a rig you took apart
local dirty = Rigs.ensure({ Lit = { Dock = true, Nope = true, Shelf = false, Night = 1 }, Extra = 4 })
assert(dirty.Extra == 4, "ensure leaves keys it does not own")
assert(dirty.Lit.Dock == true and dirty.Lit.Nope == nil and dirty.Lit.Shelf == nil and dirty.Lit.Night == nil, "only a true known rig stays lit")
assert(Rigs.litCount(dirty) == 1, "lit count ignores the junk")
local remembered = profile({}, { Dock = true })
assert(Rigs.bonus(remembered, "Production") == 0, "a remembered rig pays no bonus once the relics come off")
assert(Rigs.litCount(remembered.Items.Rigs) == 1, "the ledger still remembers it")
local looked = Rigs.view(remembered)
assert(looked.Lit.Dock == true and looked.Active.Dock ~= true and looked.Bonus.Production == 0, "the snapshot separates memory from what is socketed")

local freshLedger = Rigs.ensure(nil)
assert(freshLedger.Lit.Dock == nil and Rigs.litCount(freshLedger) == 0, "a missing ledger is empty")

print("[TEST] relic rigs passed")
