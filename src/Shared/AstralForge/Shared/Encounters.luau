--!strict

export type Choice = { Id: string, Label: string, Detail: string, Supplies: number, Risk: number, Objective: number }
export type Scene = { Title: string, Text: string, Choices: { Choice } }
export type Site = { Id: string, Name: string, Zone: number, Family: string, Description: string, Scenes: { Scene } }
export type Run = {
	Id: string, RequestId: string, Mode: string, Site: string, Artifact: string, Element: string,
	Family: string, Step: number, Choices: { string }, UnitReward: number,
}
export type Receipt = { Run: Run, Message: string, Stardust: number, Passed: boolean, Mastery: number }
export type State = {
	Day: number, Used: number, Active: Run?, History: { Receipt }, Mastery: { [string]: number },
}

local Encounters = {}
local function choice(id: string, label: string, detail: string, supplies: number, risk: number, objective: number): Choice
	return { Id = id, Label = label, Detail = detail, Supplies = supplies, Risk = risk, Objective = objective }
end

Encounters.Sites = {
	{ Id = "Freighter", Name = "Drifting freighter", Zone = 1, Family = "Current",
		Description = "Recover cargo from a quiet wreck. Optional objective: leave its distress beacon working.",
		Scenes = {
			{ Title = "A sealed cargo door", Text = "The manual latch is jammed. There is still power in the emergency bus.", Choices = {
				choice("Latch", "Work the manual latch", "1 cargo, no hull damage", 1, 0, 0),
				choice("Power", "Reroute the emergency bus", "2 cargo, 1 strain; Current companions remove the strain", 2, 1, 0),
				choice("Beacon", "Restore the distress beacon", "No cargo; advances the rescue objective", 0, 0, 2),
			} },
			{ Title = "Loose cargo", Text = "A leaking coolant pipe blocks the hold. A survivor's supply case floats nearby.", Choices = {
				choice("Hold", "Cross the leaking hold", "3 cargo, 2 strain", 3, 2, 0),
				choice("Case", "Secure the supply case", "1 cargo; advances the rescue objective", 1, 0, 1),
				choice("Patch", "Patch the pipe first", "1 cargo, removes 1 strain", 1, -1, 0),
			} },
			{ Title = "The wreck shifts", Text = "Your exit is open. One more rack remains bolted to the deck.", Choices = {
				choice("Leave", "Extract with your cargo", "No additional strain", 0, 0, 0),
				choice("Rack", "Release the last rack", "3 cargo, 2 strain", 3, 2, 0),
				choice("Rescue", "Mark a safe rescue route", "1 cargo; advances the rescue objective", 1, 0, 1),
			} },
		},
	},
	{ Id = "Foundry", Name = "Cold foundry", Zone = 3, Family = "Ember",
		Description = "Recover tooling from a shut-down furnace. Optional objective: preserve a usable casting mold.",
		Scenes = {
			{ Title = "Residual heat", Text = "The furnace is cold at its edges, but the central hoist is still glowing.", Choices = {
				choice("Cool", "Wait at the cooling channel", "1 cargo, no strain", 1, 0, 0),
				choice("Hoist", "Free the hot hoist", "3 cargo, 2 strain; Ember companions remove 1 strain", 3, 2, 0),
				choice("Mold", "Brace the casting mold", "No cargo; advances the preservation objective", 0, 0, 2),
			} },
			{ Title = "A fractured gantry", Text = "The best tooling hangs over a damaged walkway.", Choices = {
				choice("Walk", "Cross to the tooling rack", "3 cargo, 2 strain", 3, 2, 0),
				choice("Brace", "Reinforce the walkway", "1 cargo, removes 1 strain", 1, -1, 0),
				choice("Cradle", "Build a cradle for the mold", "1 cargo; advances the preservation objective", 1, 0, 1),
			} },
			{ Title = "Last lift", Text = "Your transport can take one final load.", Choices = {
				choice("Tools", "Take the loose tools", "2 cargo, 1 strain", 2, 1, 0),
				choice("Carry", "Carry the mold gently", "1 cargo; advances the preservation objective", 1, 0, 1),
				choice("Exit", "Leave through the service tunnel", "Removes 1 strain", 0, -1, 0),
			} },
		},
	},
	{ Id = "Observatory", Name = "Broken observatory", Zone = 6, Family = "Focus",
		Description = "Recover instruments above a fractured moon. Optional objective: save the observatory's survey archive.",
		Scenes = {
			{ Title = "An unstable lens", Text = "The telescope mount shudders each time its damaged motor turns.", Choices = {
				choice("Lens", "Disconnect the lens mount", "3 cargo, 2 strain; Focus companions remove 1 strain", 3, 2, 0),
				choice("Switch", "Isolate the motor", "1 cargo, no strain", 1, 0, 0),
				choice("Archive", "Copy the survey archive", "No cargo; advances the archive objective", 0, 0, 2),
			} },
			{ Title = "A cracked dome", Text = "An instrument case is wedged beneath a slowly opening seam.", Choices = {
				choice("Case", "Pull out the instrument case", "3 cargo, 2 strain", 3, 2, 0),
				choice("Seal", "Seal the seam", "1 cargo, removes 1 strain", 1, -1, 0),
				choice("Index", "Recover the archive index", "1 cargo; advances the archive objective", 1, 0, 1),
			} },
			{ Title = "The return shuttle", Text = "The uplink has enough charge for one last transmission.", Choices = {
				choice("Transmit", "Transmit the recovered archive", "1 cargo; advances the archive objective", 1, 0, 1),
				choice("Dish", "Strip the uplink hardware", "3 cargo, 2 strain", 3, 2, 0),
				choice("Return", "Return along the marked route", "No additional strain", 0, 0, 0),
			} },
		},
	},
	{ Id = "OvergrowthStation", Name = "Overgrowth station", Zone = 8, Family = "Growth",
		Description = "Harvest rare flora from an abandoned biosphere. Optional objective: secure the seed vault.",
		Scenes = {
			{ Title = "Tangled airlock", Text = "Dense alien vines entangle the outer hatch. A germination console flickers nearby.", Choices = {
				choice("Clear", "Prune the outer vines", "1 cargo, no strain", 1, 0, 0),
				choice("Force", "Force the overgrown hatch", "3 cargo, 2 strain; Growth companions remove 1 strain", 3, 2, 0),
				choice("Console", "Access the seed vault console", "No cargo; advances the seed vault objective", 0, 0, 2),
			} },
			{ Title = "Spore bloom", Text = "A burst spore pod releases caustic mist across the central corridor.", Choices = {
				choice("Canopy", "Harvest the upper canopy", "3 cargo, 2 strain", 3, 2, 0),
				choice("Filter", "Activate environmental filters", "1 cargo, removes 1 strain", 1, -1, 0),
				choice("Vault", "Protect the cryogenic seed bank", "1 cargo; advances the seed vault objective", 1, 0, 1),
			} },
			{ Title = "Canopy collapse", Text = "The glass biosphere shudders under the weight of root growth.", Choices = {
				choice("Specimen", "Retrieve root specimens", "3 cargo, 2 strain", 3, 2, 0),
				choice("Seal", "Seal the cryogenic vault", "1 cargo; advances the seed vault objective", 1, 0, 1),
				choice("Depart", "Evacuate through service shaft", "No additional strain", 0, 0, 0),
			} },
		},
	},
	{ Id = "BastionVault", Name = "Bastion vault", Zone = 10, Family = "Shelter",
		Description = "Salvage heavy alloy plating from a ruined military bunker. Optional objective: reinforce the bulkhead seal.",
		Scenes = {
			{ Title = "Reinforced blast gate", Text = "Heavy armored blast doors have buckled against structural support beams.", Choices = {
				choice("Bypass", "Bypass the secondary latch", "1 cargo, no strain", 1, 0, 0),
				choice("Breach", "Breach the armored plating", "3 cargo, 2 strain; Shelter companions remove 1 strain", 3, 2, 0),
				choice("Brace", "Brace the primary bulkhead seal", "No cargo; advances the bulkhead seal objective", 0, 0, 2),
			} },
			{ Title = "Collapsing armor bay", Text = "Falling armor slabs threaten the inner magazine and primary structural struts.", Choices = {
				choice("Ingots", "Extract dense armor ingots", "3 cargo, 2 strain", 3, 2, 0),
				choice("Strut", "Reinforce support struts", "1 cargo, removes 1 strain", 1, -1, 0),
				choice("Weld", "Weld the emergency bulkhead", "1 cargo; advances the bulkhead seal objective", 1, 0, 1),
			} },
			{ Title = "Final breach", Text = "Tremors shake the bunker foundation as the outer perimeter gives way.", Choices = {
				choice("Plating", "Strip the command plating", "3 cargo, 2 strain", 3, 2, 0),
				choice("Lockdown", "Engage magnetic bulkhead lockdown", "1 cargo; advances the bulkhead seal objective", 1, 0, 1),
				choice("Withdraw", "Withdraw along fortified ramp", "Removes 1 strain", 0, -1, 0),
			} },
		},
	},
	{ Id = "EclipseRift", Name = "Eclipse rift", Zone = 12, Family = "Shadow",
		Description = "Probe a derelict platform suspended in a dark matter fissure. Optional objective: stabilize the null core.",
		Scenes = {
			{ Title = "Event horizon platform", Text = "Gravitational shear tears at the docking ring. Null-phase containment is fluctuating.", Choices = {
				choice("Probe", "Deploy a sensor probe", "1 cargo, no strain", 1, 0, 0),
				choice("Siphon", "Siphon dark matter canisters", "3 cargo, 2 strain; Shadow companions remove 1 strain", 3, 2, 0),
				choice("Harmonize", "Harmonize the null core", "No cargo; advances the null core objective", 0, 0, 2),
			} },
			{ Title = "Spatial distortion", Text = "Geometry folds inward as shadowy anomalies ripple through the science laboratory.", Choices = {
				choice("Matter", "Capture exotic dark matter", "3 cargo, 2 strain", 3, 2, 0),
				choice("Dampen", "Dampen gravimetric resonance", "1 cargo, removes 1 strain", 1, -1, 0),
				choice("Contain", "Contain the null core fluctuation", "1 cargo; advances the null core objective", 1, 0, 1),
			} },
			{ Title = "Singularity collapse", Text = "The rift boundary begins closing. The escape corridor is decaying rapidly.", Choices = {
				choice("Relic", "Pluck the singularity artifact", "3 cargo, 2 strain", 3, 2, 0),
				choice("Anchor", "Anchor the stabilized null core", "1 cargo; advances the null core objective", 1, 0, 1),
				choice("Escape", "Escape before horizon collapse", "No additional strain", 0, 0, 0),
			} },
		},
	},
} :: { Site }

local familyOf: { [string]: string } = {}
local families = {
	Ember = { "Solar", "Plasma", "Magma", "Smoke", "Gold", "Radiance", "Starlight" },
	Current = { "Wind", "Lightning", "Sonic", "Tempest", "Magnet", "Neon", "Comet", "Feather", "Aurora" },
	Growth = { "Spore", "Bloom", "Thorn", "Vital", "Necrotic", "Amber" },
	Shelter = { "Crystal", "Steel", "Prism", "Mirror", "Lunar", "Ice", "Frost", "Earth", "Stone" },
	Shadow = { "Void", "Abyss", "Eclipse", "Ink", "Rift", "Glitch" },
}
for family, elements in families do
	for _, element in elements do familyOf[element] = family end
end
function Encounters.Family(element: string): string
	return familyOf[element] or "Focus"
end

local trialChoice = {
	choice("Release", "Release the stored power", "Strong output; keep control before committing", 2, 2, 0),
	choice("Steady", "Steady your companion", "Less output; removes strain", 1, -1, 0),
	choice("Observe", "Read the next movement", "No output; builds understanding", 0, 0, 2),
}
Encounters.Trials = {
	Ember = { Name = "Keep the flame", Rule = "Build at least 4 power without exceeding 3 strain.", Voice = "A strong flame still needs a steady hand." },
	Current = { Name = "Read the current", Rule = "Observe before releasing power, then finish with at least 3 power.", Voice = "Watch where the current is going, not where it was." },
	Growth = { Name = "Room to grow", Rule = "Build at least 3 understanding and finish with no strain.", Voice = "Leave room for the next shoot." },
	Shelter = { Name = "Hold the line", Rule = "Build at least 3 power and finish with no more than 1 strain.", Voice = "The shield holds when we hold together." },
	Shadow = { Name = "Move unseen", Rule = "Observe at least twice. Never release power on consecutive turns.", Voice = "One opening is enough. Wait for it." },
	Focus = { Name = "A clear signal", Rule = "Use each approach once and finish with at least 3 power.", Voice = "See the whole pattern before choosing a part." },
}
function Encounters.Site(id: string): Site?
	for _, site in Encounters.Sites do if site.Id == id then return site end end
	return nil
end
function Encounters.Scene(run: Run): Scene?
	if run.Mode == "Salvage" then
		local site = Encounters.Site(run.Site)
		return if site then site.Scenes[run.Step] else nil
	end
	if run.Step > 3 then return nil end
	local trial = Encounters.Trials[run.Family]
	if not trial then return nil end
	return { Title = trial.Name .. " / " .. run.Step .. " of 3", Text = trial.Voice, Choices = trialChoice }
end
function Encounters.Score(run: Run): (number, number, number)
	local supplies, risk, objective = 0, 0, 0
	local probe = table.clone(run)
	for step, id in run.Choices do
		probe.Step = step
		local scene = Encounters.Scene(probe)
		if scene then
			for _, option in scene.Choices do
				if option.Id == id then
					supplies += option.Supplies
					local protection = 0
					local site = Encounters.Site(run.Site)
					if run.Mode == "Salvage" and step == 1 and site and run.Family == site.Family and option.Risk > 0 then protection = 1 end
					risk = math.max(0, risk + option.Risk - protection)
					objective += option.Objective
					break
				end
			end
		end
	end
	return supplies, risk, objective
end
function Encounters.Passed(run: Run): boolean
	local power, strain, understanding = Encounters.Score(run)
	if run.Mode == "Salvage" then return strain <= 3 end
	local choices = run.Choices
	if run.Family == "Ember" then return power >= 4 and strain <= 3
	elseif run.Family == "Current" then
		local observed = false
		for _, id in choices do
			if id == "Observe" then observed = true end
			if id == "Release" and not observed then return false end
		end
		return power >= 3
	elseif run.Family == "Growth" then return understanding >= 3 and strain == 0
	elseif run.Family == "Shelter" then return power >= 3 and strain <= 1
	elseif run.Family == "Shadow" then
		for index = 2, #choices do if choices[index] == "Release" and choices[index - 1] == "Release" then return false end end
		return understanding >= 4
	end
	return power >= 3 and table.find(choices, "Observe") ~= nil and table.find(choices, "Steady") ~= nil and table.find(choices, "Release") ~= nil
end

local function integer(value: any, minimum: number, maximum: number): number
	return if type(value) == "number" and value == value and value > -math.huge and value < math.huge
		then math.clamp(math.floor(value), minimum, maximum) else minimum
end
local function bounded(value: any, minimum: number, maximum: number): boolean
	return type(value) == "string" and #value >= minimum and #value <= maximum
end
function Encounters.ValidBegin(payload: any): boolean
	return type(payload) == "table" and (payload.Mode == "Salvage" or payload.Mode == "Trial")
		and bounded(payload.Site, 0, 24) and bounded(payload.Artifact, 0, 64) and bounded(payload.RequestId, 8, 64)
end
function Encounters.ValidChoice(payload: any): boolean
	return type(payload) == "table" and bounded(payload.RunId, 8, 64) and bounded(payload.Choice, 1, 24)
		and type(payload.Step) == "number" and payload.Step >= 1 and payload.Step <= 3 and payload.Step % 1 == 0
		and (payload.ForfeitReward == nil or type(payload.ForfeitReward) == "boolean")
end
local function cleanRun(raw: any, completed: boolean): Run?
	if type(raw) ~= "table" or not Encounters.ValidBegin(raw) or not bounded(raw.Id, 8, 64)
		or not bounded(raw.Element, 0, 32) or not Encounters.Trials[raw.Family] then return nil end
	if raw.Mode == "Salvage" and not Encounters.Site(raw.Site) then return nil end
	local run: Run = {
		Id = raw.Id, RequestId = raw.RequestId, Mode = raw.Mode, Site = raw.Site, Artifact = raw.Artifact,
		Element = raw.Element, Family = raw.Family, Step = 1, Choices = {}, UnitReward = integer(raw.UnitReward, 1, 100),
	}
	for index = 1, if completed then 3 else 2 do
		local id = if type(raw.Choices) == "table" then raw.Choices[index] else nil
		if id == nil then break end
		run.Step = index
		local scene = Encounters.Scene(run)
		local valid = false
		if scene then for _, option in scene.Choices do if option.Id == id then valid = true end end end
		if not valid then return nil end
		table.insert(run.Choices, id)
	end
	run.Step = #run.Choices + 1
	if completed and run.Step ~= 4 then return nil end
	return run
end
function Encounters.Sanitize(raw: any): State
	local source = if type(raw) == "table" then raw else {}
	local state: State = {
		Day = integer(source.Day, -1, 1e9), Used = integer(source.Used, 0, 12),
		Active = cleanRun(source.Active, false), History = {}, Mastery = {},
	}
	if type(source.History) == "table" then
		for index = 1, math.min(10, #source.History) do
			local rawReceipt = source.History[index]
			if type(rawReceipt) ~= "table" then continue end
			local run = cleanRun(rawReceipt.Run, true)
			if run and bounded(rawReceipt.Message, 1, 512) then
				table.insert(state.History, { Run = run, Message = rawReceipt.Message,
					Stardust = integer(rawReceipt.Stardust, 0, 2000), Passed = rawReceipt.Passed == true, Mastery = integer(rawReceipt.Mastery, 0, 7) })
			end
		end
	end
	if type(source.Mastery) == "table" then
		for id, value in source.Mastery do if bounded(id, 1, 64) then state.Mastery[id] = integer(value, 0, 7) end end
	end
	return state
end

return table.freeze(Encounters)
