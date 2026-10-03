--!nocheck
-- Numeric check of the cloth and wing solver (src/Shared/AstralForge/Shared/BossPhysics). Run it in Studio,
-- for example through the Roblox Studio MCP `execute_luau` with datamodel_type Edit. It builds a small body with a
-- wing, two feathers hanging off it and a two-column cape, walks it back and forth while the wing flaps hard,
-- and reports:
--   * feather anchors stay on the simulated wing arm (the parent's motion is carried down the hierarchy);
--   * cape columns hold their spacing (the cross-links work);
--   * nothing goes NaN, and a segment never stretches by more than a few per cent;
--   * the cost per frame.
-- Expected: levels=2, feather distance well under 0.5 studs, nan=0, cape drift ~0, stretch < 3%.

local P = require(game.ReplicatedStorage.AstralForge.Shared.BossPhysics)

local heads = {
	hips = Vector3.new(0, 10, 0), spine = Vector3.new(0, 12, 0), head = Vector3.new(0, 17, 0),
	wingL1 = Vector3.new(1, 16, 1), wingL2 = Vector3.new(6, 17, 1.2), wingL3 = Vector3.new(11, 17.5, 1.4),
	fA1 = Vector3.new(4, 16.5, 1.3), fA2 = Vector3.new(4, 14, 1.3),
	fB1 = Vector3.new(8, 17, 1.4), fB2 = Vector3.new(8, 14, 1.4),
	capeA1 = Vector3.new(-1, 16, 1.6), capeA2 = Vector3.new(-1, 12, 2), capeB1 = Vector3.new(1, 16, 1.6), capeB2 = Vector3.new(1, 12, 2),
}
local body = {
	order = { "hips", "spine", "head", "wingL1", "wingL2", "wingL3", "fA1", "fA2", "fB1", "fB2", "capeA1", "capeA2", "capeB1", "capeB2" },
	parents = { spine = "hips", head = "spine", wingL1 = "spine", wingL2 = "wingL1", wingL3 = "wingL2", fA1 = "wingL1", fA2 = "fA1", fB1 = "wingL2", fB2 = "fB1", capeA1 = "spine", capeA2 = "capeA1", capeB1 = "spine", capeB2 = "capeB1" },
	heads = heads,
	scale = 6,
	physics = { chains = {
		{ Kind = "wing", Group = "wing", Column = 0, Bones = { "wingL1", "wingL2", "wingL3" }, Settings = {} },
		{ Kind = "wing", Group = "featherA", Column = 0, Bones = { "fA1", "fA2" }, Settings = { Pull = 0.2 } },
		{ Kind = "wing", Group = "featherB", Column = 0, Bones = { "fB1", "fB2" }, Settings = { Pull = 0.2 } },
		{ Kind = "cloth", Group = "cape", Column = 1, Bones = { "capeA1", "capeA2" }, Settings = {} },
		{ Kind = "cloth", Group = "cape", Column = 2, Bones = { "capeB1", "capeB2" }, Settings = {} },
	} },
}
local state = P.new(body, nil, 1)
local worstFeather, nan, drift, stretch = 0, 0, 0, 0
local started = os.clock()
for frame = 1, 480 do
	local posed = {}
	for name in heads do
		posed[name] = CFrame.identity
	end
	local flap = math.sin(frame / 60 * 6) * 0.9
	local flapped = CFrame.new(heads.wingL1) * CFrame.Angles(0, 0, flap) * CFrame.new(-heads.wingL1)
	for _, bone in { "wingL1", "wingL2", "wingL3", "fA1", "fA2", "fB1", "fB2" } do
		posed[bone] = flapped
	end
	P.step(state, 1 / 60, CFrame.new(math.sin(frame / 60) * 10, 0, 0), posed, frame / 60)
	local armA, armB = state.Chains[1].Position[1], state.Chains[1].Position[2]
	local anchor = state.Chains[2].Position[1]
	local along = math.clamp((anchor - armA):Dot(armB - armA) / (armB - armA).Magnitude ^ 2, 0, 1)
	worstFeather = math.max(worstFeather, (anchor - (armA + (armB - armA) * along)).Magnitude)
	for _, chain in state.Chains do
		for index, p in chain.Position do
			if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then
				nan += 1
			end
			if index < #chain.Position then
				stretch = math.max(stretch, math.abs((chain.Position[index + 1] - p).Magnitude - chain.Lengths[index]) / chain.Lengths[index])
			end
		end
	end
	drift = math.max(drift, math.abs((state.Chains[4].Position[2] - state.Chains[5].Position[2]).Magnitude - 2))
end
print(("levels=%d feather-to-arm %.2f studs nan=%d cape spacing drift %.2f max stretch %.1f%% %.3f ms/frame"):format(#state.Levels, worstFeather, nan, drift, stretch * 100, (os.clock() - started) / 480 * 1000))
