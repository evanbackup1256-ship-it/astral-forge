-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local _react = TS.import(script, TS.getModule(script, "@rbxts", "react"))
local React = _react
local isValidElement = _react.isValidElement
local useMemo = _react.useMemo
local LifetimeController = TS.import(script, script.Parent, "LifetimeController").LifetimeController
local function CreateChildrenMap(children, append)
	local appened = append or {}
	if not children then
		return appened
	end
	if isValidElement(children) then
		CreateChildrenMap({ children }, appened)
		return appened
	end
	for key, element in children do
		if isValidElement(element) then
			if element.key ~= nil then
				local _key = element.key
				appened[_key] = element
			else
				appened[key] = element
			end
		elseif type(element) == "table" then
			CreateChildrenMap(element, appened)
		end
	end
	return appened
end
local function LifetimeComponent(props)
	local _, setRerender = React.useState({})
	local controller = useMemo(function()
		local controller = LifetimeController.new()
		controller:SetUpdater(function()
			return setRerender({})
		end)
		return controller
	end, {})
	local _condition = props.CanRecover
	if _condition == nil then
		_condition = false
	end
	controller.CanRecover = _condition
	local children = CreateChildrenMap(props.children)
	controller:ProcessChildren(children)
	local toRender = controller:RenderComponents()
	return React.createElement(React.Fragment, nil, toRender)
end
local default = LifetimeComponent
return {
	default = default,
}
