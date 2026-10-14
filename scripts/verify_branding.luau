local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local ids = serde.decode("json", fs.readFile("assets/asset_ids.json"))
local art = fs.readFile("src/Client/AstralForge/ArtKit.luau")
local assets = {}
for _, entry in {
	{ "wordmark", "WORDMARK_ASSET", "BrandWordmark", 4096, 1536 },
	{ "compact-mark", "COMPACT_MARK_ASSET", "BrandCompactMark", 1024, 1024 },
	{ "game-icon", "GAME_ICON_ASSET", "BrandGameIcon", 2048, 2048 },
} do
	local data = fs.readFile("assets/generated/branding/" .. entry[1] .. ".png")
	assert(data:sub(1, 8) == "\137PNG\r\n\26\n", entry[1] .. ": PNG signature")
	assert(data:sub(13, 16) == "IHDR", entry[1] .. ": PNG dimensions present")
	local function u32(offset)
		local a, b, c, d = data:byte(offset, offset + 3)
		return a * 16777216 + b * 65536 + c * 256 + d
	end
	assert(u32(17) == entry[4] and u32(21) == entry[5], entry[1] .. ": full-resolution artwork")
	assert(data:byte(25) == 8 and data:byte(26) == 6, entry[1] .. ": RGBA transparency")
	local asset = art:match('local ' .. entry[2] .. ' = "(rbxassetid://%d+)"')
	assert(asset == "rbxassetid://" .. tostring(ids[entry[3]]), entry[1] .. ": uploaded reference agrees with manifest")
	assert(art:find(entry[2] .. " = " .. entry[2] .. ",", 1, true), entry[1] .. ": shared export")
	assets[entry[2]] = asset
end

local ui = fs.readFile("src/Client/AstralForge/UiCore.luau")
local start = assert(ui:find("local function LogoLockup(", 1, true))
local finish = assert(ui:find("\nreturn {", start, true))
local env = setmetatable({
	React = { createElement = function(kind, props, ...)
		return { kind = kind, props = props, children = { ... } }
	end },
	Palette = { cyan = roblox.Color3.fromRGB(91, 214, 244) },
	WORDMARK_ASSET = assets.WORDMARK_ASSET,
	COMPACT_MARK_ASSET = assets.COMPACT_MARK_ASSET,
	Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim,
	Vector2 = roblox.Vector2, Enum = roblox.Enum,
}, { __index = _G })
local render = luau.load(ui:sub(start, finish - 1) .. "\nreturn LogoLockup", { environment = env })()
for _, width in { 48, 156, 168, 176 } do
	local micro = width == 48
	local node = render({ micro = micro, compact = width < 176, reducedMotion = true })
	local mark = node.children[1]
	assert(mark.props.Size.X.Offset <= width, "mark fits smallest host")
	local image = mark.children[1]
	assert(image.kind == "imagelabel" and image.props.Image == assets.COMPACT_MARK_ASSET)
	assert(#image.children == 0, "authored monogram replaces procedural strokes")
	if micro then
		assert(node.children[2] == false, "micro uses only the readable square mark")
	else
		local wordmark = node.children[2]
		assert(wordmark.kind == "imagelabel" and wordmark.props.Image == assets.WORDMARK_ASSET)
		assert(wordmark.props.ScaleType == roblox.Enum.ScaleType.Fit, "no stretching or text refitting")
		local x = wordmark.props.Position.X.Offset
		local imageWidth = wordmark.props.Size.X.Scale * width + wordmark.props.Size.X.Offset
		assert(imageWidth > 0 and x + imageWidth == width, "wordmark stays inside its host")
	end
end
local boot = fs.readFile("src/Client/AstralForge/BootKit.luau"):gsub("\r\n", "\n")
assert(boot:find('Name = "BootWordmark"', 1, true) and boot:find('Name = "ShutdownWordmark"', 1, true))
assert(boot:find("BrandArt.COMPACT_MARK_ASSET", 1, true) and boot:find("BrandArt.WORDMARK_ASSET", 1, true))
assert(boot:find("status ~= Enum.AssetFetchStatus.Success", 1, true), "asset failures are reported")
local preloadStart = assert(boot:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true)
	or boot:find("React.useEffect(function()\n\t\tlocal probes = {}", 1, true))
local preloadEnd = assert(boot:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
for _, mode in { "success", "failure", "exception", "pending" } do
	local destroyed, warnings, cancelled = 0, {}, false
	local success = { Name = "Success" }
	local cleanup
	local preloadEnv = setmetatable({
		BrandArt = assets,
		Enum = { AssetFetchStatus = { Success = success } },
		Instance = { new = function(class)
			assert(class == "ImageLabel")
			return { Destroy = function() destroyed += 1 end }
		end },
		warn = function(message) table.insert(warnings, message) end,
		React = { useEffect = function(callback) cleanup = callback() end },
		task = {
			spawn = function(callback)
				local thread = coroutine.create(callback)
				local ok, reason = coroutine.resume(thread)
				assert(ok, reason)
				return thread
			end,
			cancel = function() cancelled = true end,
		},
		game = { GetService = function(_, service)
			assert(service == "ContentProvider")
			return { PreloadAsync = function(_, targets, callback)
				assert(#targets == 3, "all three assets preloaded")
				if mode == "pending" then coroutine.yield() end
				if mode == "exception" then error("offline", 0) end
				for _, target in targets do
					local assetId = if type(target) == "table" then target.Image else target
					assert(type(assetId) == "string" and assetId:match("^rbxassetid://%d+$"), "preload asset IDs directly")
					callback(assetId, if mode == "failure" then { Name = "Failure" } else success)
				end
			end }
		end },
	}, { __index = _G })
	luau.load(boot:sub(preloadStart, preloadEnd - 1), { environment = preloadEnv })()
	if mode == "pending" and destroyed > 0 then assert(destroyed == 0) end
	cleanup()
	if destroyed > 0 then
		assert(destroyed == 3, mode .. ": probes disposed exactly once")
	end
	assert(cancelled == (mode == "pending"), mode .. ": pending preload cancelled on unmount")
	local expectedWarnings = if mode == "failure" then 3 elseif mode == "exception" then 1 else 0
	assert(#warnings == expectedWarnings, mode .. ": failures remain explicit")
end
local layoutStart = assert(boot:find("\tlocal short = useViewport().height < 420", 1, true))
local layoutEnd = assert(boot:find("\n\tlocal marks", layoutStart, true))
for _, height in { 280, 660, 900 } do
	local layout = luau.load(boot:sub(layoutStart, layoutEnd - 1) .. "\nreturn {short, centerY, coreSize, coreY, statusY}", {
		environment = setmetatable({ useViewport = function() return { height = height } end }, { __index = _G }),
	})()
	local short, center, core, coreY, statusY = table.unpack(layout)
	local markTop = height * center + coreY - core / 2
	local progressBottom = height * center + statusY + 22 + 14
	local tipTop = height - (if short then 46 else 62) - 14
	assert(markTop >= 0 and progressBottom < tipTop, "boot content and wrapped tips do not overlap in short landscape")
end
local stageStart = assert(boot:find("local ROLL =", 1, true))
local stageEnd = assert(boot:find("\nreturn {\n\tBootStageText", stageStart, true))
local function binding(value)
	return { value = value, map = function(self, callback) return binding(callback(self.value)) end }
end
local stageEnv = setmetatable({
	React = {
		createElement = env.React.createElement,
		useRef = function(value) return { current = value } end,
		useBinding = function(value) return binding(value) end,
		useEffect = function() end,
		joinBindings = function(values)
			local joined = {}
			for key, value in values do joined[key] = value.value end
			return binding(joined)
		end,
	},
	Palette = { muted = roblox.Color3.fromRGB(190, 174, 178) },
	UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Enum = roblox.Enum, Font = roblox.Font,
}, { __index = _G })
local stage = luau.load(boot:sub(stageStart, stageEnd - 1) .. "\nreturn BootStageText", { environment = stageEnv })()
for _, width in { 323, 634, 975 } do
	local node = stage({ text = "Loading art", clock = binding(0), reducedMotion = true })
	assert(node.props.Size.X.Scale == 1 and node.props.Size.X.Offset == 0, "stage follows its parent width")
	local glyphs = node.children[1]
	local first, last = glyphs[1].props.Position.X, glyphs[#glyphs].props.Position.X
	local midpoint = ((first.Scale + last.Scale) * width + first.Offset + last.Offset) / 2
	assert(math.abs(midpoint - width / 2) < 0.001, "animated status stays centered, not at a fixed left-side width")
end
local transferStart = assert(boot:find("local function phaseName", 1, true))
local transferEnd = assert(boot:find("\nreturn {\n\tSoftShutdownScreen", transferStart, true))
for _, height in { 280, 660 } do
	local transferEnv = setmetatable({
		React = {
			createElement = env.React.createElement,
			useRef = stageEnv.React.useRef,
			useEffect = function() end,
			useBinding = function(value) return binding(value), function() end end,
		},
		useViewport = function() return { height = height } end,
		WORDMARK_ASSET = assets.WORDMARK_ASSET, LoadingDots = "LoadingDots",
		Palette = {
			mint = roblox.Color3.fromRGB(95, 211, 166),
			mango = roblox.Color3.fromRGB(247, 181, 74),
			cyan = roblox.Color3.fromRGB(91, 214, 244),
			creamSoft = roblox.Color3.fromRGB(232, 220, 219),
			muted = roblox.Color3.fromRGB(190, 174, 178),
		},
		Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim,
		Vector2 = roblox.Vector2, Enum = roblox.Enum, Font = roblox.Font,
	}, { __index = _G })
	local transfer = luau.load(boot:sub(transferStart, transferEnd - 1) .. "\nreturn SoftShutdownScreen", { environment = transferEnv })()
	for _, phase in { "Saving", "Waiting", "Teleporting" } do
		for _, message in { "", "The server is restarting. Your progress is being saved." } do
			local node = transfer({ state = { phase = phase, message = if message == "" then nil else message }, reducedMotion = true })
			local wordmark, progress, status, detail = node.children[2], node.children[4], node.children[5], node.children[6]
			assert(wordmark.props.Image == assets.WORDMARK_ASSET)
			local progressBottom = progress.props.Position.Y.Scale * height + progress.props.Position.Y.Offset + progress.props.Size.Y.Offset
			local statusBottom = status.props.Position.Y.Scale * height + status.props.Position.Y.Offset
			assert(progressBottom <= statusBottom - status.props.Size.Y.Offset, "landscape transfer progress clears status")
			local detailBottom = detail.props.Position.Y.Scale * height + detail.props.Position.Y.Offset
			assert(statusBottom <= detailBottom - detail.props.Size.Y.Offset, "status and optional message do not overlap")
			assert(math.abs(status.props.Size.X.Scale - 0.9) < 1e-6 and math.abs(detail.props.Size.X.Scale - 0.9) < 1e-6, "transfer text stays inside phone width")
			assert(detail.props.Text == message and detail.props.Visible == (message ~= ""), "missing optional message never renders Roblox's default Label")
			assert(status.props.TextSize >= 12 and detail.props.TextSize >= 12, "save/transfer instructions retain readable essential text")
		end
	end
end
assert(not ui:sub(start, finish - 1):find("useClock", 1, true), "branding introduces no independent animation clock")
print("[TEST] branding: original RGBA assets, upload manifest, actual responsive lockup and boot integration passed")
