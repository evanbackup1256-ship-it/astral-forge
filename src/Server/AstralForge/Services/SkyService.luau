--!strict
-- Star Charts and Signal Cipher. Both persist under profile.Sky.

return function(loadService: (string) -> any)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local SkyCharts = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SkyCharts"))
	local ProgressionService = loadService("ProgressionService")

	local SkyService = {}

	local function ensure(profile): any
		profile.Sky = SkyCharts.Ensure(profile.Sky)
		return profile.Sky
	end

	local function production(profile): any
		return Economy.SteadyProduction(profile)
	end

	function SkyService.PlotStar(profile, payload: any): (boolean, string, any?)
		local sky = ensure(profile)
		local index = SkyCharts.IndexOf(type(payload) == "table" and payload.Id or nil)
		if index == nil then
			return false, "Pick a constellation."
		end
		local entry = SkyCharts.CONSTELLATIONS[index]
		if not SkyCharts.IsOpen(sky, index) then
			return false, "Finish charting the previous constellation first."
		end
		local plotted = sky.Charts.Plotted[entry.Id] or 0
		if plotted >= #entry.Stars then
			return false, `{entry.Name} is already charted.`
		end
		local cost = SkyCharts.StarCost(index, plotted)
		local stardust = tonumber(profile.Stardust) or 0
		if stardust < cost then
			return false, `You need {cost - math.floor(stardust)} more Stardust.`
		end
		profile.Stardust = stardust - cost
		plotted += 1
		sky.Charts.Plotted[entry.Id] = plotted
		if plotted >= #entry.Stars then
			local message = ProgressionService.ApplyReward(profile, entry.Reward, production(profile))
			return true, `{entry.Name} charted! {message}`, { Id = entry.Id, Star = plotted, Completed = true }
		end
		return true, `Star {plotted} of {#entry.Stars} plotted.`, { Id = entry.Id, Star = plotted, Completed = false }
	end

	function SkyService.Guess(profile, payload: any, now: number, userId: number): (boolean, string, any?)
		local sky = ensure(profile)
		local day = SkyCharts.Day(now)
		SkyCharts.RollCipher(sky, day)
		local cipher = sky.Cipher
		if cipher.Solved then
			return false, "Today's signal is already decoded."
		end
		if cipher.Failed or #cipher.Guesses >= SkyCharts.CIPHER.MaxGuesses then
			return false, "Out of attempts. A new signal arrives tomorrow."
		end
		local guess = SkyCharts.Decode(type(payload) == "table" and payload.Code or nil)
		if guess == nil then
			return false, "Fill all four glyph slots."
		end
		local code = SkyCharts.CipherCode(day, userId)
		local exact, near = SkyCharts.Score(code, guess)
		table.insert(cipher.Guesses, { Code = SkyCharts.Encode(guess), Exact = exact, Near = near })
		local used = #cipher.Guesses
		if exact == SkyCharts.CIPHER.Length then
			cipher.Solved = true
			cipher.Solves = math.min(1e7, cipher.Solves + 1)
			cipher.Streak = if cipher.LastSolvedDay == day - 1 then cipher.Streak + 1 else 1
			cipher.LastSolvedDay = day
			cipher.Best = math.max(cipher.Best, cipher.Streak)
			local message = ProgressionService.ApplyReward(profile, SkyCharts.CipherReward(used, cipher.Streak), production(profile))
			return true, `Decoded in {used}! {message}`, { Exact = exact, Near = near, Solved = true }
		end
		if used >= SkyCharts.CIPHER.MaxGuesses then
			cipher.Failed = true
			cipher.Streak = 0
			return true, "The signal faded. Try again tomorrow.", { Exact = exact, Near = near, Failed = true }
		end
		return true, `{exact} locked, {near} drifting.`, { Exact = exact, Near = near }
	end

	function SkyService.State(profile, now: number, userId: number): any
		local sky = ensure(profile)
		local day = SkyCharts.Day(now)
		local cipher = sky.Cipher
		local current = cipher.Day == day
		local finished = current and (cipher.Solved or cipher.Failed)
		local streak = cipher.Streak
		if cipher.LastSolvedDay > 0 and cipher.LastSolvedDay < day - 1 then
			streak = 0
		end
		return {
			Plotted = table.clone(sky.Charts.Plotted),
			Completed = SkyCharts.Completed(sky),
			Cipher = {
				Guesses = if current then table.clone(cipher.Guesses) else {},
				Solved = current and cipher.Solved,
				Failed = current and cipher.Failed,
				Answer = if finished then SkyCharts.Encode(SkyCharts.CipherCode(day, userId)) else nil,
				Streak = streak,
				Best = cipher.Best,
				Solves = cipher.Solves,
				NextAt = (day + 1) * 86400,
			},
		}
	end

	return SkyService
end
