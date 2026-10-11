local fs = require("@lune/fs")
local luau = require("@lune/luau")
local SharedData = require("../src/Shared/AstralForge/Shared/SharedData")
local source = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau"):gsub("\r\n", "\n")
local first = assert(source:find("local function loadMonetization()", 1, true))
local last = assert(source:find("local EMPTY_CATALOG", first, true))
local loaderSource = source:sub(first, last - 1) .. "\nreturn loadMonetization"

for _, mode in { "ready", "missing", "wrong-class", "require-error", "invalid-catalog" } do
	local warnings = {}
	local bundle = {
		IsA = function(_, class)
			return mode ~= "wrong-class" and class == "ModuleScript"
		end,
	}
	local shared = {
		WaitForChild = function(_, name)
			assert(name == "SharedData", "client must load the bundled catalog, not a retired instance")
			return if mode == "missing" then nil else bundle
		end,
	}
	local astral = { WaitForChild = function(_, name) assert(name == "Shared"); return shared end }
	local loader = luau.load(loaderSource, {
		environment = setmetatable({
			ReplicatedStorage = { WaitForChild = function(_, name) assert(name == "AstralForge"); return astral end },
			ClientLog = { warn = function(_, category, message)
				assert(category == "shop")
				table.insert(warnings, message)
			end },
			require = function(module)
				assert(module == bundle)
				if mode == "require-error" then error("test catalog load failure") end
				if mode == "invalid-catalog" then return function() return false end end
				return SharedData
			end,
		}, { __index = _G }),
	})()
	local catalog = loader()
	if mode == "ready" then
		assert(catalog == SharedData("MonetizationConfig"))
		assert(#catalog.DevProducts == 4 and #catalog.GamePasses == 4)
		for _, product in catalog.DevProducts do assert(product.ProductId > 0) end
		for _, pass in catalog.GamePasses do assert(pass.PassId > 0) end
		assert(catalog.Error == nil and #warnings == 0)
	else
		assert(#catalog.DevProducts == 0 and #catalog.GamePasses == 0)
		assert(type(catalog.Error) == "string" and #warnings == 1, "failed catalog must be visible and logged")
	end
end

local tabStart = assert(source:find("local function sectionTabLayout", 1, true))
local tabEnd = assert(source:find("\nend", tabStart, true)) + #"\nend"
local layout = luau.load(source:sub(tabStart, tabEnd) .. "\nreturn sectionTabLayout", {
	environment = setmetatable({ SECTIONS = table.create(6, true) }, { __index = _G }),
})()
for _, width in { 240, 280, 320, 375, 390, 480, 600, 768, 1024, 1920 } do
	for _, rowHeight in { 44, 48 } do
		local columns, height = layout(width, rowHeight)
		local rows = math.ceil(6 / columns)
		local cellWidth = (width - (columns - 1) * 6) / columns
		assert(cellWidth >= 96, "section labels must not be squeezed into six phone-sized columns")
		assert((height - (rows - 1) * 6) / rows == rowHeight, "reflow preserves row/touch-target height")
		assert(columns <= 6 and columns >= 1)
	end
end
assert(source:find('GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)', 1, true), "tabs follow actual host width")
assert(source:find("columns = tabColumns", 1, true))
assert(source:find("value = monetization.Error or banner", 1, true), "catalog error is rendered")
local cardStart = assert(source:find("local function ArtifactCard", 1, true))
local cardEnd = assert(source:find("local function ", cardStart + 1, true))
local card = source:sub(cardStart, cardEnd - 1)
for _, retired in { '"Halo"', "h(ArtifactLight", '"IconDisc"', "VAULT ONLY", "then 36" } do
	assert(not card:find(retired, 1, true), "artifact card must not restore " .. retired)
end
assert(card:find('value = "Shop exclusive"', 1, true))
assert(card:find("h(ElementFx", 1, true), "element sprite remains visible")
print("[TEST] shop: real bundled 4-product/4-pass catalog, explicit failure states, measured responsive tabs and restrained artifact cards passed")
