--!nonstrict
local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Firewall = require("../src/Server/AstralForge/Modules/OpsMath")("RemoteFirewallMath")
local Tokens = require("../src/Client/AstralForge/MotionKit")("motionTokens")

local function source(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function extract(body, first, last)
	local start = assert(body:find(first, 1, true), first)
	local stop = assert(body:find(last, start, true), last)
	return body:sub(start, stop - 1)
end
local function load(body, environment)
	return luau.load(body, { environment = setmetatable(environment or {}, { __index = getfenv(0) }) })()
end
local Theme = load(source("src/Shared/AstralForge/Shared/ForgeTheme.luau"), { Color3 = roblox.Color3 })

local trade = source("src/Client/AstralForge/pages/PagesSocial.luau#TradeView")
local lists = extract(trade, "local BOOSTS =", "local BOOST_LABELS =")
local offerFunctions = extract(trade, "local function emptyOffer()", "local function itemName(")
local emptyOffer, wireOffer = load(lists .. offerFunctions .. "\nreturn emptyOffer, wireOffer")
local offer = emptyOffer()
offer.Cash = 50
offer.Boosts.Overdrive = 1
offer.Keys.ForgeCrate = 1
offer.ItemIds = { "item-1", "item-2", "item-3", "item-4", "item-5", "item-6" }
offer.Items = { { Name = "Server display only", Stats = { Damage = 100 } } }
local envelope = { Offer = table.clone(offer), Gen = 1, N = 2, Auth = "test", Txn = "test", TxnId = "test" }
envelope.Offer.Items = nil
assert(not Firewall.Inspect(envelope), "dense trade reproduces the default 32-entry rejection")
assert(Firewall.Inspect(envelope, nil, nil, nil, Firewall.TRADE_MAX_ENTRIES), "trade budget accepts all supported fields, six items and transport metadata")
assert(Firewall.ValidateTradeOffer(envelope.Offer, 6))
local compact = wireOffer(offer)
assert(compact.Items == nil and compact.Boosts.DomainSurge == nil and compact.Keys.EchoCrate == nil)
assert(compact.Boosts.Overdrive == 1 and compact.Keys.ForgeCrate == 1 and compact.Cash == 50)
assert(#compact.ItemIds == 6 and compact.ItemIds ~= offer.ItemIds, "wire IDs are isolated from the draft")
envelope.Offer = compact
assert(Firewall.Inspect(envelope), "normal sparse trade also fits the default budget")
assert(not Firewall.ValidateTradeOffer(offer, 6), "client cannot supply display snapshots")
for _, malformed in {
	{ Cash = -1 }, { Cash = 0.5 }, { Cash = math.huge }, { Cash = "50" },
	{ Boosts = { Overdrive = -1 } }, { Keys = { ForgeCrate = 0.5 } },
	{ ItemIds = { "1", "2", "3", "4", "5", "6", "7" } }, { ItemIds = { "" } },
	{ ItemIds = { [2] = "sparse" } }, { ItemIds = { Named = "not-an-array" } },
	{ ItemIds = { string.rep("x", 49) } }, { Unknown = 0 },
} do
	assert(not Firewall.ValidateTradeOffer(malformed, 6), "invalid trade offer must be rejected")
end
local excess = {}
for index = 1, 65 do excess[index] = index end
assert(not Firewall.Inspect(excess, nil, nil, nil, Firewall.TRADE_MAX_ENTRIES))
local cycle = {}
cycle.Self = cycle
assert(not Firewall.Inspect(cycle, nil, nil, nil, Firewall.TRADE_MAX_ENTRIES))
assert(not Firewall.Inspect({ A = { B = { C = { D = {} } } } }, nil, nil, nil, Firewall.TRADE_MAX_ENTRIES))
local firewallSource = source("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(firewallSource:find("if action == Protocol.Actions.UpdateTradeOffer then RemoteFirewallMath.TRADE_MAX_ENTRIES else nil", 1, true))
assert(firewallSource:find("RemoteFirewallMath.ValidateTradeOffer(payload.Offer, GameConfig.Trading.MaxItems)", 1, true))
assert(trade:find("offerSessionRef.current ~= sessionId", 1, true), "session changes invalidate pending offers")
assert(trade:find("revision ~= offerRevisionRef.current", 1, true), "stale offer replies cannot overwrite newer drafts")

for _, intensity in { 0, 0.1, 0.5, 1 } do
	local feel = Tokens.feel(620 * Tokens.responseScale(intensity), 48)
	assert(Tokens.settleSeconds(feel) <= 0.4, "low motion intensity must not slow controls")
	local referenceX, referenceV = Tokens.step(0, 0, 1, feel, 1)
	for _, fps in { 15, 30, 60, 144 } do
		local x, v = 0, 0
		for _ = 1, fps do x, v = Tokens.step(x, v, 1, feel, 1 / fps) end
		assert(math.abs(x - referenceX) < 1e-8 and math.abs(v - referenceV) < 1e-8, "spring timing is frame-rate independent")
	end
end
local motion = source("src/Client/AstralForge/MotionKit.luau#motion")
assert(motion:find("if atRest and math.abs(raw:getValue() - goal) < 1e-7 then", 1, true), "settled motors are not restarted by unchanged goals")
assert(motion:find("driver:Disconnect()", 1, true), "idle motion driver disconnects")
local driverBody = extract(motion, "function stopDriverIfIdle()", "local function subscribe(")
local countNames = { "flipperCount", "listenerCount", "continuousListenerCount", "realtimeClockCount", "decorativeClockCount", "pendingArrivalCount" }
local stopDriver = load("return function(driver, " .. table.concat(countNames, ", ") .. ")\n"
	.. driverBody:gsub("function stopDriverIfIdle", "local function stopDriverIfIdle")
	.. "\nstopDriverIfIdle()\nreturn driver\nend")
for activeIndex, activeCount in countNames do
	local disconnects = 0
	local driver = { Disconnect = function() disconnects += 1 end }
	local counts = { 0, 0, 0, 0, 0, 0 }
	counts[activeIndex] = 1
	driver = stopDriver(driver, table.unpack(counts))
	assert(disconnects == 0 and driver ~= nil, activeCount .. " keeps the shared driver alive")
	counts[activeIndex] = 0
	driver = stopDriver(driver, table.unpack(counts))
	driver = stopDriver(driver, table.unpack(counts))
	assert(disconnects == 1 and driver == nil, "idle disconnect is idempotent")
end
local arms = 0
local fakeMotor = {}
function fakeMotor.new(initial)
	local raw = { value = initial }
	function raw:onComplete(callback) self.complete = callback end
	function raw:onStep(callback) self.change = callback end
	function raw:getValue() return self.value end
	function raw:setGoal(goal) self.goal = goal end
	function raw:step()
		self.value = self.goal._targetValue
		self.change(self.value)
		self.complete()
		return true
	end
	function raw:stop() end
	function raw:destroy() self.destroyed = true end
	return raw
end
local createMotor = load(extract(motion, "local function createFlipperMotor(", "local nativePackageCache =") .. "\nreturn createFlipperMotor", {
	SingleMotor = fakeMotor, MotionTokens = Tokens,
	Spring = { new = function(initial) return { _targetValue = initial } end },
	Instant = { new = function(initial) return { _targetValue = initial } end },
	armFlipper = function() arms += 1 end,
	disarmFlipper = function() end, stopDriverIfIdle = function() end,
})
local motor = createMotor(0, 620, 48)
motor:setGoal(0)
assert(arms == 0, "unchanged initial goals do not allocate driver work")
motor:setGoal(1)
assert(arms == 1, "changed goals still animate")
motor.raw:step()
motor:setGoal(1)
assert(arms == 1, "completed goals remain idle")
motor:setPosition(0)
motor:setGoal(0)
assert(arms == 1, "instant positioning does not restart a settled motor")
motor:destroy()
motor:setGoal(1)
assert(arms == 1 and motor.raw.destroyed, "disposed motors cannot rearm")

local ui = source("src/Client/AstralForge/UiCore.luau#ui")
assert(not ui:find("math.round(-lift", 1, true), "panel motion retains subpixel precision")
assert(ui:find("setNarrow(instance.AbsoluteSize.X < 360)", 1, true), "steppers respond to their own row width")
local guard = source("src/Client/AstralForge/layoutGuard.luau")
assert(guard:find("FRAME_BUDGET_SECONDS = 0.0015", 1, true))
assert(guard:find("os.clock() < self.deadline", 1, true), "layout scanning yields to the frame deadline")
assert(guard:find("elseif self.overlapPhase == 2 then", 1, true), "collision passes are spread across frames")
local trackedClass = extract(guard, "local function isTrackedClass(", "local function repairText(")
local isTracked = load(trackedClass .. "\nreturn isTrackedClass", { IGNORE_ATTRIBUTE = "LayoutGuardIgnore", isFloatingPanel = function() return false end })
local function instance(class, parent, ignored)
	return {
		Parent = parent,
		IsA = function(_, wanted) return wanted == class end,
		GetAttribute = function(_, attribute) return attribute == "LayoutGuardIgnore" and ignored == true end,
	}
end
local layer = instance("LayerCollector")
local root = instance("Frame", layer, true)
local glyph = instance("TextLabel", instance("Frame", root))
assert(not isTracked(glyph), "layout-owned descendants inherit their ancestor's exclusion")
root.GetAttribute = function() return false end
assert(isTracked(glyph), "ordinary text still receives layout repairs")
local presence = source("src/Client/AstralForge/ArtifactPresence.luau")
local spriteStep = extract(presence, "spriteClock += dt", "if not advance or GuiService.ReducedMotionEnabled")
local sprites = load(source("src/Shared/AstralForge/Shared/ElementSprites.luau"), { Color3 = roblox.Color3, Vector2 = roblox.Vector2 })
assert(#sprites.ORDER == 57 and sprites.SOURCE_FRAME == 682 and sprites.SOURCE_EDGE == 4096 and sprites.UI_EDGE == 1024 and sprites.FRAME == 170.5 and sprites.COLUMNS == 6 and sprites.COUNT == 36, "source resolution must not be confused with delivered UI crop coordinates")
for _, element in sprites.ORDER do
	local animation = sprites.animation(element)
	assert(animation and animation.Spritesheet == sprites.sheet(element).Image)
	assert(animation.SpriteSize == roblox.Vector2.new(170.5, 170.5) and animation.SpriteCount == 36)
	for index = 0, sprites.COUNT - 1 do
		local x, y = (index % sprites.COLUMNS) * sprites.FRAME, math.floor(index / sprites.COLUMNS) * sprites.FRAME
		assert(x + sprites.FRAME <= 1024 and y + sprites.FRAME <= 1024, "every playback crop stays inside the delivered UI texture")
		assert(x * 4 == (index % sprites.COLUMNS) * sprites.SOURCE_FRAME and y * 4 == math.floor(index / sprites.COLUMNS) * sprites.SOURCE_FRAME, "fractional playback coordinates must preserve exact source frame boundaries")
	end
end
local tickSprite = load("return function(spriteClock, spriteFrame, dt)\nlocal frameStep = 1 / ElementSprites.FRAMERATE\n"
	.. spriteStep .. "\nreturn spriteClock, spriteFrame\nend", { ElementSprites = sprites })
for _, fps in { 15, 30, 60, 144 } do
	local clock, frame = 0, 0
	for _ = 1, fps * 2 do clock, frame = tickSprite(clock, frame, 1 / fps) end
	local expected = (sprites.FRAMERATE * 2) % sprites.COUNT
	assert(math.abs(frame - expected) <= 1, "dropped frames must not slow artifact sprites")
end

local titles = source("src/Client/AstralForge/ReactHosts.luau#HyperTextHost")
local kinds = assert(titles:match("local TITLE_FX_KINDS = (%b{})"))
local accents = extract(titles, "local FX_ACCENT =", "local function titleFxAccent")
local markupFunctions = extract(titles, "local function colorTag(", "local function buildMarkup(")
local colorFunctions = extract(source("src/Client/AstralForge/CoreKit.luau#theme"), "local function lighten(", "local function linearChannel(")
local buildKindMarkup = load(colorFunctions .. accents .. markupFunctions .. "\nreturn buildKindMarkup", { Palette = Theme.newPalette(), Color3 = roblox.Color3 })
local count = 0
for _, kind in load("return " .. kinds) do
	local markup = buildKindMarkup(kind, "ASTRAL")
	assert(type(markup) == "string" and markup:find("ASTRAL", 1, true), kind .. " retains its title text")
	for tag in markup:gmatch("<anim=[^>]+>") do
		local animation = tag:match("<anim=([%w%-]+)")
		if animation == "slide" or animation == "bounce" then
			local direction = tag:match("dir=([%w%-]+)")
			assert(direction == "up" or direction == "down", kind .. " has an unsupported vertical animation direction")
		end
	end
	count += 1
end
assert(count >= 37, "all title styles are exercised")
local spinner = source("src/Client/AstralForge/ReactHosts.luau#NumberSpinnerHost")
local display = extract(spinner, "local function spinDisplay(", "local function formatRawLabel(")
local callback = extract(spinner, "local pushDisplay = React.useCallback(", "local ensureSpinner =")
local style = { current = { size = 20, color = "cream", align = "left", prefix = "+", extraSuffix = " FLUX", spacedSuffix = true } }
local quiet = { current = {} }
local pushDisplay = load(display .. callback .. "\nreturn pushDisplay", {
	React = { useCallback = function(fn) return fn end },
	compactSpinParts = function(value) return { value = value, decimals = 0, suffix = "K" } end,
	styleRef = style, quietChromeRef = quiet, lastMantissaRef = {}, lastBandRef = {}, lastRawRef = {},
	sanitizeValue = function(value) return value end,
	applyChrome = function(target, opts) target.Suffix = opts.suffix end,
	setDigitTracking = function() end, pulseAccent = function() end,
})
local target = {}
pushDisplay(target, 10, 0, false)
assert(target.Suffix == " K FLUX")
style.current.extraSuffix = " CORES"
pushDisplay(target, 10, 0, false)
assert(target.Suffix == " K CORES", "unit labels update even when the numeric amount is unchanged")
style.current.spacedSuffix = false
pushDisplay(target, 10, 0, false)
assert(target.Suffix == "K CORES", "spacing changes propagate without requiring a numeric update")
local feedback = source("src/Client/AstralForge/UiCore.luau#FeedbackOverlay")
local pixelSource = extract(ui, "local function pixelPosition(", "local function fontForWeight(")
local pixelPosition = load(pixelSource .. "\nreturn pixelPosition", { UDim2 = roblox.UDim2 })
local resize, cleanup, disconnected = nil, nil, 0
local measured = {}
local host = {
	AbsoluteSize = roblox.Vector2.new(200, 48),
	IsA = function(_, class) return class == "GuiObject" end,
	GetPropertyChangedSignal = function(_, property)
		assert(property == "AbsoluteSize")
		return { Connect = function(_, callback)
			resize = callback
			return { Disconnect = function() disconnected += 1 end }
		end }
	end,
}
local useSize = load(extract(ui, "local function useGuiSize(", "local function pixelPosition(") .. "\nreturn useGuiSize", {
	Vector2 = roblox.Vector2,
	React = {
		useBinding = function(initial)
			measured.current = initial
			return measured, function(value) measured.current = value end
		end,
		useEffect = function(effect) cleanup = effect() end,
	},
})
assert(useSize({ current = { Parent = host } }, true).current.Y == 48)
host.AbsoluteSize = roblox.Vector2.new(360, 80)
resize()
assert(measured.current.Y == 80, "motion responds to resized hosts without a per-frame size lookup")
cleanup()
assert(disconnected == 1, "motion size subscriptions disconnect when the component leaves")
assert(roblox.UDim2.fromOffset(0.16, 0.16).Y.Offset == 0, "reproduce Roblox's integer offset truncation")
for _, dimensions in { roblox.Vector2.new(360, 740), roblox.Vector2.new(991, 537) } do
	for _, offset in { -1.4, -0.01, 0, 0.16, 16 } do
		local position = pixelPosition(dimensions, 0.5, offset, 0.5, offset)
		local x = (position.X.Scale - 0.5) * dimensions.X + position.X.Offset
		local y = (position.Y.Scale - 0.5) * dimensions.Y + position.Y.Offset
		assert(math.abs(x - offset) < 0.0001 and math.abs(y - offset) < 0.0001, "measured coordinates retain fractional pixel travel")
	end
end
assert(feedback:find("pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * cardTravel)", 1, true))
assert(ui:find("Position = surfacePosition", 1, true), "shared buttons apply measured subpixel motion")
local buttonStart=assert(ui:find("function Button(",1,true))
local iconLabelStart=assert(ui:find("ref = pinButtonLabel",buttonStart,true))
local iconLabelEnd=assert(ui:find("})), not iconOnly and not hasIcon",iconLabelStart,true))
assert(ui:sub(iconLabelStart,iconLabelEnd):find("ZIndex = zIndex + 3",1,true),"icon-bearing button labels stay above the button surface even on Global-Z hosts")
local panel = extract(ui, "local function Panel(", "local function Divider(")
assert(panel:find("local panelSize = useGuiSize(panelRef)", 1, true), "shared panels measure their motion host")
assert(panel:find("ref = panelRef", 1, true), "panel measurement is attached to its stable outer frame")
assert(panel:find("pixelPosition(values[2], 0, -4, 0, 7 + values[1])", 1, true), "panel shadows preserve fractional entrance and hover travel")
assert(panel:find("pixelPosition(values[2], 0, 0, 0, values[1])", 1, true), "panel surfaces preserve fractional entrance and hover travel")
local domainTree = source("src/Client/AstralForge/UiOverlays.luau#DomainSkillTree")
local domainExpansion = source("src/Client/AstralForge/UiOverlays.luau#DomainExpansionOverlay")
assert(domainTree:find("local hostSize = useGuiSize(hostRef)", 1, true), "domain tree measures its overlay host")
assert(domainTree:find("pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 22)", 1, true), "domain tree transitions retain fractional pixels")
assert(domainExpansion:find("local parentSize = useGuiSize(cardRef, true)", 1, true), "domain confirmation measures its card parent")
assert(domainExpansion:find("ref = cardRef", 1, true), "domain confirmation attaches its measurement ref")
assert(domainExpansion:find("pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 30)", 1, true), "domain confirmation transitions retain fractional pixels")
local roadmap = source("src/Client/AstralForge/UiCore.luau#levelRoadmap")
assert(roadmap:find("local parentSize = useGuiSize(cardRef, true)", 1, true))
assert(roadmap:find("cardRef.current = node", 1, true), "roadmap preserves focus while measuring its parent")
assert(roadmap:find("pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 12)", 1, true))
local offline = source("src/Client/AstralForge/UiCore.luau#OfflineRewardsOverlay")
assert(offline:find("local parentSize = useGuiSize(overlayHostRef, true)", 1, true))
assert(offline:find("pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 18)", 1, true))
local report = extract(source("src/Client/AstralForge/UiCore.luau#PlayerlistOverlay"), "local function ReportSheet(", "local function PlayerlistOverlay(")
assert(report:find("local hostSize = useGuiSize(hostRef)", 1, true))
assert(report:find("ref = hostRef", 1, true))
assert(report:find("pixelPosition(values[2], 0.5, 0, 0.5, (1 - math.clamp(values[1], 0, 1)) * 24)", 1, true))
local playerlist = source("src/Client/AstralForge/UiCore.luau#PlayerlistOverlay")
assert(playerlist:find("local listParentSize = useGuiSize(padFocus, true)", 1, true))
assert(playerlist:find("pixelPosition(values[2], 1, -side + (1 - values[1]) * 24, 0, top)", 1, true))
local notifications = source("src/Client/AstralForge/UiCore.luau#notifications")
assert(notifications:find("local slotSizePixels = useGuiSize(slotRef)", 1, true))
assert(notifications:find("ref = slotRef", 1, true))
assert(notifications:find("pixelPosition(values[4], 0.5, values[1] + values[2], 0.5, values[3])", 1, true))
assert(feedback:find('Name = "Impact" .. level', 1, true), "feedback impact controls are individually identifiable")
assert(feedback:find("value = tostring(level)", 1, true), "impact levels must be visible before selection")
assert(feedback:find('Suggestion = "IDEA"', 1, true), "the suggestion category fits its selected tab")
assert(feedback:find("elseif narrow then 30 + TapTarget + 4 else 30", 1, true), "phone impact controls have a separate touch-sized row")
local tapTarget = assert(tonumber(source("src/Client/AstralForge/CoreKit.luau#theme"):match("local TapTarget = (%d+)")))
for _, width in { 288, 340, 390, 620 } do
	local pipWidth = math.min(tapTarget, (width - 28 - 16) / 5)
	assert(pipWidth * 5 + 4 * 4 <= width - 28, "all five impact controls fit inside the card")
	if width >= 288 then assert(pipWidth >= tapTarget, "standard phone cards retain touch-sized impact controls") end
end
print(`[INFO] [TEST] 7.0 polish passed | trade, stale sessions, motor cleanup, subpixel motion, layout deadlines, sprite timing at 15-144 fps, {count} title styles`)