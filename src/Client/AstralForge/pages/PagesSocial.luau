--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesSocial: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesSocial: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["TradeView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local unixNow = require(script.Parent.Parent.CoreKit)("deadlines").unixNow
local TradeHistory = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("TradeHistory"))
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local QuantityStepper = _ui.QuantityStepper
local SearchField = _ui.SearchField
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Stroke = _ui.Stroke
local Text = _ui.Text
local BOOSTS = { "DomainSurge", "Overdrive", "Hyperdrive", "VaultSurge", "NightShift", "FoundryRush", "Afterburner", "SteadyBurn", "CoreSurge", "StarforgeFlow", "EchoDrive", "Ionstorm", "TwinCatalyst", "MidnightForge" }
local KEYS = { "ForgeCrate", "CrystalCrate", "HorizonCrate", "NebulaCrate", "OrbitCrate", "SingularityCrate", "EchoCrate" }
local BOOST_LABELS = {
	Overdrive = "Overdrive",
	Hyperdrive = "Hyperdrive",
	VaultSurge = "Vault Surge",
	DomainSurge = "Domain Surge",
	NightShift = "Night Shift",
	FoundryRush = "Foundry Rush",
	Afterburner = "Afterburner",
	SteadyBurn = "Steady Burn",
	CoreSurge = "Core Surge",
	StarforgeFlow = "Starforge Flow",
	EchoDrive = "Echo Drive",
	Ionstorm = "Ionstorm",
	TwinCatalyst = "Twin Catalyst",
	MidnightForge = "Midnight Forge",
}
local KEY_LABELS = {
	ForgeCrate = "Forge key",
	CrystalCrate = "Crystal key",
	HorizonCrate = "Horizon key",
	NebulaCrate = "Nebula key",
	OrbitCrate = "Orbit key",
	SingularityCrate = "Singularity key",
	EchoCrate = "Echo key",
}
local function emptyOffer()
	return {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boosts = {
			DomainSurge = 0,
			Overdrive = 0,
			Hyperdrive = 0,
			VaultSurge = 0,
			NightShift = 0,
			FoundryRush = 0,
			Afterburner = 0,
			SteadyBurn = 0,
			CoreSurge = 0,
			StarforgeFlow = 0,
			EchoDrive = 0,
			Ionstorm = 0,
			TwinCatalyst = 0,
			MidnightForge = 0,
		},
		Keys = {
			ForgeCrate = 0,
			CrystalCrate = 0,
			HorizonCrate = 0,
			NebulaCrate = 0,
			OrbitCrate = 0,
			SingularityCrate = 0,
			EchoCrate = 0,
		},
		ItemIds = {},
		Items = {},
	}
end
local function wireOffer(offer)
	if type(offer) ~= "table" then
		return emptyOffer()
	end
	local result = {
		Cash = tonumber(offer.Cash) or 0,
		Stardust = tonumber(offer.Stardust) or 0,
		Cores = tonumber(offer.Cores) or 0,
		Signals = tonumber(offer.Signals) or 0,
		Essence = tonumber(offer.Essence) or 0,
		Boosts = {},
		Keys = {},
		ItemIds = if type(offer.ItemIds) == "table" then table.clone(offer.ItemIds) else {},
	}
	for _, id in BOOSTS do
		local amount = offer.Boosts and tonumber(offer.Boosts[id]) or 0
		if amount > 0 then
			result.Boosts[id] = amount
		end
	end
	for _, id in KEYS do
		local amount = offer.Keys and tonumber(offer.Keys[id]) or 0
		if amount > 0 then
			result.Keys[id] = amount
		end
	end
	return result
end
local function itemName(config, definitionId)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Definitions
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	for _, definition in _condition do
		if definition.Id == definitionId then
			return definition.Name
		end
	end
	return definitionId
end
local function clockLabel(deadline, now)
	local left = math.max(0, math.floor(deadline - now))
	local minutes = math.floor(left / 60)
	local seconds = left % 60
	return if minutes > 0 then `{minutes}:{string.format("%02d", seconds)}` else `{seconds}s`
end
local function offerEmpty(offer)
	if offer.Cash > 0 or offer.Stardust > 0 or offer.Cores > 0 or offer.Signals > 0 or offer.Essence > 0 then
		return false
	end
	for _, id in BOOSTS do
		local _condition = offer.Boosts[id]
		if _condition == nil then
			_condition = 0
		end
		if _condition > 0 then
			return false
		end
	end
	for _, id in KEYS do
		local _condition = offer.Keys[id]
		if _condition == nil then
			_condition = 0
		end
		if _condition > 0 then
			return false
		end
	end
	return #offer.ItemIds == 0
end
local function offerLines(offer, config, inventory)
	local lines = {}
	if offer.Cash > 0 then
		local _arg0 = {
			key = "cash",
			label = `{compactNumber(offer.Cash)} Flux`,
			detail = "Currency",
			accent = Palette.cyan,
			icon = "Flux.15",
		}
		table.insert(lines, _arg0)
	end
	if offer.Stardust > 0 then
		local _arg0 = {
			key = "dust",
			label = `{compactNumber(offer.Stardust)} Stardust`,
			detail = "Dust",
			accent = Palette.mango,
			icon = "Dust.4",
		}
		table.insert(lines, _arg0)
	end
	if offer.Cores > 0 then
		local _arg0 = {
			key = "cores",
			label = `{offer.Cores} Cores`,
			detail = "Prestige",
			accent = Palette.violet,
			icon = "Core.6",
		}
		table.insert(lines, _arg0)
	end
	if offer.Signals > 0 then
		local _arg0 = {
			key = "signals",
			label = `{offer.Signals} Signals`,
			detail = "Command",
			accent = Palette.cyan,
			icon = "Command.3",
		}
		table.insert(lines, _arg0)
	end
	if offer.Essence > 0 then
		local _arg0 = {
			key = "essence",
			label = `{offer.Essence} Essence`,
			detail = "Relic craft",
			accent = Palette.pink,
			icon = "Artifact.6",
		}
		table.insert(lines, _arg0)
	end
	for _, id in BOOSTS do
		local _condition = offer.Boosts[id]
		if _condition == nil then
			_condition = 0
		end
		local count = _condition
		if count > 0 then
			local _object = {
				key = `boost-{id}`,
			}
			local _left = "label"
			local _condition_1 = BOOST_LABELS[id]
			if _condition_1 == nil then
				_condition_1 = id
			end
			_object[_left] = `{count}× {_condition_1}`
			_object.detail = "Boost"
			_object.accent = Palette.coral
			_object.icon = "Boost.17"
			table.insert(lines, _object)
		end
	end
	for _, id in KEYS do
		local _condition = offer.Keys[id]
		if _condition == nil then
			_condition = 0
		end
		local count = _condition
		if count > 0 then
			local _object = {
				key = `key-{id}`,
			}
			local _left = "label"
			local _condition_1 = KEY_LABELS[id]
			if _condition_1 == nil then
				_condition_1 = id
			end
			_object[_left] = `{count}× {_condition_1}`
			_object.detail = "Crate key"
			_object.accent = Palette.mango
			_object.icon = "Crate.6"
			table.insert(lines, _object)
		end
	end
	local previews = offer.Items or {}
	if #previews > 0 then
		for _, preview in previews do
			local _arg0 = {
				key = preview.Uid,
				label = preview.Name,
				detail = "Relic",
				accent = Palette.mint,
				icon = "Inventory.2",
			}
			table.insert(lines, _arg0)
		end
	else
		for _, uid in offer.ItemIds do
			local instance = inventory[uid]
			local _arg0 = {
				key = uid,
				label = if instance ~= nil then itemName(config, instance.DefinitionId) else "Relic",
				detail = "Relic",
				accent = Palette.mint,
				icon = "Inventory.3",
			}
			table.insert(lines, _arg0)
		end
	end
	return lines
end
local function useSecondClock()
	local now, setNow = React.useState(unixNow())
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.5)
				if not alive then
					break
				end
				setNow(unixNow())
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, {})
	return now
end
local function AvatarMark(_param)
	local userId = _param.userId
	local accent = _param.accent
	local size = _param.size
	local position = _param.position
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundColor3 = darken(accent, 0.62),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Stroke, {
		color = accent,
		thickness = 1,
		transparency = 0.28,
	}), React.createElement("imagelabel", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={if userId > 0 then userId else 1}&w=150&h=150`,
		ScaleType = Enum.ScaleType.Crop,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function OfferRow(_param)
	local line = _param.line
	local touch = _param.touch
	if touch == nil then
		touch = false
	end
	local rowH = if touch then 56 else 50
	local tile = if touch then 40 else 36
	local textX = tile + 16
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Stroke, {
		color = line.accent,
		thickness = 1,
		transparency = 0.5,
	}), React.createElement(IconTile, {
		kind = line.icon,
		accent = line.accent,
		size = tile,
		radius = 10,
		position = UDim2.fromOffset(8, math.floor((rowH - tile) / 2)),
		spin = false,
		reducedMotion = true,
	}), React.createElement(Text, {
		value = line.label,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(textX, if touch then 6 else 5),
		sizeConstraint = UDim2.new(1, -(textX + 12), 0, 22),
	}), React.createElement(Text, {
		value = line.detail,
		size = 12,
		color = line.accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(textX, if touch then 30 else 28),
		sizeConstraint = UDim2.new(1, -(textX + 12), 0, 16),
	}))
end
local function RelicPick(_param)
	local name = _param.name
	local picked = _param.picked
	local reducedMotion = _param.reducedMotion
	local onToggle = _param.onToggle
	local touch = _param.touch
	if touch == nil then
		touch = false
	end
	return React.createElement(Button, {
		text = `{if picked then "IN OFFER  ·  " else ""}{name}`,
		icon = "Inventory.4",
		onClick = onToggle,
		color = if picked then Palette.mint else Palette.panelSoft,
		textColor = if picked then Palette.ink else Palette.cream,
		size = UDim2.new(1, 0, 0, if touch then TapTarget else 40),
		reducedMotion = reducedMotion,
		highlight = picked,
	})
end


local function calcOfferValue(offer)
	if type(offer) ~= "table" then return 0 end
	local total = (tonumber(offer.Cash) or 0) / 10000
		+ (tonumber(offer.Stardust) or 0) * 10
		+ (tonumber(offer.Cores) or 0) * 1000
		+ (tonumber(offer.Signals) or 0) * 20
		+ (tonumber(offer.Essence) or 0) * 15
	if type(offer.Boosts) == "table" then
		for _, count in pairs(offer.Boosts) do
			total += (tonumber(count) or 0) * 450
		end
	end
	if type(offer.Keys) == "table" then
		for _, count in pairs(offer.Keys) do
			total += (tonumber(count) or 0) * 350
		end
	end
	if type(offer.ItemIds) == "table" then
		total += #offer.ItemIds * 800
	end
	return math.round(total)
end

local function TradeFairnessMeter(props)
	local yourScore = calcOfferValue(props.draft)
	local theirScore = calcOfferValue(props.them)
	local total = yourScore + theirScore
	local yourRatio = if total > 0 then yourScore / total else 0.5
	local balanceText, balanceColor
	if total == 0 then
		balanceText = "Place items or currencies on the table to compare cosmic trade balance."
		balanceColor = Palette.muted
	elseif yourRatio >= 0.42 and yourRatio <= 0.58 then
		balanceText = "Fair Exchange · Equal Cosmic Weight"
		balanceColor = Palette.mint
	elseif yourRatio > 0.58 then
		local adv = math.round((yourRatio - 0.5) * 200)
		balanceText = `Generous Offer (+{adv}% extra value to partner)`
		balanceColor = Palette.mango
	else
		local adv = math.round((0.5 - yourRatio) * 200)
		balanceText = `Favorable Offer (+{adv}% extra value to you)`
		balanceColor = Palette.cyan
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 8) }),
	React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}),
	React.createElement(Text, {
		value = balanceText,
		size = 12,
		color = balanceColor,
		weight = Enum.FontWeight.Bold,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}),
	React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.fromOffset(0, 24),
		BackgroundColor3 = Palette.graphite,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
	React.createElement("frame", {
		Size = UDim2.new(yourRatio, 0, 1, 0),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
	React.createElement("frame", {
		Size = UDim2.new(1 - yourRatio, 0, 1, 0),
		Position = UDim2.new(yourRatio, 0, 0, 0),
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))))
end

-- quick phrases: the same list as the server's (TradeDesk.PHRASES), sent by index so they never need filtering
local TRADE_PHRASES = {
	"Deal?", "Can you add a little more?", "That's fair.", "Not for that.",
	"Let me look.", "Ready when you are.", "Thanks for the trade.", "One sec.",
}

-- table talk: the real conversation from the server, quick phrases, and a filtered line of your own
local function TradeChatStream(props)
	local session = props.session
	local dispatch = props.dispatch
	local inputVal, setInputVal = React.useState("")
	local scrollRef = React.useRef(nil)
	local lines = session.Chat or {}
	local myId = Players.LocalPlayer.UserId
	local seen = React.useRef(#lines)
	React.useEffect(function()
		-- a new line from them gets a sound; the list stays pinned to the newest line
		if #lines > seen.current and lines[#lines] and lines[#lines].From ~= myId then
			Audio:play("chatReceive")
		end
		seen.current = #lines
		local list = scrollRef.current
		if list then
			task.defer(function()
				list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y))
			end)
		end
	end, { #lines })
	local function send(text, phrase)
		local clean = if text then string.gsub(text, "^%s*(.-)%s*$", "%1") else nil
		if phrase == nil and (clean == nil or clean == "") then
			return
		end
		Audio:play("chatSend")
		dispatch("TradeChat", if phrase then { Phrase = phrase } else { Text = string.sub(clean, 1, 140) })
		setInputVal("")
	end
	local pills = {
		layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, phrase in TRADE_PHRASES do
		pills["p" .. index] = React.createElement("textbutton", {
			LayoutOrder = index,
			Text = phrase,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Palette.panelSoft,
			TextColor3 = Palette.cream,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			AutoButtonColor = false,
			Event = {
				Activated = function()
					send(nil, index)
				end,
			},
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }), React.createElement("uipadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}))
	end
	local rows = {
		layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if #lines == 0 then
		rows.empty = React.createElement(Text, {
			value = `Nothing said yet. Talk it through with {session.PartnerName}.`,
			size = 12,
			color = Palette.muted,
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		})
	end
	for index, line in lines do
		local mine = line.From == myId
		rows["l" .. index] = React.createElement("frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, React.createElement("textlabel", {
			Size = UDim2.new(0.82, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromScale(if mine then 1 else 0, 0),
			AnchorPoint = Vector2.new(if mine then 1 else 0, 0),
			BackgroundColor3 = if mine then darken(Palette.mint, 0.6) else Palette.panelSoft,
			Text = (if mine then "" else `<b>{line.Name}</b>  `) .. line.Text,
			RichText = true,
			TextWrapped = true,
			TextSize = 13,
			FontFace = Font.fromEnum(if line.Phrase then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium),
			TextColor3 = Palette.cream,
			TextXAlignment = if mine then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement("uipadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		})))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }), React.createElement(Stroke, {
		color = Palette.line,
		thickness = 1,
		transparency = 0.4,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}), React.createElement(Text, {
		value = if session.PartnerAway then `TABLE TALK  ·  {string.upper(session.PartnerName)} STEPPED AWAY` else "TABLE TALK",
		size = 11,
		color = if session.PartnerAway then Palette.coral else Palette.mint,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement("scrollingframe", {
		ref = scrollRef,
		Size = UDim2.new(1, 0, 1, -(18 + 32 + 38)),
		Position = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.muted,
	}, rows), React.createElement("scrollingframe", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -(32 + 36)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
	}, pills), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 1, -32),
		BackgroundTransparency = 1,
	}, React.createElement("textbox", {
		Size = UDim2.new(1, -78, 1, 0),
		BackgroundColor3 = Palette.graphite,
		TextColor3 = Palette.cream,
		PlaceholderText = `Say something to {session.PartnerName}`,
		PlaceholderColor3 = Palette.muted,
		Text = inputVal,
		TextSize = 13,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Change = {
			Text = function(rbx)
				if #rbx.Text > 140 then
					rbx.Text = string.sub(rbx.Text, 1, 140)
				end
				setInputVal(rbx.Text)
			end,
		},
		Event = {
			FocusLost = function(_, enterPressed)
				if enterPressed then
					send(inputVal)
				end
			end,
		},
	}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 8) }), React.createElement("uipadding", { PaddingLeft = UDim.new(0, 10) })), React.createElement(Button, {
		text = "Send",
		onClick = function()
			send(inputVal)
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(0, 70, 1, 0),
		position = UDim2.new(1, -70, 0, 0),
	})))
end

-- asking: browse what they could trade and ask for it; see what they asked of you and add it in one tap
local RARITY_COLOR = {
	Common = Palette.muted, Uncommon = Palette.mint, Rare = Palette.cyan, Epic = Palette.violet,
	Legendary = Palette.mango, Mythic = Palette.pink,
}
local function TradeAsks(props)
	local session = props.session
	local myRelics = props.myRelics
	local asked, setAsked = React.useState(function()
		local set = {}
		for _, uid in (session.YourRequest and session.YourRequest.ItemIds) or {} do
			set[uid] = true
		end
		return set
	end)
	local askCount = 0
	for _ in asked do
		askCount += 1
	end
	local relicNames = {}
	for _, relic in session.PartnerRelics or {} do
		relicNames[relic.Uid] = relic.Name
	end
	-- what they asked you for, and how much of it you actually have
	local theirs = session.TheirRequest
	local theirLine = nil
	if theirs then
		local parts = {}
		for _, key in { "Cash", "Stardust", "Cores", "Signals", "Essence" } do
			if (tonumber(theirs[key]) or 0) > 0 then
				table.insert(parts, `{compactNumber(theirs[key])} {if key == "Cash" then "Flux" else key}`)
			end
		end
		local mine = {}
		for _, relic in myRelics do
			mine[relic.uid] = relic.name
		end
		for _, uid in theirs.ItemIds or {} do
			if mine[uid] then
				table.insert(parts, mine[uid])
			end
		end
		theirLine = if #parts > 0 then table.concat(parts, ", ") else nil
	end
	local chips = {
		layout = React.createElement("uigridlayout", {
			CellSize = UDim2.new(0.5, -4, 0, 40),
			CellPadding = UDim2.fromOffset(8, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, relic in session.PartnerRelics or {} do
		local on = asked[relic.Uid] == true
		local color = RARITY_COLOR[relic.Rarity] or Palette.muted
		chips["r" .. relic.Uid] = React.createElement("textbutton", {
			LayoutOrder = index,
			BackgroundColor3 = if on then darken(color, 0.55) else Palette.panelSoft,
			AutoButtonColor = false,
			Text = "",
			Event = {
				Activated = function()
					Audio:play("tick")
					setAsked(function(current)
						local nextSet = table.clone(current)
						nextSet[relic.Uid] = if nextSet[relic.Uid] then nil else true
						return nextSet
					end)
				end,
			},
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement(Stroke, {
			color = if on then color else Palette.line,
			thickness = if on then 2 else 1,
			transparency = if on then 0 else 0.5,
		}), React.createElement(Text, {
			value = relic.Name,
			size = 12,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(10, 4),
			sizeConstraint = UDim2.new(1, -20, 0, 16),
		}), React.createElement(Text, {
			value = `{string.upper(relic.Rarity)}  ·  L{relic.Level}{if on then "  ·  ASKED" else ""}`,
			size = 10,
			color = color,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(10, 21),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}))
	end
	local partnerCount = #(session.PartnerRelics or {})
	local gridRows = math.ceil(partnerCount / 2)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }), React.createElement(Stroke, {
		color = Palette.line,
		thickness = 1,
		transparency = 0.4,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), theirLine and React.createElement("frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = darken(Palette.mango, 0.7),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement(Text, {
		value = `{string.upper(session.PartnerName)} ASKED FOR`,
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 6),
		sizeConstraint = UDim2.new(1, -150, 0, 14),
	}), React.createElement(Text, {
		value = theirLine,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, 24),
		sizeConstraint = UDim2.new(1, -150, 0, 26),
	}), React.createElement(Button, {
		text = "Add to my offer",
		onClick = function()
			props.onAddRequested(theirs)
		end,
		color = Palette.mango,
		textColor = Palette.ink,
		size = UDim2.fromOffset(130, 36),
		position = UDim2.new(1, -140, 0.5, -18),
	})) or nil, React.createElement(Text, {
		value = if partnerCount == 0 then `{session.PartnerName} has no relics they could trade right now.` else `ASK {string.upper(session.PartnerName)} FOR THEIR RELICS`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), partnerCount > 0 and React.createElement("frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, gridRows * 46),
		BackgroundTransparency = 1,
	}, chips) or nil, partnerCount > 0 and React.createElement("frame", {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, TapTarget),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = if askCount > 0 then `Ask for {askCount} {if askCount == 1 then "relic" else "relics"}` else "Pick relics to ask for",
		onClick = function()
			local ids = {}
			for uid in asked do
				table.insert(ids, uid)
			end
			props.dispatch("TradeRequest", { Request = { ItemIds = ids } })
		end,
		disabled = askCount == 0,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
	})) or nil)
end
-- how tall TradeAsks wants to be
local function tradeAsksHeight(session)
	local partnerCount = #(session.PartnerRelics or {})
	return 20 + (if session.TheirRequest then 66 else 0) + 24 + (if partnerCount > 0 then math.ceil(partnerCount / 2) * 46 + 8 + TapTarget else 0)
end

local function TradeView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(reducedMotion)
	local reveal = useStagger(0, softMotion)
	local boardReveal = useStagger(1, reducedMotion)
	local inviteReveal = useStagger(2, reducedMotion)
	local confirmReveal = useStagger(3, reducedMotion)
	local deskReveal = useStagger(4, reducedMotion)
	local dailyReveal = useStagger(5, reducedMotion)
	local softInvite = softMotion or inviteReveal ~= nil
	local softConfirm = softMotion or confirmReveal ~= nil
	local tradeSoft = softMotion or deskReveal == nil or dailyReveal == nil
	local now = useSecondClock()
	local trade = state.Trade
	local _result = trade
	if _result ~= nil then
		_result = _result.Unlocked
	end
	local unlocked = _result == true
	local _session = trade
	if _session ~= nil then
		_session = _session.Session
	end
	local session = _session
	local _invite = trade
	if _invite ~= nil then
		_invite = _invite.Invite
	end
	local invite = _invite
	local _outgoing = trade
	if _outgoing ~= nil then
		_outgoing = _outgoing.Outgoing
	end
	local outgoing = _outgoing
	local _daily = trade
	if _daily ~= nil then
		_daily = _daily.Daily
	end
	local daily = _daily
	local rows, setRows = React.useState({})
	local query, setQuery = React.useState("")
	local selected, setSelected = React.useState(0)
	local draft, setDraft = React.useState(emptyOffer())
	local youReadyLocal, setYouReadyLocal = React.useState(false)
	local busy, setBusy = React.useState("")
	local shakeAction, setShakeAction = React.useState()
	local offerTab, setOfferTab = React.useState("You")
	local dirtyRef = React.useRef(false)
	local flushRef = React.useRef(nil)
	local offerRevisionRef = React.useRef(0)
	local offerSessionRef = React.useRef(if session ~= nil then session.Id else nil)
	local offerPending, setOfferPending = React.useState(false)
	local sessionActionsHostRef = React.useRef(nil)
	local _result_1 = state.Items
	if _result_1 ~= nil then
		_result_1 = _result_1.Inventory
	end
	local _condition = _result_1
	if _condition == nil then
		_condition = {}
	end
	local inventory = _condition
	local equippedUids = {}
	local _result_2 = state.Items
	if _result_2 ~= nil then
		_result_2 = _result_2.Equipped
	end
	local _condition_1 = _result_2
	if _condition_1 == nil then
		_condition_1 = {}
	end
	for _, uid in pairs(_condition_1) do
		if uid ~= "" then
			equippedUids[uid] = true
		end
	end
	local loadRoster = React.useCallback(function()
		dispatch("GetPlayers", {}, function(response)
			if not response.ok then
				return nil
			end
			local roster = {}
			for _, row in response.Players or {} do
				if not row.IsLocal then
					table.insert(roster, row)
				end
			end
			setRows(roster)
			if selected == 0 and #roster > 0 then
				setSelected(roster[1].UserId)
			end
		end)
	end, { dispatch, selected })
	local _exp = function()
		loadRoster()
		local added = Players.PlayerAdded:Connect(function()
			return loadRoster()
		end)
		local removed = Players.PlayerRemoving:Connect(function()
			return loadRoster()
		end)
		local alive = true
		local pulse = task.spawn(function()
			while alive do
				task.wait(4)
				if not alive then
					break
				end
				if session == nil then
					loadRoster()
				end
			end
		end)
		return function()
			alive = false
			added:Disconnect()
			removed:Disconnect()
			pcall(task.cancel, pulse)
		end
	end
	local _result_3 = session
	if _result_3 ~= nil then
		_result_3 = _result_3.Id
	end
	React.useEffect(_exp, { loadRoster, _result_3 })
	local _exp_1 = function()
		local sessionId = if session ~= nil then session.Id else nil
		if offerSessionRef.current ~= sessionId then
			offerSessionRef.current = sessionId
			offerRevisionRef.current += 1
			if flushRef.current ~= nil then
				pcall(task.cancel, flushRef.current)
				flushRef.current = nil
			end
			dirtyRef.current = false
			setOfferPending(false)
		end
		if session == nil then
			if flushRef.current ~= nil then
				pcall(task.cancel, flushRef.current)
				flushRef.current = nil
			end
			offerRevisionRef.current += 1
			setOfferPending(false)
			setDraft(emptyOffer())
			setYouReadyLocal(false)
			dirtyRef.current = false
			return nil
		end
		setYouReadyLocal(session.YouReady)
		if not dirtyRef.current then
			setDraft(session.You)
		end
	end
	local _result_4 = session
	if _result_4 ~= nil then
		_result_4 = _result_4.Id
	end
	local _result_5 = trade
	if _result_5 ~= nil then
		_result_5 = _result_5.Epoch
	end
	local _result_6 = session
	if _result_6 ~= nil then
		_result_6 = _result_6.YouReady
	end
	local _result_7 = session
	if _result_7 ~= nil then
		_result_7 = _result_7.ThemReady
	end
	local _result_8 = session
	if _result_8 ~= nil then
		_result_8 = _result_8.YouConfirmed
	end
	React.useEffect(_exp_1, { _result_4, _result_5, _result_6, _result_7, _result_8 })
	React.useEffect(function()
		return function()
			offerRevisionRef.current += 1
			if flushRef.current ~= nil then
				pcall(task.cancel, flushRef.current)
			end
		end
	end, {})
	local queueOffer = function(offer)
		setDraft(offer)
		setYouReadyLocal(false)
		dirtyRef.current = true
		setOfferPending(true)
		offerRevisionRef.current += 1
		local revision = offerRevisionRef.current
		if flushRef.current ~= nil then
			pcall(task.cancel, flushRef.current)
		end
		flushRef.current = task.delay(0.14, function()
			flushRef.current = nil
			dispatch("UpdateTradeOffer", {
				Offer = wireOffer(offer),
			}, function(response)
				if revision ~= offerRevisionRef.current then
					return
				end
				dirtyRef.current = false
				setOfferPending(false)
				if not response.ok and session ~= nil then
					setDraft(session.You)
					setYouReadyLocal(false)
				end
			end)
		end)
	end
	local run = function(action, payload)
		if payload == nil then
			payload = {}
		end
		if busy ~= "" then
			return nil
		end
		setBusy(action)
		dispatch(action, payload, function(response)
			setBusy("")
			if not response.ok then
				if action == "SetTradeReady" then
					setYouReadyLocal(session ~= nil and session.YouReady == true)
				end
				setShakeAction(function(current)
					local _object = {
						action = action,
					}
					local _left = "token"
					local _result_9 = current
					if _result_9 ~= nil then
						_result_9 = _result_9.action
					end
					_object[_left] = (if _result_9 == action then current.token else 0) + 1
					return _object
				end)
			end
		end)
	end
	local shakeFor = function(action)
		local _result_9 = shakeAction
		if _result_9 ~= nil then
			_result_9 = _result_9.action
		end
		return if _result_9 == action then shakeAction.token else 0
	end
	local cap = function(key, owned)
		local _result_9 = daily
		if _result_9 ~= nil then
			_result_9 = _result_9.PerTrade[key]
		end
		local per = _result_9
		local _result_10 = daily
		if _result_10 ~= nil then
			_result_10 = _result_10.Sent[key]
		end
		local used = _result_10
		local _result_11 = daily
		if _result_11 ~= nil then
			_result_11 = _result_11.Caps[key]
		end
		local _condition_2 = _result_11
		if _condition_2 == nil then
			_condition_2 = owned
		end
		local _condition_3 = used
		if _condition_3 == nil then
			_condition_3 = 0
		end
		local dailyLeft = _condition_2 - _condition_3
		local _exp_2 = owned
		local _condition_4 = per
		if _condition_4 == nil then
			_condition_4 = owned
		end
		return math.max(0, math.min(_exp_2, _condition_4, dailyLeft))
	end
	local _lock = state.FeatureUnlocks
	if _lock ~= nil then
		_lock = _lock.Trade
	end
	local lock = _lock
	local accent = Palette.mint
	local fade = enter:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local phone = chrome.stack or chrome.mobile
	local compactTrade = phone or chrome.landscape or viewport.height < 700
	local needle = string.lower(query)
	local visibleRows = (function()
		local matches = {}
		for _, row in rows do
			if needle == "" then
				table.insert(matches, row)
				continue
			end
			if require(script.Parent.Parent.BrowseKit).matches(needle, row.DisplayName, row.Name) then
				table.insert(matches, row)
			end
		end
		return matches
	end)()
	local _callback = function(row)
		return row.UserId == selected
	end
	local _result_9
	for _i, _v in visibleRows do
		if _callback(_v, _i - 1, visibleRows) == true then
			_result_9 = _v
			break
		end
	end
	local _condition_2 = _result_9
	if _condition_2 == nil then
		local _callback_1 = function(row)
			return row.UserId == selected
		end
		local _result_10
		for _i, _v in rows do
			if _callback_1(_v, _i - 1, rows) == true then
				_result_10 = _v
				break
			end
		end
		_condition_2 = _result_10
	end
	local selectedRow = _condition_2
	local inviteLive = invite ~= nil and invite.ExpiresAt > now
	local outgoingLive = outgoing ~= nil and outgoing.ExpiresAt > now
	local sessionLeft = if session ~= nil then math.max(0, session.ExpiresAt - now) else 0
	local confirmLeft = if session ~= nil and session.ConfirmEndsAt > 0 then math.max(0, session.ConfirmEndsAt - now) else 0
	local tableEmpty = session ~= nil and offerEmpty(draft) and offerEmpty(session.Them)
	local _condition_3 = youReadyLocal
	if _condition_3 then
		local _result_10 = session
		if _result_10 ~= nil then
			_result_10 = _result_10.ThemReady
		end
		_condition_3 = (_result_10 == true)
	end
	local bothReady = _condition_3
	local lockBanner = not unlocked
	local actionH = if compactTrade then TapTarget * 3 + 24 else TapTarget + 8
	local lockH = if lockBanner and session == nil then (if compactTrade then 92 else 72) else 0
	local inviteH = if inviteLive and session == nil then (if compactTrade then 126 else 92) else 0
	local outgoingH = if outgoingLive and session == nil and not inviteLive then (if compactTrade then 136 else 72) else 0
	local rosterRowH = if compactTrade then 96 else 66
	local searchH = TapTarget
	local relics = {}
	for uid, instance in pairs(inventory) do
		if equippedUids[uid] ~= nil or instance.Locked == true then
			continue
		end
		local _arg0 = {
			uid = uid,
			name = itemName(config, instance.DefinitionId),
		}
		table.insert(relics, _arg0)
		if #relics >= 40 then
			break
		end
	end
	local function addRequested(request)
		if type(request) ~= "table" then
			return
		end
		local offer = table.clone(draft)
		offer.Boosts = table.clone(draft.Boosts or {})
		offer.Keys = table.clone(draft.Keys or {})
		offer.ItemIds = table.clone(draft.ItemIds or {})
		local owned = {
			Cash = asFlux(state.Cash),
			Stardust = tonumber(state.Stardust) or 0,
			Cores = asFlux(state.Cores),
			Signals = state.Command and tonumber(state.Command.Signals) or 0,
			Essence = state.Items and tonumber(state.Items.Essence) or 0,
		}
		for key, have in owned do
			local want = tonumber(request[key]) or 0
			if want > 0 then
				offer[key] = math.max(offer[key] or 0, math.min(want, cap(key, have)))
			end
		end
		local mine = {}
		for _, relic in relics do
			mine[relic.uid] = true
		end
		local already = {}
		for _, uid in offer.ItemIds do
			already[uid] = true
		end
		for _, uid in request.ItemIds or {} do
			if mine[uid] and not already[uid] then
				table.insert(offer.ItemIds, uid)
			end
		end
		Audio:play("tick")
		queueOffer(offer)
	end
	local yourLines = offerLines(draft, config, inventory)
	local theirLines = if session ~= nil then offerLines(session.Them, config, inventory) else {}
	local function raritiesOf(offer, fromInventory)
		local list = {}
		local definitions = config.Items and config.Items.Definitions or {}
		local function rarityFor(definitionId)
			for _, definition in definitions do
				if definition.Id == definitionId then return definition.Rarity end
			end
			return nil
		end
		if fromInventory then
			for _, uid in (offer and offer.ItemIds) or {} do
				local instance = inventory[uid]
				local rarity = instance and rarityFor(instance.DefinitionId)
				if rarity then table.insert(list, rarity) end
			end
		else
			for _, preview in (offer and offer.Items) or {} do
				local rarity = rarityFor(preview.DefinitionId)
				if rarity then table.insert(list, rarity) end
			end
		end
		return list
	end
	local tradeWarnings = if session ~= nil then TradeHistory.warnings(draft, session.Them, raritiesOf(draft, true), raritiesOf(session.Them, false)) else {}
	local offerBody = function(editor, lines)
		local _exp_2 = editor and not offerEmpty(draft) and React.createElement(Button, {
			text = "CLEAR OFFER",
			icon = "Refresh.1",
			onClick = function()
				return queueOffer(emptyOffer())
			end,
			color = Palette.panelSoft,
			textColor = Palette.creamSoft,
			size = UDim2.new(1, 0, 0, if phone then TapTarget else 34),
			reducedMotion = softInvite,
		})
		local _condition_4 = editor
		if _condition_4 then
			local _exp_3 = React.createElement(QuantityStepper, {
				label = "Flux",
				detail = if cap("Cash", asFlux(state.Cash)) <= 0 then "None tradable" else `{compactNumber(draft.Cash)} / {compactNumber(cap("Cash", asFlux(state.Cash)))}`,
				value = draft.Cash,
				max = cap("Cash", asFlux(state.Cash)),
				accent = Palette.cyan,
				reducedMotion = softConfirm,
				onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					_object.Cash = value
					return queueOffer(_object)
				end,
			})
			local _exp_4 = React.createElement(QuantityStepper, {
				label = "Stardust",
				value = draft.Stardust,
				max = cap("Stardust", state.Stardust),
				accent = Palette.mango,
				reducedMotion = softMotion,
				onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					_object.Stardust = value
					return queueOffer(_object)
				end,
			})
			local _exp_5 = React.createElement(QuantityStepper, {
				label = "Cores",
				value = draft.Cores,
				max = cap("Cores", state.Cores),
				accent = Palette.violet,
				reducedMotion = softMotion,
				onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					_object.Cores = value
					return queueOffer(_object)
				end,
			})
			local _attributes = {
				label = "Signals",
				value = draft.Signals,
			}
			local _result_10 = state.Command
			if _result_10 ~= nil then
				_result_10 = _result_10.Signals
			end
			local _condition_5 = _result_10
			if _condition_5 == nil then
				_condition_5 = 0
			end
			_attributes.max = cap("Signals", _condition_5)
			_attributes.accent = Palette.cyan
			_attributes.reducedMotion = softMotion
			_attributes.onChange = function(value)
				local _object = table.clone(draft)
				setmetatable(_object, nil)
				_object.Signals = value
				return queueOffer(_object)
			end
			local _exp_6 = React.createElement(QuantityStepper, _attributes)
			local _attributes_1 = {
				label = "Essence",
				value = draft.Essence,
			}
			local _result_11 = state.Items
			if _result_11 ~= nil then
				_result_11 = _result_11.Essence
			end
			local _condition_6 = _result_11
			if _condition_6 == nil then
				_condition_6 = 0
			end
			_attributes_1.max = cap("Essence", _condition_6)
			_attributes_1.accent = Palette.pink
			_attributes_1.reducedMotion = softMotion
			_attributes_1.onChange = function(value)
				local _object = table.clone(draft)
				setmetatable(_object, nil)
				_object.Essence = value
				return queueOffer(_object)
			end
			local _exp_7 = React.createElement(QuantityStepper, _attributes_1)
			local _newValue = table.create(#BOOSTS)
			local _callback_1 = function(id)
				local _result_12 = daily
				if _result_12 ~= nil then
					_result_12 = _result_12.PerTrade.Boost
				end
				local _condition_7 = _result_12
				if _condition_7 == nil then
					_condition_7 = 3
				end
				local perTradeBoostCap = _condition_7
				local _result_13 = 0
				local _callback_2 = function(sum, other)
					local _exp_8 = sum
					local _result_14
					if other == id then
						_result_14 = 0
					else
						local _condition_8 = draft.Boosts[other]
						if _condition_8 == nil then
							_condition_8 = 0
						end
						_result_14 = _condition_8
					end
					return _exp_8 + _result_14
				end
				for _i = 1, #BOOSTS do
					_result_13 = _callback_2(_result_13, BOOSTS[_i], _i - 1, BOOSTS)
				end
				local otherBoostsUsed = _result_13
				local remainingBudget = math.max(0, perTradeBoostCap - otherBoostsUsed)
				local _attributes_2 = {
					key = id,
				}
				local _condition_8 = BOOST_LABELS[id]
				if _condition_8 == nil then
					_condition_8 = id
				end
				_attributes_2.label = _condition_8
				local _condition_9 = draft.Boosts[id]
				if _condition_9 == nil then
					_condition_9 = 0
				end
				_attributes_2.value = _condition_9
				local _result_14 = state.BoostInventory
				if _result_14 ~= nil then
					_result_14 = _result_14[id]
				end
				local _condition_10 = _result_14
				if _condition_10 == nil then
					_condition_10 = 0
				end
				_attributes_2.max = math.min(remainingBudget, _condition_10)
				_attributes_2.accent = Palette.coral
				_attributes_2.reducedMotion = softMotion
				_attributes_2.onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					local _left = "Boosts"
					local _object_1 = table.clone(draft.Boosts)
					setmetatable(_object_1, nil)
					_object_1[id] = value
					_object[_left] = _object_1
					return queueOffer(_object)
				end
				return React.createElement(QuantityStepper, _attributes_2)
			end
			for _k, _v in BOOSTS do
				_newValue[_k] = _callback_1(_v, _k - 1, BOOSTS)
			end
			local _newValue_1 = table.create(#KEYS)
			local _callback_2 = function(id)
				local _attributes_2 = {
					key = id,
				}
				local _condition_7 = KEY_LABELS[id]
				if _condition_7 == nil then
					_condition_7 = id
				end
				_attributes_2.label = _condition_7
				local _condition_8 = draft.Keys[id]
				if _condition_8 == nil then
					_condition_8 = 0
				end
				_attributes_2.value = _condition_8
				local _result_12 = daily
				if _result_12 ~= nil then
					_result_12 = _result_12.PerTrade.Keys
				end
				local _condition_9 = _result_12
				if _condition_9 == nil then
					_condition_9 = 5
				end
				local _result_13 = state.Items
				if _result_13 ~= nil then
					_result_13 = _result_13.Keys[id]
				end
				local _condition_10 = _result_13
				if _condition_10 == nil then
					_condition_10 = 0
				end
				_attributes_2.max = math.min(_condition_9, _condition_10)
				_attributes_2.accent = Palette.mango
				_attributes_2.reducedMotion = softMotion
				_attributes_2.onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					local _left = "Keys"
					local _object_1 = table.clone(draft.Keys)
					setmetatable(_object_1, nil)
					_object_1[id] = value
					_object[_left] = _object_1
					return queueOffer(_object)
				end
				return React.createElement(QuantityStepper, _attributes_2)
			end
			for _k, _v in KEYS do
				_newValue_1[_k] = _callback_2(_v, _k - 1, KEYS)
			end
			local _exp_8 = React.createElement(SectionLabel, {
				value = "Relics",
			})
			local _exp_9 = #relics == 0 and React.createElement(Text, {
				value = "No tradeable relics. Equipped and locked pieces stay home.",
				size = 13,
				color = Palette.muted,
				wrap = true,
				sizeConstraint = UDim2.new(1, 0, 0, 36),
			})
			local _newValue_2 = table.create(#relics)
			local _callback_3 = function(relic)
				local _itemIds = draft.ItemIds
				local _uid = relic.uid
				local picked = table.find(_itemIds, _uid) ~= nil
				return React.createElement(RelicPick, {
					key = relic.uid,
					uid = relic.uid,
					name = relic.name,
					picked = picked,
					touch = phone,
					reducedMotion = softMotion,
					onToggle = function()
						local pickedIds = {}
						if picked then
							for _, id in draft.ItemIds do
								if id ~= relic.uid then
									table.insert(pickedIds, id)
								end
							end
						else
							local _exp_10 = #draft.ItemIds
							local _result_12 = daily
							if _result_12 ~= nil then
								_result_12 = _result_12.PerTrade.Items
							end
							local _condition_7 = _result_12
							if _condition_7 == nil then
								_condition_7 = 6
							end
							if _exp_10 < _condition_7 then
								for _, id in draft.ItemIds do
									table.insert(pickedIds, id)
								end
								local _uid_1 = relic.uid
								table.insert(pickedIds, _uid_1)
							else
								return nil
							end
						end
						local _object = table.clone(draft)
						setmetatable(_object, nil)
						_object.ItemIds = pickedIds
						queueOffer(_object)
					end,
				})
			end
			for _k, _v in relics do
				_newValue_2[_k] = _callback_3(_v, _k - 1, relics)
			end
			_condition_4 = React.createElement(React.Fragment, nil, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _newValue, _newValue_1, _exp_8, _exp_9, _newValue_2)
		end
		local _condition_5 = not editor
		if _condition_5 then
			local _newValue = table.create(#lines)
			local _callback_1 = function(line)
				return React.createElement(OfferRow, {
					key = line.key,
					line = line,
					touch = phone,
				})
			end
			for _k, _v in lines do
				_newValue[_k] = _callback_1(_v, _k - 1, lines)
			end
			_condition_5 = _newValue
		end
		return React.createElement(React.Fragment, nil, _exp_2, _condition_4, _condition_5, not editor and #lines == 0 and React.createElement(Text, {
			value = "Nothing on their side yet.",
			size = 13,
			color = Palette.muted,
			wrap = true,
			sizeConstraint = UDim2.new(1, 0, 0, 32),
		}))
	end
	local offerPane = function(title, partnerName, ready, confirmed, lines, editor, flow, flowOrder)
		if flow == nil then
			flow = false
		end
		local paneAccent = if editor then accent else Palette.cyan
		local header = if flow then React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
			LayoutOrder = 0,
		}, React.createElement(Text, {
			value = title,
			size = 14,
			color = paneAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			sizeConstraint = UDim2.new(1, 0, 0, 20),
		}), React.createElement(Text, {
			value = partnerName,
			size = 13,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}), React.createElement(Badge, {
			value = if confirmed then "CONFIRMED" elseif ready then "READY" else "NOT READY",
			accent = if confirmed then Palette.mango elseif ready then Palette.mint else Palette.muted,
			filled = confirmed or ready,
			position = UDim2.fromOffset(0, 46),
			size = UDim2.fromOffset(120, 28),
		})) else React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
			LayoutOrder = 0,
		}, React.createElement(Text, {
			value = title,
			size = 13,
			color = paneAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			sizeConstraint = UDim2.new(1, -120, 0, 18),
		}), React.createElement(Text, {
			value = partnerName,
			size = 12,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, -120, 0, 18),
		}), React.createElement(Badge, {
			value = if confirmed then "CONFIRMED" elseif ready then "READY" else "NOT READY",
			accent = if confirmed then Palette.mango elseif ready then Palette.mint else Palette.muted,
			filled = confirmed or ready,
			position = UDim2.new(1, -108, 0, 8),
			size = UDim2.fromOffset(108, 28),
		}))
		if flow == false then
			flow = true
		end
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			LayoutOrder = flowOrder,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement(Stroke, {
			color = paneAccent,
			thickness = 1,
			transparency = 0.42,
		}), React.createElement("uipadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}), React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}), header, offerBody(editor, lines))
	end
	local _result_10 = daily
	if _result_10 ~= nil then
		_result_10 = _result_10.Limit
	end
	local _condition_4 = _result_10
	if _condition_4 == nil then
		local _result_11 = config.Trading
		if _result_11 ~= nil then
			_result_11 = _result_11.DailyTrades
		end
		_condition_4 = _result_11
	end
	local dailyLimit = _condition_4
	local dailyLabel = if daily ~= nil and dailyLimit ~= nil then `{daily.Completed} / {dailyLimit} trades today` else "Daily limits on every side"
	local function onReadyClick()
		if offerPending or (tableEmpty and not youReadyLocal) then
			return nil
		end
		local following = not youReadyLocal
		setYouReadyLocal(following)
		run("SetTradeReady", {
			Ready = following,
		})
	end
	local function onConfirmClick()
		return run("ConfirmTrade")
	end
	local function onCancelClick()
		return run("CancelTrade")
	end
	local readyDisabled = busy ~= "" or offerPending or (tableEmpty and not youReadyLocal)
	local confirmDisabled = busy ~= "" or offerPending or not bothReady
	React.useEffect(function()
		if session == nil then
			GamepadNavigationService.EndOverlayFocus()
			return nil
		end
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { session ~= nil })
	React.useEffect(function()
		if session == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = sessionActionsHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { session ~= nil, bothReady, youReadyLocal, tableEmpty, busy, readyDisabled, confirmDisabled })
	local function buildConfirmActions(orientation)
		if session == nil then
			return nil
		end
		local vertical = orientation == "vertical"
		local readySlot = React.createElement("frame", {
			Name = "TradeReady",
			Size = if vertical then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, not vertical and React.createElement("uiflexitem", {
			FlexMode = Enum.UIFlexMode.Fill,
		}), React.createElement(Button, {
			text = if offerPending then "SENDING…" elseif youReadyLocal then "UNREADY" elseif tableEmpty then "ADD SOMETHING FIRST" else "READY",
			onClick = onReadyClick,
			color = if youReadyLocal then Palette.panelSoft else accent,
			textColor = if youReadyLocal then Palette.cream else Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = readyDisabled,
			loading = busy == "SetTradeReady",
			shakeToken = shakeFor("SetTradeReady"),
			reducedMotion = softMotion,
			highlight = not youReadyLocal and not tableEmpty,
			selectable = not readyDisabled,
		}))
		local confirmSlot = React.createElement("frame", {
			Name = "TradeConfirm",
			Size = if vertical then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, not vertical and React.createElement("uiflexitem", {
			FlexMode = Enum.UIFlexMode.Fill,
		}), React.createElement(Button, {
			text = if session.YouConfirmed then "CONFIRMED" elseif confirmLeft > 0 then `CONFIRM  {clockLabel(session.ConfirmEndsAt, now)}` else "CONFIRM",
			onClick = onConfirmClick,
			color = Palette.mango,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = confirmDisabled,
			loading = busy == "ConfirmTrade",
			shakeToken = shakeFor("ConfirmTrade"),
			reducedMotion = reducedMotion,
			highlight = bothReady and not session.YouConfirmed,
			selectable = not confirmDisabled,
		}))
		local cancelSlot = React.createElement("frame", {
			Name = "TradeCancel",
			Size = if vertical then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}, not vertical and React.createElement("uiflexitem", {
			FlexMode = Enum.UIFlexMode.Fill,
		}), React.createElement(Button, {
			text = "CANCEL",
			onClick = onCancelClick,
			color = Palette.coral,
			textColor = Palette.coral,
			outline = true,
			size = UDim2.fromScale(1, 1),
			disabled = busy ~= "",
			loading = busy == "CancelTrade",
			shakeToken = shakeFor("CancelTrade"),
			reducedMotion = reducedMotion,
			selectable = busy == "",
		}))
		if vertical then
			return React.createElement("frame", {
				ref = sessionActionsHostRef,
				Name = "TradeSessionActions",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}), readySlot, confirmSlot, cancelSlot)
		end
		return React.createElement("frame", {
			ref = sessionActionsHostRef,
			Name = "TradeSessionActions",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}), readySlot, confirmSlot, cancelSlot)
	end
	local _newValue = table.create(#visibleRows)
	local _callback_1 = function(row, index)
		local active = row.UserId == selected
		local _condition_5 = outgoingLive
		if _condition_5 then
			local _result_11 = outgoing
			if _result_11 ~= nil then
				_result_11 = _result_11.ToUserId
			end
			_condition_5 = _result_11 == row.UserId
		end
		local waiting = _condition_5
		return React.createElement(Panel, {
			key = row.UserId,
			size = UDim2.new(1, 0, 0, rosterRowH),
			accent = if active then accent else Palette.line,
			background = if active then darken(accent, 0.82) else Palette.panel,
			padding = 10,
			interactive = true,
			reveal = if reducedMotion then deskReveal else boardReveal,
			reducedMotion = reducedMotion or tradeSoft,
			layoutOrder = 6 + index,
		}, React.createElement("textbutton", {
			Size = UDim2.new(1, if compactTrade then 0 else -118, 0, if compactTrade then 48 else 46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Selectable = false,
			Event = {
				Activated = function()
					Audio:play("tick")
					setSelected(row.UserId)
				end,
				MouseEnter = function()
					return Audio:play("hover")
				end,
			},
		}), React.createElement(AvatarMark, {
			userId = row.UserId,
			accent = if active then accent else Palette.cyan,
			size = 44,
		}), React.createElement(Text, {
			value = row.DisplayName,
			size = 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(56, 4),
			sizeConstraint = UDim2.new(1, if compactTrade then -56 else -176, 0, 22),
		}), React.createElement(Text, {
			value = `{row.Rebirths} rebirths · world {row.CurrentZone}`,
			size = 12,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(56, 28),
			sizeConstraint = UDim2.new(1, if compactTrade then -56 else -176, 0, 18),
		}), React.createElement(Button, {
			text = if waiting then "WAITING" else "INVITE",
			onClick = function()
				setSelected(row.UserId)
				if not waiting then
					run("InviteTrade", {
						UserId = row.UserId,
					})
				end
			end,
			color = if waiting then Palette.panelSoft else accent,
			textColor = if waiting then Palette.cream else Palette.ink,
			size = if compactTrade then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(110, 40),
			position = if compactTrade then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -110, 0.5, -20),
			disabled = busy ~= "" or waiting or not unlocked,
			loading = busy == "InviteTrade",
			shakeToken = shakeFor("InviteTrade"),
			reducedMotion = reducedMotion,
			highlight = not waiting,
		}))
	end
	for _k, _v in visibleRows do
		_newValue[_k] = _callback_1(_v, _k - 1, visibleRows)
	end
	local rosterCards = _newValue
	if session ~= nil then
		local pinnedActions = buildConfirmActions(if compactTrade then "vertical" else "horizontal")
		local stepRow = if phone then TapTarget + 10 else 48
		local lineRow = if phone then 64 else 58
		local function offerFloor(editor, lines)
			local header = 96
			if not editor then
				return header + math.max(#lines, 1) * lineRow + 24
			end
			return header + 40 + 6 * stepRow + 140 + math.min(#relics, 24) * stepRow
		end
		local youFloor = offerFloor(true, yourLines)
		local themFloor = offerFloor(false, theirLines)
		local offerContentFloor = if compactTrade then (if offerTab == "You" then youFloor else themFloor) else math.max(youFloor, themFloor)
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("frame", {
			Size = UDim2.new(1, 0, 1, -(actionH + 8)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement(PageScaffold, {
			scrollBarColor = accent,
			scrollBarThickness = 4,
			tailPad = scrollTail(true, chrome.bottomSafe, if chrome.landscape then 16 else 20),
			gap = if chrome.landscape then 8 else Layout.stackGap,
			sections = { {
				id = "status",
				height = (if chrome.landscape then 52 else 60) + (if #tradeWarnings > 0 then 40 else 0),
				element = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(Text, {
					value = if bothReady then "Both ready. Confirm to finish the trade." elseif youReadyLocal then `Waiting on {session.PartnerName}.` else "Add your offer, then select Ready.",
					size = 13,
					color = if bothReady then Palette.mango else Palette.creamSoft,
					wrap = true,
					sizeConstraint = UDim2.new(1, 0, 0, 32),
				}), React.createElement(Text, {
					value = if sessionLeft > 0 then `Table {clockLabel(session.ExpiresAt, now)}` else "Table expired",
					size = 11,
					color = if sessionLeft > 12 then Palette.mint else Palette.coral,
					weight = Enum.FontWeight.Bold,
					fit = true,
					position = UDim2.fromOffset(0, 34),
					sizeConstraint = UDim2.new(1, 0, 0, 18),
				}), #tradeWarnings > 0 and React.createElement(Text, {
					-- one-sided offers are allowed (gifts), but never by accident
					value = tradeWarnings[1],
					size = 13,
					color = Palette.coral,
					weight = Enum.FontWeight.Bold,
					wrap = true,
					position = UDim2.fromOffset(0, 56),
					sizeConstraint = UDim2.new(1, 0, 0, 36),
				}) or nil),
			}, {
				id = "meter",
				height = 54,
				element = React.createElement(TradeFairnessMeter, {
					draft = draft,
					them = session.Them,
				}),
			}, {
				id = "chat",
				height = if compactTrade then 200 else 230,
				element = React.createElement(TradeChatStream, {
					session = session,
					dispatch = dispatch,
				}),
			}, {
				id = "asks",
				height = tradeAsksHeight(session),
				element = React.createElement(TradeAsks, {
					session = session,
					dispatch = dispatch,
					myRelics = relics,
					onAddRequested = addRequested,
				}),
			}, {
				id = "tabs",
				height = TapTarget,
				element = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(SegmentedTabs, {
					options = { {
						id = "You",
						label = `YOUR OFFER{if youReadyLocal then " ✓" else ""}`,
					}, {
						id = "Them",
						label = `{string.upper(session.PartnerName)}{if session.ThemReady then " ✓" else ""}`,
					} },
					value = offerTab,
					onChange = setOfferTab,
					accent = accent,
					columns = 2,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
				})),
			}, {
				id = "offer",
				fill = true,
				minHeight = 120,
				height = offerContentFloor,
				element = if compactTrade then (
					if offerTab == "You" then offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true) else offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false, true)
				) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement("frame", {
					Size = UDim2.new(0.49, -4, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true)), React.createElement("frame", {
					Size = UDim2.new(0.49, -4, 0, 0),
					Position = UDim2.new(0.51, 4, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false, true))),
			} },
		})), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, actionH),
			Position = UDim2.new(0, 0, 1, -actionH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, pinnedActions))
	end
	do
		local _exp_4 = React.createElement(Text, {
			value = dailyLabel,
			size = 14,
			color = Palette.mint,
			weight = Enum.FontWeight.Bold,
			layoutOrder = 0,
			sizeConstraint = UDim2.new(1, 0, 0, 22),
			transparency = fade,
		})
		local _condition_5 = lockBanner and session == nil
		if _condition_5 then
			local _exp_5 = React.createElement(Text, {
				value = "Player trading is locked",
				size = 15,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 22),
			})
			local _attributes = {}
			local _result_11 = lock
			if _result_11 ~= nil then
				_result_11 = _result_11.Requirement
			end
			local _condition_6 = _result_11
			if _condition_6 == nil then
				_condition_6 = "Complete your first rebirth."
			end
			_attributes.value = _condition_6
			_attributes.size = 13
			_attributes.color = Palette.creamSoft
			_attributes.wrap = true
			_attributes.position = UDim2.fromOffset(0, 26)
			_attributes.sizeConstraint = UDim2.new(1, 0, 0, 48)
			_condition_5 = React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, 86),
				accent = Palette.muted,
				padding = if compactTrade then 12 else Layout.cardPadding,
				reducedMotion = reducedMotion,
				layoutOrder = 1,
			}, _exp_5, React.createElement(Text, _attributes))
		end
		local _exp_5 = inviteLive and session == nil and React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 128),
			accent = Palette.cyan,
			padding = if compactTrade then 12 else Layout.cardPadding,
			reducedMotion = reducedMotion,
			layoutOrder = 2,
		}, React.createElement(AvatarMark, {
			userId = invite.FromUserId,
			accent = Palette.cyan,
			size = 44,
		}), React.createElement(Text, {
			value = `{(invite and invite.FromName) or "Someone"} invited you`,
			size = 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(56, 2),
			sizeConstraint = UDim2.new(1, -64, 0, 22),
		}), React.createElement(Text, {
			value = `Accept to open a live table · {clockLabel(invite.ExpiresAt, now)} left`,
			size = 13,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(56, 26),
			sizeConstraint = UDim2.new(1, -64, 0, 20),
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, TapTarget),
			Position = UDim2.new(0, 0, 1, -TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, {
			text = "ACCEPT",
			onClick = function()
				return run("RespondTrade", {
					Accept = true,
				})
			end,
			color = Palette.mint,
			textColor = Palette.ink,
			size = UDim2.new(0.48, -4, 1, 0),
			disabled = busy ~= "",
			loading = busy == "RespondTrade",
			shakeToken = shakeFor("RespondTrade"),
			reducedMotion = reducedMotion,
			highlight = true,
		}), React.createElement(Button, {
			text = "DECLINE",
			onClick = function()
				return run("RespondTrade", {
					Accept = false,
				})
			end,
			color = Palette.coral,
			textColor = Palette.ink,
			size = UDim2.new(0.48, -4, 1, 0),
			position = UDim2.new(0.52, 4, 0, 0),
			disabled = busy ~= "",
			loading = busy == "RespondTrade",
			shakeToken = shakeFor("RespondTrade"),
			reducedMotion = reducedMotion,
		})))
		local _exp_6 = outgoingLive and session == nil and not inviteLive and React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 124),
			accent = Palette.mango,
			padding = if compactTrade then 12 else Layout.cardPadding,
			reducedMotion = reducedMotion,
			layoutOrder = 3,
		}, React.createElement(Icon, {
			kind = "Timer.4",
			color = Palette.mango,
			accent = Palette.mango,
			size = 22,
			position = UDim2.fromOffset(2, 6),
			clipSafe = true,
			spin = false,
		}), React.createElement(Text, {
			value = `Waiting on {(outgoing and outgoing.ToName) or "partner"}`,
			size = 15,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(32, 2),
			sizeConstraint = UDim2.new(1, -40, 0, 22),
		}), React.createElement(Text, {
			value = `Invite expires in {clockLabel(outgoing.ExpiresAt, now)}`,
			size = 13,
			color = Palette.mango,
			weight = Enum.FontWeight.Bold,
			fit = true,
			position = UDim2.fromOffset(32, 26),
			sizeConstraint = UDim2.new(1, -40, 0, 18),
		}), React.createElement(Button, {
			text = "CANCEL",
			onClick = function()
				return run("CancelTrade")
			end,
			color = Palette.coral,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -TapTarget),
			disabled = busy ~= "",
			loading = busy == "CancelTrade",
			shakeToken = shakeFor("CancelTrade"),
			reducedMotion = reducedMotion,
		}))
		local _exp_7 = session == nil and React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, searchH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 4,
		}, React.createElement(SearchField, {
			value = query,
			onChange = setQuery,
			accent = accent,
			placeholder = "Find a forgemaster",
			size = UDim2.new(1, -(searchH + 8), 0, searchH),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "",
			icon = "Refresh.2",
			onClick = function()
				return loadRoster()
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.fromOffset(searchH, searchH),
			position = UDim2.new(1, -searchH, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_8 = session == nil and #visibleRows == 0 and React.createElement(EmptyState, {
			icon = "Crew.4",
			title = if #rows == 0 then "Server is quiet" else "No match",
			body = if #rows == 0 then ((config.ClientPageGuides and config.ClientPageGuides.Trade and config.ClientPageGuides.Trade.EmptySession) or "Nobody else is in this server. Invites only work here.") else "Try a different name.",
			accent = accent,
			compact = true,
			layoutOrder = 5,
			reducedMotion = reducedMotion,
		})
		local _exp_9 = session == nil and rosterCards
		local _condition_6 = session == nil
		if _condition_6 then
			local _attributes = {
				text = if selectedRow ~= nil then `INVITE  {string.upper(selectedRow.DisplayName)}` else "CHOOSE SOMEONE",
				icon = "Send.2",
				onClick = function()
					if selected ~= 0 then
						run("InviteTrade", {
							UserId = selected,
						})
					end
				end,
				color = accent,
				textColor = Palette.ink,
				size = UDim2.new(1, 0, 0, TapTarget),
			}
			local _condition_7 = selected == 0 or busy ~= ""
			if not _condition_7 then
				local _condition_8 = outgoingLive
				if _condition_8 then
					local _result_11 = outgoing
					if _result_11 ~= nil then
						_result_11 = _result_11.ToUserId
					end
					_condition_8 = _result_11 == selected
				end
				_condition_7 = _condition_8
				if not _condition_7 then
					_condition_7 = not unlocked
				end
			end
			_attributes.disabled = _condition_7
			_attributes.reducedMotion = reducedMotion
			_attributes.highlight = true
			_condition_6 = React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, TapTarget),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 7,
			}, React.createElement(Button, _attributes))
		end
		local rosterStride = rosterRowH + (if chrome.landscape then 8 else Layout.stackGap)
		local rosterFloor = if #visibleRows == 0 then 140 else #visibleRows * rosterStride
		local sections = {
			{
				id = "daily",
				height = 22,
				element = _exp_4,
			},
		}
		if _condition_5 then
			table.insert(sections, {
				id = "lock",
				height = 86,
				element = _condition_5,
			})
		end
		if _exp_5 then
			table.insert(sections, {
				id = "invite",
				height = 128,
				element = _exp_5,
			})
		end
		if _exp_6 then
			table.insert(sections, {
				id = "outgoing",
				height = 124,
				element = _exp_6,
			})
		end
		if _exp_7 then
			table.insert(sections, {
				id = "search",
				height = searchH,
				element = _exp_7,
			})
		end
		local rosterElement = if _exp_8 then _exp_8 elseif #visibleRows >= 8 then React.createElement(FlatList, {
			data = visibleRows,
			itemHeight = rosterStride,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 8,
			Size = UDim2.fromScale(1, 1),
			scrollBarColor = accent,
			scrollBarThickness = 4,
			keyExtractor = function(row)
				return row.UserId
			end,
			renderItem = function(_param_1)
				local index = _param_1.index
				return rosterCards[index + 1]
			end,
		}) else React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if chrome.landscape then 8 else Layout.stackGap),
		}), rosterCards)
		table.insert(sections, {
			id = "roster",
			fill = #visibleRows >= 4,
			minHeight = rosterFloor,
			height = rosterFloor,
			element = rosterElement,
		})
		if _condition_6 then
			table.insert(sections, {
				id = "invite-cta",
				height = TapTarget,
				element = _condition_6,
			})
		end
		-- completed trades, newest first: who, when, what changed hands
		local history = if trade and type(trade.History) == "table" then trade.History else {}
		table.insert(sections, {
			id = "history-heading",
			height = 30,
			element = React.createElement(Text, {
				value = if #history > 0 then "Recent trades" else "Recent trades: none yet. Finished trades show up here.",
				size = 15, color = Palette.cream, weight = Enum.FontWeight.Heavy, wrap = true,
				sizeConstraint = UDim2.new(1, 0, 0, 28),
			}),
		})
		for index, entry in history do
			local ago = math.max(0, os.time() - entry.At)
			local when = if ago < 3600 then `{math.max(1, math.floor(ago / 60))}m ago` elseif ago < 86400 then `{math.floor(ago / 3600)}h ago` else `{math.floor(ago / 86400)}d ago`
			table.insert(sections, {
				id = "history-" .. index,
				height = if phone then 104 else 84,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1), accent = accent, background = Palette.panel, padding = 12, clips = false,
				}, React.createElement(Text, {
					value = `With {entry.Partner}  ·  {when}`, size = 14, color = Palette.cream, weight = Enum.FontWeight.Bold,
					sizeConstraint = UDim2.new(1, -150, 0, 20),
				}), React.createElement(Text, {
					value = `You gave {entry.Gave}.\nYou got {entry.Got}.`, size = 13, color = Palette.muted, wrap = true,
					position = UDim2.fromOffset(0, 24), sizeConstraint = UDim2.new(1, -150, 0, if phone then 56 else 40),
				}), game:GetService("Players"):GetPlayerByUserId(entry.PartnerId) ~= nil and React.createElement(Button, {
					-- the same partner is still here: one tap opens a fresh trade with them
					text = "Trade again", icon = "Send.3", color = accent, textColor = Palette.ink,
					size = UDim2.fromOffset(140, TapTarget), position = UDim2.new(1, -140, 0, 4), reducedMotion = reducedMotion,
					onClick = function() dispatch("InviteTrade", { UserId = entry.PartnerId }) end,
				}) or nil),
			})
		end
		return React.createElement(PageScaffold, {
			scrollBarColor = accent,
			scrollBarThickness = 4,
			tailPad = scrollTail(true, chrome.bottomSafe, if chrome.landscape then 24 else 32),
			gap = if chrome.landscape then 8 else Layout.stackGap,
			sections = sections,
		})
	end
end
return {
	TradeView = TradeView,
}
end

__defs["CrewView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local PlayerMark = require(script.Parent.Parent.ArtKit)("Icon").PlayerMark
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local NumberSpinnerHost = require(script.Parent.Parent.ReactHosts)("NumberSpinnerHost").NumberSpinnerHost
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local AppHelpers = require(script.Parent.Parent.CoreKit)("appNav").AppHelpers
local PageReadyMath = require(script.Parent.Parent.LayoutKit)("pageReadyMath")
local PageBoardHeights = require(script.Parent.Parent.CoreKit)("pageBoardHeights")
local Browse = require(script.Parent.Parent.BrowseKit)

local function CrewRow(_param)
	local player = _param.player
	local visiting = _param.visiting
	local visitorsHere = _param.visitorsHere
	local onVisit = _param.onVisit
	local onNudge = _param.onNudge
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(math.min(layoutOrder, 8), softMotion)
	local accent = if player.IsLocal then Palette.green else Palette.blue
	local rowH = if stack then (if player.IsLocal then 118 else 158) else 100
	local pad = if stack then 14 else 12
	local _exp = React.createElement("frame", {
		Size = UDim2.fromOffset(if stack then 48 else 44, if stack then 48 else 44),
		Position = UDim2.fromOffset(0, if stack then 8 else 14),
		BackgroundColor3 = darken(accent, 0.62),
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.12), darken(accent, 0.48)),
		Rotation = 120,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = 0.32,
	}), React.createElement(PlayerMark, {
		userId = player.UserId,
		color = Palette.ink,
		accent = accent,
		size = if stack then 42 else 38,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))
	local _exp_1 = React.createElement(Text, {
		value = if player.IsLocal then "YOU" else player.DisplayName,
		size = if stack then 17 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(58, 2),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -280, 0, 22),
	})
	local _exp_2 = React.createElement(Text, {
		value = `World {player.CurrentZone}`,
		size = if stack then 12 else 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(58, 28),
		sizeConstraint = UDim2.fromOffset(80, 16),
	})
	local _exp_3 = React.createElement(Text, {
		value = `{compactNumber(player.Production)} /s`,
		size = if stack then 12 else 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(144, 28),
		sizeConstraint = UDim2.new(1, -160, 0, 16),
	})
	local _condition = not player.IsLocal
	if _condition then
		local _attributes = {}
		local _condition_1 = player.CurrentPage
		if _condition_1 == nil then
			_condition_1 = "Overview"
		end
		_attributes.value = `Browsing {AppHelpers:pageEntry(_condition_1).label}`
		_attributes.size = if stack then 11 else 9
		_attributes.color = if player.PresenceAge ~= nil and player.PresenceAge >= 0 and player.PresenceAge < 12 then Palette.mint else Palette.muted
		_attributes.weight = Enum.FontWeight.Bold
		_attributes.fit = true
		_attributes.minSize = 8
		_attributes.position = UDim2.fromOffset(58, if stack then 52 else 56)
		_attributes.sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -16, 0, 16)
		_condition = React.createElement(Text, _attributes)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, rowH),
		accent = accent,
		background = if visiting then Palette.panelRaised else Palette.panel,
		padding = pad,
		layoutOrder = layoutOrder,
		reveal = reveal,
		interactive = not player.IsLocal,
		highlight = visiting,
		reducedMotion = softMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _condition, if player.IsLocal then React.createElement(Text, {
		value = if visitorsHere > 0 then `{visitorsHere} visiting your shop` else `{player.Rebirths} resets`,
		size = if stack then 12 else 10,
		color = if visitorsHere > 0 then Palette.mango else accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(58, if stack then 52 else 56),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -16, 0, 18),
	}) elseif stack then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -(TapTarget + 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "WAVE",
		icon = "Wave.5",
		onClick = onNudge,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	})), React.createElement("frame", {
		Name = "CrewVisitConfirm",
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = if visiting then "HERE" else "VISIT",
		icon = "Visit.2",
		onClick = onVisit,
		color = if visiting then Palette.green else Palette.blue,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = visiting,
		highlight = visiting,
	}))) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "WAVE",
		icon = "Wave.6",
		onClick = onNudge,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = softMotion,
	}), React.createElement("frame", {
		Name = "CrewVisitConfirm",
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		LayoutOrder = 2,
	}, React.createElement(Button, {
		text = if visiting then "HERE" else "VISIT",
		icon = "Visit.3",
		onClick = onVisit,
		color = if visiting then Palette.green else Palette.blue,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = softMotion,
		disabled = visiting,
		highlight = visiting,
	}))))
end
local function VisitPanel(_param)
	local visit = _param.visit
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(0, softMotion)
	local vaultFill = meterFill(asFlux(visit.Vault), asFlux(visit.Capacity))
	local machineBits = {}
	for id, level in pairs(visit.Machines) do
		if #machineBits < 4 then
			local _arg0 = `{id} {level}`
			table.insert(machineBits, _arg0)
		end
	end
	local lineWord = if visit.MachineKinds == 1 then "line" else "lines"
	local machineLine = if #machineBits > 0 then `{visit.MachineKinds} {lineWord} · {machineBits[1]}{if machineBits[2] ~= nil then `  ·  {machineBits[2]}` else ""}{if machineBits[3] ~= nil then `  ·  {machineBits[3]}` else ""}` else "No machines built yet"
	local _exp = React.createElement(Text, {
		value = "VISITING",
		size = 10,
		color = Palette.blue,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 16),
	})
	local _exp_1 = React.createElement(Text, {
		value = visit.DisplayName,
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 30),
	})
	local _exp_2 = React.createElement(Text, {
		value = `World {visit.CurrentZone}  ·  {visit.Rebirths} resets  ·  live`,
		size = 11,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 18),
	})
	local _exp_3 = React.createElement(Button, {
		text = "LEAVE",
		icon = "Close.3",
		onClick = function()
			return dispatch("LeavePlot")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(120, 40),
		position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -120, 0, 12),
		reducedMotion = softMotion,
	})
	local _exp_4 = { {
		label = "FLUX / SEC",
		value = visit.Production,
		color = Palette.green,
	}, {
		label = "BALANCE",
		value = visit.Cash,
		color = Palette.cream,
	}, {
		label = "CORES",
		value = visit.Cores,
		color = Palette.violet,
	}, {
		label = "STARDUST",
		value = visit.Stardust,
		color = Palette.cyan,
	} }
	local _newValue = table.create(#_exp_4)
	local _callback = function(stat, index)
		return React.createElement("frame", {
			key = stat.label,
			Size = if stack then UDim2.new(0.5, -4, 0, 72) else UDim2.new(0.25, -6, 1, 0),
			Position = if stack then UDim2.new(if index % 2 == 0 then 0 else 0.5, if index % 2 == 0 then 0 else 4, 0, if index < 2 then 0 else 80) else UDim2.new(index * 0.25, if index == 0 then 0 else 2, 0, 0),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement(Text, {
			value = stat.label,
			size = 9,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 10),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}), React.createElement(NumberSpinnerHost, {
			value = asFlux(stat.value),
			reducedMotion = softMotion,
			duration = 0.4,
			size = 16,
			color = stat.color,
			position = UDim2.fromOffset(10, 32),
			sizeConstraint = UDim2.new(1, -20, 0, 24),
		}))
	end
	for _k, _v in _exp_4 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_4)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, PageBoardHeights.Visit(stack)),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = 16,
		layoutOrder = layoutOrder,
		reveal = reveal,
		highlight = true,
		reducedMotion = softMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 152 else 72),
		Position = UDim2.fromOffset(0, if stack then 76 else 86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue), React.createElement(Text, {
		value = `Vault {compactNumber(visit.Vault)} / {compactNumber(visit.Capacity)}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 238 else 170),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = vaultFill,
		color = Palette.blue,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(0, if stack then 258 else 192),
		size = UDim2.new(1, 0, 0, 7),
	}), React.createElement(Text, {
		value = machineLine,
		size = 10,
		color = Palette.creamSoft,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 274 else 210),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}))
end
local function sameCrewSnapshot(left, right)
	return PageReadyMath.SameCrewSnapshot(left, right)
end
local CrewStore = require(script.Parent.Parent.CrewStore)
local CrewMath = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("CrewMath"))

-- The party block above the server roster: invite card, crew summary, members, goal and actions.
local function crewPartySections(args)
	local crewState, players, dispatch, stack, softMotion = args.crewState, args.players, args.dispatch, args.stack, args.softMotion
	local renameDraft, setRenameDraft, note, setNote = args.renameDraft, args.setRenameDraft, args.note, args.setNote
	local localId = Players.LocalPlayer.UserId
	local crew, invite = crewState.crew, crewState.invite
	local sections = {}
	local function run(action, payload)
		dispatch(action, payload or {}, function(response)
			if type(response) ~= "table" then return end
			if action == "GetCrew" or response.Crew ~= nil or response.Invite ~= nil then
				CrewStore.set({ crew = response.Crew or CrewStore.NONE })
			end
			setNote(if response.ok == false then (response.error or "That didn't work.") else (response.message or ""))
		end)
	end
	local function text(value, size, color, height, weight)
		return React.createElement(Text, { value = value, size = size, color = color, wrap = true, weight = weight,
			sizeConstraint = UDim2.new(1, 0, 0, height) })
	end
	-- leaving or removing someone takes a second tap, so a stray click can't break up a crew
	local confirmKey, setConfirmKey = args.confirmKey, args.setConfirmKey
	local function confirmed(key, action, payload)
		if confirmKey == key then
			setConfirmKey(nil)
			run(action, payload)
		else
			setConfirmKey(key)
		end
	end
	local GAP = 10
	if invite and (invite.ExpiresAt or 0) > os.time() then
		table.insert(sections, { id = "crew-invite", height = if stack then 46 + TapTarget * 2 + GAP + 28 else 104, element = React.createElement(Panel, {
			size = UDim2.fromScale(1, 1), accent = Palette.mango, background = Palette.panelRaised, padding = 14, clips = false,
		}, text(`{invite.FromName} invited you to {invite.CrewName}.`, 17, Palette.cream, 44, Enum.FontWeight.Heavy),
			React.createElement(Button, { text = "Join crew", icon = "Crew.5", color = Palette.mango, textColor = Palette.ink,
				size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(160, TapTarget),
				position = if stack then UDim2.fromOffset(0, 46) else UDim2.new(1, -330 - GAP, 0, 34), reducedMotion = softMotion,
				onClick = function() CrewStore.set({ invite = CrewStore.NONE }); run("CrewRespond", { Accept = true }) end }),
			React.createElement(Button, { text = "Decline", color = Palette.panelSoft, textColor = Palette.cream, outline = true,
				size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(160, TapTarget),
				position = if stack then UDim2.fromOffset(0, 46 + TapTarget + GAP) else UDim2.new(1, -160, 0, 34), reducedMotion = softMotion,
				onClick = function() CrewStore.set({ invite = CrewStore.NONE }); run("CrewRespond", { Accept = false }) end })) })
	end
	local leader = crew ~= nil and crew.Leader == localId
	if crew then
		local bonus = math.floor((crew.Bonus or 0) * 100 + 0.5)
		table.insert(sections, { id = "crew-summary", height = 96, element = React.createElement(Panel, {
			size = UDim2.fromScale(1, 1), accent = Palette.green, background = Palette.panelRaised, padding = 14, clips = false,
		}, text(crew.Name, 22, Palette.cream, 30, Enum.FontWeight.Heavy),
			React.createElement(Text, { value = `{#crew.Members} of {crew.Max} members · +{bonus}% production while you play together · crew chat is in Chat`,
				size = 14, color = Palette.muted, wrap = true, position = UDim2.fromOffset(0, 34), sizeConstraint = UDim2.new(1, 0, 0, 40) })) })
		for index, member in crew.Members do
			table.insert(sections, { id = "crew-member-" .. member.UserId, height = 56, element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.panel, BorderSizePixel = 0,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement(Text, { value = member.DisplayName .. (if member.Leader then "  ·  leader" else "") .. (if member.UserId == localId then "  ·  you" else ""),
					size = 16, color = Palette.cream, weight = Enum.FontWeight.Bold, position = UDim2.fromOffset(14, 6), sizeConstraint = UDim2.new(1, -140, 0, 22) }),
				React.createElement(Text, { value = `{member.Collects} collect{if member.Collects == 1 then "" else "s"} today`,
					size = 13, color = Palette.muted, position = UDim2.fromOffset(14, 30), sizeConstraint = UDim2.new(1, -140, 0, 18) }),
				member.UserId ~= localId and React.createElement(Button, { text = "Visit", icon = "Visit.4", color = Palette.blue, textColor = Palette.ink,
					size = UDim2.fromOffset(104, 44), position = UDim2.new(1, if leader then -236 else -110, 0.5, -22), reducedMotion = softMotion,
					onClick = function() dispatch("VisitPlot", { UserId = member.UserId }) end }) or nil,
				leader and member.UserId ~= localId and React.createElement(Button, {
					text = if confirmKey == "kick-" .. member.UserId then "Sure?" else "Remove",
					color = if confirmKey == "kick-" .. member.UserId then Palette.coral else Palette.panelSoft,
					textColor = if confirmKey == "kick-" .. member.UserId then Palette.ink else Palette.cream,
					outline = confirmKey ~= "kick-" .. member.UserId, size = UDim2.fromOffset(112, 44), position = UDim2.new(1, -118, 0.5, -22), reducedMotion = softMotion,
					onClick = function() confirmed("kick-" .. member.UserId, "CrewKick", { UserId = member.UserId }) end }) or nil) })
		end
		-- the daily goal: one meter to the next tier, then a claim button per tier
		local nextTier = nil
		for index, tier in crew.Tiers do
			if crew.Pooled < tier.Target then nextTier = tier; break end
		end
		local mine = 0
		for _, member in crew.Members do
			if member.UserId == localId then mine = member.Collects end
		end
		local goalChildren = {
			text(if nextTier then `Crew goal: {crew.Pooled} / {nextTier.Target} vault collects today` else `Every crew goal is done today ({crew.Pooled} collects).`,
				16, Palette.cream, 22, Enum.FontWeight.Bold),
			React.createElement(Meter, { value = if nextTier then math.clamp(crew.Pooled / nextTier.Target, 0, 1) else 1, color = Palette.green,
				reducedMotion = softMotion, position = UDim2.fromOffset(0, 28), size = UDim2.new(1, 0, 0, 8) }),
			React.createElement(Text, { value = if mine < crew.MinContribution then `Collect your vault {crew.MinContribution - mine} more time{if crew.MinContribution - mine == 1 then "" else "s"} to share the rewards.` else "You've pitched in enough to share every reward.",
				size = 13, color = Palette.muted, wrap = true, position = UDim2.fromOffset(0, 42), sizeConstraint = UDim2.new(1, 0, 0, 18) }),
		}
		local columns = if stack then 1 else 3
		local cellW = 1 / columns
		for index, tier in crew.Tiers do
			local ready = crew.Pooled >= tier.Target and not tier.Claimed and mine >= crew.MinContribution
			local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
			table.insert(goalChildren, React.createElement(Button, {
				text = if tier.Claimed then `Claimed · {tier.Stardust} dust` elseif crew.Pooled >= tier.Target then `Claim {tier.Stardust} dust` else `{tier.Target} collects · {tier.Stardust} dust`,
				color = if ready then Palette.green else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted,
				disabled = not ready, highlight = ready, reducedMotion = softMotion,
				size = UDim2.new(cellW, -GAP, 0, TapTarget), position = UDim2.new(col * cellW, 0, 0, 68 + row * (TapTarget + GAP)),
				onClick = function() run("CrewClaim", { Tier = index }) end,
			}))
		end
		local goalRows = math.ceil(#crew.Tiers / columns)
		table.insert(sections, { id = "crew-goal", height = 68 + goalRows * (TapTarget + GAP) + 28, element = React.createElement(Panel, {
			size = UDim2.fromScale(1, 1), accent = Palette.green, background = Palette.panelRaised, padding = 14, clips = false,
		}, table.unpack(goalChildren)) })
		local actions = {
			React.createElement(Button, {
				text = if confirmKey == "leave" then "Tap again to leave" else "Leave crew",
				color = if confirmKey == "leave" then Palette.coral else Palette.panelSoft,
				textColor = if confirmKey == "leave" then Palette.ink else Palette.cream, outline = confirmKey ~= "leave",
				size = UDim2.new(if leader and not stack then 0.3 else 1, -GAP / 2, 0, TapTarget), position = if leader and not stack then UDim2.new(0.7, GAP / 2, 0, 0) elseif leader then UDim2.fromOffset(0, TapTarget + GAP) else UDim2.new(),
				reducedMotion = softMotion, onClick = function() confirmed("leave", "CrewLeave") end }),
		}
		if leader then
			table.insert(actions, React.createElement("textbox", {
				Size = UDim2.new(if stack then 1 else 0.45, -GAP / 2, 0, TapTarget), BackgroundColor3 = Palette.panel, BorderSizePixel = 0,
				Text = renameDraft, PlaceholderText = "New crew name", PlaceholderColor3 = Palette.muted, TextColor3 = Palette.cream,
				TextSize = 16, ClearTextOnFocus = false, FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				Change = { Text = function(box) setRenameDraft(string.sub(box.Text, 1, 40)) end },
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement("uipadding", { PaddingLeft = UDim.new(0, 10) })))
			if not stack then
				table.insert(actions, React.createElement(Button, { text = "Rename", color = Palette.green, textColor = Palette.ink,
					size = UDim2.new(0.25, -GAP, 0, TapTarget), position = UDim2.new(0.45, GAP / 2, 0, 0), reducedMotion = softMotion,
					disabled = CrewMath.cleanName(renameDraft) == nil, onClick = function() run("CrewRename", { Name = renameDraft }); setRenameDraft("") end }))
			end
		end
		table.insert(sections, { id = "crew-actions", height = if leader and stack then TapTarget * 2 + GAP else TapTarget,
			element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, table.unpack(actions)) })
	end
	-- recruiting: anyone here who isn't already in your crew
	local canInvite = crew == nil or (leader and #crew.Members < crew.Max)
	if canInvite then
		local candidates = {}
		local members = {}
		if crew then for _, member in crew.Members do members[member.UserId] = true end end
		for _, player in players do
			if not player.IsLocal and not members[player.UserId] then table.insert(candidates, player) end
		end
		local intro = if crew then "Invite more players to your crew." else
			`Start a crew with up to {CrewMath.MAX_MEMBERS - 1} other players here. Each crewmate adds {math.floor(CrewMath.BONUS_PER_MEMBER * 100)}% production, and you share a daily goal.`
		local columns = if stack then 1 else 2
		local rows = math.ceil(math.min(#candidates, 8) / columns)
		local children = { text(if #candidates == 0 then intro .. " Nobody else is free right now." else intro, 15, Palette.creamSoft, 40) }
		for index = 1, math.min(#candidates, 8) do
			local player = candidates[index]
			local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
			table.insert(children, React.createElement(Button, { text = `Invite {player.DisplayName}`, icon = "Crew.6",
				color = Palette.blue, textColor = Palette.ink, reducedMotion = softMotion,
				size = UDim2.new(1 / columns, -GAP, 0, TapTarget), position = UDim2.new(col / columns, 0, 0, 46 + row * (TapTarget + GAP)),
				onClick = function() run("CrewInvite", { UserId = player.UserId }) end }))
		end
		table.insert(sections, { id = "crew-recruit", height = 46 + rows * (TapTarget + GAP) + 26, element = React.createElement(Panel, {
			size = UDim2.fromScale(1, 1), accent = Palette.blue, background = Palette.panelRaised, padding = 14, clips = false,
		}, table.unpack(children)) })
	end
	if note ~= "" then
		table.insert(sections, { id = "crew-note", height = 40, element = text(note, 14, Palette.mango, 36) })
	end
	return sections
end

local function CrewView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local visit = _param.visit
	local setVisit = _param.setVisit
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion
	local players, setPlayers = React.useState({})
	local mountedRef = React.useRef(true)
	local visitAttemptRef = React.useRef(0)
	local crewHostRef = React.useRef(nil)
	local crewState = CrewStore.useCrew()
	local renameDraft, setRenameDraft = React.useState("")
	local crewNote, setCrewNote = React.useState("")
	local confirmKey, setConfirmKey = React.useState(nil)
	-- an unanswered "tap again" quietly resets
	React.useEffect(function()
		if confirmKey == nil then
			return nil
		end
		local reset = task.delay(4, function()
			setConfirmKey(nil)
		end)
		return function()
			pcall(task.cancel, reset)
		end
	end, { confirmKey })
	React.useEffect(function()
		return function()
			mountedRef.current = false
			visitAttemptRef.current += 1
		end
	end, {})
	-- the crew page asks once on open; afterwards CrewState effects keep the store current
	React.useEffect(function()
		dispatch("GetCrew", {}, function(response)
			if type(response) == "table" and response.ok then
				CrewStore.set({ crew = response.Crew or CrewStore.NONE, invite = response.Invite or CrewStore.NONE })
			end
		end)
	end, {})
	local refresh = React.useCallback(function()
		return dispatch("GetPlayers", {}, function(response)
			if not mountedRef.current or not response.ok then
				return nil
			end
			local raw = response.Players or {}
			local cleaned = {}
			for _, entry in raw do
				local _userId = entry.UserId
				local id = if type(_userId) == "number" then math.floor(entry.UserId) else tonumber(tostring(entry.UserId))
				if id == nil or id ~= id or id == 0 then
					continue
				end
				local _object = table.clone(entry)
				setmetatable(_object, nil)
				_object.UserId = id
				table.insert(cleaned, _object)
			end
			setPlayers(function(current)
				return if sameCrewSnapshot(current, cleaned) then current else cleaned
			end)
		end)
	end, { dispatch })
	React.useEffect(function()
		refresh()
	end, { refresh })
	React.useEffect(function()
		local joined = Players.PlayerAdded:Connect(refresh)
		local left = Players.PlayerRemoving:Connect(refresh)
		return function()
			joined:Disconnect()
			left:Disconnect()
		end
	end, { refresh })
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(4)
				if not alive then
					break
				end
				refresh()
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { refresh })
	local crewFocusReady = #players > 0
	React.useEffect(function()
		if not crewFocusReady or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = crewHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { crewFocusReady, #players })
	local _visitUserId = visit
	if _visitUserId ~= nil then
		_visitUserId = _visitUserId.UserId
	end
	local visitUserId = _visitUserId
	local coerceCrewId = function(raw)
		local _raw = raw
		local _result
		if type(_raw) == "number" then
			_result = raw
		else
			local _raw_1 = raw
			_result = if type(_raw_1) == "string" then tonumber(raw) else nil
		end
		local asNumber = _result
		if asNumber == nil or asNumber ~= asNumber then
			return nil
		end
		local id = math.floor(asNumber + (if asNumber >= 0 then 1e-9 else -1e-9))
		if id == 0 then
			return nil
		end
		return id
	end
	local startVisit = function(userId)
		local id = coerceCrewId(userId)
		if id == nil then
			return nil
		end
		local attempt = visitAttemptRef.current + 1
		visitAttemptRef.current = attempt
		dispatch("VisitPlot", {
			UserId = id,
			userId = id,
		}, function(response)
			if not mountedRef.current or visitAttemptRef.current ~= attempt then
				return nil
			end
			if not response.ok then
				return nil
			end
			if response.Visit then
				setVisit(response.Visit)
			else
				local _result = response.State
				if _result ~= nil then
					_result = _result.Visit
				end
				if _result then
					setVisit(response.State.Visit)
				end
			end
		end)
	end
	local nudgeCrew = function(userId)
		local id = coerceCrewId(userId)
		if id == nil then
			return nil
		end
		dispatch("NudgeCrew", {
			UserId = id,
			userId = id,
		})
	end
	local headerReveal = useStagger(0, softMotion)
	local crewBrowse = Browse.useBrowse({
		id = "Crew",
		items = players,
		text = function(player)
			return { player.DisplayName, player.CurrentPage, `world {player.CurrentZone or ""}` }
		end,
		categories = {
			{ id = "All", label = "Everyone" },
			{ id = "SameWorld", label = "Same world", test = function(player)
				return not player.IsLocal and player.CurrentZone ~= nil and player.CurrentZone == state.CurrentZone
			end },
			{ id = "Others", label = "Not me", test = function(player)
				return not player.IsLocal
			end },
		},
		sorts = {
			{ id = "Joined", label = "Server order" },
			{ id = "Production", label = "Top production", compare = function(a, b)
				return (asFlux(a.Production) or 0) > (asFlux(b.Production) or 0)
			end },
			{ id = "Rebirths", label = "Most rebirths", compare = function(a, b)
				return (tonumber(a.Rebirths) or 0) > (tonumber(b.Rebirths) or 0)
			end },
			{ id = "Name", label = "A to Z", compare = function(a, b)
				return string.lower(tostring(a.DisplayName)) < string.lower(tostring(b.DisplayName))
			end },
		},
	})
	local showCrewBar = #players >= 3
	local crewBarH = if showCrewBar then Browse.barHeight(stack, true) + 10 else 0
	local allPlayers = players
	players = crewBrowse.results
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	local rowStride = if stack then 176 else 124
	local headerH = (if stack then 182 else 112) + crewBarH -- phone: title, two-line blurb, then a full-width Refresh
	local listGap = if visit ~= nil then math.max(chrome.panelGap, 18) else math.max(chrome.panelGap, 12)
	local visitBlock = if visit ~= nil then PageBoardHeights.Visit(stack) else 0
	local crewTail = scrollTail(stack, chrome.bottomSafe, 48)
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = chrome.cardPadding,
		layoutOrder = 0,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(Text, {
		value = "CREW ROSTER",
		size = 10,
		color = Palette.blue,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -160, 0, 18),
	}), React.createElement(Text, {
		value = "Crew on this server",
		size = if stack then 20 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then -8 else -190, 0, 30),
	}), React.createElement(Text, {
		value = if visitorsHere > 0 then `{visitorsHere} visiting your forge. Pick someone below to visit or send a wave.` else "Form a crew with players here for a production bonus and a shared daily goal, or visit someone's forge.",
		size = chrome.labelText,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, if stack then -8 else -190, 0, 38),
	}), React.createElement(Button, {
		text = if stack then "REFRESH" else "REFRESH CREW",
		icon = "Refresh.3",
		onClick = refresh,
		sound = "tick",
		color = Palette.blue,
		textColor = Palette.ink,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(170, 44),
		position = if stack then UDim2.new(0, 0, 1, -(TapTarget + crewBarH)) else UDim2.new(1, -170, 0, 24),
		reducedMotion = softMotion,
	}), showCrewBar and React.createElement(Browse.BrowseBar, {
		browse = crewBrowse,
		placeholder = "Search crew by name or activity",
		accent = Palette.blue,
		stack = stack,
		reducedMotion = softMotion,
		position = UDim2.new(0, 0, 1, -(crewBarH - 10)),
		zIndex = 30,
	}))
	local visitPanel = visit ~= nil and React.createElement(VisitPanel, {
		visit = visit,
		dispatch = dispatch,
		reducedMotion = softMotion,
		layoutOrder = 1,
		stack = stack,
	})
	local emptyPanel = if #allPlayers == 0 then React.createElement(EmptyState, {
		icon = "Crew.7",
		title = "No one else is on shift",
		body = "Crew shows up here once someone else is online with you.",
		accent = Palette.blue,
		layoutOrder = 2,
	}) elseif #players == 0 then React.createElement(Browse.NoResults, {
		browse = crewBrowse,
		noun = "crew",
		icon = "Crew.8",
		accent = Palette.blue,
		reducedMotion = softMotion,
		size = UDim2.fromScale(1, 1),
		layoutOrder = 2,
	}) else nil
	local sections = {
		{
			id = "header",
			height = headerH,
			element = headerPanel,
		},
	}
	for _, section in crewPartySections({
		crewState = crewState, players = allPlayers, dispatch = dispatch, stack = stack, softMotion = softMotion,
		renameDraft = renameDraft, setRenameDraft = setRenameDraft, note = crewNote, setNote = setCrewNote,
		confirmKey = confirmKey, setConfirmKey = setConfirmKey,
	}) do
		table.insert(sections, section)
	end
	if visitPanel then
		table.insert(sections, {
			id = "visit",
			height = PageBoardHeights.Visit(stack),
			element = visitPanel,
		})
	end
	if emptyPanel then
		table.insert(sections, {
			id = "empty",
			height = 180,
			element = emptyPanel,
		})
	end
	local virtRoster = #players >= 8
	if virtRoster then
		local rosterCards = table.create(#players)
		for index, player in players do
			rosterCards[index] = React.createElement(CrewRow, {
				key = player.UserId,
				player = player,
				visiting = visitUserId == player.UserId,
				visitorsHere = if player.IsLocal then visitorsHere else 0,
				onVisit = function()
					return startVisit(player.UserId)
				end,
				onNudge = function()
					return nudgeCrew(player.UserId)
				end,
				reducedMotion = reducedMotion,
				layoutOrder = index,
				stack = stack,
			})
		end
		table.insert(sections, {
			id = "roster",
			fill = true,
			minHeight = 120,
			element = React.createElement(FlatList, {
				data = players,
				itemHeight = rowStride,
				overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
				canvasTail = 8,
				Size = UDim2.fromScale(1, 1),
				scrollBarColor = Palette.blue,
				scrollBarThickness = 4,
				keyExtractor = function(player)
					return player.UserId
				end,
				renderItem = function(_param_1)
					local index = _param_1.index
					return rosterCards[index + 1]
				end,
			}),
		})
	else
		for index, player in players do
			table.insert(sections, {
				id = "crew-" .. tostring(index),
				height = rowStride,
				element = React.createElement(CrewRow, {
					key = player.UserId,
					player = player,
					visiting = visitUserId == player.UserId,
					visitorsHere = if player.IsLocal then visitorsHere else 0,
					onVisit = function()
						return startVisit(player.UserId)
					end,
					onNudge = function()
						return nudgeCrew(player.UserId)
					end,
					reducedMotion = reducedMotion,
					layoutOrder = index + 3,
					stack = stack,
				}),
			})
		end
	end
	return React.createElement("frame", {
		ref = crewHostRef,
		Name = "CrewVisitClaim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		gap = listGap,
		tailPad = crewTail,
		scrollBarColor = Palette.blue,
		scrollBarThickness = 4,
		sections = sections,
	}))
end

return {
	CrewView = CrewView,
}
end

__defs["GuildView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local PlayerMark = require(script.Parent.Parent.ArtKit)("Icon").PlayerMark
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local gteFlux = _format.gteFlux
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local Social = require(game.ReplicatedStorage.AstralForge.Shared.SocialProgression)(require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath))
local createRequest = require(script.Parent.Parent.ActionRequest)
local SearchField = _ui.SearchField
local Browse = require(script.Parent.Parent.BrowseKit)
local ChatText = require(script.Parent.Parent.CoreKit)("chatText")
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
			local tier = tiers[index + 1]
			local effect = if type(tier) == "table" then tier.Effect else nil
			total += if type(effect) == "number" then effect else 0
		end
	end
	if safe > named then
		total += (safe - named) * config.EffectPerLevel
	end
	return total
end
local function costAtLevel(config, level)
	local tiers = config.Tiers
	local nextIndex = level + 1
	if tiers ~= nil and nextIndex >= 1 and nextIndex <= #tiers then
		local tierCost = tiers[nextIndex].Cost
		if type(tierCost) == "number" then
			return math.floor(tierCost + 0.5)
		end
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
			affordable = not maxed and gteFlux(bank, cost),
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
local function GuildGoalCardReady(_param)
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
	local claimHostRef = React.useRef(nil)
	React.useEffect(function()
		if not canClaim or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { canClaim, goal.TypeId, goal.Completed })
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
	}), React.createElement("frame", {
		Name = "GuildClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, 46) else UDim2.fromOffset(160, 46),
		Position = if stack then UDim2.new(0, 0, 1, -46) else UDim2.new(1, -160, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if canClaim then claimHostRef else nil,
	}, React.createElement(Button, {
		text = if claimed then "CLAIMED" elseif canClaim then "CLAIM REWARD" elseif goal.Completed then "NOT ELIGIBLE" else "NOT YET",
		icon = if claimed then "Check.13" else "Gift.9",
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
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})))
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
	return React.createElement(GuildGoalCardReady, _param)
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
		_result = `{percentText(row.currentEffect)}, fully installed`
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
		icon = if row.maxed then "Check.14" else "Forge.15",
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
	local manageable = canManage and Social.canManage({Role=_param.myRole or "Leader"},{Role=role},"Kick")
	local canPromote = (_param.myRole or "Leader") == "Leader"
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
	}), 	React.createElement(Text, {
		value = name,
		size = 14,
		color = ensureContrast(surface, Palette.cream),
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(44, 0),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 20),
	}), React.createElement(Badge, {
		value = string.upper(role),
		accent = accent,
		filled = role == "Leader" or role == "Officer",
		position = UDim2.fromOffset(44, 20),
		size = UDim2.fromOffset(if role == "Leader" then 60 else (if role == "Officer" then 64 else 58), 16),
	}), isLocal and React.createElement(Badge, {
		value = "YOU",
		accent = Palette.green,
		filled = true,
		position = UDim2.new(1, -48, 0, 2),
		size = UDim2.fromOffset(44, 18),
	}), React.createElement(Text, {
		value = `{compactNumber(contributed)} banked  •  {math.floor(share * 100 + 0.5)}% of all deposits`,
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(44, 38),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 16),
	}), goalShare > 0 and React.createElement(Text, {
		value = `{compactNumber(goalShare)} toward this goal`,
		size = 9,
		color = ensureContrast(surface, Palette.mint),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(44, 54),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 14),
	}), manageable and React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = if not canPromote then "LEADER ONLY" elseif role == "Officer" then "DEMOTE" else "PROMOTE",
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
		disabled = busy or not canPromote,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(0.5, -4, 0, 40) else UDim2.new(0.5, -4, 0, 40),
		position = if stack then UDim2.new(0, 0, 1, -40) else UDim2.new(0, 0, 1, -40),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if _param.confirmKick then "CONFIRM KICK" else "KICK",
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
				local value = ChatText.cutBytes(box.Text, 28)
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
		icon = "Forge.16",
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
		icon = "Crew.9",
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
local function GuildCommunityPanel(_param)
	local guild = _param.guild
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local role = _param.role
	local onBack = _param.onBack
	local guildConfig = (_param.config and _param.config.Guild) or {}
	local community = guild.Community or {}
	local settings, setSettings = React.useState(community.Settings or { ChatEnabled = true, AnnouncementsEnabled = true, LogoEnabled = true })
	local messages, setMessages = React.useState(community.Chat or {})
	local announcements, setAnnouncements = React.useState(community.Announcements or {})
	local logos, setLogos = React.useState({})
	local chatDraft, setChatDraft = React.useState("")
	local announcementTitle, setAnnouncementTitle = React.useState("")
	local announcementBody, setAnnouncementBody = React.useState("")
	local logoAsset, setLogoAsset = React.useState("")
	local moderationUserId, setModerationUserId = React.useState("")
	local renameName, setRenameName = React.useState("")
	local renameTag, setRenameTag = React.useState("")
	local chatScroll = React.useRef(nil)
	local localUserId = game:GetService("Players").LocalPlayer.UserId
	local busy, setBusy = React.useState("")
	local leader = role == "Leader"
	local manager = leader or role == "Officer"
	local requestCommunity = React.useCallback(function()
		dispatch("GetGuildChatHistory", { Limit = 50 }, function(result)
			if result.ok then setMessages(result.Messages or {}) end
		end)
		dispatch("GetGuildAnnouncements", {}, function(result)
			if result.ok then setAnnouncements(result.Announcements or {}) end
		end)
		dispatch("GetGuildSettings", {}, function(result)
			if result.ok then setSettings(result.Settings or {}) end
		end)
		if leader then
			dispatch("GetGuildLogoReview", {}, function(result)
				if result.ok then setLogos(result.Logos or {}) end
			end)
		end
	end, { dispatch, manager, guild.Id })
	React.useEffect(function()
		requestCommunity()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(8)
				if alive then requestCommunity() end
			end
		end)
		local connection = game:GetService("ReplicatedStorage"):WaitForChild("__AFX_BRIDGE_31"):WaitForChild("re_e31").OnClientEvent:Connect(function(packet)
			if not alive or type(packet) ~= "table" or packet.GuildId ~= guild.Id then return end
			if packet.Type == "GuildChat" and type(packet.Message) == "table" then					setMessages(function(previous)
						local updated = table.clone(previous)
						for _, existing in updated do if existing.Id == packet.Message.Id then return previous end end
						updated[#updated + 1] = packet.Message

					while #updated > 50 do table.remove(updated, 1) end
					return updated
				end)
			elseif packet.Refresh == true or packet.Type == "GuildAnnouncement" or packet.Type == "GuildSettings" or packet.Type == "GuildLogo" or packet.Type == "GuildModeration" then
				-- Refresh: another server changed something too large to relay inline
				requestCommunity()
			end
		end)
		return function()
			alive = false
			connection:Disconnect()
			pcall(task.cancel, worker)
		end
	end, { requestCommunity, guild.Id })
	local run = function(action, payload, done)
		if busy ~= "" then return end
		setBusy(action)
		dispatch(action, payload, function(result)
			setBusy("")
			if result.ok then requestCommunity() end
			if done then done(result) end
		end)
	end
	local fieldStyle = { BackgroundColor3 = Palette.void, BorderSizePixel = 0, TextColor3 = Palette.cream, PlaceholderColor3 = Palette.muted, TextSize = 14, ClearTextOnFocus = false, FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium) }
	local function input(placeholder, value, onChange, height, position)
		return React.createElement("textbox", {
			Size = UDim2.new(1, 0, 0, height or 42),
			Position = position or UDim2.fromOffset(0, 0),
			PlaceholderText = placeholder,
			Text = value,
			TextXAlignment = Enum.TextXAlignment.Left,
			Change = { Text = function(box) onChange(ChatText.cutBytes(box.Text, 800)) end },
			BackgroundColor3 = fieldStyle.BackgroundColor3,
			BorderSizePixel = fieldStyle.BorderSizePixel,
			TextColor3 = fieldStyle.TextColor3,
			PlaceholderColor3 = fieldStyle.PlaceholderColor3,
			TextSize = fieldStyle.TextSize,
			ClearTextOnFocus = false,
			FontFace = fieldStyle.FontFace,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement("uipadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }))
	end
	local ROLE_COLORS = { Leader = Palette.mango, Officer = Palette.cyan, Member = Palette.creamSoft }
	local chatRows = {}
	local previousSpeaker = nil
	for index, message in messages do
		local own = message.SpeakerUserId == localUserId
		local grouped = previousSpeaker == message.SpeakerUserId
		previousSpeaker = message.SpeakerUserId
		local stamp = if type(message.PublishedAt) == "number" then os.date("%H:%M", message.PublishedAt) else ""
		local roleColor = ROLE_COLORS[message.SpeakerRole] or Palette.creamSoft
		chatRows[#chatRows + 1] = React.createElement("frame", {
			key = message.Id or tostring(index),
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, React.createElement("uipadding", { PaddingLeft = UDim.new(0, if own then 40 else 0), PaddingRight = UDim.new(0, if own then 0 else 40), PaddingTop = UDim.new(0, if grouped then 0 else 4) }),
			React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = if own then Palette.cyan else Palette.panelSoft,
				BackgroundTransparency = if own then 0.82 else 0.35,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
				React.createElement("uipadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
				React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				not grouped and React.createElement("textlabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = `{message.SpeakerName or tostring(message.SpeakerUserId)}{if message.SpeakerRole and message.SpeakerRole ~= "Member" then "  ·  " .. string.upper(message.SpeakerRole) else ""}   {stamp}`,
					TextColor3 = roleColor,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				}),
				React.createElement("textlabel", {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = tostring(message.Message or ""),
					TextColor3 = Palette.cream,
					TextSize = 14,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				})))
	end
	if #chatRows == 0 then chatRows[1] = React.createElement(Text, { key = "no-chat", value = "No messages yet. Chat is visible only to this guild's members.", size = 12, color = Palette.muted, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 34) }) end
	React.useEffect(function()
		local frame = chatScroll.current
		if frame == nil then return nil end
		local job = task.defer(function()
			if frame.Parent then frame.CanvasPosition = Vector2.new(0, math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y)) end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { #messages })
	local function sendChat()
		if chatDraft == "" or settings.ChatEnabled == false then return end
		run("SendGuildChat", { Content = chatDraft }, function(result) if result.ok then setChatDraft("") end end)
	end
	local announcementRows = {}
	for index, item in announcements do
		local label = `{if item.Pinned then "[PINNED] " else ""}{item.Title}  ·  {item.AuthorName or "Guild staff"}`
		announcementRows[index] = React.createElement(Panel, {
			key = item.Id,
			size = UDim2.new(1, 0, 0, 116),
			accent = item.Pinned and Palette.mango or Palette.cyan,
			padding = 12,
			reducedMotion = reducedMotion,
		}, React.createElement(Text, { value = label, size = 13, weight = Enum.FontWeight.Bold, fit = true, sizeConstraint = UDim2.new(1, 0, 0, 22) }), React.createElement(Text, { value = item.Body, size = 11, color = Palette.creamSoft, wrap = true, position = UDim2.fromOffset(0, 28), sizeConstraint = UDim2.new(1, 0, 0, 52) }), manager and React.createElement(Button, {
			text = item.Pinned and "UNPIN" or "PIN",
			onClick = function() run("PinGuildAnnouncement", { AnnouncementId = item.Id, Pinned = not item.Pinned }) end,
			color = Palette.panelSoft,
			size = UDim2.fromOffset(92, 32),
			position = UDim2.new(1, -96, 1, -32),
			disabled = busy ~= "",
			reducedMotion = reducedMotion,
		}), manager and React.createElement(Button, {
			text = "ARCHIVE",
			onClick = function() run("ArchiveGuildAnnouncement", { AnnouncementId = item.Id }) end,
			color = Palette.panelSoft,
			textColor = Palette.coral,
			size = UDim2.fromOffset(92, 32),
			position = UDim2.new(1, -194, 1, -32),
			disabled = busy ~= "",
			reducedMotion = reducedMotion,
		}), React.createElement(Text, {
			value = if type(item.PublishedAt) == "number" then os.date("%b %d · %H:%M", item.PublishedAt) .. (if item.EditedAt then " · edited" else "") else "",
			size = 10,
			color = Palette.muted,
			position = UDim2.new(0, 0, 1, -24),
			sizeConstraint = UDim2.new(1, -200, 0, 18),
		}))
	end
	if #announcementRows == 0 then announcementRows[1] = React.createElement(Text, { key = "no-announcements", value = "No current announcements.", size = 12, color = Palette.muted }) end
	local logoRows = {}
	for index, logo in logos do
		logoRows[index] = React.createElement(Panel, { key = logo.Id, size = UDim2.new(1, 0, 0, 84), accent = Palette.violet, padding = 10 },

			React.createElement("imagelabel", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Image = logo.URL or "", ScaleType = Enum.ScaleType.Fit }),
			React.createElement(Text, { value = `Logo {string.sub(logo.Id, 1, 8)} · pending`, size = 12, fit = true, position = UDim2.fromOffset(58, 4), sizeConstraint = UDim2.new(1, -220, 0, 22) }),

			React.createElement(Button, { text = "APPROVE", onClick = function() run("ModerateGuildLogo", { LogoId = logo.Id, Decision = "approved" }) end, color = Palette.mint, size = UDim2.fromOffset(92, 34), position = UDim2.new(1, -196, 0, 12), disabled = busy ~= "", reducedMotion = reducedMotion }),
			React.createElement(Button, { text = "REJECT", onClick = function() run("ModerateGuildLogo", { LogoId = logo.Id, Decision = "rejected", Reason = "Did not meet guild logo guidelines." }) end, color = Palette.panelSoft, textColor = Palette.coral, size = UDim2.fromOffset(92, 34), position = UDim2.new(1, -98, 0, 12), disabled = busy ~= "", reducedMotion = reducedMotion }))
	end
	local settingsRows = {}
	if leader then
		local SETTING_LABELS = {
			ChatEnabled = "CHAT",
			AnnouncementsEnabled = "NEWS",
			LogoEnabled = "LOGOS",
			OfficerAnnouncements = "OFFICER NEWS",
			OfficerModeration = "OFFICER MODS",
			SlowMode = "SLOW MODE",
		}
		for index, key in { "ChatEnabled", "AnnouncementsEnabled", "LogoEnabled", "OfficerAnnouncements", "OfficerModeration", "SlowMode" } do
			local enabled = if key == "SlowMode" then settings[key] == true else settings[key] ~= false
			settingsRows[index] = React.createElement(Button, {
				key = key,
				text = `{SETTING_LABELS[key]}  {if enabled then "ON" else "OFF"}`,
				onClick = function()
					local updated = table.clone(settings)
					updated[key] = not enabled
					setSettings(updated)
					run("SetGuildSettings", { Settings = { [key] = updated[key] } })
				end,
				color = if enabled then Palette.mint else Palette.panelSoft,
				textColor = if enabled then Palette.ink else Palette.cream,
				size = UDim2.new(1 / 3, -6, 0, 42),
				position = UDim2.new(((index - 1) % 3) / 3, 0, 0, math.floor((index - 1) / 3) * 48),
				disabled = busy ~= "",
				reducedMotion = reducedMotion,
			})
		end
	end
	local sections = {
		{ id = "guild-community-back", height = 48, element = React.createElement(Button, { text = "‹  GUILD OVERVIEW", onClick = onBack, color = Palette.panelSoft, textColor = Palette.cream, size = UDim2.new(1, 0, 0, 44), reducedMotion = reducedMotion }) },
		{ id = "guild-community-chat", height = 430, element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.cyan, padding = 14, reducedMotion = reducedMotion, clips = false },
			React.createElement(Text, { value = `GUILD CHANNEL · {#messages} MESSAGE{if #messages == 1 then "" else "S"}{if settings.SlowMode == true then " · SLOW MODE" else ""}`, size = 12, color = Palette.cyan, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, 0, 0, 20) }),
			React.createElement("scrollingframe", {
				ref = chatScroll,
				Size = UDim2.new(1, 0, 0, 308),
				Position = UDim2.fromOffset(0, 26),
				BackgroundColor3 = Palette.void,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Palette.cyan,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement("uipadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
				React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }), chatRows),
			React.createElement("textbox", {
				Size = UDim2.new(1, -112, 0, 42),
				Position = UDim2.fromOffset(0, 344),
				PlaceholderText = if settings.ChatEnabled == false then "Chat is disabled by the leader" else "Message your guild…  (Enter to send)",
				Text = chatDraft,
				TextXAlignment = Enum.TextXAlignment.Left,
				Change = { Text = function(box) setChatDraft(ChatText.cutBytes(box.Text, 400)) end },
				Event = { FocusLost = function(_, enterPressed) if enterPressed then sendChat() end end },
				BackgroundColor3 = fieldStyle.BackgroundColor3,
				BorderSizePixel = 0,
				TextColor3 = fieldStyle.TextColor3,
				PlaceholderColor3 = fieldStyle.PlaceholderColor3,
				TextSize = fieldStyle.TextSize,
				ClearTextOnFocus = false,
				TextEditable = settings.ChatEnabled ~= false,
				FontFace = fieldStyle.FontFace,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement("uipadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })),
			React.createElement(Button, { text = "SEND", onClick = sendChat, color = Palette.cyan, textColor = Palette.ink, size = UDim2.new(0, 104, 0, 42), position = UDim2.new(1, -104, 0, 344), disabled = busy ~= "" or settings.ChatEnabled == false or chatDraft == "", loading = busy == "SendGuildChat", reducedMotion = reducedMotion }),
			React.createElement(Text, { value = `{#chatDraft}/400 · filtered by Roblox · members only`, size = 10, color = Palette.muted, position = UDim2.fromOffset(0, 390), sizeConstraint = UDim2.new(1, 0, 0, 16) })) },
		{ id = "guild-community-announcements", height = math.max(168, #announcementRows * 126 + (manager and 164 or 64)), element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
			React.createElement(SectionLabel, { value = "ANNOUNCEMENTS", color = Palette.mango }),
			manager and React.createElement(Panel, { size = UDim2.new(1, 0, 0, 154), accent = Palette.mango, padding = 12, clips = false }, input("Announcement title", announcementTitle, function(value) setAnnouncementTitle(ChatText.cutBytes(value, 120)) end, 40, UDim2.fromOffset(0, 0)), input("Announcement body", announcementBody, setAnnouncementBody, 46, UDim2.fromOffset(0, 44)), React.createElement(Button, { text = "PUBLISH", onClick = function() run("CreateGuildAnnouncement", { Title = announcementTitle, Body = announcementBody }, function(result) if result.ok then setAnnouncementTitle(""); setAnnouncementBody("") end end) end, color = Palette.mango, textColor = Palette.ink, size = UDim2.new(1, 0, 0, 36), position = UDim2.new(0, 0, 1, -36), disabled = busy ~= "" or settings.AnnouncementsEnabled == false or announcementTitle == "" or announcementBody == "", reducedMotion = reducedMotion }), settings.AnnouncementsEnabled == false and React.createElement(Text, { value = "Announcements are disabled by the guild leader.", size = 11, color = Palette.coral, position = UDim2.fromOffset(0, -16) })),
			announcementRows) },
	}
	if manager then
		local moderationButtons = {}
		for index, action in { "MuteGuildMember", "BanGuildMember", "UnmuteGuildMember", "UnbanGuildMember" } do
			local labels = { MuteGuildMember = "MUTE", BanGuildMember = "BAN", UnmuteGuildMember = "UNMUTE", UnbanGuildMember = "UNBAN" }
			local colors = { MuteGuildMember = Palette.mango, BanGuildMember = Palette.coral, UnmuteGuildMember = Palette.cyan, UnbanGuildMember = Palette.violet }
			moderationButtons[index] = React.createElement(Button, { key = action, text = labels[action], onClick = function()
				local id = tonumber(moderationUserId)
				if id and id > 0 then run(action, { UserId = math.floor(id) }) end
			end, color = colors[action], textColor = Palette.ink, size = UDim2.new(0.25, -6, 0, 40), position = UDim2.new((index - 1) * 0.25, 0, 0, 0), disabled = busy ~= "" or tonumber(moderationUserId) == nil, reducedMotion = reducedMotion })
		end
		table.insert(sections, { id = "guild-community-moderation", height = 146, element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.coral, padding = 14, clips = false }, React.createElement(SectionLabel, { value = "MEMBER MODERATION · USER ID", color = Palette.coral }), input("Guild member user ID", moderationUserId, function(value) setModerationUserId(string.sub(value, 1, 20)) end, 42, UDim2.fromOffset(0, 28)), React.createElement("frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 76), BackgroundTransparency = 1 }, moderationButtons)) })
	end
	if leader then
		table.insert(sections, { id = "guild-community-settings", height = 160, element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.violet, padding = 14 }, React.createElement(SectionLabel, { value = "GUILD RULES", color = Palette.violet }), React.createElement("frame", { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1 }, settingsRows), React.createElement(Text, { value = "Choose what officers can manage. Slow mode adds 6 seconds between member messages.", size = 11, color = Palette.muted, wrap = true, position = UDim2.fromOffset(0, 116), sizeConstraint = UDim2.new(1, 0, 0, 16) })) })
		local cooldownDays = math.floor((tonumber(guildConfig.RenameCooldownSeconds) or 604800) / 86400)
		local renameReady = #renameName >= 3 or #renameTag >= 3
		table.insert(sections, { id = "guild-community-rename", height = 178, element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.mango, padding = 14, clips = false },
			React.createElement(SectionLabel, { value = `RENAME · NOW {string.upper(tostring(guild.Name or ""))} [{guild.Tag or "?"}]`, color = Palette.mango }),
			React.createElement("textbox", {
				Size = UDim2.new(0.7, -6, 0, 42),
				Position = UDim2.fromOffset(0, 28),
				PlaceholderText = "New guild name (3–28)",
				Text = renameName,
				TextXAlignment = Enum.TextXAlignment.Left,
				Change = { Text = function(box) setRenameName(ChatText.cutBytes(box.Text, 28)) end },
				BackgroundColor3 = fieldStyle.BackgroundColor3,
				BorderSizePixel = 0,
				TextColor3 = fieldStyle.TextColor3,
				PlaceholderColor3 = fieldStyle.PlaceholderColor3,
				TextSize = fieldStyle.TextSize,
				ClearTextOnFocus = false,
				FontFace = fieldStyle.FontFace,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }), React.createElement("uipadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })),
			React.createElement("textbox", {
				Size = UDim2.new(0.3, 0, 0, 42),
				Position = UDim2.new(0.7, 0, 0, 28),
				PlaceholderText = "TAG",
				Text = renameTag,
				Change = { Text = function(box) setRenameTag(string.upper(string.sub((string.gsub(box.Text, "[^%w]", "")), 1, 4))) end },
				BackgroundColor3 = fieldStyle.BackgroundColor3,
				BorderSizePixel = 0,
				TextColor3 = fieldStyle.TextColor3,
				PlaceholderColor3 = fieldStyle.PlaceholderColor3,
				TextSize = fieldStyle.TextSize,
				ClearTextOnFocus = false,
				FontFace = fieldStyle.FontFace,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) })),
			React.createElement(Button, { text = "RENAME GUILD", onClick = function()
				local nextName = if #renameName >= 3 then renameName else tostring(guild.Name or "")
				run("RenameGuild", { Name = nextName, Tag = if #renameTag >= 3 then renameTag else nil }, function(result) if result.ok then setRenameName(""); setRenameTag("") end end)
			end, color = Palette.mango, textColor = Palette.ink, size = UDim2.new(1, 0, 0, 40), position = UDim2.fromOffset(0, 78), disabled = busy ~= "" or not renameReady, loading = busy == "RenameGuild", reducedMotion = reducedMotion }),
			React.createElement(Text, { value = `Costs {tostring(guildConfig.RenameCost or 10000)} flux · once every {cooldownDays} days · names are filtered`, size = 10, color = Palette.muted, position = UDim2.fromOffset(0, 124), sizeConstraint = UDim2.new(1, 0, 0, 16) })) })
	end
	if manager then
		local activeLogo = community.Logo
		local logoPreview = activeLogo and activeLogo.URL and React.createElement("imagelabel", { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(1, -60, 0, 0), BackgroundTransparency = 1, Image = activeLogo.URL, ScaleType = Enum.ScaleType.Fit })
		table.insert(sections, { id = "guild-community-logo", height = 164 + #logoRows * 94, element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.violet, padding = 14, clips = false }, React.createElement(SectionLabel, { value = "ROBLOX IMAGE LOGO · REVIEW REQUIRED", color = Palette.violet }), logoPreview, input("Roblox image asset ID", logoAsset, setLogoAsset, 42, UDim2.fromOffset(0, 28)), React.createElement(Button, { text = "SUBMIT FOR REVIEW", onClick = function() run("UploadGuildLogo", { URL = logoAsset }, function(result) if result.ok then setLogoAsset("") end end) end, color = Palette.violet, textColor = Palette.cream, size = UDim2.new(1, 0, 0, 38), position = UDim2.fromOffset(0, 76), disabled = busy ~= "" or settings.LogoEnabled == false or logoAsset == "", reducedMotion = reducedMotion }), React.createElement("frame", { Size = UDim2.new(1, 0, 0, #logoRows * 90), Position = UDim2.fromOffset(0, 120), BackgroundTransparency = 1 }, React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }), logoRows)) })
	end
	return React.createElement(PageScaffold, { gap = 10, tailPad = scrollTail(stack, 0, 72), scrollBarColor = Palette.cyan, scrollBarThickness = 4, sections = sections })
end

local function GuildView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local enter = useEntrance(softMotion)
	local reveal = useStagger(0, softMotion)
	local bankReveal = useStagger(1, softMotion)
	local membersReveal = useStagger(2, softMotion)
	local goalReveal = useStagger(3, softMotion)
	local _, refreshRequest = React.useState(0)

	local request = React.useMemo(function()
		return createRequest(dispatch,task.delay,function() refreshRequest(function(v) return v+1 end) end)
	end,{dispatch})
	React.useEffect(function() request.alive=true;return function() request.dispose() end end,{request})
	local busy=request.busy
	local confirmation=React.useRef(nil)
	local pane,setPane=React.useState(_param.initialTab or "Overview")
	local shakeToken, setShakeToken = React.useState(0)
	local contributeCash, setContributeCash = React.useState("")
	local contributeDust, setContributeDust = React.useState("")
	-- member search lives above the no-guild early return so hook order never changes
	local memberQuery, setMemberQuery = Browse.useLinkedQuery("GuildMembers")
	local memberRole, setMemberRole = React.useState("All")
	local guild = state.Guild
	local localPlayer = Players.LocalPlayer
	local localKey = if localPlayer ~= nil then tostring(localPlayer.UserId) else ""
	React.useEffect(function()
		dispatch("GetGuild", {})
	end, { dispatch })
	local send = function(action,payload,callback)
		if request.busy then return false end
		if action=="LeaveGuild" or action=="DisbandGuild" or action=="KickGuildMember" then
			local key=action..":"..tostring(payload and payload.UserId or "")
			if not confirmation.current or confirmation.current.key~=key or os.clock()>confirmation.current.untilTime then
				confirmation.current={key=key,untilTime=os.clock()+8}
				request.status="Press the same action again within 8 seconds to confirm. Leaving a guild does not refund contributions."
				refreshRequest(function(v) return v+1 end)
				return false
			end
		end
		confirmation.current=nil
		return request.run(action,payload,function(response)
			if not response.ok then setShakeToken(function(token) return token+1 end) end
			if callback then callback(response) end
		end)
	end
	-- the result of the last guild action; the panel only exists while there is one to show
	local function statusSection()
		if request.status == "" then return nil end
		return {id="guild-feedback",height=72,element=React.createElement(Panel,{size=UDim2.fromScale(1,1),padding=16,accent=Palette.cyan},React.createElement(Text,{value=request.status,size=13,wrap=true,sizeConstraint=UDim2.new(1,0,0,40)}))}
	end
	local function withStatus(list, at)
		local status = statusSection()
		if status then table.insert(list, at, status) end
		return list
	end
	if guild == nil or guild.Id == "" then
		local guide = if config.ClientPageGuides ~= nil then config.ClientPageGuides.Guild else nil
		local pageGap = if stack then 12 else Layout.panelGap
		local joinBlockH = 276 + pageGap + 192
		return React.createElement(PageScaffold, {
			gap = pageGap,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 80),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			sections = withStatus({
				{
					id = "empty-hero",
					height = 128,
					element = React.createElement(Panel, {
						size = UDim2.fromScale(1, 1),
						accent = Palette.violet,
						background = Palette.panelRaised,
						padding = if stack then 16 else 20,
						highlight = true,
						reveal = enter,
						reducedMotion = softMotion,
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
						reducedMotion = softMotion,
						busy = busy,
						shakeToken = shakeToken,
						stack = stack,
						cash = state.Cash,
					})),
				},
			}, 1),
		})
	end
	if pane == "Community" then
		return React.createElement(GuildCommunityPanel, {
			guild = guild,
			dispatch = dispatch,
			reducedMotion = softMotion,
			stack = stack,
			role = guild.Members[localKey] and guild.Members[localKey].Role or "Member",
			config = config,
			onBack = function() setPane("Overview") end,
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
	local heroHeight = if stack then 218 else 132
	local goalHeight = if guild.Goal == nil then 116 elseif stack then 234 else 196
	local bankHeight = if stack then 310 else 216
	local upgradeHeight = if stack then 180 else 140
	local memberHeight = if stack then 122 elseif canBuy then 112 else 84
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
	_attributes.sizeConstraint = UDim2.new(1, if stack then -8 else -160, 0, 14)
	local _exp_4 = React.createElement(Text, _attributes)
	local _exp_5 = React.createElement(Text, {
		value = guild.Name,
		size = if stack then 24 else 31,
		color = ensureContrast(heroSurface, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 17,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then -8 else -160, 0, 38),
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
		reveal = if reducedMotion then bankReveal else reveal,
		highlight = not reducedMotion and membersReveal ~= nil and goalReveal ~= nil,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_4, _exp_5, _exp_6, React.createElement(Text, _attributes_1), if canManage and #members == 1 then React.createElement(Button, {
		text = if confirmation.current and confirmation.current.key=="DisbandGuild:" then "CONFIRM DISBAND" else "DISBAND",
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
		position = if stack then UDim2.new(0, 0, 1, -42) else UDim2.new(1, -140, 0, 0),
		reducedMotion = softMotion,
	}) else React.createElement(Button, {
		text = if confirmation.current and confirmation.current.key=="LeaveGuild:" then "CONFIRM LEAVE" else "LEAVE",
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
		position = if stack then UDim2.new(0, 0, 1, -42) else UDim2.new(1, -140, 0, 0),
		reducedMotion = softMotion,
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
	local upgradeChildren = {}
	if #rows == 0 then
		upgradeChildren[1] = React.createElement(EmptyState, {
			key = "empty-upgrades",
			title = "No hall upgrades",
			body = "Hall upgrades are still loading.",
			icon = "Forge.17",
			accent = Palette.violet,
			size = UDim2.new(1, 0, 0, 72),
			layoutOrder = 1,
		})
	else
		for index, row in rows do
			upgradeChildren[index] = React.createElement(UpgradeCard, {
				key = row.id,
				row = row,
				guild = guild,
				canBuy = canBuy,
				stack = stack,
				reducedMotion = reducedMotion,
				dispatch = send,
				busy = busy,
				shakeToken = shakeToken,
				layoutOrder = index,
			})
		end
	end
	local upgradeBlockH = if #rows == 0 then 72 else #rows * upgradeHeight + math.max(0, #rows - 1) * pageGap
	local upgradeList = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pageGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), upgradeChildren)
	local roleCounts = { All = 0, Leader = 0, Officer = 0, Member = 0 }
	local shownMembers = {}
	for _, member in members do
		if Browse.matches(memberQuery, member.name, member.role, member.key) then
			roleCounts.All += 1
			roleCounts[member.role] = (roleCounts[member.role] or 0) + 1
			if memberRole == "All" or member.role == memberRole then
				table.insert(shownMembers, member)
			end
		end
	end
	local memberChildren = {}
	for index, member in shownMembers do
		local share = 0
		if goalContributors ~= nil then
			share = goalContributors[member.key] or 0
		end
		memberChildren[index] = React.createElement(MemberRow, {
			key = member.key,
			userKey = member.key,
			name = member.name,
			role = member.role,
			contributed = member.contributed,
			goalShare = share,
			share = if totalContributed > 0 then member.contributed / totalContributed else 0,
			isLocal = member.key == localKey,
			canManage = canBuy and member.key ~= localKey,
			myRole = myRole,
			confirmKick = confirmation.current and confirmation.current.key=="KickGuildMember:"..tostring(member.key),
			isLeader = member.role == "Leader",
			stack = stack,
			reducedMotion = reducedMotion,
			dispatch = send,
			busy = busy,
			shakeToken = shakeToken,
			layoutOrder = index,
		})
	end
	local memberBlockH = if #shownMembers == 0 then 72 else #shownMembers * memberHeight + math.max(0, #shownMembers - 1) * pageGap
	local overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2
	local memberSearchH = if stack then TapTarget else 40
	local memberFilter = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, React.createElement(SearchField, {
		value = memberQuery,
		onChange = setMemberQuery,
		placeholder = "Search members",
		accent = Palette.violet,
		reducedMotion = softMotion,
		size = UDim2.new(1, 0, 0, memberSearchH),
		zIndex = 20,
	}), React.createElement(Browse.ChipRow, {
		options = {
			{ id = "All", label = "Everyone" },
			{ id = "Leader", label = "Leader" },
			{ id = "Officer", label = "Officers" },
			{ id = "Member", label = "Members" },
		},
		value = memberRole,
		onChange = function(id)
			setMemberRole(id)
		end,
		counts = roleCounts,
		accent = Palette.violet,
		position = UDim2.fromOffset(0, memberSearchH + 8),
	}))
	local memberList = if #shownMembers == 0 then React.createElement(EmptyState, {
		title = if #members > 0 then "No members match" else "No members",
		body = if #members > 0 then "Clear the search or pick Everyone." else "Members show up here.",
		icon = "Pilot.2",
		accent = Palette.cyan,
		size = UDim2.new(1, 0, 0, 72),
	}) else React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pageGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), memberChildren)
	local hall=Social.hall(guild)
	local tabs={}
	local columns=if stack then 2 else 5
	local guildTabs={"Overview","Treasury","Upgrades","Members","Community"}
	for index,id in guildTabs do
		tabs[index]=React.createElement(Button,{text=string.upper(id),size=UDim2.new(1/columns,-6,0,48),position=UDim2.new(((index-1)%columns)/columns,0,0,math.floor((index-1)/columns)*56),color=if pane==id then Palette.violet else Palette.panelSoft,onClick=function() setPane(id) end,reducedMotion=softMotion})
	end
	local navigationHeight=math.ceil(#guildTabs/columns)*56
	local sections=withStatus({
		{id="hero",height=heroHeight,element=_exp_11},
		{id="guild-navigation",height=navigationHeight,element=React.createElement("frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},tabs)},
	}, 2)
	local function add(id,height,element) table.insert(sections,{id=id,height=height,element=element}) end
	if pane=="Overview" then
		add("hall-progress",if stack then 132 else 112,React.createElement(Panel,{size=UDim2.fromScale(1,1),padding=16,accent=Palette.mint},
			React.createElement(Text,{value=`HALL LEVEL {hall.Level} · {hall.Title}`,size=19,wrap=true,weight=Enum.FontWeight.Heavy,sizeConstraint=UDim2.new(1,0,0,26)}),
			React.createElement(Meter,{value=hall.Progress,position=UDim2.fromOffset(0,34),size=UDim2.new(1,0,0,10),color=Palette.mint,reducedMotion=softMotion}),
			React.createElement(Text,{value=`{hall.Remaining} more upgrade level{if hall.Remaining == 1 then "" else "s"} to the next hall level. Every five installed upgrade levels add one.`,position=UDim2.fromOffset(0,54),size=13,color=Palette.creamSoft,wrap=true,sizeConstraint=UDim2.new(1,0,0,if stack then 44 else 24)})))
		add("goal",goalHeight,_exp_12)
	elseif pane=="Treasury" then
		add("bank",bankHeight,_exp_19)
	elseif pane=="Upgrades" then
		add("upgrades-label",sectionLabelH,_exp_20)
		add("upgrades",upgradeBlockH,upgradeList)
	else
		add("role-policy",if stack then 176 else 120,React.createElement(Panel,{size=UDim2.fromScale(1,1),padding=16,accent=Palette.cyan},
			React.createElement(Text,{value="ROLES & SUCCESSION",size=17,weight=Enum.FontWeight.Heavy,sizeConstraint=UDim2.new(1,0,0,24)}),
			React.createElement(Text,{value="Leaders manage roles and the hall. Officers handle upgrades and members. Everyone can contribute and claim goal rewards. Leadership passes to an officer, then the earliest member.",position=UDim2.fromOffset(0,32),size=13,color=Palette.creamSoft,wrap=true,sizeConstraint=UDim2.new(1,0,0,if stack then 110 else 52)})))
		if #members > 3 then
			add("member-filter",memberSearchH + 8 + Browse.CHIP_H,memberFilter)
		end
		add("members",memberBlockH,memberList)
	end
	return React.createElement(PageScaffold,{gap=12,tailPad=scrollTail(chrome.stack,chrome.bottomSafe,80),scrollBarColor=Palette.violet,scrollBarThickness=4,sections=sections})

end
return {
	GuildView = GuildView,
}
end

__defs["MailboxView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local formatReward = require(script.Parent.Parent.CoreKit)("format").formatReward
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local TapTarget = _theme.TapTarget
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local measureWrappedTextHeight = _ui.measureWrappedTextHeight
local ScriptedText = require(script.Parent.Parent.ReactHosts)("RichTextHost").ScriptedText
local SearchField = _ui.SearchField
local Browse = require(script.Parent.Parent.BrowseKit)
local ChatText = require(script.Parent.Parent.CoreKit)("chatText")

local h = React.createElement
local ROW_H = 84
local ROW_GAP = 8
local FILTERS = {
	{ id = "All", label = "All" },
	{ id = "Unread", label = "Unread" },
	{ id = "Gifts", label = "Gifts" },
	{ id = "Collected", label = "Collected" },
	{ id = "Alerts", label = "Alerts" },
}
local NoticeMath = require(script.Parent.Parent.CoreKit)("noticeMath")
local ALERT_COLORS = { Success = "mint", Warning = "mango", Error = "coral", Special = "violet" }

local function alertRows(query)
	local rows = {}
	for _, entry in NoticeMath.Entries() do
		local subject = if entry.Count > 1 then `{entry.Title}  ×{entry.Count}` else entry.Title
		local keep = query == "" or Browse.matches(query, entry.Title, entry.Body)
		if keep then
			local item = {
				Id = entry.Id,
				Subject = if subject ~= "" then subject else "Forge alert",
				Sender = "Forge alerts",
				Preview = entry.Body,
				Date = os.date("%H:%M", entry.At),
				Body = { if entry.Body ~= "" then entry.Body else entry.Title },
				Color = Palette[ALERT_COLORS[entry.Tone] or "cyan"] or Palette.cyan,
			}
			table.insert(rows, { Id = entry.Id, item = item, mail = { Read = true, Claimed = false } })
		end
	end
	return rows
end

local function paragraphHeight(value, width, size)
	return math.max(20, measureWrappedTextHeight(value, width, size, Enum.FontWeight.Regular) + 6)
end

local function hasGift(item)
	return item.Attachment ~= nil and next(item.Attachment) ~= nil
end

local function Avatar(props)
	local item = props.item
	local letter = ChatText.initial(item.Sender)
	return h("frame", {
		Size = UDim2.fromOffset(props.size, props.size),
		Position = props.position,
		BackgroundColor3 = darken(item.Color, if props.unread then 0.25 else 0.65),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = item.Color,
		Thickness = 1.5,
		Transparency = if props.unread then 0.05 else 0.55,
	}), h(Text, {
		value = letter,
		size = math.floor(props.size * 0.42),
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 4,
	}))
end

local function MailRow(props)
	local item = props.item
	local mail = props.mail
	local unread = not mail.Read
	local gift = hasGift(item) and not mail.Claimed
	local softMotion = props.softMotion
	local reveal = useStagger(props.order, softMotion, 0.02, 0.2)
	local hover, setHover = React.useState(false)
	local glow = useFlipperSpring(if props.active then 1 elseif hover then 0.5 else 0, softMotion, 640, 36)
	return h("imagebutton", {
		Name = "MailRow",
		Size = UDim2.new(1, -4, 0, ROW_H),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = reveal:map(function(a)
			return 1 - a
		end),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Selectable = true,
		ClipsDescendants = false,
		Event = {
			Activated = function()
				props.onChoose(item.Id)
			end,
			MouseEnter = function()
				setHover(true)
				Audio:play("hover")
			end,
			MouseLeave = function()
				setHover(false)
			end,
			SelectionGained = function()
				setHover(true)
			end,
			SelectionLost = function()
				setHover(false)
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = if props.active or unread then item.Color else Palette.lineSoft,
		Thickness = glow:map(function(a)
			return 1 + a
		end),
		Transparency = glow:map(function(a)
			return if unread then 0.35 - a * 0.3 else 0.7 - a * 0.5
		end),
	}), h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = item.Color,
		BackgroundTransparency = glow:map(function(a)
			return 1 - a * 0.1
		end),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) })), h(Avatar, {
		item = item,
		unread = unread,
		size = 44,
		position = UDim2.new(0, 12, 0.5, -22),
	}), h(Text, {
		value = item.Subject,
		size = 15,
		color = Palette.cream,
		weight = if unread then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(68, 12),
		sizeConstraint = UDim2.new(1, -150, 0, 20),
		zIndex = 3,
	}), h(Text, {
		value = item.Sender,
		size = 12,
		color = item.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(68, 33),
		sizeConstraint = UDim2.new(1, -150, 0, 16),
		zIndex = 3,
	}), h(Text, {
		value = item.Preview or "",
		size = 12,
		color = Palette.muted,
		position = UDim2.fromOffset(68, 52),
		sizeConstraint = UDim2.new(1, -80, 0, 18),
		zIndex = 3,
	}), h(Text, {
		value = item.Date or "",
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -94, 0, 12),
		sizeConstraint = UDim2.fromOffset(82, 16),
		zIndex = 3,
	}), h("frame", {
		Size = UDim2.fromOffset(70, 20),
		Position = UDim2.new(1, -82, 0, 32),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, h("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 4),
	}), unread and h(Badge, {
		value = "NEW",
		accent = item.Color,
		filled = true,
		size = UDim2.fromOffset(40, 18),
	}), gift and h("frame", {
		Size = UDim2.fromOffset(22, 18),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 6) }), h(Icon, {
		kind = "Gift.10",
		color = Palette.ink,
		accent = Palette.mint,
		size = 14,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), not gift and mail.Claimed and hasGift(item) and h("frame", {
		Size = UDim2.fromOffset(22, 18),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 6) }), h(Icon, {
		kind = "Check.15",
		color = Palette.mint,
		accent = Palette.mint,
		size = 14,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	}))))
end

local function Parcel(props)
	local item = props.item
	local claimed = props.claimed
	local softMotion = props.softMotion
	local stack = props.stack
	local pop = useFlash(props.claimToken, softMotion, 0.7)
	return h("frame", {
		Name = "MailClaimActions",
		Size = UDim2.new(1, 0, 0, props.height),
		Position = UDim2.new(0, 0, 1, -props.height),
		BackgroundColor3 = darken(item.Color, if claimed then 0.85 else 0.72),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 6,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = if claimed then Palette.lineSoft else item.Color,
		Thickness = pop:map(function(a)
			return 1.5 + a * 2
		end),
		Transparency = if claimed then 0.6 else 0.15,
	}), h("frame", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromOffset(14, 14),
		BackgroundColor3 = if claimed then Palette.panelSoft else item.Color,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uiscale", {
		Scale = pop:map(function(a)
			return 1 + a * 0.3
		end),
	}), h(Icon, {
		kind = if claimed then "Check.16" else "Gift.11",
		color = if claimed then Palette.mint else Palette.ink,
		accent = item.Color,
		size = 28,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
		reducedMotion = softMotion,
	})), h(Text, {
		value = if claimed then "COLLECTED" else "ATTACHED GIFT",
		size = 11,
		color = if claimed then Palette.mint else item.Color,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(74, 16),
		sizeConstraint = UDim2.new(1, if stack then -86 else -340, 0, 14),
		zIndex = 7,
	}), h(Text, {
		value = formatReward(item.Attachment),
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(74, 34),
		sizeConstraint = UDim2.new(1, if stack then -86 else -340, 0, 22),
		zIndex = 7,
	}), h("frame", {
		Size = if stack then UDim2.new(1, -28, 0, TapTarget) else UDim2.fromOffset(310, TapTarget),
		Position = if stack then UDim2.new(0, 14, 1, -(TapTarget + 14)) else UDim2.new(1, -324, 0.5, -TapTarget / 2),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 8,
	}, h("frame", {
		Name = "MailClaim",
		Size = UDim2.new(0.62, -4, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, h(Button, {
		text = if claimed then "COLLECTED" else "CLAIM GIFT",
		icon = "Gift.12",
		onClick = props.onClaim,
		color = if claimed then Palette.panelSoft else item.Color,
		textColor = if claimed then Palette.muted else Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = claimed,
		highlight = not claimed,
		reducedMotion = softMotion,
	})), h("frame", {
		Name = "MailArchive",
		Size = UDim2.new(0.38, -4, 1, 0),
		Position = UDim2.new(0.62, 4, 0, 0),
		BackgroundTransparency = 1,
	}, h(Button, {
		text = "ARCHIVE",
		icon = "Close.4",
		onClick = props.onArchive,
		color = Palette.coral,
		textColor = if claimed then Palette.cream else Palette.muted,
		outline = true,
		size = UDim2.fromScale(1, 1),
		disabled = not claimed,
		reducedMotion = softMotion,
	}))))
end

local function MailboxView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local stack = chrome.contentStack
	local mobileRoute = chrome.mobile or viewport.width < 760
	local mountedRef = React.useRef(true)
	local mailActionsHostRef = React.useRef(nil)
	React.useEffect(function()
		mountedRef.current = true
		return function()
			mountedRef.current = false
		end
	end, {})
	local filter, setFilter = React.useState("All")
	local query, setQuery = Browse.useLinkedQuery("Mail")
	local claimToken, setClaimToken = React.useState(0)
	local alertRevision, setAlertRevision = React.useState(0)
	React.useEffect(function()
		return NoticeMath.Subscribe(function()
			if mountedRef.current then
				setAlertRevision(function(n)
					return n + 1
				end)
			end
		end)
	end, {})
	local messages = (state.Mailbox and state.Mailbox.Messages) or {}
	local defs = {}
	for _, def in config.Mail or {} do
		defs[def.Id] = def
	end
	local rows, unread, gifts = {}, 0, 0
	for _, mail in messages do
		local item = defs[mail.Id]
		if item ~= nil then
			local gift = hasGift(item) and not mail.Claimed
			if not mail.Read then
				unread += 1
			end
			if gift then
				gifts += 1
			end
			local keep = filter == "All" or (filter == "Unread" and not mail.Read) or (filter == "Gifts" and gift) or (filter == "Collected" and mail.Claimed)
			if keep and query ~= "" then
				keep = Browse.matches(query, item.Subject, item.Sender, if type(item.Body) == "table" then table.concat(item.Body, " ") else nil)
			end
			if keep then
				table.insert(rows, { Id = item.Id, item = item, mail = mail })
			end
		end
	end
	if filter == "Alerts" and alertRevision >= 0 then
		rows = alertRows(query)
	end
	local selectedId, setSelectedId = React.useState(if mobileRoute then "" else (rows[1] and rows[1].Id or ""))
	local selected = nil
	for _, row in rows do
		if row.Id == selectedId then
			selected = row
		end
	end
	if selected == nil and not mobileRoute then
		selected = rows[1]
	end
	local showReader = mobileRoute and selected ~= nil
	local slide = useFlipperSpring(if showReader then 1 else 0, softMotion, 700, 40)
	local selectedKey = selected and selected.Id or ""
	local selectedRead = selected ~= nil and selected.mail.Read
	React.useEffect(function()
		if selected ~= nil and not selected.mail.Read then
			dispatch("ReadMail", { Id = selected.Id })
		end
	end, { selectedKey, selectedRead })
	React.useEffect(function()
		if selected == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = mailActionsHostRef.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { selectedKey, selected ~= nil and selected.mail.Claimed })
	local choose = function(id)
		if id ~= selectedId then
			Audio:play("mailRead")
			setSelectedId(id)
		end
	end
	local headerH = if stack then 118 else 64
	local header = h("frame", {
		Size = UDim2.new(1, 0, 0, headerH),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = Palette.lineSoft,
		Transparency = 0.5,
	}), h("frame", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = darken(Palette.cyan, 0.6),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h(Icon, {
		kind = "Mail.2",
		color = Palette.cream,
		accent = Palette.cyan,
		size = 24,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		reducedMotion = softMotion,
	})), h(Text, {
		value = "MAILBOX",
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(62, 12),
		sizeConstraint = UDim2.new(0, 160, 0, 14),
	}), h(Text, {
		value = if unread == 0 and gifts == 0 then "All caught up" else `{unread} unread · {gifts} gift{if gifts == 1 then "" else "s"} waiting`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(62, 28),
		sizeConstraint = UDim2.new(if stack then 1 else 0, if stack then -(62 + 150) else 260, 0, 22),
	}), gifts > 0 and h(Button, {
		text = `CLAIM ALL ({gifts})`,
		icon = "Gift.13",
		onClick = function()
			Audio:play("mailClaim")
			setClaimToken(function(n)
				return n + 1
			end)
			dispatch("ClaimAllMail", {})
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromOffset(140, TapTarget - 4),
		position = UDim2.new(1, -152, 0, 10),
		highlight = true,
		reducedMotion = softMotion,
	}), h("frame", {
		Size = if stack then UDim2.new(1, -24, 0, TapTarget + 8) else UDim2.new(1, -(380 + (if gifts > 0 then 164 else 12)), 0, 40),
		Position = if stack then UDim2.fromOffset(12, headerH - TapTarget - 18) else UDim2.fromOffset(372, 12),
		BackgroundTransparency = 1,
	}, h(SegmentedTabs, {
		options = FILTERS,
		value = filter,
		onChange = function(id)
			setFilter(id)
			setSelectedId("")
		end,
		accent = Palette.cyan,
		columns = #FILTERS,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	})))
	local selectedRowId = selected and selected.Id or ""
	local searchH = if stack then TapTarget else 40
	local list = if #rows == 0 then h("frame", {
		Size = UDim2.new(1, 0, 1, -(searchH + 12)),
		Position = UDim2.fromOffset(0, searchH + 12),
		BackgroundTransparency = 1,
	}, h(EmptyState, {
		icon = if query ~= "" then "Search.6" else "Mail.3",
		title = if query ~= "" then `No letters match "{query}"` elseif filter == "All" then "Your tray is empty" elseif filter == "Alerts" then "No recent alerts" else "Nothing in " .. string.lower(filter),
		body = if query ~= "" then "Try the sender's name or one word from the subject." elseif filter == "Alerts" then "Pop-ups from this session are kept here so you can read them again." else "Patch notes, letters and gifts land here.",
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	})) else React.createElement(FlatList, {
		data = rows,
		itemHeight = ROW_H + ROW_GAP,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 6,
		Size = UDim2.new(1, -12, 1, -(searchH + 18)),
		Position = UDim2.fromOffset(6, searchH + 12),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 3,
		keyExtractor = function(row)
			return row.Id
		end,
		renderItem = function(entry)
			local row = entry.item
			return h(MailRow, {
				item = row.item,
				mail = row.mail,
				active = row.Id == selectedRowId,
				order = 0,
				softMotion = softMotion,
				onChoose = choose,
			})
		end,
	})
	local bodyArea = nil
	if selected ~= nil then
		local item = selected.item
		local readerW = if mobileRoute then viewport.width - 24 else viewport.width * 0.6
		local textW = math.max(60, readerW - 64)
		local bodySize = if stack then 16 else 15
		local bodyRows = {}
		local stride = 28
		for index, paragraph in item.Body or {} do
			local height = paragraphHeight(paragraph, textW, bodySize)
			stride = math.max(stride, height + 10)
			bodyRows[index] = { Id = `{item.Id}:{index}`, Text = paragraph, Index = index - 1, Height = height }
		end
		local gift = hasGift(item)
		local claimed = selected.mail.Claimed == true
		local parcelH = if not gift then 0 elseif stack then 138 else 78
		local letterTop = if stack then 74 else 92
		bodyArea = h("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = lighten(Palette.panel, 0.02),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
			Color = item.Color,
			Transparency = 0.5,
		}), h("frame", {
			Name = "LetterHead",
			Size = UDim2.new(1, 0, 0, letterTop),
			BackgroundColor3 = darken(item.Color, 0.8),
			BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), mobileRoute and h(Button, {
			text = "",
			icon = "Back.1",
			onClick = function()
				setSelectedId("")
			end,
			color = Palette.panelSoft,
			textColor = item.Color,
			outline = true,
			size = UDim2.fromOffset(TapTarget, TapTarget),
			position = UDim2.new(0, 10, 0.5, -TapTarget / 2),
			reducedMotion = softMotion,
		}), not mobileRoute and h(Avatar, {
			item = item,
			unread = true,
			size = 52,
			position = UDim2.new(0, 18, 0.5, -26),
		}), h(Text, {
			value = item.Subject,
			size = if stack then 18 else 22,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 12,
			position = UDim2.fromOffset(if mobileRoute then 64 else 84, if stack then 12 else 20),
			sizeConstraint = UDim2.new(1, if mobileRoute then -76 else -104, 0, if stack then 24 else 30),
		}), h(Text, {
			value = `From {item.Sender}{if item.Date then "  ·  " .. item.Date else ""}`,
			size = 12,
			color = item.Color,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(if mobileRoute then 64 else 84, if stack then 40 else 54),
			sizeConstraint = UDim2.new(1, if mobileRoute then -76 else -104, 0, 18),
		})), React.createElement(FlatList, {
			key = item.Id,
			data = bodyRows,
			itemHeight = stride,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 8,
			Size = UDim2.new(1, -40, 1, -(letterTop + parcelH + 24)),
			Position = UDim2.fromOffset(20, letterTop + 10),
			scrollBarColor = item.Color,
			scrollBarThickness = 3,
			keyExtractor = function(row)
				return row.Id
			end,
			renderItem = function(entry)
				local row = entry.item
				if row.Index == 0 then
					return h(ScriptedText, {
						key = row.Id,
						text = row.Text,
						width = textW,
						height = row.Height,
						size = bodySize,
						color = Palette.cream,
						weight = Enum.FontWeight.SemiBold,
						typewriterInterval = 0.01,
						reducedMotion = softMotion,
					})
				end
				return h(Text, {
					key = row.Id,
					value = row.Text,
					size = bodySize,
					color = Palette.creamSoft,
					wrap = true,
					sizeConstraint = UDim2.new(1, -8, 0, row.Height),
				})
			end,
		}), gift and h("frame", {
			ref = mailActionsHostRef,
			Size = UDim2.new(1, -20, 0, parcelH),
			Position = UDim2.new(0, 10, 1, -(parcelH + 10)),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
		}, h(Parcel, {
			item = item,
			claimed = claimed,
			stack = stack,
			height = parcelH,
			softMotion = softMotion,
			claimToken = claimToken,
			onClaim = function()
				Audio:play("mailClaim")
				setClaimToken(function(n)
					return n + 1
				end)
				dispatch("ClaimMail", { Id = item.Id })
			end,
			onArchive = function()
				dispatch("DeleteMail", { Id = item.Id }, function(response)
					if mountedRef.current and response.ok then
						setSelectedId("")
					end
				end)
			end,
		})))
	elseif not mobileRoute then
		bodyArea = h(EmptyState, {
			icon = "Mail.4",
			title = "Pick a letter",
			body = "Choose a message on the left to read it.",
			accent = Palette.cyan,
			size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
		})
	end
	local bodyTop = headerH + 10
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, header, h("frame", {
		Size = UDim2.new(1, 0, 1, -bodyTop),
		Position = UDim2.fromOffset(0, bodyTop),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, h("frame", {
		Name = "Inbox",
		Size = if mobileRoute then UDim2.fromScale(1, 1) else UDim2.new(0.38, -6, 1, 0),
		Position = if mobileRoute then slide:map(function(a)
			return UDim2.fromScale(-math.clamp(a, 0, 1), 0)
		end) else nil,
		Visible = if mobileRoute then slide:map(function(a)
			return a < 0.99
		end) else true,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h(SearchField, {
		value = query,
		onChange = function(text)
			setQuery(text)
			setSelectedId("")
		end,
		placeholder = "Search letters",
		accent = Palette.cyan,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(6, 6),
		size = UDim2.new(1, -12, 0, searchH),
		zIndex = 6,
	}), list), bodyArea ~= nil and h("frame", {
		Name = "Reader",
		Size = if mobileRoute then UDim2.fromScale(1, 1) else UDim2.new(0.62, -6, 1, 0),
		Position = if mobileRoute then slide:map(function(a)
			return UDim2.fromScale(1 - math.clamp(a, 0, 1), 0)
		end) else UDim2.new(0.38, 6, 0, 0),
		Visible = if mobileRoute then slide:map(function(a)
			return a > 0.01
		end) else true,
		BackgroundTransparency = 1,
	}, bodyArea)))
end

return {
	MailboxView = MailboxView,
}
end

__defs["ChatView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _AnimatedTitle = require(script.Parent.Parent.ReactHosts)("AnimatedTitle")
local AnimatedTitle = _AnimatedTitle.AnimatedTitle
local titleFxAccent = _AnimatedTitle.titleFxAccent
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _Icon = require(script.Parent.Parent.ArtKit)("Icon")
local Icon = _Icon.Icon
local PlayerMark = _Icon.PlayerMark
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local Layout = _theme.Layout
local darken = _theme.darken
local lighten = _theme.lighten
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local SearchField = _ui.SearchField
local SegmentedTabs = _ui.SegmentedTabs
local ElementFx = require(script.Parent.Parent.ElementFx).ElementFx
local ARTIFACT_CHIP_W = 124
local ROW_HEIGHT = 98
local CARD_H = 90
local SYSTEM_CARD_H = 66
local STATUS_HEIGHT = 64
local BANNER_HEIGHT = 52
local INPUT_HEIGHT = 60
local GAP = Layout.stackGap
local SIDE_INSET = 12
local STATUS_RESERVE = 128
local NEAR_BOTTOM = 96
local ChatText = require(script.Parent.Parent.CoreKit)("chatText")
local ChatRules = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ChatRules"))
local DRAFT_LIMIT = ChatRules.MAX_INPUT + 40 -- room for "/w name " in front of a full message
local TAB_ROW_H = 44
local PEER_ROW_H = 40
local SUGGEST_ROW_H = 40
local TAB_DEFS = {
	{ id = "all", label = "All" },
	{ id = "global", label = "Global" },
	{ id = "server", label = "Server" },
	{ id = "crew", label = "Crew" },
	{ id = "friends", label = "Friends" },
	{ id = "whispers", label = "Whispers" },
}
local EMPTY_CHAT = {
	messages = {}, unread = 0, unreadByTab = {}, connected = false,
	tab = "all", setTab = function() end, peer = nil, setPeer = function() end, whispers = {},
	send = function(_, done) if done then done(false, "Chat is still connecting.") end end,
	clear = function() end,
	suggest = function() return {} end,
}
-- one-row chip strip (whisper peers, autocomplete). Chat keeps no raw scrollers, so it clips:
-- callers pass chips most-relevant first and the tail is what gets cut on narrow screens.
local function chipRail(chips, zIndex)
	local children = {
		layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for order, chip in chips do
		children[chip.key] = React.createElement("frame", {
			LayoutOrder = order,
			Size = UDim2.new(0, 0, 1, -4),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, chip.element)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex,
	}, children)
end
local function channelBadge(message)
	if message.localPlayer then
		return "YOU"
	end
	if message.channel == "global" then
		return "GLOBAL"
	elseif message.channel == "crew" then
		return "CREW"
	elseif message.channel == "whisper" then
		return "WHISPER"
	elseif message.channel == "friends" then
		return "FRIEND"
	end
	return `WORLD {message.world}`
end
local TAG_COLORS = { Palette.cyan, Palette.mint, Palette.violet, Palette.mango, Palette.pink, Palette.blue }
local function userColor(userId)
	local authorId = tonumber(userId) or 0
	if authorId ~= authorId or math.abs(authorId) == math.huge then
		authorId = 0
	end
	return TAG_COLORS[math.floor(math.abs(authorId)) % #TAG_COLORS + 1]
end
local function useMessageEntrance(animate, reducedMotion)
	local shouldAnimate = React.useRef(animate and not reducedMotion)
	local live, setLive = React.useState(not shouldAnimate.current)
	React.useEffect(function()
		if not shouldAnimate.current then
			setLive(true)
			return nil
		end
		setLive(false)
		local alive = true
		local job = task.defer(function()
			if alive then
				setLive(true)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, {})
	return useFlipperSpring(if live then 1 else 0, reducedMotion, 780, 38)
end
local function MessageRow(_param)
	local message = _param.message
	local position = _param.position
	local reducedMotion = _param.reducedMotion
	local bodySize = _param.bodySize
	local animate = _param.animate
	local rowHeight = _param.rowHeight
	local softMotion = reducedMotion
	local enter = useMessageEntrance(animate, reducedMotion)
	local accent = if message.system then Palette.mango else userColor(message.userId)
	local authorId = tonumber(message.userId) or 0
	if authorId ~= authorId or math.abs(authorId) == math.huge then
		authorId = 0
	end
	local pulse = usePulse(not message.system, 2.4 + math.abs(authorId % 5) * 0.14)
	local fade = enter:map(function(amount)
		return 1 - amount
	end)
	local cardY = if message.system then math.floor((rowHeight - SYSTEM_CARD_H) / 2) else 4
	local cardH = if message.system then SYSTEM_CARD_H else math.max(CARD_H, rowHeight - 8)
	if message.system then
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, rowHeight),
			Position = position,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("frame", {
			Size = UDim2.new(1, -4, 0, cardH),
			Position = enter:map(function(amount)
				return UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 8))
			end),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = fade:map(function(amount)
				return 0.08 + amount * 0.92
			end),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uiscale", {
			Scale = enter:map(function(amount)
				return 0.97 + amount * 0.03
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			Color = accent,
			Thickness = 1,
			Transparency = fade:map(function(amount)
				return 0.42 + amount * 0.58
			end),
		}), React.createElement("frame", {
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = accent,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 2),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.fromOffset(14, 14),
			BackgroundColor3 = darken(accent, 0.62),
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement(Icon, {
			kind = "Chat.2",
			color = Palette.ink,
			accent = accent,
			size = 22,
			position = UDim2.fromOffset(8, 8),
			spin = false,
		})), React.createElement(Text, {
			value = "GAME MESSAGE",
			size = 12,
			color = accent,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(64, 12),
			sizeConstraint = UDim2.new(1, -78, 0, 16),
			transparency = fade,
		}), React.createElement(Text, {
			value = message.text,
			size = bodySize,
			color = Palette.cream,
			weight = Enum.FontWeight.Medium,
			wrap = true,
			position = UDim2.fromOffset(64, 32),
			sizeConstraint = UDim2.new(1, -78, 0, 28),
			transparency = fade,
		})))
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, cardH),
		Position = enter:map(function(amount)
			return UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 10))
		end),
		BackgroundColor3 = if message.mention then darken(Palette.mango, 0.8) elseif message.localPlayer then darken(accent, 0.88) else Palette.panel,
		BackgroundTransparency = fade:map(function(amount)
			return 0.04 + amount * 0.96
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = enter:map(function(amount)
			return 0.97 + amount * 0.03
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if message.mention then Palette.mango else accent,
		Thickness = if message.mention then 2 else 1,
		Transparency = fade:map(function(amount)
			return (if message.mention then 0.1 elseif message.localPlayer then 0.32 else 0.58) + amount * 0.42
		end),
	}), message.artifactElement ~= nil and React.createElement(ElementFx, {
		element = message.artifactElement,
		size = UDim2.fromOffset(64, 64),
		position = UDim2.fromOffset(33, 38),
		transparency = 0.25,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(12, 17),
		BackgroundColor3 = darken(accent, 0.5),
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = pulse:map(function(amount)
			return 0.2 + amount * 0.4
		end),
	}), React.createElement(PlayerMark, {
		userId = message.userId,
		color = Palette.ink,
		accent = accent,
		size = 26,
		position = UDim2.fromOffset(8, 8),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.ink,
		Thickness = 1,
	}))), React.createElement(Text, {
		value = message.displayName,
		size = 15,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(66, 8),
		sizeConstraint = UDim2.new(1, -(STATUS_RESERVE + 72 + (if message.artifactName ~= nil then ARTIFACT_CHIP_W - 52 else 0)), 0, 18),
		transparency = fade,
	}), message.artifactName ~= nil and React.createElement("frame", {
		Size = UDim2.fromOffset(ARTIFACT_CHIP_W, 20),
		Position = UDim2.new(1, -(78 + ARTIFACT_CHIP_W), 0, 9),
		BackgroundColor3 = darken(message.artifactColor or accent, 0.72),
		BackgroundTransparency = fade:map(function(amount)
			return 0.1 + amount * 0.9
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = message.artifactColor or accent,
		Thickness = 1,
		Transparency = pulse:map(function(amount)
			return 0.25 + amount * 0.35
		end),
	}), message.artifactElement ~= nil and React.createElement(ElementFx, {
		element = message.artifactElement,
		size = UDim2.fromOffset(22, 22),
		position = UDim2.fromOffset(12, 10),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = string.upper(message.artifactName),
		size = 10,
		color = lighten(message.artifactColor or accent, 0.2),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(24, 3),
		sizeConstraint = UDim2.new(1, -30, 0, 14),
		transparency = fade,
	})), if message.titleName ~= nil then React.createElement(AnimatedTitle, {
		text = message.titleName,
		fx = message.titleFx,
		size = 12,
		reducedMotion = reducedMotion,
		inline = true,
		position = UDim2.fromOffset(66, 28),
		sizeConstraint = UDim2.new(1, -(STATUS_RESERVE + 72), 0, 18),
		transparency = fade,
	}) else React.createElement(Text, {
		value = `@{message.username}`,
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(66, 28),
		sizeConstraint = UDim2.new(1, -80, 0, 16),
		transparency = fade,
	}), React.createElement(Badge, {
		value = channelBadge(message),
		accent = if message.titleFx ~= nil then titleFxAccent(message.titleFx) else accent,
		filled = true,
		position = UDim2.new(1, -72, 0, 10),
		size = UDim2.fromOffset(62, 26),
	}), React.createElement(Text, {
		value = ChatRules.clock(message.at),
		size = 11,
		color = Palette.muted,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(1, -72, 0, 38),
		sizeConstraint = UDim2.fromOffset(62, 16),
		transparency = fade,
	}), _param.onWhisper ~= nil and not message.localPlayer and React.createElement("textbutton", {
		-- the author's name opens a private conversation with them
		Name = "WhisperAuthor",
		Size = UDim2.new(1, -(STATUS_RESERVE + 72), 0, 24),
		Position = UDim2.fromOffset(66, 6),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		[React.Event.Activated] = function()
			_param.onWhisper(message.userId)
		end,
	}) or nil, message.titleName ~= nil and React.createElement(Text, {
		value = `@{message.username}`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(66, 46),
		sizeConstraint = UDim2.new(1, -80, 0, 14),
		transparency = fade,
	}), React.createElement(Text, {
		value = message.text,
		size = bodySize + 1,
		color = Palette.cream,
		weight = Enum.FontWeight.Medium,
		wrap = true,
		position = UDim2.fromOffset(66, if message.titleName ~= nil then 62 else 48),
		sizeConstraint = UDim2.new(1, -78, 0, math.max(if message.titleName ~= nil then 26 else 34, cardH - (if message.titleName ~= nil then 70 else 56))),
		transparency = fade,
	})))
end
local function ChatView(_param)
	local chat = _param.chat or EMPTY_CHAT
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local textScale = chat.textScale or 1.075
	local bodySize = math.floor((if chrome.mobile then 15 else 14) * textScale + 0.5)
	local rowHeight = math.floor((if chrome.mobile then 144 else ROW_HEIGHT) * math.max(1, textScale * 0.95) + 0.5)
	local condensed = chrome.landscape or viewport.keyboardOpen or viewport.height < 700
	local showStatus = not condensed
	local showBanner = not condensed and viewport.height >= 760
	local chromeGap = if condensed then 8 else GAP
	local inputHeight = if condensed then 62 else INPUT_HEIGHT
	local draft, setDraft = React.useState("")
	local failure, setFailure = React.useState("")
	local viewHeight, setViewHeight = React.useState(0)
	local searchOpen, setSearchOpen = React.useState(false)
	local logQuery, setLogQuery = React.useState("")
	local input = React.useRef()
	local stickBottom = React.useRef(true)
	local lastMessageId = React.useRef(nil)
	local sendAttempt = React.useRef(0)
	local sentHistory = React.useRef({})
	local recallIndex = React.useRef(0)
	local recallDraft = React.useRef("")
	local chatClaimHostRef = React.useRef(nil)
	local headerReveal = useStagger(0, softMotion)
	local bannerReveal = useStagger(1, softMotion)
	local composerReveal = useStagger(2, softMotion)
	local statusReveal = useStagger(3, softMotion)
	React.useEffect(function()
		return function()
			sendAttempt.current += 1
		end
	end, {})
	local enteredIds = React.useRef({})
	local listFrame = React.useRef(nil)
	local count = #chat.messages
	local latestMessageId = if count > 0 then chat.messages[count].id else nil
	local tab = chat.tab or "all"
	local peer = if tab == "whispers" then chat.peer else nil
	-- searching the log shows only matching lines; the live log keeps scrolling underneath
	local filteringLog = searchOpen and not string.match(logQuery, "^%s*$")
	local shownMessages = chat.messages
	if filteringLog or tab ~= "all" or chat.showGlobal == false then
		shownMessages = {}
		for _, message in chat.messages do
			local channel = message.channel or "server"
			local keep = ChatRules.inTab(channel, tab)
				and not (tab == "all" and channel == "global" and chat.showGlobal == false)
				and (peer == nil or channel == "system" or message.peerId == peer)
			if keep and filteringLog then
				keep = ChatRules.matches({
					text = message.text or "",
					username = message.username or "",
					displayName = message.displayName or "",
					channel = channel,
				}, logQuery)
			end
			if keep then
				table.insert(shownMessages, message)
			end
		end
	end
	local suggestions = if string.match(draft, "^%s*$") then {} else chat.suggest(draft)
	local stackH = math.max(0, #shownMessages) * rowHeight
	local topPad = if viewHeight > 0 then math.max(0, viewHeight - stackH) else 0
	local renderedIds = {}
	do
		local index = 0
		while index < count do
			local message = chat.messages[index + 1]
			if message ~= nil then
				local _current = enteredIds.current
				local _id = message.id
				local animate = not (_current[_id] ~= nil)
				if animate then
					local _current_1 = enteredIds.current
					local _id_1 = message.id
					_current_1[_id_1] = true
				end
				renderedIds[message.id] = animate
			end
			index += 1
		end
	end
	local _size = 0
	for _ in enteredIds.current do
		_size += 1
	end
	if _size > count + 8 then
		local live = {}
		for _, message in chat.messages do
			local _id = message.id
			live[_id] = true
		end
		enteredIds.current = live
	end
	local scrollToBottom = React.useCallback(function(force)
		task.defer(function()
			local frame = listFrame.current
			if not frame then
				return nil
			end
			if force ~= true and not stickBottom.current then
				return nil
			end
			local bottom = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			frame.CanvasPosition = Vector2.new(0, bottom)
			stickBottom.current = true
		end)
	end, { listFrame })
	React.useEffect(function()
		local frame = listFrame.current
		if not frame then
			return nil
		end
		local syncSize = function()
			return setViewHeight(math.max(0, frame.AbsoluteWindowSize.Y))
		end
		syncSize()
		local sizeConn = frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(syncSize)
		local scrollConn = frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local maxY = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			stickBottom.current = frame.CanvasPosition.Y >= maxY - NEAR_BOTTOM
		end)
		return function()
			sizeConn:Disconnect()
			scrollConn:Disconnect()
		end
	end, { listFrame, count, topPad })
	-- reading history: new messages are counted instead of yanking the list, and a button jumps back
	local unseen, setUnseen = React.useState(0)
	React.useEffect(function()
		if latestMessageId ~= lastMessageId.current then
			if lastMessageId.current ~= nil and not stickBottom.current then
				setUnseen(function(n) return math.min(99, n + 1) end)
			end
			scrollToBottom()
		end
		lastMessageId.current = latestMessageId
	end, { latestMessageId, scrollToBottom })
	React.useEffect(function()
		local frame = listFrame.current
		if not frame then return nil end
		local connection = frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local maxY = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			if frame.CanvasPosition.Y >= maxY - NEAR_BOTTOM then setUnseen(0) end
		end)
		return function() connection:Disconnect() end
	end, { listFrame, count })
	React.useEffect(function()
		scrollToBottom(true)
	end, { scrollToBottom })
	local submit = function()
		local box = input.current
		local outgoing = if box ~= nil then box.Text else draft
		if (string.gsub(outgoing, "%s", "")) == "" then
			return nil
		end
		local attempt = sendAttempt.current + 1
		sendAttempt.current = attempt
		ChatRules.remember(sentHistory.current, outgoing)
		recallIndex.current = 0
		setFailure("")
		setDraft("")
		if box ~= nil then
			box.Text = ""
			task.defer(function()
				if input.current == box then
					box:CaptureFocus()
				end
			end)
		end
		stickBottom.current = true
		chat.send(outgoing, function(ok, reason)
			if attempt ~= sendAttempt.current then
				return nil
			end
			if ok then
				setFailure("")
				scrollToBottom(true)
			else
				local restore = input.current
				if restore ~= nil then
					if (string.gsub(restore.Text, "%s", "")) == "" then
						restore.Text = outgoing
						setDraft(outgoing)
					end
				else
					setDraft(function(current)
						return if (string.gsub(current, "%s", "")) == "" then outgoing else current
					end)
				end
				local _condition = reason
				if _condition == nil then
					_condition = "Message not sent."
				end
				setFailure(_condition)
			end
		end)
	end
	-- global and slash commands go through the server, so they don't wait on the TextChannel
	local canSend = (string.gsub(draft, "%s", "")) ~= ""
		and (chat.connected or tab == "global" or string.match(draft, "^%s*/") ~= nil)
	local applySuggestion = function(fill)
		setDraft(fill)
		local box = input.current
		if box ~= nil then
			box.Text = fill
			task.defer(function()
				if input.current == box then
					box:CaptureFocus()
					box.CursorPosition = #fill + 1
				end
			end)
		end
	end
	-- The "/" key asks for the box; wait a frame so the slash itself isn't typed into it.
	React.useEffect(function()
		local requested = chat.focusRequest or 0
		if requested <= 0 or os.clock() - requested > 1 then
			return
		end
		local thread = task.delay(0.05, function()
			local box = input.current
			if box ~= nil and box:IsDescendantOf(game) then
				box:CaptureFocus()
				if box.Text == "/" then
					box.Text = ""
					setDraft("")
				end
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, { chat.focusRequest })
	-- Up / Down in the focused chat box walks back through what you sent; coming back down past
	-- the newest message restores whatever you had been typing.
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(inputObject)
			local box = input.current
			if box == nil or not box:IsFocused() then
				return
			end
			local direction = if inputObject.KeyCode == Enum.KeyCode.Up then 1
				elseif inputObject.KeyCode == Enum.KeyCode.Down then -1
				else 0
			if direction == 0 then
				return
			end
			if recallIndex.current == 0 then
				recallDraft.current = box.Text
			end
			local index, text = ChatRules.recall(sentHistory.current, recallIndex.current, direction)
			if index == recallIndex.current then
				return
			end
			recallIndex.current = index
			local fill = if index == 0 then recallDraft.current else text
			setDraft(fill)
			box.Text = fill
			task.defer(function()
				if input.current == box then
					box.CursorPosition = #fill + 1
				end
			end)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = chatClaimHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { condensed, canSend })
	local statusLabel = if chat.connected then "ONLINE" else "CONNECTING"
	local statusAccent = if chat.connected then Palette.green else Palette.mango
	local placeholder = if failure ~= "" then failure elseif chrome.mobile then (if tab == "global" then "Message global…  (/help)" elseif tab == "server" then "Message server…  (/help)" elseif tab == "crew" then "Message crew…  (/help)" elseif tab == "friends" then "Message friends…  (/help)" elseif tab == "whispers" then "Private message…  (/help)" else "Message…  (/help)") else (chat.placeholder or "Say something... (/help)")
	local statusElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.5,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(14, 11),
		BackgroundColor3 = darken(Palette.cyan, 0.72),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.cyan, 0.15), darken(Palette.cyan, 0.45)),
		Rotation = 120,
	}), React.createElement(Icon, {
		kind = "Chat.3",
		color = Palette.ink,
		accent = Palette.cyan,
		size = 26,
		position = UDim2.fromOffset(8, 8),
		spin = false,
		reducedMotion = softMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -(STATUS_RESERVE + 68 + 52), 0, 48),
		Position = UDim2.fromOffset(68, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = "Chat",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 24),
		transparency = headerReveal:map(function(amount)
			return 1 - amount
		end),
	}), React.createElement(Text, {
		value = if filteringLog then `{#shownMessages} of {count} match` else `{count} log{if count == 1 then "" else "s"}  ·  Roblox-filtered`,
		size = 13,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
		transparency = (if showBanner then bannerReveal else statusReveal):map(function(amount)
			return 1 - amount
		end),
	})), React.createElement(Button, {
		text = "",
		icon = if searchOpen then "Close.5" else "Search.7",
		onClick = function()
			if searchOpen then
				setLogQuery("")
			end
			setSearchOpen(not searchOpen)
		end,
		color = if searchOpen then Palette.cyan else Palette.panelSoft,
		textColor = if searchOpen then Palette.ink else Palette.cream,
		size = UDim2.fromOffset(44, 44),
		position = UDim2.new(1, -(STATUS_RESERVE + 48), 0.5, -22),
		reducedMotion = softMotion,
	}), React.createElement(Badge, {
		value = statusLabel,
		accent = statusAccent,
		filled = true,
		position = UDim2.new(1, -(STATUS_RESERVE - 4), 0.5, -13),
		size = UDim2.fromOffset(STATUS_RESERVE - 16, 26),
	}))
	local composerSoft = reducedMotion or composerReveal == nil
	local _chatSoftKeep = if composerSoft then bannerReveal else statusReveal
	local messagesElement = React.createElement(FlatList, {
		data = shownMessages,
		itemHeight = rowHeight,
		headerHeight = topPad,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 0,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		scrollBarTransparency = 0.12,
		ZIndex = 10,
		frameRef = listFrame,
		keyExtractor = function(message)
			return message.id
		end,
		renderItem = function(_param_1)
			local message = _param_1.item
			local animate = renderedIds[message.id] == true
			return React.createElement(MessageRow, {
				message = message,
				reducedMotion = softMotion,
				bodySize = bodySize,
				animate = animate,
				rowHeight = rowHeight,
				onWhisper = if not message.system and chat.openWhisper ~= nil and not message.remote then function(userId)
					chat.openWhisper(userId)
				end else nil,
			})
		end,
	})
	if unseen > 0 then
		messagesElement = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		}, messagesElement, React.createElement(Button, {
			text = `{unseen} new message{if unseen == 1 then "" else "s"}`, icon = "Chat.4",
			color = Palette.cyan, textColor = Palette.ink, hug = true, reducedMotion = softMotion,
			size = UDim2.fromOffset(0, 40), position = UDim2.new(0.5, -90, 1, -52), zIndex = 30,
			onClick = function()
				setUnseen(0)
				scrollToBottom(true)
			end,
		}))
	end
	local bannerElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.cardRadius),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = 0.32,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement(Icon, {
		kind = "Forge.18",
		color = Palette.ink,
		accent = Palette.mango,
		size = 24,
		position = UDim2.fromOffset(14, 14),
		spin = false,
				reducedMotion = softMotion,
	}), React.createElement(Text, {
		value = "KEEP IT CLEAN",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(48, 8),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
	}), React.createElement(Text, {
		value = "Roblox filters messages. Type /help for shortcuts.",
		size = 13,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(48, 28),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
	}))
	local inputElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if failure ~= "" then Palette.coral else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.45,
	}), React.createElement("textbox", {
		ref = input,
		Size = UDim2.new(1, -148, 1, -14),
		Position = UDim2.fromOffset(14, 7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = draft,
		PlaceholderText = placeholder,
		PlaceholderColor3 = if failure ~= "" then Palette.coral else Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextScaled = false,
		MultiLine = false,
		TextEditable = true,
		MaxVisibleGraphemes = DRAFT_LIMIT,
		Change = {
			Text = function(box)
				return setDraft(ChatText.limit(box.Text, DRAFT_LIMIT))
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
			FocusLost = function(_box, enterPressed)
				if enterPressed then
					submit()
				end
			end,
		},
	}), React.createElement("frame", {
		Name = "ChatClaimActions",
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = chatClaimHostRef,
	}, React.createElement(Button, {
		text = "SEND",
		icon = "Send.4",
		onClick = submit,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, 48),
		hug = true,
		disabled = not canSend,
		reducedMotion = reducedMotion,
		highlight = canSend,
	})))
	local sections = {}
	if showStatus then
		table.insert(sections, {
			id = "status",
			height = STATUS_HEIGHT,
			element = statusElement,
		})
	end
	if showStatus and searchOpen then
		table.insert(sections, {
			id = "search",
			height = 44,
			element = React.createElement(SearchField, {
				value = logQuery,
				onChange = setLogQuery,
				placeholder = "Search words, from:name or in:global",
				accent = Palette.cyan,
				reducedMotion = softMotion,
				size = UDim2.fromScale(1, 1),
				zIndex = 22,
			}),
		})
	end
	local unreadByTab = chat.unreadByTab or {}
	local tabOptions = {}
	for _, def in TAB_DEFS do
		local waiting = unreadByTab[def.id] or 0
		table.insert(tabOptions, { id = def.id, label = if waiting > 0 then `{def.label} {waiting}` else def.label })
	end
	local tabColumns = if viewport.compact then 3 else #TAB_DEFS
	local tabRows = math.ceil(#TAB_DEFS / tabColumns)
	table.insert(sections, {
		id = "tabs",
		height = tabRows * TAB_ROW_H + (tabRows - 1) * 6,
		element = React.createElement(SegmentedTabs, {
			options = tabOptions,
			value = tab,
			onChange = chat.setTab,
			accent = Palette.cyan,
			columns = tabColumns,
			gap = 6,
			size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
		}),
	})
	if tab == "whispers" and #chat.whispers > 0 then
		local peerChips = {}
		for _, entry in chat.whispers do
			local selected = entry.userId == chat.peer
			local label = entry.displayName
			if entry.unread > 0 then
				label = `{label} ({entry.unread})`
			end
			if entry.online == false then
				label ..= " · away"
			end
			table.insert(peerChips, { key = `peer-{entry.userId}`, element = React.createElement(Button, {
				text = label,
				onClick = function()
					chat.setPeer(entry.userId)
				end,
				color = if selected then Palette.violet else Palette.panelSoft,
				textColor = if selected then Palette.ink else Palette.cream,
				size = UDim2.fromOffset(0, PEER_ROW_H - 4),
				hug = true,
				reducedMotion = softMotion,
			}) })
		end
		table.insert(sections, {
			id = "peers",
			height = PEER_ROW_H,
			element = chipRail(peerChips, nil),
		})
	end
	table.insert(sections, {
		id = "messages",
		fill = true,
		minHeight = 120,
		element = if not filteringLog and #shownMessages == 0 then React.createElement(Text, {
			value = if tab == "whispers" then "No whispers yet. Type /w name message to start one."
				elseif tab == "friends" then "Nothing from friends in this server yet."
				elseif tab == "crew" then "Crew chat is private to your crew. Start one on the Crew page."
				elseif tab == "global" then "Global chat is quiet. Say hello to every server."
				else "No messages yet.",
			size = 14,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, 0, 0, 40),
			position = UDim2.fromOffset(0, 20),
		}) elseif filteringLog and #shownMessages == 0 then React.createElement(Text, {
			value = `No messages match "{logQuery}".`,
			size = 14,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, 0, 0, 40),
			position = UDim2.fromOffset(0, 20),
		}) else messagesElement,
	})
	if showBanner then
		table.insert(sections, {
			id = "banner",
			height = BANNER_HEIGHT,
			element = bannerElement,
		})
	end
	if #suggestions > 0 then
		local suggestChips = {}
		for order, suggestion in suggestions do
			table.insert(suggestChips, { key = `suggest-{order}`, element = React.createElement(Button, {
				text = if suggestion.kind == "command" then suggestion.label else `{suggestion.label}  {suggestion.detail}`,
				onClick = function()
					applySuggestion(suggestion.fill)
				end,
				color = if order == 1 then Palette.cyan else Palette.panelSoft,
				textColor = if order == 1 then Palette.ink else Palette.cream,
				size = UDim2.fromOffset(0, SUGGEST_ROW_H - 4),
				hug = true,
				reducedMotion = softMotion,
			}) })
		end
		table.insert(sections, {
			id = "suggest",
			height = SUGGEST_ROW_H,
			element = chipRail(suggestChips, 24),
		})
	end
	table.insert(sections, {
		id = "input",
		height = inputHeight,
		element = inputElement,
	})
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.cardRadius),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement(PageScaffold, {
		gap = chromeGap,
		inset = SIDE_INSET,
		tailPad = chromeGap,
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 0,
		sections = sections,
	}))
end
return {
	ChatView = ChatView,
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
