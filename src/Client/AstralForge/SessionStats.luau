--!nonstrict
-- "This session": what you've done since you joined, counted on the client and shown as a live card.
-- Values bump when they change and play time ticks every second.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local theme = require(script.Parent.CoreKit)("theme")
local format = require(script.Parent.CoreKit)("format")
local motion = require(script.Parent.MotionKit)("motion")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local P = theme.Palette
local h = React.createElement

local SessionStats = {}

local startedAt = os.clock()
local counts = { collects = 0, overcharges = 0, crits = 0, claims = 0, upgrades = 0, bestCombo = 0 }
local fluxCollected = 0 -- a number in log space would lose precision; we keep the display string too
local fluxText = "0"
local listeners = {}

local function notify()
	for listener in listeners do
		task.spawn(listener)
	end
end

function SessionStats.bump(key: string, amount: number?)
	if counts[key] == nil then
		return
	end
	counts[key] += amount or 1
	notify()
end

function SessionStats.best(key: string, value: number)
	if counts[key] ~= nil and value > counts[key] then
		counts[key] = value
		notify()
	end
end

-- collected flux, kept as the biggest-number-safe sum the formatter can show
local omegaModule = nil
local function omega()
	if omegaModule == nil then
		local ok, module = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
		end)
		omegaModule = if ok then module else false
	end
	return omegaModule or nil
end
function SessionStats.addFlux(amount)
	local O = omega()
	if O == nil or amount == nil then
		return
	end
	local ok, total = pcall(O.Add, fluxCollected, amount)
	if ok then
		fluxCollected = O.Persist(total)
		fluxText = format.compactNumber(fluxCollected)
		notify()
	end
end

local function useStats()
	local _, setRevision = React.useState(0)
	React.useEffect(function()
		local listener = function()
			setRevision(function(n) return n + 1 end)
		end
		listeners[listener] = true
		return function()
			listeners[listener] = nil
		end
	end, {})
	return counts
end

local function clockText(seconds)
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	end
	return string.format("%dm %02ds", s // 60, s % 60)
end

local function Stat(props)
	local flash = motion.useFlash(props.value, props.reducedMotion, 0.5)
	return h("frame", {
		Size = UDim2.new(0, 0, 0, 44),
		LayoutOrder = props.order,
		BackgroundColor3 = P.panelSoft,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, h("uiflexitem", { FlexMode = Enum.UIFlexMode.Fill }), h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", {
		Color = props.accent,
		Thickness = 1,
		Transparency = flash:map(function(v) return 0.75 - v * 0.65 end),
	}), h("uiscale", {
		Scale = flash:map(function(v) return 1 + v * 0.05 end),
	}), h(Icon, {
		kind = props.icon,
		color = P.cream,
		accent = props.accent,
		size = 20,
		position = UDim2.new(0, 10, 0.5, -10),
		spin = false,
	}), h("textlabel", {
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.fromOffset(36, 5),
		BackgroundTransparency = 1,
		Text = if props.live then props.live else tostring(props.text),
		TextColor3 = P.cream,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	}, h("uitextsizeconstraint", { MaxTextSize = 15, MinTextSize = 10 })), h("textlabel", {
		Size = UDim2.new(1, -40, 0, 14),
		Position = UDim2.fromOffset(36, 24),
		BackgroundTransparency = 1,
		Text = props.label,
		TextColor3 = P.muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	}, h("uitextsizeconstraint", { MaxTextSize = 11, MinTextSize = 8 })))
end

-- the card; `columns` rows of stats fill the given size
function SessionStats.Card(props)
	local stats = useStats()
	local clock = motion.useClock(true, 1, 86400, true)
	local columns = props.columns or 4
	local entries = {
		{ key = "time", label = "Played", icon = "Timer", accent = P.cyan, live = clock:map(function() return clockText(os.clock() - startedAt) end) },
		{ key = "flux", label = "Flux collected", icon = "Flux", accent = P.cyan, text = fluxText, value = fluxText },
		{ key = "collects", label = "Vault collects", icon = "Vault", accent = P.green, text = stats.collects },
		{ key = "overcharges", label = "Overcharges", icon = "Overcharge", accent = P.mango, text = stats.overcharges },
		{ key = "crits", label = "Critical taps", icon = "Boost", accent = P.mango, text = stats.crits },
		{ key = "combo", label = "Best combo", icon = "Wave", accent = P.pink, text = `x{stats.bestCombo}` },
		{ key = "claims", label = "Rewards claimed", icon = "Rewards", accent = P.pink, text = stats.claims },
		{ key = "upgrades", label = "Upgrades bought", icon = "Forge", accent = P.violet, text = stats.upgrades },
	}
	local rows = math.ceil(#entries / columns)
	local grid = {
		layout = h("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for row = 1, rows do
		local cells = {
			layout = h("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			}),
		}
		for col = 1, columns do
			local entry = entries[(row - 1) * columns + col]
			if entry then
				cells[entry.key] = h(Stat, {
					order = col,
					label = entry.label,
					icon = entry.icon,
					accent = entry.accent,
					text = entry.text,
					live = entry.live,
					value = entry.value or entry.text,
					reducedMotion = props.reducedMotion,
				})
			end
		end
		grid["row" .. row] = h("frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = row }, cells)
	end
	return h("frame", {
		Size = UDim2.new(1, 0, 0, rows * 52 - 8),
		Position = props.position,
		BackgroundTransparency = 1,
	}, grid)
end

function SessionStats.height(columns: number)
	return math.ceil(8 / columns) * 52 - 8
end

return SessionStats
