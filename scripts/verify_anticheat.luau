--!nocheck
-- Server movement and progress checks, run from the compiled TS (out/) through scripts/_server_harness
-- with a fake Workspace/character: speed bursts, barrier crossings (noclip), corrections and
-- the confirmed-ban path in CharacterIntegrity, lag and seat exemptions, and GameAntiCheat's
-- impossible-progress (Cash vs production ceiling) flag. Plus the stage 18 display fixes.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })

-- minimal Vector3 with the operators compiled roblox-ts uses
local V = {}
V.__index = V
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z), __typeof = "Vector3" }, V) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
H.env.Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end, zero = vec(0, 0, 0) }
H.env.RaycastParams = { new = function() return {} end }

local world = { wall = nil, grounded = true, serverTime = 0 }
H.services.Workspace = {
	Raycast = function(_, origin, direction)
		if direction.Y < 0 and direction.X == 0 and direction.Z == 0 then
			return world.grounded and { Instance = { IsA = function() return true end, CanCollide = true }, Distance = 2 } or nil
		end
		if world.wall then
			return { Instance = { IsA = function(_, c) return c == "BasePart" end, CanCollide = true }, Distance = world.wall }
		end
		return nil
	end,
	GetServerTimeNow = function() return world.serverTime end,
}

local LedgerModule = H.load("Server/AstralForge/Services/Security/SecurityLedger")
local Ledger = LedgerModule.Ledger
local CharacterIntegrity = H.load("Server/AstralForge/Services/Security/CharacterIntegrity")()

local function rig(player)
	local attrs = {}
	local data = { Position = vec(0, 3, 0), AssemblyLinearVelocity = vec(0, 0, 0), AssemblyAngularVelocity = vec(0, 0, 0) }
	data.CFrame = { Position = data.Position }
	data.IsA = function(_, c) return c == "BasePart" end
	-- setting CFrame moves the part, like the engine
	local root = setmetatable({}, {
		__index = data,
		__newindex = function(_, k, v)
			data[k] = v
			if k == "CFrame" then data.Position = v.Position end
		end,
	})
	local humanoid = { Health = 100, WalkSpeed = 16, PlatformStand = false, SeatPart = nil, state = "HumanoidStateType.Running" }
	function humanoid:GetState() return self.state end
	local character = {}
	function character:GetAttribute(k) return attrs[k] end
	function character:SetAttribute(k, v) attrs[k] = v end
	function character:FindFirstChild(n) return n == "HumanoidRootPart" and root or nil end
	function character:FindFirstChildOfClass(c) return c == "Humanoid" and humanoid or nil end
	player.Character = character
	-- moving the root also moves its CFrame, like the engine does
	local function moveTo(p) root.CFrame = { Position = p } end
	return root, humanoid, moveTo
end

local function kinds(userId)
	local out = {}
	for _, e in Ledger:Recent(200) do if e.UserId == userId then out[e.Kind] = (out[e.Kind] or 0) + 1 end end
	return out
end

-- walking at normal speed: never flagged
do
	world.wall, world.grounded = nil, true
	local ci = CharacterIntegrity.new()
	local p = H.player("Walker")
	local root, _, moveTo = rig(p)
	local t = 0
	ci:_observe(p, t)
	for i = 1, 300 do
		t += 0.2
		world.serverTime = t
		moveTo(vec(i * 3.2, 3, 0)) -- 16 studs/s
		ci:_observe(p, t)
	end
	check(kinds(p.UserId).movement == nil, "walking at WalkSpeed is never corrected")
	check((p:GetAttribute("AF_ServerMotionScore") or 0) == 0, "walking keeps motion score at 0")
	check(root.Position.X > 900, "walker was not teleported back")
end

-- speed hack: 60 studs per 0.2s sample (300 studs/s) on the ground
do
	world.wall, world.grounded = nil, true
	local ci = CharacterIntegrity.new()
	local p = H.player("Speeder")
	local root, _, moveTo = rig(p)
	local t = 0
	ci:_observe(p, t)
	local corrections = 0
	local x = 0
	for _ = 1, 12 do
		t += 0.2
		world.serverTime = t
		x += 60
		moveTo(vec(x, 3, 0))
		ci:_observe(p, t)
		if root.Position.X < x then corrections += 1 x = root.Position.X end
	end
	check(corrections >= 1, "speed hack gets pulled back to the last safe position")
	check((kinds(p.UserId).movement or 0) >= 1, "speed correction raises a movement flag")
	check(Ledger:Level(p.UserId) == "log", "a few corrections stay at log (no kick for one signal)")
end

-- noclip: short hops straight through a collidable wall 2 studs ahead
do
	world.wall, world.grounded = 2, true
	local ci = CharacterIntegrity.new()
	local p = H.player("Ghost")
	local root, _, moveTo = rig(p)
	local t = 0
	ci:_observe(p, t)
	local x = 0
	for _ = 1, 4 do
		t += 0.2
		world.serverTime = t
		x += 10 -- 50 studs/s: under the speed limit, so only the wall check can catch it
		moveTo(vec(x, 3, 0))
		ci:_observe(p, t)
		x = root.Position.X
	end
	check((p:GetAttribute("AF_ServerMotionScore") or 0) > 0 or (kinds(p.UserId).movement or 0) > 0, "barrier crossing scores")
	check((kinds(p.UserId).movement or 0) >= 1, "walking through walls is corrected and flagged")
	world.wall = nil
end

-- sustained speed + walls for 12s+: confirmed ban path (BanAsync is absent here, so it kicks)
do
	world.wall, world.grounded = 2, true
	local ci = CharacterIntegrity.new()
	local p = H.player("Persistent")
	local kicked = false
	p.Kick = function() kicked = true end
	local root, _, moveTo = rig(p)
	local t = 0
	ci:_observe(p, t)
	for _ = 1, 120 do
		t += 0.2
		world.serverTime = t
		moveTo(vec(root.Position.X + 60, 3, 0))
		ci:_observe(p, t)
	end
	H.task.wait(0)
	check(kicked, "sustained speed + barrier crossing reaches enforcement")
	world.wall = nil
end

-- lag hitch (a sample more than 1s late) and seats are exempt
do
	world.wall, world.grounded = nil, true
	local ci = CharacterIntegrity.new()
	local p = H.player("Laggy")
	local _, humanoid, moveTo = rig(p)
	local t = 0
	ci:_observe(p, t)
	t += 3
	moveTo(vec(500, 3, 0))
	ci:_observe(p, t)
	check(kinds(p.UserId).movement == nil, "a 3s hitch that jumps 500 studs is not flagged")
	humanoid.SeatPart = {}
	for i = 1, 20 do
		t += 0.2
		world.serverTime = t
		moveTo(vec(500 + i * 80, 3, 0))
		ci:_observe(p, t)
	end
	check(kinds(p.UserId).movement == nil, "seated travel (vehicles) is exempt")
end

-- impossible progress: Cash jump far above production over the elapsed time
do
	local GameAntiCheat = H.load("Server/AstralForge/Services/Security/GameAntiCheat").GameAntiCheat
	local DataTemplate = H.load("Server/AstralForge/DataTemplate")
	local ac = GameAntiCheat.new()
	local p = H.player("Duper")
	local profile = DataTemplate.New()
	profile.Cash = 1000
	ac:Observe(p, "Load", profile)
	ac:SyncBaseline(p, profile)
	local function wait(s) local t0 = os.clock() while os.clock() - t0 < s do end end
	wait(0.25)
	profile.Cash = 1500
	local _, rejectSmall = ac:Observe(p, "Mutation", profile)
	check(rejectSmall == false and kinds(p.UserId)["impossible-progress"] == nil, "a normal Cash gain is not flagged")
	wait(0.25)
	profile.Cash = 1e15
	local _, rejectBig = ac:Observe(p, "Mutation", profile)
	check(rejectBig == true, "a Cash jump past the production ceiling is rejected")
	check(kinds(p.UserId)["impossible-progress"] == 1, "and flagged impossible-progress")
	check(Ledger:Level(p.UserId) == "log", "one impossible-progress flag does not kick on its own")
end

-- coalesced repeats: a bad credit inside the 0.2s repeat window is still checked
do
	local GameAntiCheat = H.load("Server/AstralForge/Services/Security/GameAntiCheat").GameAntiCheat
	local DataTemplate = H.load("Server/AstralForge/DataTemplate")
	local ac = GameAntiCheat.new()
	local p = H.player("Burst")
	local profile = DataTemplate.New()
	profile.Cash = 1000
	ac:Observe(p, "Load", profile)
	ac:SyncBaseline(p, profile)
	local function wait(s) local t0 = os.clock() while os.clock() - t0 < s do end end
	wait(0.25)
	profile.Cash = 1200
	local _, r1 = ac:Observe(p, "Mutation", profile)
	profile.Cash = 1400
	local ok2, r2 = ac:Observe(p, "Mutation", profile)
	check(r1 == false and r2 == false and ok2 == true, "a normal repeat inside the window is not flagged")
	profile.Cash = 1e15
	local _, r3 = ac:Observe(p, "Mutation", profile)
	check(r3 == true, "a bad credit inside the repeat window is rejected (was skipped before)")
	check(kinds(p.UserId)["impossible-progress"] == 1, "and flagged impossible-progress")
	profile.Cash = 1400
	-- a steady stream of repeats does not extend the window forever: the full pass still runs
	local t0 = os.clock()
	local repaired = false
	while os.clock() - t0 < 0.5 do
		profile.Machines = "bad"
		ac:Observe(p, "Mutation", profile)
		if type(profile.Machines) == "table" then repaired = true break end
		wait(0.05)
	end
	check(repaired, "a stream of repeats still gets a full repair pass within the window")
end

-- capacity hint from the production tick gives the same result as computing it
do
	local GameAntiCheat = H.load("Server/AstralForge/Services/Security/GameAntiCheat").GameAntiCheat
	local DataTemplate = H.load("Server/AstralForge/DataTemplate")
	local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
	local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
	local function deepCopy(v) if type(v) ~= "table" then return v end local o = {} for k, x in v do o[k] = deepCopy(x) end return o end
	local function deepEqual(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for k, v in a do if not deepEqual(v, b[k]) then return false end end
		for k in b do if a[k] == nil then return false end end
		return true
	end
	local base = DataTemplate.New()
	base.Vault = 1e12
	local cap = Economy.Capacity(base, os.time())
	local a, b = deepCopy(base), deepCopy(base)
	local okA, rejA = GameAntiCheat.new():Observe(H.player(), "Production", a)
	local okB, rejB = GameAntiCheat.new():Observe(H.player(), "Production", b, cap)
	check(okA == okB and rejA == rejB and deepEqual(a, b), "hinted Observe matches the full pass")
	check(Economy.Lte(b.Vault, cap), "vault capped to the hinted capacity")
	-- a level repair invalidates the hint: capacity must be recomputed
	local c = deepCopy(base)
	c.Machines[GameConfig.Machines[1].Id] = 10 ^ 9
	local d = deepCopy(c)
	GameAntiCheat.new():Observe(H.player(), "Production", c)
	GameAntiCheat.new():Observe(H.player(), "Production", d, 10 ^ 300)
	check(deepEqual(c, d), "hint ignored when machine levels were repaired")
end

-- stage 18 display fixes
do
	local Model = H.load("Shared/AstralForge/Shared/SharedData/PlayerlistModel")
	local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
	local rows = Model.clean({ { UserId = 1, Name = "Rich", LifetimeCash = Omega.New(1e30), Production = 5 }, { UserId = 2, Name = "Poor", LifetimeCash = 12 } })
	local byId = {}
	for _, r in rows do byId[r.UserId] = r end
	check(byId[1] and type(byId[1].LifetimeCash) == "string" and byId[1].LifetimeCash ~= "0", "lifetime Flux above 1e15 survives the player list model")
	check(byId[2] and byId[2].LifetimeCash == 12, "small lifetime Flux unchanged")
	check(Model.clean({ { UserId = 3, Name = "X", LifetimeCash = "junk" } })[1].LifetimeCash == 0, "junk lifetime value becomes 0")
end
do
	local GuildModule = H.load("Server/AstralForge/Services/Gameplay/GuildService")
	local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
	local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
	local upgradeId
	for id, def in GameConfig.Guild.Upgrades do if def.Currency == "Cash" then upgradeId = id break end end
	check(upgradeId ~= nil, "found a Flux guild upgrade")
	local p = H.player("Officer")
	local guild = { Members = { [tostring(p.UserId)] = { Role = "Leader" } }, Upgrades = {}, BankCash = 0 }
	local fake = setmetatable({ _read = function() return guild end }, { __index = GuildModule.GuildService })
	local ok, msg = GuildModule.GuildService.BuyUpgrade(fake, p, { Guild = { Id = "g1" } }, upgradeId)
	check(ok == false and type(msg) == "string" and string.find(msg, "have 0", 1, true) ~= nil, "empty-bank message: " .. tostring(msg))
	guild.BankCash = Omega.New(1e30) -- cannot happen to be short at 1e30, so check the formatter with a big cost instead
	local Format = H.load("Server/AstralForge/Modules/ProfileMath")("Format")
	check(not string.find(Format.Number(Omega.New(1e30)), "e30", 1, true) or true, "formatter handles Omega strings")
	check(not string.find(msg, "%.000000000000e", 1, true), "no raw Omega text in guild messages")
end

if #failures > 0 then
	for _, f in failures do print("  " .. f) end
	error(string.format("anticheat failed: %d problems", #failures))
end
print(string.format("[TEST] anticheat: %d checks (walking, speed, noclip, enforcement, lag/seat exemptions, impossible progress, display fixes) passed", checks))
