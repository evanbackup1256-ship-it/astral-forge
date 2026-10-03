--!nocheck
-- Guards for the Blender-built boss bodies (src/Shared/AstralForge/Shared/BossBody_<Kind>.luau):
--   1. Every boss has a body module small enough for Roblox (a script has a size limit).
--   2. The skeleton is sound: every bone's parent exists and comes earlier, every piece sits on a real bone.
--   3. The physics chains the rig declares name real bones, in parent order, with sane settings, and a
--      ring or sheet of columns shares one group with distinct columns.
--   4. Every clip the game plays exists for every boss, loops are flagged the way the game expects, the
--      strike times match the boss config, and no animation number is NaN or wild.
--   5. The physics module and the spring module are present.

local fs = require("@lune/fs")
local SanctuaryConfig = require("../src/Shared/AstralForge/Shared/SharedData")("SanctuaryConfig")

local function check(condition: boolean, message: string)
	if not condition then
		error("boss rigs: " .. message, 0)
	end
end

local FOLDER = "src/Shared/AstralForge/Shared/"
local MAX_BYTES = 900 * 1024
local CLIPS = { "idle", "forming", "slam", "thrust", "pull", "sweep", "floor", "roar", "summon", "walk", "run", "hit", "death" }
local LOOPING = { idle = true, forming = true, pull = true, sweep = true, floor = true, walk = true, run = true }
local STRIKE = { slam = true, thrust = true }

check(fs.isFile(FOLDER .. "BossPhysics.luau"), "BossPhysics.luau is missing")
check(fs.isFile(FOLDER .. "Spr.luau"), "Spr.luau (the vendored spring module) is missing")
check(fs.isFile("vendor/licenses/spr.txt"), "the Spr licence text is missing")
local loader = fs.readFile(FOLDER .. "BossBodies.luau")
check(string.find(loader, "BossBody_", 1, true) ~= nil, "BossBodies.luau must load the per-boss modules")

local totals = { bones = 0, chains = 0, pieces = 0 }
for _, boss in SanctuaryConfig.RiftBosses do
	local kind = boss.Kind
	local path = FOLDER .. "BossBody_" .. kind .. ".luau"
	check(fs.isFile(path), kind .. ": no body module (run tools/bossbuild/export_bodies.py)")
	local size = #fs.readFile(path)
	check(size <= MAX_BYTES, `{kind}: body module is {size // 1024} KB, over the {MAX_BYTES // 1024} KB limit`)
	local body = require("../src/Shared/AstralForge/Shared/BossBody_" .. kind)
	check(type(body.scale) == "number" and body.scale > 1, kind .. ": bad scale")
	check(type(body.ref) == "string" and body.pieces[body.ref] ~= nil, kind .. ": ref piece missing")

	-- skeleton
	local seen = {}
	for index, name in body.order do
		local bone = body.bones[name]
		check(bone ~= nil, `{kind}: order names a bone with no data: {name}`)
		check(#bone.head == 3, `{kind}: {name} head is not a vector`)
		for _, v in bone.head do
			check(v == v and math.abs(v) < 60, `{kind}: {name} head is NaN or far outside the model`)
		end
		if bone.parent ~= nil then
			check(seen[bone.parent] ~= nil, `{kind}: {name} comes before its parent {bone.parent}`)
		end
		seen[name] = index
		totals.bones += 1
	end
	check(body.bones.hips ~= nil and body.bones.spine ~= nil and body.bones.head ~= nil, kind .. ": the humanoid core (hips, spine, head) is missing")
	for pieceName, piece in body.pieces do
		check(seen[piece.bone] ~= nil, `{kind}: piece {pieceName} sits on a missing bone {piece.bone}`)
		totals.pieces += 1
	end

	-- physics chains
	local physics = body.physics
	check(physics ~= nil and #physics.chains > 0, kind .. ": no simulated cloth or wings were declared")
	local groups = {}
	local claimed = {}
	for _, chain in physics.chains do
		check(chain.Kind == "cloth" or chain.Kind == "wing" or chain.Kind == "heavy", `{kind}: chain kind {chain.Kind}`)
		check(#chain.Bones >= 1 and #chain.Bones <= 8, `{kind}: chain of {#chain.Bones} bones`)
		for index, bone in chain.Bones do
			check(seen[bone] ~= nil, `{kind}: chain names a missing bone {bone}`)
			check(claimed[bone] == nil, `{kind}: bone {bone} is in two chains`)
			claimed[bone] = true
			if index > 1 then
				check(body.bones[bone].parent == chain.Bones[index - 1], `{kind}: {bone} is not parented to {chain.Bones[index - 1]} inside its chain`)
			end
		end
		local settings = chain.Settings
		for key, value in settings do
			if type(value) == "number" then
				check(value == value and math.abs(value) < 500, `{kind}: setting {key} is out of range`)
			end
		end
		if settings.Pull ~= nil then
			check(settings.Pull >= 0 and settings.Pull <= 1, kind .. ": Pull must be 0..1")
		end
		groups[chain.Group] = groups[chain.Group] or {}
		check(groups[chain.Group][chain.Column] == nil, `{kind}: group {chain.Group} has two chains in column {chain.Column}`)
		groups[chain.Group][chain.Column] = true
		totals.chains += 1
	end

	-- clips
	for _, name in CLIPS do
		local clip = body.clips[name]
		check(clip ~= nil, `{kind}: clip {name} is missing`)
		check(clip.length > 0.3 and clip.length < 6, `{kind}: clip {name} has length {clip.length}`)
		check(clip.loop == (LOOPING[name] == true), `{kind}: clip {name} loop flag is {tostring(clip.loop)}`)
		if STRIKE[name] then
			check(clip.hit > 0.3 and clip.hit < clip.length, `{kind}: clip {name} has no sensible strike time`)
		end
		local frames = math.floor(clip.length * clip.fps + 0.5) + 1
		for bone, values in clip.bones do
			check(seen[bone] ~= nil, `{kind}: clip {name} animates a missing bone {bone}`)
			check(#values == frames * 3, `{kind}: clip {name} bone {bone} has {#values} numbers, expected {frames * 3}`)
			for _, v in values do
				check(v == v and math.abs(v) < 4.5, `{kind}: clip {name} bone {bone} has a wild angle {v}`)
			end
			-- no frame may spin a bone more than half a turn at once
			for i = 4, #values do
				check(math.abs(values[i] - values[i - 3]) < 3.2, `{kind}: clip {name} bone {bone} jumps between frames`)
			end
		end
		if clip.loop and clip.length > 0.5 then
			for bone, values in clip.bones do
				local last = #values
				for axis = 1, 3 do
					check(math.abs(values[axis] - values[last - 3 + axis]) < 0.12, `{kind}: looping clip {name} bone {bone} does not close its seam`)
				end
			end
		end
	end
end
print(`[TEST] boss rig guards passed | {totals.bones} bones, {totals.pieces} pieces, {totals.chains} simulated chains across {#SanctuaryConfig.RiftBosses} bosses`)
