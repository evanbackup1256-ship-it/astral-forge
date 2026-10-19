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
	local palette = setmetatable({}, { __index = function(_, key) return key end })
	local environment = setmetatable({
		h = node, Palette = palette, Format = Format,
		Ui = setmetatable({}, { __index = function(_, key) return key end }),
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
		PageScaffold = "PageScaffold", UDim2 = roblox.UDim2, Enum = roblox.Enum,
		workspace = { GetServerTimeNow = function() return 3601 end },
		Workspace = { GetServerTimeNow = function() return 3601 end },
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
for _, width in { 260, 280, 359, 705, 1024, 1600 } do
	local tree = render(width, "dust", offers)
	local sections, comparisons = {}, {}
	for _, section in tree.props.sections do
		sections[section.id] = section
		if section.id:sub(1, 8) == "compare-" then table.insert(comparisons, section.id) end
	end
	assert(sections["inspection-detail"].element.props.value:find("Stardust: 120", 1, true))
	assert(sections["inspection-detail"].element.props.value:find("Order: 1 units for 4000", 1, true))
	assert(comparisons[1] == "compare-bulk" and comparisons[2] == "compare-dust" and #comparisons == 2,
		"compare exact supply sorted by per-reward-unit cost, including sold-out packs")
	local heading = sections["inspection-heading"]
	local close = heading.element.children[2]
	assert(close.props.size.Y.Offset >= 48 and close.props.position.Y.Offset + close.props.size.Y.Offset <= heading.height - 28)
	for key, section in sections do
		if key:sub(1, 6) ~= "shelf-" then continue end
		local cards = section.element.children[1]
		for _, card in cards do
			local panel = card.children[1]
			local inspect, buy = panel.children[7], panel.children[8]
			assert(inspect.props.text == "Inspect / compare" or inspect.props.text == "Inspecting")
			assert(inspect.props.position.Y.Offset + inspect.props.size.Y.Offset < buy.props.position.Y.Offset)
			assert(buy.props.position.Y.Offset + buy.props.size.Y.Offset <= section.height - 28)
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
print("[TEST] Market inspection: actual component holdings, comparable supply identity, huge unit prices, sold-out comparisons and responsive button geometry passed")
