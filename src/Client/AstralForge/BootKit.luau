--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("BootKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("BootKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["BootLedger"] = function()
-- What the loading screen reads. Every loader reports here by station with real counts and the
-- name of what it is on right now; the boot screen polls it each frame (no React traffic).
local STATIONS = {
	{ key = "server", label = "SERVER", verb = "Reaching the server" },
	{ key = "save", label = "SAVE", verb = "Opening your save" },
	{ key = "art", label = "ART", verb = "Loading art" },
	{ key = "sound", label = "SOUND", verb = "Loading sounds" },
	{ key = "world", label = "WORLD", verb = "Loading the world" },
	{ key = "code", label = "CODE", verb = "Starting the game" },
	{ key = "menus", label = "MENUS", verb = "Building the menus" },
}
local MENU_NAMES = {
	shell = "Main menu", mail = "Mailbox", research = "Research", forge = "Forge",
	trade = "Trading", boosts = "Boosts", settings = "Settings", mobile = "Touch controls",
}
local MARKS = {
	bridge = { "server", "bridge", "Handshake" },
	remotes = { "server", "remotes", "Remotes" },
	state = { "save", "state", "Save loaded" },
	audio = { "sound", "bank", nil },
	fonts = { "art", "fonts", "Fonts" },
	modules = { "code", "modules", nil },
}
local parts = {}
local items = {}
local itemAt = {}
local version = 0
local cache = nil
local cacheVersion = -1

local function stamp(station, item)
	if type(item) == "string" and item ~= "" then
		items[station] = item
		itemAt[station] = os.clock()
	end
end
local function part(station: string, sub: string, loaded: number?, total: number?, item: string?)
	local list = parts[station]
	if list == nil then
		list = {}
		parts[station] = list
	end
	local entry = list[sub]
	if entry == nil then
		entry = { loaded = 0, total = 1 }
		list[sub] = entry
	end
	local nextTotal = if type(total) == "number" then total else entry.total
	if nextTotal <= 0 then
		-- nothing of this kind to load counts as done
		entry.loaded, entry.total = 1, 1
	else
		entry.total = nextTotal
		entry.loaded = math.clamp(if type(loaded) == "number" then loaded else entry.loaded, 0, nextTotal)
	end
	stamp(station, item)
	version += 1
end
local function finish(station: string, sub: string, item: string?)
	local entry = parts[station] and parts[station][sub]
	if entry == nil then
		part(station, sub, 1, 1, item)
		return
	end
	entry.loaded = entry.total
	stamp(station, item)
	version += 1
end
-- every part is known up front, so a station never looks done before its loader reports
part("server", "bridge", 0, 1)
part("server", "remotes", 0, 1)
part("save", "state", 0, 1)
part("art", "images", 0, 1)
part("art", "fonts", 0, 1)
part("sound", "bank", 0, 1)
part("world", "world", 0, 1)
part("code", "modules", 0, 1)
for key in MENU_NAMES do
	part("menus", key, 0, 1)
end

local Ledger = {}
Ledger.STATIONS = STATIONS
Ledger.part = part
Ledger.finish = finish
-- a boot checklist key ("state", "fonts", "shell" ...) completing
function Ledger.mark(key: string)
	if key == "assets" then
		finish("art", "images")
		finish("world", "world")
		return
	end
	local entry = MARKS[key]
	if entry ~= nil then
		finish(entry[1], entry[2], entry[3])
	elseif MENU_NAMES[key] ~= nil then
		finish("menus", key, MENU_NAMES[key])
	end
end
-- { stations = { {key, label, verb, loaded, total, fraction, done, item} }, overall, active }
function Ledger.read()
	if cache ~= nil and cacheVersion == version then
		return cache
	end
	local view = { stations = {}, overall = 0, active = nil }
	local sum = 0
	local newest = -math.huge
	for _, station in STATIONS do
		local loaded, total = 0, 0
		for _, entry in parts[station.key] or {} do
			loaded += entry.loaded
			total += entry.total
		end
		local fraction = if total > 0 then loaded / total else 1
		local row = {
			key = station.key, label = station.label, verb = station.verb,
			loaded = loaded, total = total, fraction = fraction, done = fraction >= 1,
			item = items[station.key],
		}
		table.insert(view.stations, row)
		sum += fraction
		-- the station working most recently is the one the screen talks about
		if not row.done and (itemAt[station.key] or 0) > newest then
			newest = itemAt[station.key] or 0
			view.active = row
		end
	end
	view.overall = sum / #STATIONS
	cache, cacheVersion = view, version
	return view
end
function Ledger.version(): number
	return version
end
return Ledger
end

__defs["BootScreen"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local BrandArt = require(script.Parent.ArtKit)("Icon")
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local Ledger = __load("BootLedger")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local BOOT_MODULE_TIMEOUT = 9
local MIN_BOOT_SECONDS = 2.6
local BOOT_MOTION = {
	motionScale = 1,
	viewportScale = 1,
	textScale = 1,
}
local EXIT_FLASH_SECONDS = 0.26
local EXIT_WIPE_SECONDS = 0.5
local STALL_SECONDS = 45
local TIP_SECONDS = 5.8
local EMBER_COUNT = 28
local SPARK_COUNT = 16
local SYSTEMS = { "bridge", "remotes", "state", "assets", "modules", "fonts", "audio", "shell", "mail", "research", "forge", "trade", "boosts", "settings", "mobile" }
local LOADING_TIPS = {
	"Research stays with you when you rebirth.",
	"A full vault stops filling. Collect it often.",
	"Overcharge a machine by tapping it fast.",
	"Boosts stack with research, so start one before a long session.",
	"Rebirth when the Cores on offer would beat what you have now.",
	"The wheel's pity counter guarantees a rare sooner or later.",
	"Auto-Forge keeps buying your best machine while you're away.",
	"Daily shop stock changes at midnight UTC.",
	"Relics can be salvaged for essence if you pull a duplicate.",
	"You can replay the tour from Settings.",
	"Ctrl+K opens Find from anywhere.",
}
local HOT = Color3.fromRGB(255, 150, 60)
local WHITE_HOT = Color3.fromRGB(255, 244, 222)

local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function easeOut(t)
	local u = 1 - clamp01(t)
	return 1 - u * u * u
end
local function progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	local complete = 0
	for _, key in SYSTEMS do
		if marks[key] then
			complete += 1
		end
	end
	local partial = 0
	if not marks.assets and assetsTotal ~= nil and assetsTotal > 0 and assetsLoaded ~= nil then
		partial += math.clamp(assetsLoaded / assetsTotal, 0, 1) * 0.85
	end
	if not marks.modules and modulesTotal ~= nil and modulesTotal > 0 and modulesLoaded ~= nil then
		partial += math.clamp(modulesLoaded / modulesTotal, 0, 1) * 0.85
	end
	return math.clamp((complete + partial) / #SYSTEMS, 0, 1)
end
local function bootChecklistReady(marks)
	for _, key in SYSTEMS do
		if not marks[key] then
			return false
		end
	end
	return true
end
local function bootProgress(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	return progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
end

-- where everything sits for a screen size; the block is centred in the space above the tip
local function layoutFor(width: number, height: number)
	local short = height < 420
	local column = math.min(620, width * 0.86)
	local twoRows = column < 460
	local tipLines = if short then 2 else 3
	local tipSize = if short then 13 else 15
	local tipHeight = 18 + tipLines * (tipSize + 6) + 10
	local tipTop = height - tipHeight - (if short then 10 else 28)
	local stationRow = if short then 30 else 36
	local stationsH = if twoRows then stationRow * 2 + 8 else stationRow
	local wordH = if short then 32 else 60
	local gapWord = if short then 14 else 30
	local statusH = if short then 24 else 32
	local itemGap = if short then 10 else 22
	local block = wordH + gapWord + statusH + 6 + 8 + 8 + 16 + itemGap + stationsH
	local y = math.max(if short then 10 else 24, math.floor((tipTop - block) * 0.5))
	local L = {
		short = short, column = column, twoRows = twoRows, tipTop = tipTop, tipHeight = tipHeight,
		tipSize = tipSize, tipLines = tipLines, stationRow = stationRow, stationsH = stationsH,
		wordH = wordH, statusH = statusH,
	}
	L.wordY = y
	y += wordH + gapWord
	L.statusY = y
	y += statusH + 6
	L.channelY = y
	y += 8 + 8
	L.itemY = y
	y += 16 + itemGap
	L.stationsY = y
	y += stationsH
	L.blockBottom = y
	return L
end

-- centred word wrap: widths -> { [index] = { line, x } } with x measured from the centre line
local function wrapWords(widths: { number }, maxWidth: number, space: number)
	local lines = {}
	local line = { width = 0, items = {} }
	for index, w in widths do
		local grown = if #line.items == 0 then w else line.width + space + w
		if #line.items > 0 and grown > maxWidth then
			table.insert(lines, line)
			line = { width = 0, items = {} }
			grown = w
		end
		table.insert(line.items, { index = index, x = if #line.items == 0 then 0 else line.width + space })
		line.width = grown
	end
	if #line.items > 0 then
		table.insert(lines, line)
	end
	local placed = {}
	for lineIndex, entry in lines do
		for _, item in entry.items do
			placed[item.index] = { line = lineIndex, x = item.x - entry.width / 2 }
		end
	end
	return placed, #lines
end

-- a tip that arrives word by word, glowing hot and cooling to cream, and leaves the same way
local function TipText(props)
	local words = {}
	for word in string.gmatch(props.text or "", "%S+") do
		table.insert(words, word)
	end
	local size = props.size
	local widths = {}
	for index, word in words do
		local ok, bounds = pcall(function()
			return TextService:GetTextSize(word, size, Enum.Font.BuilderSansMedium, Vector2.new(4096, 4096))
		end)
		widths[index] = if ok then bounds.X + 1 else #word * size * 0.52
	end
	local space = math.max(3, math.floor(size * 0.22))
	local placed = wrapWords(widths, props.maxWidth, space)
	local lineHeight = size + 6
	local bornAt, leaveAt = props.bornAt, props.leaveAt
	local children = {}
	for index, word in words do
		local spot = placed[index]
		local delay = (index - 1) * 0.04
		local motion = props.tick:map(function()
			local now = os.clock()
			local arrive = easeOut((now - bornAt - delay) / 0.4)
			local leave = if leaveAt then easeOut((now - leaveAt - (index - 1) * 0.015) / 0.24) else 0
			local cool = clamp01((now - bornAt - delay - 0.15) / 0.8)
			return { y = (1 - arrive) * 10 - leave * 9, alpha = 1 - arrive + leave, cool = cool }
		end)
		children["w" .. index] = React.createElement("textlabel", {
			Size = UDim2.fromOffset(widths[index] + 2, lineHeight),
			Position = motion:map(function(m)
				return UDim2.new(0.5, spot.x, 0, (spot.line - 1) * lineHeight + m.y)
			end),
			BackgroundTransparency = 1,
			Text = word,
			TextSize = size,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = motion:map(function(m)
				return HOT:Lerp(Palette.creamSoft, m.cool)
			end),
			TextTransparency = React.joinBindings({ motion, props.hidden }):map(function(values)
				return clamp01(values[1].alpha + values[2])
			end),
			ZIndex = 8,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, children)
end

-- the station check (stamped in when a station finishes)
local function CheckGlyph(props)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = props.position,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 9,
	}, React.createElement("uiscale", { Scale = props.scale }), React.createElement(BrandArt.Icon, {
		kind = "Check.1",
		color = props.color,
		size = 12,
		spin = false,
	}))
end

local function BootScreen(_param)
	local viewport = useViewport()
	local L = layoutFor(viewport.width, viewport.height)
	local ready = _param.ready
	local softMotion = _param.reducedMotion
	local startedAt = _param.startedAt
	local _version = _param.version
	local onExitDone = _param.onExitDone
	local mountedAt = React.useRef(startedAt or os.clock())
	local finished = React.useRef(false)
	local exitClock = React.useRef(0)
	local exiting, setExiting = React.useState(false)
	local gone, setGone = React.useState(false)
	local stalled, setStalled = React.useState(false)
	local tip, setTip = React.useState(function()
		return { index = math.random(1, #LOADING_TIPS), bornAt = os.clock(), leaveAt = nil }
	end)
	local tick, setTick = React.useBinding(0)
	local flash, setFlash = React.useBinding(0)
	local wipe, setWipe = React.useBinding(0)
	local shownProgress, setShownProgress = React.useBinding(0)
	local shownRef = React.useRef(0)
	local readyRef = React.useRef(ready)
	readyRef.current = ready
	-- what the labels read; filled from the ledger each frame
	local view = React.useRef({
		status = "Starting", statusPrev = "", statusAt = 0,
		item = "", itemAt = 0, percent = 0,
		stations = Ledger.read().stations, doneAt = {},
	})
	local sparks = React.useRef(nil)
	if sparks.current == nil then
		local list = {}
		for index = 1, SPARK_COUNT do
			list[index] = { born = -1, vx = 0, vy = 0, life = 1, head = 0 }
		end
		sparks.current = list
	end
	React.useEffect(function()
		local alive = true
		Audio:setScene("boot")
		local start = function()
			if alive and os.clock() - mountedAt.current <= 0.55 then
				Audio:play("bootStart")
			end
		end
		if Audio:isWarm() then
			start()
		else
			Audio:whenWarm(start)
		end
		return function()
			alive = false
			Audio:setScene("default")
		end
	end, {})
	React.useEffect(function()
		local assetList = { BrandArt.GAME_ICON_ASSET, BrandArt.WORDMARK_ASSET, BrandArt.COMPACT_MARK_ASSET }
		local isStudio = false
		pcall(function()
			local rs = game:GetService("RunService")
			if rs and type(rs.IsStudio) == "function" then
				isStudio = rs:IsStudio()
			end
		end)
		local preload = task.spawn(function()
			local ok, reason = pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(assetList, function(asset, status)
					if status ~= Enum.AssetFetchStatus.Success and not isStudio then
						warn(`[Branding] {asset} failed to load: {status.Name}`)
					end
				end)
			end)
			if not ok and not isStudio then
				warn(`[Branding] Preload failed: {tostring(reason)}`)
			end
		end)
		return function()
			if coroutine.status(preload) == "suspended" then
				task.cancel(preload)
			end
		end
	end, {})
	-- tips: each one stays TIP_SECONDS, then its words leave before the next arrives
	local advanceTip = React.useCallback(function()
		setTip(function(current)
			if current.leaveAt ~= nil then
				return current
			end
			return { index = current.index, bornAt = current.bornAt, leaveAt = os.clock() }
		end)
	end, {})
	React.useEffect(function()
		if tip.leaveAt ~= nil then
			local token = task.delay(0.32, function()
				setTip({ index = tip.index % #LOADING_TIPS + 1, bornAt = os.clock(), leaveAt = nil })
			end)
			return function()
				pcall(task.cancel, token)
			end
		end
		local token = task.delay(TIP_SECONDS, advanceTip)
		return function()
			pcall(task.cancel, token)
		end
	end, { tip })
	React.useEffect(function()
		if ready then
			return nil
		end
		local remaining = math.max(0, STALL_SECONDS - (os.clock() - mountedAt.current))
		local token = task.delay(remaining, function()
			setStalled(true)
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { ready })
	React.useEffect(function()
		if ready and not exiting and not finished.current then
			local hold = math.max(0, MIN_BOOT_SECONDS - (os.clock() - mountedAt.current))
			local token = task.delay(hold, function()
				if finished.current then
					return nil
				end
				finished.current = true
				exitClock.current = 0
				setExiting(true)
				Audio:play("bootReady")
			end)
			return function()
				pcall(task.cancel, token)
			end
		elseif not exiting and not finished.current then
			local timeout = if RunService:IsStudio() then 22 else 36
			local token = task.delay(timeout, function()
				if not finished.current then
					finished.current = true
					exitClock.current = 0
					setExiting(true)
				end
			end)
			return function()
				pcall(task.cancel, token)
			end
		end
	end, { exiting, ready })
	-- one frame driver: ledger -> labels, the pour, the sparks and the exit
	React.useEffect(function()
		local spawnCarry = 0
		local nextSpark = 1
		local connection = RunService.RenderStepped:Connect(function(dt)
			local now = os.clock()
			local data = Ledger.read()
			local v = view.current
			local target = if readyRef.current or exiting then 1 else math.min(0.99, data.overall)
			local before = shownRef.current
			shownRef.current += (target - before) * (1 - math.exp(-dt * 6))
			setShownProgress(shownRef.current)
			v.percent = math.floor(shownRef.current * 100 + 0.5)
			v.stations = data.stations
			local status = if readyRef.current or exiting then "Ready" elseif data.active then data.active.verb else "Almost there"
			if status ~= v.status then
				v.statusPrev, v.status, v.statusAt = v.status, status, now
			end
			local item = if data.active and data.active.item then data.active.item else ""
			if item ~= v.item and now - v.itemAt > 0.11 then
				v.item, v.itemAt = item, now
			end
			for _, station in data.stations do
				if station.done and v.doneAt[station.key] == nil then
					v.doneAt[station.key] = now
					if now - mountedAt.current > 0.4 then
						pcall(function()
							Audio:play("countTick")
						end)
					end
				end
			end
			-- sparks thrown back off the head of the pour, more when it surges
			if not softMotion and not exiting then
				local surge = math.max(0, shownRef.current - before) * 900
				spawnCarry += dt * (5 + math.min(30, surge))
				while spawnCarry >= 1 do
					spawnCarry -= 1
					local spark = sparks.current[nextSpark]
					nextSpark = nextSpark % SPARK_COUNT + 1
					spark.born = now
					spark.head = shownRef.current
					spark.vx = -(25 + math.random() * 80)
					spark.vy = -(35 + math.random() * 95)
					spark.life = 0.4 + math.random() * 0.45
				end
			end
			setTick(now)
			if exiting then
				exitClock.current += dt
				local elapsed = exitClock.current
				local scale = if softMotion then 0.6 else 1
				setFlash(easeOut(elapsed / (EXIT_FLASH_SECONDS * scale)))
				local w = clamp01((elapsed - EXIT_FLASH_SECONDS * scale) / (EXIT_WIPE_SECONDS * scale))
				setWipe(w * w * (3 - 2 * w))
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { exiting, softMotion })
	React.useEffect(function()
		if not exiting then
			return nil
		end
		local span = (EXIT_FLASH_SECONDS + EXIT_WIPE_SECONDS) * (if softMotion then 0.6 else 1) + 0.05
		local token = task.delay(span, function()
			setGone(true)
			onExitDone()
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { exiting, onExitDone })
	if gone then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end

	-- on the way out the pour flashes white-hot, the content dims and rides up with the lifting cover
	local hidden = flash:map(function(f)
		return clamp01((f - 0.4) / 0.6) * 0.55
	end)
	local function fadeFrom(base)
		return hidden:map(function(amount)
			return clamp01(base + amount)
		end)
	end
	local heat = React.joinBindings({ shownProgress, flash })

	-- embers rising off the forge floor; more and brighter as it heats up
	local embers = {}
	for index = 1, EMBER_COUNT do
		local seed = math.abs(math.sin(index * 12.9898) * 43758.5453) % 1
		local seedB = math.abs(math.sin(index * 78.233) * 12345.678) % 1
		local speed = (0.05 + seedB * 0.06) * (if softMotion then 0.5 else 1)
		local px = 2 + math.floor(seed * 3)
		embers["e" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(px, px),
			Position = tick:map(function(now)
				local rise = (now * speed + seedB) % 1
				local sway = math.sin(now * (0.7 + seed) + index) * 0.018
				return UDim2.fromScale(seed + sway, 1.02 - rise * 1.08)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 4 == 0 then WHITE_HOT else (if index % 2 == 0 then Palette.mango else Palette.ember),
			BackgroundTransparency = React.joinBindings({ tick, shownProgress, hidden }):map(function(values)
				local rise = (values[1] * speed + seedB) % 1
				local edge = if rise < 0.1 then 1 - rise / 0.1 else (if rise > 0.7 then (rise - 0.7) / 0.3 else 0)
				return clamp01(0.62 - values[2] * 0.35 + edge * 0.6 + values[3])
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end

	local forgeGlow = React.createElement("frame", {
		Size = UDim2.fromScale(1, 0.6),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = heat:map(function(values)
			return clamp01(0.62 - values[1] * 0.3 - values[2] * 0.25)
		end),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Rotation = -90,
		Color = ColorSequence.new(Palette.mango, Palette.ember),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}))

	local column = L.column
	local function at(y, h)
		return UDim2.new(0.5, 0, 0, y), UDim2.fromOffset(column, h)
	end

	-- wordmark with a white-hot glint crossing it now and then
	local wordPos, wordSize = at(L.wordY, L.wordH)
	local wordmark = React.createElement("frame", {
		Position = wordPos,
		Size = wordSize,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, React.createElement("imagelabel", {
		Name = "BootWordmark",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = BrandArt.WORDMARK_ASSET,
		ImageTransparency = fadeFrom(0),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 6,
	}), not softMotion and React.createElement("imagelabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = BrandArt.WORDMARK_ASSET,
		ImageColor3 = WHITE_HOT,
		ImageTransparency = fadeFrom(0),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 7,
	}, React.createElement("uigradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = tick:map(function(now)
			local cycle = (now - mountedAt.current) % 3.2
			return Vector2.new(-1.2 + clamp01(cycle / 1.1) * 2.4, 0)
		end),
	})))

	-- status: what the game is doing (rolls over when it changes) and the percent
	local statusPos, statusSize = at(L.statusY, L.statusH)
	local statusSizePx = if L.short then 15 else 19
	local function statusLabel(prev)
		return React.createElement("textlabel", {
			Size = UDim2.new(1, -110, 1, 0),
			Position = tick:map(function(now)
				local a = easeOut((now - view.current.statusAt) / 0.32)
				return UDim2.fromOffset(0, if prev then -a * 12 else (1 - a) * 12)
			end),
			BackgroundTransparency = 1,
			Text = tick:map(function()
				return if prev then view.current.statusPrev else view.current.status
			end),
			TextColor3 = Palette.cream,
			TextTransparency = React.joinBindings({ tick, hidden }):map(function(values)
				local a = easeOut((values[1] - view.current.statusAt) / 0.32)
				return clamp01((if prev then a else 1 - a) + values[2])
			end),
			TextSize = statusSizePx,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			ZIndex = 7,
		})
	end
	local statusRow = React.createElement("frame", {
		Position = statusPos,
		Size = statusSize,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 6,
	}, statusLabel(false), statusLabel(true), React.createElement("textlabel", {
		Size = UDim2.new(0, 110, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Text = tick:map(function()
			return `{view.current.percent}<font size="{math.floor(statusSizePx * 0.75)}" transparency="0.35">%</font>`
		end),
		RichText = true,
		TextColor3 = heat:map(function(values)
			return Palette.mango:Lerp(WHITE_HOT, values[2])
		end),
		TextTransparency = fadeFrom(0),
		TextSize = if L.short then 22 else 30,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		ZIndex = 7,
	}))

	-- the pour: molten metal running along a channel, white-hot at its head
	local sparkFrames = {}
	for index = 1, SPARK_COUNT do
		local function sample(now)
			local spark = sparks.current[index]
			local age = now - spark.born
			if spark.born < 0 or age > spark.life or age < 0 then
				return nil, spark
			end
			return age, spark
		end
		sparkFrames["s" .. index] = React.createElement("frame", {
			Size = tick:map(function(now)
				local age, spark = sample(now)
				local d = if age then math.max(1, 3.5 * (1 - age / spark.life)) else 0
				return UDim2.fromOffset(d, d)
			end),
			Position = tick:map(function(now)
				local age, spark = sample(now)
				if not age then
					return UDim2.fromScale(0, 0.5)
				end
				return UDim2.new(spark.head, spark.vx * age, 0.5, spark.vy * age + 140 * age * age)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE_HOT,
			BackgroundTransparency = tick:map(function(now)
				local age, spark = sample(now)
				return if age then clamp01(age / spark.life) else 1
			end),
			BorderSizePixel = 0,
			ZIndex = 9,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	local channelPos, channelSize = at(L.channelY, 8)
	local channel = React.createElement("frame", {
		Name = "BootPour",
		Position = channelPos,
		Size = channelSize,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = fadeFrom(0.1),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), React.createElement("uistroke", {
		Color = Palette.line,
		Transparency = fadeFrom(0.35),
		Thickness = 1,
	}), React.createElement("frame", {
		Name = "Metal",
		Size = shownProgress:map(function(shown)
			return UDim2.fromScale(math.max(0.012, shown), 1)
		end),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = fadeFrom(0),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), React.createElement("uigradient", {
		Color = flash:map(function(f)
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Palette.ember:Lerp(WHITE_HOT, f)),
				ColorSequenceKeypoint.new(0.8, Palette.mango:Lerp(WHITE_HOT, f)),
				ColorSequenceKeypoint.new(1, WHITE_HOT),
			})
		end),
	}), React.createElement("frame", {
		-- slag ripples drifting back along the surface
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE_HOT,
		BackgroundTransparency = fadeFrom(0),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), React.createElement("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.7),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.55, 0.78),
			NumberSequenceKeypoint.new(0.62, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = tick:map(function(now)
			return Vector2.new(-((now * 0.35) % 1), 0)
		end),
	}))), React.createElement("frame", {
		Name = "Head",
		Size = tick:map(function(now)
			local d = 26 + math.sin(now * 7) * 3
			return UDim2.fromOffset(d, d)
		end),
		Position = shownProgress:map(function(shown)
			return UDim2.fromScale(math.max(0.012, shown), 0.5)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = fadeFrom(0.72),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), React.createElement("frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = WHITE_HOT,
		BackgroundTransparency = fadeFrom(0),
		BorderSizePixel = 0,
		ZIndex = 9,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))), sparkFrames)

	-- the exact thing loading right now
	local itemPos, itemSize = at(L.itemY, 16)
	local itemLine = React.createElement("textlabel", {
		Position = itemPos,
		Size = itemSize,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = tick:map(function()
			return view.current.item
		end),
		TextColor3 = Palette.muted,
		TextTransparency = React.joinBindings({ tick, hidden }):map(function(values)
			return clamp01(0.15 + (1 - easeOut((values[1] - view.current.itemAt) / 0.16)) * 0.6 + values[2])
		end),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	})

	-- stations: every part of the game, with its real count; a check stamps in when one is done
	local stationNodes = {}
	local perRow = if L.twoRows then 4 else #Ledger.STATIONS
	local cellW = column / perRow
	for index, station in Ledger.STATIONS do
		local key = station.key
		local row = math.floor((index - 1) / perRow)
		local col = (index - 1) % perRow
		local function readRow()
			for _, entry in view.current.stations do
				if entry.key == key then
					return entry
				end
			end
			return nil
		end
		local function stampScale(now)
			local doneAt = view.current.doneAt[key]
			if doneAt == nil then
				return 0
			end
			return easeOut((now - doneAt) / 0.28)
		end
		stationNodes[key] = React.createElement("frame", {
			Size = UDim2.fromOffset(cellW - 8, L.stationRow),
			Position = UDim2.fromOffset(col * cellW, row * (L.stationRow + 8)),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Palette.line,
			BackgroundTransparency = fadeFrom(0.4),
			BorderSizePixel = 0,
			ZIndex = 6,
		}, React.createElement("frame", {
			Size = tick:map(function()
				local entry = readRow()
				return UDim2.fromScale(if entry then entry.fraction else 0, 1)
			end),
			BackgroundColor3 = tick:map(function()
				local entry = readRow()
				return if entry and entry.done then Palette.cream else Palette.mango
			end),
			BackgroundTransparency = fadeFrom(0),
			BorderSizePixel = 0,
			ZIndex = 7,
		})), React.createElement(CheckGlyph, {
			position = UDim2.new(0, 0, 0, 13),
			color = Palette.cream,
			scale = tick:map(function(now)
				local s = stampScale(now)
				return if s <= 0 then 0 else 1 + (1 - s) * 0.6
			end),
			transparency = fadeFrom(0),
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, -14, 0, 14),
			Position = tick:map(function(now)
				return UDim2.fromOffset(if view.current.doneAt[key] then 15 * stampScale(now) else 0, 6)
			end),
			BackgroundTransparency = 1,
			Text = station.label,
			TextColor3 = tick:map(function(now)
				local entry = readRow()
				if entry and entry.done then
					return Palette.cream
				end
				local active = view.current.status == station.verb
				return if active then Palette.mango:Lerp(WHITE_HOT, (math.sin(now * 5) + 1) * 0.2) else Palette.muted
			end),
			TextTransparency = fadeFrom(0),
			TextSize = 11,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		}), not L.short and React.createElement("textlabel", {
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.fromOffset(0, 21),
			BackgroundTransparency = 1,
			Text = tick:map(function()
				local entry = readRow()
				if entry == nil then
					return ""
				end
				if entry.total <= 1 or entry.done then
					return if entry.done then "done" else "waiting"
				end
				return `{math.floor(entry.loaded)} / {math.floor(entry.total)}`
			end),
			TextColor3 = Palette.muted,
			TextTransparency = fadeFrom(0.3),
			TextSize = 10,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		}))
	end
	local stationsPos, stationsSize = at(L.stationsY, L.stationsH)
	local stationsRow = React.createElement("frame", {
		Position = stationsPos,
		Size = stationsSize,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, stationNodes)

	-- the tip: numbered, word by word, with a fuse burning down to the next one; tap for the next
	local tipText = if stalled then "Still loading. Your save is safe." else LOADING_TIPS[tip.index] or ""
	local tipBlock = React.createElement("textbutton", {
		Position = UDim2.new(0.5, 0, 0, L.tipTop),
		Size = UDim2.fromOffset(math.min(column, 560), L.tipHeight),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = not exiting,
		ZIndex = 7,
		[React.Event.Activated] = advanceTip,
	}, React.createElement("textlabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = if stalled then "TAKING A WHILE" else `TIP {tip.index} OF {#LOADING_TIPS}`,
		TextColor3 = Palette.mango,
		TextTransparency = fadeFrom(0.1),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 8,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, L.tipLines * (L.tipSize + 6)),
		Position = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, React.createElement(TipText, {
		key = tostring(tip.index) .. ":" .. tostring(tip.bornAt) .. (if stalled then ":stall" else ""),
		text = tipText,
		size = L.tipSize,
		maxWidth = math.min(column, 560),
		bornAt = tip.bornAt,
		leaveAt = tip.leaveAt,
		tick = tick,
		hidden = hidden,
	})), not stalled and React.createElement("frame", {
		Size = UDim2.fromOffset(120, 2),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = fadeFrom(0.5),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("frame", {
		Size = tick:map(function(now)
			return UDim2.fromScale(1 - clamp01((now - tip.bornAt) / TIP_SECONDS), 1)
		end),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = fadeFrom(0.1),
		BorderSizePixel = 0,
		ZIndex = 9,
	})))

	-- the cover lifts from the bottom up, a glowing seam running along its edge
	local seam = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = wipe:map(function(w)
			return UDim2.fromScale(0, 1 - w)
		end),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = WHITE_HOT,
		BorderSizePixel = 0,
		Visible = wipe:map(function(w)
			return w > 0.001 and w < 0.999
		end),
		ZIndex = 30,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 29,
	}, React.createElement("uigradient", {
		Rotation = -90,
		Transparency = NumberSequence.new(0.35, 1),
	})))

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BorderSizePixel = 0,
		Active = not exiting and not gone,
		ClipsDescendants = true,
		ZIndex = 420,
		Visible = wipe:map(function(w)
			return w < 0.995
		end),
	}, React.createElement("uigradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.void),
			ColorSequenceKeypoint.new(0.55, Palette.night),
			ColorSequenceKeypoint.new(1, Palette.void),
		}),
		Transparency = wipe:map(function(w)
			if w <= 0.001 then
				return NumberSequence.new(0)
			elseif w >= 0.999 then
				return NumberSequence.new(1)
			end
			local edge = 1 - w
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(math.max(0.001, edge - 0.002), 0),
				NumberSequenceKeypoint.new(math.min(0.999, edge), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end),
	}), React.createElement("frame", {
		-- everything inside lifts away with the cover
		Size = UDim2.fromScale(1, 1),
		Position = wipe:map(function(w)
			return UDim2.fromScale(0, -w)
		end),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, forgeGlow, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, embers), wordmark, statusRow, channel, itemLine, stationsRow, tipBlock, _version ~= nil and React.createElement("textlabel", {
		Size = UDim2.fromOffset(160, 14),
		Position = UDim2.new(1, -16, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Text = `v{_version}`,
		TextColor3 = Palette.line,
		TextTransparency = fadeFrom(0),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
	})), seam)
end
return {
	bootChecklistReady = bootChecklistReady,
	bootProgress = bootProgress,
	BootScreen = BootScreen,
	layoutFor = layoutFor,
	wrapWords = wrapWords,
	BOOT_MODULE_TIMEOUT = BOOT_MODULE_TIMEOUT,
	BOOT_MOTION = BOOT_MOTION,
}
end

__defs["LoadingDots"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.CoreKit)("theme").Palette
local DOTS = { 0, 1, 2, 3 }
local CYCLE = 0.86
local COUNT = 4
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function pulse(elapsed, index)
	local travel = ((elapsed / CYCLE) % 1) * COUNT
	local delta = math.abs(travel - index)
	local wrap = math.min(delta, COUNT - delta)
	local falloff = clamp01(1 - wrap)
	return falloff * falloff * (3 - 2 * falloff)
end
local function LoadingDots(_param)
	local clock = _param.clock
	local leaving = _param.leaving
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	local width = if compact then 92 else 112
	local height = if compact then 22 else 26
	local gap = if compact then 18 else 22
	local size = if compact then 7 else 8
	local lift = if compact then 5 else 6
	local center = width / 2
	local restY = height * 0.55
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave
	local _newValue = table.create(#DOTS)
	local _callback = function(index)
		local x = center + (index - 1.5) * gap
		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(_param_1)
			local elapsed = _param_1.clock
			local exit = _param_1.leaving
			local fade = clamp01(exit)
			if reducedMotion or ready then
				return {
					y = restY,
					scale = 0.72,
					alpha = 0.45,
					mix = 0,
					fade = fade,
				}
			end
			local amount = pulse(elapsed, index)
			return {
				y = restY - amount * lift,
				scale = 0.62 + amount * 0.38,
				alpha = 0.28 + amount * 0.72,
				mix = amount,
				fade = fade,
			}
		end)
		return React.createElement("frame", {
			key = `load-dot-{index}`,
			Size = motion:map(function(value)
				return UDim2.fromOffset(size * value.scale, size * value.scale)
			end),
			Position = motion:map(function(value)
				return UDim2.fromOffset(x, value.y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = motion:map(function(value)
				return Palette.cream:Lerp(Palette.cyan, value.mix)
			end),
			BackgroundTransparency = motion:map(function(value)
				return clamp01(1 - value.alpha + value.fade)
			end),
			BorderSizePixel = 0,
			ZIndex = 527,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in DOTS do
		_newValue[_k] = _callback(_v, _k - 1, DOTS)
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 525,
	}, _newValue)
end
return {
	LoadingDots = LoadingDots,
}
end

__defs["SoftShutdownScreen"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local WORDMARK_ASSET = require(script.Parent.ArtKit)("Icon").WORDMARK_ASSET
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local LoadingDots = __load("LoadingDots").LoadingDots
local Palette = require(script.Parent.CoreKit)("theme").Palette
local function phaseName(phase)
	if phase == "Teleporting" then
		return "Teleporting"
	end
	if phase == "Waiting" then
		return "Waiting"
	end
	return "Saving"
end
local function titleFor(phase)
	if phase == "Teleporting" then
		return "JOINING NEW SERVER"
	end
	if phase == "Waiting" then
		return "RECONNECTING"
	end
	return "SAVING YOUR PROGRESS"
end
local function statusFor(phase)
	if phase == "Teleporting" then
		return "Save locked in. Moving you to the fresh server."
	end
	if phase == "Waiting" then
		return "Stay here. We'll move you when the new server is ready."
	end
	return "Don't leave yet. Saving your progress."
end
local function cueFor(phase)
	if phase == "Teleporting" then
		return "travel"
	end
	if phase == "Waiting" then
		return "systemAlert"
	end
	return "bootStart"
end
local function SoftShutdownScreen(_param)
	local centerY = if useViewport().height < 420 then 0.32 else 0.44
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local phase = phaseName(state.phase)
	local teleporting = phase == "Teleporting"
	local waiting = phase == "Waiting"
	local clock, setClock = React.useBinding(0)
	local spinClock = React.useRef(0)
	local barPulse, setBarPulse = React.useBinding(0.35)
	React.useEffect(function()
		spinClock.current = 0
		setClock(0)
		if reducedMotion then
			setBarPulse(if teleporting then 1 elseif waiting then 0.55 else 0.4)
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function(dt)
			spinClock.current += dt
			setClock(spinClock.current)
			local wave = (math.sin(spinClock.current * 2.1) + 1) * 0.5
			if teleporting then
				setBarPulse(0.72 + wave * 0.28)
			elseif waiting then
				setBarPulse(0.4 + wave * 0.35)
			else
				setBarPulse(0.28 + wave * 0.32)
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { phase, reducedMotion, setClock, teleporting, waiting })
	React.useEffect(function()
		Audio:setScene("shutdown")
		Audio:play(cueFor(phase))
		return function()
			return Audio:setScene("default")
		end
	end, { phase })
	local phaseAccent = if teleporting then Palette.mint elseif waiting then Palette.mango else Palette.cyan
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Active = true,
		Selectable = false,
		ZIndex = 900,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(112, 26),
		Position = UDim2.new(0.5, 0, centerY, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 903,
	}, React.createElement(LoadingDots, {
		clock = clock,
		ready = teleporting,
		reducedMotion = reducedMotion,
		compact = false,
	})), React.createElement("imagelabel", {
		Name = "ShutdownWordmark",
		Size = UDim2.new(0.8, 0, 0, 32),
		Position = UDim2.new(0.5, 0, centerY, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = WORDMARK_ASSET,
		ImageTransparency = 0.08,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 904,
	}), React.createElement("textlabel", {
		Size = UDim2.new(0.9, 0, 0, 18),
		Position = UDim2.new(0.5, 0, centerY, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = titleFor(phase),
		TextColor3 = Color3.fromRGB(190, 174, 178),
		TextTransparency = 0.18,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(220, 4),
		Position = UDim2.new(0.5, 0, centerY, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(46, 36, 50),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 904,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = barPulse:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.08, 1), 0, 1, 0)
		end),
		BackgroundColor3 = phaseAccent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("textlabel", {
		Name = "ShutdownStatus",
		Size = UDim2.new(0.9, 0, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -52),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = statusFor(phase),
		TextWrapped = true,
		TextColor3 = Palette.creamSoft,
		TextTransparency = 0.08,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("textlabel", {
		Name = "ShutdownMessage",
		Size = UDim2.new(0.9, 0, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = state.message or "",
		Visible = state.message ~= nil and state.message ~= "",
		TextColor3 = Palette.muted,
		TextTransparency = 0.08,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		ZIndex = 904,
	}))
end
return {
	SoftShutdownScreen = SoftShutdownScreen,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
