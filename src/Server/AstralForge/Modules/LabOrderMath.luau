--!strict
-- Pure lab-order progress / claim / target / cell math. No Roblox services —
-- LabService and Lune verify scripts share this so order readiness and claim
-- gates can be tested without Studio. Reward application stays with the caller.

local LabOrderMath = {}

export type OrderDefinition = {
	Id: string,
	Kind: string,
	BaseTarget: number,
	PerRebirth: number?,
	ProductionSeconds: number?,
	Reward: any?,
}

export type OrderState = {
	Id: string,
	Progress: number,
	Target: number,
	Claimed: boolean,
}

export type LabBag = {
	Day: number,
	Orders: { OrderState },
	Routing: { [string]: number },
}

LabOrderMath.CHANNEL_ORDER = { "Production", "Storage", "Tap" }

-- Studio fixtures / mid-migrate bags may omit Lab entirely, or leave Orders /
-- Routing nil — LabService.Ensure / DataService sanitize must rebuild first.
function LabOrderMath.Ensure(lab: any, baseCells: number?): LabBag
	local cells = math.max(3, math.floor(tonumber(baseCells) or 12))
	local per = math.max(1, math.floor(cells / 3))
	if type(lab) ~= "table" then
		return {
			Day = -1,
			Orders = {},
			Routing = { Production = per, Storage = per, Tap = per },
		}
	end
	if type(lab.Orders) ~= "table" then
		lab.Orders = {}
	end
	if type(lab.Routing) ~= "table" then
		lab.Routing = { Production = per, Storage = per, Tap = per }
	end
	lab.Day = if type(lab.Day) == "number" then lab.Day else -1
	return lab :: LabBag
end

-- Clamp routing to the power-cell budget; returns whether any channel changed.
function LabOrderMath.NormalizeRouting(
	routing: { [string]: number },
	channelOrder: { string },
	totalCells: number
): boolean
	local changed = false
	local total = math.max(0, math.floor(tonumber(totalCells) or 0))
	local used = 0
	for _, channelId in channelOrder do
		local value = routing[channelId]
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			value = 0
		end
		local clean = math.clamp(math.floor(value), 0, total)
		if routing[channelId] ~= clean then
			routing[channelId] = clean
			changed = true
		end
		used += clean
	end
	if used > total then
		local overflow = used - total
		for index = #channelOrder, 1, -1 do
			local channelId = channelOrder[index]
			local current = routing[channelId] or 0
			local removed = math.min(current, overflow)
			if removed > 0 then
				routing[channelId] = current - removed
				overflow -= removed
				changed = true
			end
			if overflow <= 0 then
				break
			end
		end
	end
	return changed
end

-- Power-cell budget from rebirths. Mirrors LabService.totalCells / DataService.
function LabOrderMath.TotalCells(
	rebirths: number,
	baseCells: number,
	rebirthsPerCell: number,
	maxCells: number
): number
	local safeRebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	local per = math.max(1, math.floor(tonumber(rebirthsPerCell) or 1))
	return math.clamp(
		baseCells + math.floor(safeRebirths / per),
		baseCells,
		maxCells
	)
end

-- BankFlux callers pass bankFluxTarget = floor(AsNumber(Mul(steady, ProductionSeconds))).
-- Non-BankFlux ignores bankFluxTarget and uses BaseTarget + rebirths * PerRebirth.
function LabOrderMath.OrderTarget(order: OrderDefinition, rebirths: number, bankFluxTarget: number?): number
	if order.Kind == "BankFlux" then
		return math.max(order.BaseTarget, math.floor(tonumber(bankFluxTarget) or 0))
	end
	local per = tonumber(order.PerRebirth) or 0
	return math.max(1, math.floor(order.BaseTarget + math.max(0, rebirths) * per))
end

-- Studio fixtures / mid-migrate bags may store Progress/Target as numeric strings.
-- Bare `progress + gain` concatenates; `"9" < "10"` is false and `"9" >= "10"` is
-- true lexicographically — incomplete orders looked ready and skipped ApplyProgress.
local function progressPair(state: any): (number, number)
	local progress = math.max(0, math.floor(tonumber(state and state.Progress) or 0))
	local target = math.max(0, math.floor(tonumber(state and state.Target) or 0))
	return progress, target
end

function LabOrderMath.IsReady(state: OrderState): boolean
	if type(state) ~= "table" or state.Claimed == true then
		return false
	end
	local progress, target = progressPair(state)
	return progress >= target and target > 0
end

function LabOrderMath.CountReady(orders: { OrderState }): number
	local ready = 0
	for _, state in orders do
		if LabOrderMath.IsReady(state) then
			ready += 1
		end
	end
	return ready
end

function LabOrderMath.ApplyProgress(
	orders: { OrderState },
	orderById: { [string]: OrderDefinition },
	kind: string,
	amount: number
): boolean
	local gain = math.max(0, math.floor(tonumber(amount) or 0))
	if gain <= 0 then
		return false
	end
	local changed = false
	for _, state in orders do
		local definition = orderById[state.Id]
		if definition and definition.Kind == kind and not state.Claimed then
			local progress, target = progressPair(state)
			if progress < target then
				state.Progress = math.min(target, progress + gain)
				changed = true
			end
		end
	end
	return changed
end

function LabOrderMath.TryClaim(
	orders: { OrderState },
	orderById: { [string]: OrderDefinition },
	orderId: string
): (boolean, string, any?)
	local definition = orderById[orderId]
	if not definition then
		return false, "That order is no longer on the board.", nil
	end
	for _, state in orders do
		if state.Id == orderId then
			if state.Claimed then
				return false, "That order has already been paid.", nil
			end
			local progress, target = progressPair(state)
			if progress < target then
				return false, "That order is not finished yet.", nil
			end
			state.Claimed = true
			state.Progress = progress
			state.Target = math.max(1, target)
			return true, "Order paid.", definition.Reward
		end
	end
	return false, "That order is no longer on the board.", nil
end

return table.freeze(LabOrderMath)
