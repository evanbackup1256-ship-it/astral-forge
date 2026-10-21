--!nocheck
-- Rebirth regressions (day-b batch 46), run against GameService from the compiled TS (out/)
-- through scripts/_server_harness. Kept apart from verify_gameplay_fixes because GameService
-- needs its network mocks in place before anything else loads. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
-- batch 46: rebirth caps cores at 1e14 like the save clamp, and a 0 bonus gives no Overdrive
do
	H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
	H.env.Enum = setmetatable({}, { __index = function(_, cat)
		return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
	end })
	local GS = H.load("Server/AstralForge/Services/GameService").GameService
	local DataTemplate = H.load("Server/AstralForge/DataTemplate")
	local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
	local function deepCopy(v)
		if type(v) ~= "table" then return v end
		local o = {}
		for k, x in v do o[k] = deepCopy(x) end
		return o
	end
	local one = setmetatable({}, { __index = function() return function() return 1 end end })
	local function rebirth(cores, bonus)
		local p = DataTemplate.New()
		p.RunCash, p.Cash, p.LifetimeCash, p.Cores = 1e12, 1e12, 1e12, cores
		local player = H.player()
		local data = { profile = p }
		function data:Update(_, cb)
			local d = deepCopy(self.profile)
			local r = cb(d)
			if not (type(r) == "table" and r.ok == false) then self.profile = d end
			return true, r
		end
		function data:AtomicUpdate(pl, cb) return self:Update(pl, cb) end
		function data:Get() return self.profile end
		local s = setmetatable({
			_data = data, _runtime = { [player] = {} }, _running = true,
			_antiCheat = { Observe = function() return nil, false end },
			_events = one, _convergence = one, _effect = H.Stub, _world = H.Stub,
			_pushState = function() end, _toastPlayer = function() end,
		}, { __index = function(_, k) local v = GS[k] if v ~= nil then return v end return H.Stub end })
		local rebirthConfig = GameConfig.Economy.Rebirth
		local old = rebirthConfig.BonusOverdrive
		rebirthConfig.BonusOverdrive = bonus
		local r = s:_rebirth(player, {})
		rebirthConfig.BonusOverdrive = old
		return r, data.profile
	end
	local r, p = rebirth(1e14 - 1, 1)
	check(r.ok == true and type(p.Cores) == "number" and p.Cores == 1e14, "rebirth cores capped at 1e14")
	check((p.BoostInventory.Overdrive or 0) == 1 and r.CelebrationBoost == "Overdrive", "bonus 1 gives one Overdrive")
	local r0, p0 = rebirth(0, 0)
	check(r0.ok == true and (p0.BoostInventory.Overdrive or 0) == 0, "bonus 0 gives no Overdrive")
	check(r0.CelebrationBoost == nil, "bonus 0 announces no boost")
	check(p0.Cores > 0 and p0.Cores == math.floor(p0.Cores), "small core rewards stay exact")
end

if #failures > 0 then
	error("rebirth fixes failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] rebirth fixes: %d checks passed", checks))
