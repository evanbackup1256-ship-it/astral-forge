local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local flamework = game.ReplicatedStorage.rbxts_include.node_modules["@flamework"]
local _core = importTsModule(flamework.core.out)
local _components = importTsModule(flamework.components.out)
local t = importTsModule(flamework.core.out.prelude).t
local SYMBOL_ATTRIBUTE_SETTER = importTsModule(flamework.components.out.baseComponent).SYMBOL_ATTRIBUTE_SETTER
local Reflect = _core.Reflect
local BaseComponent = _components.BaseComponent
local Component = _components.Component
local Controller = _core.Controller
local Flamework = _core.Flamework
local CollectionService = game:GetService("CollectionService")
local currentAntilagInfo = require(script.Parent.antilag).currentAntilagInfo
local getActiveClientStore = require(script.Parent.clientStore).getActiveClientStore
local ClientLog = require(script.Parent.log).ClientLog
-- Imported for its side effect: this registers LayoutGuardController with Flamework's
-- reflection metadata before Flamework.ignite() runs below. LayoutGuardController only
-- depends on UiRootComponent's *type* (for a Components<UiRootComponent> generic, resolved by
-- Flamework's decorator metadata, not a runtime value read from this module), so this import
-- does not create a real circular runtime dependency between the two files.
require(script.Parent.layoutGuard)
local UI_ROOT_TAG = "AstralForgeUiRoot"
-- A typed attribute schema for the root ScreenGui, shared by every component/controller that
-- reads or writes one of these — Flamework's BaseComponent<A> makes `this.attributes.X = value`
-- (and `onAttributeChanged("X", ...)`) type-checked against this shape instead of the raw
-- stringly-typed `SetAttribute`/`GetAttribute` calls this module used everywhere before.
local UiRootComponent
do
	local super = BaseComponent
	UiRootComponent = setmetatable({}, {
		__tostring = function()
			return "UiRootComponent"
		end,
		__index = super,
	})
	UiRootComponent.__index = UiRootComponent
	function UiRootComponent.new(...)
		local self = setmetatable({}, UiRootComponent)
		return self:constructor(...) or self
	end
	function UiRootComponent:constructor(...)
		super.constructor(self, ...)
	end
	function UiRootComponent:onStart()
		self.instance.ResetOnSpawn = false
		self.instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		self[SYMBOL_ATTRIBUTE_SETTER](self, "AstralFramework", "1")
		self[SYMBOL_ATTRIBUTE_SETTER](self, "AstralFrameworkReady", true)
		local store = getActiveClientStore()
		if store == nil then
			self[SYMBOL_ATTRIBUTE_SETTER](self, "AstralStateStatus", "store unavailable")
			return nil
		end
		local syncDebugState = function(state)
			self[SYMBOL_ATTRIBUTE_SETTER](self, "AstralRoute", state.navigation.page)
			local _self = self
			local _result = state.session
			if _result ~= nil then
				_result = _result.SnapshotId
			end
			local _condition = _result
			if _condition == nil then
				_condition = -1
			end
			_self[SYMBOL_ATTRIBUTE_SETTER](_self, "AstralSnapshot", _condition)
			self[SYMBOL_ATTRIBUTE_SETTER](self, "AstralStateStatus", if state.session == nil then "waiting for profile" else "live")
		end
		syncDebugState(store:getState())
		local connection = store.changed:connect(syncDebugState)
		self.instance.Destroying:Once(function()
			return connection:disconnect()
		end)
	end
	do
		-- (Flamework) UiRootComponent metadata
		Reflect.defineMetadata(UiRootComponent, "identifier", "client/framework/init@UiRootComponent")
		Reflect.defineMetadata(UiRootComponent, "flamework:implements", { "$:flamework@OnStart" })
	end
end
-- (Flamework) UiRootComponent decorators
Reflect.decorate(UiRootComponent, "$c:components@Component", Component, { {
	tag = UI_ROOT_TAG,
	warningTimeout = 0,
	defaults = {
		AstralFramework = "0",
		AstralFrameworkReady = false,
		AstralRoute = "",
		AstralSnapshot = -1,
		AstralStateStatus = "starting",
		AstralAntilagTier = 3,
		AstralAntilagQuality = 1,
		AstralFps = 60,
		AstralHitchScore = 0,
	},
	attributes = {
		AstralFramework = t.string,
		AstralFrameworkReady = t.boolean,
		AstralRoute = t.string,
		AstralSnapshot = t.number,
		AstralStateStatus = t.string,
		AstralAntilagTier = t.number,
		AstralAntilagQuality = t.number,
		AstralFps = t.number,
		AstralHitchScore = t.number,
	},
	instanceGuard = t.instanceIsA("ScreenGui"),
} })
local UiRuntimeController
do
	UiRuntimeController = setmetatable({}, {
		__tostring = function()
			return "UiRuntimeController"
		end,
	})
	UiRuntimeController.__index = UiRuntimeController
	function UiRuntimeController.new(...)
		local self = setmetatable({}, UiRuntimeController)
		return self:constructor(...) or self
	end
	function UiRuntimeController:constructor(components)
		self.components = components
	end
	function UiRuntimeController:onStart()
		local announced = {}
		local announce = function(root)
			local _root = root
			if announced[_root] ~= nil then
				return nil
			end
			local _root_1 = root
			announced[_root_1] = true
			root.Destroying:Once(function()
				local _root_2 = root
				-- ▼ Set.delete ▼
				local _valueExisted = announced[_root_2] ~= nil
				announced[_root_2] = nil
				-- ▲ Set.delete ▲
				return _valueExisted
			end)
			ClientLog:once("framework-ready", "framework", `{root.Name} ready`)
		end
		self.components:onComponentAdded(function(_component, root)
			return announce(root)
		end, "client/framework/init@UiRootComponent")
		for _, component in self.components:getAllComponents("client/framework/init@UiRootComponent") do
			announce(component.instance)
		end
	end
	do
		-- (Flamework) UiRuntimeController metadata
		Reflect.defineMetadata(UiRuntimeController, "identifier", "client/framework/init@UiRuntimeController")
		Reflect.defineMetadata(UiRuntimeController, "flamework:parameters", { "$c:components@Components" })
		Reflect.defineMetadata(UiRuntimeController, "flamework:implements", { "$:flamework@OnStart" })
	end
end
-- (Flamework) UiRuntimeController decorators
Reflect.decorate(UiRuntimeController, "$:flamework@Controller", Controller, { {
	loadOrder = -100,
} })
local DIAGNOSTIC_INTERVAL_SECONDS = 1
-- Mirrors live client performance state onto the same root ScreenGui's attributes,
-- alongside the route/snapshot attributes UiRootComponent already sets — so a Studio
-- session (or a remote admin tool reading player instance attributes) can see the current
-- antilag tier/quality/fps without needing a print statement or a debugger attached.
-- Runs after UiRuntimeController (default loadOrder 0) so at least one UiRootComponent has
-- usually already registered by the time this starts polling for one.
local DiagnosticsController
do
	DiagnosticsController = setmetatable({}, {
		__tostring = function()
			return "DiagnosticsController"
		end,
	})
	DiagnosticsController.__index = DiagnosticsController
	function DiagnosticsController.new(...)
		local self = setmetatable({}, DiagnosticsController)
		return self:constructor(...) or self
	end
	function DiagnosticsController:constructor(components)
		self.components = components
		self.elapsed = 0
	end
	function DiagnosticsController:onStart()
		self.components:onComponentAdded(function(component)
			self.target = component
			return self.target
		end, "client/framework/init@UiRootComponent")
		local _binding = self.components:getAllComponents("client/framework/init@UiRootComponent")
		local existing = _binding[1]
		if existing ~= nil then
			self.target = existing
		end
	end
	function DiagnosticsController:onTick(dt)
		self.elapsed += dt
		if self.elapsed < DIAGNOSTIC_INTERVAL_SECONDS then
			return nil
		end
		self.elapsed = 0
		local target = self.target
		if target == nil or target.instance.Parent == nil then
			return nil
		end
		local info = currentAntilagInfo()
		target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralAntilagTier", info.tier)
		target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralAntilagQuality", math.floor(info.quality * 100) / 100)
		target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralFps", math.floor(info.fps))
		target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralHitchScore", math.floor(info.hitchScore * 100) / 100)
	end
	do
		-- (Flamework) DiagnosticsController metadata
		Reflect.defineMetadata(DiagnosticsController, "identifier", "client/framework/init@DiagnosticsController")
		Reflect.defineMetadata(DiagnosticsController, "flamework:parameters", { "$c:components@Components" })
		Reflect.defineMetadata(DiagnosticsController, "flamework:implements", { "$:flamework@OnStart", "$:flamework@OnTick" })
	end
end
-- (Flamework) DiagnosticsController decorators
Reflect.decorate(DiagnosticsController, "$:flamework@Controller", Controller, { {
	loadOrder = 10,
} })
local initialized = false
local function initializeClientFramework(root)
	root:SetAttribute("AstralFrameworkBoot", "loading")
	if not CollectionService:HasTag(root, UI_ROOT_TAG) then
		CollectionService:AddTag(root, UI_ROOT_TAG)
	end
	if not initialized then
		Flamework.ignite()
		initialized = true
	end
	root:SetAttribute("AstralFrameworkBoot", "ready")
end
return {
	initializeClientFramework = initializeClientFramework,
	UI_ROOT_TAG = UI_ROOT_TAG,
	UiRootComponent = UiRootComponent,
	UiRuntimeController = UiRuntimeController,
	DiagnosticsController = DiagnosticsController,
}
