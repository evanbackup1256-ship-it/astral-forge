local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Omega = require("../out/Shared/AstralForge/Shared/OmegaMath")
local source = fs.readFile("src/Client/AstralForge/pages/PagesBazaar.luau"):gsub("\r\n", "\n")
local helpersStart = assert(source:find("local function orderTotal", 1, true))
local helpersEnd = assert(source:find("local function BazaarView", helpersStart, true))
local Format = {
	log10Flux = Omega.Log10,
	compareFlux = function(a, b) return if Omega.Gt(a, b) then 1 elseif Omega.Gt(b, a) then -1 else 0 end,
	gteFlux = Omega.Gte,
	compactNumber = tostring,
	formatReward = function(reward)
		local text = {}
		for kind, amount in reward do table.insert(text, kind .. " " .. tostring(amount)) end
		return table.concat(text, ", ")
	end,
	clockText = tostring,
}
local env = setmetatable({ Format = Format }, { __index = _G })
local helpers = luau.load(source:sub(helpersStart, helpersEnd - 1) .. "\nreturn { total = orderTotal, unit = supplyUnit }", { environment = env })()
assert(helpers.total(1000, 3) == 3000)
assert(Omega.Gt(helpers.total("1e400", 3), "2.99e400"))
assert(Omega.Gte(helpers.total("1e400", 0.1), "1e399"))
assert(helpers.unit({ Stardust = 40 }) == "Stardust")
local id, amount = helpers.unit({ Keys = { ForgeCrate = 3 } })
assert(id == "Keys:ForgeCrate" and amount == 3)
assert(helpers.unit({ Boost = "Overdrive" }) ~= helpers.unit({ Boost = "Hyperdrive" }))
assert(helpers.unit({ Keys = { ForgeCrate = 1 } }) ~= helpers.unit({ Keys = { EchoCrate = 1 } }))
assert(helpers.unit({ Stardust = 20, Keys = { ForgeCrate = 2 } }) == nil, "mixed kits must not advertise misleading unit comparisons")

local function node(kind, props, ...)
	return { kind = kind, props = props, children = { ... } }
end
local function render(width, inspected, offers)
	local hook = 0
	local palette = setmetatable({}, { __index = function() return roblox.Color3.new(0.5, 0.5, 0.5) end })
	local environment = setmetatable({
		h = node, Palette = palette, Format = Format,
		Ui = setmetatable({ useSegmentedHeight = function(count, cols, rowH, gap) local rows = math.ceil(count / cols); return rows * rowH + (rows - 1) * gap end }, { __index = function(_, key) return key end }),
		React = {
			createElement = node,
			useState = function(initial)
				hook += 1
				return if hook == 3 then inspected elseif hook == 6 then width else initial, function() end
			end,
			useRef = function(value) return { current = value } end,
			useEffect = function() end,
		},
		Browse = { useLinkedTab = function(_, default) return default, function() end end,
			useLinkedQuery = function() return "", function() end end },
		PageScaffold = "PageScaffold", UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2, Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Enum = roblox.Enum,
		-- offer cards are a memoised component (B34); render them inline here so the geometry checks still see them
		memoRow = function(impl) return impl end,
		sameFields = function() return function() return true end end,
		counted = function(_, impl) return impl end,
		useViewport = function() return {} end,
		chromeFor = function() return { stack = false, bottomSafe = 0 } end,
		scrollTail = function(_, _, base) return base end,
		workspace = { GetServerTimeNow = function() return 3601 end },
		Workspace = { GetServerTimeNow = function() return 3601 end },
		-- cast-iron styling helpers (pages revamp): inert stand-ins for geometry checks
		named = function(name) return { Name = name } end,
		ironFace = function() return node("IronFace", {}) end,
		BRASS = roblox.Color3.fromRGB(170, 126, 70), IRON_RADIUS = 4,
		StrokeWidth = setmetatable({}, { __index = function() return 1 end }),
		Audio = setmetatable({}, { __index = function() return function() end end }),
		HttpService = { JSONEncode = function() return "" end, GenerateGUID = function() return "guid" end },
		-- layout rebuild helpers (UiCore/ui): same column maths as splitColumns/stackHeight, components as tags
		splitColumns = function(w, sideWidth, gap, minWidth)
			sideWidth, gap, minWidth = sideWidth or 320, gap or 14, minWidth or 860
			local usable = math.max(0, math.floor(w))
			if usable < minWidth then return { split = false, side = usable, main = usable, gap = gap } end
			local side = math.clamp(sideWidth, 220, math.floor(usable * 0.45))
			return { split = true, side = side, main = usable - side - gap, gap = gap }
		end,
		stackHeight = function(heights, gap)
			local total = 0
			for index, value in heights do total += value + (if index > 1 then (gap or 10) else 0) end
			return total
		end,
		columnsBalanced = function(a, b, tolerance)
			local tall = math.max(a, b)
			return tall <= 0 or (tall - math.min(a, b)) / tall <= (tolerance or 0.18)
		end,
		SplitColumns = "SplitColumns", StackBlocks = "StackBlocks",
		useFocusOrder = function() end, -- gamepad focus wiring needs live instances
		-- 06 mockup pieces (mockKit/mockRows): components as tags, sizes from the same maths
		TapTarget = 48, SEC = roblox.Color3.fromRGB(58, 46, 62), HEADING_SECTION_H = 30,
		MockPanel = "MockPanel", PanelHeading = "PanelHeading", MockRow = "MockRow", MockBtn = "MockBtn",
		HeadingSection = "HeadingSection", Line = "Line", Bar = "Bar", RowFace = "RowFace", TileWell = "TileWell",
		BODY = "BODY", BODY_BOLD = "BODY_BOLD", NUM = "NUM",
		rowHeight = function(phone, twoLine) return if phone then (if twoLine then 46 else 44) else (if twoLine then 56 else 48) end,
		panelHeight = function(phone, content) return content + (if phone then 20 else 36) end,
		headingBlock = function(phone) return if phone then 26 else 34 end,
	}, { __index = _G })
	local first = assert(source:find("local CATEGORIES", 1, true))
	local last = assert(source:find("return { BazaarView = BazaarView }", first, true) or source:find("return {%s*BazaarView = BazaarView", first))
	local component = luau.load(source:sub(first, last - 1) .. "\nreturn BazaarView", { environment = environment })()
	return component({
		state = { Cash = "1e400", Bazaar = { Market = { Offers = offers, EndsAt = 7200, CatalogSize = 36, Saved = {}, History = {} } } },
		reducedMotion = true, dispatch = function() error("inspection must not transact") end,
	})
end
local offers = {
	{ Id = "dust", Name = "Stardust Pouch", Category = "Resources", Reward = { Stardust = 40 }, Price = 4000, Discount = 0.2, Left = 3, Stock = 4, Holdings = { { Label = "Stardust", Count = 120 } } },
	{ Id = "bulk", Name = "Stardust Shipment", Category = "Resources", Reward = { Stardust = 300 }, Price = 15000, Discount = 0.3, Left = 0, Stock = 2, Holdings = { { Label = "Stardust", Count = 120 } } },
	{ Id = "cores", Name = "Loose Core", Category = "Resources", Reward = { Cores = 1 }, Price = 1000, Discount = 0.4, Left = 2, Stock = 2, Holdings = { { Label = "Cores", Count = 2 } } },
}
local splitSeen = {}
for _, width in { 260, 280, 359, 705, 1024, 1600 } do
	local tree = render(width, "dust", offers)
	local sections, comparisons = {}, {}
	-- wide layouts put the inspection in a side column next to the shelf: read both columns' blocks
	local flat, split = {}, false
	for _, section in tree.props.sections do
		if section.id == "shelf-split" then
			split = true
			local props = section.element.props
			assert(props.plan.split and props.sideOnRight, "inspection sits in the right-hand column")
			for _, block in props.main.props.blocks do table.insert(flat, block) end
			for _, block in props.side.props.blocks do table.insert(flat, block) end
		else
			table.insert(flat, section)
		end
	end
	-- two columns only when wide enough AND the inspection column and the shelf (worked out at the
	-- split width) come out within 18% of each other
	local inspectH, inspectCount = 0, 0
	for _, section in flat do
		local id = section.id
		if id:sub(1, 10) == "inspection" or id:sub(1, 8) == "compare-" then
			inspectH += section.height + (if inspectCount > 0 then 12 else 0)
			inspectCount += 1
		end
	end
	local expected = false
	if width >= 860 then
		local main = width - math.clamp(340, 220, math.floor(width * 0.45)) - 12
		-- 06 listing rows: one offer per 72px row, 10px apart
		local rows = #offers
		local shelfH = rows * 72 + (rows - 1) * 10
		expected = (math.max(inspectH, shelfH) - math.min(inspectH, shelfH)) / math.max(inspectH, shelfH) <= 0.18
	end
	assert(split == expected, `split at {width}px only when wide enough and balanced (inspection {inspectH})`)
	splitSeen[width] = split
	for _, section in flat do
		sections[section.id] = section
		if section.id:sub(1, 8) == "compare-" then table.insert(comparisons, section.id) end
	end
	local function find(tree, test)
		if type(tree) ~= "table" then return nil end
		if tree.props and test(tree) then return tree end
		for _, child in tree.children or {} do
			local hit = find(child, test)
			if hit then return hit end
		end
		for _, child in tree do
			if type(child) == "table" and child ~= tree.children and child.kind ~= nil and child ~= tree then
				local hit = find(child, test)
				if hit then return hit end
			end
		end
		return nil
	end
	local heading = sections["inspection-heading"]
	assert(find(heading.element, function(n) return n.props.title == "Held · Stardust" and n.props.value == "120" end), "inspection lists the held amount")
	assert(find(heading.element, function(n) return n.props.title == "Order of 1" and n.props.value == "4000 flux" end), "inspection quotes the order")
	assert(find(heading.element, function(n) return n.props.text == "Close inspection" end), "inspection keeps a close button")
	assert(comparisons[1] == "compare-bulk" and comparisons[2] == "compare-dust" and #comparisons == 2,
		"compare exact supply sorted by per-reward-unit cost, including sold-out packs")
	for key, section in sections do
		if key:sub(1, 6) ~= "shelf-" then continue end
		local cards = section.element.children[1]
		for _, card in cards do
			if type(card.kind) == "function" then
				card = card.kind(card.props)
			end
			local inspect = find(card, function(n) return n.props.text == "Inspect" or n.props.text == "Inspecting" end)
			local buy = find(card, function(n) local t = n.props.text; return type(t) == "string" and (t:sub(1, 3) == "Buy" or t:find("Sold", 1, true) ~= nil) end)
			assert(inspect and buy, "offer row keeps its inspect and buy buttons")
			assert(section.height >= 72, "listing row is at least the 06 row height")
		end
	end
	local expired = render(width, "gone", offers)
	local found = false
	for _, section in expired.props.sections do
		found = found or section.id == "inspection-expired"
		assert(section.id ~= "inspection-detail", "never present a stale inspection quote")
	end
	assert(found)
end
assert(splitSeen[260] == false and splitSeen[359] == false, "narrow pages never split")
print("[TEST] Market inspection: actual component holdings, comparable supply identity, huge unit prices, sold-out comparisons and responsive button geometry passed")
