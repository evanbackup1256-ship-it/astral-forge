--!nocheck
-- Shared browsing UI for every list page: one hook (search + category + sort, remembered
-- per page for the session) and one bar (search field, sort menu, category chips with live
-- counts). The matching rules live in BrowseModel so Lune can test them.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Model = require(script.Parent.BrowseModel)
local ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon

local Palette = theme.Palette
local TapTarget = theme.TapTarget
local h = React.createElement

local Kit = { Model = Model }

Kit.CHIP_H = 32
Kit.ROW_GAP = 8

-- Normalized fields are cached per item table, so typing stays cheap on long lists.
-- Snapshots replace item tables when data changes, which naturally invalidates the cache.
local fieldCache = setmetatable({}, { __mode = "k" })
local function cachedFields(text, key)
	return function(item)
		if type(item) ~= "table" then
			return Model.fieldsOf(item, text)
		end
		local cached = fieldCache[item]
		if cached ~= nil and cached.key == key then
			return cached.fields
		end
		local fields = Model.fieldsOf(item, text)
		fieldCache[item] = { key = key, fields = fields }
		return fields
	end
end

--[[
	config = {
		id = "Boosts",                       -- remembers the choices for this page
		items = { ... },
		text = function(item) return { item.Name, item.Desc } end,
		categories = { { id = "All", label = "All" }, { id = "Ready", label = "Ready", test = fn } },
		sorts = { { id = "Default", label = "Recommended" }, { id = "Name", label = "A to Z", compare = fn } },
	}
]]
function Kit.useBrowse(config)
	local saved = if config.id then Model.recall(config.id) else nil
	local categories = config.categories
	local sorts = config.sorts
	local firstCategory = if categories and categories[1] then categories[1].id else "All"
	local firstSort = if sorts and sorts[1] then sorts[1].id else nil
	local query, setQuery = React.useState(if saved then saved.query else (config.initialQuery or ""))
	local category, setCategory = React.useState(if saved and saved.category then saved.category else (config.initialCategory or firstCategory))
	local sort, setSort = React.useState(if saved and saved.sort then saved.sort else (config.initialSort or firstSort))
	-- a category that disappeared (data changed) falls back to the first one
	if categories ~= nil and Model.findById(categories, category) == nil then
		category = firstCategory
	end
	if sorts ~= nil and Model.findById(sorts, sort) == nil then
		sort = firstSort
	end
	React.useEffect(function()
		if config.id then
			Model.remember(config.id, { query = query, category = category, sort = sort })
		end
	end, { query, category, sort })
	React.useEffect(function()
		if not config.id then
			return nil
		end
		return Model.listen(config.id, function(entry)
			setQuery(entry.query or "")
			setCategory(entry.category or firstCategory)
			if entry.sort then
				setSort(entry.sort)
			end
		end)
	end, { config.id, firstCategory })
	-- `id` keys the cache; pages whose searchable text depends on more than the item pass `textKey`
	local fieldsFn = React.useMemo(function()
		return cachedFields(config.text, (config.id or "") .. "|" .. tostring(config.textKey or ""))
	end, { config.text, config.textKey })
	local result = Model.run(config.items or {}, {
		fields = fieldsFn,
		categories = categories,
		sorts = sorts,
		aliases = config.aliases,
	}, query, category, sort)
	local browse = {
		query = query,
		setQuery = setQuery,
		category = category,
		setCategory = function(id)
			if id ~= category then
				Audio:play("tabSwitch")
			end
			setCategory(id)
		end,
		sort = sort,
		setSort = setSort,
		categories = categories,
		sorts = sorts,
		results = result.results,
		counts = result.counts,
		matched = result.matched,
		total = result.total,
		relevance = result.relevance,
		searching = query ~= "",
		filtered = query ~= "" or category ~= firstCategory,
		firstCategory = firstCategory,
	}
	browse.reset = function()
		setQuery("")
		setCategory(firstCategory)
	end
	browse.label = function(id)
		local entry = Model.findById(categories, id or category)
		return if entry then entry.label else ""
	end
	return browse
end

-- For pages with their own filter logic: a search string that is remembered per page and
-- that Quick Find deep links fill in. Returns query, setQuery like useState.
function Kit.useLinkedQuery(id, initial)
	local saved = Model.recall(id)
	local query, setQuery = React.useState(if saved then saved.query else (initial or ""))
	React.useEffect(function()
		local previous = Model.recall(id)
		Model.remember(id, { query = query, category = if previous then previous.category else nil, sort = if previous then previous.sort else nil })
	end, { query })
	React.useEffect(function()
		return Model.listen(id, function(entry)
			setQuery(entry.query or "")
		end)
	end, { id })
	return query, setQuery
end

-- A tab that Quick Find can open directly (links carry the tab id as `category`).
-- An explicit `preferred` tab (a prop from the caller) wins over the last linked one.
function Kit.useLinkedTab(id, fallback, preferred)
	local linked = Model.recall(id)
	local tab, setTab = React.useState(preferred or (linked and linked.category) or fallback)
	React.useEffect(function()
		return Model.listen(id, function(entry)
			if entry.category ~= nil then
				setTab(entry.category)
			end
		end)
	end, { id })
	return tab, setTab
end

-- True when `query` fuzzily matches any of the given strings (for pages with custom filters).
function Kit.matches(query, ...)
	if query == nil or string.match(query, "^%s*$") then
		return true
	end
	local fields = {}
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if value ~= nil then
			table.insert(fields, Model.normalize(value))
		end
	end
	return Model.score(query, fields) > 0
end

-- Server time that re-renders every `period` seconds (countdowns to UTC resets and deadlines).
function Kit.useServerNow(period)
	local now, setNow = React.useState(function()
		return workspace:GetServerTimeNow()
	end)
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(period or 1)
				if alive then
					setNow(workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, { period })
	return now
end

-- Seconds until the next UTC midnight, when dailies, missions and playtime drops reset.
function Kit.untilUtcReset(now)
	return 86400 - (math.floor(now) % 86400)
end

function Kit.shortDuration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	elseif minutes > 0 then
		return `{minutes}m {seconds % 60}s`
	end
	return `{seconds}s`
end

function Kit.barHeight(stack, hasChips)
	local row = if stack then TapTarget else 40
	return row + (if hasChips then Kit.ROW_GAP + Kit.CHIP_H else 0)
end

local function Chip(props)
	local hovered, setHovered = React.useState(false)
	local selected = props.selected
	local accent = props.accent
	local count = props.count
	local empty = count ~= nil and count == 0 and not selected
	return h("textbutton", {
		Size = UDim2.fromOffset(0, Kit.CHIP_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if selected then accent elseif hovered then Palette.panelRaised else Palette.panelSoft,
		BackgroundTransparency = if selected then 0.05 elseif empty then 0.5 else 0.15,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		Event = {
			Activated = function()
				props.onSelect(props.id)
			end,
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if selected then theme.lighten(accent, 0.25) else Palette.lineSoft,
		Transparency = if selected then 0.2 else 0.55,
		Thickness = 1,
	}), h("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, if count ~= nil then 6 else 12),
	}), h("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}), props.icon and h("frame", {
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		ZIndex = props.zIndex + 1,
	}, h(Icon, {
		kind = props.icon,
		color = if selected then Palette.ink else Palette.creamSoft,
		accent = accent,
		size = 16,
		spin = false,
	})), h("textlabel", {
		Size = UDim2.fromOffset(0, Kit.CHIP_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = props.label,
		TextSize = 13,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans, if selected then Enum.FontWeight.Heavy else Enum.FontWeight.Bold),
		TextColor3 = if selected then Palette.ink elseif empty then Palette.muted else Palette.creamSoft,
		LayoutOrder = 1,
		ZIndex = props.zIndex + 1,
	}), count ~= nil and h("frame", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if selected then Palette.ink else Palette.ink,
		BackgroundTransparency = if selected then 0.55 else 0.35,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = props.zIndex + 1,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", {
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
	}), h("textlabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = tostring(count),
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans, Enum.FontWeight.Bold),
		TextColor3 = if selected then Palette.cream else Palette.muted,
		ZIndex = props.zIndex + 2,
	})))
end
Kit.Chip = Chip

-- Horizontally scrolling category chips; `counts` adds a live tally to each chip.
function Kit.ChipRow(props)
	local children = {
		layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}
	local zIndex = props.zIndex or 6
	for index, entry in props.options or {} do
		children[entry.id] = h(Chip, {
			id = entry.id,
			label = entry.label,
			icon = entry.icon,
			count = if props.counts then props.counts[entry.id] else nil,
			selected = entry.id == props.value,
			accent = entry.accent or props.accent or Palette.cyan,
			onSelect = props.onChange,
			layoutOrder = index,
			zIndex = zIndex,
		})
	end
	return h("scrollingframe", {
		Size = props.size or UDim2.new(1, 0, 0, Kit.CHIP_H),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		ZIndex = zIndex,
	}, children)
end

--[[
	The browse bar: search + sort on the first row, category chips on the second.
	props: browse (from useBrowse), placeholder, accent, stack, reducedMotion, position, zIndex,
	       extra (an element placed right of the search on wide screens, e.g. a toggle)
]]
function Kit.BrowseBar(props)
	local browse = props.browse
	local stack = props.stack == true
	local accent = props.accent or Palette.cyan
	local zIndex = props.zIndex or 30
	local rowH = if stack then TapTarget else 40
	local hasSorts = browse.sorts ~= nil and #browse.sorts > 1
	local hasChips = browse.categories ~= nil and #browse.categories > 1
	local sortW = if not hasSorts then 0 elseif stack then 128 else 184
	local countW = if stack or not hasChips then 0 else 124
	local summary = if browse.filtered
		then `{#browse.results} of {browse.total}`
		else `{browse.total} total`
	return h("frame", {
		Size = props.size or UDim2.new(1, 0, 0, Kit.barHeight(stack, hasChips)),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = zIndex,
	}, h(ui.SearchField, {
		value = browse.query,
		onChange = browse.setQuery,
		placeholder = props.placeholder or "Search",
		accent = accent,
		reducedMotion = props.reducedMotion,
		position = UDim2.fromOffset(0, 0),
		size = UDim2.new(1, -(sortW + (if sortW > 0 then 8 else 0)), 0, rowH),
		zIndex = zIndex + 2,
	}), hasSorts and h(ui.Dropdown, {
		options = browse.sorts,
		value = browse.sort,
		onChange = browse.setSort,
		accent = accent,
		label = if stack then nil else "Sort",
		reducedMotion = props.reducedMotion,
		position = UDim2.new(1, -sortW, 0, 0),
		size = UDim2.fromOffset(sortW, rowH),
		zIndex = zIndex + 14,
	}), hasChips and h(Kit.ChipRow, {
		options = browse.categories,
		value = browse.category,
		onChange = browse.setCategory,
		counts = browse.counts,
		accent = accent,
		position = UDim2.fromOffset(0, rowH + Kit.ROW_GAP),
		size = UDim2.new(1, -countW, 0, Kit.CHIP_H),
		zIndex = zIndex + 1,
	}), countW > 0 and h("textbutton", {
		Size = UDim2.fromOffset(countW - 8, Kit.CHIP_H),
		Position = UDim2.new(1, 0, 0, rowH + Kit.ROW_GAP),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = if browse.filtered then `{summary} · <u>Clear</u>` else summary,
		RichText = true,
		TextSize = 13,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans, Enum.FontWeight.Bold),
		TextColor3 = if browse.filtered then accent else Palette.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Selectable = browse.filtered,
		Active = browse.filtered,
		ZIndex = zIndex + 1,
		Event = {
			Activated = function()
				if browse.filtered then
					Audio:play("close")
					browse.reset()
				end
			end,
		},
	}))
end

-- Shown when a filter leaves nothing; offers the fix instead of a dead end.
function Kit.NoResults(props)
	local browse = props.browse
	local noun = props.noun or "items"
	local title, body
	if browse.total == 0 then
		title = props.emptyTitle or `No {noun} yet`
		body = props.emptyBody or "They will show up here."
	elseif browse.searching and browse.matched == 0 then
		title = `Nothing matches "{browse.query}"`
		body = "Check the spelling or try a shorter word."
	elseif browse.searching then
		title = `No {string.lower(browse.label())} {noun} match "{browse.query}"`
		body = `{browse.matched} found in other categories.`
	else
		title = props.filteredTitle or `No {string.lower(browse.label())} {noun}`
		body = props.filteredBody or "Try another category."
	end
	local canClear = browse.total > 0 and browse.filtered
	return h("frame", {
		Size = props.size or UDim2.new(1, 0, 0, 200),
		Position = props.position,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, h(ui.EmptyState, {
		icon = props.icon or "Search",
		title = title,
		body = body,
		accent = props.accent,
		reducedMotion = props.reducedMotion,
		compact = props.compact,
		size = UDim2.new(1, 0, 1, if canClear then -52 else 0),
	}), canClear and h("frame", {
		Size = UDim2.fromOffset(200, 44),
		Position = UDim2.new(0.5, 0, 1, -48),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	}, h(ui.Button, {
		text = if browse.searching and browse.matched > 0 then "Show all matches" else "Clear filters",
		icon = "Search",
		color = Palette.panelRaised,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = props.reducedMotion,
		onClick = function()
			if browse.searching and browse.matched > 0 then
				browse.setCategory(browse.firstCategory)
			else
				browse.reset()
			end
		end,
	})))
end

return Kit
