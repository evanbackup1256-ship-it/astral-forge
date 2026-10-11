--!nonstrict
local __defs = {}
local unresolved
__defs["SalvageView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.Parent.UiCore)("ui")
local Theme = require(script.Parent.Parent.CoreKit)("theme")
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Encounters = require(game.ReplicatedStorage.AstralForge.Shared.Encounters)
local ElementFx = require(script.Parent.Parent.ElementFx).ElementFx
local HttpService = game:GetService("HttpService")
local h, Palette = React.createElement, Theme.Palette

local function EncounterView(props)
	local mode = props.mode
	local data = props.state.Encounters
	local active = data and data.Active
	local owned = data and data.Owned or {}
	local artifact, setArtifact = React.useState("")
	local note, setNote = React.useState("")
	local forfeit, setForfeit = React.useState(nil)
	local busy, setBusy = React.useState(false)
	local pending = React.useRef(false)
	local live = React.useRef(true)
	local lastPreview = React.useRef(nil)
	local timeout = React.useRef(nil)
	local serial = React.useRef(0)
	local width, setWidth = React.useState(320)
	local ref = React.useRef(nil)
	React.useEffect(function()
		live.current = true
		local host = ref.current
		local connection
		if host then
			local function measure() if host.AbsoluteSize.X > 0 then setWidth(host.AbsoluteSize.X) end end
			measure()
			connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		end
		return function()
			live.current = false
			if timeout.current then task.cancel(timeout.current) end
			if connection then connection:Disconnect() end
		end
	end, {})
	local function request(action, payload)
		if pending.current then return end
		if unresolved then
			action, payload = unresolved.Action, unresolved.Payload
		else
			unresolved = { Action = action, Payload = payload }
		end
		pending.current = true
		setBusy(true)
		serial.current += 1
		local token = serial.current
		timeout.current = task.delay(20, function()
			if not live.current or serial.current ~= token then return end
			serial.current += 1
			timeout.current = nil
			pending.current = false
			setBusy(false)
			setNote("No response yet. Check the saved choice below before making another.")
		end)
		props.dispatch(action, payload, function(response)
			if response.Uncertain ~= true and unresolved and unresolved.Payload == payload then unresolved = nil end
			if not live.current or serial.current ~= token then return end
			if timeout.current then task.cancel(timeout.current); timeout.current = nil end
			pending.current = false
			setBusy(false)
			setForfeit(if response.ok == false and action == "ChooseEncounter" and response.error
				and response.error:find("Your stardust balance cannot hold", 1, true) then payload else nil)
			setNote(if response.Uncertain then "The connection interrupted. Check the same request below; it will not award twice."
				elseif response.ok then response.message or "Encounter saved." else response.error or "The encounter could not continue.")
		end)
	end
	local sections = {}
	local function add(key, height, element)
		table.insert(sections, { key = key, height = height, element = element })
	end
	local function text(value, height, color)
		return h(Ui.Text, { value = value, size = 15, wrap = true, color = color or Palette.creamSoft, sizeConstraint = UDim2.new(1, 0, 0, height) })
	end
	add("heading", 130, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.cyan },
		h(Ui.Text, { value = if mode == "Salvage" then "Salvage Runs" else "Artifact Trials", size = 26,
			weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, 0, 0, 40) }),
		h(Ui.Text, { value = if mode == "Salvage" then "Three choices. Bring a companion, recover useful cargo, and decide when the risk is worth it."
			else "Learn how your companions work. Meet their rules to earn mastery and new expressions.",
			size = 14, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 44), sizeConstraint = UDim2.new(1, 0, 0, 58) })))
	if note ~= "" then add("feedback", 100, text(note, 100)) end
	if unresolved then
		add("retry", 48, h(Ui.Button, { text = "Check saved request", color = Palette.cyan,
			size = UDim2.fromScale(1, 1), disabled = busy, reducedMotion = props.reducedMotion,
			onClick = function() request(unresolved.Action, unresolved.Payload) end }))
	end
	if forfeit then
		add("forfeit-reward", 60, h(Ui.Button, {
			text = "Complete this choice without stardust", color = Palette.mango,
			size = UDim2.fromScale(1, 1), disabled = busy, reducedMotion = props.reducedMotion,
			onClick = function()
				local payload = table.clone(forfeit)
				payload.ForfeitReward = true
				request("ChooseEncounter", payload)
			end,
		}))
	end
	if not data then
		add("loading", 100, text("Waiting for your encounter history and companions.", 100))
	elseif active then
		local scene = Encounters.Scene(active)
		local supplies, strain, objective = Encounters.Score(active)
		local trial = Encounters.Trials[active.Family]
		if active.Mode ~= mode then
			add("other-mode", 96, text("An unfinished " .. (if active.Mode == "Salvage" then "salvage run" else "artifact trial") .. " is ready below. Finish it before starting another.", 96, Palette.mango))
		end
		add("companion", 180, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.cyan },
			h(ElementFx, { element = active.Element, size = UDim2.fromOffset(110, 110),
				position = UDim2.fromOffset(55, 64), reducedMotion = props.reducedMotion,
				reaction = "reveal", reactionKey = active.Id }),
			h(Ui.Text, { value = if active.Element ~= "" then active.Element .. " companion" else "Solo salvage",
				size = 18, wrap = true, position = UDim2.fromOffset(120, 0), sizeConstraint = UDim2.new(1, -120, 0, 64) }),
			h(Ui.Text, { value = if active.Mode == "Trial" then trial.Rule
				else `{supplies} cargo / {strain} strain / {objective}/3 objective\nOver 3 strain forces an early extraction.`,
				size = 14, wrap = true, position = UDim2.fromOffset(120, 68), sizeConstraint = UDim2.new(1, -120, 0, 84), color = Palette.muted })))
		if active.Mode == "Trial" then add("trial-score", 64, text(`{supplies} power / {strain} strain / {objective} understanding`, 64, Palette.cyan)) end
		if scene then
			add("scene", 160, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.cyan },
				h(Ui.Text, { value = scene.Title, size = 20, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 64) }),
				h(Ui.Text, { value = scene.Text, size = 15, wrap = true, color = Palette.muted,
					position = UDim2.fromOffset(0, 68), sizeConstraint = UDim2.new(1, 0, 0, 62) })))
			for _, option in scene.Choices do
				add("choice-" .. option.Id, 156, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 12 },
					h(Ui.Text, { value = option.Detail, size = 14, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 62), color = Palette.muted }),
					h(Ui.Button, { text = option.Label, size = UDim2.new(1, 0, 0, 54), position = UDim2.fromOffset(0, 76),
						color = Palette.cyan, disabled = busy or unresolved ~= nil, reducedMotion = props.reducedMotion,
						onClick = function() request("ChooseEncounter", { RunId = active.Id, Step = active.Step, Choice = option.Id }) end })))
			end
		end
	else
		if mode == "Salvage" then
			add("allowance", 100, text(`{data.Remaining} of {data.DailyLimit} runs left today. Resets at midnight UTC. Starting uses one run; leaving the screen does not discard it.`, 100, Palette.muted))
		else
			add("mastery-policy", 110, text("Mastery milestones at 1, 3 and 7 award stardust once per companion. Other successes improve mastery without repeat payouts. Failed trials can be retried for free.", 110, Palette.muted))
		end
		local options = { { id = "", label = if mode == "Salvage" then "Go solo" else "Choose a companion" } }
		for _, item in owned do table.insert(options, { id = item.Id, label = item.Name }) end
		local columns = if width >= 620 then 3 elseif width >= 400 then 2 else 1
		add("loadout-label", 48, text("Your companion", 48))
		add("loadout", math.ceil(#options / columns) * 54 + (math.ceil(#options / columns) - 1) * 6,
			h(Ui.SegmentedTabs, { options = options, value = artifact, onChange = setArtifact,
				columns = columns, gap = 6, size = UDim2.fromScale(1, 1), reducedMotion = props.reducedMotion }))
		local selected
		for _, item in owned do if item.Id == artifact then selected = item end end
		if mode == "Salvage" then
			for _, site in Encounters.Sites do
				local locked = (props.state.Zone or 1) < site.Zone
				local advantage = selected and Encounters.Family(selected.Element) == site.Family
				add("site-" .. site.Id, 260, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.cyan },
					h(Ui.Text, { value = site.Name, size = 20, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 48) }),
					h(Ui.Text, { value = site.Description .. `\nZone {site.Zone}. {site.Family} companions protect against the first hazard.`
						.. (if advantage then "\nYour companion has the advantage." else "")
						.. `\nReward: {data.UnitReward} stardust per recovered cargo; +{data.UnitReward * 2} for the objective. Early extraction: {data.UnitReward}.`,
						size = 14, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 52), sizeConstraint = UDim2.new(1, 0, 0, 120) }),
					h(Ui.Button, { text = if locked then "Requires zone " .. site.Zone else "Start salvage run",
						size = UDim2.new(1, 0, 0, 54), position = UDim2.fromOffset(0, 182), color = Palette.cyan,
						disabled = busy or unresolved ~= nil or locked or data.Remaining <= 0, reducedMotion = props.reducedMotion,
						onClick = function() request("BeginEncounter", { Mode = "Salvage", Site = site.Id, Artifact = artifact, RequestId = HttpService:GenerateGUID(false) }) end })))
			end
		elseif selected then
			local trial = Encounters.Trials[Encounters.Family(selected.Element)]
			-- the same companion gaining mastery spins; picking another companion bounces
			local previous = lastPreview.current
			local reaction = if previous and previous.Id == selected.Id and selected.Mastery > previous.Mastery then "mastery" else "select"
			lastPreview.current = { Id = selected.Id, Mastery = selected.Mastery }
			add("trial-preview", 320, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.violet },
				h(ElementFx, { element = selected.Element, size = UDim2.fromOffset(100, 100), position = UDim2.fromOffset(50, 60), reducedMotion = props.reducedMotion,
					framerate = if selected.Mastery >= 7 then 16 elseif selected.Mastery >= 3 then 12 else 8,
					reaction = reaction, reactionKey = `{selected.Id}:{selected.Mastery}` }),
				h(Ui.Text, { value = trial.Name .. `\nMastery {selected.Mastery}/7`, size = 20, wrap = true,
					position = UDim2.fromOffset(118, 0), sizeConstraint = UDim2.new(1, -118, 0, 108) }),
				h(Ui.Text, { value = trial.Rule .. "\n" .. trial.Voice, size = 15, wrap = true, color = Palette.muted,
					position = UDim2.fromOffset(0, 126), sizeConstraint = UDim2.new(1, 0, 0, 108) }),
				h(Ui.Button, { text = "Start trial", size = UDim2.new(1, 0, 0, 54), position = UDim2.fromOffset(0, 240),
					color = Palette.violet, disabled = busy or unresolved ~= nil, reducedMotion = props.reducedMotion,
					onClick = function() request("BeginEncounter", { Mode = "Trial", Site = "", Artifact = artifact, RequestId = HttpService:GenerateGUID(false) }) end })))
		elseif #owned == 0 then
			add("no-companions", 96, text("Trials use artifacts from Command. Find your first companion on a Command expedition, then return here.", 96))
		end
	end
	if data then
		for index, receipt in data.History do
			if index > 3 or receipt.Run.Mode ~= mode then continue end
			add("outcome-" .. index, 180, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = if receipt.Passed then Palette.green else Palette.mango },
				h(Ui.Text, { value = "Last outcome", size = 18, sizeConstraint = UDim2.new(1, 0, 0, 32) }),
				h(Ui.Text, { value = receipt.Message, size = 14, wrap = true, position = UDim2.fromOffset(0, 40), sizeConstraint = UDim2.new(1, 0, 0, 110) })))
		end
	end
	return React.createElement(PageScaffold, { hostRef = ref, sections = sections, gap = 12, tailPad = 72, scrollBarColor = Palette.cyan })
end
return {
	SalvageView = function(props) return h(EncounterView, { mode = "Salvage", state = props.state, dispatch = props.dispatch, reducedMotion = props.reducedMotion }) end,
	TrialsView = function(props) return h(EncounterView, { mode = "Trial", state = props.state, dispatch = props.dispatch, reducedMotion = props.reducedMotion }) end,
}
end
__defs["TrialsView"] = __defs["SalvageView"]
return function(member)
	return assert(__defs[member], "Unknown encounter page: " .. tostring(member))()
end
