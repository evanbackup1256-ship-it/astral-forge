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

function LabOrderMath.IsReady(state: OrderState): boolean
	return not state.Claimed and state.Progress >= state.Target
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

-- Apply progress gain to matching unclaimed orders. Mutates orders in place.
function LabOrderMath.ApplyProgress(
	orders: { OrderState },
	orderById: { [string]: OrderDefinition },
	kind: string,
	amount: number
): boolean
	local gain = math.max(0, amount)
	if gain <= 0 then
		return false
	end
	local changed = false
	for _, state in orders do
		local definition = orderById[state.Id]
		if definition and definition.Kind == kind and not state.Claimed and state.Progress < state.Target then
			state.Progress = math.min(state.Target, state.Progress + gain)
			changed = true
		end
	end
	return changed
end

-- Mutates matching order Claimed=true on success. Does not touch Stats —
-- LabService bumps OrdersCompleted after a successful claim.
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
			if state.Progress < state.Target then
				return false, "That order is not finished yet.", nil
			end
			state.Claimed = true
			return true, "Order paid.", definition.Reward
		end
	end
	return false, "That order is no longer on the board.", nil
end

return table.freeze(LabOrderMath)
