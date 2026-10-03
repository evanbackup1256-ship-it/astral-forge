local isAbstractConstructor
local function isConstructor(obj)
	return isAbstractConstructor(obj) and obj.new ~= nil
end
function isAbstractConstructor(obj)
	return obj.constructor ~= nil
end
return {
	isConstructor = isConstructor,
	isAbstractConstructor = isAbstractConstructor,
}
