--!nonstrict
-- Secondary motion for the Blender-rigged bosses: capes, cloaks, robes, coats, tabards and wings
-- follow the body like real cloth and feather instead of replaying a canned swing.
--
--   * Chains: the rig declares them (`body.physics.chains`: Kind, Bones, Group, Column, Settings), or
--     they are found by name ("cape1, cape2, cape3" or "wingL1, wingL2, wingL3"). Each bone's head is
--     a particle; a virtual particle past the last bone carries the tip.
--   * Verlet integration in WORLD space, so a boss that walks, turns, leaps or is knocked back drags
--     its cloth and wings behind it by inertia alone.
--   * Forces: gravity, a drifting wind plus a gust, air drag, and a soft pull toward the pose the
--     animation clip asked for (low for cloth, high for wings so a flap still reads as a flap).
--   * Constraints: segment lengths stay as modelled (cloth does not stretch); chains of one Group in
--     neighbouring Columns are cross-linked, so a cape built from several columns moves as one sheet;
--     particles are pushed out of capsules fitted to the torso, hips, head, arms and legs.
--   * Hierarchy: a chain that hangs off another (feathers on a wing arm) is simulated after it, and the
--     parent's simulated motion is carried down to it, so feathers stay on a wing that lags the body.
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
local LINK_STRENGTH = 0.45 -- how firmly neighbouring columns of one cloth hold their spacing

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

-- The chains of a body: { { Kind, Bones = { name, ... }, Group, Column, Settings } }. A rig declares
-- its own in `body.physics.chains`; otherwise they are found by name: a run of bones sharing a
-- prefix whose parent is the previous bone.
function BossPhysics.findChains(body: any): { any }
	if type(body.physics) == "table" and type(body.physics.chains) == "table" and #body.physics.chains > 0 then
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
				table.insert(chains, { Kind = kind, Bones = { name }, Group = prefix, Column = 0, Settings = {} })
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
	Group: string,
	Column: number,
	Level: number,
	Heads: { Vector3 }, -- rest heads in body space, plus the virtual tip
	Lengths: { number },
	Position: { Vector3 }, -- world
	Previous: { Vector3 },
	Settings: any,
	Primed: boolean,
	Active: boolean,
	Targets: { Vector3 }?,
	Free: { [number]: { boolean } }?,
}

export type State = {
	Chains: { Chain },
	Levels: { { Chain } },
	Links: { { A: Chain, B: Chain, Rest: { number } } },
	Capsules: { { From: string, To: string, Radius: number } },
	Scale: number,
	Accessories: { [string]: { Value: CFrameValue, Settings: any, Primed: boolean } },
	Seed: number,
	Rest: any?,
	Order: { string },
	Parents: { [string]: string },
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
				Group = definition.Group or baseName(bones[1]),
				Column = definition.Column or 0,
				Level = 1,
				Heads = heads,
				Lengths = lengths,
				Position = table.create(#heads, Vector3.zero),
				Previous = table.create(#heads, Vector3.zero),
				Settings = settings,
				Primed = false,
				Active = false,
			})
		end
	end
	-- Dependency order: a chain that hangs off another chain's bone is one level deeper.
	local owner: { [string]: Chain } = {}
	for _, chain in chains do
		for _, bone in chain.Bones do
			owner[bone] = chain
		end
	end
	local resolved: { [Chain]: boolean } = {}
	local function levelOf(chain: Chain, depth: number): number
		if resolved[chain] then
			return chain.Level
		end
		local level = 1
		local bone = body.parents[chain.Bones[1]]
		while bone ~= nil and depth < 16 do
			local above = owner[bone]
			if above ~= nil and above ~= chain then
				level = math.max(level, levelOf(above, depth + 1) + 1)
				break
			end
			bone = body.parents[bone]
		end
		chain.Level = level
		resolved[chain] = true
		return level
	end
	local levels: { { Chain } } = {}
	for _, chain in chains do
		local level = levelOf(chain, 0)
		levels[level] = levels[level] or {}
		table.insert(levels[level], chain)
	end
	-- Neighbouring columns of one cloth hold their spacing
	local links = {}
	local groups: { [string]: { Chain } } = {}
	for _, chain in chains do
		groups[chain.Group] = groups[chain.Group] or {}
		table.insert(groups[chain.Group], chain)
	end
	for _, group in groups do
		table.sort(group, function(a, b)
			return a.Column < b.Column
		end)
		-- a ring (a skirt or robe) also links its last column back to its first
		local pairs_ = #group - 1
		if #group > 2 and group[1].Settings.Ring == true then
			pairs_ = #group
		end
		for index = 1, pairs_ do
			local a, b = group[index], group[index % #group + 1]
			local rest = {}
			for particle = 2, math.min(#a.Heads, #b.Heads) do
				rest[particle] = (a.Heads[particle] - b.Heads[particle]).Magnitude
			end
			table.insert(links, { A = a, B = b, Rest = rest })
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
		Levels = levels,
		Links = links,
		Capsules = capsules,
		Scale = body.scale or 6,
		Accessories = accessories,
		Seed = seed or 0,
		Rest = body.heads,
		Order = body.order,
		Parents = body.parents,
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

-- One level of chains: aim them at the pose, integrate, constrain, and write their bones back.
local function simulate(state: State, chains: { Chain }, steps: number, h: number, bodyFrame: CFrame, posed: { [string]: CFrame }, capsules: { any }, air: Vector3)
	for _, chain in chains do
		local count = #chain.Heads
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
		chain.Active = complete
		if complete then
			chain.Targets = targets
			if not chain.Primed or (chain.Position[1] - targets[1]).Magnitude > RESET_DISTANCE then
				for index = 1, count do
					chain.Position[index] = targets[index]
					chain.Previous[index] = targets[index]
				end
				chain.Primed = true
			end
			-- A particle the pose already put inside a capsule belongs to it (a tabard sewn to the hips): leave it be.
			local free = {}
			if chain.Settings.Collide then
				for index = 2, count do
					local open = {}
					for slot, capsule in capsules do
						local nearest = closestOnSegment(targets[index], capsule.A, capsule.B)
						open[slot] = (targets[index] - nearest).Magnitude >= capsule.Radius * 0.9
					end
					free[index] = open
				end
			end
			chain.Free = free
		end
	end
	for _ = 1, steps do
		for _, chain in chains do
			if chain.Active then
				local settings = chain.Settings
				local count = #chain.Heads
				local targets = chain.Targets
				local pull = 1 - (1 - settings.Pull) ^ (h * 60)
				local keep = settings.Drag ^ (h * 60)
				local push = air * settings.Wind
				local down = Vector3.new(0, -settings.Gravity, 0)
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
			end
		end
		for _ = 1, ITERATIONS do
			for _, chain in chains do
				if chain.Active then
					for index = 1, #chain.Heads - 1 do
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
				end
			end
			for _, link in state.Links do
				local a, b = link.A, link.B
				if a.Active and b.Active and a.Level == b.Level and a.Level == chains[1].Level then
					for index, rest in link.Rest do
						local pa, pb = a.Position[index], b.Position[index]
						if pa ~= nil and pb ~= nil then
							local delta = pb - pa
							local distance = delta.Magnitude
							if distance > 1e-5 then
								local correction = delta * ((distance - rest) / distance) * (0.5 * LINK_STRENGTH)
								a.Position[index] = pa + correction
								b.Position[index] = pb - correction
							end
						end
					end
				end
			end
			if #capsules > 0 then
				for _, chain in chains do
					if chain.Active and chain.Settings.Collide then
						for index = 2, #chain.Heads do
							local point = chain.Position[index]
							local open = chain.Free[index]
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
		end
	end
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
		chain.Active = false
	end
	for _, chains in state.Levels do
		simulate(state, chains, steps, h, bodyFrame, posed, capsules, air)
		-- Write the level's bones back, and carry each bone's motion down to whatever hangs from it.
		local deltas: { [string]: CFrame } = {}
		local rebuilt: { [string]: boolean } = {}
		for _, chain in chains do
			if chain.Active then
				local count = #chain.Heads
				local bodySpace = table.create(count)
				for index = 1, count do
					bodySpace[index] = bodyFrame:PointToObjectSpace(chain.Position[index])
				end
				for index, bone in chain.Bones do
					local old = posed[bone]
					if old ~= nil then
						local new = rebuild(old, chain.Heads[index], chain.Heads[index + 1], bodySpace[index], bodySpace[index + 1])
						posed[bone] = new
						deltas[bone] = new * old:Inverse()
						rebuilt[bone] = true
					end
				end
			end
		end
		if next(deltas) ~= nil then
			for _, bone in state.Order do
				if not rebuilt[bone] then
					local parent = state.Parents[bone]
					local delta = if parent ~= nil then deltas[parent] else nil
					if delta ~= nil and posed[bone] ~= nil then
						posed[bone] = delta * posed[bone]
						deltas[bone] = delta
					end
				end
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
