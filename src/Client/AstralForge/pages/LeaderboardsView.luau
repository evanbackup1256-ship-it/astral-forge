local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _Icon = require(script.Parent.Parent.Icon)
local Icon = _Icon.Icon
local PlayerMark = _Icon.PlayerMark
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local _motion = require(script.Parent.Parent.motion)
local useEntrance = _motion.useEntrance
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local EmptyState = _ui.EmptyState
local Panel = _ui.Panel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local BOARDS = { {
	id = "Flux",
	label = "Lifetime Flux",
	short = "FLUX",
	description = "Every unit of flux forged across all realities.",
	icon = "Flux",
	accent = Palette.cyan,
}, {
	id = "Rebirths",
	label = "Most Rebirths",
	short = "REBIRTHS",
	description = "Pilots who have restarted the forge the most.",
	icon = "Rebirth",
	accent = Palette.violet,
}, {
	id = "PlayTime",
	label = "Time Played",
	short = "PLAYTIME",
	description = "Total time spent playing.",
	icon = "Command",
	accent = Palette.mint,
}, {
	id = "Dust",
	label = "Most Stardust",
	short = "DUST",
	description = "Current stardust reserves held by each pilot.",
	icon = "Dust",
	accent = Palette.mango,
}, {
	id = "Cores",
	label = "Most Cores",
	short = "CORES",
	description = "Current astral cores ready for permanent upgrades.",
	icon = "Core",
	accent = Palette.violet,
}, {
	id = "Domain",
	label = "Domain Rank",
	short = "DOMAIN",
	description = "The deepest realities established through mega rebirths.",
	icon = "Domain",
	accent = Palette.pink,
}, {
	id = "Worlds",
	label = "Farthest World",
	short = "WORLDS",
	description = "The farthest forge worlds unlocked.",
	icon = "World",
	accent = Palette.green,
} }
local _array = {}
local _length = #_array
-- ▼ ReadonlyArray.map ▼
local _newValue = table.create(#BOARDS)
local _callback = function(board)
	return {
		id = board.id,
		label = board.short,
		icon = board.icon,
		accent = board.accent,
	}
end
for _k, _v in BOARDS do
	_newValue[_k] = _callback(_v, _k - 1, BOARDS)
end
-- ▲ ReadonlyArray.map ▲
local _Length = #_newValue
table.move(_newValue, 1, _Length, _length + 1, _array)
_length += _Length
_array[_length + 1] = {
	id = "Guilds",
	label = "GUILDS",
	icon = "Crew",
	accent = Palette.violet,
}
local RANK_TABS = _array
local ROW_H = 54
local ROW_GAP = 6
local AUTO_REFRESH_SECONDS = 15
local function metaFor(id)
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(board)
		return board.id == id
	end
	local _result
	for _i, _v in BOARDS do
		if _callback_1(_v, _i - 1, BOARDS) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result
	if _condition == nil then
		_condition = BOARDS[1]
	end
	return _condition
end
local function formatValue(id, value)
	if id == "PlayTime" then
		local _value = value
		return clockText(if type(_value) == "number" then value else asFlux(value))
	end
	if id == "Worlds" then
		return `WORLD {math.max(1, math.floor(asFlux(value)))}`
	end
	if id == "Domain" then
		local rank = math.floor(asFlux(value))
		return if rank > 0 then `RANK {rank}` else "UNRANKED"
	end
	return compactNumber(value)
end
local function scoreCounts(id, value)
	if id == "Worlds" then
		return asFlux(value) > 1
	end
	return asFlux(value) > 0
end
local function ownValue(state, id)
	if id == "Flux" then
		return state.LifetimeCash
	end
	if id == "Rebirths" then
		return state.Rebirths
	end
	if id == "PlayTime" then
		local _result = state.Stats
		if _result ~= nil then
			_result = _result.PlayTime
		end
		local _condition = _result
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
	if id == "Dust" then
		return state.Stardust
	end
	if id == "Cores" then
		return state.Cores
	end
	if id == "Domain" then
		local _result = state.Domain
		if _result ~= nil then
			_result = _result.Rank
		end
		local _condition = _result
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
	return state.Zone
end
local SCOPE_TABS = { {
	id = "Global",
	label = "GLOBAL",
	icon = "Leaderboard",
}, {
	id = "Server",
	label = "THIS SERVER",
	icon = "Command",
} }
local function serverValueFor(summary, id)
	if id == "Flux" then
		local _condition = summary.LifetimeCash
		if _condition == nil then
			_condition = 0
		end
		return asFlux(_condition)
	end
	if id == "Rebirths" then
		return summary.Rebirths
	end
	if id == "PlayTime" then
		local _condition = summary.PlayTime
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
	if id == "Dust" then
		local _condition = summary.Stardust
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
	if id == "Cores" then
		local _condition = summary.Cores
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
	if id == "Domain" then
		local _condition = summary.DomainRank
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
	return summary.CurrentZone
end
local function serverEntries(players, id)
	local _array_1 = {}
	local _length_1 = #_array_1
	table.move(players, 1, #players, _length_1 + 1, _array_1)
	table.sort(_array_1, function(left, right)
		return serverValueFor(left, id) > serverValueFor(right, id)
	end)
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#_array_1)
	local _callback_1 = function(summary)
		return {
			UserId = summary.UserId,
			Name = summary.DisplayName,
			Value = serverValueFor(summary, id),
			Category = id,
		}
	end
	for _k, _v in _array_1 do
		_newValue_1[_k] = _callback_1(_v, _k - 1, _array_1)
	end
	-- ▲ ReadonlyArray.map ▲
	return _newValue_1
end
local function medalColor(rank, accent)
	if rank == 1 then
		return Palette.mango
	end
	if rank == 2 then
		return Palette.creamSoft
	end
	if rank == 3 then
		return Palette.coral
	end
	return accent
end
local function PodiumCard(_param)
	local entry = _param.entry
	local rank = _param.rank
	local meta = _param.meta
	local width = _param.width
	local height = _param.height
	local reducedMotion = _param.reducedMotion
	local reveal = useStagger(rank - 1, reducedMotion, 0.055, 0.28)
	local pulse = usePulse(rank == 1 and entry ~= nil and not reducedMotion, 1.8)
	local accent = medalColor(rank, meta.accent)
	local surface = if rank == 1 and entry ~= nil then darken(accent, 0.84) else Palette.panel
	local nameColor = ensureContrast(surface, Palette.cream)
	local chipFill = Palette.void
	local chipText = ensureContrast(chipFill, accent)
	local rankText = ensureContrast(darken(accent, 0.68), accent)
	local markSize = if height < 140 then 34 else 40
	return React.createElement(Panel, {
		size = UDim2.new(width.X.Scale, width.X.Offset, 0, height),
		accent = accent,
		background = surface,
		padding = 10,
		reveal = reveal,
		reducedMotion = reducedMotion,
		highlight = rank == 1 and entry ~= nil,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(34, 24),
		BackgroundColor3 = darken(accent, 0.68),
		BackgroundTransparency = if rank == 1 then pulse:map(function(amount)
			return 0.04 + (1 - amount) * 0.08
		end) else 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = `#{rank}`,
		size = 14,
		color = rankText,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 3,
	})), if entry ~= nil then React.createElement(React.Fragment, nil, React.createElement(PlayerMark, {
		userId = entry.UserId,
		accent = accent,
		size = markSize,
		position = UDim2.new(0.5, 0, 0, 2),
		anchorPoint = Vector2.new(0.5, 0),
	}), React.createElement(Text, {
		value = entry.Name,
		size = 13,
		color = nameColor,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, markSize + 6),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -8, 0, 32),
		Position = UDim2.new(0, 4, 1, -34),
		BackgroundColor3 = chipFill,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = formatValue(meta.id, entry.Value),
		size = 16,
		color = chipText,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 11,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 5,
	}))) else React.createElement(React.Fragment, nil, React.createElement(Icon, {
		kind = "Leaderboard",
		color = ensureContrast(surface, Palette.creamSoft),
		accent = accent,
		size = 32,
		spin = false,
		position = UDim2.new(0.5, -16, 0, 28),
	}), React.createElement(Text, {
		value = "OPEN SLOT",
		size = 12,
		color = ensureContrast(surface, Palette.creamSoft),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 66),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Text, {
		value = "Claim this place",
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 1, -28),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})))
end
local function RankRow(_param)
	local entry = _param.entry
	local rank = _param.rank
	local meta = _param.meta
	local isLocal = _param.isLocal
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = rank
	end
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local accent = if isLocal then Palette.green else medalColor(rank, meta.accent)
	local reveal = useStagger(math.min(rank, 9), reducedMotion, 0.025, 0.18)
	local surface = if isLocal then darken(Palette.green, 0.88) else Palette.panel
	local nameColor = ensureContrast(surface, Palette.cream)
	local valueColor = ensureContrast(surface, accent)
	-- Rank + avatar + value columns used to reserve a combined 296px (40 rank / 86 name-start /
	-- 248 name-end-gap / 160 value) regardless of viewport -- fine on a 1280px desktop row, but on
	-- a 320-360px phone that left the name column at a negative or near-zero width (86 to
	-- width-248 is already negative below 334px), so the player's actual name could render fully
	-- clipped to nothing. Mobile keeps the same one-line row with narrower rank/avatar/value
	-- columns so the name gets real room instead of none. Rows are stacked by UIListLayout —
	-- no absolute Y — so scaffold section height stays honest on short phones.
	local rankW = if stack then 26 else 40
	local avatarSize = if stack then 28 else 34
	local avatarX = if stack then rankW + 4 else 44
	local nameX = if stack then avatarX + avatarSize + 8 else 86
	local valueW = if stack then 84 else 160
	local nameReserve = if stack then -(valueW + 12) else -248
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, ROW_H),
		layoutOrder = layoutOrder,
		accent = accent,
		background = surface,
		padding = 10,
		reveal = reveal,
		reducedMotion = reducedMotion,
		highlight = isLocal,
		clips = false,
	}, React.createElement(Text, {
		value = `#{rank}`,
		size = if stack then 12 else 15,
		color = valueColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		sizeConstraint = UDim2.new(0, rankW, 1, 0),
	}), React.createElement(PlayerMark, {
		userId = entry.UserId,
		accent = accent,
		size = avatarSize,
		position = UDim2.fromOffset(avatarX, if stack then 7 else 4),
	}), React.createElement(Text, {
		value = entry.Name,
		size = if stack then 13 else 15,
		color = nameColor,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(nameX, 8),
		sizeConstraint = UDim2.new(1, nameReserve, 0, 28),
	}), React.createElement(Text, {
		value = formatValue(meta.id, entry.Value),
		size = if stack then 13 else 16,
		color = valueColor,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -(valueW + 8), 0, 8),
		sizeConstraint = UDim2.new(0, valueW, 0, 28),
	}))
end
local GUILD_ROW_H = 52
local GUILD_ROWS_SHOWN = 5
local GUILD_ACCENT = Palette.violet
--* Featured guild board: your hall's standing plus the top halls, above the personal boards. 
local function GuildSpotlight(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local entries, setEntries = React.useState({})
	local loading, setLoading = React.useState(true)
	local alive = React.useRef(true)
	React.useEffect(function()
		alive.current = true
		local timer
		local pull
		pull = function()
			dispatch("GetGuildLeaderboard", {
				Page = 1,
			}, function(response)
				if not alive.current then
					return nil
				end
				setLoading(false)
				if response.ok and response.GuildLeaderboard ~= nil then
					setEntries(response.GuildLeaderboard)
				end
			end)
			timer = task.delay(AUTO_REFRESH_SECONDS * 2, pull)
		end
		pull()
		return function()
			alive.current = false
			if timer ~= nil then
				task.cancel(timer)
			end
		end
	end, { dispatch })
	local _result = state.Guild
	if _result ~= nil then
		_result = _result.Id
	end
	local _condition = _result
	if _condition == nil then
		_condition = ""
	end
	local myGuildId = _condition
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_1 = {}
	local _callback_1 = function(entry)
		return entry.Activity > 0
	end
	local _length_1 = 0
	for _k, _v in entries do
		if _callback_1(_v, _k - 1, entries) == true then
			_length_1 += 1
			_newValue_1[_length_1] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local ranked = _newValue_1
	local _result_1
	if myGuildId ~= "" then
		-- ▼ ReadonlyArray.findIndex ▼
		local _callback_2 = function(entry)
			return entry.Id == myGuildId
		end
		local _result_2 = -1
		for _i, _v in ranked do
			if _callback_2(_v, _i - 1, ranked) == true then
				_result_2 = _i - 1
				break
			end
		end
		-- ▲ ReadonlyArray.findIndex ▲
		_result_1 = _result_2
	else
		_result_1 = -1
	end
	local myIndex = _result_1
	local myRank = if myIndex >= 0 then myIndex + 1 else nil
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_2 = {}
	local _callback_2 = function(_, index)
		return index < GUILD_ROWS_SHOWN
	end
	local _length_2 = 0
	for _k, _v in ranked do
		if _callback_2(_v, _k - 1, ranked) == true then
			_length_2 += 1
			_newValue_2[_length_2] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local shown = _newValue_2
	local heroSurface = darken(GUILD_ACCENT, 0.9)
	local heroTitle = ensureContrast(heroSurface, Palette.cream)
	local heroBody = ensureContrast(heroSurface, Palette.creamSoft)
	local heroEyebrow = ensureContrast(heroSurface, GUILD_ACCENT)
	local recordFill = Palette.void
	local recordLabel = ensureContrast(recordFill, Palette.muted)
	local recordValue = ensureContrast(recordFill, GUILD_ACCENT)
	local recordRank = ensureContrast(recordFill, if myRank ~= nil then Palette.green else Palette.muted)
	local heroH = if stack then 156 else 148
	local listTop = heroH + 34
	local _exp = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, heroH),
		accent = GUILD_ACCENT,
		background = heroSurface,
		padding = if stack then 12 else 16,
		highlight = myRank ~= nil and myRank <= 3,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(if stack then 44 else 56, if stack then 44 else 56),
		BackgroundColor3 = darken(GUILD_ACCENT, 0.72),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = GUILD_ACCENT,
		Thickness = 2,
		Transparency = 0.18,
	}), React.createElement(Icon, {
		kind = "Crew",
		color = ensureContrast(darken(GUILD_ACCENT, 0.72), Palette.cream),
		accent = GUILD_ACCENT,
		size = if stack then 44 else 56,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = "GUILD RANKINGS",
		size = 9,
		color = heroEyebrow,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(if stack then 56 else 72, 0),
		sizeConstraint = UDim2.new(1, if stack then -56 else -260, 0, 14),
	}), React.createElement(Text, {
		value = "Top Halls",
		size = if stack then 18 else 24,
		color = heroTitle,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(if stack then 56 else 72, 16),
		sizeConstraint = UDim2.new(1, if stack then -56 else -260, 0, if stack then 24 else 32),
	}), React.createElement(Text, {
		value = "Guilds ranked by everything their members bank and build together.",
		size = if stack then 10 else 12,
		color = heroBody,
		wrap = true,
		position = UDim2.fromOffset(if stack then 56 else 72, if stack then 42 else 50),
		sizeConstraint = UDim2.new(1, if stack then -56 else -280, 0, if stack then 28 else 36),
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 52) else UDim2.fromOffset(220, 76),
		Position = if stack then UDim2.new(0, 0, 1, -54) else UDim2.new(1, -220, 0.5, -38),
		BackgroundColor3 = recordFill,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = GUILD_ACCENT,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement(Text, {
		value = "YOUR GUILD",
		size = 8,
		color = recordLabel,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(12, 4),
		sizeConstraint = UDim2.new(1, -24, 0, 12),
	}), React.createElement(Text, {
		value = if state.Guild ~= nil and state.Guild.Id ~= "" then `[{state.Guild.Tag}] {compactNumber(state.Guild.Activity)}` else "NO GUILD YET",
		size = if stack then 15 else 20,
		color = recordValue,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(12, 16),
		sizeConstraint = UDim2.new(1, -24, 0, 20),
	}), React.createElement(Text, {
		value = if myRank ~= nil then `GLOBAL POSITION #{myRank}` elseif state.Guild ~= nil and state.Guild.Id ~= "" then "BANK MORE TO ENTER THE TOP 20" else "JOIN A HALL TO COMPETE",
		size = 8,
		color = recordRank,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.new(0, 12, 1, -16),
		sizeConstraint = UDim2.new(1, -24, 0, 12),
	})))
	local _exp_1 = React.createElement(Text, {
		value = if loading and #shown == 0 then "LOADING GUILD RANKS…" else "TOP HALLS",
		size = 10,
		color = ensureContrast(Palette.night, Palette.muted),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(0, heroH + 12),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _result_2
	if #shown == 0 then
		_result_2 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, GUILD_ROW_H),
			Position = UDim2.fromOffset(0, listTop),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Text, {
			value = if loading then "" else "No guilds have banked anything yet.",
			size = 11,
			color = ensureContrast(Palette.night, Palette.muted),
			sizeConstraint = UDim2.fromScale(1, 1),
		}))
	else
		-- ▼ ReadonlyArray.map ▼
		local _newValue_3 = table.create(#shown)
		local _callback_3 = function(entry, index)
			local isMine = entry.Id == myGuildId
			local rank = index + 1
			local rowAccent = if isMine then Palette.green else medalColor(rank, GUILD_ACCENT)
			local surface = if isMine then darken(Palette.green, 0.88) else Palette.panel
			-- Same fixed-column bug as RankRow above: 112 (tag badge end) to width-280 (value
			-- column start) went negative on anything narrower than ~392px, clipping the guild
			-- name to nothing on every phone. Mobile gets a narrower rank/tag/value budget so
			-- the name column stays real width instead of negative.
			local gRankW = if stack then 22 else 40
			local gTagX = if stack then gRankW + 4 else 44
			local gTagW = if stack then 46 else 60
			local gNameX = if stack then gTagX + gTagW + 8 else 112
			local gValueW = if stack then 74 else 152
			local gNameReserve = if stack then -(gValueW + 12) else -280
			return React.createElement(Panel, {
				key = `guild-{entry.Id}`,
				size = UDim2.new(1, 0, 0, GUILD_ROW_H),
				position = UDim2.fromOffset(0, listTop + index * (GUILD_ROW_H + ROW_GAP)),
				accent = rowAccent,
				background = surface,
				padding = 10,
				reducedMotion = reducedMotion,
				highlight = isMine,
				clips = true,
			}, React.createElement(Text, {
				value = `#{rank}`,
				size = if stack then 12 else 15,
				color = ensureContrast(surface, rowAccent),
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 9,
				sizeConstraint = UDim2.new(0, gRankW, 1, 0),
			}), React.createElement(Badge, {
				value = entry.Tag,
				accent = rowAccent,
				filled = true,
				position = UDim2.fromOffset(gTagX, 6),
				size = UDim2.fromOffset(gTagW, 24),
			}), React.createElement(Text, {
				value = entry.Name,
				size = if stack then 12 else 14,
				color = ensureContrast(surface, Palette.cream),
				weight = Enum.FontWeight.Bold,
				fit = true,
				minSize = 9,
				position = UDim2.fromOffset(gNameX, 6),
				sizeConstraint = UDim2.new(1, gNameReserve, 0, 24),
			}), React.createElement(Text, {
				value = compactNumber(entry.Activity),
				size = if stack then 12 else 15,
				color = ensureContrast(surface, rowAccent),
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Right,
				fit = true,
				minSize = 9,
				position = UDim2.new(1, -(gValueW + 8), 0, 6),
				sizeConstraint = UDim2.new(0, gValueW, 0, 24),
			}))
		end
		for _k, _v in shown do
			_newValue_3[_k] = _callback_3(_v, _k - 1, shown)
		end
		-- ▲ ReadonlyArray.map ▲
		_result_2 = _newValue_3
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, listTop + math.max(#shown, 1) * (GUILD_ROW_H + ROW_GAP)),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _result_2)
end
local function LeaderboardsView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — LeaderboardsView
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	-- Canonical softMotion antilag gate — LeaderboardsBoard.
	local boardReveal = useStagger(0, softMotion)
	-- Canonical softMotion antilag gate — LeaderboardsScope.
	local scopeReveal = useStagger(1, softMotion)
	-- Canonical softMotion antilag gate — LeaderboardsRows.
	local rowsReveal = useStagger(2, softMotion)
	local boardHostRef = React.useRef(nil)
	local selected, setSelected = React.useState("Flux")
	local scope, setScope = React.useState("Global")
	-- Gamepad: park Selection on board filter tabs (FocusClaim prefers Confirm-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = boardHostRef.current
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
	end, { selected, scope })
	local entries, setEntries = React.useState({})
	local loading, setLoading = React.useState(true)
	local requestId = React.useRef(0)
	local lastSentAt = React.useRef(-math.huge)
	local queuedRefresh = React.useRef()
	local localId = Players.LocalPlayer.UserId
	local guildBoard = selected == "Guilds"
	local meta = if guildBoard then {
		id = "Flux",
		label = "Guild Halls",
		short = "GUILDS",
		description = "Halls ranked by everything their members bank and build together.",
		icon = "Crew",
		accent = Palette.violet,
	} else metaFor(selected)
	local refresh = React.useCallback(function(id)
		local request = requestId.current + 1
		requestId.current = request
		setLoading(true)
		local wait = math.max(0, 1.12 - (os.clock() - lastSentAt.current))
		if queuedRefresh.current ~= nil then
			task.cancel(queuedRefresh.current)
		end
		queuedRefresh.current = task.delay(wait, function()
			queuedRefresh.current = nil
			if request ~= requestId.current then
				return nil
			end
			lastSentAt.current = os.clock()
			dispatch("GetLeaderboard", {
				Id = id,
			}, function(response)
				if request ~= requestId.current then
					return nil
				end
				setLoading(false)
				if response.ok and response.Leaderboard ~= nil then
					setEntries(response.Leaderboard)
				end
			end)
		end)
	end, { dispatch })
	local refreshServer = React.useCallback(function(id)
		local request = requestId.current + 1
		requestId.current = request
		setLoading(true)
		dispatch("GetPlayers", {}, function(response)
			if request ~= requestId.current then
				return nil
			end
			setLoading(false)
			if response.ok and response.Players ~= nil then
				setEntries(serverEntries(response.Players, id))
			end
		end)
	end, { dispatch })
	React.useEffect(function()
		if selected == "Guilds" then
			setLoading(false)
			return nil
		end
		setEntries({})
		local alive = true
		local refreshTimer
		local scheduleRefresh
		scheduleRefresh = function()
			if not alive then
				return nil
			end
			if scope == "Server" then
				refreshServer(selected)
			else
				refresh(selected)
			end
			refreshTimer = task.delay(AUTO_REFRESH_SECONDS, scheduleRefresh)
		end
		scheduleRefresh()
		return function()
			alive = false
			if refreshTimer ~= nil then
				task.cancel(refreshTimer)
			end
			if queuedRefresh.current ~= nil then
				task.cancel(queuedRefresh.current)
				queuedRefresh.current = nil
			end
			requestId.current += 1
		end
	end, { refresh, refreshServer, scope, selected })
	local _result
	if guildBoard then
		_result = {}
	else
		-- ▼ ReadonlyArray.filter ▼
		local _newValue_1 = {}
		local _callback_1 = function(entry)
			return scoreCounts(selected, entry.Value)
		end
		local _length_1 = 0
		for _k, _v in entries do
			if _callback_1(_v, _k - 1, entries) == true then
				_length_1 += 1
				_newValue_1[_length_1] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		_result = _newValue_1
	end
	local ranked = _result
	local heroH = if stack then 148 else 148
	-- Narrow stack wraps RANK_TABS into two rows so the selection carrier never clips inside
	-- an X-scroller; desktop keeps a 4-column grid. PageScaffold owns vertical body scroll.
	local filterColumns = 4
	local filterRows = math.ceil(#RANK_TABS / filterColumns)
	local filterGap = 7
	local filtersH = filterRows * TapTarget + (filterRows - 1) * filterGap + 8
	local scopeH = if guildBoard then 0 else TapTarget * 0.72 + 10
	-- Phone stacks the podium as three short cards (no 1/3-width squeeze / clip); desktop keeps
	-- the classic three-across band. Section heights are intrinsic — UIListLayout owns vertical
	-- flow so RankRow / PodiumCard never need absolute Y under the scaffold.
	local podiumCardH = if stack then 118 else 152
	local podiumGap = if stack then 8 else 8
	local podiumBandH = if stack then podiumCardH * 3 + podiumGap * 2 else podiumCardH
	local podiumSectionH = 22 + podiumBandH
	local guildHeroH = if stack then 156 else 148
	local guildBlockH = guildHeroH + 34 + GUILD_ROWS_SHOWN * (GUILD_ROW_H + ROW_GAP)
	local hasEntries = #ranked > 0
	local remaining = math.max(0, #ranked - 3)
	local ranksLabelH = 22
	local rankStride = ROW_H + ROW_GAP
	local ranksListH = if hasEntries then (
		if remaining >= 8 then math.min(remaining, 12) * rankStride - ROW_GAP
		else math.max(remaining, 0) * rankStride - (if remaining > 0 then ROW_GAP else 0)
	) else 0
	local emptyOrLoadingH = 160
	local ranksSectionH = if hasEntries then ranksLabelH + ranksListH else emptyOrLoadingH
	local leaderTail = scrollTail(stack, chrome.bottomSafe, 56)
	local own = if guildBoard then 0 else ownValue(state, selected)
	-- ▼ ReadonlyArray.findIndex ▼
	local _callback_1 = function(entry)
		return entry.UserId == localId
	end
	local _result_1 = -1
	for _i, _v in ranked do
		if _callback_1(_v, _i - 1, ranked) == true then
			_result_1 = _i - 1
			break
		end
	end
	-- ▲ ReadonlyArray.findIndex ▲
	local localRankIndex = _result_1
	local localRank = if localRankIndex >= 0 then localRankIndex + 1 else nil
	local heroSurface = darken(meta.accent, 0.9)
	local heroTitle = ensureContrast(heroSurface, Palette.cream)
	local heroBody = ensureContrast(heroSurface, Palette.creamSoft)
	local heroEyebrow = ensureContrast(heroSurface, meta.accent)
	local recordFill = Palette.void
	local recordLabel = ensureContrast(recordFill, Palette.muted)
	local recordValue = ensureContrast(recordFill, meta.accent)
	local recordRank = ensureContrast(recordFill, if localRank ~= nil then Palette.green else Palette.muted)
	local _exp = React.createElement("frame", {
		Name = "LeaderboardConfirmFilters",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(SegmentedTabs, {
		options = RANK_TABS,
		value = selected,
		onChange = setSelected,
		accent = meta.accent,
		sound = "leaderboardSwitch",
		columns = filterColumns,
		gap = filterGap,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	}))
	local _exp_1 = not guildBoard and React.createElement("frame", {
		Size = UDim2.new(0, if stack then 220 else 260, 0, math.max(1, scopeH - 10)),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(SegmentedTabs, {
		options = SCOPE_TABS,
		value = scope,
		onChange = setScope,
		accent = meta.accent,
		sound = "tabSwitch",
		columns = 2,
		gap = 4,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	}))
	local boardSoft = softMotion or scopeReveal == nil or rowsReveal == nil
	local heroPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = meta.accent,
		background = heroSurface,
		padding = if stack then 12 else 16,
		highlight = not loading and not softMotion and not boardSoft,
		reveal = if softMotion then boardReveal else enter,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(if stack then 44 else 56, if stack then 44 else 56),
		BackgroundColor3 = darken(meta.accent, 0.72),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = meta.accent,
		Thickness = 2,
		Transparency = 0.18,
	}), React.createElement(Icon, {
		kind = meta.icon,
		color = ensureContrast(darken(meta.accent, 0.72), Palette.cream),
		accent = meta.accent,
		size = if stack then 44 else 56,
		reducedMotion = softMotion,
	})), React.createElement(Text, {
		value = if scope == "Server" then "THIS SERVER" else "ALL-TIME RANKINGS",
		size = 9,
		color = heroEyebrow,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(if stack then 56 else 72, 0),
		sizeConstraint = UDim2.new(1, if stack then -56 else -260, 0, 14),
	}), React.createElement(Text, {
		value = meta.label,
		size = if stack then 18 else 24,
		color = heroTitle,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(if stack then 56 else 72, 16),
		sizeConstraint = UDim2.new(1, if stack then -56 else -260, 0, if stack then 24 else 32),
	}), React.createElement(Text, {
		value = meta.description,
		size = if stack then 10 else 12,
		color = heroBody,
		wrap = true,
		position = UDim2.fromOffset(if stack then 56 else 72, if stack then 42 else 50),
		sizeConstraint = UDim2.new(1, if stack then -56 else -280, 0, if stack then 28 else 36),
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 52) else UDim2.fromOffset(220, 76),
		Position = if stack then UDim2.new(0, 0, 1, -54) else UDim2.new(1, -220, 0.5, -38),
		BackgroundColor3 = recordFill,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = meta.accent,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement(Text, {
		value = "YOUR RECORD",
		size = 8,
		color = recordLabel,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(12, 4),
		sizeConstraint = UDim2.new(1, -24, 0, 12),
	}), React.createElement(Text, {
		value = formatValue(selected, own),
		size = if stack then 16 else 22,
		color = recordValue,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(12, 16),
		sizeConstraint = UDim2.new(1, -24, 0, 20),
	}), React.createElement(Text, {
		value = if localRank ~= nil then `{if scope == "Server" then "SERVER" else "GLOBAL"} POSITION #{localRank}` elseif scope == "Server" then "NOT RANKED HERE YET" else "PUSH HIGHER TO ENTER TOP 25",
		size = 8,
		color = recordRank,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.new(0, 12, 1, -16),
		sizeConstraint = UDim2.new(1, -24, 0, 12),
	})))
	local podiumSlots = { 0, 1, 2 }
	local podiumCards = table.create(#podiumSlots)
	for _k, index in podiumSlots do
		podiumCards[_k] = React.createElement("frame", {
			key = `podium-{index}`,
			Size = if stack then UDim2.new(1, 0, 0, podiumCardH) else UDim2.new(1 / 3, -16 / 3, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ClipsDescendants = false,
		}, React.createElement(PodiumCard, {
			entry = ranked[index + 1],
			rank = index + 1,
			meta = meta,
			width = UDim2.fromScale(1, 1),
			height = podiumCardH,
			reducedMotion = softMotion,
		}))
	end
	local podiumPane = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = "TOP PILOTS",
		size = 10,
		color = ensureContrast(Palette.night, Palette.muted),
		weight = Enum.FontWeight.Heavy,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, podiumBandH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = if stack then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, podiumGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), podiumCards))
	local ranksPane
	if loading and not hasEntries then
		ranksPane = React.createElement(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = meta.accent,
			background = Palette.panel,
			padding = 16,
			reducedMotion = softMotion,
		}, React.createElement(Text, {
			value = "Updating rankings…",
			size = 14,
			color = ensureContrast(Palette.panel, Palette.creamSoft),
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.fromScale(1, 1),
		}))
	elseif not hasEntries then
		ranksPane = React.createElement(EmptyState, {
			title = "No ranked pilots yet",
			body = "Your first saved score will open this board.",
			icon = "Leaderboard",
			accent = meta.accent,
			size = UDim2.fromScale(1, 1),
		})
	else
		local restEntries = {}
		local restCount = 0
		for index, entry in ranked do
			if index > 3 then
				restCount += 1
				restEntries[restCount] = entry
			end
		end
		local rankStride = ROW_H + ROW_GAP
		local virtRanks = restCount >= 8
		local ranksBody = if virtRanks then React.createElement(FlatList, {
			data = restEntries,
			itemHeight = rankStride,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 8,
			Size = UDim2.new(1, 0, 0, ranksListH),
			scrollBarColor = meta.accent,
			scrollBarThickness = 3,
			keyExtractor = function(entry)
				return `{selected}-{entry.UserId}`
			end,
			renderItem = function(_param_1)
				local entry = _param_1.item
				local index = _param_1.index
				local rank = index + 4
				return React.createElement(RankRow, {
					entry = entry,
					rank = rank,
					meta = meta,
					isLocal = entry.UserId == localId,
					layoutOrder = rank,
					reducedMotion = softMotion,
					stack = stack,
				})
			end,
		}) else (function()
			local rest = {}
			for index, entry in restEntries do
				rest[index] = React.createElement(RankRow, {
					key = `{selected}-{entry.UserId}`,
					entry = entry,
					rank = index + 3,
					meta = meta,
					isLocal = entry.UserId == localId,
					layoutOrder = index + 3,
					reducedMotion = softMotion,
					stack = stack,
				})
			end
			return React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, ranksListH),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ROW_GAP),
			}), rest)
		end)()
		ranksPane = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ROW_GAP),
		}), React.createElement(Text, {
			value = if loading then "GETTING THE LATEST SCORES…" else `UPDATES EVERY {AUTO_REFRESH_SECONDS} SECONDS`,
			size = 10,
			color = ensureContrast(Palette.night, Palette.muted),
			weight = Enum.FontWeight.Heavy,
			layoutOrder = 0,
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, ranksListH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			ClipsDescendants = false,
		}, ranksBody))
	end
	local sections = {
		{
			id = "filters",
			height = filtersH,
			element = _exp,
		},
	}
	if not guildBoard then
		table.insert(sections, {
			id = "scope",
			height = scopeH,
			element = _exp_1,
		})
		table.insert(sections, {
			id = "hero",
			height = heroH,
			element = heroPanel,
		})
		if hasEntries then
			table.insert(sections, {
				id = "podium",
				height = podiumSectionH,
				element = podiumPane,
			})
		end
		table.insert(sections, {
			id = "ranks",
			height = ranksSectionH,
			element = ranksPane,
		})
	else
		table.insert(sections, {
			id = "guilds",
			height = guildBlockH,
			element = React.createElement(GuildSpotlight, {
				state = state,
				dispatch = dispatch,
				stack = stack,
				reducedMotion = softMotion,
				position = UDim2.fromOffset(0, 0),
			}),
		})
	end
	return React.createElement("frame", {
		ref = boardHostRef,
		Name = "LeaderboardConfirm",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		gap = 12,
		tailPad = leaderTail,
		scrollBarColor = meta.accent,
		scrollBarThickness = 4,
		inset = 0,
		sections = sections,
	}))
end
return {
	LeaderboardsView = LeaderboardsView,
}
