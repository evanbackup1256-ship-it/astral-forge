--!nocheck
return function(Math)
	local Model = {}
	function Model.ratio(value, target)
		if not Math.Gt(target or 0, 0) then return 0 end
		return math.clamp(Math.ToNumber(Math.Div(value or 0, target)), 0, 1)
	end
	function Model.nextRank(state, config)
		local rank = state.Continuum or {}
		local rules = config.Continuum or {}
		local current = rank.Rank or 0
		local interval = math.max(1, rules.MilestoneEvery or 25)
		local nextRank = current + 1
		local milestone = nextRank % interval == 0
		local multiplier = if milestone then (rules.MilestoneScale or 1.5) else 1
		local capped = current >= (rules.MaxRank or math.huge)
		return {
			rank = current, nextRank = nextRank, capped = capped,
			ready = not capped and rank.CanUpgrade == true,
			flux = Math.Max(0, Math.Sub(rank.FluxCost or 0, state.Cash or 0)),
			dust = Math.Max(0, Math.Sub(rank.StardustCost or 0, state.Stardust or 0)),
			fluxProgress = Model.ratio(state.Cash, rank.FluxCost),
			dustProgress = Model.ratio(state.Stardust, rank.StardustCost),
			milestone = milestone, milestoneRank = (math.floor(current / interval) + 1) * interval,
			production = (rules.ProductionScale or 1.16) * multiplier,
			capacity = rules.CapacityScale or 1.1, tap = rules.TapScale or 1.14,
			offline = math.min(rules.OfflineCap or 0.45, (rank.OfflineBonus or 0) + (rules.OfflinePerRank or 0.0025)),
		}
	end
	function Model.toggleLoadout(anomaly, id)
		local result, present = {}, false
		local current = anomaly.Loadout or { anomaly.Channel or "Strike" }
		for _, entry in current do
			if entry == id then present = true else table.insert(result, entry) end
		end
		if present then
			if #result == 0 then return nil, "Keep at least one channel equipped." end
		else
			if #result >= math.max(1, anomaly.LoadoutSlots or 1) then return nil, "Unequip a channel to free a slot." end
			table.insert(result, id)
		end
		return result
	end
	function Model.protocol(anomaly, definition)
		local level = (anomaly.Protocols or {})[definition.Id] or 0
		local cost = Math.Max(1,Math.Floor(Math.Add(Math.Mul(definition.BaseCost, Math.Pow(definition.CostScale, level)),0.5)))
		local capped = level >= (definition.MaxLevel or math.huge)
		return { definition = definition, level = level, cost = cost, capped = capped,
			ready = not capped and Math.Gte(anomaly.Fragments or 0, cost) }
	end
	function Model.shift(state, config)
		local anomaly = state.Anomaly or {}
		local plan = { charge = Model.ratio(anomaly.Charge, anomaly.Target), jobs = {}, milestones = {}, protocols = {} }
		for _, job in anomaly.Directives or {} do
			if not job.Claimed then table.insert(plan.jobs, job) end
		end
		table.sort(plan.jobs, function(a, b)
			local ra, rb = Model.ratio(a.Progress, a.Target), Model.ratio(b.Progress, b.Target)
			return if ra == rb then a.Id < b.Id else ra > rb
		end)
		for _, milestone in anomaly.Milestones or {} do
			if not milestone.Claimed then table.insert(plan.milestones, milestone) end
		end
		for _, definition in (config.Anomalies or {}).Protocols or {} do
			table.insert(plan.protocols, Model.protocol(anomaly, definition))
		end
		table.sort(plan.protocols, function(a,b)
			if a.ready ~= b.ready then return a.ready end
			if Math.Compare(a.cost, b.cost) == 0 then return a.definition.Id < b.definition.Id end
			return Math.Lt(a.cost,b.cost)
		end)
		if anomaly.Ready then
			plan.title, plan.body, plan.action = "Bank your completed shift", "Charge is full. Collect your shift reward and start the next cycle.", "StabilizeAnomaly"
		elseif plan.jobs[1] and Model.ratio(plan.jobs[1].Progress, plan.jobs[1].Target) >= 1 then
			plan.title, plan.body, plan.action, plan.payload = "Collect a finished directive", plan.jobs[1].Name, "ClaimAnomalyDirective", {Id=plan.jobs[1].Id}
		elseif plan.milestones[1] and (anomaly.Stabilizations or 0) >= plan.milestones[1].Required then
			plan.title, plan.body, plan.action, plan.payload = "Collect your shift milestone", `Tier {plan.milestones[1].Tier} reward is ready.`, "ClaimAnomalyMilestone", {Tier=plan.milestones[1].Tier}
		else
			plan.title, plan.body, plan.action = "Build charge with a pulse", `Charge is {math.floor(plan.charge * 100)}%. Pulses and game actions advance the current shift.`, "PulseAnomaly"
		end
		return plan
	end
	return Model
end
