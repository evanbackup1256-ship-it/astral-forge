local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local Icon = require(script.Parent.Parent.Icon).Icon
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local _theme = require(script.Parent.Parent.theme)
local Palette = _theme.Palette
local _adminFields = require(script.Parent.Parent.adminFields)
local fieldsFor = _adminFields.fieldsFor
local reasonsFor = _adminFields.reasonsFor
local compactNumber = require(script.Parent.Parent.format).compactNumber
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local Panel = _ui.Panel
local SearchField = _ui.SearchField
local Text = _ui.Text
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold

-- Admin is the one page that is deliberately desktop-only: a fixed three-column
-- console instead of the stacked/reflow layout every other page uses. On small
-- windows the columns get narrow but never reflow — the owner tooling stays
-- predictable instead of rearranging under the cursor. PageScaffold owns the
-- outer Y scroll; FlatList owns the long player/command catalogs.
local GAP = 14
local HEADER_H = 62
local PLAYERS_W = 280
local DETAIL_W = 340
local CMD_MIN = 360
local CONSOLE_W = PLAYERS_W + DETAIL_W + CMD_MIN + GAP * 2
local RECENT_MIN = 200
local PLAYER_ROW = 56
local PLAYER_ROW_STRIDE = PLAYER_ROW + 6
local COMMAND_ROW = 48
local COMMAND_ROW_STRIDE = COMMAND_ROW + 6
local SCROLL_BAR = 4

local ADMIN_CATS = {
	{ id = "All", label = "ALL" },
	{ id = "Economy", label = "ECON" },
	{ id = "Progress", label = "PROG" },
	{ id = "Items", label = "ITEMS" },
	{ id = "Resets", label = "RESET" },
	{ id = "Troll", label = "TROLL" },
	{ id = "Moderation", label = "MOD" },
}

local function hayHas(hay, needle)
	if #needle == 0 then
		return true
	end
	return (string.find(string.lower(hay), string.lower(needle), 1, true)) ~= nil
end

local function catAccent(category)
	if category == "Economy" then return Palette.mint end
	if category == "Progress" then return Palette.cyan end
	if category == "Items" then return Palette.violet end
	if category == "Resets" then return Palette.mango end
	if category == "Troll" then return Palette.pink end
	if category == "Moderation" then return Palette.coral end
	return Palette.steel
end

local function commandNeedsArm(entry)
	if entry == nil then return true end
	if entry.Danger == "quick" then return false end
	if entry.Danger == "arm" then return true end
	local category = entry.Category or "Economy"
	return category == "Troll" or category == "Resets" or category == "Moderation"
end

local function SectionTitle(_param)
	return React.createElement(Text, {
		value = _param.value,
		size = 10,
		color = _param.accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = _param.position or UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, -8, 0, 13),
		layoutOrder = _param.layoutOrder,
	})
end

-- Stat tile for the target inspect grid.
local function StatCell(_param)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = _param.label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(10, 6),
		sizeConstraint = UDim2.new(1, -16, 0, 11),
	}), React.createElement(Text, {
		value = _param.value,
		size = 14,
		color = _param.accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, 19),
		sizeConstraint = UDim2.new(1, -16, 0, 18),
	}))
end

local function PlayerRow(_param)
	local player = _param.player
	local selected = _param.selected
	local you = _param.you
	local onClick = _param.onClick
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local accent = if selected then Palette.mint else Palette.lineSoft
	local reveal = useStagger(layoutOrder, reducedMotion)

	return React.createElement("textbutton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, PLAYER_ROW),
		BackgroundTransparency = reveal:map(function(amount)
			return (if selected then 0 else 0.12) + (1 - math.clamp(amount, 0, 1)) * (1 - (if selected then 0 else 0.12))
		end),
		BackgroundColor3 = if selected then Palette.panelRaised else Palette.panel,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play("playerlistSelect")
				onClick()
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = if selected then 0.45 else 1,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(12, 10),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Icon, {
		kind = "Crew",
		color = if selected then Palette.mint else Palette.muted,
		accent = Palette.mint,
		size = 18,
		spin = false,
		position = UDim2.fromOffset(9, 9),
	})), React.createElement(Text, {
		value = if you then `{player.DisplayName}  ·  YOU` else player.DisplayName,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(58, 9),
		sizeConstraint = UDim2.new(1, -70, 0, 17),
	}), React.createElement(Text, {
		value = `@{player.Name}  ·  {compactNumber(player.Cash or 0)}`,
		size = 10,
		color = Palette.cyan,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(58, 28),
		sizeConstraint = UDim2.new(1, -70, 0, 14),
	}), selected and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -20, 0.5, -4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end

local function CommandRow(_param)
	local entry = _param.entry
	local selected = _param.selected
	local onClick = _param.onClick
	local accent = catAccent(entry.Category)
	local arm = commandNeedsArm(entry)

	return React.createElement("textbutton", {
		Size = UDim2.new(1, -4, 0, COMMAND_ROW - 6),
		BackgroundColor3 = if selected then Palette.panelRaised else Palette.panel,
		BackgroundTransparency = if selected then 0 else 0.08,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				onClick()
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("uistroke", {
		Color = if selected then accent else Palette.line,
		Thickness = 1,
		Transparency = if selected then 0.3 else 0.78,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 4, 1, -14),
		Position = UDim2.fromOffset(0, 7),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = entry.Label,
		size = 12,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(15, 6),
		sizeConstraint = UDim2.new(1, -104, 0, 16),
	}), React.createElement(Text, {
		value = string.upper(entry.Category or "ECON"),
		size = 9,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -92, 0, 7),
		sizeConstraint = UDim2.fromOffset(80, 12),
	}), React.createElement(Text, {
		value = if arm then "ARM" else "RUN",
		size = 8,
		color = if arm then Palette.mango else Palette.mint,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -92, 0, 21),
		sizeConstraint = UDim2.fromOffset(80, 12),
	}))
end

local function AuditLine(_param)
	local record = _param.record
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = record.Command,
		size = 10,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		sizeConstraint = UDim2.new(0.42, -4, 1, 0),
	}), React.createElement(Text, {
		value = `{record.ActorName} → {record.TargetName}`,
		size = 9,
		color = Palette.cyan,
		fit = true,
		minSize = 8,
		position = UDim2.new(0.42, 4, 0, 0),
		sizeConstraint = UDim2.new(0.58, -4, 1, 0),
	}))
end

local function AdminView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local admin = state.Admin

	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion

	local targetId, setTargetId = React.useState((admin and admin.SelfUserId) or (admin and admin.Online and admin.Online[1] and admin.Online[1].UserId) or 0)
	local command, setCommand = React.useState((admin and admin.Commands and admin.Commands[1] and admin.Commands[1].Id) or "GrantFlux")
	local category, setCategory = React.useState("All")
	local playerQuery, setPlayerQuery = React.useState("")
	local commandQuery, setCommandQuery = React.useState("")
	local amount, setAmount = React.useState("1000")
	local option, setOption = React.useState("")
	local reason, setReason = React.useState(reasonsFor("GrantFlux", "Economy")[1].id)
	local armed, setArmed = React.useState(false)
	local busy, setBusy = React.useState(false)
	local shakeToken, setShakeToken = React.useState(0)
	local lastNote, setLastNote = React.useState((admin and admin.LastAction and admin.LastAction.Message) or "")
	local lastOk, setLastOk = React.useState((admin and admin.LastAction and admin.LastAction.Ok) or true)
	local mountedRef = React.useRef(true)
	local executeAttempt = React.useRef(0)
	local enter = useEntrance(softMotion)

	React.useEffect(function()
		return function()
			mountedRef.current = false
			executeAttempt.current += 1
		end
	end, {})

	React.useEffect(function()
		if targetId == 0 and admin and admin.SelfUserId then
			setTargetId(admin.SelfUserId)
		end
	end, { admin and admin.SelfUserId, targetId })

	React.useEffect(function()
		local online = (admin and admin.Online) or {}
		if #online == 0 then return end
		local found = false
		for _, p in online do
			if p.UserId == targetId then found = true break end
		end
		if not found then
			setTargetId((admin and admin.SelfUserId) or online[1].UserId)
		end
	end, { admin and admin.Online, admin and admin.SelfUserId, targetId })

	React.useEffect(function()
		local commands = (admin and admin.Commands) or {}
		if #commands == 0 then return end
		local found = false
		for _, c in commands do
			if c.Id == command then found = true break end
		end
		if not found then
			setCommand(commands[1].Id or "GrantFlux")
		end
	end, { admin and admin.Commands, command })

	React.useEffect(function()
		setArmed(false)
	end, { amount, command, option, reason, targetId })

	React.useEffect(function()
		local layout = fieldsFor(command, config, admin and admin.Banned)
		local commands = (admin and admin.Commands) or {}
		local current = nil
		for _, c in commands do
			if c.Id == command then current = c break end
		end
		local reasonChoices = reasonsFor(command, current and current.Category)
		setAmount(layout.defaultAmount)
		setOption(layout.defaultOption)
		setReason(reasonChoices[1] and reasonChoices[1].id or "Owner gameplay administration")
		if layout.overridesTarget and layout.defaultAmount ~= "" then
			local userId = tonumber(layout.defaultAmount)
			if userId then setTargetId(userId) end
		end
	end, { admin and admin.Banned, admin and admin.Commands, command, config })

	React.useEffect(function()
		if not (admin and admin.LastAction) then return end
		setLastNote(admin.LastAction.Message)
		setLastOk(admin.LastAction.Ok)
	end, { admin and admin.LastAction })

	if not (admin and admin.Access == true) then
		return React.createElement(EmptyState, {
			icon = "Lock",
			title = "Owner tools locked",
			body = "Only the game owner can open this page.",
			accent = Palette.coral,
		})
	end

	local online = admin.Online or {}
	local commands = admin.Commands or {}
	local shownPlayers = {}
	for _, p in online do
		if hayHas(`{p.DisplayName} {p.Name} {p.UserId}`, playerQuery) then
			table.insert(shownPlayers, p)
		end
	end
	local shownCommands = {}
	for _, c in commands do
		local catOk = category == "All" or (c.Category or "Economy") == category
		if catOk and hayHas(`{c.Id} {c.Label} {c.Category or ""}`, commandQuery) then
			table.insert(shownCommands, c)
		end
	end
	local recent = admin.Recent or {}
	local selected = nil
	for _, c in commands do
		if c.Id == command then selected = c break end
	end
	local selectedPlayer = nil
	for _, p in online do
		if p.UserId == targetId then selectedPlayer = p break end
	end
	local fields = fieldsFor(command, config, admin.Banned)
	local needsArm = commandNeedsArm(selected)
	local accent = catAccent(selected and selected.Category)
	local integrity = admin.Integrity
	local reasonChoices = reasonsFor(command, selected and selected.Category)
	local fieldSlots = (if fields.usesAmount then 1 else 0) + (if fields.usesOption then 1 else 0) + (if needsArm then 1 else 0)

	local execute = function()
		if busy then return end
		if needsArm and not armed then
			setArmed(true)
			Audio:play("adminArm")
			return
		end
		setBusy(true)
		local attempt = executeAttempt.current + 1
		executeAttempt.current = attempt
		Audio:play("adminExecute")
		local sendAmount = if amount == "Permanent" then "1" else (if amount ~= "" then amount else "1")
		local sendOption = if amount == "Permanent" then "Permanent" else option
		local sendTarget = if fields.overridesTarget then (tonumber(amount) or targetId) else targetId
		dispatch("AdminExecute", {
			TargetUserId = sendTarget,
			Command = command,
			Amount = sendAmount,
			Option = sendOption,
			Reason = reason,
			Nonce = HttpService:GenerateGUID(false),
		}, function(response)
			if not mountedRef.current or executeAttempt.current ~= attempt then return end
			setBusy(false)
			setArmed(false)
			setLastOk(response.ok == true)
			setLastNote(if response.ok == true then (response.message or "Done.") else (response.error or "Failed."))
			if response.ok ~= true then
				setShakeToken(function(t) return t + 1 end)
			end
		end)
	end

	local runDisabled = busy or (if fields.overridesTarget then #fields.amountChoices == 0 else targetId == 0) or (needsArm and #reason < 3)
	local runLabel = if busy then "APPLYING…" elseif needsArm and not armed then "ARM" else "RUN"
	local runColor = if busy then Palette.panelSoft elseif needsArm and armed then Palette.coral elseif needsArm then Palette.mango else Palette.mint

	-- Fixed geometry. The page area is always treated as a desktop console:
	-- header on top, three columns below, no reflow.
	local FIELD_H = 50
	local EXEC_TITLE = 40
	local EXEC_BUTTON = 46
	local EXEC_NOTE = 22
	local executeH = EXEC_TITLE + math.max(0, fieldSlots) * FIELD_H + EXEC_BUTTON + EXEC_NOTE + 20

	local INSPECT_TITLE = 34
	local STAT_H = 40
	local STAT_GAP = 8
	local inspectH = INSPECT_TITLE + STAT_H * 2 + STAT_GAP + 26

	-- Header bar.
	local header = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, HEADER_H),
		accent = Palette.coral,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 0,
		reveal = enter,
		clips = false,
	}, React.createElement(Text, {
		value = "ADMIN",
		size = 9,
		color = Palette.coral,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(0, 70, 0, 12),
	}), React.createElement(Text, {
		value = "Owner Console",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 13),
		sizeConstraint = UDim2.new(1, -340, 0, 22),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -120, 0, 22),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Badge, {
		value = admin.Role or "ADMIN",
		accent = Palette.coral,
		filled = true,
		size = UDim2.fromOffset(108, 22),
	}), React.createElement(Badge, {
		value = if (integrity and integrity.Healthy) == false then "RESTORED" else "HEALTHY",
		accent = if (integrity and integrity.Healthy) == false then Palette.mango else Palette.mint,
		filled = true,
		size = UDim2.fromOffset(84, 22),
	}), selectedPlayer and selectedPlayer.Unlimited == true and React.createElement(Badge, {
		value = "UNLIMITED",
		accent = Palette.violet,
		filled = true,
		size = UDim2.fromOffset(88, 22),
	})), React.createElement(Button, {
		text = "REFRESH",
		onClick = function() dispatch("GetAdminState") end,
		color = Palette.panelSoft,
		textColor = Palette.mint,
		outline = true,
		size = UDim2.fromOffset(104, 32),
		position = UDim2.new(1, -104, 0, 3),
		reducedMotion = reducedMotion,
	}))

	-- Column 1: players.
	local playerSection = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 1,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "PLAYERS",
		accent = Palette.cyan,
	}), React.createElement(SearchField, {
		value = playerQuery,
		onChange = setPlayerQuery,
		accent = Palette.cyan,
		placeholder = "Search players…",
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 20),
		reducedMotion = reducedMotion,
	}), (function()
		local listSize = UDim2.new(1, 0, 1, -64)
		local listPos = UDim2.fromOffset(0, 64)
		if #shownPlayers == 0 then
			return React.createElement("frame", {
				Size = listSize,
				Position = listPos,
				BackgroundTransparency = 1,
			}, React.createElement(Text, {
				value = "No players match.",
				size = 11,
				color = Palette.muted,
			}))
		end
		return React.createElement(FlatList, {
			data = shownPlayers,
			itemHeight = PLAYER_ROW_STRIDE,
			overscan = if softMotion then 0 else 2,
			canvasTail = 4,
			Size = listSize,
			Position = listPos,
			scrollBarColor = Palette.cyan,
			scrollBarThickness = SCROLL_BAR,
			keyExtractor = function(player)
				return tostring(player.UserId)
			end,
			renderItem = function(_param)
				local player = _param.item
				local index = _param.index
				return React.createElement(PlayerRow, {
					player = player,
					selected = player.UserId == targetId,
					you = player.UserId == admin.SelfUserId,
					onClick = function() setTargetId(player.UserId) end,
					layoutOrder = index + 1,
					reducedMotion = reducedMotion,
				})
			end,
		})
	end)())

	-- Column 2: commands.
	local commandSection = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 2,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "COMMANDS",
		accent = Palette.violet,
	}), React.createElement(SearchField, {
		value = commandQuery,
		onChange = setCommandQuery,
		accent = Palette.violet,
		placeholder = "Search commands…",
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 20),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 62),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), (function()
		local pills = table.create(#ADMIN_CATS)
		for i, cat in ADMIN_CATS do
			pills[i] = React.createElement(Button, {
				key = cat.id,
				text = cat.label,
				onClick = function() setCategory(cat.id) end,
				color = if category == cat.id then Palette.violet else Palette.panelSoft,
				textColor = if category == cat.id then Palette.ink else Palette.creamSoft,
				outline = category ~= cat.id,
				highlight = category == cat.id,
				size = UDim2.fromOffset(62, 28),
				reducedMotion = reducedMotion,
			})
		end
		return pills
	end)()), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -100),
		Position = UDim2.fromOffset(0, 100),
		BackgroundTransparency = 1,
	}, #shownCommands == 0 and React.createElement(Text, {
		value = "Nothing matches that filter.",
		size = 11,
		color = Palette.muted,
	}) or React.createElement(FlatList, {
		data = shownCommands,
		itemHeight = COMMAND_ROW_STRIDE,
		overscan = if softMotion then 0 else 2,
		canvasTail = 4,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.violet,
		scrollBarThickness = SCROLL_BAR,
		keyExtractor = function(entry)
			return entry.Id
		end,
		renderItem = function(_param)
			local entry = _param.item
			local index = _param.index
			return React.createElement(CommandRow, {
				entry = entry,
				selected = entry.Id == command,
				onClick = function() setCommand(entry.Id) end,
				layoutOrder = index + 1,
			})
		end,
	})))

	-- Column 3 top: target inspect.
	local inspectSection = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, inspectH),
		accent = Palette.mint,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 0,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "TARGET",
		accent = Palette.mint,
	}), React.createElement(Text, {
		value = if selectedPlayer then `{selectedPlayer.DisplayName}  ·  {selectedPlayer.UserId}` else "Select a player.",
		size = 12,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 15),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, STAT_H * 2 + STAT_GAP),
		Position = UDim2.fromOffset(0, INSPECT_TITLE),
		BackgroundTransparency = 1,
	}, React.createElement("uigridlayout", {
		CellSize = UDim2.new(0.25, -6, 0, STAT_H),
		CellPadding = UDim2.fromOffset(STAT_GAP, STAT_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
	}), React.createElement(StatCell, { label = "CASH", value = selectedPlayer and compactNumber(selectedPlayer.Cash or 0) or "--", accent = Palette.cyan }),
		React.createElement(StatCell, { label = "VAULT", value = selectedPlayer and `{compactNumber(selectedPlayer.Vault or 0)}/{compactNumber(selectedPlayer.Capacity or 0)}` or "--", accent = Palette.mint }),
		React.createElement(StatCell, { label = "CORES", value = selectedPlayer and compactNumber(selectedPlayer.Cores or 0) or "--", accent = Palette.violet }),
		React.createElement(StatCell, { label = "REBIRTHS", value = selectedPlayer and compactNumber(selectedPlayer.Rebirths or 0) or "--", accent = Palette.pink }),
		React.createElement(StatCell, { label = "WORLD", value = selectedPlayer and tostring(selectedPlayer.Zone or 1) or "--", accent = Palette.mango }),
		React.createElement(StatCell, { label = "RATE", value = selectedPlayer and `{compactNumber(selectedPlayer.Production or 0)}/s` or "--", accent = Palette.cyan }),
		React.createElement(StatCell, { label = "DUST", value = selectedPlayer and compactNumber(selectedPlayer.Stardust or 0) or "--", accent = Palette.steel }),
		React.createElement(StatCell, { label = "KEYS", value = selectedPlayer and compactNumber(selectedPlayer.Keys or 0) or "--", accent = Palette.violet })))

	-- Column 3 middle: execute dock.
	local executeActionsHostRef = React.useRef(nil)
	-- Gamepad: park Selection on ARM/RUN (FocusClaim prefers Confirm-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = executeActionsHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			task.cancel(selectJob)
		end
	end, { command, armed, busy, targetId })

	local executeDock = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, executeH),
		accent = if armed then Palette.coral else accent,
		background = Palette.panelRaised,
		padding = 12,
		layoutOrder = 1,
		highlight = armed,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = if needsArm then "ARM TO RUN" else "READY",
		accent = if armed then Palette.coral else accent,
	}), React.createElement(Text, {
		value = (selected and selected.Label) or command,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, 15),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, math.max(0, fieldSlots * FIELD_H - 6)),
		Position = UDim2.fromOffset(0, EXEC_TITLE),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}), fields.usesAmount and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, FIELD_H - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		ZIndex = 52,
	}, React.createElement(Dropdown, {
		options = fields.amountChoices,
		value = amount,
		onChange = function(id)
			setAmount(id)
			if fields.overridesTarget then
				local uid = tonumber(id)
				if uid then setTargetId(uid) end
			end
		end,
		accent = Palette.mango,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 80,
	})), fields.usesOption and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, FIELD_H - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 51,
	}, React.createElement(Dropdown, {
		options = fields.optionChoices,
		value = option,
		onChange = setOption,
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 70,
	})), needsArm and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, FIELD_H - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 50,
	}, React.createElement(Dropdown, {
		options = reasonChoices,
		value = reason,
		onChange = setReason,
		accent = Palette.steel,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 60,
	}))), React.createElement("frame", {
		Name = "AdminExecuteActions",
		Size = UDim2.new(1, 0, 0, EXEC_BUTTON),
		Position = UDim2.fromOffset(0, EXEC_TITLE + fieldSlots * FIELD_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ref = executeActionsHostRef,
	}, React.createElement("frame", {
		Name = "AdminConfirmRun",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = runLabel,
		icon = "Lock",
		onClick = execute,
		color = runColor,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = runDisabled,
		loading = busy,
		shakeToken = shakeToken,
		highlight = armed or not needsArm,
		reducedMotion = reducedMotion,
	}))), React.createElement(Text, {
		value = if lastNote ~= "" then lastNote else (if needsArm then "Arm first. Dangerous commands need a second tap." else "Economy, progress, and item grants run on one tap."),
		size = 9,
		color = if lastNote ~= "" then (if lastOk then Palette.mint else Palette.coral) else Palette.muted,
		wrap = true,
		fit = false,
		position = UDim2.new(0, 0, 1, -EXEC_NOTE + 4),
		sizeConstraint = UDim2.new(1, 0, 0, EXEC_NOTE - 4),
	}))

	-- Column 3 bottom: recent audit feed fills whatever is left.
	local recentSection = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.steel,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 2,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "RECENT",
		accent = Palette.steel,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -20),
		Position = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}), #recent == 0 and React.createElement(Text, {
		value = "No commands run yet.",
		size = 10,
		color = Palette.muted,
	}) or (function()
		local rows = table.create(math.min(6, #recent))
		for i = 1, math.min(6, #recent) do
			rows[i] = React.createElement(AuditLine, {
				key = recent[i].Id,
				record = recent[i],
			})
		end
		return rows
	end)()))

	-- Fixed three-column console: PLAYERS | COMMANDS | TARGET+EXECUTE+RECENT.
	-- PageScaffold owns outer Y scroll when the viewport is shorter than the console
	-- body; UISizeConstraint keeps the owner console at CONSOLE_W so columns never reflow.
	local BODY_H = inspectH + GAP + executeH + GAP + RECENT_MIN
	local consoleBody = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(CONSOLE_W, BODY_H),
	}), React.createElement("frame", {
		Size = UDim2.new(0, PLAYERS_W, 1, 0),
		BackgroundTransparency = 1,
	}, playerSection), React.createElement("frame", {
		Size = UDim2.new(0, DETAIL_W, 1, 0),
		Position = UDim2.new(1, -DETAIL_W, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, inspectH),
		BackgroundTransparency = 1,
	}, inspectSection), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, executeH),
		Position = UDim2.fromOffset(0, inspectH + GAP),
		BackgroundTransparency = 1,
	}, executeDock), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -(inspectH + executeH + GAP * 2)),
		Position = UDim2.fromOffset(0, inspectH + executeH + GAP * 2),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(0, RECENT_MIN),
	}), recentSection)), React.createElement("frame", {
		Size = UDim2.new(1, -(PLAYERS_W + DETAIL_W + GAP * 2), 1, 0),
		Position = UDim2.fromOffset(PLAYERS_W + GAP, 0),
		BackgroundTransparency = 1,
	}, commandSection))

	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = 8,
		scrollBarColor = Palette.steel,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = HEADER_H,
				element = header,
			},
			{
				id = "console",
				fill = true,
				minHeight = BODY_H,
				element = consoleBody,
			},
		},
	})
end

return {
	AdminView = AdminView,
}
