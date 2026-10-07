local Engine = require("../src/Client/AstralForge/LayoutGuardEngine")

local function object(className, parent, x, y, width, height)
	local instance = {
		Parent = parent,
		AbsolutePosition = { X = x or 0, Y = y or 0 },
		AbsoluteSize = { X = width or 200, Y = height or 100 },
		Size = 100,
		Position = 0,
		ZIndex = 1,
		Visible = true,
		Text = "Example",
		TextFits = true,
		TextSize = 14,
		attributes = {},
	}
	function instance:IsA(name)
		return name == className or name == "GuiObject"
	end
	function instance:GetAttribute(name)
		return self.attributes[name]
	end
	function instance:GetFullName()
		return className
	end
	function instance:FindFirstChildWhichIsA()
		return nil
	end
	return instance
end

local parent = object("Frame", nil, 0, 0, 500, 500)
parent.Parent = {
	IsA = function()
		return false
	end,
	GetAttribute = function()
		return nil
	end,
}
local label = object("TextLabel", parent)
local now = 0
local engine = Engine.new(function()
	return now
end)
engine.beginFrame(1 / 60, false)
now = 0.0013
assert(not engine.hasBudget(), "ordinary frames must stop guard work after their CPU budget")
engine.beginFrame(1 / 20, true)
now += 0.0007
assert(not engine.hasBudget(), "slow frames receive a smaller budget even during a burst")
engine.endFrame()
assert(engine.diagnostics().metrics.frameMs > 0.6)

local repairs = 0
local function repair(instance)
	repairs += 1
	instance.TextSize = 12
end
assert(engine.inspect(label, repair) == "deferred")
label.AbsolutePosition.X = 30
assert(engine.inspect(label, repair) == "deferred" and repairs == 0, "moving geometry must settle before repair")
assert(engine.inspect(label, repair) == "verify")
assert(not engine.mayRepair(label), "an unverified write cannot be repaired again")
label.TextFits = false
assert(engine.inspect(label, repair) == "rollback")
assert(label.TextSize == 14 and not engine.mayRepair(label), "a worse repair must roll back and stop retrying")
engine.invalidate(label)
assert(engine.mayRepair(label))
assert(engine.inspect(label, repair) == "verify")
label.TextSize = 18
assert(
	engine.inspect(label, repair) == "superseded" and label.TextSize == 18,
	"React's newer value must survive verification"
)

local observed = object("TextLabel", parent)
parent.attributes.LayoutGuardMode = "observe"
observed.TextFits = false
assert(engine.inspect(observed, repair) == "deferred")
assert(engine.inspect(observed, repair) == "observed" and observed.TextSize == 14)
parent.attributes.LayoutGuardMode = "off"
assert(engine.inspect(observed, repair) == "ignored")
parent.attributes.LayoutGuardMode = nil
observed.attributes.LayoutGuardTransient = true
assert(engine.inspect(observed, repair) == "ignored", "authored animation can opt out")

local errored = object("TextLabel", parent)
engine.inspect(errored, function() end)
assert(engine.inspect(errored, function(instance)
	instance.ZIndex = 8
	error("broken repair")
end) == "error")
assert(errored.ZIndex == 1, "an exception must restore every captured property")

local sibling = object("TextButton", parent)
local edited = engine.repairGroup({ sibling }, function()
	sibling.ZIndex = 2
	parent.Position = 30
end)
assert(#edited == 2, "group transactions must include a moved action container")
assert(engine.needsVerification(parent) and engine.needsVerification(sibling))
engine.inspect(parent, function() end)
engine.inspect(sibling, function() end)
assert(not engine.needsVerification(parent) and engine.diagnostics().metrics.repaired >= 2)

local scroll = object("ScrollingFrame", parent, 0, 0, 100, 100)
local canvasChild = object("TextLabel", scroll, 0, 800, 100, 100)
assert(Engine.score(canvasChild) == 0, "offscreen canvas content is valid")
local nanParent = object("Frame", nil, 0 / 0)
assert(Engine.score(object("Frame", nanParent)) == 0, "invalid parent bounds cannot propagate NaN scores")

local items = {}
for index = 1, 100 do
	items[index] = object("TextButton", parent, index * 10, 140, 25, 80)
end
items[1].AbsoluteSize.X = 900
local iterator = Engine.pairIterator(items)
local pairs = {}
local checkpoints = 0
local calls = 0
while true do
	local pair = iterator()
	calls += 1
	assert(calls < 10000)
	if pair == nil then
		break
	elseif pair == false then
		checkpoints += 1
	else
		assert(#pair == 2)
		local key = tostring(table.find(items, pair[1])) .. ":" .. tostring(table.find(items, pair[2]))
		assert(not pairs[key], "multi-row geometry must not repeat collision pairs")
		pairs[key] = true
	end
end
assert(checkpoints > 0 and pairs["1:80"], "a wide hitbox must find distant overlaps without one unbounded repair pass")
for index = 1, 150 do
	local entry = object("TextLabel", parent)
	entry.TextFits = false
	entry.attributes.LayoutGuardMode = "observe"
	engine.inspect(entry, repair)
	engine.inspect(entry, repair)
end
local diagnostics = engine.diagnostics()
assert(#diagnostics.history == 128 and diagnostics.metrics.rolledBack == 1)
diagnostics.metrics.checked = -1
assert(engine.diagnostics().metrics.checked >= 0, "diagnostic snapshots must not expose mutable counters")
print(
	"[TEST] layout guard settling, CPU budgets, reversible/group repairs, authored overrides and incremental collision pairs passed"
)
