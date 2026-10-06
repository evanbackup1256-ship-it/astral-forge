--!strict



local function Retry<T...>(
	maxAttempts: number,
	initialWait: number,
	func: (T...) -> any,
	...: T...
): { success: boolean, returnValues: { any } }
	local result: { any }

	for i = 1, maxAttempts do
		result = { pcall(func, ...) }

		if result[1] == true then
			break
		end

		warn(`[DocumentService Retry] Attempt {i} failed: {result[2]} {debug.traceback("\nat", 1)}`)

		if i < maxAttempts then
			task.wait(initialWait * (2 ^ (i - 1)))
		end
	end

	local success = result[1]
	table.remove(result, 1)

	return {
		success = success,
		returnValues = result,
	}
end

return Retry
