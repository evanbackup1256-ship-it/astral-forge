type CoreReactBinding<T> = {
	getValue: (self: CoreReactBinding<T>) -> T,
	_source: string?,
}

type ReactBindingMap = {
	map: <T, U>(self: CoreReactBinding<T> & ReactBindingMap, (T) -> U) -> ReactBindingMap & CoreReactBinding<U>,
}

export type Binding<T> = CoreReactBinding<T> & ReactBindingMap

local function findPackage(name)
	local current = script.Parent
	for _ = 1, 4 do
		if current == nil then
			break
		end
		local found = current:FindFirstChild(name)
		if found ~= nil then
			return found
		end
		current = current.Parent
	end
	error(`{name} package was not found from {script:GetFullName()}`)
end
return require(findPackage("@rbxts-js").React)
