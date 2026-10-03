--!nonstrict
-- Secondary motion for the Blender-rigged bosses: capes, cloaks, robes, coats, tabards and wings
-- follow the body like real cloth and feather instead of replaying a canned swing.
--
--   * Chains: every run of bones named like "cape1, cape2, cape3" (or "wingL1, wingL2, wingL3") that
--     hang off one parent is one chain. Each bone's head is a particle; a virtual particle past the
--     last bone carries the tip.
--   * Verlet integration in WORLD space, so a boss that walks, turns, leaps or is knocked back drags
--     its cloth and wings behind it by inertia alone.
--   * Forces: gravity, a drifting wind plus a gust, air drag, and a soft pull toward the pose the
--     animation clip asked for (low for cloth, high for wings so a flap still reads as a flap).
--   * Constraints: segment lengths stay as modelled (cloth does not stretch), and particles are
--     pushed out of capsules fitted to the torso, hips, head, arms and legs.
--   * Output: each chain bone's transform is rebuilt from the particles, keeping the clip's own twist,
--     so the mesh pieces bolted to it simply follow.
--   * Accessory bones (halo, rings, blades, sword, ...) get a damped spring (Spr's CFrame spring on a
--     CFrameValue) so they lag and settle instead of snapping to the clip.
--
-- Data in, CFrames out: nothing is touched except the CFrameValues Spr animates.

local BossPhysics = {}

local SUBSTEP = 1 / 60
local MAX_SUBSTEPS = 4
local ITERATIONS = 3
local RESET_DISTANCE = 40 -- studs: further than this in one frame and the body was teleported

-- What each kind of chain feels like. Gravity is studs/s^2, Drag is the share of speed kept per
-- 1/60 s, Pull is how hard particles are drawn toward the animated pose per 1/60 s (0..1), Wind is
-- how much of the air's push reaches it.
local KINDS = {
	cloth = { Gravity = 46, Drag = 0.972, Pull = 0.05, Wind = 1.0, Collide = true },
	wing = { Gravity = 8, Drag = 0.93, Pull = 0.34, Wind = 0.45, Collide = false },
	heavy = { Gravity = 60, Drag = 0.96, Pull = 0.1, Wind = 0.4, Collide = true },
}

local CLOTH_NAMES = { "cape", "cloak", "robe", "coat", "tabard", "skirt", "mantle", "drape", "banner", "scarf" }

-- Capsules the cloth must not sink into: { fromBone, toBone, radius in metres }.
local CAPSULES = {
	{ "hips", "spine", 0.34 },
	{ "spine", "head", 0.3 },
	{ "upperLegL", "lowerLegL", 0.17 },
	{ "upperLegR", "lowerLegR", 0.17 },
	{ "lowerLegL", "footL", 0.14 },
	{ "lowerLegR", "footR", 0.14 },
	{ "upperArmL", "lowerArmL", 0.13 },
	{ "upperArmR", "lowerArmR", 0.13 },
	{ "lowerArmL", "handL", 0.11 },
	{ "lowerArmR", "handR", 0.11 },
}

-- Bones that trail their clip pose with a lag and a little overshoot.
local ACCESSORIES = {
	halo = { Damping = 0.62, Frequency = 3.2 },
	ringA = { Damping = 0.55, Frequency = 2.4 },
	ringB = { Damping = 0.55, Frequency = 2.0 },
	blades = { Damping = 0.6, Frequency = 2.8 },
	sword = { Damping = 0.7, Frequency = 5.5 },
	vents = { Damping = 0.55, Frequency = 4.0 },
	back = { Damping = 0.6, Frequency = 3.5 },
}

local function baseName(name: string): string
	return (string.gsub(name, "%d+$", ""))
end

local function kindOf(prefix: string): string?
	if string.find(prefix, "^wing") ~= nil then
		return "wing"
	end
	for _, word in CLOTH_NAMES do
		if string.find(prefix, word, 1, true) ~= nil then
			return "cloth"
		end
	end
	return nil
end

-- Finds the chains in a body: { { Kind, Bones = { name, ... } } }. A chain is a run of bones whose
-- names share a prefix and whose parent is the previous bone. A rig can name its own chains in
-- `body.physics.chains` (with optional per-chain `Settings`), which wins.
function BossPhysics.findChains(body: any): { any }
	if type(body.physics) == "table" and type(body.physics.chains) == "table" then
		return body.physics.chains
	end
	local chains = {}
	for _, name in body.order do
		local prefix = baseName(name)
		local kind = kindOf(prefix)
		if kind ~= nil and name ~= prefix then
			local parent = body.parents[name]
			local joined = false
			if parent ~= nil and baseName(parent) == prefix then
				for _, chain in chains do
					if chain.Bones[#chain.Bones] == parent then
						table.insert(chain.Bones, name)
						joined = true
						break
					end
				end
			end
			if not joined then
				table.insert(chains, { Kind = kind, Bones = { name }, Prefix = prefix })
			end
		end
	end
	return chains
end

local function shortestArc(from: Vector3, to: Vector3): CFrame
	local a, b = from.Unit, to.Unit
	local dot = math.clamp(a:Dot(b), -1, 1)
	if dot > 0.99999 then
		return CFrame.identity
	end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-6 then
		-- opposite: turn half way round about any axis perpendicular to `a`
		local helper = if math.abs(a.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
		axis = a:Cross(helper)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

type Chain = {
	Kind: string,
	Bones: { string },
	Heads: { Vector3 }, -- rest heads in body space, plus the virtual tip
	Lengths: { number },
	Position: { Vector3 }, -- world
	Previous: { Vector3 },
	Settings: any,
	Primed: boolean,
}

export type State = {
	Chains: { Chain },
	Capsules: { { From: string, To: string, Radius: number } },
	Scale: number,
	Accessories: { [string]: { Value: CFrameValue, Settings: any, Primed: boolean } },
	Seed: number,
	Rest: any?,
	Spr: any?,
}

-- Builds the simulation for one body. `body.heads` is in studs in body space, `body.scale` is
-- studs per metre. Returns nil when the body has nothing worth simulating.
function BossPhysics.new(body: any, spr: any, seed: number?): State?
	local chains: { Chain } = {}
	for _, definition in BossPhysics.findChains(body) do
		local bones = definition.Bones
		local settings = table.clone(KINDS[definition.Kind] or KINDS.cloth)
		for key, value in definition.Settings or {} do
			settings[key] = value
		end
		local heads: { Vector3 } = {}
		local valid = true
		for _, bone in bones do
			local head = body.heads[bone]
			if head == nil then
				valid = false
				break
			end
			table.insert(heads, head)
		end
		if valid and #heads >= 1 then
			local count = #heads
			-- the virtual tip: one more segment the way the chain was already going (or hanging down)
			local tip
			if count >= 2 then
				tip = heads[count] + (heads[count] - heads[count - 1])
			else
				tip = heads[1] + Vector3.new(0, -2.5 * (body.scale or 6), 0)
			end
			table.insert(heads, tip)
			local lengths = {}
			for index = 1, #heads - 1 do
				lengths[index] = math.max(0.05, (heads[index + 1] - heads[index]).Magnitude)
			end
			table.insert(chains, {
				Kind = definition.Kind,
				Bones = bones,
				Heads = heads,
				Lengths = lengths,
				Position = table.create(#heads, Vector3.zero),
				Previous = table.create(#heads, Vector3.zero),
				Settings = settings,
				Primed = false,
			})
		end
	end
	local accessories = {}
	if spr ~= nil then
		for _, name in body.order do
			local settings = ACCESSORIES[name]
			if settings ~= nil then
				local value = Instance.new("CFrameValue")
				value.Name = "Spring_" .. name
				accessories[name] = { Value = value, Settings = settings, Primed = false }
			end
		end
	end
	if #chains == 0 and next(accessories) == nil then
		return nil
	end
	local capsules = {}
	for _, spec in CAPSULES do
		if body.heads[spec[1]] ~= nil and body.heads[spec[2]] ~= nil then
			table.insert(capsules, { From = spec[1], To = spec[2], Radius = spec[3] * (body.scale or 6) })
		end
	end
	return {
		Chains = chains,
		Capsules = capsules,
		Scale = body.scale or 6,
		Accessories = accessories,
		Seed = seed or 0,
		Rest = body.heads,
		Spr = spr,
	}
end

function BossPhysics.destroy(state: State?)
	if state == nil then
		return
	end
	for _, accessory in state.Accessories do
		if state.Spr ~= nil then
			state.Spr.stop(accessory.Value)
		end
		accessory.Value:Destroy()
	end
end

-- Forget the cloth's history (a boss that was moved instantly would otherwise stretch it across the map).
function BossPhysics.reset(state: State)
	for _, chain in state.Chains do
		chain.Primed = false
	end
	for _, accessory in state.Accessories do
		accessory.Primed = false
	end
end

local function closestOnSegment(point: Vector3, a: Vector3, b: Vector3): Vector3
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return a
	end
	local t = math.clamp((point - a):Dot(ab) / lengthSq, 0, 1)
	return a + ab * t
end

-- The air: a breeze that wanders and a gust that comes and goes. The boss's own motion needs no
-- term: particles live in world space, so moving the body drags them.
local function wind(state: State, now: number): Vector3
	local seed = state.Seed
	local breeze = Vector3.new(math.sin(now * 0.31 + seed) * 2.2, 0.15 * math.sin(now * 0.7), math.cos(now * 0.23 + seed * 1.7) * 2.2)
	local gust = math.max(0, math.sin(now * 0.9 + seed * 2.3)) ^ 3
	return breeze + Vector3.new(math.sin(now * 0.4 + 1.3), 0, math.cos(now * 0.37)) * (gust * 5)
end

-- Rebuild a chain bone's body-space transform so its head sits on `wantHead` and it points at
-- `wantNext`, keeping the twist the clip gave it.
local function rebuild(posedBone: CFrame, restHead: Vector3, restNext: Vector3, wantHead: Vector3, wantNext: Vector3): CFrame
	local rotation = posedBone.Rotation
	local current = rotation:VectorToWorldSpace(restNext - restHead)
	local wanted = wantNext - wantHead
	if current.Magnitude < 1e-6 or wanted.Magnitude < 1e-6 then
		return CFrame.new(wantHead - rotation:VectorToWorldSpace(restHead)) * rotation
	end
	local turned = shortestArc(current, wanted) * rotation
	return CFrame.new(wantHead - turned:VectorToWorldSpace(restHead)) * turned
end

-- Advance every chain by `dt` and overwrite their entries in `posed` (bone -> body-space CFrame, as
-- the clip pose left them). `bodyFrame` is the body's world transform.
function BossPhysics.step(state: State, dt: number, bodyFrame: CFrame, posed: { [string]: CFrame }, now: number)
	if dt <= 0 then
		return
	end
	-- The body's capsules in world space for this frame (the pose does not change inside a frame).
	local capsules = {}
	for _, spec in state.Capsules do
		local from, to = posed[spec.From], posed[spec.To]
		local fromHead, toHead = state.Rest[spec.From], state.Rest[spec.To]
		if from ~= nil and to ~= nil and fromHead ~= nil and toHead ~= nil then
			table.insert(capsules, {
				A = bodyFrame:PointToWorldSpace(from:PointToWorldSpace(fromHead)),
				B = bodyFrame:PointToWorldSpace(to:PointToWorldSpace(toHead)),
				Radius = spec.Radius * 1.05,
			})
		end
	end
	local air = wind(state, now)
	local steps = math.clamp(math.ceil(dt / SUBSTEP), 1, MAX_SUBSTEPS)
	local h = math.min(dt / steps, 1 / 20)
	for _, chain in state.Chains do
		local settings = chain.Settings
		local count = #chain.Heads
		-- Where the animation wants every particle, in world space
		local targets = table.create(count)
		local complete = true
		for index = 1, count do
			local transform = posed[chain.Bones[math.min(index, #chain.Bones)]]
			if transform == nil then
				complete = false
				break
			end
			targets[index] = bodyFrame:PointToWorldSpace(transform:PointToWorldSpace(chain.Heads[index]))
		end
		if not complete then
			continue
		end
		if not chain.Primed or (chain.Position[1] - targets[1]).Magnitude > RESET_DISTANCE then
			for index = 1, count do
				chain.Position[index] = targets[index]
				chain.Previous[index] = targets[index]
			end
			chain.Primed = true
		end
		-- A particle the pose already put inside a capsule belongs to it (a tabard sewn to the hips): leave it be.
		local free = {}
		if settings.Collide then
			for index = 2, count do
				local open = {}
				for slot, capsule in capsules do
					local nearest = closestOnSegment(targets[index], capsule.A, capsule.B)
					open[slot] = (targets[index] - nearest).Magnitude >= capsule.Radius * 0.9
				end
				free[index] = open
			end
		end
		local pull = 1 - (1 - settings.Pull) ^ (h * 60)
		local keep = settings.Drag ^ (h * 60)
		local push = air * settings.Wind
		local down = Vector3.new(0, -settings.Gravity, 0)
		for _ = 1, steps do
			-- the anchor rides the skeleton
			chain.Position[1] = targets[1]
			chain.Previous[1] = targets[1]
			for index = 2, count do
				local p = chain.Position[index]
				local velocity = (p - chain.Previous[index]) * keep
				chain.Previous[index] = p
				-- the further down the chain, the lighter it is and the more the air moves it
				local lightness = 0.6 + 0.4 * (index - 1) / math.max(1, count - 1)
				chain.Position[index] = p + velocity + (down + push * lightness) * (h * h) + (targets[index] - p) * pull
			end
			for _ = 1, ITERATIONS do
				for index = 1, count - 1 do
					local a, b = chain.Position[index], chain.Position[index + 1]
					local delta = b - a
					local distance = delta.Magnitude
					if distance > 1e-5 then
						local correction = delta * ((distance - chain.Lengths[index]) / distance)
						if index == 1 then
							chain.Position[index + 1] = b - correction
						else
							chain.Position[index] = a + correction * 0.5
							chain.Position[index + 1] = b - correction * 0.5
						end
					end
				end
				if settings.Collide then
					for index = 2, count do
						local point = chain.Position[index]
						local open = free[index]
						for slot, capsule in capsules do
							if open[slot] then
								local nearest = closestOnSegment(point, capsule.A, capsule.B)
								local offset = point - nearest
								local distance = offset.Magnitude
								if distance < capsule.Radius then
									local direction = if distance > 1e-4 then offset / distance else Vector3.new(0, 0, 1)
									point = nearest + direction * capsule.Radius
								end
							end
						end
						chain.Position[index] = point
					end
				end
			end
		end
		-- Back into bone transforms (body space), keeping each bone's own twist from the clip.
		local bodySpace = table.create(count)
		for index = 1, count do
			bodySpace[index] = bodyFrame:PointToObjectSpace(chain.Position[index])
		end
		for index, bone in chain.Bones do
			local transform = posed[bone]
			if transform ~= nil then
				posed[bone] = rebuild(transform, chain.Heads[index], chain.Heads[index + 1], bodySpace[index], bodySpace[index + 1])
			end
		end
	end
	-- Accessory springs: lag the clip's pose and settle with a little overshoot.
	local spr = state.Spr
	if spr ~= nil then
		for name, accessory in state.Accessories do
			local goal = posed[name]
			if goal ~= nil then
				if not accessory.Primed then
					accessory.Value.Value = goal
					accessory.Primed = true
				end
				spr.target(accessory.Value, accessory.Settings.Damping, accessory.Settings.Frequency, { Value = goal })
				posed[name] = accessory.Value.Value
			end
		end
	end
end

return BossPhysics
