--!strict


local DataStoreService
do
	DataStoreService = game:GetService("DataStoreService")
end

local Retry = require(script.Parent:FindFirstChild("Retry"))
local Types = require(script.Parent:FindFirstChild("Types"))

type DataStoreInterface = Types.DataStoreInterface


local SaveUtil = {}


local RETRY = {
	ATTEMPTS = 5,
	INITIAL_WAIT = 1,
}



function SaveUtil.assertStorable(data: unknown, fieldName: string?)
	local indexDataType

	if not fieldName then
		fieldName = "Data"
	end


	assert(data == data, `NaN is not storable. Field: {fieldName}`)

	local dataType = type(data)

	assert(dataType ~= "userdata", `Userdata is not storable in DataStores. Field: {fieldName}`)

	assert(dataType ~= "thread", `Threads are not storable in DataStores. Field: {fieldName}`)

	assert(dataType ~= "function", `Functions are not storable in DataStores. Field: {fieldName}`)

	if dataType == "string" then
		local len = utf8.len(data :: string)
		assert(len, `Strings with invalid UTF-8 codepoints are not storable in Datastores. Field: {fieldName}`)
	end

	if dataType == "table" then
		assert(getmetatable(data :: any) == nil, `Metatables are not storable in DataStores. Field: {fieldName}`)

		local last
		for i, v in data :: {} do
			if not indexDataType then
				indexDataType = type(i)

				if not (indexDataType == "string" or indexDataType == "number") then
					error(`Table indexes must be strings or numbers to be storable. Field: {fieldName}`)
				end
			end

			if indexDataType and type(i) ~= indexDataType then
				error(`Tables must only have on type of index to be storable. Field: {fieldName}`)
			end

			if type(i) == "number" and last then
				if i - last ~= 1 then
					error(`Tables with number indexes must be sequential. Field: {fieldName}`)
				end

				last = i
			end

			if v == data then
				error(`Tables cannot be cyclic. Field: {fieldName}`)
			end

			SaveUtil.assertStorable(v, tostring(i))
		end
	end
end

function SaveUtil.getUpdateBudget()
	do
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end
end

function SaveUtil.getSetBudget()
	do
		return game:GetService("DataStoreService")
			:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
	end
end

function SaveUtil.getGetBudget()
	do
		return game:GetService("DataStoreService"):GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
	end
end


function SaveUtil.uuid(): string
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"


	local uuid = string.gsub(template, "[xy]", function(match)
		local v = if match == "x" then math.random(0, 0xf) else math.random(8, 0xb)

		return string.format("%x", v)
	end)

	return uuid
end


function SaveUtil.updateAsync<T>(
	transform: ((err: string) -> (), unknown, DataStoreKeyInfo) -> (any, { number }?, {}?),
	dataStore: DataStoreInterface,
	key: string
): (boolean, any, DataStoreKeyInfo)
	local result = Retry(RETRY.ATTEMPTS, RETRY.INITIAL_WAIT, function(): (any, DataStoreKeyInfo)

		local shouldAbort = false
		local abortError: string
		local function abortAttempt(err: string)
			shouldAbort = true
			abortError = err
		end


		assert(SaveUtil.getUpdateBudget() > 0, "Ran out of budget")

		local resultData, resultKeyInfo = dataStore:UpdateAsync(key, function(data: any, keyInfo: DataStoreKeyInfo)
			local transformResult = transform(abortAttempt, data, keyInfo)

			if shouldAbort then
				return data
			else
				return transformResult
			end
		end)

		if shouldAbort then
			error(abortError)
		end

		return resultData, resultKeyInfo
	end)

	return result.success, result.returnValues[1], result.returnValues[2]
end


function SaveUtil.getAsync<T>(dataStore: DataStoreInterface, key: string): (boolean, any, DataStoreKeyInfo)
	local result = Retry(RETRY.ATTEMPTS, RETRY.INITIAL_WAIT, function(): (any, DataStoreKeyInfo)
		local options
		do
			options = Instance.new("DataStoreGetOptions")
			options.UseCache = false
		end

		assert(SaveUtil.getGetBudget() > 0, "Ran out of budget")

		local resultData, resultKeyInfo = dataStore:GetAsync(key, options)

		return resultData, resultKeyInfo
	end)

	return result.success, result.returnValues[1], result.returnValues[2]
end


function SaveUtil.removeAsync<T>(dataStore: DataStoreInterface, key: string): boolean
	local result = Retry(RETRY.ATTEMPTS, RETRY.INITIAL_WAIT, function()
		assert(SaveUtil.getSetBudget() > 0, "Ran out of budget")

		return dataStore:RemoveAsync(key)
	end)

	return result.success
end

return SaveUtil
