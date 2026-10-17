--!nocheck
-- Quick Find: one search box over every page, setting, machine, research, relic, world,
-- boost, milestone and story chapter. Ctrl+K opens it, the top bar has a button.
-- Picking a result opens its page with that page's search already filled in.
-- It opens out of a molten seam, results cascade in, one slab glides between rows and a
-- spark flies off the caret with every keypress.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Model = require(script.Parent.BrowseModel)
local ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local AppHelpers = require(script.Parent.CoreKit)("appNav").AppHelpers
local NavRoutes = require(script.Parent.CoreKit)("navRouteTable")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local useFlipperSpring = require(script.Parent.MotionKit)("motion").useFlipperSpring
local ReadyBoard = require(script.Parent.ReadyBoard)

local Palette = theme.Palette
local h = React.createElement

local QuickFind = {}

-- open requests from anywhere (top bar button, menu, keyboard)
local openers = {}
function QuickFind.open()
	for _, fn in table.clone(openers) do
		fn()
	end
end

-- extra words for each page so "money", "pets" or "spin" land somewhere useful
local PAGE_WORDS = {
	Overview = "home vault collect production summary dashboard",
	Workshop = "machines buy build production upgrade forge",
	Inventory = "relics items equip codex crates keys pets essence",
	Research = "upgrades bonuses permanent study",
	Shop = "store buy packs gamepass robux crates codes",
	Settings = "options audio sound music graphics controls mobile accessibility",
	Missions = "quests jobs tasks daily weekly",
	Rewards = "daily login streak claim free timed gifts",
	Wheel = "spin prize tokens cooldown",
	Bazaar = "black market supplies stock deals restock materials keys boosts",
	Boosts = "potions buffs multiplier overdrive surge",
	Worlds = "zones maps travel expedition",
	Lab = "orders cells power",
	StarGrid = "forge specializations builds handcraft deep reserves night shift preserved bonuses",
	Ascension = "ascension ascend final rebirth aether sigils harmony prestige",
	Echoes = "echo forge keep",
	ForgePath = "path pass track xp chests",
	Milestones = "achievements goals badges",
	Story = "chapters lore read vale",
	Command = "crew titles officers",
	Convergence = "co op event together",
	Guild = "clan team charter members",
	Crew = "friends online players",
	Chat = "talk messages",
	Mail = "inbox letters gifts parcels",
	Trade = "swap exchange offers",
	Leaderboards = "ranks top players best",
	Credits = "about thanks team",
	Admin = "owner moderation tools",
}

local KIND_META = {
	Action = { label = "Action", group = "ACTIONS", weight = 1.35, accent = "mint" },
	Page = { label = "Page", group = "PAGES", weight = 1.3, accent = "cyan" },
	Setting = { label = "Setting", group = "SETTINGS", weight = 1.05, accent = "violet" },
	Machine = { label = "Machine", group = "MACHINES", weight = 1, accent = "coral", route = "Workshop", icon = "Forge" },
	Research = { label = "Research", group = "RESEARCH", weight = 1, accent = "cyan", route = "Research", icon = "Research" },
	Relic = { label = "Relic", group = "RELICS", weight = 0.95, accent = "violet", route = "Inventory", icon = "Inventory" },
	World = { label = "World", group = "WORLDS", weight = 0.95, accent = "mint", route = "Worlds", icon = "World" },
	Boost = { label = "Boost", group = "BOOSTS", weight = 0.95, accent = "pink", route = "Boosts", icon = "Boost" },
	Milestone = { label = "Milestone", group = "MILESTONES", weight = 0.85, accent = "mango", route = "Milestones", icon = "Milestone" },
	Story = { label = "Story", group = "STORY", weight = 0.85, accent = "mint", route = "Story", icon = "Story" },
	Letter = { label = "Letter", group = "MAIL", weight = 0.8, accent = "cyan", route = "Mail", icon = "Mail" },
	Section = { label = "Shop", group = "SHOP", weight = 1.15, accent = "mango", route = "Shop", icon = "Shop" },
	Deal = { label = "Black Market", group = "BLACK MARKET", weight = 1.1, accent = "violet", route = "Bazaar", icon = "Shop" },
}

local function accentOf(key)
	return Palette[key] or Palette.cyan
end

local GameConfig
local SettingsSchema
local function loadData()
	if GameConfig == nil then
		local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
		GameConfig = require(shared:WaitForChild("GameConfig"))
		SettingsSchema = require(shared:WaitForChild("SharedData"))("SettingsSchema")
	end
end

local function authored(entry)
	return type(entry) == "table" and type(entry.Name) == "string" and not string.find(tostring(entry.Id or ""), "^Horizon")
end

-- Static content index, built once per session the first time Quick Find opens.
local staticIndex
local function buildStatic()
	if staticIndex ~= nil then
		return staticIndex
	end
	loadData()
	local list = {}
	local function add(kind, key, title, subtitle, extra, icon, link)
		local meta = KIND_META[kind]
		table.insert(list, {
			key = kind .. ":" .. key,
			kind = kind,
			title = title,
			subtitle = subtitle,
			icon = icon or meta.icon,
			accent = accentOf(meta.accent),
			route = link and link.route or meta.route,
			query = link and link.query or title,
			category = link and link.category or nil,
			fields = { Model.normalize(title), Model.normalize(subtitle or ""), Model.normalize(extra or "") },
		})
	end
	for _, entry in SettingsSchema.ENTRIES do
		local section
		for _, s in SettingsSchema.SECTIONS do
			if s.id == entry.section then
				section = s
			end
		end
		add("Setting", entry.key, entry.label, entry.help, (if section then section.label else "") .. " settings", "Settings", { route = "Settings", query = entry.label })
	end
	for _, machine in GameConfig.Machines or {} do
		if authored(machine) then
			add("Machine", machine.Id, machine.Name, machine.Description, "machine workshop", machine.Icon)
		end
	end
	for _, study in GameConfig.Research or {} do
		if authored(study) then
			add("Research", study.Id, study.Name, study.Description, "research upgrade", "Research")
		end
	end
	local items = GameConfig.Items
	for _, relic in (if items then items.Definitions else nil) or {} do
		if authored(relic) then
			add("Relic", relic.Id, relic.Name, `{relic.Rarity or ""} · {relic.Description or ""}`, `relic {relic.Slot or ""} {relic.Rarity or ""}`)
		end
	end
	for index, zone in GameConfig.Zones or {} do
		if authored(zone) and index <= 24 then
			add("World", tostring(zone.Id), zone.Name, zone.Tagline or zone.Description, "world zone travel")
		end
	end
	for id, boost in GameConfig.Boosts or {} do
		if type(boost) == "table" and type(boost.Name) == "string" then
			add("Boost", tostring(id), boost.Name, boost.Description, "boost potion")
		end
	end
	for _, achievement in GameConfig.Achievements or {} do
		if authored(achievement) then
			add("Milestone", achievement.Id, achievement.Name, achievement.Description, "milestone achievement goal")
		end
	end
	for _, chapter in GameConfig.Story or {} do
		if type(chapter) == "table" and type(chapter.Title) == "string" then
			add("Story", chapter.Id or chapter.Title, chapter.Title, `{chapter.Chapter or ""} · {chapter.Summary or ""}`, "story chapter lore")
		end
	end
	for _, section in {
		{ id = "Daily", title = "Daily shop", body = "Today's rotating offers", words = "deals daily offers rotation", icon = "Calendar" },
		{ id = "Crates", title = "Crates", body = "Open crates with your keys", words = "keys open loot boxes", icon = "Crate" },
		{ id = "Skins", title = "Crate skins", body = "Change how your crates look", words = "cosmetics skins looks", icon = "Crate" },
		{ id = "Codex", title = "Relic codex", body = "Every relic, fusing and stars", words = "collection codex fuse stars relics", icon = "Artifact" },
		{ id = "Premium", title = "Premium shop", body = "Packs, passes and codes", words = "robux gamepass passes packs codes redeem", icon = "Shop" },
	} do
		add("Section", section.id, section.title, section.body, section.words, section.icon, { route = "Shop", query = "", category = section.id })
	end
	for _, deal in {
		{ id = "Resources", title = "Market resources", body = "Stardust, cores, essence and fragments", words = "materials supplies stock", icon = "Dust" },
		{ id = "Keys", title = "Market keys", body = "Keys from Forge to Echo", words = "keys crates shipment", icon = "Crate" },
		{ id = "Boosts", title = "Market boosts", body = "Production cells and upgrades", words = "boosts power overdrive", icon = "Boost" },
		{ id = "Command", title = "Command supplies", body = "Signals, field notes and streak shields", words = "command experience signals crew", icon = "Mission" },
	} do
		add("Deal", deal.id, deal.title, deal.body, deal.words, deal.icon, { route = "Bazaar", query = "", category = deal.id })
	end
	for _, letter in GameConfig.Mail or {} do
		if type(letter) == "table" and type(letter.Subject) == "string" then
			add("Letter", letter.Id or letter.Subject, letter.Subject, `From {letter.Sender or "the forge"}`, "mail letter inbox")
		end
	end
	staticIndex = list
	return list
end

-- Pages and actions depend on the player (locks, admin, badges), so they rebuild per open.
local function buildLive(state, chatUnread)
	local list = {}
	local routes = {}
	for _, route in NavRoutes.PRIMARY_ROUTES do
		table.insert(routes, route)
	end
	for _, route in NavRoutes.MORE_ROUTES do
		table.insert(routes, route)
	end
	local groupLabel = {}
	for _, group in NavRoutes.NAV_GROUPS do
		for _, id in group.routes do
			groupLabel[id] = group.label
		end
	end
	for order, route in routes do
		if route.id == "Admin" and not (state.Admin and state.Admin.Access == true) then
			continue
		end
		local lock = state.FeatureUnlocks and state.FeatureUnlocks[route.id]
		local locked = route.id ~= "Trade" and lock ~= nil and lock.Unlocked == false
		local badge = 0
		local ok, value = pcall(function()
			return AppHelpers:navBadge(route, state, chatUnread or 0)
		end)
		if ok and type(value) == "number" then
			badge = value
		end
		table.insert(list, {
			key = "Page:" .. route.id,
			kind = "Page",
			title = route.label,
			subtitle = if locked
				then `Locked · {lock.Requirement or (if lock.Level then "Level " .. lock.Level else "not open yet")}`
				else `{groupLabel[route.id] or "Page"} · {route.eyebrow}`,
			icon = route.icon,
			accent = accentOf(route.accentKey),
			route = route.id,
			locked = locked,
			badge = badge,
			order = order,
			fields = { Model.normalize(route.label), Model.normalize(route.eyebrow .. " " .. (groupLabel[route.id] or "")), Model.normalize((PAGE_WORDS[route.id] or "") .. " " .. route.id) },
		})
	end
	local function action(id, title, subtitle, icon, words, run)
		table.insert(list, {
			key = "Action:" .. id,
			kind = "Action",
			title = title,
			subtitle = subtitle,
			icon = icon,
			accent = Palette.mint,
			run = run,
			fields = { Model.normalize(title), Model.normalize(subtitle), Model.normalize(words) },
		})
	end
	action("Collect", "Collect vault", "Bank everything your machines made", "Vault", "collect bank vault cash flux claim", "CollectVault")
	action("Tour", "Replay the tour", "Walk through the basics again", "Guide", "tutorial help guide tour how to play", "ReplayTutorial")
	action("Notes", "Patch notes", "See what changed in this update", "Gift", "update changes news release version", "OpenRelease")
	return list
end

local RunService = game:GetService("RunService")
local WHITE_HOT = Color3.fromRGB(255, 244, 222)
local MAX_RESULTS = 40
local ROW_H = 52
local HEADER_H = 28
local ROW_GAP = 2
local CASCADE_ROWS = 14

local function easeOut(t)
	local u = 1 - math.clamp(t, 0, 1)
	return 1 - u * u * u
end

-- y of every row inside the list (headers, rows and the gap between them)
local function rowOffsets(sections)
	local ys = {}
	local y = 0
	local index = 0
	for s, section in sections do
		if s > 1 then
			y += ROW_GAP
		end
		y += HEADER_H + ROW_GAP
		for r in section.entries do
			index += 1
			if r > 1 then
				y += ROW_GAP
			end
			ys[index] = y
			y += ROW_H
		end
	end
	return ys, y
end
QuickFind.rowOffsets = rowOffsets

local function Row(props)
	local entry = props.entry
	local meta = KIND_META[entry.kind]
	local appearAt = props.appearAt
	local arrive = props.tick:map(function(now)
		return if appearAt == nil then 1 else easeOut((now - appearAt) / 0.24)
	end)
	local selected = props.selected
	return h("textbutton", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 504,
		Event = {
			Activated = function()
				props.onPick(entry)
			end,
			MouseEnter = function()
				props.onHover(props.index)
			end,
		},
	}, h("frame", {
		-- everything in the row rides in together
		Size = UDim2.fromScale(1, 1),
		Position = arrive:map(function(a)
			return UDim2.fromOffset((1 - a) * 14, 0)
		end),
		BackgroundTransparency = 1,
		ZIndex = 504,
	}, h("frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.darken(entry.accent, 0.62),
		BackgroundTransparency = arrive:map(function(a)
			return 1 - a
		end),
		BorderSizePixel = 0,
		ZIndex = 505,
	}, h("uicorner", { CornerRadius = UDim.new(0, 9) }), h("uiscale", {
		Scale = props.tick:map(function(now)
			if not selected then
				return 1
			end
			return 1 + math.sin(now * 5) * 0.035
		end),
	}), h("frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 506,
	}, h(Icon, {
		kind = if entry.locked then "Lock" else entry.icon,
		color = if entry.locked then Palette.muted else entry.accent,
		accent = entry.accent,
		size = 20,
		spin = false,
	}))), h("textlabel", {
		Size = UDim2.new(1, -(60 + props.rightW), 0, 20),
		Position = UDim2.fromOffset(58, 7),
		BackgroundTransparency = 1,
		Text = Model.highlight(entry.title, props.query, "#" .. entry.accent:ToHex()),
		RichText = true,
		TextSize = 15,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3 = if entry.locked then Palette.creamSoft elseif selected then WHITE_HOT else Palette.cream,
		TextTransparency = arrive:map(function(a)
			return 1 - a
		end),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 506,
	}), h("textlabel", {
		Size = UDim2.new(1, -(60 + props.rightW), 0, 16),
		Position = UDim2.fromOffset(58, 28),
		BackgroundTransparency = 1,
		Text = entry.subtitle or "",
		TextSize = 12,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3 = Palette.muted,
		TextTransparency = arrive:map(function(a)
			return 1 - a
		end),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 506,
	}), props.rightW > 0 and h("frame", {
		Size = UDim2.fromOffset(props.rightW - 12, 22),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 506,
	}, h("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), (entry.badge or 0) > 0 and h("textlabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		BackgroundColor3 = Palette.mango,
		Text = tostring(entry.badge),
		TextSize = 11,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3 = Palette.ink,
		ZIndex = 507,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })), h("textlabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Text = meta.label,
		TextSize = 12,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3 = if selected then entry.accent else Palette.muted,
		TextTransparency = arrive:map(function(a)
			return 1 - a
		end),
		ZIndex = 507,
	}))))
end

-- a section title with a rule that draws itself out to the right
local function Header(props)
	local appearAt = props.appearAt
	local arrive = props.tick:map(function(now)
		return if appearAt == nil then 1 else easeOut((now - appearAt) / 0.4)
	end)
	return h("frame", {
		Size = UDim2.new(1, 0, 0, HEADER_H),
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		ZIndex = 503,
	}, h("textlabel", {
		Size = UDim2.new(0, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0, 12, 1, -8),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Text = props.text,
		TextSize = 11,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3 = Palette.mango,
		TextTransparency = arrive:map(function(a)
			return 1 - a
		end),
		ZIndex = 504,
	}), h("frame", {
		Size = arrive:map(function(a)
			return UDim2.new(a, -(24 + props.labelW), 0, 1)
		end),
		Position = UDim2.new(0, 20 + props.labelW, 1, -14),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 504,
	}))
end

function QuickFind.QuickFind(props)
	local state = props.state
	local open, setOpen = React.useState(false)
	local query, setQuery = React.useState("")
	local selected, setSelected = React.useState(1)
	local boxRef = React.useRef(nil)
	local listRef = React.useRef(nil)
	local viewport = useViewport()
	local reduced = props.reducedMotion == true
	local show = useFlipperSpring(if open then 1 else 0, reduced, 420, 30)
	local enabled = props.enabled ~= false
	local tick, setTick = React.useBinding(os.clock())
	-- when the current results arrived (rows cascade from here) and when a row was picked
	local resultsAt = React.useRef(os.clock())
	local pickedAt = React.useRef(-10)

	local close = React.useCallback(function()
		setOpen(false)
		local box = boxRef.current
		if box ~= nil then
			box:ReleaseFocus()
		end
	end, {})

	React.useEffect(function()
		local function request()
			if enabled then
				setQuery("")
				setSelected(1)
				resultsAt.current = os.clock() + 0.12
				setOpen(true)
				Audio:play("open")
			end
		end
		table.insert(openers, request)
		return function()
			local at = table.find(openers, request)
			if at ~= nil then
				table.remove(openers, at)
			end
		end
	end, { enabled })

	React.useEffect(function()
		if not enabled and open then
			setOpen(false)
		end
	end, { enabled })

	-- one clock while it is on screen (and a little after, for the fold-away)
	React.useEffect(function()
		local closingUntil = os.clock() + 0.6
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			setTick(now)
			if not open and now > closingUntil then
				connection:Disconnect()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { open })

	-- keyboard: Ctrl+K opens, Escape closes, arrows move, Enter picks
	local resultsRef = React.useRef({})
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local key = input.KeyCode
			if not open then
				if not enabled or UserInputService:GetFocusedTextBox() ~= nil then
					return
				end
				local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
					or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta) or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
				-- "/" belongs to Roblox chat, so only Ctrl/Cmd+K opens it from the keyboard
				if key == Enum.KeyCode.K and ctrl then
					QuickFind.open()
				end
				return
			end
			if key == Enum.KeyCode.Escape then
				close()
				Audio:play("close")
			elseif key == Enum.KeyCode.Down then
				Audio:play("tick")
				setSelected(function(current)
					return math.min(#resultsRef.current, current + 1)
				end)
			elseif key == Enum.KeyCode.Up then
				Audio:play("tick")
				setSelected(function(current)
					return math.max(1, current - 1)
				end)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { open, enabled })

	React.useEffect(function()
		if not open then
			return nil
		end
		local job = task.defer(function()
			local box = boxRef.current
			if box ~= nil and box.Parent ~= nil then
				box:CaptureFocus()
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { open })

	-- build and rank
	local sections = {}
	local flat = {}
	local totalMatches = 0
	if open then
		local live = buildLive(state, props.chatUnread)
		local byKey = {}
		for _, entry in live do
			byKey[entry.key] = entry
		end
		local static = buildStatic()
		for _, entry in static do
			byKey[entry.key] = entry
		end
		local tokens = Model.tokens(query)
		if #tokens == 0 then
			local okReady, ready = pcall(ReadyBoard.collect, state, GameConfig)
			if okReady and #ready > 0 then
				local items = {}
				for _, entry in ready do
					local page = byKey["Page:" .. entry.route]
					if page ~= nil then
						table.insert(items, {
							key = page.key,
							kind = "Page",
							title = entry.label,
							subtitle = entry.detail,
							icon = entry.icon,
							accent = entry.accent,
							route = entry.route,
							badge = entry.count,
							fields = page.fields,
						})
					end
				end
				table.insert(sections, { title = "READY NOW", entries = items })
			end
			local recent = {}
			for _, key in Model.recent() do
				if byKey[key] ~= nil then
					table.insert(recent, byKey[key])
				end
			end
			if #recent > 0 then
				table.insert(sections, { title = "RECENT", entries = recent })
			end
			local pages = {}
			for _, entry in live do
				if entry.kind == "Page" and not entry.locked then
					table.insert(pages, entry)
				end
			end
			table.sort(pages, function(a, b)
				if (a.badge or 0) > 0 ~= ((b.badge or 0) > 0) then
					return (a.badge or 0) > 0
				end
				return a.order < b.order
			end)
			table.insert(sections, { title = "JUMP TO", entries = pages })
		else
			local scored = {}
			local function consider(entry)
				local value = Model.score(tokens, entry.fields)
				if value > 0 then
					local weight = KIND_META[entry.kind].weight * (if entry.locked then 0.6 else 1)
					table.insert(scored, { entry = entry, score = value * weight })
				end
			end
			for _, entry in live do
				consider(entry)
			end
			for _, entry in static do
				consider(entry)
			end
			table.sort(scored, function(a, b)
				if a.score ~= b.score then
					return a.score > b.score
				end
				return a.entry.title < b.entry.title
			end)
			totalMatches = #scored
			-- best match first, then the rest grouped by what they are
			local byKind, kinds = {}, {}
			for i = 1, math.min(MAX_RESULTS, #scored) do
				local entry = scored[i].entry
				if i == 1 then
					table.insert(sections, { title = "BEST MATCH", entries = { entry } })
				else
					local label = KIND_META[entry.kind].group
					if byKind[label] == nil then
						byKind[label] = { title = label, entries = {} }
						table.insert(kinds, byKind[label])
					end
					table.insert(byKind[label].entries, entry)
				end
			end
			for _, section in kinds do
				table.insert(sections, section)
			end
		end
		for _, section in sections do
			for _, entry in section.entries do
				table.insert(flat, entry)
			end
		end
	end
	resultsRef.current = flat
	local pickIndex = math.clamp(selected, 1, math.max(1, #flat))
	local rowYs, listHeight = rowOffsets(sections)

	-- a new set of results cascades in
	local signature = query .. "#" .. tostring(#flat)
	local lastSignature = React.useRef(signature)
	if lastSignature.current ~= signature then
		lastSignature.current = signature
		resultsAt.current = os.clock()
	end

	local pick = function(entry)
		if entry == nil then
			return
		end
		pickedAt.current = os.clock()
		Model.pushRecent(entry.key)
		close()
		if entry.kind == "Action" then
			Audio:play("confirm")
			props.dispatch(entry.run)
			return
		end
		if entry.kind ~= "Page" and entry.route ~= nil then
			Model.link(entry.route, { query = entry.query or entry.title, category = entry.category })
		end
		props.navigate(entry.route)
	end

	-- keep the highlighted row in view while arrowing
	React.useEffect(function()
		local list = listRef.current
		local top = rowYs[pickIndex]
		if list == nil or not open or top == nil then
			return
		end
		local bottom = top + ROW_H
		local view = list.AbsoluteWindowSize.Y
		if top - HEADER_H < list.CanvasPosition.Y then
			list.CanvasPosition = Vector2.new(0, math.max(0, top - HEADER_H))
		elseif bottom > list.CanvasPosition.Y + view then
			list.CanvasPosition = Vector2.new(0, bottom - view)
		end
	end, { pickIndex, open, query })

	-- the selection slab glides to the highlighted row
	local slabY = useFlipperSpring(rowYs[pickIndex] or 0, reduced, 760, 44)
	local slabAccent = (flat[pickIndex] and flat[pickIndex].accent) or Palette.mango

	local rows = {
		layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ROW_GAP),
		}),
	}
	local order = 0
	local index = 0
	local width = math.min(680, viewport.width - 24)
	local rightW = if width >= 520 then 120 else 0
	local cascadeFrom = if reduced then nil else resultsAt.current
	for s, section in sections do
		order += 1
		local labelW = 0
		pcall(function()
			labelW = game:GetService("TextService"):GetTextSize(section.title, 11, Enum.Font.BuilderSansExtraBold, Vector2.new(400, 20)).X
		end)
		rows["h" .. s] = h(Header, {
			text = section.title,
			labelW = labelW,
			layoutOrder = order,
			tick = tick,
			appearAt = if cascadeFrom then cascadeFrom + math.min(index, CASCADE_ROWS) * 0.02 else nil,
		})
		for _, entry in section.entries do
			order += 1
			index += 1
			local rowIndex = index
			rows[entry.key .. "#" .. s] = h(Row, {
				entry = entry,
				selected = rowIndex == pickIndex,
				index = rowIndex,
				rightW = rightW,
				query = query,
				layoutOrder = order,
				onPick = pick,
				onHover = setSelected,
				tick = tick,
				appearAt = if cascadeFrom and rowIndex <= CASCADE_ROWS then cascadeFrom + rowIndex * 0.022 else nil,
			})
		end
	end

	local empty = open and #flat == 0 and h("frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		ZIndex = 503,
	}, h("textlabel", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 26),
		BackgroundTransparency = 1,
		Text = `Nothing matches "{query}"`,
		TextSize = 16,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3 = Palette.cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 504,
	}), h("textlabel", {
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 52),
		BackgroundTransparency = 1,
		Text = "Search works on page names, settings, relics, machines and research. Try \"music\", \"vault\" or a relic's name.",
		TextSize = 13,
		TextWrapped = true,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3 = Palette.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 504,
	}))

	local inset = GuiService:GetGuiInset()
	local height = math.min(560, viewport.height - inset.Y - 48)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	-- the seam ignites first, then the panel unfolds down out of it
	local seam = show:map(function(amount)
		return math.clamp(amount * 1.8, 0, 1)
	end)
	local unfold = show:map(function(amount)
		return math.clamp((amount - 0.3) / 0.7, 0, 1)
	end)
	local shownCount = React.useRef(0)
	local countText = tick:map(function()
		local target = if query == "" then #flat else totalMatches
		shownCount.current += (target - shownCount.current) * 0.35
		if math.abs(target - shownCount.current) < 0.5 then
			shownCount.current = target
		end
		if query == "" then
			return ""
		end
		local n = math.floor(shownCount.current + 0.5)
		return `{n} found`
	end)
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = show:map(function(amount)
			return amount > 0.01
		end),
		ZIndex = 500,
	}, h("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = show:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.5
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Active = open,
		ZIndex = 500,
		Event = {
			Activated = function()
				close()
				Audio:play("close")
			end,
		},
	}), h("frame", {
		-- the seam: a molten line the palette opens out of
		Size = seam:map(function(a)
			return UDim2.fromOffset(width * a, 2)
		end),
		Position = UDim2.new(0.5, 0, 0, inset.Y + 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = show:map(function(amount)
			return 1 - math.clamp(amount * 2, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 510,
	}, h("uigradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.ember),
			ColorSequenceKeypoint.new(0.5, WHITE_HOT),
			ColorSequenceKeypoint.new(1, Palette.ember),
		}),
		Offset = tick:map(function(now)
			return Vector2.new(math.sin(now * 1.7) * 0.35, 0)
		end),
	})), h("frame", {
		Name = "QuickFind",
		Size = unfold:map(function(a)
			return UDim2.fromOffset(width, math.max(2, height * a))
		end),
		Position = UDim2.new(0.5, 0, 0, inset.Y + 24),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 501,
		ClipsDescendants = true,
	}, h("uicorner", { CornerRadius = UDim.new(0, 16) }), h("uistroke", {
		Color = Palette.lineSoft,
		Transparency = 0.3,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = 502,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = tick:map(function(now)
			return 0.55 + math.sin(now * 2.2) * 0.15
		end),
	}), h("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 503,
	}, h(Icon, { kind = "Search", color = Palette.mango, accent = Palette.mango, size = 22, spin = false })), h("textbox", {
		ref = boxRef,
		Size = UDim2.new(1, -(48 + (if touch then 52 else 70) + 80), 1, 0),
		Position = UDim2.fromOffset(46, 0),
		BackgroundTransparency = 1,
		Text = query,
		PlaceholderText = "Pages, settings, relics, machines…",
		PlaceholderColor3 = Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 17,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 503,
		Change = {
			Text = function(box)
				if box.Text ~= query then
					if box:IsFocused() and #box.Text > #query then
						Audio:play("searchType")
						-- every keypress throws a spark off the end of the text
						if not reduced then
							pcall(function()
								local Juice = require(script.Parent.JuiceFx)
								local at = box.AbsolutePosition + Vector2.new(math.min(box.TextBounds.X, box.AbsoluteSize.X) + 2, box.AbsoluteSize.Y / 2)
								Juice.spark(at, Palette.mango, 9 + math.random() * 5)
							end)
						end
					end
					setQuery(box.Text)
					setSelected(1)
				end
			end,
		},
		Event = {
			FocusLost = function(_box, enterPressed)
				if enterPressed and open then
					pick(resultsRef.current[pickIndex])
				end
			end,
		},
	}), h("textlabel", {
		Size = UDim2.fromOffset(76, 30),
		Position = UDim2.new(1, -(if touch then 60 else 76), 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Text = countText,
		TextSize = 12,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3 = Palette.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 503,
	}), h("textbutton", {
		Size = UDim2.fromOffset(if touch then 44 else 58, 30),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = if touch then "Close" else "Esc",
		TextSize = 12,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3 = Palette.muted,
		ZIndex = 503,
		Event = {
			Activated = function()
				close()
				Audio:play("close")
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 8) }))), h("scrollingframe", {
		ref = listRef,
		Size = UDim2.new(1, -16, 1, -(74 + (if touch then 8 else 30))),
		Position = UDim2.fromOffset(8, 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, if #flat == 0 then 120 else listHeight + 6),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 502,
	}, #flat > 0 and h("frame", {
		-- the selection slab: one plate that glides between rows, its edge glowing in the row's colour
		Size = UDim2.new(1, -4, 0, ROW_H),
		Position = slabY:map(function(y)
			return UDim2.fromOffset(0, y)
		end),
		BackgroundColor3 = tick:map(function(now)
			local flash = 1 - math.clamp((now - pickedAt.current) / 0.25, 0, 1)
			return Palette.panelRaised:Lerp(WHITE_HOT, flash * 0.7)
		end),
		BorderSizePixel = 0,
		ZIndex = 502,
	}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", {
		Color = slabAccent,
		Transparency = 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = slabAccent,
		BorderSizePixel = 0,
		ZIndex = 504,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
		Rotation = 90,
		Color = ColorSequence.new(slabAccent, WHITE_HOT),
		Offset = tick:map(function(now)
			return Vector2.new(0, math.sin(now * 3) * 0.4)
		end),
	}))), h("frame", {
		Size = UDim2.new(1, 0, 0, if #flat == 0 then 120 else listHeight),
		BackgroundTransparency = 1,
		ZIndex = 504,
	}, rows, empty)), not touch and h("textlabel", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.new(0, 12, 1, -26),
		BackgroundTransparency = 1,
		Text = "Up and Down to move  ·  Enter to open  ·  Ctrl+K from anywhere",
		TextSize = 12,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3 = Palette.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 502,
	})))
end

return QuickFind
