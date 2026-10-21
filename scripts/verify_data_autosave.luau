--!nocheck
-- DataService autosave: a profile left behind after a failed release save on leave keeps
-- retrying the release (never a session-renewing plain save), a lost-lock profile of a departed
-- player is dropped unwritten, and in-game players are saved only when dirty. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local DataService = H.load("Server/AstralForge/Services/DataService").DataService

local function fake()
	local self = setmetatable({ _profiles = {}, _dirty = {}, _broken = {}, saves = {}, cleared = {} }, { __index = DataService })
	-- roblox-ts Maps compile to plain tables
	function self:Save(player, release) table.insert(self.saves, { player, release == true }) return false end
	function self:_clearPlayer(player) self.cleared[player] = true self._profiles[player] = nil end
	return self
end

local inGameClean, inGameDirty, gone, goneBroken = H.player("A"), H.player("B"), H.player("C"), H.player("D")
gone.Parent = nil
goneBroken.Parent = nil
local svc = fake()
for _, p in { inGameClean, inGameDirty, gone, goneBroken } do svc._profiles[p] = {} end
svc._dirty[inGameDirty] = true
svc._dirty[gone] = true
svc._broken[goneBroken] = "SessionLockedError"
svc:_autosaveTick()

local byPlayer = {}
for _, s in svc.saves do byPlayer[s[1]] = s[2] end
check(byPlayer[inGameClean] == nil, "a clean in-game profile is not saved")
check(byPlayer[inGameDirty] == false, "a dirty in-game profile gets a plain save")
check(byPlayer[gone] == true, "a departed player's leftover profile retries the release save")
check(byPlayer[goneBroken] == nil and svc.cleared[goneBroken] == true, "a departed lost-lock profile is dropped, not written")
check(#svc.saves == 2, "exactly two saves issued")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("data autosave failed: %d problems", #failures))
end
print(string.format("[TEST] data autosave: %d checks (leftover release retry, lost-lock drop, dirty-only saves) passed", checks))
