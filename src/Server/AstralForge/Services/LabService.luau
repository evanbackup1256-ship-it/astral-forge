--!strict

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
	local LabOrderMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("LabOrderMath"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

	local LabService = {}

	local orderById = {}
	for _, order in GameConfig.Lab.Orders do
		orderById[order.Id] = order
	end

	local channelOrder = LabOrderMath.CHANNEL_ORDER

	local function utcDay(): number
		return math.floor(os.time() / 86_400)
	end

	local function ensureLab(profile)
		profile.Lab = LabOrderMath.Ensure(profile.Lab, GameConfig.Lab.Power.BaseCells)
		return profile.Lab
	end

	local function totalCells(profile): number
		return LabOrderMath.TotalCells(
			profile.Rebirths,
			GameConfig.Lab.Power.BaseCells,
			GameConfig.Lab.Power.RebirthsPerCell,
			GameConfig.Lab.Power.MaxCells
		)
	end

	local function normalizeRouting(profile): boolean
		local lab = ensureLab(profile)
		return LabOrderMath.NormalizeRouting(lab.Routing, channelOrder, totalCells(profile))
	end

	local function orderTarget(profile, order): number
		local bankFluxTarget = nil
		if order.Kind == "BankFlux" then
			-- Size bank targets from SteadyProduction so Flux Surge / ActiveBoost / Anomaly Surge
			-- cannot inflate lab targets mid-shift the way they must not inflate vault capacity.
			local steady = Economy.SteadyProduction(profile)
			bankFluxTarget = Economy.AsNumber(Economy.Mul(steady, order.ProductionSeconds))
		end
		return LabOrderMath.OrderTarget(order, math.max(0, profile.Rebirths), bankFluxTarget)
	end

	local function rollOrders(profile, day: number, userId: number)
		local available = table.create(#GameConfig.Lab.Orders)
		for index, definition in GameConfig.Lab.Orders do
			if definition.Kind ~= "UnlockWorld" or profile.Zone < GameConfig.MaxZone then
				table.insert(available, index)
			end
		end
		local seed = math.abs((day * 48_271 + userId * 69_621 + 17) % 2_147_483_647)
		local random = Random.new(seed)
		local rolled = {}
		for slot = 1, math.min(GameConfig.Lab.OrderCount, #available) do
			local pick = random:NextInteger(1, #available)
			local definition = GameConfig.Lab.Orders[available[pick]]
			table.remove(available, pick)
			rolled[slot] = {
				Id = definition.Id,
				Progress = 0,
				Target = orderTarget(profile, definition),
				Claimed = false,
			}
		end
		profile.Lab.Day = day
		profile.Lab.Orders = rolled
	end

	function LabService.Ensure(profile, userId: number): boolean
		local lab = ensureLab(profile)
		local changed = normalizeRouting(profile)
		local day = utcDay()
		if lab.Day ~= day then
			rollOrders(profile, day, userId)
			changed = true
		else
			local seen = {}
			local count = 0
			for index, state in lab.Orders do
				count += 1
				if
					type(index) ~= "number"
					or index ~= math.floor(index)
					or index < 1
					or index > GameConfig.Lab.OrderCount
					or type(state) ~= "table"
					or not orderById[state.Id]
					or seen[state.Id]
				then
					rollOrders(profile, day, userId)
					changed = true
					break
				end
				seen[state.Id] = true
			end
			if count ~= GameConfig.Lab.OrderCount then
				rollOrders(profile, day, userId)
				changed = true
			end
		end
		return changed
	end

	function LabService.Progress(profile, kind: string, amount: number): boolean
		local lab = ensureLab(profile)
		return LabOrderMath.ApplyProgress(lab.Orders, orderById, kind, amount)
	end

	function LabService.ClaimOrder(profile, orderId: string)
		local lab = ensureLab(profile)
		local orders = lab.Orders
		if type(orders) ~= "table" then
			return false, "That order is no longer on the board.", nil
		end
		local ok, message, reward = LabOrderMath.TryClaim(orders, orderById, orderId)
		if ok then
			-- Partial / mid-sanitize fixtures may lack Stats; don't throw on claim.
			if type(profile.Stats) ~= "table" then
				profile.Stats = { OrdersCompleted = 0 }
			end
			profile.Stats.OrdersCompleted =
				math.max(0, math.floor(tonumber(profile.Stats.OrdersCompleted) or 0)) + 1
		end
		return ok, message, reward
	end

	function LabService.RoutePower(profile, channelId: string, delta: number)
		if not GameConfig.Lab.Power.Channels[channelId] then
			return false, "That power rail does not exist."
		end
		if delta ~= -1 and delta ~= 1 then
			return false, "Move one cell at a time."
		end
		local lab = ensureLab(profile)
		normalizeRouting(profile)
		local total = totalCells(profile)
		local used = 0
		for _, id in channelOrder do
			used += lab.Routing[id]
		end
		local current = lab.Routing[channelId]
		if delta > 0 and used >= total then
			return false, "All cells are already assigned. Free one first."
		end
		if delta < 0 and current <= 0 then
			return false, "That rail is already empty."
		end
		lab.Routing[channelId] = current + delta
		-- Partial Stats bags (same class as ClaimOrder) must not crash power routing.
		if type(profile.Stats) ~= "table" then
			profile.Stats = { PowerMoves = 0 }
		end
		profile.Stats.PowerMoves = math.max(0, math.floor(tonumber(profile.Stats.PowerMoves) or 0)) + 1
		return true, delta > 0 and "Power cell assigned." or "Power cell returned."
	end

	function LabService.PowerEffect(profile, channelId: string): number
		local channel = GameConfig.Lab.Power.Channels[channelId]
		if not channel then
			return 0
		end
		local lab = ensureLab(profile)
		return math.max(0, lab.Routing[channelId] or 0) * channel.EffectPerCell
	end

	function LabService.State(profile)
		local lab = ensureLab(profile)
		local total = totalCells(profile)
		local used = 0
		local routing = {}
		local effects = {}
		for _, channelId in channelOrder do
			local raw = lab.Routing[channelId]
			local value = if type(raw) == "number" and raw == raw and raw ~= math.huge and raw ~= -math.huge
				then math.clamp(math.floor(raw), 0, math.max(0, total - used))
				else 0
			routing[channelId] = value
			local channel = GameConfig.Lab.Power.Channels[channelId]
			effects[channelId] = if channel then value * channel.EffectPerCell else 0
			used += value
		end
		local orders = table.create(#lab.Orders)
		for index, state in lab.Orders do
			orders[index] = {
				Id = state.Id,
				Progress = state.Progress,
				Target = state.Target,
				Claimed = state.Claimed,
			}
		end
		return {
			Day = lab.Day,
			ResetAt = (utcDay() + 1) * 86_400,
			Orders = orders,
			Routing = routing,
			Effects = effects,
			TotalCells = total,
			AvailableCells = math.max(0, total - used),
		}
	end

	return table.freeze(LabService)
end
