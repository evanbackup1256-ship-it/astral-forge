--!strict
-- Pure PageRouter readiness / crew-snapshot helpers. No Roblox services —
-- Overview badges, Forge Path CTA readiness, and Crew roster equality can be
-- asserted under Lune without Studio. Partial quest/lab/forge bags must not throw.

local PageReadyMath = {}

function PageReadyMath.CountReadyQuests(quests: any): number
	local ready = 0
	if type(quests) ~= "table" then
		return 0
	end
	for _, quest in quests do
		if type(quest) == "table" and not quest.Claimed then
			local progress = tonumber(quest.Progress) or 0
			local target = tonumber(quest.Target) or 0
			if target > 0 and progress >= target then
				ready += 1
			end
		end
	end
	return ready
end

function PageReadyMath.CountReadyLabOrders(lab: any): number
	local ready = 0
	if type(lab) ~= "table" or type(lab.Orders) ~= "table" then
		return 0
	end
	for _, order in lab.Orders do
		if type(order) == "table" and not order.Claimed then
			local progress = tonumber(order.Progress) or 0
			local target = tonumber(order.Target) or 0
			if target > 0 and progress >= target then
				ready += 1
			end
		end
	end
	return ready
end

function PageReadyMath.ForgePathReady(state: any, config: any): boolean
	if type(state) ~= "table" then
		return false
	end
	local forgePath = state.ForgePath
	if type(forgePath) ~= "table" then
		return false
	end
	local steps = nil
	if type(config) == "table" and type(config.ForgePath) == "table" then
		steps = config.ForgePath.Steps
	end
	if type(steps) ~= "table" or #steps == 0 then
		return false
	end
	local claimed = {}
	local claimedSteps = forgePath.ClaimedSteps
	if type(claimedSteps) == "table" then
		for _, stepId in claimedSteps do
			claimed[stepId] = true
		end
	end
	local xp = tonumber(forgePath.XP) or 0
	for _, step in steps do
		if type(step) == "table" and claimed[step.Step] == nil then
			local unlocked = step.Step == 1 or claimed[step.Step - 1] ~= nil
			if unlocked then
				return xp >= (tonumber(step.XPCost) or 0)
			end
			return false
		end
	end
	return false
end

local CREW_KEYS = {
	"UserId",
	"Name",
	"DisplayName",
	"CurrentZone",
	"Rebirths",
	"Production",
	"LifetimeCash",
	"IsLocal",
	"CurrentPage",
}

function PageReadyMath.SameCrewSnapshot(left: any, right: any): boolean
	if type(left) ~= "table" or type(right) ~= "table" then
		return left == right
	end
	if #left ~= #right then
		return false
	end
	for index = 1, #left do
		local a = left[index]
		local b = right[index]
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		for _, key in CREW_KEYS do
			if a[key] ~= b[key] then
				return false
			end
		end
	end
	return true
end

-- Overview ops strip: anomaly pulse ready or any unclaimed met directive.
function PageReadyMath.AnomalyReady(anomaly: any): boolean
	if type(anomaly) ~= "table" then
		return false
	end
	if anomaly.Ready == true then
		return true
	end
	local directives = anomaly.Directives
	if type(directives) ~= "table" then
		return false
	end
	for _, directive in directives do
		if type(directive) == "table" and not directive.Claimed then
			local progress = tonumber(directive.Progress)
			local target = tonumber(directive.Target)
			if progress ~= nil and target ~= nil and progress >= target then
				return true
			end
		end
	end
	return false
end

-- Sum of ready mission/lab/path/anomaly claim badges on Overview ops rail.
function PageReadyMath.OpsClaims(missionsReady: any, labReady: any, pathReady: any, anomalyReady: any): number
	local total = math.max(0, math.floor(tonumber(missionsReady) or 0))
		+ math.max(0, math.floor(tonumber(labReady) or 0))
	if pathReady then
		total += 1
	end
	if anomalyReady then
		total += 1
	end
	return total
end

return table.freeze(PageReadyMath)
