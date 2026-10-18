--!strict
-- Tooltips: the bubble never covers what it explains or the pointer, stays inside the screen,
-- and is wired into buttons, currencies, the collapsed rail and the rebirth chamber.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function v2(x: number, y: number)
	return setmetatable({ X = x, Y = y }, {
		__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end,
		__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end,
	})
end
local signal = { Connect = function() return { Disconnect = function() end } end }
local services = {
	Players = {},
	RunService = { RenderStepped = signal },
	GuiService = { GetGuiInset = function() return v2(0, 58), v2(0, 0) end },
	UserInputService = { InputChanged = signal, MouseEnabled = true, TouchEnabled = false },
	TweenService = {},
}
local env = setmetatable({
	game = { GetService = function(_, name) return services[name] end },
	workspace = { CurrentCamera = { ViewportSize = v2(1280, 720) } },
	Vector2 = { new = v2 },
	script = {},
}, { __index = _G })
local Tooltip = luau.load(fs.readFile("src/Client/AstralForge/Tooltip.luau"), { chunkName = "Tooltip", environment = env })() :: any

local function inside(p, s)
	return p.X >= 10 and p.Y >= 62 and p.X + s.X <= 1270 and p.Y + s.Y <= 710
end
local function covers(p, s, q, t)
	return p.X < q.X + t.X and q.X < p.X + s.X and p.Y < q.Y + t.Y and q.Y < p.Y + s.Y
end

local size = v2(200, 60)
-- room above: it goes above, centred, clear of the target
local target, tsize = v2(500, 400), v2(120, 44)
local spot, side = Tooltip._place(target, tsize, size)
assert(side == "above" and inside(spot, size) and not covers(spot, size, target, tsize), "above when there's room")
assert(math.abs(spot.X + 100 - 560) < 1, "centred on the target")
-- at the top of the screen: it drops below instead
spot, side = Tooltip._place(v2(500, 70), tsize, size)
assert(side == "below" and inside(spot, size), "below near the top bar")
-- in a corner: it slides along the edge, never off screen
spot, side = Tooltip._place(v2(1240, 70), v2(36, 36), size)
assert(inside(spot, size) and not covers(spot, size, v2(1240, 70), v2(36, 36)), "corner targets stay on screen")
-- the pointer is never under the bubble
local pointer = v2(560, 370)
spot, side = Tooltip._place(target, tsize, size, pointer)
assert(not covers(spot, size, pointer - v2(4, 4), v2(22, 26)), "bubble avoids the pointer")
-- a tall rail item on the left edge goes to its right
spot, side = Tooltip._place(v2(8, 300), v2(56, 52), v2(240, 80))
assert(inside(spot, v2(240, 80)) and not covers(spot, v2(240, 80), v2(8, 300), v2(56, 52)), "rail items get room")

assert(Tooltip.labelFor("Close.rebirthChamber") == "Close" and Tooltip.labelFor("Nonsense.x") == nil, "icon-only buttons get a name")

-- wiring
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau")
assert(ui:find("Tooltip.useTooltip(buttonRef,", 1, true), "Button takes tooltips")
assert(ui:find("Tooltip.useTooltip(juiceRef,", 1, true), "currencies explain themselves")
assert(ui:find("Tooltip.useTooltip(railRef,", 1, true), "the collapsed rail names its pages")
assert(ui:find("Tooltip.setEnabled(tooltipsOn)", 1, true), "the Tooltips setting is honoured")
local schema = fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau")
assert(schema:find('toggle("Tooltips", "interface"', 1, true), "a Tooltips switch in settings")
local core = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau")
assert(core:find("Tooltip.useTooltip(cardRef, props.tooltip)", 1, true), "rebirth choices explain themselves")

print("[TEST] tooltips: placement, pointer, edges and wiring")
