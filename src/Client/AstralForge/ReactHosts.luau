--!nonstrict
--[=[
	ReactHosts: merged module suite.
	Members (8): reactModules, vendorHost, reactHost, HyperTextHost, RichTextHost, NumberSpinnerHost, egooeHost, AnimatedTitle.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("ReactHosts: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("ReactHosts: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: reactModules   (merged from reactModules.luau, 206 lines)
-- ======================================================================
__defs["reactModules"] = function()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function childOf(parent, name)
	if typeof(parent) ~= "Instance" then
		return nil
	end
	return parent:FindFirstChild(name)
end

local include = childOf(ReplicatedStorage, "rbxts_include")
local importTsModule = nil
do
	local importScript = childOf(include, "TSImport")
	if importScript ~= nil and importScript:IsA("ModuleScript") then
		local ok, loaded = pcall(require, importScript)
		if ok and type(loaded) == "function" then
			importTsModule = loaded
		end
	end
end
local packages = childOf(childOf(include, "node_modules"), "@rbxts")
local hooksPackage = childOf(packages, "pretty-react-hooks")
local hooksRoot = childOf(hooksPackage, "out")
local loaded = {}

local function resolveHookScript(folder)
	local hookRoot = childOf(hooksRoot, folder)
	if hookRoot == nil then
		return nil
	end
	if hookRoot:IsA("ModuleScript") then
		return hookRoot
	end
	local initScript = childOf(hookRoot, "init")
	if initScript ~= nil and initScript:IsA("ModuleScript") then
		return initScript
	end
	return nil
end

local function load(folder)
	local existing = loaded[folder]
	if existing ~= nil then
		if existing == false then
			return nil
		end
		return existing
	end
	local moduleScript = resolveHookScript(folder)
	if moduleScript == nil or importTsModule == nil then
		loaded[folder] = false
		return nil
	end
	local ok, pkg = pcall(importTsModule, moduleScript)
	if not ok or type(pkg) ~= "table" then
		loaded[folder] = false
		return nil
	end
	loaded[folder] = pkg
	return pkg
end

local function hookFunction(folder, name)
	local pkg = load(folder)
	if type(pkg) ~= "table" then
		return nil
	end
	local fn = pkg[name]
	if type(fn) ~= "function" then
		return nil
	end
	return fn
end

local function callable(callback)
	local invoke = function(...)
		if type(callback) == "function" then
			return callback(...)
		end
		return nil
	end
	-- Debounce fallback: callers use `.run(...)` and `.flush()` as well as calling
	-- the object. `run` fires immediately (no debounce available), and `flush`
	-- has nothing pending, so it must NOT invoke the callback with no arguments
	-- (that used to wipe the parent's filter text on focus loss and unmount).
	return setmetatable({
		run = invoke,
		flush = function() end,
		cancel = function() end,
	}, {
		__call = function(_, ...)
			return invoke(...)
		end,
	})
end

local function useLatestCallback(callback)
	local fn = hookFunction("use-latest-callback", "useLatestCallback")
	if fn == nil then
		return callable(callback)
	end
	return fn(callback)
end

local function useDebounceCallback(callback, options)
	local fn = hookFunction("use-debounce-callback", "useDebounceCallback")
	if fn == nil then
		return callable(callback)
	end
	return fn(callback, options)
end

local function useDebounceState(initialState, options)
	local fn = hookFunction("use-debounce-state", "useDebounceState")
	if fn == nil then
		return initialState, function() end
	end
	return fn(initialState, options)
end

local function usePrevious(value, predicate)
	local fn = hookFunction("use-previous", "usePrevious")
	if fn == nil then
		return nil
	end
	return fn(value, predicate)
end

local function useMountEffect(callback)
	local fn = hookFunction("use-mount-effect", "useMountEffect")
	if fn == nil then
		return nil
	end
	return fn(callback)
end

local function useUpdateEffect(effect, dependencies)
	local fn = hookFunction("use-update-effect", "useUpdateEffect")
	if fn == nil then
		return nil
	end
	return fn(effect, dependencies)
end

local function useUnmountEffect(callback)
	local fn = hookFunction("use-unmount-effect", "useUnmountEffect")
	if fn == nil then
		return nil
	end
	return fn(callback)
end

local function useDeferEffect(callback, dependencies)
	local fn = hookFunction("use-defer-effect", "useDeferEffect")
	if fn == nil then
		return nil
	end
	return fn(callback, dependencies)
end

local function useEventListener(event, listener, options)
	local fn = hookFunction("use-event-listener", "useEventListener")
	if fn == nil then
		return nil
	end
	return fn(event, listener, options)
end

local function useThrottleCallback(callback, options)
	local fn = hookFunction("use-throttle-callback", "useThrottleCallback")
	if fn == nil then
		return callable(callback)
	end
	return fn(callback, options)
end

local function useTimeout(callback, delay)
	local fn = hookFunction("use-timeout", "useTimeout")
	if fn == nil then
		return nil
	end
	return fn(callback, delay)
end

local function useInterval(callback, delay, options)
	local fn = hookFunction("use-interval", "useInterval")
	if fn == nil then
		return nil
	end
	return fn(callback, delay, options)
end

return {
	useLatestCallback = useLatestCallback,
	useDebounceCallback = useDebounceCallback,
	useDebounceState = useDebounceState,
	usePrevious = usePrevious,
	useMountEffect = useMountEffect,
	useUpdateEffect = useUpdateEffect,
	useUnmountEffect = useUnmountEffect,
	useDeferEffect = useDeferEffect,
	useEventListener = useEventListener,
	useThrottleCallback = useThrottleCallback,
	useTimeout = useTimeout,
	useInterval = useInterval,
}
end

-- ======================================================================
-- Module: vendorHost   (merged from vendorHost.luau, 210 lines)
-- ======================================================================
__defs["vendorHost"] = function()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function childOf(parent, name)
	if typeof(parent) ~= "Instance" then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function requireChild(parent, name)
	local child = childOf(parent, name)
	if child == nil or not child:IsA("ModuleScript") then
		return nil
	end
	local ok, loaded = pcall(require, child)
	if not ok or type(loaded) ~= "table" then
		return nil
	end
	return loaded
end

local function moduleScript(parent, name)
	local child = childOf(parent, name)
	if child == nil then
		return nil
	end
	if child:IsA("ModuleScript") then
		return child
	end
	local initScript = childOf(child, "init")
	if initScript ~= nil and initScript:IsA("ModuleScript") then
		return initScript
	end
	return nil
end

local include = childOf(ReplicatedStorage, "rbxts_include")
local nodes = childOf(childOf(include, "node_modules"), "@rbxts")
local importScript = childOf(include, "TSImport")
local importTsModule = nil
if importScript ~= nil and importScript:IsA("ModuleScript") then
	local ok, loaded = pcall(require, importScript)
	if ok and type(loaded) == "function" then
		importTsModule = loaded
	end
end

local servicesModule = requireChild(nodes, "services")
local Players = game:GetService("Players")
if servicesModule ~= nil and servicesModule.Players ~= nil then
	Players = servicesModule.Players
end

local maidModule = requireChild(childOf(nodes, "maid"), "Maid")
local signalModule = requireChild(childOf(nodes, "lemon-signal"), "src")
local Signal = nil
if signalModule ~= nil then
	local candidate = signalModule.Signal
	if candidate == nil then
		candidate = signalModule.default
	end
	if type(candidate) == "table" then
		Signal = candidate
	end
end
local matterModule = requireChild(childOf(nodes, "matter"), "lib")

local PageVisit = nil
local world = nil
local session = nil
pcall(function()
	if matterModule == nil or type(matterModule.component) ~= "function" or type(matterModule.World) ~= "table" or type(matterModule.World.new) ~= "function" then
		return nil
	end
	local visit = matterModule.component("PageVisit")
	local nextWorld = matterModule.World.new()
	local nextSession = nextWorld:spawn(visit({
		page = "Overview",
		at = 0,
	}))
	PageVisit = visit
	world = nextWorld
	session = nextSession
end)

local maid = nil
pcall(function()
	if maidModule ~= nil and type(maidModule.new) == "function" then
		maid = maidModule.new()
	end
end)
local navigated = nil
pcall(function()
	if Signal ~= nil and type(Signal.new) == "function" then
		navigated = Signal.new()
	end
end)
pcall(function()
	if maid ~= nil and navigated ~= nil and type(maid.GiveTask) == "function" then
		maid:GiveTask(navigated)
	end
end)

local journalState = nil
local journalReady = false
local debouncePage = nil

local journalScript = moduleScript(childOf(nodes, "action-journal"), "out")
if journalScript ~= nil and type(importTsModule) == "function" then
	local loadedJournal, journalPkg = pcall(importTsModule, journalScript)
	if loadedJournal and type(journalPkg) == "table" and type(journalPkg.StateManager) == "table" and type(journalPkg.ActionJournal) == "table" and type(journalPkg.StateManager.new) == "function" and type(journalPkg.ActionJournal.new) == "function" then
		pcall(function()
			local state = journalPkg.StateManager.new({
				page = "Overview",
			})
			journalPkg.ActionJournal.new(state, {
				mode = 0,
				historySize = 32,
			})
			journalState = state
			journalReady = true
		end)
	end
end

local function authorName()
	local ok, name = pcall(function()
		local player = Players.LocalPlayer
		if player ~= nil then
			return player.Name
		end
		return nil
	end)
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return "player"
end

local function record(pageId)
	if journalReady and journalState ~= nil and type(journalState.setPath) == "function" then
		pcall(function()
			journalState:setPath("page", pageId, authorName())
		end)
	end
	if world ~= nil and session ~= nil and PageVisit ~= nil and type(world.insert) == "function" then
		pcall(function()
			world:insert(session, PageVisit({
				page = pageId,
				at = os.clock(),
			}))
		end)
	end
	if navigated ~= nil and type(navigated.Fire) == "function" then
		pcall(function()
			navigated:Fire(pageId)
		end)
	end
end

local timersScript = moduleScript(childOf(nodes, "set-timeout"), "out")
if timersScript ~= nil and type(importTsModule) == "function" then
	local loadedTimers, timers = pcall(importTsModule, timersScript)
	if loadedTimers and type(timers) == "table" and type(timers.debounce) == "function" then
		pcall(function()
			debouncePage = timers.debounce(record, 0.12, {
				leading = true,
				trailing = false,
			})
		end)
	end
end

local function notePage(pageId)
	if type(pageId) ~= "string" or pageId == "" then
		return nil
	end
	if debouncePage ~= nil then
		local ok = pcall(debouncePage, pageId)
		if ok then
			return nil
		end
	end
	record(pageId)
end

local function shutdown()
	pcall(function()
		if debouncePage ~= nil and debouncePage.cancel ~= nil then
			debouncePage.cancel()
		end
	end)
	pcall(function()
		if maid ~= nil and type(maid.DoCleaning) == "function" then
			maid:DoCleaning()
		elseif navigated ~= nil and type(navigated.Destroy) == "function" then
			navigated:Destroy()
		end
	end)
	debouncePage = nil
	journalReady = false
	journalState = nil
	navigated = nil
	maid = nil
end

return {
	notePage = notePage,
	shutdown = shutdown,
}
end

-- ======================================================================
-- Module: reactHost   (merged from reactHost.luau, 199 lines)
-- ======================================================================
__defs["reactHost"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local reactModules = __load("reactModules")
local notePage = __load("vendorHost").notePage
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local Palette = require(script.Parent.CoreKit)("theme").Palette

local PageHostContext = React.createContext({
	page = "",
	retry = function() end,
})

local function onPageRender(id, _phase, actualDuration)
	if type(actualDuration) ~= "number" or actualDuration < 20 then
		return nil
	end
	ClientLog:warnEvery(`react-slow-{id}`, 10, "React", `{id} commit took {math.floor(actualDuration)}ms`)
end

local PagePending = React.PureComponent:extend("PagePending")
function PagePending:render()
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "Loading",
		TextColor3 = Palette.cream,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}))
end

local function CrashNotice(props)
	local host = React.useContext(PageHostContext)
	local transparency, setTransparency = React.useBinding(1)
	local pressed, setPressed = React.useState(false)
	React.useDebugValue(props.message)
	reactModules.useMountEffect(function()
		setTransparency(0)
	end)
	reactModules.useTimeout(function()
		setPressed(false)
	end, if pressed then 0.45 else nil)
	local retry = React.useCallback(function()
		setPressed(true)
		if props.onRetry ~= nil then
			props.onRetry()
		else
			host.retry()
		end
	end, { host, props.onRetry })
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, React.createElement("textlabel", {
		Size = UDim2.new(1, -32, 0, 48),
		Position = UDim2.new(0.5, 0, 0.5, -36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "This screen hit an error. You can open it again.",
		TextColor3 = Palette.cream,
		TextTransparency = transparency,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}), React.createElement("textbutton", {
		Size = UDim2.fromOffset(140, 36),
		Position = UDim2.new(0.5, 0, 0.5, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = if pressed then Palette.panelSoft else Palette.cyan,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "TRY AGAIN",
		TextColor3 = Palette.ink,
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		Event = {
			Activated = retry,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})))
end

local PageErrorBoundary = React.Component:extend("PageErrorBoundary")
function PageErrorBoundary:init()
	self.state = {
		failed = false,
		message = "",
	}
end
function PageErrorBoundary.getDerivedStateFromError(err)
	return {
		failed = true,
		message = tostring(err),
	}
end
function PageErrorBoundary:componentDidCatch(err)
	ClientLog:warnEvery("react-page", 5, "React", tostring(err))
end
function PageErrorBoundary:render()
	if self.state.failed then
		return React.createElement(CrashNotice, {
			message = self.state.message,
			onRetry = function()
				self:setState({
					failed = false,
					message = "",
				})
			end,
		})
	end
	return self.props.children
end

local PageFrame = React.memo(React.forwardRef(function(props, ref)
	local page = props.page
	if page == nil then
		page = ""
	end
	local retryCount, bumpRetry = React.useReducer(function(count)
		return count + 1
	end, 0)
	local seenPage = React.useRef(page)
	local previousPage = reactModules.usePrevious(page)
	React.useDebugValue(if previousPage ~= nil and previousPage ~= "" then `{previousPage} -> {page}` else page)
	React.useLayoutEffect(function()
		seenPage.current = page
		return function()
			seenPage.current = ""
		end
	end, { page })
	-- notePage's debounce keeps one timer. A throttled Heartbeat (maxWait) overwrites
	-- that timer without disconnecting it, so rapid page switches leaked connections.
	React.useEffect(function()
		if page == "" then
			return nil
		end
		notePage(page)
		local pending = true
		local trailing = task.delay(0.12, function()
			pending = false
			notePage(page)
		end)
		return function()
			if pending then
				task.cancel(trailing)
			end
		end
	end, { page })
	React.useImperativeHandle(ref, function()
		return {
			retry = bumpRetry,
			page = function()
				return seenPage.current
			end,
		}
	end, { bumpRetry })
	local contextValue = React.useMemo(function()
		return {
			page = page,
			retry = bumpRetry,
		}
	end, { page, bumpRetry })
	local child = React.useMemo(function()
		local only = React.Children.only(props.children)
		if not React.isValidElement(only) then
			return only
		end
		return React.cloneElement(only, {
			key = `{page}:{retryCount}`,
		})
	end, { props.children, page, retryCount })
	return React.createElement(PageHostContext.Provider, {
		value = contextValue,
	}, React.createElement(React.Suspense, {
		fallback = React.createElement(PagePending),
	}, React.createElement(PageErrorBoundary, {
		key = `{page}:{retryCount}`,
	}, React.createElement(React.Profiler, {
		id = if page ~= "" then page else "Game",
		onRender = onPageRender,
	}, child))))
end))

return {
	PageFrame = PageFrame,
	PageErrorBoundary = PageErrorBoundary,
	PagePending = PagePending,
}
end

-- ======================================================================
-- Module: HyperTextHost   (merged from HyperTextHost.luau, 450 lines)
-- ======================================================================
__defs["HyperTextHost"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local _theme = require(script.Parent.CoreKit)("theme")
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
-- Bridges the vendor HyperText Luau module (ReplicatedStorage.AstralForge.Vendor.HyperText) into
-- React-Lua for player titles. HyperText renders real per-character Instances driven by its own
-- markup tags (<anim=wiggle>, <shake>, <rainbow>, <emitImg>, ...), giving actual positional motion
-- and particle effects instead of the color/stroke-only tricks the previous title renderer used.
-- Follows the same load-with-retry-and-fallback pattern as RichTextHost.tsx/NumberSpinnerHost.tsx:
-- the module is fetched once, cached, and any load failure degrades to a plain static textlabel
-- instead of leaving a title blank.
local TITLE_FX_KINDS = { "wave", "fire", "ice", "glitch", "galaxy", "rainbow", "glow", "neon", "sparkle", "shake", "pulse", "gradient-shift", "holographic", "void", "plasma", "chrome", "ember", "frost", "aurora", "matrix", "static", "bounce-in", "blur-resolve", "shimmer", "toxic", "solar", "ocean", "candy", "voltage", "prism", "phantom" }
local _set = {}
for _, _v in TITLE_FX_KINDS do
	_set[_v] = true
end
local FX_SET = _set
local function parseFx(fx)
	if fx == nil or fx == "" then
		return nil
	end
	local key = string.lower(fx)
	return if FX_SET[key] ~= nil then key else nil
end
-- One accent per kind, used for the reduced-motion/failed-load fallback text and anywhere else
-- in the UI that just needs "the color for this title" (badges, plates) without a live render.
local FX_ACCENT = {
	wave = Palette.cyan,
	fire = Palette.mango,
	ice = Palette.cyan,
	glitch = Palette.pink,
	galaxy = Palette.violet,
	rainbow = Color3.fromRGB(255, 170, 60),
	glow = lighten(Palette.cream, 0.1),
	neon = Palette.mint,
	sparkle = Palette.mango,
	shake = Palette.coral,
	pulse = Palette.violet,
	["gradient-shift"] = Palette.blue,
	holographic = Palette.cyan,
	void = Palette.violet,
	plasma = Palette.pink,
	chrome = Palette.creamSoft,
	ember = Palette.coral,
	frost = Color3.fromRGB(180, 220, 255),
	aurora = Palette.mint,
	matrix = Palette.green,
	static = Palette.cream,
	["bounce-in"] = Palette.mango,
	["blur-resolve"] = Palette.cream,
	shimmer = Palette.creamSoft,
	toxic = Color3.fromRGB(120, 255, 40),
	solar = Palette.mango,
	ocean = Palette.blue,
	candy = Palette.pink,
	voltage = Palette.cyan,
	prism = Palette.pink,
	phantom = Palette.violet,
}
local function titleFxAccent(fx)
	local kind = parseFx(fx)
	return if kind ~= nil then FX_ACCENT[kind] else Palette.creamSoft
end
local function darkTitlePlate(fx)
	return darken(titleFxAccent(fx), 0.82)
end
local function colorTag(color)
	return `{math.round(color.R * 255)},{math.round(color.G * 255)},{math.round(color.B * 255)}`
end
local function safeText(value)
	local cleaned = (string.gsub(value, "<", "("))
	cleaned = (string.gsub(cleaned, ">", ")"))
	return cleaned
end
-- Per-character reveal stagger applied uniformly on top of every kind below. `interval` is the
-- one HyperText primitive none of the 30 kinds touch internally, so wrapping it around the whole
-- body can never collide with (shadow/override) a kind's own <anim>/<trans> stack — those tags
-- override same-type ancestors when nested, so anything kind-specific has to stay the innermost
-- layer of its own type. The result: titles no longer pop in as a static block and then loop —
-- each character cascades in on its own beat and is already animating (color/shake/particles/
-- gradient, whatever the kind does) from the instant it appears.
local REVEAL_STAGGER = 0.045
-- Each kind is a unique combination of HyperText motion (wiggle / bounce / slide / grow /
-- shake), color treatment (solid, gradient, rainbow, stroke, shadow, mark), and overlay
-- (shiny, fog, decode, transparency tween). Shared "recolor of the same wiggle" setups are
-- banned — NumberRange attrs must be min,max (so rising sparks use velY=-1.2,-.6 not -.6,-1.2).
local function buildKindMarkup(kind, body)
	local accent = FX_ACCENT[kind]
	repeat
		if kind == "wave" then
			return `<anim=wiggle freq=1.05 amp=.38 offset=.18 rot=true loop=true><color={colorTag(Palette.cyan)}>{body}</color></anim>`
		end
		if kind == "ocean" then
			return `<anim=bounce dir=down offset=.22 exp=1.15 loop=true><fog=true color={colorTag(Palette.blue)} rate=.45 chance=40 lifetime=.8,1.4 startSize=.5,.8 endSize=.1,.2 velY=-.15,.2 startTrans=.4,.6 endTrans=1,1><gradient=true colors={colorTag(Palette.blue)};{colorTag(Palette.cyan)};{colorTag(Color3.fromRGB(20, 70, 140))} individual=false moveDir=left moveSpeed=.18 rot=12>{body}</gradient></fog></anim>`
		end
		if kind == "aurora" then
			return `<trans=.08 tweenDur=1.6 tweenFrom=.28 loopTween=true><gradient=true colors={colorTag(Palette.mint)};{colorTag(Palette.cyan)};{colorTag(Palette.violet)};{colorTag(Palette.pink)} individual=false moveDir=right moveSpeed=.22 spacing=.15>{body}</gradient></trans>`
		end
		if kind == "fire" then
			return `<anim=bounce dir=up offset=.2 exp=1.8 loop=true><shiny=true color={colorTag(Color3.fromRGB(255, 190, 70))} rate=.85 chance=55 lifetime=.35,.7 startSize=.28,.42 endSize=0,0 velY=-1.2,-.7 startPosY=.15,.45 rotVel=-40,40><gradient=true colors={colorTag(Color3.fromRGB(255, 70, 16))};{colorTag(Palette.mango)};{colorTag(Color3.fromRGB(255, 230, 110))} individual=true moveDir=right moveSpeed=.4>{body}</gradient></shiny></anim>`
		end
		if kind == "ember" then
			return `<shake=true maxOffset=.012 maxRot=1.2 loop=true freq=3 dur=0><shiny=true color={colorTag(Color3.fromRGB(255, 110, 40))} rate=.35 chance=40 lifetime=.7,1.3 startSize=.18,.28 endSize=0,0 velY=.2,.65 startPosY=-.25,.05 accelY=.15,.4><color={colorTag(Color3.fromRGB(210, 55, 18))}>{body}</color></shiny></shake>`
		end
		if kind == "solar" then
			return `<anim=grow startScale=.86 exp=1.4 loop=true><shiny=true color={colorTag(Color3.fromRGB(255, 240, 160))} rate=.5 chance=30 lifetime=.5,.9 startSize=.35,.5 endSize=.05,.1 velY=-.35,.35 velX=-.4,.4 startPosY=-.15,.15><gradient=true colors={colorTag(Color3.fromRGB(255, 210, 70))};{colorTag(Color3.fromRGB(255, 255, 210))};{colorTag(Palette.mango)} individual=false moveDir=right moveSpeed=.55 rot=90>{body}</gradient></shiny></anim>`
		end
		if kind == "ice" then
			return `<anim=slide dir=down offset=.16 rot=-6 loop=true><stroke=true color={colorTag(Palette.white)} thickness=.055><color={colorTag(Color3.fromRGB(150, 220, 255))}>{body}</color></stroke></anim>`
		end
		if kind == "frost" then
			return `<fog=true color={colorTag(Color3.fromRGB(210, 235, 255))} rate=.3 chance=50 lifetime=1,1.6 startSize=.4,.7 endSize=.15,.25 velY=-.08,.12 startTrans=.35,.55 endTrans=1,1><shiny=true color={colorTag(Palette.white)} rate=.18 chance=22 lifetime=.8,1.3 startSize=.12,.2 endSize=0,0 velY=-.12,.2><stroke=true color={colorTag(Color3.fromRGB(230, 245, 255))} thickness=.03 trans=.25><color={colorTag(Color3.fromRGB(180, 220, 255))}>{body}</color></stroke></shiny></fog>`
		end
		if kind == "glitch" then
			return `<decode=true dur=.16 freq=8 loop=true><shake=true maxOffset=.06 maxRot=3 loop=true freq=7 dur=0><color={colorTag(Palette.pink)}><strike=true>{body}</strike></color></shake></decode>`
		end
		if kind == "static" then
			return `<decode=true dur=.08 freq=14 loop=true><color={colorTag(Palette.cream)}>{body}</color></decode>`
		end
		if kind == "voltage" then
			return `<shake=true maxOffset=.03 maxRot=5 loop=true freq=12 dur=0><stroke=true color={colorTag(Palette.white)} thickness=.035><strokeGradient=true colors={colorTag(Palette.cyan)};{colorTag(Palette.white)};{colorTag(Palette.blue)} moveDir=right moveSpeed=1.1 individual=false><color={colorTag(Palette.cyan)}>{body}</color></strokeGradient></stroke></shake>`
		end
		if kind == "shake" then
			return `<shake=true maxOffset=.07 maxRot=8 loop=true freq=9 dur=0 fade=false><color={colorTag(Palette.coral)}>{body}</color></shake>`
		end
		if kind == "galaxy" then
			return `<anim=wiggle freq=.35 amp=.14 offset=.28 rot=false loop=true><shadow=true color={colorTag(Color3.fromRGB(20, 8, 40))} offset=0,.28 trans=.35><rainbow=true freq=.12 offset=.22>{body}</rainbow></shadow></anim>`
		end
		if kind == "prism" then
			return `<stroke=true color={colorTag(Palette.white)} thickness=.04><strokeGradient=true colors={colorTag(Palette.pink)};{colorTag(Palette.cyan)};{colorTag(Palette.mango)};{colorTag(Palette.violet)} individual=true moveDir=right moveSpeed=.8><rainbow=true freq=.55 offset=.08>{body}</rainbow></strokeGradient></stroke>`
		end
		if kind == "holographic" then
			return `<italic=true><trans=.1 tweenDur=.9 tweenFrom=.32 loopTween=true><gradient=true colors={colorTag(Palette.cyan)};{colorTag(Palette.pink)};{colorTag(Palette.mint)};{colorTag(Palette.white)} individual=true moveDir=left moveSpeed=.95>{body}</gradient></trans></italic>`
		end
		if kind == "gradient-shift" then
			return `<stroke=true color={colorTag(Palette.white)} thickness=.03 trans=.55><gradient=true colors={colorTag(Palette.blue)};{colorTag(Palette.violet)};{colorTag(Palette.pink)};{colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.38 spacing=.08>{body}</gradient></stroke>`
		end
		if kind == "candy" then
			return `<anim=bounce dir=up offset=.48 exp=2.1 loop=true><gradient=true colors={colorTag(Palette.pink)};{colorTag(Palette.cream)};{colorTag(Palette.violet)};{colorTag(Palette.mint)} individual=true moveDir=right moveSpeed=.28>{body}</gradient></anim>`
		end
		if kind == "rainbow" then
			return `<stroke=true color={colorTag(Palette.white)} thickness=.03 trans=.6><rainbow=true freq=.7 offset=.16>{body}</rainbow></stroke>`
		end
		if kind == "toxic" then
			return `<fog=true color={colorTag(Color3.fromRGB(90, 255, 40))} rate=.55 chance=45 lifetime=.6,1.1 startSize=.3,.5 endSize=.05,.12 velY=.25,.75 startPosY=-.2,.1 startTrans=.2,.4 endTrans=1,1><shake=true maxOffset=.018 maxRot=.8 loop=true freq=4 dur=0><color={colorTag(Color3.fromRGB(120, 255, 40))}>{body}</color></shake></fog>`
		end
		if kind == "matrix" then
			return `<italic=true><decode=true dur=.28 freq=4 loop=true><color={colorTag(Palette.green)}>{body}</color></decode></italic>`
		end
		if kind == "glow" then
			return `<trans=.04 tweenDur=1.1 tweenFrom=.3 loopTween=true><stroke=true color={colorTag(Color3.fromRGB(255, 236, 190))} thickness=.07 trans=.15><color={colorTag(Color3.fromRGB(255, 244, 210))}>{body}</color></stroke></trans>`
		end
		if kind == "neon" then
			return `<mark=true color={colorTag(Color3.fromRGB(8, 28, 22))} trans=.72><stroke=true color={colorTag(Palette.mint)} thickness=.06><strokeGradient=true colors={colorTag(Palette.mint)};{colorTag(Palette.white)};{colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.7><color={colorTag(Palette.mint)}>{body}</color></strokeGradient></stroke></mark>`
		end
		if kind == "sparkle" then
			return `<anim=bounce dir=up offset=.12 exp=1.2 loop=true><shiny=true color={colorTag(Palette.white)} rate=.9 chance=60 lifetime=.4,.75 startSize=.2,.34 endSize=0,0 velY=-.9,-.4 velX=-.5,.5 startPosY=-.2,.2 rotVel=-80,80><color={colorTag(Palette.mango)}>{body}</color></shiny></anim>`
		end
		if kind == "shimmer" then
			return `<trans=.06 tweenDur=1.4 tweenFrom=.22 loopTween=true><gradient=true colors={colorTag(Palette.creamSoft)};{colorTag(Palette.white)};{colorTag(Palette.cream)};{colorTag(Palette.creamSoft)} individual=false moveDir=right moveSpeed=.62 rot=18>{body}</gradient></trans>`
		end
		if kind == "pulse" then
			return `<anim=grow startScale=.78 exp=1.15 loop=true><trans=.05 tweenDur=.9 tweenFrom=.4 loopTween=true><stroke=true color={colorTag(lighten(Palette.violet, 0.3))} thickness=.05><color={colorTag(Palette.violet)}>{body}</color></stroke></trans></anim>`
		end
		if kind == "void" then
			return `<anim=wiggle freq=.28 amp=.2 offset=.32 rot=true loop=true><shadow=true color={colorTag(Color3.fromRGB(8, 0, 16))} offset=.08,.4 trans=.2><stroke=true color={colorTag(Color3.fromRGB(18, 6, 28))} thickness=.08><trans=.12 tweenDur=2 tweenFrom=.45 loopTween=true><color={colorTag(Palette.violet)}>{body}</color></trans></stroke></shadow></anim>`
		end
		if kind == "plasma" then
			return `<shake=true maxOffset=.028 maxRot=2.5 loop=true freq=8 dur=0><shiny=true color={colorTag(Palette.pink)} rate=.7 chance=40 lifetime=.3,.55 startSize=.22,.36 endSize=0,0 velX=-.8,.8 velY=-.5,.5><gradient=true colors={colorTag(Palette.pink)};{colorTag(Palette.violet)};{colorTag(Palette.coral)};{colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=1.05>{body}</gradient></shiny></shake>`
		end
		if kind == "chrome" then
			return `<shadow=true color={colorTag(Color3.fromRGB(40, 44, 52))} offset=.06,.22 trans=.45><gradient=true colors={colorTag(Palette.muted)};{colorTag(Palette.creamSoft)};{colorTag(Palette.white)};{colorTag(Palette.creamSoft)};{colorTag(Color3.fromRGB(90, 96, 108))} individual=false moveDir=right moveSpeed=.48 rot=90>{body}</gradient></shadow>`
		end
		if kind == "phantom" then
			return `<italic=true><anim=slide dir=up offset=.2 rot=4 loop=true><trans=.18 tweenDur=1.3 tweenFrom=.62 loopTween=true><color={colorTag(Palette.violet)}>{body}</color></trans></anim></italic>`
		end
		if kind == "bounce-in" then
			return `<anim=bounce dir=up offset=.7 exp=1.55><color={colorTag(Palette.mango)}>{body}</color></anim>`
		end
		if kind == "blur-resolve" then
			return `<anim=grow startScale=.4 exp=2.6><decode=true dur=.22 freq=7 loop=false><color={colorTag(Palette.cream)}>{body}</color></decode></anim>`
		end
		return `<color={colorTag(accent)}>{body}</color>`
	until true
end
local function buildMarkup(kind, text, preview)
	local body = safeText(text)
	if preview then
		local accent = FX_ACCENT[kind] or Palette.cream
		-- Visible motion without per-card particle emitters. Full kinds stay on the equipped title.
		return `<interval={REVEAL_STAGGER}><anim=wiggle freq=.7 amp=.22 offset=.1 rot=true loop=true><gradient=true colors={colorTag(accent)};{colorTag(Palette.cream)};{colorTag(accent)} individual=false moveDir=right moveSpeed=.42>{body}</gradient></anim></interval>`
	end
	return `<interval={REVEAL_STAGGER}>{buildKindMarkup(kind, body)}</interval>`
end
local cachedModule
local loadFailed = false
local pendingWarned = false
local TITLE_FONT = "rbxasset://fonts/families/BuilderSans.json"
local function makeTitleMarkups(mod, size, align)
	local markups = mod.newMarkups()
	markups.font.value = TITLE_FONT
	markups.weight.value = Enum.FontWeight.ExtraBold
	markups.size.value = size
	markups.horizontalAlignment.value = if align == Enum.TextXAlignment.Center then Enum.HorizontalAlignment.Center elseif align == Enum.TextXAlignment.Right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	markups.verticalAlignment.value = Enum.VerticalAlignment.Center
	markups.scaleDimension.value = "Y"
	return markups
end
local function resolveModuleScript(node)
	if node:IsA("ModuleScript") then
		return node
	end
	local initChild = node:FindFirstChild("init")
	if initChild ~= nil and initChild:IsA("ModuleScript") then
		return initChild
	end
	return nil
end
local function loadHyperTextModule()
	if cachedModule ~= nil then
		return cachedModule
	end
	if loadFailed then
		return nil
	end
	local astral = ReplicatedStorage:FindFirstChild("AstralForge")
	local _vendor = astral
	if _vendor ~= nil then
		_vendor = _vendor:FindFirstChild("Vendor")
	end
	local vendor = _vendor
	local _node = vendor
	if _node ~= nil then
		_node = _node:FindFirstChild("HyperText")
	end
	local node = _node
	if node == nil then
		return nil
	end
	local moduleScript = resolveModuleScript(node)
	if moduleScript == nil then
		ClientLog:warn("hypertext", `HyperText is a {node.ClassName}, not a ModuleScript`)
		loadFailed = true
		return nil
	end
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	local _condition = not ok or result == nil
	if not _condition then
		local _new = result.new
		_condition = (type(_new) == "function") ~= true
	end
	if _condition then
		ClientLog:warn("hypertext", `couldn't load HyperText: {tostring(result)}`)
		loadFailed = true
		return nil
	end
	cachedModule = result
	pendingWarned = false
	return cachedModule
end
local function AnimatedTitle(_param)
	local text = _param.text
	local fx = _param.fx
	local size = _param.size
	if size == nil then
		size = 13
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local position = _param.position
	local sizeConstraint = _param.sizeConstraint
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local _inline = _param.inline
	if _inline == nil then
		_inline = false
	end
	local kind = parseFx(fx)
	local width = sizeConstraint or UDim2.new(1, 0, 0, size + 4)
	local pos = position or UDim2.fromOffset(0, 0)
	local accent = if kind ~= nil then FX_ACCENT[kind] else Palette.creamSoft
	local preview = _param.preview == true
	local live = kind ~= nil and not reducedMotion and text ~= ""
	local hostRef = React.useRef()
	local richRef = React.useRef()
	local fallbackRef = React.useRef()
	local mounted, setMounted = React.useState(false)
	local destroy = React.useCallback(function()
		local rich = richRef.current
		richRef.current = nil
		if rich ~= nil then
			pcall(function()
				return rich:Destroy()
			end)
		end
		setMounted(false)
	end, {})
	React.useEffect(function()
		if not live or kind == nil then
			destroy()
			return nil
		end
		local cancelled = false
		local attempts = 0
		local retryJob
		local tryMount
		tryMount = function()
			if cancelled then
				return nil
			end
			attempts += 1
			local host = hostRef.current
			local mod = loadHyperTextModule()
			if host == nil or mod == nil then
				if attempts < 80 then
					retryJob = task.delay(if attempts < 10 then 0.05 else 0.15, tryMount)
				elseif not pendingWarned then
					pendingWarned = true
					ClientLog:warnEvery("hypertext-root", 30, "hypertext", "title renderer is still loading")
				end
				return nil
			end
			local fallback = fallbackRef.current
			local rich = mod.new(host)
			local markups = makeTitleMarkups(mod, size, align)
			local okUpdate, updateErr = pcall(function()
				return rich:UpdateDefaultMarkups(markups)
			end)
			if not okUpdate then
				ClientLog:warn("hypertext", `title markup failed: {tostring(updateErr)}`)
				pcall(function()
					return rich:Destroy()
				end)
				return nil
			end
			local okRender, renderErr = pcall(function()
				return rich:Render(buildMarkup(kind, text, preview), false, false, false)
			end)
			if not okRender then
				ClientLog:warn("hypertext", `title render failed: {tostring(renderErr)}`)
				pcall(function()
					return rich:Destroy()
				end)
				return nil
			end
			if cancelled then
				pcall(function()
					return rich:Destroy()
				end)
				return nil
			end
			if fallback ~= nil then
				fallback.Visible = false
			end
			richRef.current = rich
			setMounted(true)
		end
		local mountJob = task.defer(tryMount)
		return function()
			cancelled = true
			task.cancel(mountJob)
			if retryJob ~= nil then
				task.cancel(retryJob)
			end
			destroy()
		end
		-- eslint-disable-next-line react-hooks/exhaustive-deps
	end, { live, kind, text, size, align, preview, destroy })
	local showFallback = not live or not mounted
	return React.createElement("frame", {
		Size = width,
		Position = pos,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}), showFallback and React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = accent,
		TextSize = size,
		TextTransparency = transparency,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextScaled = true,
		ZIndex = 1,
	}, React.createElement("uitextsizeconstraint", {
		MinTextSize = math.max(9, size - 4),
		MaxTextSize = size,
	})))
end
local function AnimatedTitlePreview(_param)
	local text = _param.text
	local fx = _param.fx
	local size = _param.size
	if size == nil then
		size = 15
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local preview = _param.preview == true
	return React.createElement(AnimatedTitle, {
		text = text,
		fx = fx,
		size = size,
		reducedMotion = reducedMotion,
		transparency = transparency,
		align = Enum.TextXAlignment.Center,
		preview = preview,
	})
end
return {
	parseFx = parseFx,
	titleFxAccent = titleFxAccent,
	darkTitlePlate = darkTitlePlate,
	AnimatedTitle = AnimatedTitle,
	AnimatedTitlePreview = AnimatedTitlePreview,
	TITLE_FX_KINDS = TITLE_FX_KINDS,
}
end

-- ======================================================================
-- Module: RichTextHost   (merged from RichTextHost.luau, 252 lines)
-- ======================================================================
__defs["RichTextHost"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local Palette = require(script.Parent.CoreKit)("theme").Palette
-- Bridges the vendor RichText Luau module (ReplicatedStorage.AstralForge.Vendor.RichText) --
-- an imperative class that builds real per-character Instances with typewriter timing, <wait>/
-- <br> markup, and Shiny/Stinky particle effects -- into a React-Lua component. Deliberately kept
-- separate from AnimatedTitle.tsx's 31-effect player-title system: that system's per-glyph color/
-- motion math has no equivalent here (RichText only knows Shake/Rainbow/Shiny/Stinky/None), and
-- swapping it out would mean losing 25+ existing effects for a much smaller vocabulary. This host
-- is for what RichText is actually good at and AnimatedTitle doesn't do at all: scripted narrative
-- text with a real typewriter reveal and inline pacing (Story chapters, Mail bodies, tutorial
-- copy) -- see StoryView.tsx/MailboxView.tsx for the call sites.
--
-- Follows the same load-with-retry-and-fallback pattern as NumberSpinnerHost.tsx: the module is
-- fetched once, cached, and any failure to load (missing replication, wrong instance type, a
-- require() error) degrades to a plain static text label instead of leaving the page blank --
-- this text is often the only content on the page (a story chapter, a mail body), so a silent
-- blank render on a load hiccup would be a much worse failure than briefly-unanimated text.
local cachedModule
local loadFailed = false
local pendingWarned = false
local function resolveModuleScript(node)
	if node:IsA("ModuleScript") then
		return node
	end
	local initChild = node:FindFirstChild("init")
	if initChild ~= nil and initChild:IsA("ModuleScript") then
		return initChild
	end
	return nil
end
local function loadRichTextModule()
	if cachedModule ~= nil then
		return cachedModule
	end
	if loadFailed then
		return nil
	end
	local astral = ReplicatedStorage:FindFirstChild("AstralForge")
	local _vendor = astral
	if _vendor ~= nil then
		_vendor = _vendor:FindFirstChild("Vendor")
	end
	local vendor = _vendor
	local _node = vendor
	if _node ~= nil then
		_node = _node:FindFirstChild("RichText")
	end
	local node = _node
	if node == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("richtext-root", 15, "richtext", "ReplicatedStorage.AstralForge.Vendor.RichText is not replicated yet")
		end
		return nil
	end
	local moduleScript = resolveModuleScript(node)
	if moduleScript == nil then
		ClientLog:warn("richtext", `RichText is a {node.ClassName}, not a ModuleScript`)
		loadFailed = true
		return nil
	end
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	local _condition = not ok or result == nil
	if not _condition then
		local _new = result.new
		_condition = (type(_new) == "function") ~= true
	end
	if _condition then
		ClientLog:warn("richtext", `couldn't load RichText: {tostring(result)}`)
		loadFailed = true
		return nil
	end
	cachedModule = result
	pendingWarned = false
	return cachedModule
end
-- Plain-text width/height is measured the same way AutoHeightText in ui.tsx does, so the reserved
-- space for the scripted version matches what the fallback would have needed -- switching between
-- them (e.g. reducedMotion toggling mid-session) doesn't jump the layout.
local function ScriptedText(_param)
	local text = _param.text
	local width = _param.width
	local height = _param.height
	local size = _param.size
	if size == nil then
		size = 15
	end
	local color = _param.color
	if color == nil then
		color = Palette.creamSoft
	end
	local weight = _param.weight
	if weight == nil then
		weight = Enum.FontWeight.Medium
	end
	local italic = _param.italic
	if italic == nil then
		italic = false
	end
	local align = _param.align
	if align == nil then
		align = Enum.HorizontalAlignment.Left
	end
	local typewriterInterval = _param.typewriterInterval
	if typewriterInterval == nil then
		typewriterInterval = 0.015
	end
	local typewriterSoundId = _param.typewriterSoundId
	local animation = _param.animation
	if animation == nil then
		animation = "None"
	end
	local animationDuration = _param.animationDuration
	if animationDuration == nil then
		animationDuration = 0.125
	end
	local effect = _param.effect
	if effect == nil then
		effect = "None"
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local position = _param.position
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local renderKey = _param.renderKey
	local onRenderEnded = _param.onRenderEnded
	local hostRef = React.useRef()
	local richRef = React.useRef()
	local fallbackRef = React.useRef()
	local live, setLive = React.useState(false)
	local destroy = React.useCallback(function()
		local rich = richRef.current
		richRef.current = nil
		if rich ~= nil then
			pcall(function()
				rich:Destroy()
			end)
		end
		setLive(false)
	end, {})
	React.useEffect(function()
		if reducedMotion or text == "" then
			destroy()
			return nil
		end
		local cancelled = false
		local attempts = 0
		local retryJob
		local tryMount
		tryMount = function()
			if cancelled then
				return nil
			end
			attempts += 1
			local host = hostRef.current
			local mod = loadRichTextModule()
			if host == nil or mod == nil then
				if attempts < 50 then
					retryJob = task.delay(0.1, tryMount)
				end
				return nil
			end
			local fallback = fallbackRef.current
			if fallback ~= nil then
				fallback.Visible = false
			end
			local rich = mod.new(host, {
				Color = color,
				Size = size,
				XAlign = align,
				YAlign = Enum.VerticalAlignment.Top,
				TypewriterInterval = typewriterInterval,
				TypewriterSoundId = typewriterSoundId,
				Animation = animation,
				AnimationDuration = animationDuration,
				AnimationLoop = false,
				Effect = effect,
				Weight = weight,
				Italic = italic,
				Transparency = 0,
			})
			richRef.current = rich
			setLive(true)
			if onRenderEnded ~= nil and rich.onRenderEnded ~= nil then
				rich.onRenderEnded.Event:Once(function()
					if not cancelled then
						onRenderEnded()
					end
				end)
			end
			rich:Render(text, false, true, false)
		end
		local mountJob = task.defer(tryMount)
		return function()
			cancelled = true
			-- A finished defer cannot be cancelled; task.cancel throws and would skip destroy().
			pcall(task.cancel, mountJob)
			if retryJob ~= nil then
				pcall(task.cancel, retryJob)
			end
			destroy()
		end
		-- eslint-disable-next-line react-hooks/exhaustive-deps
	end, { renderKey, reducedMotion, text, destroy })
	local showFallback = reducedMotion or not live or text == ""
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex + 1,
	}), showFallback and React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		FontFace = Font.fromEnum(if weight == Enum.FontWeight.Heavy then Enum.Font.BuilderSansExtraBold elseif weight == Enum.FontWeight.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium),
		TextXAlignment = if align == Enum.HorizontalAlignment.Center then Enum.TextXAlignment.Center elseif align == Enum.HorizontalAlignment.Right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LineHeight = 1.12,
		ZIndex = zIndex,
	}))
end
return {
	ScriptedText = ScriptedText,
}
end

-- ======================================================================
-- Module: NumberSpinnerHost   (merged from NumberSpinnerHost.luau, 829 lines)
-- ======================================================================
__defs["NumberSpinnerHost"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local compactSpinParts = require(script.Parent.CoreKit)("format").compactSpinParts
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local useMotionSettings = require(script.Parent.MotionKit)("motion").useMotionSettings
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local lighten = _theme.lighten
local AUTO_WIDTH_PAD = 4
local function estimateLabelWidth(text, textSize)
	return math.max(4, math.ceil(#text * textSize * 0.7)) + AUTO_WIDTH_PAD
end
local SPINNER_FONT = Font.fromEnum(Enum.Font.RobotoMono)
local function findSpinnerLayout(host)
	for _, child in host:GetChildren() do
		if not child:IsA("GuiObject") or child.Name == "NumberSpinnerGuide" then
			continue
		end
		local layout = child:FindFirstChildOfClass("UIListLayout")
		if layout ~= nil then
			return layout
		end
	end
	return nil
end
local function hugSpinnerContent(host)
	for _, child in host:GetChildren() do
		if not child:IsA("GuiObject") or child.Name == "NumberSpinnerGuide" then
			continue
		end
		local layout = child:FindFirstChildOfClass("UIListLayout")
		if layout == nil then
			continue
		end
		if child.AutomaticSize ~= Enum.AutomaticSize.X then
			child.AutomaticSize = Enum.AutomaticSize.X
		end
		local hug = UDim2.new(0, 0, 1, 0)
		if child.Size ~= hug then
			child.Size = hug
		end
		if not child.ClipsDescendants then
			child.ClipsDescendants = true
		end
		return layout
	end
	return nil
end
local SPINNER_RS_PATH = "ReplicatedStorage.AstralForge.Shared.NumberSpinner"
local cachedModule
local loadFailed = false
local pendingWarned = false
local function resolveModuleScript(node)
	if node:IsA("ModuleScript") then
		return node
	end
	local initChild = node:FindFirstChild("init")
	if initChild ~= nil and initChild:IsA("ModuleScript") then
		return initChild
	end
	return nil
end
local function childNames(parent)
	local names = {}
	for _, child in parent:GetChildren() do
		local _name = child.Name
		table.insert(names, _name)
	end
	return if #names > 0 then table.concat(names, ", ") else "(none)"
end
local function loadModule()
	if cachedModule ~= nil then
		return cachedModule
	end
	if loadFailed then
		return nil
	end
	local astral = ReplicatedStorage:FindFirstChild("AstralForge")
	if astral == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("spinner-root", 15, "spinner", `{SPINNER_RS_PATH} is not replicated`)
		end
		return nil
	end
	local sharedFolder = astral:FindFirstChild("Shared")
	if sharedFolder == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("spinner-shared", 15, "spinner", `Shared folder missing (have {childNames(astral)})`)
		end
		return nil
	end
	local node = sharedFolder:FindFirstChild("NumberSpinner")
	if node == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("spinner-module", 15, "spinner", `NumberSpinner missing (have {childNames(sharedFolder)})`)
		end
		return nil
	end
	local moduleScript = resolveModuleScript(node)
	if moduleScript == nil then
		ClientLog:warn("spinner", `NumberSpinner is a {node.ClassName}, not a ModuleScript`)
		loadFailed = true
		return nil
	end
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	if not ok or result == nil then
		ClientLog:warn("spinner", `couldn't load NumberSpinner: {tostring(result)}`)
		loadFailed = true
		return nil
	end
	local _new = result.new
	if (type(_new) == "function") ~= true then
		ClientLog:warn("spinner", "loaded module has no constructor")
		loadFailed = true
		return nil
	end
	cachedModule = result
	pendingWarned = false
	return cachedModule
end
local function sanitizeValue(value, decimals)
	local _value = value
	local _condition = not (type(_value) == "number")
	if not _condition then
		_condition = value ~= value or value == math.huge or value == -math.huge
	end
	if _condition then
		return 0
	end
	local capped = math.clamp(value, -1e100, 1e100)
	if decimals <= 0 then
		return math.floor(capped + (if capped >= 0 then 0.5 else -0.5))
	end
	local factor = 10 ^ decimals
	return math.floor(capped * factor + (if capped >= 0 then 0.5 else -0.5)) / factor
end
local function spinDisplay(raw, extraSuffix, spacedSuffix)
	local parts = compactSpinParts(raw)
	local lead = if spacedSuffix and parts.suffix ~= "" then " " else ""
	return {
		value = parts.value,
		suffix = `{lead}{parts.suffix}{extraSuffix}`,
		decimals = parts.decimals,
		band = parts.suffix,
	}
end
local function formatRawLabel(value, prefix, extraSuffix, spacedSuffix)
	local display = spinDisplay(value, extraSuffix, spacedSuffix)
	local amount = sanitizeValue(display.value, display.decimals)
	local abs = math.abs(amount)
	local body = string.format(if display.decimals <= 0 then "%.0f" elseif display.decimals == 1 then "%.1f" else "%.2f", abs)
	return `{prefix}{if amount < 0 then "-" else ""}{body}{display.suffix}`
end
local function applyChrome(spinner, opts)
	-- Duration and Decimals both call Spinner:Update, which reassigns every digit.
	-- Skip them when they already match so a value push is not a second roll.
	if spinner.Duration ~= opts.duration then
		spinner.Duration = opts.duration
	end
	if spinner.Decimals ~= opts.decimals then
		spinner.Decimals = opts.decimals
	end
	spinner.Prefix = opts.prefix
	spinner.Suffix = opts.suffix
	spinner.TextSize = opts.size
	spinner.TextColor3 = opts.color
	spinner.TextStrokeTransparency = 1
	spinner.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	spinner.FontFace = SPINNER_FONT
	spinner.TextXAlignment = opts.align
	spinner.Commas = false
	spinner.ClipsDescendants = true
end
local function setDigitTracking(spinner, scale, gap)
	local padding = UDim.new(0, math.clamp(math.floor(gap), -3, 6))
	if spinner.Layout.Padding ~= padding then
		spinner.Layout.Padding = padding
	end
	if scale >= 0.995 then
		return nil
	end
	local baseWidth = math.max(6, math.floor(spinner.TextSize * 0.7 + 0.5))
	local width = math.max(6, math.floor(baseWidth * math.clamp(scale, 0.65, 1) + 0.5))
	for _, child in spinner.Frame:GetChildren() do
		if not child:IsA("Frame") or child.Name ~= "digit" then
			continue
		end
		local nextSize = UDim2.fromOffset(width, child.Size.Y.Offset)
		if child.Size ~= nextSize then
			child.Size = nextSize
		end
	end
end
local function rollDurationForJump(base, fromRaw, toRaw, fromBand, toBand, motionScale)
	local scale = math.clamp(if motionScale == nil then 1 else motionScale, 0.35, 1.35)
	if fromBand ~= toBand then
		return 0.04 * scale
	end
	local jump = math.abs(toRaw - fromRaw)
	local magnitude = math.log10(math.max(1, jump))
	local rel = if fromRaw > 0 then jump / fromRaw else jump
	if magnitude >= 6 or rel >= 0.35 then
		return 0.08 * scale
	end
	if magnitude >= 4 or rel >= 0.12 then
		return 0.16 * scale
	end
	local fromParts = compactSpinParts(fromRaw)
	local toParts = compactSpinParts(toRaw)
	local mantJump = math.abs(toParts.value - fromParts.value)
	if mantJump >= 50 then
		return 0.14 * scale
	end
	if mantJump >= 8 then
		return 0.24 * scale
	end
	-- Digit.luau fake-spins an unchanged digit when Duration is at least 0.34.
	-- That module is shared, not client-owned, so small rolls stay under the snap cutoff.
	return math.clamp(base * 0.62 * scale, 0.26, 0.33)
end
local VELOCITY_TICK_HZ = 5
local VELOCITY_TICK_DT = 1 / VELOCITY_TICK_HZ

-- One thread for every velocity-driven spinner on screen.
local velocitySteps = {}
local velocityStepCount = 0
local velocityWorker = nil
local function registerVelocityStep(step)
	velocitySteps[step] = true
	velocityStepCount += 1
	if velocityWorker == nil then
		velocityWorker = task.spawn(function()
			while velocityStepCount > 0 do
				task.wait(VELOCITY_TICK_DT)
				for step in velocitySteps do
					-- One spinner erroring must not stop the others (or the ticker).
					pcall(step)
				end
			end
			velocityWorker = nil
		end)
	end
	return function()
		if velocitySteps[step] then
			velocitySteps[step] = nil
			velocityStepCount -= 1
		end
	end
end
local VELOCITY_ROLL = 0.07
local function NumberSpinnerHost(_param)
	local value = _param.value
	local requestedReducedMotion = _param.reducedMotion
	if requestedReducedMotion == nil then
		requestedReducedMotion = false
	end
	local duration = _param.duration
	if duration == nil then
		duration = 0.78
	end
	local prefix = _param.prefix
	if prefix == nil then
		prefix = ""
	end
	local extraSuffix = _param.extraSuffix
	if extraSuffix == nil then
		extraSuffix = ""
	end
	local spacedSuffix = _param.spacedSuffix
	if spacedSuffix == nil then
		spacedSuffix = false
	end
	local _decimals = _param.decimals
	if _decimals == nil then
		_decimals = 0
	end
	local velocity = _param.velocity
	if velocity == nil then
		velocity = 0
	end
	local size = _param.size
	if size == nil then
		size = 16
	end
	local color = _param.color
	if color == nil then
		color = Palette.white
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local position = _param.position
	local sizeConstraint = _param.sizeConstraint
	if sizeConstraint == nil then
		sizeConstraint = UDim2.fromScale(1, 1)
	end
	local autoWidth = _param.autoWidth
	if autoWidth == nil then
		autoWidth = false
	end
	local digitWidthScale = _param.digitWidthScale
	if digitWidthScale == nil then
		digitWidthScale = 1
	end
	local digitGap = _param.digitGap
	if digitGap == nil then
		digitGap = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local _binding = useMotionSettings()
	local numberScale = _binding.numberScale
	if numberScale == nil then
		numberScale = 1
	end
	local motionScale = _binding.motionScale
	if motionScale == nil then
		motionScale = 1
	end
	local reducedMotion = requestedReducedMotion or numberScale <= 0.02
	local hostRef = React.useRef()
	local spinnerRef = React.useRef()
	local guideRef = React.useRef()
	local fallbackRef = React.useRef()
	local lastRawRef = React.useRef(nil)
	local lastBandRef = React.useRef("")
	local lastMantissaRef = React.useRef(nil)
	local targetRef = React.useRef(value)
	local velocityRef = React.useRef(velocity)
	local autoWidthRef = React.useRef(autoWidth)
	local styleRef = React.useRef({
		duration = duration,
		prefix = prefix,
		extraSuffix = extraSuffix,
		spacedSuffix = spacedSuffix,
		size = size,
		color = color,
		align = align,
		digitWidthScale = digitWidthScale,
		digitGap = digitGap,
	})
	local velocitySnapRef = React.useRef(false)
	local pulseResetRef = React.useRef()
	local motionScaleRef = React.useRef(motionScale)
	motionScaleRef.current = motionScale
	local live, setLive = React.useState(false)
	local label = formatRawLabel(value, prefix, extraSuffix, spacedSuffix)
	local contentWidth, setContentWidth = React.useState(function()
		return estimateLabelWidth(label, size)
	end)
	local contentWidthRef = React.useRef(contentWidth)
	local quietChromeRef = React.useRef({
		size = nil,
		color = nil,
		align = nil,
		prefix = nil,
		suffix = nil,
	})
	targetRef.current = value
	velocityRef.current = velocity
	autoWidthRef.current = autoWidth
	styleRef.current = {
		duration = duration,
		prefix = prefix,
		extraSuffix = extraSuffix,
		spacedSuffix = spacedSuffix,
		size = size,
		color = color,
		align = align,
		digitWidthScale = digitWidthScale,
		digitGap = digitGap,
	}
	local pulseAccent = React.useCallback(function(spinner, base)
		if pulseResetRef.current ~= nil then
			pcall(task.cancel, pulseResetRef.current)
		end
		spinner.TextColor3 = lighten(base, 0.48)
		pulseResetRef.current = task.delay(0.18, function()
			pulseResetRef.current = nil
			if spinnerRef.current ~= spinner then
				return nil
			end
			spinner.TextColor3 = styleRef.current.color
		end)
	end, {})
	local destroySpinner = React.useCallback(function()
		if pulseResetRef.current ~= nil then
			pcall(task.cancel, pulseResetRef.current)
			pulseResetRef.current = nil
		end
		local spinner = spinnerRef.current
		spinnerRef.current = nil
		lastRawRef.current = nil
		lastMantissaRef.current = nil
		lastBandRef.current = ""
		if spinner ~= nil then
			local frame = spinner.Frame
			local destroyed = pcall(function()
				spinner:Destroy()
			end)
			if not destroyed and typeof(frame) == "Instance" then
				pcall(function()
					frame:Destroy()
				end)
			end
		end
		local guide = guideRef.current
		if guide ~= nil then
			guide:Destroy()
			guideRef.current = nil
		end
		local fallback = fallbackRef.current
		if fallback ~= nil then
			fallback.Visible = true
			fallback.TextTransparency = 0
		end
		setLive(false)
	end, {})
	local pushDisplay = React.useCallback(function(spinner, raw, roll, pulse)
		local style = styleRef.current
		local display = spinDisplay(raw, style.extraSuffix, style.spacedSuffix)
		local mantissa = sanitizeValue(display.value, display.decimals)
		local prevMantissa = lastMantissaRef.current
		local bandChanged = lastBandRef.current ~= display.band
		lastRawRef.current = raw
		-- Duration/Decimals/Value all call Spinner:Update, which reassigns every digit.
		-- An unchanged mantissa still rolls when Duration is >= 0.34, so identical
		-- production ticks must not touch those props.
		if prevMantissa == mantissa and not bandChanged then
			local quiet = quietChromeRef.current
			if quiet.size ~= style.size then
				spinner.TextSize = style.size
				quiet.size = style.size
			end
			if quiet.color ~= style.color then
				spinner.TextColor3 = style.color
				quiet.color = style.color
			end
			if quiet.align ~= style.align then
				spinner.TextXAlignment = style.align
				quiet.align = style.align
			end
			if quiet.prefix ~= style.prefix then
				spinner.Prefix = style.prefix
				quiet.prefix = style.prefix
			end
			if quiet.suffix ~= style.suffix then
				spinner.Suffix = style.suffix
				quiet.suffix = style.suffix
			end
			return nil
		end
		applyChrome(spinner, {
			duration = roll,
			decimals = display.decimals,
			prefix = style.prefix,
			suffix = display.suffix,
			size = style.size,
			color = style.color,
			align = style.align,
		})
		lastBandRef.current = display.band
		quietChromeRef.current.size = style.size
		quietChromeRef.current.color = style.color
		quietChromeRef.current.align = style.align
		quietChromeRef.current.prefix = style.prefix
		quietChromeRef.current.suffix = style.suffix
		spinner.Value = mantissa
		setDigitTracking(spinner, style.digitWidthScale, style.digitGap)
		lastMantissaRef.current = mantissa
		if pulse and prevMantissa ~= nil then
			pulseAccent(spinner, style.color)
		end
	end, { pulseAccent })
	local ensureSpinner = React.useCallback(function()
		if reducedMotion then
			return nil
		end
		local existing = spinnerRef.current
		local existingFrame = if existing ~= nil then existing.Frame else nil
		if typeof(existingFrame) == "Instance" and existingFrame.Parent ~= nil then
			return existing
		end
		destroySpinner()
		local host = hostRef.current
		local mod = loadModule()
		if host == nil or mod == nil then
			return nil
		end
		local fallback = fallbackRef.current
		if fallback ~= nil then
			fallback.Visible = false
			fallback.TextTransparency = 1
		end
		for _, child in host:GetChildren() do
			if child.Name == "NumberSpinnerGuide" or string.sub(child.Name, 1, 8) == "Spinner_" then
				child:Destroy()
			end
		end
		local style = styleRef.current
		local guide = Instance.new("TextLabel")
		guide.Name = "NumberSpinnerGuide"
		guide.BackgroundTransparency = 1
		guide.BorderSizePixel = 0
		guide.Size = if autoWidthRef.current then UDim2.new(0, 0, 1, 0) else UDim2.fromScale(1, 1)
		guide.AutomaticSize = if autoWidthRef.current then Enum.AutomaticSize.X else Enum.AutomaticSize.None
		guide.FontFace = SPINNER_FONT
		guide.TextSize = style.size
		guide.TextColor3 = style.color
		guide.TextXAlignment = style.align
		guide.TextYAlignment = Enum.TextYAlignment.Center
		guide.TextScaled = false
		guide.TextStrokeTransparency = 1
		guide.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		guide.Text = ""
		guide.Parent = host
		guideRef.current = guide
		local spinner = if mod.fromGuiObject ~= nil then mod.fromGuiObject(guide) else nil
		if spinner == nil then
			spinner = mod.new()
			spinner.Parent = host
			spinner.Size = if autoWidthRef.current then UDim2.new(0, 0, 1, 0) else UDim2.fromScale(1, 1)
			spinner.Position = UDim2.fromScale(0, 0)
			spinner.BackgroundTransparency = 1
			spinner.FontFace = guide.FontFace
			guide.Visible = false
		end
		if autoWidthRef.current then
			spinner.AutomaticSize = Enum.AutomaticSize.X
			spinner.Size = UDim2.new(0, 0, 1, 0)
			spinner.ClipsDescendants = true
			hugSpinnerContent(host)
		end
		local initialRaw = targetRef.current
		local display = spinDisplay(initialRaw, style.extraSuffix, style.spacedSuffix)
		applyChrome(spinner, {
			duration = 0.08,
			decimals = display.decimals,
			prefix = style.prefix,
			suffix = display.suffix,
			size = style.size,
			color = style.color,
			align = style.align,
		})
		local mantissa = sanitizeValue(display.value, display.decimals)
		spinner.Value = mantissa
		setDigitTracking(spinner, style.digitWidthScale, style.digitGap)
		lastRawRef.current = initialRaw
		lastBandRef.current = display.band
		lastMantissaRef.current = mantissa
		spinnerRef.current = spinner
		setLive(true)
		return spinner
	end, { destroySpinner, reducedMotion })
	React.useEffect(function()
		if reducedMotion then
			destroySpinner()
			return nil
		end
		local cancelled = false
		local attempts = 0
		local retryJob
		local tryMount
		tryMount = function()
			if cancelled then
				return nil
			end
			attempts += 1
			if ensureSpinner() == nil and attempts < 100 then
				retryJob = task.delay(0.1, tryMount)
			end
		end
		local mountJob = task.defer(tryMount)
		return function()
			cancelled = true
			if mountJob ~= nil then
				pcall(task.cancel, mountJob)
			end
			if retryJob ~= nil then
				pcall(task.cancel, retryJob)
			end
			mountJob = nil
			retryJob = nil
			destroySpinner()
		end
	end, { destroySpinner, ensureSpinner, reducedMotion })
	React.useEffect(function()
		if reducedMotion then
			return nil
		end
		local spinner = ensureSpinner()
		if spinner == nil then
			return nil
		end
		local style = styleRef.current
		local previous = lastRawRef.current
		local producing = velocityRef.current > 0
		if producing and previous ~= nil then
			local jump = math.abs(value - previous)
			if jump > 0 and jump < math.max(3, velocityRef.current * 0.35) then
				return nil
			end
		end
		local fromBand = if previous ~= nil then spinDisplay(previous, style.extraSuffix, style.spacedSuffix).band else ""
		local toBand = spinDisplay(value, style.extraSuffix, style.spacedSuffix).band
		local roll = if previous ~= nil then rollDurationForJump(style.duration, previous, value, fromBand, toBand, motionScaleRef.current) else 0.08
		velocitySnapRef.current = false
		local jump = if previous ~= nil then math.abs(value - previous) else 0
		local shouldPulse = previous ~= nil and jump >= math.max(18, math.abs(previous) * 0.03 + 1)
		pushDisplay(spinner, value, roll, shouldPulse)
	end, { align, color, duration, ensureSpinner, extraSuffix, prefix, pushDisplay, reducedMotion, size, value })
	React.useEffect(function()
		if not live or reducedMotion or velocity <= 0 then
			return nil
		end
		local alive = true
		local _condition = lastRawRef.current
		if _condition == nil then
			_condition = targetRef.current
		end
		local displayRaw = _condition
		local previousAt = os.clock()
		-- One step per spinner, run by the shared ticker below (was one task.spawn loop
		-- per spinner: N spinners meant N threads waking 5x a second).
		local function step()
			do
				if not alive then
					return
				end
				local now = os.clock()
				local dt = math.min(1, now - previousAt)
				previousAt = now
				local spinner = ensureSpinner()
				if spinner == nil then
					return
				end
				local server = targetRef.current
				local rate = math.max(0, velocityRef.current)
				if server > displayRaw then
					displayRaw = server
				end
				displayRaw += rate * dt
				local ceiling = server + rate * 2
				if displayRaw > ceiling then
					displayRaw = ceiling
				end
				local style = styleRef.current
				local compact = spinDisplay(displayRaw, style.extraSuffix, style.spacedSuffix)
				local mantissa = sanitizeValue(compact.value, compact.decimals)
				if mantissa == lastMantissaRef.current and compact.band == lastBandRef.current then
					lastRawRef.current = displayRaw
					return
				end
				local bandChanged = lastBandRef.current ~= compact.band
				local roll = if bandChanged then 0.03 else VELOCITY_ROLL
				if not velocitySnapRef.current or bandChanged then
					velocitySnapRef.current = true
				end
				applyChrome(spinner, {
					duration = roll,
					decimals = compact.decimals,
					prefix = style.prefix,
					suffix = compact.suffix,
					size = style.size,
					color = style.color,
					align = style.align,
				})
				spinner.Value = mantissa
				lastRawRef.current = displayRaw
				lastBandRef.current = compact.band
				lastMantissaRef.current = mantissa
			end
		end
		local unregister = registerVelocityStep(step)
		return function()
			alive = false
			unregister()
		end
	end, { ensureSpinner, live, reducedMotion, velocity })
	React.useEffect(function()
		if not autoWidth then
			return nil
		end
		if reducedMotion or not live then
			local estimated = estimateLabelWidth(label, size)
			contentWidthRef.current = estimated
			setContentWidth(estimated)
			return nil
		end
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local connections = {}
		local boundLayout
		local layoutConnection
		local settleJob
		local cancelled = false
		local sync
		sync = function()
			if cancelled then
				return nil
			end
			local layout = hugSpinnerContent(host) or findSpinnerLayout(host)
			if layout == nil then
				return nil
			end
			if boundLayout ~= layout then
				local _result = layoutConnection
				if _result ~= nil then
					_result:Disconnect()
				end
				boundLayout = layout
				layoutConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(sync)
			end
			local measured = math.ceil(layout.AbsoluteContentSize.X) + AUTO_WIDTH_PAD
			if measured > AUTO_WIDTH_PAD and measured > contentWidthRef.current then
				contentWidthRef.current = measured
				setContentWidth(measured)
			end
			if settleJob ~= nil then
				pcall(task.cancel, settleJob)
			end
			settleJob = task.delay(0.24, function()
				settleJob = nil
				if cancelled or boundLayout == nil then
					return nil
				end
				local settled = math.ceil(boundLayout.AbsoluteContentSize.X) + AUTO_WIDTH_PAD
				if settled > AUTO_WIDTH_PAD and settled ~= contentWidthRef.current then
					contentWidthRef.current = settled
					setContentWidth(settled)
				end
			end)
		end
		sync()
		local _arg0 = host.ChildAdded:Connect(sync)
		table.insert(connections, _arg0)
		return function()
			cancelled = true
			if settleJob ~= nil then
				pcall(task.cancel, settleJob)
			end
			local _result = layoutConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { autoWidth, live, reducedMotion, size })
	React.useEffect(function()
		if not autoWidth or (not reducedMotion and live) then
			return nil
		end
		local estimated = estimateLabelWidth(label, size)
		contentWidthRef.current = estimated
		setContentWidth(estimated)
	end, { autoWidth, label, live, reducedMotion, size })
	local height = if sizeConstraint.Y.Offset > 0 then sizeConstraint.Y.Offset else size + 8
	local frameSize = if autoWidth then UDim2.fromOffset(math.max(1, contentWidth), height) else sizeConstraint
	local hostSize = if autoWidth then UDim2.new(0, 0, 1, 0) else UDim2.fromScale(1, 1)
	return React.createElement("frame", {
		Size = frameSize,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
	}, React.createElement("frame", {
		ref = hostRef,
		Size = hostSize,
		AutomaticSize = if autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex + 1,
	}), (reducedMotion or not live) and (if autoWidth then React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = color,
		TextSize = size,
		FontFace = SPINNER_FONT,
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1,
		ZIndex = zIndex,
	}) else React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Text = label,
		TextColor3 = color,
		TextSize = size,
		FontFace = SPINNER_FONT,
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeTransparency = 1,
		ZIndex = zIndex,
	}, React.createElement("uitextsizeconstraint", {
		MinTextSize = math.min(10, math.max(1, size)),
		MaxTextSize = math.max(size, 1),
	}))))
end
return {
	NumberSpinnerHost = NumberSpinnerHost,
}
end

-- ======================================================================
-- Module: egooeHost   (merged from egooeHost.luau, 172 lines)
-- ======================================================================
__defs["egooeHost"] = function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local HOST_NAME = "AstralForgeEgooE"
local function loadEgooe()
	local include = ReplicatedStorage:FindFirstChild("rbxts_include")
	local _modules = include
	if _modules ~= nil then
		_modules = _modules:FindFirstChild("node_modules")
	end
	local modules = _modules
	local _scope = modules
	if _scope ~= nil then
		_scope = _scope:FindFirstChild("@rbxts")
	end
	local scope = _scope
	local _pack = scope
	if _pack ~= nil then
		_pack = _pack:FindFirstChild("egooe")
	end
	local pack = _pack
	local _out = pack
	if _out ~= nil then
		_out = _out:FindFirstChild("out")
	end
	local out = _out
	if out == nil or not out:IsA("ModuleScript") then
		return nil
	end
	local ok, loaded = pcall(function()
		return require(out)
	end)
	if not ok then
		warn(`[WARN] [EGOOE] couldn't load studio overlay: {tostring(loaded)}`)
		return nil
	end
	return loaded
end
local function startEgooeHost(playerGui)
	if not RunService:IsStudio() then
		return function()
			return nil
		end
	end
	local hostGui = playerGui or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if hostGui == nil then
		return function()
			return nil
		end
	end
	local stale = hostGui:FindFirstChild(HOST_NAME)
	if stale ~= nil then
		stale:Destroy()
	end
	local layer = Instance.new("ScreenGui")
	layer.Name = HOST_NAME
	layer.ResetOnSpawn = false
	layer.IgnoreGuiInset = true
	layer.DisplayOrder = 240
	layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	layer.Parent = hostGui
	local api
	local node
	local open = false
	local showDemo = false
	local frames = 0
	local fps = 60
	local sampleAt = os.clock()
	local heartbeat
	local paint = function(dt)
		if api == nil then
			return nil
		end
		frames += 1
		local now = os.clock()
		if now - sampleAt >= 0.4 then
			fps = frames / math.max(0.001, now - sampleAt)
			frames = 0
			sampleAt = now
		end
		local player = Players.LocalPlayer
		api.start(node, function()
			if not open then
				return nil
			end
			local handle = api.window({
				title = "Astral Forge",
				closable = true,
				minimizable = true,
				movable = true,
				resizable = true,
				size = Vector2.new(340, 300),
				position = Vector2.new(18, 86),
			}, function()
				api.heading("Studio debug")
				api.separator()
				api.label(`FPS     {string.format("%.0f", fps)}  ({string.format("%.1f", dt * 1000)} ms)`)
				api.label(`Player  {player.Name}  ({player.UserId})`)
				api.label(`Mem     {string.format("%.1f", Stats:GetTotalMemoryUsageMb())} MB`)
				api.label(`Inst    {Stats.InstanceCount}`)
				api.space()
				api.label("F8 toggles this overlay. It is not the game UI.")
				api.separator()
				local gallery = api.checkbox("Widget gallery", {
					checked = showDemo,
				})
				if gallery:clicked() then
					showDemo = not showDemo
				end
				if api.button("Close overlay"):clicked() then
					open = false
				end
			end)
			if handle:closed() then
				open = false
			end
			if showDemo then
				api.demoWindow()
			end
		end)
	end
	local ensureHeartbeat = function()
		if heartbeat ~= nil then
			return nil
		end
		heartbeat = RunService.Heartbeat:Connect(paint)
	end
	local stopHeartbeat = function()
		local _result = heartbeat
		if _result ~= nil then
			_result:Disconnect()
		end
		heartbeat = nil
	end
	local setOpen = function(shouldOpen)
		if shouldOpen and api == nil then
			api = loadEgooe()
			if api == nil then
				return nil
			end
			node = api.new(layer)
		end
		open = shouldOpen and api ~= nil
		if open then
			ensureHeartbeat()
		else
			stopHeartbeat()
			for _, child in layer:GetChildren() do
				child:Destroy()
			end
		end
	end
	local input = UserInputService.InputBegan:Connect(function(inputObject, processed)
		if processed then
			return nil
		end
		if inputObject.KeyCode ~= Enum.KeyCode.F8 then
			return nil
		end
		setOpen(not open)
	end)
	return function()
		input:Disconnect()
		stopHeartbeat()
		layer:Destroy()
	end
end
return {
	startEgooeHost = startEgooeHost,
}
end

-- ======================================================================
-- Module: AnimatedTitle   (merged from AnimatedTitle.luau, 13 lines)
-- ======================================================================
__defs["AnimatedTitle"] = function()
local exports = {}
-- Player titles now render through the HyperText vendor module (real per-character motion,
-- gradients, and particle effects) instead of the old color/stroke-only glyph tricks -- see
-- HyperTextHost.tsx for the renderer and per-kind markup. Kept as a re-export so ChatView.tsx and
-- CommandView.tsx don't need to change their import path.
local _HyperTextHost = __load("HyperTextHost")
exports.AnimatedTitle = _HyperTextHost.AnimatedTitle
exports.AnimatedTitlePreview = _HyperTextHost.AnimatedTitlePreview
exports.darkTitlePlate = _HyperTextHost.darkTitlePlate
exports.parseFx = _HyperTextHost.parseFx
exports.titleFxAccent = _HyperTextHost.titleFxAccent
exports.TITLE_FX_KINDS = _HyperTextHost.TITLE_FX_KINDS
return exports
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
