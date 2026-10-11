local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/Client/AstralForge/layoutGuard.luau"):gsub("\r\n", "\n")
local first = assert(source:find("\tfunction LayoutGuardController:checkResize(root)", 1, true))
local last = assert(source:find("\tfunction LayoutGuardController:onStart()", first, true))
local layout = fs.readFile("src/Client/AstralForge/LayoutKit.luau"):gsub("\r\n", "\n")
local planFirst = assert(layout:find('__defs["layoutGuardPlan"] = function()', 1, true)) + #'__defs["layoutGuardPlan"] = function()'
local planLast = assert(layout:find("return table.freeze(Plan)", planFirst, true)) + #"return table.freeze(Plan)" - 1
local Plan = luau.load(layout:sub(planFirst, planLast))()
local tryCount, abandoned = { blocked = 9 }, { blocked = true }
local model = {
	shortFight = { thrash = 3, p = 0.6, n = 8 },
	longFight = { thrash = 20, p = 0.8, n = 24 },
}
local stats = { bursts = 0 }
local diagnostics = require("../src/Client/AstralForge/LayoutDiagnostics").new(os.clock)
local controller = luau.load("local LayoutGuardController={}\n" .. source:sub(first, last - 1) .. "\nreturn LayoutGuardController", {
	environment = setmetatable({
		Plan = Plan, tryCount = tryCount, abandoned = abandoned,
		model = model, stats = stats, diagnostics = diagnostics,
	}, { __index = _G }),
})()
local self = setmetatable({ lastWidth = 1000, lastHeight = 800 }, { __index = controller })
assert(not self:checkResize({ AbsoluteSize = { X = 1000, Y = 800 } }))
assert(model.longFight.thrash == 20 and tryCount.blocked == 9, "no-op scans cannot reopen an owner fight")
assert(self:checkResize({ AbsoluteSize = { X = 375, Y = 667 } }))
assert(next(tryCount) == nil and next(abandoned) == nil)
for _, entry in model do assert(entry.thrash == 0, "even long-running fights must be reconsidered after resize") end
assert(model.longFight.p == 0.8 and model.longFight.n == 24, "retain learned inspection priorities")
assert(self.cursor == 1 and self.burstLeft == Plan.BURST_FRAMES and stats.bursts == 1)
assert(not self:checkResize({ AbsoluteSize = { X = 375, Y = 667 } }))
assert(stats.bursts == 1, "stable layout cannot continually reset repair budgets")
print("[TEST] LayoutGuard resize: old suppression/text-floor rejection reset, learned priorities retained, stable layouts bounded")
