--!nocheck
return function(Math, compact)
	return function(state, ready)
		-- Keep the guided first run, then prioritize actionable progression.
		if (state.Rebirths or 0) < 1 and (not state.Level or (state.Level.Level or 1) < 5) then return nil end
		local function unlocked(page)
			local gate = state.FeatureUnlocks and state.FeatureUnlocks[page]
			return gate == nil or gate.Unlocked ~= false
		end
		for _, reward in { {"Missions", ready.missions, "mission rewards"}, {"Lab", ready.lab, "Lab rewards"}, {"ForgePath", if ready.path then 1 else 0, "Forge Path reward"}, {"Anomaly", if ready.anomaly then 1 else 0, "Anomaly reward"} } do
			if reward[2] > 0 and unlocked(reward[1]) then
				return { title = `Claim your {reward[3]}`, body = `{reward[2]} ready to collect. Bank these rewards before your next upgrade.`, page = reward[1], cta = "Open " .. (if reward[1] == "ForgePath" then "Forge Path" else reward[1]), value = tostring(reward[2]), label = "REWARDS READY", progress = 1 }
			end
		end
		if state.Domain and state.Domain.CanExpand then
			return { title = "Your next Domain is ready", body = "Review the reset and permanent bonuses before expanding your Domain.", page = "Domain", cta = "Review Domain", value = "READY", label = "DOMAIN EXPANSION", progress = 1 }
		end
		if Math.Gte(state.PrestigeReward or 0, 1) and unlocked("Rebirth") then
			return { title = "Rebirth rewards are ready", body = `Review the panel below to reset machines and collect {compact(state.PrestigeReward)} Cores. Research stays permanent.`, value = "+" .. compact(state.PrestigeReward), label = "CORES READY", progress = 1 }
		end
		local nextLevel = state.Level and state.Level.Next
		if type(nextLevel) == "table" and type(nextLevel.Text) == "string" then
			local progress = if Math.Gt(nextLevel.Target or 0, 0) then math.clamp(Math.ToNumber(Math.Div(nextLevel.Progress or 0, nextLevel.Target)), 0, 1) else 0
			local page = if nextLevel.Kind == "Domain" then "Domain" elseif nextLevel.Kind == "Rebirths" then nil else "Workshop"
			return { title = `Forge level {nextLevel.Level}`, body = `{nextLevel.Text} · {compact(nextLevel.Progress or 0)} / {compact(nextLevel.Target or 0)}`, page = page, cta = if page == "Domain" then "Review Domain" elseif page then "Build production" else nil, value = `{math.floor(progress * 100)}%`, label = "LEVEL PROGRESS", progress = progress }
		end
		return { title = "Build your next production jump", body = "Compare machine returns and buy a budgeted batch. Research stays with you across rebirths.", page = "Workshop", cta = "Compare machines", value = "NEXT", label = "PRODUCTION", progress = 0 }
	end
end
