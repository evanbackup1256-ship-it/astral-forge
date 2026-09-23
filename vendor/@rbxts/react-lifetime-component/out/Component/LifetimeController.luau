-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local useAsyncEffect = TS.import(script, TS.getModule(script, "@rbxts", "pretty-react-hooks").out).useAsyncEffect
local _react = TS.import(script, TS.getModule(script, "@rbxts", "react"))
local React = _react
local useCallback = _react.useCallback
local useEffect = _react.useEffect
local useMemo = _react.useMemo
local useRef = _react.useRef
local useState = _react.useState
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LifetimeInternal = newproxy()
local UIDInternal = newproxy()
local LifetimeController
do
	LifetimeController = setmetatable({}, {
		__tostring = function()
			return "LifetimeController"
		end,
	})
	LifetimeController.__index = LifetimeController
	function LifetimeController.new(...)
		local self = setmetatable({}, LifetimeController)
		return self:constructor(...) or self
	end
	function LifetimeController:constructor()
		self.CanRecover = false
		self.AllComponents = {}
		self.CurrentRendered = {}
		self.Updater = function() end
	end
	function LifetimeController:SetUpdater(updater)
		self.Updater = updater
	end
	function LifetimeController:GetComponent(uid)
		local _allComponents = self.AllComponents
		local _uid = uid
		return _allComponents[_uid]
	end
	function LifetimeController:IsComponentActive(uid)
		local component = self:GetComponent(uid)
		if not component then
			return false
		end
		local render = self:GetRendered(component)
		if render == nil then
			return false
		end
		return self.CurrentRendered[render] == uid
	end
	function LifetimeController:GetRendered(component)
		local _currentRendered = self.CurrentRendered
		local _key = component.Key
		local renderKey = _currentRendered[_key]
		if renderKey == nil then
			return renderKey
		end
		if renderKey ~= component.UID then
			return nil
		end
		return component.Key
	end
	function LifetimeController:RemoveRenderedByUID(uid)
		local component = self:GetComponent(uid)
		if not component then
			return nil
		end
		local _currentRendered = self.CurrentRendered
		local _key = component.Key
		local rendered = _currentRendered[_key]
		if rendered == uid then
			local _currentRendered_1 = self.CurrentRendered
			local _key_1 = component.Key
			_currentRendered_1[_key_1] = nil
		end
	end
	function LifetimeController:UnlistComponent(uid)
		if self:IsComponentActive(uid) then
			return nil
		end
		self:RemoveRenderedByUID(uid)
		local _allComponents = self.AllComponents
		local _uid = uid
		_allComponents[_uid] = nil
		self.Updater()
	end
	function LifetimeController:RegistryComponent(element, key)
		local uid = HttpService:GenerateGUID()
		local newComponent = {
			Key = key,
			Element = element,
			UID = uid,
		}
		self.AllComponents[uid] = newComponent
		local _currentRendered = self.CurrentRendered
		local _key = key
		_currentRendered[_key] = uid
	end
	function LifetimeController:UpdateComponent(uid, element)
		local _allComponents = self.AllComponents
		local _uid = uid
		local component = _allComponents[_uid]
		if not component then
			return nil
		end
		local _allComponents_1 = self.AllComponents
		local _exp = uid
		local _object = table.clone(component)
		setmetatable(_object, nil)
		_object.Element = element
		_allComponents_1[_exp] = _object
	end
	function LifetimeController:GetRenderedComponentByKey(key)
		for _, component in self.AllComponents do
			if component.Key == key then
				return component
			end
		end
	end
	function LifetimeController:ProcessChildren(children)
		local newChildren = {}
		local _exp = self.CurrentRendered
		-- ▼ ReadonlyMap.forEach ▼
		local _callback = function(uid, key)
			local _children = children
			local _key = key
			local child = _children[_key]
			if not child then
				return nil
			end
			local _key_1 = key
			local _uid = uid
			newChildren[_key_1] = _uid
			self:UpdateComponent(uid, child)
		end
		for _k, _v in _exp do
			_callback(_v, _k, _exp)
		end
		-- ▲ ReadonlyMap.forEach ▲
		self.CurrentRendered = newChildren
		-- ▼ ReadonlyMap.forEach ▼
		local _callback_1 = function(child, key)
			local _currentRendered = self.CurrentRendered
			local _key = key
			local uid = _currentRendered[_key]
			if uid == nil then
				if self.CanRecover then
					local component = self:GetRenderedComponentByKey(key)
					if component then
						self:UpdateComponent(component.UID, child)
						local _currentRendered_1 = self.CurrentRendered
						local _key_1 = key
						local _uID = component.UID
						_currentRendered_1[_key_1] = _uID
						return nil
					end
				end
				self:RegistryComponent(child, key)
			end
		end
		for _k, _v in children do
			_callback_1(_v, _k, children)
		end
		-- ▲ ReadonlyMap.forEach ▲
	end
	function LifetimeController:RenderComponents()
		local renderedChildren = {}
		local _exp = self.AllComponents
		-- ▼ ReadonlyMap.forEach ▼
		local _callback = function(component, uid)
			local child = {}
			local element = component.Element
			if element.props ~= nil then
				local props = (element.props) or {}
				props[LifetimeInternal] = self
				props[UIDInternal] = uid
				local _exp_1 = component.Key
				local _exp_2 = element.type
				local _object = table.clone(props)
				setmetatable(_object, nil)
				local _arg1 = React.createElement(_exp_2, _object)
				child[_exp_1] = _arg1
			else
				local _key = component.Key
				child[_key] = element
			end
			local _uid = uid
			local _arg1 = React.createElement(React.Fragment, nil, child)
			renderedChildren[_uid] = _arg1
		end
		for _k, _v in _exp do
			_callback(_v, _k, _exp)
		end
		-- ▲ ReadonlyMap.forEach ▲
		return renderedChildren
	end
end
-- ---------------------------------- HOOKS --------------------------------- 
local function useIntrinsicData(props)
	local uid = props[UIDInternal]
	local controller = props[LifetimeInternal]
	if uid == nil or not controller then
		return nil
	end
	return {
		uid = uid,
		controller = controller,
	}
end
--[[
	*
	 * Checks if the component is active in the LifetimeController children list (returns true when it's not inside a LifetimeComponent)
	 * @param props your component props
	 * @returns true if the component is active
	 
]]
local function useComponentIsActive(props)
	local _binding = useIntrinsicData(props)
	local uid = _binding.uid
	local controller = _binding.controller
	if uid == nil or not controller then
		return true
	end
	return controller:IsComponentActive(uid)
end
--[[
	*
	 * Checks if the component was rendered instead of a LifetimeComponent
	 
]]
local function useIsLifetimeComponent(props)
	local data = useIntrinsicData(props)
	local isComponent = useMemo(function()
		-- using useMemo to avoid this from ever changing for whatever reason
		return data ~= nil
	end, {})
	return isComponent
end
--[[
	*
	 * Returns a function to set the time in seconds the component will be alive for
	 * @param props your component props
	 * @param seconds initial lifetime in seconds (can be reassigned later)
	 
]]
local function useComponentLifetime(props, initLifetime)
	local lifetime, setLifetime = useState(initLifetime)
	local unmountTick, setUnmountTick = useState()
	local _binding = useIntrinsicData(props)
	local uid = _binding.uid
	local controller = _binding.controller
	if uid == nil or not controller then
		error('You cant use useComponentLifetime hook in components that are not children of a "LifetimeComponent"')
	end
	local isActive = controller:IsComponentActive(uid)
	useEffect(function()
		if isActive then
			setUnmountTick(nil)
		else
			setUnmountTick(os.clock())
		end
	end, { isActive })
	useEffect(function()
		if unmountTick == nil then
			return nil
		end
		if isActive then
			return nil
		end
		if lifetime == nil then
			return nil
		end
		local connector = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - unmountTick > lifetime then
				controller:UnlistComponent(uid)
				setLifetime(nil)
			end
		end)
		return function()
			return connector:Disconnect()
		end
	end, { isActive, unmountTick, lifetime })
	return setLifetime
end
--[[
	*
	 * Defers the component unmount until the given number of frames have passed
	 * @param props your component props
	 * @param steps the number of frames to defer the component (default 1)
	 
]]
local function useDeferLifetime(props, frames)
	if frames == nil then
		frames = 1
	end
	local deferred = useRef(0)
	local active = useComponentIsActive(props)
	local _binding = useIntrinsicData(props)
	local uid = _binding.uid
	local controller = _binding.controller
	if uid == nil or not controller then
		error('You cant use useComponentLifetime hook in components that are not children of "LifetimeComponent"')
	end
	useEffect(function()
		if active then
			deferred.current = 0
			return nil
		end
		local connection = RunService.Heartbeat:Connect(function()
			deferred.current += 1
			if deferred.current < frames then
				return nil
			end
			controller:UnlistComponent(uid)
		end)
		return function()
			return connection:Disconnect()
		end
	end, { active, frames })
end
--[[
	*
	 * Returns a function to set an async function that will run when the component is not active
	 * and then removes the component when the async function resolves
	 * @param props your component props
	 * @param asyncCallback the initial async function (can be reassigned later)
	 
]]
local function useLifetimeAsync(props, asyncCallback)
	local _binding = useIntrinsicData(props)
	local uid = _binding.uid
	local controller = _binding.controller
	local asyncLifetime, setAsyncLifetime = useState(function()
		return asyncCallback
	end)
	local active = useComponentIsActive(props)
	if uid == nil or not controller then
		error('You cant use useComponentLifetime hook in components that are not children of "LifetimeComponent"')
	end
	local OnSetAsync = useCallback(function(asyncCallback)
		setAsyncLifetime(function()
			return asyncCallback
		end)
	end, {})
	useAsyncEffect(function()
		if not asyncLifetime or active then
			return TS.Promise.resolve()
		end
		return asyncLifetime():finally(function()
			controller:UnlistComponent(uid)
		end)
	end, { active, asyncLifetime })
	return OnSetAsync
end
local function SanitizeProps(props)
	local _props = props
	if not (type(_props) == "table") then
		return props
	end
	local newProps = {}
	for key, value in pairs(props) do
		local unknownKey = key
		if unknownKey == LifetimeInternal or unknownKey == UIDInternal then
			continue
		end
		newProps[unknownKey] = value
	end
	return newProps
end
return {
	useComponentIsActive = useComponentIsActive,
	useIsLifetimeComponent = useIsLifetimeComponent,
	useComponentLifetime = useComponentLifetime,
	useDeferLifetime = useDeferLifetime,
	useLifetimeAsync = useLifetimeAsync,
	SanitizeProps = SanitizeProps,
	LifetimeController = LifetimeController,
}
