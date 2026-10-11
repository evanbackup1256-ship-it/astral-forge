--!strict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.Parent.UiCore)("ui")
local Palette = require(script.Parent.Parent.CoreKit)("theme").Palette
local Format = require(script.Parent.Parent.CoreKit)("format")
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Specializations = require(game.ReplicatedStorage.AstralForge.Shared.Specializations)
type Response = { ok: boolean, Uncertain: boolean?, message: string?, error: string? }
type Props = {
	state: { Specialization: Specializations.Snapshot? },
	reducedMotion: boolean?,
	dispatch: (string, { Id: string }, (Response) -> ()) -> (),
}
local h = React.createElement
local unresolved: { Id: string }? = nil
local function SpecializationsView(props: Props)
	local state = props.state.Specialization
	local note, setNote = React.useState("")
	local busy, setBusy = React.useState(false)
	local pending = React.useRef(false)
	local live = React.useRef(true)
	local timeout = React.useRef(nil)
	local serial = React.useRef(0)
	React.useEffect(function()
		live.current = true
		return function() live.current = false; if timeout.current then task.cancel(timeout.current) end end
	end, {})
	local sections = {}
	local function add(key, height, element) table.insert(sections, { key = key, height = height, element = element }) end
	local function selectBuild(id: string)
		if pending.current then return end
		local order = unresolved or { Id = id }
		unresolved = order
		pending.current = true
		serial.current += 1
		local token = serial.current
		setBusy(true)
		timeout.current = task.delay(20, function()
			if serial.current ~= token then return end
			serial.current += 1
			timeout.current = nil
			pending.current = false
			if live.current then setBusy(false); setNote("No response yet. Retry to confirm the previous build change.") end
		end)
		props.dispatch("SelectSpecialization", order, function(response)
			if not response.Uncertain and unresolved == order then unresolved = nil end
			if serial.current ~= token then return end
			if timeout.current then task.cancel(timeout.current); timeout.current = nil end
			pending.current = false
			if not live.current then return end
			setBusy(false)
			setNote(if response.Uncertain then "The change has not been confirmed. Retry before choosing another build."
				elseif response.ok then response.message or "Build equipped." else response.error or "The build could not be changed.")
		end)
	end
	add("heading", 156, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.mango },
		h(Ui.Text, { value = "Forge Specializations", size = 26, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 68) }),
		h(Ui.Text, { value = "Set up your forge for hands-on work, larger collections, or time away. Research, Domain, and Forge Path bonuses still apply.",
			size = 14, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 72), sizeConstraint = UDim2.new(1, 0, 0, 58) })))
	if unresolved then
		add("retry", 66, h(Ui.Button, { text = "Confirm previous build change", size = UDim2.fromScale(1, 1),
			color = Palette.mango, disabled = busy, reducedMotion = props.reducedMotion,
			onClick = function() selectBuild(unresolved.Id) end }))
	end
	if note ~= "" then
		add("response", 96, h(Ui.Text, { value = note, size = 15, wrap = true, sizeConstraint = UDim2.fromScale(1, 1) }))
	end
	if not state then
		add("loading", 100, h(Ui.Text, { value = "Waiting for your current build.", size = 15, wrap = true, sizeConstraint = UDim2.fromScale(1, 1) }))
	else
		add("current", 184, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.mango },
			h(Ui.Text, { value = "Current build: " .. state.Name, size = 20, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 56) }),
			h(Ui.Text, { value = "Production " .. Format.compactNumber(state.Production) .. "/s before server events\nVault " .. Format.compactNumber(state.Capacity)
				.. "\nOvercharge " .. Format.compactNumber(state.Tap) .. " / Offline efficiency " .. math.floor(state.Offline * 100) .. "%",
				size = 14, wrap = true, position = UDim2.fromOffset(0, 60), sizeConstraint = UDim2.new(1, 0, 0, 98), color = Palette.muted })))
		add("policy", 140, h(Ui.Text, { value = "Changing builds is free, with a " .. math.ceil(state.Cooldown / 60)
			.. "-minute reconfiguration cooldown. Collect your vault before switching to a smaller build. Purchased Star Grid bonuses remain permanent. Equipped rates stay fixed."
			.. (if state.ReadyAt > workspace:GetServerTimeNow() then "\nReconfiguration available in " .. math.ceil(state.ReadyAt - workspace:GetServerTimeNow()) .. " seconds." else "\nAll four builds are available."),
			size = 14, wrap = true, color = Palette.muted, sizeConstraint = UDim2.fromScale(1, 1) }))
		for _, build in state.Builds do
			local equipped = state.Focus == build.Id
			local positive = math.floor((build.GainMultiplier - 1) * 100 + 0.5)
			local negative = math.floor((1 - build.CostMultiplier) * 100 + 0.5)
			add("build-" .. build.Id, 270, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14,
				accent = if equipped then Palette.mango else Palette.cyan },
				h(Ui.Text, { value = build.Name, size = 21, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 52) }),
				h(Ui.Text, { value = build.Description .. (if build.Gain ~= "" then `\n+{positive}% {build.Gain}, -{negative}% {build.Cost}.` else "")
					.. "\nPreview: " .. Format.compactNumber(build.Production) .. "/s production; " .. Format.compactNumber(build.Capacity) .. " vault; "
					.. Format.compactNumber(build.Tap) .. " overcharge; " .. math.floor(build.Offline * 100) .. "% offline.",
					size = 14, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 56), sizeConstraint = UDim2.new(1, 0, 0, 122) }),
				h(Ui.Button, { text = if equipped then "Equipped" else "Equip this build", size = UDim2.new(1, 0, 0, 54),
					position = UDim2.fromOffset(0, 188), color = Palette.mango, disabled = busy or unresolved ~= nil or equipped or state.ReadyAt > workspace:GetServerTimeNow(),
					reducedMotion = props.reducedMotion, onClick = function() selectBuild(build.Id) end })))
		end
		if #state.Foundation > 0 then
			add("legacy-header", 64, h(Ui.Text, { value = "Preserved foundation bonuses", size = 20, wrap = true, sizeConstraint = UDim2.fromScale(1, 1) }))
			for index, bonus in state.Foundation do
				add("legacy-" .. index, 74, h(Ui.Text, { value = bonus.Name .. "  +" .. string.format("%.2f", bonus.Value * 100) .. "%",
					size = 15, wrap = true, color = Palette.muted, sizeConstraint = UDim2.fromScale(1, 1) }))
			end
		end
	end
	return React.createElement(PageScaffold, { sections = sections, gap = 12, tailPad = 72, scrollBarColor = Palette.mango })
end
return function() return { SpecializationsView = SpecializationsView } end
