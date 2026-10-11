--!strict

return function(loadService: (string) -> any)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
	local Encounters = require(Shared:WaitForChild("Encounters"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local HttpService = game:GetService("HttpService")
	local Progression = loadService("ProgressionService")
	type Profile = {
		Zone: number, Stardust: number,
		Command: { Artifacts: { [string]: { Level: number, Fragments: number } } },
		Encounters: Encounters.State?,
	}
	local definitions = {}
	for _, artifact in GameConfig.Operations.Artifacts do definitions[artifact.Id] = artifact end
	local dailyLimit, unitReward = 3, 4
	task.defer(function()
		local ok, snapshot = pcall(function() return game:GetService("ConfigService"):GetConfigAsync() end)
		if not ok then ModuleLog.Warn("Encounters", "Live encounter balance unavailable; using documented defaults."); return end
		local function refresh()
			local limit, reward = snapshot:GetValue("SalvageDailyLimit"), snapshot:GetValue("EncounterStardustUnit")
			dailyLimit = if type(limit) == "number" and limit == limit then math.clamp(math.floor(limit), 1, 12) else 3
			unitReward = if type(reward) == "number" and reward == reward then math.clamp(math.floor(reward), 1, 100) else 4
		end
		refresh()
		snapshot.UpdateAvailable:Connect(function()
			local refreshed, message = pcall(function() snapshot:Refresh(); refresh() end)
			if not refreshed then ModuleLog.Warn("Encounters", "Live balance refresh failed: " .. tostring(message)) end
		end)
	end)
	local Service = {}
	function Service.Begin(profile: Profile, payload: any, now: number): (boolean, string)
		if not Encounters.ValidBegin(payload) then return false, "Choose a valid site and companion." end
		local state = Encounters.Sanitize(profile.Encounters)
		for _, receipt in state.History do
			if receipt.Run.RequestId == payload.RequestId then
				if receipt.Run.Mode ~= payload.Mode or receipt.Run.Site ~= payload.Site or receipt.Run.Artifact ~= payload.Artifact then
					return false, "That request already belongs to another encounter."
				end
				return true, receipt.Message
			end
		end
		if state.Active then
			local active = state.Active
			if active.RequestId == payload.RequestId and active.Mode == payload.Mode and active.Site == payload.Site and active.Artifact == payload.Artifact then
				return true, "Your encounter is ready to continue."
			end
			return false, "Finish your current encounter before starting another."
		end
		local artifact = definitions[payload.Artifact]
		local owned = profile.Command.Artifacts[payload.Artifact]
		if payload.Artifact ~= "" and (not artifact or not owned) then return false, "That companion is not in your collection." end
		if payload.Mode == "Trial" and not artifact then return false, "Choose an owned companion for its trial." end
		if payload.Mode == "Salvage" then
			local site = Encounters.Site(payload.Site)
			if not site then return false, "That salvage site is unavailable." end
			if profile.Zone < site.Zone then return false, "Reach zone " .. site.Zone .. " to explore this site." end
			local day = math.floor(now / 86400)
			if day > state.Day then state.Day = day; state.Used = 0 end
			if state.Used >= dailyLimit then return false, "Today's salvage runs are used. More are available at midnight UTC." end
			state.Used += 1
		elseif payload.Site ~= "" then return false, "Trials do not use a salvage site." end
		local element = if artifact then artifact.Element else ""
		state.Active = {
			Id = HttpService:GenerateGUID(false), RequestId = payload.RequestId, Mode = payload.Mode,
			Site = payload.Site, Artifact = payload.Artifact, Element = element, Family = Encounters.Family(element),
			Step = 1, Choices = {}, UnitReward = unitReward,
		}
		profile.Encounters = state
		return true, "Your encounter has started. Choices are saved as you make them."
	end
	function Service.Choose(profile: Profile, payload: any): (boolean, string)
		if not Encounters.ValidChoice(payload) then return false, "Choose one of the available approaches." end
		local state = Encounters.Sanitize(profile.Encounters)
		for _, receipt in state.History do
			if receipt.Run.Id == payload.RunId then
				if receipt.Run.Choices[payload.Step] ~= payload.Choice then return false, "That turn was already resolved with a different choice." end
				return true, receipt.Message
			end
		end
		local run = state.Active
		if not run or run.Id ~= payload.RunId then return false, "That encounter is no longer active. Refresh to see your current run." end
		if payload.Step < run.Step then
			return run.Choices[payload.Step] == payload.Choice, if run.Choices[payload.Step] == payload.Choice
				then "That choice is already saved." else "That turn was already resolved with a different choice."
		end
		if payload.Step ~= run.Step then return false, "Complete the current turn before moving ahead." end
		if payload.ForfeitReward == true and run.Step ~= 3 then return false, "Only the final choice can forfeit its reward." end
		local scene = Encounters.Scene(run)
		local valid = false
		if scene then for _, option in scene.Choices do if option.Id == payload.Choice then valid = true end end end
		if not valid then return false, "That approach is not available in this encounter." end
		table.insert(run.Choices, payload.Choice)
		run.Step += 1
		if run.Step <= 3 then profile.Encounters = state; return true, "Choice saved. The next encounter is ready." end
		local passed = Encounters.Passed(run)
		local cargo, strain, objective = Encounters.Score(run)
		local mastery = state.Mastery[run.Artifact] or 0
		local reward = 0
		local message
		if run.Mode == "Salvage" then
			reward = if passed then run.UnitReward * (cargo + (if objective >= 3 then 2 else 0)) else run.UnitReward
			message = if passed then `{cargo} cargo recovered with {strain} strain. `
				.. (if objective >= 3 then "Optional objective completed. " else "Optional objective not completed. ")
				else "The wreck became unsafe. You extracted early with a small recovery. "
		else
			if passed and mastery < 7 then
				mastery += 1
				state.Mastery[run.Artifact] = mastery
				if mastery == 1 or mastery == 3 or mastery == 7 then reward = run.UnitReward * mastery end
			end
			local expression = if mastery >= 7 then "Confident" elseif mastery >= 3 then "Attentive" elseif mastery >= 1 then "Curious" else "Unfamiliar"
			message = if passed then `Trial complete. Mastery {mastery}/7: {expression}. `
				else "Your companion needs a different approach. Review its rule and try again. "
		end
		if payload.ForfeitReward == true then
			reward = 0
			message ..= "You chose to finish without stardust. "
		elseif reward > 0 then
			-- Do not acknowledge a grant that cannot change the persisted balance.
			if profile.Stardust + reward == profile.Stardust or profile.Stardust + reward >= math.huge then
				return false, "Your stardust balance cannot hold this reward. You can finish this choice without stardust."
			end
			Progression.ApplyReward(profile, { Stardust = reward })
		end
		message ..= if reward > 0 then `{reward} stardust received.` else "No additional stardust reward."
		table.insert(state.History, 1, { Run = run, Message = message, Stardust = reward, Passed = passed, Mastery = mastery })
		while #state.History > 10 do table.remove(state.History) end
		state.Active = nil
		profile.Encounters = state
		return true, message
	end
	function Service.State(profile: Profile, now: number)
		local state = Encounters.Sanitize(profile.Encounters)
		local owned = {}
		for id in profile.Command.Artifacts do
			local definition = definitions[id]
			if definition then table.insert(owned, { Id = id, Name = definition.Name, Element = definition.Element, Mastery = state.Mastery[id] or 0 }) end
		end
		table.sort(owned, function(a, b) return a.Name < b.Name end)
		return {
			Active = state.Active, History = state.History, Owned = owned,
			Remaining = math.max(0, dailyLimit - (if math.floor(now / 86400) > state.Day then 0 else state.Used)),
			DailyLimit = dailyLimit, ResetAt = (math.floor(now / 86400) + 1) * 86400, UnitReward = unitReward,
		}
	end
	return table.freeze(Service)
end
