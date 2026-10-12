--!nocheck
-- "Ready now": everything claimable across the game in one list, with the page that claims it.
-- Overview shows it as a strip of jump buttons; Quick Find lists it before you type.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local PageReadyMath = require(script.Parent.LayoutKit)("pageReadyMath")
local theme = require(script.Parent.CoreKit)("theme")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon

local Palette = theme.Palette
local h = React.createElement
local TextService = game:GetService("TextService")

local Board = {}

local function readyCount(list)
	local count = 0
	for _, entry in (if type(list) == "table" then list else {}) do
		if type(entry) == "table" and not entry.Claimed and (tonumber(entry.Progress) or 0) >= (tonumber(entry.Target) or math.huge) then
			count += 1
		end
	end
	return count
end

local function unlocked(state, id)
	local lock = state.FeatureUnlocks and state.FeatureUnlocks[id]
	return not (lock ~= nil and lock.Unlocked == false)
end

-- { route, label, detail, count, icon, accent } for every page with something to claim
function Board.collect(state, config)
	local list = {}
	local function add(route, label, detail, count, icon, accent)
		if count > 0 and unlocked(state, route) then
			table.insert(list, { route = route, label = label, detail = detail, count = count, icon = icon, accent = accent })
		end
	end
	local daily = state.Daily or {}
	local timed = state.TimedRewards or {}
	local played = tonumber(timed.PlaySeconds) or 0
	local timedReady = 0
	for _, entry in timed.Rewards or {} do
		if not entry.Claimed and played >= (tonumber(entry.Seconds) or math.huge) then
			timedReady += 1
		end
	end
	local rewards = (if daily.CanClaim == true then 1 else 0) + timedReady
	add("Rewards", "Rewards", if daily.CanClaim == true then "Daily parcel is ready" else "Playtime drop ready", rewards, "Gift", Palette.pink)
	add("Missions", "Missions", "Finished missions", PageReadyMath.CountReadyQuests(state.Quests), "Mission", Palette.green)
	add("Milestones", "Milestones", "Goals reached", readyCount(state.Achievements), "Milestone", Palette.mango)
	if state.Wheel ~= nil and state.Wheel.CanSpin == true then
		add("Wheel", "Wheel", "Free spin ready", 1, "Wheel", Palette.mango)
	end
	local unread = state.Mailbox and tonumber(state.Mailbox.Unread) or 0
	add("Mail", "Mail", "Unread letters", unread, "Mail", Palette.cyan)
	add("Lab", "Lab", "Finished orders", PageReadyMath.CountReadyLabOrders(state.Lab), "Lab", Palette.mint)
	local okPath, pathReady = pcall(PageReadyMath.ForgePathReady, state, config)
	add("ForgePath", "Forge Path", "Step ready", if okPath and pathReady then 1 else 0, "Forge", Palette.violet)
	local invite = state.Trade and state.Trade.Invite
	add("Trade", "Trade", "Trade invite waiting", if invite ~= nil then 1 else 0, "Send", Palette.mint)
	-- crews: an invite to answer, or crew-goal tiers this player can claim
	local okCrew, crewState = pcall(function() return require(script.Parent.CrewStore).get() end)
	if okCrew and type(crewState) == "table" then
		local crew = crewState.crew
		local claimable = 0
		if crew and type(crew.Tiers) == "table" then
			local mine = 0
			for _, member in crew.Members or {} do
				if member.UserId == game:GetService("Players").LocalPlayer.UserId then mine = member.Collects or 0 end
			end
			for _, tier in crew.Tiers do
				if not tier.Claimed and (crew.Pooled or 0) >= tier.Target and mine >= (crew.MinContribution or 0) then
					claimable += 1
				end
			end
		end
		local pending = crewState.invite and (crewState.invite.ExpiresAt or 0) > os.time()
		add("Crew", "Crew", if pending then "Crew invite waiting" else "Crew goal ready", claimable + (if pending then 1 else 0), "Crew", Palette.green)
	end
	return list
end

function Board.total(list)
	local total = 0
	for _, entry in list do
		total += entry.count
	end
	return total
end

local function Pill(props)
	local entry = props.entry
	local hovered, setHovered = React.useState(false)
	return h("textbutton", {
		Size = UDim2.fromOffset(0, props.height),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = if hovered then theme.darken(entry.accent, 0.45) else theme.darken(entry.accent, 0.62),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				props.onOpen(entry.route)
			end,
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = entry.accent,
		Transparency = if hovered then 0.1 else 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("uipadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 12),
	}), h("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}), h("frame", {
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
	}, h(Icon, { kind = entry.icon, color = entry.accent, accent = entry.accent, size = 20, spin = false })), h("textlabel", {
		Size = UDim2.fromOffset(0, props.height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Text = if props.brief then `<b>{entry.label}</b>` else `<b>{entry.label}</b>  <font transparency="0.35">{entry.detail}</font>`,
		RichText = true,
		TextSize = 14,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3 = Palette.cream,
	}), h("frame", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = entry.accent,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}), h("textlabel", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = tostring(entry.count),
		TextSize = 13,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3 = Palette.ink,
	})))
end

-- Width a pill takes: padding, icon, label (+ detail), count badge.
local function textWidth(text, font)
	local ok, size = pcall(TextService.GetTextSize, TextService, text, 14, font, Vector2.new(2000, 40))
	return if ok then size.X else #text * 7
end
function Board.pillWidth(entry, brief)
	local label = textWidth(entry.label, Enum.Font.BuilderSansBold)
	local detail = if brief then 0 else textWidth("  " .. entry.detail, Enum.Font.BuilderSansMedium)
	local count = textWidth(tostring(entry.count), Enum.Font.BuilderSansExtraBold) + 16
	return 10 + 20 + 8 + label + detail + 8 + count + 12
end

-- Fit pills into `room`: full pills if they all fit, else label-only pills, else as many label-only
-- pills as fit beside a "+N" pill. Returns (shown, brief, hidden) so nothing is cut by the edge.
function Board.plan(list, room, widthOf)
	widthOf = widthOf or Board.pillWidth
	local function total(entries, brief, extra)
		local sum = extra or 0
		for index, entry in entries do
			sum += widthOf(entry, brief) + (if index > 1 or extra then 8 else 0)
		end
		return sum
	end
	if room <= 0 or total(list, false) <= room then
		return list, false, 0
	end
	if total(list, true) <= room then
		return list, true, 0
	end
	local moreW = 64
	local shown = {}
	for _, entry in list do
		local candidate = table.clone(shown)
		table.insert(candidate, entry)
		if total(candidate, true, moreW) > room then break end
		shown = candidate
	end
	return shown, true, #list - #shown
end

-- One row of jump buttons plus a Find button; height is fixed by the caller.
function Board.Strip(props)
	local list = props.list
	local pillH = props.pillHeight or 40
	local stripRef = React.useRef(nil)
	local room, setRoom = React.useState(0)
	React.useEffect(function()
		local strip = stripRef.current
		if strip == nil then return nil end
		local function sync() setRoom(math.floor(strip.AbsoluteSize.X)) end
		sync()
		local connection = strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
		return function() connection:Disconnect() end
	end, {})
	local shownList, brief, hidden = Board.plan(list, room)
	local children = {
		layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	for index, entry in shownList do
		children[entry.route] = h(Pill, { entry = entry, layoutOrder = index, height = pillH, onOpen = props.onOpen, brief = brief })
	end
	if hidden > 0 then
		children.more = h("textbutton", {
			Size = UDim2.fromOffset(56, pillH),
			LayoutOrder = #shownList + 1,
			BackgroundColor3 = Palette.panelSoft,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = `+{hidden}`,
			TextSize = 14,
			FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
			TextColor3 = Palette.cream,
			Event = { Activated = function() if props.onFind then props.onFind() end end },
		}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
			Color = Palette.lineSoft, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}))
	end
	if #list == 0 then
		children.none = h("textlabel", {
			Size = UDim2.fromOffset(0, pillH),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Text = "Nothing waiting right now. Keep forging.",
			TextSize = 14,
			FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
			TextColor3 = Palette.muted,
		})
	end
	local findW = if props.onFind then (if props.compact then pillH else 132) else 0
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = Palette.lineSoft,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("textlabel", {
		Size = UDim2.fromOffset(if props.compact then 0 else 92, pillH),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Visible = not props.compact,
		Text = if #list > 0 then `READY · {Board.total(list)}` else "READY",
		TextSize = 12,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3 = if #list > 0 then Palette.green else Palette.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}), h("scrollingframe", {
		Name = "ReadyStrip",
		ref = stripRef,
		Size = UDim2.new(1, -((if props.compact then 12 else 112) + findW + (if findW > 0 then 20 else 12)), 1, 0),
		Position = UDim2.fromOffset(if props.compact then 10 else 106, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		ClipsDescendants = true,
	}, children), findW > 0 and h("textbutton", {
		Size = UDim2.fromOffset(findW, pillH),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Event = {
			Activated = function()
				props.onFind()
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = Palette.lineSoft,
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, if props.compact then (findW - 18) / 2 else 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
	}, h(Icon, { kind = "Search", color = Palette.cream, accent = Palette.cyan, size = 18, spin = false })), not props.compact and h("textlabel", {
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1,
		Text = "Find  <font transparency=\"0.5\">Ctrl+K</font>",
		RichText = true,
		TextSize = 14,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3 = Palette.cream,
		TextXAlignment = Enum.TextXAlignment.Left,
	})))
end

return Board
