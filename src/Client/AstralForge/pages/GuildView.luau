local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local Audio = require(script.Parent.Parent.audio).Audio
local PlayerMark = require(script.Parent.Parent.Icon).PlayerMark
local _format = require(script.Parent.Parent.format)
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local gteFlux = _format.gteFlux
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local ROLE_RANK = {
	Leader = 0,
	Officer = 1,
	Member = 2,
}
local UPGRADE_ACCENTS = {
	ProductionBoost = Palette.coral,
	VaultBoost = Palette.mango,
	OfflineBoost = Palette.cyan,
	AutomationBoost = Palette.mint,
	TapBoost = Palette.violet,
}
--* Mirrors the server's upgradeEffect: cumulative named tiers, then an endless flat tail. 
local function effectAtLevel(config, level)
	local safe = math.max(0, math.floor(level))
	if safe <= 0 then
		return 0
	end
	local tiers = config.Tiers
	if tiers == nil or #tiers == 0 then
		return safe * config.EffectPerLevel
	end
	local named = math.min(safe, #tiers)
	local total = 0
	do
		local index = 0
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < named) then
				break
			end
			total += tiers[index + 1].Effect
		end
	end
	if safe > named then
		total += (safe - named) * config.EffectPerLevel
	end
	return total
end
--* Mirrors the server's upgradeCost: `level` is current, the purchase priced is level + 1. 
local function costAtLevel(config, level)
	local tiers = config.Tiers
	local nextIndex = level + 1
	if tiers ~= nil and nextIndex >= 1 and nextIndex <= #tiers then
		return math.floor(tiers[nextIndex].Cost + 0.5)
	end
	return math.floor(config.BaseCost * config.CostScale ^ math.max(0, level) + 0.5)
end
local function percentText(value)
	local scaled = value * 100
	if scaled >= 10 or scaled % 1 == 0 then
		return `+{math.floor(scaled + 0.5)}%`
	end
	return `+{string.format("%.1f", scaled)}%`
end
local function buildUpgradeRows(config, guild)
	local guildConfig = config.Guild
	if guildConfig == nil then
		return {}
	end
	local order = guildConfig.UpgradeOrder or {}
	local ids = {}
	for _, id in order do
		if guildConfig.Upgrades[id] ~= nil then
			table.insert(ids, id)
		end
	end
	-- Any upgrade the server knows about but that is missing from UpgradeOrder still renders.
	for id in pairs(guildConfig.Upgrades) do
		if not (table.find(ids, id) ~= nil) then
			table.insert(ids, id)
		end
	end
	local rows = {}
	for _, id in ids do
		local upgrade = guildConfig.Upgrades[id]
		local _condition = guild.Upgrades[id]
		if _condition == nil then
			_condition = 0
		end
		local level = _condition
		local maxed = level >= upgrade.MaxLevel
		local cost = costAtLevel(upgrade, level)
		local bank = if upgrade.Currency == "Cash" then guild.BankCash else guild.BankDust
		local tiers = upgrade.Tiers
		local _result = tiers
		if _result ~= nil then
			_result = #_result
		end
		local _condition_1 = _result
		if _condition_1 == nil then
			_condition_1 = 0
		end
		local tierCount = _condition_1
		local _arg0 = {
			id = id,
			config = upgrade,
			level = level,
			cost = cost,
			currentEffect = effectAtLevel(upgrade, level),
			nextEffect = effectAtLevel(upgrade, level + 1),
			tierName = if level > 0 and tiers ~= nil and level <= tierCount then tiers[level].Name elseif level > 0 then "Endless" else "Not installed",
			nextTierName = if tiers ~= nil and level < tierCount then tiers[level + 1].Name else nil,
			tierIndex = math.min(level, tierCount),
			tierCount = tierCount,
			affordable = not maxed and bank >= cost,
			maxed = maxed,
			accent = UPGRADE_ACCENTS[id] or Palette.violet,
		}
		table.insert(rows, _arg0)
	end
	return rows
end
local function goalConfigFor(config, typeId)
	local _result = config.Guild
	if _result ~= nil then
		_result = _result.Goal
		if _result ~= nil then
			_result = _result.Types
		end
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	for _, entry in _condition do
		if entry.Id == typeId then
			return entry
		end
	end
	return nil
end
local function goalUnitLabel(metric)
	if metric == "ContributeCash" then
		return "flux banked"
	end
	if metric == "ContributeDust" then
		return "dust banked"
	end
	return "upgrades bought"
end
local function GuildGoalCard(_param)
	local guild = _param.guild
	local config = _param.config
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local goal = guild.Goal
	local now = useWallClock(goal ~= nil)
	local localKey = tostring(Players.LocalPlayer.UserId)
	if goal == nil then
		return React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 116),
			accent = Palette.mint,
			background = Palette.panelRaised,
			padding = if stack then 16 else 18,
			layoutOrder = layoutOrder,
			reducedMotion = reducedMotion,
		}, React.createElement(Text, {
			value = "GUILD GOAL",
			size = 10,
			color = Palette.mint,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}), React.createElement(Text, {
			value = "The next shared goal is being drawn up.",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, 0, 0, 34),
		}))
	end
	local definition = goalConfigFor(config, goal.TypeId)
	local fill = math.clamp(goal.Progress / math.max(1, goal.Target), 0, 1)
	local _condition = goal.Contributors[localKey]
	if _condition == nil then
		_condition = 0
	end
	local mine = _condition
	local _result = config.Guild
	if _result ~= nil then
		_result = _result.Goal
		if _result ~= nil then
			_result = _result.MinContributionForReward
		end
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = 1
	end
	local helped = mine >= _condition_1
	local claimed = goal.Claimed[localKey] == true
	local canClaim = goal.Completed and helped and not claimed
	local accent = if goal.Completed then Palette.mint else Palette.mango
	local surface = darken(accent, 0.9)
	local height = if stack then 234 else 196
	-- The highlight breathing pulse fires only while the reward is actually claimable.
	local _exp = React.createElement(Text, {
		value = if goal.Completed then "GUILD GOAL • COMPLETE" else "GUILD GOAL",
		size = 10,
		color = ensureContrast(surface, accent),
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
	})
	local _attributes = {}
	local _result_1 = definition
	if _result_1 ~= nil then
		_result_1 = _result_1.Name
	end
	local _condition_2 = _result_1
	if _condition_2 == nil then
		_condition_2 = "Shared objective"
	end
	_attributes.value = _condition_2
	_attributes.size = if stack then 20 else 25
	_attributes.color = ensureContrast(surface, Palette.cream)
	_attributes.weight = Enum.FontWeight.Heavy
	_attributes.fit = true
	_attributes.minSize = 15
	_attributes.position = UDim2.fromOffset(0, 18)
	_attributes.sizeConstraint = UDim2.new(1, -8, 0, 32)
	local _exp_1 = React.createElement(Text, _attributes)
	local _attributes_1 = {}
	local _result_2 = definition
	if _result_2 ~= nil then
		_result_2 = _result_2.Description
	end
	local _condition_3 = _result_2
	if _condition_3 == nil then
		_condition_3 = "Work together to finish this goal."
	end
	_attributes_1.value = _condition_3
	_attributes_1.size = 11
	_attributes_1.color = ensureContrast(surface, Palette.creamSoft)
	_attributes_1.wrap = true
	_attributes_1.position = UDim2.fromOffset(0, if stack then 50 else 52)
	_attributes_1.sizeConstraint = UDim2.new(1, -8, 0, 30)
	local _exp_2 = React.createElement(Text, _attributes_1)
	local _exp_3 = React.createElement(Text, {
		value = now:map(function(timestamp)
			return if goal.EndsAt > timestamp then `{clockText(math.max(0, goal.EndsAt - timestamp))} LEFT` else "WINDOW CLOSED"
		end),
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -150, 0, 0),
		sizeConstraint = UDim2.fromOffset(150, 16),
	})
	local _exp_4 = React.createElement(Meter, {
		value = fill,
		color = accent,
		position = UDim2.new(0, 0, 0, if stack then 92 else 94),
		size = UDim2.new(1, 0, 0, 9),
		reducedMotion = reducedMotion,
		shimmer = goal.Completed,
	})
	local _attributes_2 = {}
	local _exp_5 = compactNumber(goal.Progress)
	local _exp_6 = compactNumber(goal.Target)
	local _result_3 = definition
	if _result_3 ~= nil then
		_result_3 = _result_3.Metric
	end
	local _condition_4 = _result_3
	if _condition_4 == nil then
		_condition_4 = ""
	end
	_attributes_2.value = `{_exp_5} / {_exp_6} {goalUnitLabel(_condition_4)}`
	_attributes_2.size = 10
	_attributes_2.color = ensureContrast(surface, Palette.creamSoft)
	_attributes_2.fit = true
	_attributes_2.minSize = 8
	_attributes_2.position = UDim2.fromOffset(0, if stack then 106 else 108)
	_attributes_2.sizeConstraint = UDim2.new(1, 0, 0, 16)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = surface,
		padding = 16,
		layoutOrder = layoutOrder,
		highlight = canClaim,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, React.createElement(Text, _attributes_2), React.createElement(Text, {
		value = if mine > 0 then `YOU HELPED WITH {compactNumber(mine)}` else "YOU HAVE NOT HELPED YET",
		size = 10,
		color = ensureContrast(surface, if mine > 0 then Palette.mint else Palette.muted),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(0, if stack then 126 else 128),
		sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 16),
	}), definition ~= nil and React.createElement(Text, {
		value = `REWARD  {formatReward(definition.Reward)}`,
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 146 else 148),
		sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 16),
	}), React.createElement(Button, {
		text = if claimed then "CLAIMED" elseif canClaim then "CLAIM REWARD" elseif goal.Completed then "NOT ELIGIBLE" else "IN PROGRESS",
		icon = if claimed then "Check" else "Gift",
		onClick = function()
			if canClaim and not busy then
				dispatch("ClaimGuildGoal", {})
			end
		end,
		color = if canClaim then Palette.mint else Palette.panelSoft,
		textColor = if canClaim then Palette.ink else Palette.creamSoft,
		disabled = not canClaim or busy,
		loading = canClaim and busy,
		shakeToken = if canClaim then shakeToken else 0,
		highlight = canClaim,
		size = if stack then UDim2.new(1, 0, 0, 46) else UDim2.fromOffset(160, 46),
		position = if stack then UDim2.new(0, 0, 1, -46) else UDim2.new(1, -160, 1, -46),
		reducedMotion = reducedMotion,
	}))
end
local function UpgradeCard(_param)
	local row = _param.row
	local guild = _param.guild
	local canBuy = _param.canBuy
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local layoutOrder = _param.layoutOrder
	local currencyLabel = if row.config.Currency == "Cash" then "flux" else "dust"
	local bank = if row.config.Currency == "Cash" then guild.BankCash else guild.BankDust
	-- Progress toward affording the next tier, so the bar always means "how close are we".
	local fill = if row.maxed then 1 else math.clamp(bank / math.max(1, row.cost), 0, 1)
	local actionable = canBuy and row.affordable and not row.maxed
	local height = if stack then 180 else 140
	local _exp = React.createElement(Text, {
		value = row.config.Name,
		size = if stack then 15 else 17,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		sizeConstraint = UDim2.new(1, if stack then -90 else -260, 0, 22),
	})
	local _exp_1 = React.createElement(Badge, {
		value = if row.tierCount > 0 then `TIER {row.tierIndex}/{row.tierCount}` else `LV {compactNumber(row.level)}`,
		accent = row.accent,
		filled = row.level > 0,
		position = UDim2.new(1, if stack then -84 else -254, 0, 0),
		size = UDim2.fromOffset(84, 24),
	})
	local _exp_2 = React.createElement(Text, {
		value = row.config.Description,
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, if stack then 0 else -260, 0, 28),
	})
	local _attributes = {}
	local _result
	if row.maxed then
		_result = `{percentText(row.currentEffect)} — fully installed`
	else
		local _exp_3 = percentText(row.currentEffect)
		local _exp_4 = percentText(row.nextEffect)
		local _condition = row.nextTierName
		if _condition == nil then
			_condition = "the next level"
		end
		_result = `{_exp_3} now  →  {_exp_4} at {_condition}`
	end
	_attributes.value = _result
	_attributes.size = 11
	_attributes.color = if row.maxed then Palette.mint else Palette.creamSoft
	_attributes.weight = Enum.FontWeight.Bold
	_attributes.fit = true
	_attributes.minSize = 8
	_attributes.position = UDim2.fromOffset(0, if stack then 58 else 60)
	_attributes.sizeConstraint = UDim2.new(1, if stack then 0 else -260, 0, 18)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = row.accent,
		background = Palette.panelRaised,
		padding = if stack then 14 else 16,
		layoutOrder = layoutOrder,
		interactive = actionable,
		highlight = actionable,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, React.createElement(Text, _attributes), React.createElement(Meter, {
		value = fill,
		color = row.accent,
		position = UDim2.fromOffset(0, if stack then 82 else 84),
		size = UDim2.new(1, if stack then 0 else -260, 0, 6),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = if row.maxed then "MAXED" else `BANK {compactNumber(bank)} / {compactNumber(row.cost)} {currencyLabel}`,
		size = 10,
		color = if row.affordable then Palette.mint else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 96 else 98),
		sizeConstraint = UDim2.new(1, if stack then 0 else -260, 0, 16),
	}), React.createElement(Button, {
		text = if row.maxed then "MAXED" elseif row.affordable then `BUY {compactNumber(row.cost)}` else "NEED MORE",
		icon = if row.maxed then "Check" else "Forge",
		onClick = function()
			if actionable and not busy then
				dispatch("BuyGuildUpgrade", {
					Id = row.id,
				})
			end
		end,
		color = if actionable then row.accent else Palette.panelSoft,
		textColor = if actionable then Palette.ink else Palette.creamSoft,
		disabled = not actionable or busy,
		loading = actionable and busy,
		shakeToken = if actionable then shakeToken else 0,
		highlight = actionable,
		size = if stack then UDim2.new(1, 0, 0, 44) else UDim2.fromOffset(240, 44),
		position = if stack then UDim2.new(0, 0, 1, -44) else UDim2.new(1, -240, 1, -44),
		reducedMotion = reducedMotion,
	}))
end
local function MemberRow(_param)
	local userKey = _param.userKey
	local name = _param.name
	local role = _param.role
	local contributed = _param.contributed
	local goalShare = _param.goalShare
	local share = _param.share
	local isLocal = _param.isLocal
	local canManage = _param.canManage
	local isLeader = _param.isLeader
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local layoutOrder = _param.layoutOrder
	local accent = if role == "Leader" then Palette.mango elseif role == "Officer" then Palette.cyan else Palette.steel
	local surface = if isLocal then darken(Palette.green, 0.88) else Palette.panel
	local _condition = tonumber(userKey)
	if _condition == nil then
		_condition = 0
	end
	local userId = _condition
	local manageable = canManage and not isLeader
	-- Non-stack rows used to put PROMOTE/KICK vertically centered on the row (y 18-58 on a
	-- 76px row) while the banked/goal text sits at y 36-66 — those two ranges overlap, so the
	-- buttons drew on top of the text. Manageable rows now get extra height and the buttons
	-- pinned to the bottom instead of vertically centered, the same pattern the stack layout
	-- already used correctly.
	-- Keep in sync with GuildView's canvas memberHeight — short desktop rows used to clip
	-- promote/kick controls when the canvas reserved only 76px for a 108px manageable row.
	local height = if stack then 122 elseif manageable then 112 else 84
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = if isLocal then Palette.green else accent,
		background = surface,
		padding = if stack then 12 else 14,
		layoutOrder = layoutOrder,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(PlayerMark, {
		userId = userId,
		accent = accent,
		size = 34,
		position = UDim2.fromOffset(0, 2),
	}), React.createElement(Text, {
		value = name,
		size = 14,
		color = ensureContrast(surface, Palette.cream),
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(44, 0),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 20),
	}), React.createElement(Text, {
		value = string.upper(role),
		size = 9,
		color = ensureContrast(surface, accent),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(44, 20),
		sizeConstraint = UDim2.new(0, 90, 0, 14),
	}), React.createElement(Text, {
		value = `{compactNumber(contributed)} banked  •  {math.floor(share * 100 + 0.5)}% of all deposits`,
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(44, 36),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 16),
	}), goalShare > 0 and React.createElement(Text, {
		value = `{compactNumber(goalShare)} toward this goal`,
		size = 9,
		color = ensureContrast(surface, Palette.mint),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(44, 52),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 14),
	}), manageable and React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = if role == "Officer" then "DEMOTE" else "PROMOTE",
		onClick = function()
			if not busy then
				dispatch("SetGuildRole", {
					UserId = userId,
					Role = if role == "Officer" then "Member" else "Officer",
				})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(0.5, -4, 0, 40) else UDim2.new(0.5, -4, 0, 40),
		position = if stack then UDim2.new(0, 0, 1, -40) else UDim2.new(0, 0, 1, -40),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = "KICK",
		onClick = function()
			if not busy then
				dispatch("KickGuildMember", {
					UserId = userId,
				})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.coral,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(0.5, -4, 0, 40) else UDim2.new(0.5, -4, 0, 40),
		position = if stack then UDim2.new(0.5, 4, 1, -40) else UDim2.new(0.5, 4, 1, -40),
		reducedMotion = reducedMotion,
	})))
end
local function sanitizeGuildTag(value)
	return string.sub((string.gsub(string.upper(value), "[^A-Z0-9]", "")), 1, 4)
end
local function JoinOrCreate(_param)
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local stack = _param.stack
	local cash = _param.cash
	local name, setName = React.useState("")
	local tag, setTag = React.useState("")
	local joinTag, setJoinTag = React.useState("")
	local nameRef = React.useRef(name)
	local tagRef = React.useRef(tag)
	local joinRef = React.useRef(joinTag)
	local _result = config.Guild
	if _result ~= nil then
		_result = _result.CreateCost
	end
	local _condition = _result
	if _condition == nil then
		_condition = 5000
	end
	local createCost = _condition
	local canAfford = gteFlux(cash, createCost)
	local canCharter = not busy and #name >= 3 and #tag >= 3 and canAfford
	local canJoin = not busy and #joinTag >= 3
	local fieldStyle = {
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
	}
	local charter = function()
		local nextName = (string.gsub((string.gsub(nameRef.current, "^%s+", "")), "%s+$", ""))
		local nextTag = sanitizeGuildTag(tagRef.current)
		if busy or #nextName < 3 or #nextTag < 3 or not canAfford then
			return nil
		end
		dispatch("CreateGuild", {
			Name = nextName,
			Tag = nextTag,
		})
	end
	local join = function()
		local nextTag = sanitizeGuildTag(joinRef.current)
		if busy or #nextTag < 3 then
			return nil
		end
		dispatch("JoinGuild", {
			Tag = nextTag,
		})
	end
	local _exp = React.createElement(Text, {
		value = "CHARTER A GUILD",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _exp_1 = React.createElement(Text, {
		value = "Start your own hall",
		size = if stack then 21 else 26,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	})
	local _exp_2 = React.createElement(Text, {
		value = `Costs {compactNumber(createCost)} flux · you have {compactNumber(cash)}. You lead it and share every hall upgrade.`,
		size = 11,
		color = if canAfford then Palette.creamSoft else Palette.coral,
		wrap = true,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	})
	local _attributes = {
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 90),
		PlaceholderText = "Guild name (3-28 characters)",
		Text = name,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Change = {
			Text = function(box)
				local value = string.sub(box.Text, 1, 28)
				nameRef.current = value
				setName(value)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}
	for _k, _v in fieldStyle do
		_attributes[_k] = _v
	end
	local _exp_3 = React.createElement("textbox", _attributes, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}))
	local _attributes_1 = {
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 138),
		PlaceholderText = "Tag (3-4 letters or numbers)",
		Text = tag,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Change = {
			Text = function(box)
				local value = sanitizeGuildTag(box.Text)
				tagRef.current = value
				setTag(value)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}
	for _k, _v in fieldStyle do
		_attributes_1[_k] = _v
	end
	local _exp_4 = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 276),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = 18,
		layoutOrder = 1,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("textbox", _attributes_1, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})), React.createElement(Button, {
		text = if not canAfford then `NEED {compactNumber(createCost)} FLUX` else "CHARTER GUILD",
		icon = "Forge",
		onClick = charter,
		color = if canCharter then Palette.violet else Palette.panelSoft,
		textColor = if canCharter then Palette.ink else Palette.muted,
		disabled = not canCharter,
		loading = canAfford and busy,
		shakeToken = if canAfford then shakeToken else 0,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
	}))
	local _exp_5 = React.createElement(Text, {
		value = "JOIN A GUILD",
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _exp_6 = React.createElement(Text, {
		value = "Already know a tag? Type it in and jump into the hall.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	})
	local _attributes_2 = {
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 56),
		PlaceholderText = "Guild tag",
		Text = joinTag,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Change = {
			Text = function(box)
				local value = sanitizeGuildTag(box.Text)
				joinRef.current = value
				setJoinTag(value)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}
	for _k, _v in fieldStyle do
		_attributes_2[_k] = _v
	end
	return React.createElement(React.Fragment, nil, _exp_4, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 192),
		accent = Palette.mint,
		padding = 18,
		layoutOrder = 2,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp_5, _exp_6, React.createElement("textbox", _attributes_2, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})), React.createElement(Button, {
		text = "JOIN GUILD",
		icon = "Crew",
		onClick = join,
		color = if canJoin then Palette.mint else Palette.panelSoft,
		textColor = if canJoin then Palette.ink else Palette.muted,
		disabled = not canJoin,
		loading = canJoin and busy,
		shakeToken = if canJoin then shakeToken else 0,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
	})))
end
local function GuildView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local stack = chrome.contentStack
	local reveal = useStagger(0, reducedMotion)
	local busy, setBusy = React.useState(false)
	local shakeToken, setShakeToken = React.useState(0)
	local contributeCash, setContributeCash = React.useState("")
	local contributeDust, setContributeDust = React.useState("")
	local guild = state.Guild
	local localPlayer = Players.LocalPlayer
	local localKey = if localPlayer ~= nil then tostring(localPlayer.UserId) else ""
	-- The guild document is only pushed with state; ask for a fresh copy on mount so the
	-- bank, goal, and member contributions are current when the page opens.
	React.useEffect(function()
		dispatch("GetGuild", {})
	end, { dispatch })
	-- Wraps dispatch so every guild mutation disables its button until the server replies,
	-- which stops double-submits on slow connections. A failure also bumps shakeToken so
	-- whichever button triggered it can shake/flash instead of failing silently on-screen.
	local send = React.useCallback(function(action, payload, callback)
		setBusy(true)
		dispatch(action, payload, function(response)
			setBusy(false)
			if not response.ok then
				setShakeToken(function(token)
					return token + 1
				end)
			end
			if callback ~= nil then
				callback(response)
			end
		end)
	end, { dispatch })
	if guild == nil or guild.Id == "" then
		local guide = if config.ClientPageGuides ~= nil then config.ClientPageGuides.Guild else nil
		local pageGap = if stack then 12 else Layout.panelGap
		local joinBlockH = 276 + pageGap + 192
		return React.createElement(PageScaffold, {
			gap = pageGap,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 80),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			sections = {
				{
					id = "empty-hero",
					height = 128,
					element = React.createElement(Panel, {
						size = UDim2.fromScale(1, 1),
						accent = Palette.violet,
						background = Palette.panelRaised,
						padding = if stack then 16 else 20,
						highlight = true,
						reveal = reveal,
						clips = false,
					}, React.createElement(Text, {
						value = (guide and guide.EmptyTitle) or "No guild yet",
						size = 20,
						color = Palette.cream,
						weight = Enum.FontWeight.Heavy,
						sizeConstraint = UDim2.new(1, 0, 0, 28),
					}), React.createElement(Text, {
						value = (guide and guide.EmptyBody) or "Charter one for shared upgrades, or join with a tag.",
						size = 12,
						color = Palette.creamSoft,
						wrap = true,
						position = UDim2.fromOffset(0, 34),
						sizeConstraint = UDim2.new(1, 0, 0, 36),
					}), React.createElement(Text, {
						value = (guide and guide.Benefits) or "Shared production, vault, offline, automation, and tap boosts.",
						size = 11,
						color = Palette.violet,
						weight = Enum.FontWeight.Bold,
						wrap = true,
						position = UDim2.fromOffset(0, 78),
						sizeConstraint = UDim2.new(1, 0, 0, 28),
					})),
				},
				{
					id = "join",
					height = joinBlockH,
					element = React.createElement("frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					}, React.createElement("uilistlayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, pageGap),
					}), React.createElement(JoinOrCreate, {
						config = config,
						dispatch = send,
						reducedMotion = reducedMotion,
						busy = busy,
						shakeToken = shakeToken,
						stack = stack,
						cash = state.Cash,
					})),
				},
			},
		})
	end
	local members = {}
	for key, member in pairs(guild.Members) do
		local _arg0 = {
			key = key,
			name = member.Name,
			role = member.Role,
			contributed = member.Contributed,
		}
		table.insert(members, _arg0)
	end
	table.sort(members, function(left, right)
		local _condition = ROLE_RANK[left.role]
		if _condition == nil then
			_condition = 3
		end
		local leftRank = _condition
		local _condition_1 = ROLE_RANK[right.role]
		if _condition_1 == nil then
			_condition_1 = 3
		end
		local rightRank = _condition_1
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end
		return left.contributed > right.contributed
	end)
	local totalContributed = 0
	for _, member in members do
		totalContributed += member.contributed
	end
	local _result = guild.Members[localKey]
	if _result ~= nil then
		_result = _result.Role
	end
	local _condition = _result
	if _condition == nil then
		_condition = "Member"
	end
	local myRole = _condition
	local canManage = myRole == "Leader"
	local canBuy = myRole == "Leader" or myRole == "Officer"
	local rows = buildUpgradeRows(config, guild)
	local _goalContributors = guild.Goal
	if _goalContributors ~= nil then
		_goalContributors = _goalContributors.Contributors
	end
	local goalContributors = _goalContributors
	local pageGap = if stack then 12 else Layout.panelGap
	local heroHeight = if stack then 218 else 188
	local goalHeight = if guild.Goal == nil then 116 elseif stack then 234 else 196
	local bankHeight = if stack then 310 else 216
	local upgradeHeight = if stack then 180 else 140
	local memberHeight = if stack then 122 elseif canManage then 112 else 84
	local sectionLabelH = 34
	local heroSurface = darken(Palette.violet, 0.9)
	local _attributes = {}
	local _exp_2 = guild.Tag
	local _exp_3 = #members
	local _result_1 = config.Guild
	if _result_1 ~= nil then
		_result_1 = _result_1.MaxMembers
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 20
	end
	_attributes.value = `[{_exp_2}]  •  {_exp_3}/{_condition_1} MEMBERS`
	_attributes.size = 10
	_attributes.color = ensureContrast(heroSurface, Palette.violet)
	_attributes.weight = Enum.FontWeight.Heavy
	_attributes.sizeConstraint = UDim2.new(1, -8, 0, 14)
	local _exp_4 = React.createElement(Text, _attributes)
	local _exp_5 = React.createElement(Text, {
		value = guild.Name,
		size = if stack then 24 else 31,
		color = ensureContrast(heroSurface, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 17,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, -8, 0, 38),
	})
	local _exp_6 = React.createElement(Text, {
		value = `ACTIVITY {compactNumber(guild.Activity)}  •  YOU ARE {string.upper(myRole)}`,
		size = 11,
		color = ensureContrast(heroSurface, Palette.creamSoft),
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, if stack then 62 else 64),
		sizeConstraint = UDim2.new(1, -8, 0, 18),
	})
	local _attributes_1 = {}
	local _result_2 = state.GuildBonuses
	if _result_2 ~= nil then
		_result_2 = _result_2.Production
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local _exp_7 = percentText(_condition_2)
	local _result_3 = state.GuildBonuses
	if _result_3 ~= nil then
		_result_3 = _result_3.Capacity
	end
	local _condition_3 = _result_3
	if _condition_3 == nil then
		_condition_3 = 0
	end
	local _exp_8 = percentText(_condition_3)
	local _result_4 = state.GuildBonuses
	if _result_4 ~= nil then
		_result_4 = _result_4.Offline
	end
	local _condition_4 = _result_4
	if _condition_4 == nil then
		_condition_4 = 0
	end
	local _exp_9 = percentText(_condition_4)
	local _result_5 = state.GuildBonuses
	if _result_5 ~= nil then
		_result_5 = _result_5.Automation
	end
	local _condition_5 = _result_5
	if _condition_5 == nil then
		_condition_5 = 0
	end
	local _exp_10 = percentText(_condition_5)
	local _result_6 = state.GuildBonuses
	if _result_6 ~= nil then
		_result_6 = _result_6.Tap
	end
	local _condition_6 = _result_6
	if _condition_6 == nil then
		_condition_6 = 0
	end
	_attributes_1.value = `SHARED BONUSES  {_exp_7} production  •  {_exp_8} vault  •  {_exp_9} offline  •  {_exp_10} auto  •  {percentText(_condition_6)} tap`
	_attributes_1.size = 10
	_attributes_1.color = ensureContrast(heroSurface, Palette.mint)
	_attributes_1.wrap = true
	_attributes_1.position = UDim2.fromOffset(0, if stack then 86 else 88)
	_attributes_1.sizeConstraint = UDim2.new(1, -8, 0, if stack then 46 else 32)
	local _exp_11 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = heroSurface,
		padding = if stack then 16 else 20,
		reveal = reveal,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp_4, _exp_5, _exp_6, React.createElement(Text, _attributes_1), if canManage and #members == 1 then React.createElement(Button, {
		text = "DISBAND",
		onClick = function()
			if not busy then
				send("DisbandGuild", {})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.coral,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.fromOffset(140, 42),
		position = if stack then UDim2.new(0, 0, 1, -42) else UDim2.new(1, -140, 1, -42),
		reducedMotion = reducedMotion,
	}) else React.createElement(Button, {
		text = "LEAVE",
		onClick = function()
			if not busy then
				send("LeaveGuild", {})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.coral,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.fromOffset(140, 42),
		position = if stack then UDim2.new(0, 0, 1, -42) else UDim2.new(1, -140, 1, -42),
		reducedMotion = reducedMotion,
	}))
	local _exp_12 = React.createElement(GuildGoalCard, {
		guild = guild,
		config = config,
		layoutOrder = 0,
		stack = stack,
		reducedMotion = reducedMotion,
		dispatch = send,
		busy = busy,
		shakeToken = shakeToken,
	})
	local _exp_13 = React.createElement(Text, {
		value = "GUILD BANK",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _exp_14 = React.createElement(Text, {
		value = `{compactNumber(guild.BankCash)} flux  •  {compactNumber(guild.BankDust)} dust`,
		size = if stack then 17 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 13,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	})
	local _exp_15 = React.createElement(Text, {
		value = "Deposits fund every hall upgrade and count toward the guild goal.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 46),
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	})
	local _exp_16 = React.createElement("textbox", {
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -6, 0, 40),
		Position = UDim2.fromOffset(0, 76),
		PlaceholderText = "Flux amount",
		Text = contributeCash,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Change = {
			Text = function(box)
				return setContributeCash(box.Text)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}))
	local _attributes_2 = {
		text = "DEPOSIT FLUX",
		onClick = function()
			local amount = tonumber(contributeCash)
			if amount ~= nil and amount >= 1 and not busy then
				send("ContributeGuild", {
					Amount = math.floor(amount),
					Currency = "Cash",
				})
				setContributeCash("")
			end
		end,
		color = Palette.mango,
		textColor = Palette.ink,
	}
	local _condition_7 = busy
	if not _condition_7 then
		local _condition_8 = tonumber(contributeCash)
		if _condition_8 == nil then
			_condition_8 = 0
		end
		_condition_7 = _condition_8 < 1
	end
	_attributes_2.disabled = _condition_7
	_attributes_2.size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.new(0.5, -6, 0, 42)
	_attributes_2.position = if stack then UDim2.fromOffset(0, 126) else UDim2.new(0, 0, 0, 128)
	_attributes_2.reducedMotion = reducedMotion
	local _exp_17 = React.createElement(Button, _attributes_2)
	local _exp_18 = React.createElement("textbox", {
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -6, 0, 40),
		Position = if stack then UDim2.fromOffset(0, 172) else UDim2.new(0.5, 6, 0, 76),
		PlaceholderText = "Dust amount",
		Text = contributeDust,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Change = {
			Text = function(box)
				return setContributeDust(box.Text)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}))
	local _attributes_3 = {
		text = "DEPOSIT DUST",
		onClick = function()
			local amount = tonumber(contributeDust)
			if amount ~= nil and amount >= 1 and not busy then
				send("ContributeGuild", {
					Amount = math.floor(amount),
					Currency = "Dust",
				})
				setContributeDust("")
			end
		end,
		color = Palette.cyan,
		textColor = Palette.ink,
	}
	local _condition_8 = busy
	if not _condition_8 then
		local _condition_9 = tonumber(contributeDust)
		if _condition_9 == nil then
			_condition_9 = 0
		end
		_condition_8 = _condition_9 < 1
	end
	_attributes_3.disabled = _condition_8
	_attributes_3.size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.new(0.5, -6, 0, 42)
	_attributes_3.position = if stack then UDim2.fromOffset(0, 222) else UDim2.new(0.5, 6, 0, 128)
	_attributes_3.reducedMotion = reducedMotion
	local _exp_19 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = if stack then 16 else 18,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp_13, _exp_14, _exp_15, _exp_16, _exp_17, _exp_18, React.createElement(Button, _attributes_3))
	local _exp_20 = React.createElement(SectionLabel, {
		value = "HALL UPGRADES",
		color = Palette.violet,
	})
	local listStride = math.max(upgradeHeight, memberHeight, 150, sectionLabelH) + pageGap
	local listData = {}
	if #rows == 0 then
		table.insert(listData, {
			Id = "empty-upgrades",
			kind = "empty-upgrades",
		})
	else
		for _, row in rows do
			table.insert(listData, {
				Id = `upgrade-{row.id}`,
				kind = "upgrade",
				row = row,
			})
		end
	end
	table.insert(listData, {
		Id = "members-label",
		kind = "members-label",
	})
	for _, member in members do
		table.insert(listData, {
			Id = `member-{member.key}`,
			kind = "member",
			member = member,
		})
	end
	local hallList = React.createElement(FlatList, {
		data = listData,
		itemHeight = listStride,
		headerHeight = 0,
		overscan = if antilag.tier <= 1 or antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 3,
		scrollBarTransparency = 0.28,
		keyExtractor = function(entry)
			return entry.Id
		end,
		renderItem = function(_param_1)
			local entry = _param_1.item
			if entry.kind == "empty-upgrades" then
				return React.createElement(EmptyState, {
					title = "No hall upgrades",
					body = "Upgrade definitions are still loading.",
					icon = "Forge",
					accent = Palette.violet,
					size = UDim2.fromScale(1, 1),
				})
			elseif entry.kind == "members-label" then
				return React.createElement(SectionLabel, {
					value = "MEMBERS",
					color = Palette.cyan,
					layoutOrder = 0,
				})
			elseif entry.kind == "upgrade" then
				return React.createElement(UpgradeCard, {
					row = entry.row,
					guild = guild,
					canBuy = canBuy,
					stack = stack,
					reducedMotion = reducedMotion,
					dispatch = send,
					busy = busy,
					shakeToken = shakeToken,
					layoutOrder = 0,
				})
			end
			local member = entry.member
			local share = 0
			if goalContributors ~= nil then
				share = goalContributors[member.key] or 0
			end
			return React.createElement(MemberRow, {
				userKey = member.key,
				name = member.name,
				role = member.role,
				contributed = member.contributed,
				goalShare = share,
				share = if totalContributed > 0 then member.contributed / totalContributed else 0,
				isLocal = member.key == localKey,
				canManage = canManage and member.key ~= localKey,
				isLeader = member.role == "Leader",
				stack = stack,
				reducedMotion = reducedMotion,
				dispatch = send,
				busy = busy,
				shakeToken = shakeToken,
				layoutOrder = 0,
			})
		end,
	})
	return React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 80),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero",
				height = heroHeight,
				element = _exp_11,
			},
			{
				id = "goal",
				height = goalHeight,
				element = _exp_12,
			},
			{
				id = "bank",
				height = bankHeight,
				element = _exp_19,
			},
			{
				id = "upgrades-label",
				height = sectionLabelH,
				element = _exp_20,
			},
			{
				id = "hall-list",
				fill = true,
				minHeight = math.max(180, listStride * 2),
				element = hallList,
			},
		},
	})

end
return {
	GuildView = GuildView,
}
