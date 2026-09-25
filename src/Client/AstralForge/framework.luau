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
		local ok, reason = pcall(function()
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
			if self.stateConnection ~= nil then
				pcall(function()
					self.stateConnection:disconnect()
				end)
				self.stateConnection = nil
			end
			local connection = store.changed:connect(syncDebugState)
			self.stateConnection = connection
			local bound, bindReason = pcall(function()
				self.instance.Destroying:Once(function()
					pcall(function()
						connection:disconnect()
					end)
					self.stateConnection = nil
				end)
			end)
			if not bound then
				pcall(function()
					connection:disconnect()
				end)
				self.stateConnection = nil
				error(bindReason, 0)
			end
		end)
		if not ok then
			ClientLog:warn("framework", `UiRootComponent onStart failed: {tostring(reason)}`)
		end
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
		AstralRenderFps = 60,
		AstralStepMs = 16,
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
		AstralRenderFps = t.number,
		AstralStepMs = t.number,
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
		self.announced = {}
		self.primaryRoot = nil
		self.ready = false
	end
	function UiRuntimeController:onInit()
		local ok, reason = pcall(function()
			self.ready = false
		end)
		if not ok then
			ClientLog:warn("framework", `UiRuntimeController onInit failed: {tostring(reason)}`)
		end
	end
	function UiRuntimeController:primary()
		return self.primaryRoot
	end
	function UiRuntimeController:onStart()
		local ok, reason = pcall(function()
			self.ready = true
			if self.addedConnection ~= nil then
				pcall(function()
					self.addedConnection:Disconnect()
				end)
				self.addedConnection = nil
			end
			local announced = self.announced
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
			self.addedConnection = self.components:onComponentAdded(function(component, root)
				local addedOk, addedReason = pcall(function()
					if self.primaryRoot == nil then
						self.primaryRoot = component
					end
					return announce(root)
				end)
				if not addedOk then
					ClientLog:warn("framework", `UiRuntimeController component add failed: {tostring(addedReason)}`)
				end
			end, "client/framework/init@UiRootComponent")
			for _, component in self.components:getAllComponents("client/framework/init@UiRootComponent") do
				if self.primaryRoot == nil then
					self.primaryRoot = component
				end
				announce(component.instance)
			end
		end)
		if not ok then
			ClientLog:warn("framework", `UiRuntimeController onStart failed: {tostring(reason)}`)
		end
	end
	do
		-- (Flamework) UiRuntimeController metadata
		Reflect.defineMetadata(UiRuntimeController, "identifier", "client/framework/init@UiRuntimeController")
		Reflect.defineMetadata(UiRuntimeController, "flamework:parameters", { "$c:components@Components" })
		Reflect.defineMetadata(UiRuntimeController, "flamework:implements", { "$:flamework@OnInit", "$:flamework@OnStart" })
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
	function DiagnosticsController:constructor(components, runtime)
		self.components = components
		self.runtime = runtime
		self.elapsed = 0
		self.booted = false
	end
	function DiagnosticsController:onInit()
		local ok, reason = pcall(function()
			self.booted = true
		end)
		if not ok then
			ClientLog:warn("framework", `DiagnosticsController onInit failed: {tostring(reason)}`)
		end
	end
	function DiagnosticsController:onStart()
		local ok, reason = pcall(function()
			if self.addedConnection ~= nil then
				pcall(function()
					self.addedConnection:Disconnect()
				end)
				self.addedConnection = nil
			end
			self.addedConnection = self.components:onComponentAdded(function(component)
				self.target = component
				return self.target
			end, "client/framework/init@UiRootComponent")
			local _binding = self.components:getAllComponents("client/framework/init@UiRootComponent")
			local existing = _binding[1]
			if existing ~= nil then
				self.target = existing
			end
		end)
		if not ok then
			ClientLog:warn("framework", `DiagnosticsController onStart failed: {tostring(reason)}`)
		end
	end
	function DiagnosticsController:onTick(dt)
		local ok, reason = pcall(function()
			self.elapsed += dt
			if self.elapsed < DIAGNOSTIC_INTERVAL_SECONDS then
				return nil
			end
			self.elapsed = 0
			local target = self.target
			if (target == nil or target.instance.Parent == nil) and self.runtime ~= nil then
				target = self.runtime:primary()
				self.target = target
			end
			if target == nil or target.instance.Parent == nil then
				return nil
			end
			local info = currentAntilagInfo()
			target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralAntilagTier", info.tier)
			target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralAntilagQuality", math.floor(info.quality * 100) / 100)
			target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralFps", math.floor(info.fps))
			target[SYMBOL_ATTRIBUTE_SETTER](target, "AstralHitchScore", math.floor(info.hitchScore * 100) / 100)
		end)
		if not ok then
			ClientLog:warnEvery("diagnostics-tick", 15, "framework", `DiagnosticsController onTick failed: {tostring(reason)}`)
		end
	end
	do
		-- (Flamework) DiagnosticsController metadata
		Reflect.defineMetadata(DiagnosticsController, "identifier", "client/framework/init@DiagnosticsController")
		Reflect.defineMetadata(DiagnosticsController, "flamework:parameters", { "$c:components@Components", "client/framework/init@UiRuntimeController" })
		Reflect.defineMetadata(DiagnosticsController, "flamework:implements", { "$:flamework@OnInit", "$:flamework@OnStart", "$:flamework@OnTick" })
	end
end
-- (Flamework) DiagnosticsController decorators
Reflect.decorate(DiagnosticsController, "$:flamework@Controller", Controller, { {
	loadOrder = 10,
} })
local ShellClockController
do
	ShellClockController = setmetatable({}, {
		__tostring = function()
			return "ShellClockController"
		end,
	})
	ShellClockController.__index = ShellClockController
	function ShellClockController.new(...)
		local self = setmetatable({}, ShellClockController)
		return self:constructor(...) or self
	end
	function ShellClockController:constructor(runtime)
		self.runtime = runtime
		self.renderElapsed = 0
		self.renderFrames = 0
		self.physicsElapsed = 0
		self.physicsFrames = 0
	end
	function ShellClockController:onInit()
		local ok, reason = pcall(function()
			self.renderElapsed = 0
			self.physicsElapsed = 0
		end)
		if not ok then
			ClientLog:warn("framework", `ShellClockController onInit failed: {tostring(reason)}`)
		end
	end
	function ShellClockController:publish(name, value)
		local root = self.runtime:primary()
		if root == nil or root.instance.Parent == nil then
			return nil
		end
		root[SYMBOL_ATTRIBUTE_SETTER](root, name, value)
	end
	function ShellClockController:onRender(dt)
		local ok, reason = pcall(function()
			self.renderElapsed += dt
			self.renderFrames += 1
			if self.renderElapsed < 0.5 then
				return nil
			end
			local fps = math.floor(self.renderFrames / math.max(self.renderElapsed, 0.001))
			self.renderElapsed = 0
			self.renderFrames = 0
			self:publish("AstralRenderFps", fps)
		end)
		if not ok then
			ClientLog:warnEvery("shell-render", 15, "framework", `ShellClockController onRender failed: {tostring(reason)}`)
		end
	end
	function ShellClockController:onPhysics(dt)
		local ok, reason = pcall(function()
			self.physicsElapsed += dt
			self.physicsFrames += 1
			if self.physicsElapsed < 0.5 then
				return nil
			end
			local ms = math.floor((self.physicsElapsed / math.max(self.physicsFrames, 1)) * 1000)
			self.physicsElapsed = 0
			self.physicsFrames = 0
			self:publish("AstralStepMs", ms)
		end)
		if not ok then
			ClientLog:warnEvery("shell-physics", 15, "framework", `ShellClockController onPhysics failed: {tostring(reason)}`)
		end
	end
	do
		Reflect.defineMetadata(ShellClockController, "identifier", "client/framework/init@ShellClockController")
		Reflect.defineMetadata(ShellClockController, "flamework:parameters", { "client/framework/init@UiRuntimeController" })
		Reflect.defineMetadata(ShellClockController, "flamework:implements", { "$:flamework@OnInit", "$:flamework@OnRender", "$:flamework@OnPhysics" })
	end
end
Reflect.decorate(ShellClockController, "$:flamework@Controller", Controller, { {
	loadOrder = 20,
} })
local initialized = false
local igniteFailed = false
local function initializeClientFramework(root)
	root:SetAttribute("AstralFrameworkBoot", "loading")
	if not CollectionService:HasTag(root, UI_ROOT_TAG) then
		CollectionService:AddTag(root, UI_ROOT_TAG)
	end
	if not initialized then
		-- Set before ignite so a yielding or failed start cannot enter ignite twice.
		initialized = true
		local ok, reason = pcall(function()
			Flamework.ignite()
			Flamework.resolveDependency("client/framework/init@UiRuntimeController")
			Flamework.resolveDependency("client/framework/init@ShellClockController")
		end)
		if not ok then
			igniteFailed = true
			ClientLog:warn("framework", `framework didn't start: {tostring(reason)}`)
			root:SetAttribute("AstralFrameworkBoot", "error")
			return nil
		end
	end
	if igniteFailed then
		root:SetAttribute("AstralFrameworkBoot", "error")
		return nil
	end
	root:SetAttribute("AstralFrameworkBoot", "ready")
end
return {
	initializeClientFramework = initializeClientFramework,
	UI_ROOT_TAG = UI_ROOT_TAG,
	UiRootComponent = UiRootComponent,
	UiRuntimeController = UiRuntimeController,
	DiagnosticsController = DiagnosticsController,
	ShellClockController = ShellClockController,
}
