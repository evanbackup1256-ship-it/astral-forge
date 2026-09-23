--!strict
-- Pure offline earnings segment projection. No Roblox services — Economy and
-- Lune verify scripts share this so elapsed/cap/boundary math can be tested
-- without Studio. Production/efficiency sampling stays injected by the caller.

local OfflineProjection = {}

export type SampleResult = {
	Production: any,
	Efficiency: number,
}

-- sampleAt(midpointSeconds) -> SampleResult
-- add(left, right) / mul(left, right) match Economy.Add / Economy.Mul
-- persist(value) matches Economy bounded Persist (optional; identity if nil)
function OfflineProjection.Project(
	startedAt: number,
	endedAt: number,
	maxSeconds: number,
	minElapsed: number,
	cycleSeconds: number,
	boostEnd: number,
	surgeEnd: number,
	sampleAt: (number) -> SampleResult,
	add: (any, any) -> any,
	mul: (any, any) -> any,
	persist: ((any) -> any)?
): (any, number, number, boolean)
	local rawElapsed = math.max(0, endedAt - startedAt)
	local maximum = math.max(0, maxSeconds)
	local elapsed = math.min(rawElapsed, maximum)
	local capped = rawElapsed > maximum
	if elapsed < minElapsed then
		return 0, elapsed, 0, capped
	end

	local from = startedAt
	local to = startedAt + elapsed
	local boundaries = { from, to }
	local cycle = math.max(1, cycleSeconds)
	local nextCycle = (math.floor(from / cycle) + 1) * cycle
	while nextCycle < to do
		table.insert(boundaries, nextCycle)
		nextCycle += cycle
	end
	if boostEnd > from and boostEnd < to then
		table.insert(boundaries, boostEnd)
	end
	if surgeEnd > from and surgeEnd < to then
		table.insert(boundaries, surgeEnd)
	end
	table.sort(boundaries)

	local reward: any = 0
	local weightedEfficiency = 0
	for index = 1, #boundaries - 1 do
		local left = boundaries[index]
		local right = boundaries[index + 1]
		local duration = right - left
		if duration > 0 then
			local sample = left + duration * 0.5
			local result = sampleAt(sample)
			local efficiency = result.Efficiency
			reward = add(reward, mul(result.Production, efficiency * duration))
			weightedEfficiency += efficiency * duration
		end
	end
	if persist then
		reward = persist(reward)
	end
	return reward, elapsed, weightedEfficiency / elapsed, capped
end

-- Client Offline rail bag (wave48). Runtime fields optional when session cold.
function OfflineProjection.PublicSnapshot(args: {
	runtime: any?,
	production: any,
	vault: any,
	offlineHours: number,
}): any
	local runtime = args.runtime
	if runtime then
		return {
			Reward = runtime.OfflineReward,
			Seconds = runtime.OfflineSeconds,
			Efficiency = runtime.OfflineEfficiency,
			Capped = runtime.OfflineCapped,
			Production = args.production,
			AwaySeconds = runtime.OfflineAwaySeconds or runtime.OfflineSeconds,
			CapHours = runtime.OfflineCapHours or args.offlineHours,
			Vault = args.vault,
		}
	end
	return {
		Reward = 0,
		Seconds = 0,
		Efficiency = 0,
		Capped = false,
		Production = args.production,
		AwaySeconds = 0,
		CapHours = args.offlineHours,
		Vault = args.vault,
	}
end

return table.freeze(OfflineProjection)
