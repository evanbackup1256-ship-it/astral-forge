-- The Foundry: spend the ore mined in the sanctuary on lasting upgrades.
--
-- Balances come from state.Ore (OreMath.PublicState on the server): the three
-- ores and every upgrade with its level, bonus, next bonus and cost. Buying
-- sends BuyOreUpgrade; the server checks the cost and the level cap.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _ui = require(script.Parent.Parent.ui)
local Panel = _ui.Panel
local Button = _ui.Button
local Text = _ui.Text
local Meter = _ui.Meter
local IconTile = _ui.IconTile
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local compactNumber = require(script.Parent.Parent.format).compactNumber
local SanctuaryConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SanctuaryConfig"))

local ACCENT = Color3.fromRGB(255, 150, 84)
local ROW_H = 112
local ROW_H_STACK = 176
local BUY_W = 150

local EFFECT_NOUNS = {
	Production = "production",
	Capacity = "vault capacity",
	Tap = "overcharge tap power",
	BossDamage = "damage to the Rift Warden",
	OreYield = "ore from every outcrop",
}

local REGION_NAMES = {
	Emberreach = "Emberreach",
	Hollows = "Voidglass Hollows",
	Spire = "Starsteel Spire",
}

local ORE_INFO = {}
for index, ore in SanctuaryConfig.Ore.Types do
	ORE_INFO[ore.Id] = {
		order = index,
		name = ore.Name,
		color = Color3.fromRGB(ore.Color[1], ore.Color[2], ore.Color[3]),
		region = REGION_NAMES[ore.Region] or ore.Region,
	}
end

local function percent(value: number): string
	local scaled = value * 100
	if math.abs(scaled - math.floor(scaled + 0.5)) < 0.05 then
		return `+{math.floor(scaled + 0.5)}%`
	end
	return string.format("+%.1f%%", scaled)
end

-- A small gem in the ore's colour, for balances and cost chips.
local function Gem(props)
	return React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position,
		Size = UDim2.fromOffset(props.size, props.size),
		Rotation = 45,
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 3,
	})
end

local function OreBalance(props)
	local info = ORE_INFO[props.id]
	return React.createElement("frame", {
		Size = props.size,
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = info.order,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = info.color,
		Transparency = 0.72,
		Thickness = 1,
	}), React.createElement(Gem, {
		position = UDim2.fromOffset(18, 20),
		size = 10,
		color = info.color,
	}), React.createElement(Text, {
		value = compactNumber(props.amount),
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(32, 8),
		sizeConstraint = UDim2.new(1, -40, 0, 24),
	}), React.createElement(Text, {
		value = info.name,
		size = 11,
		color = info.color,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(12, 36),
		sizeConstraint = UDim2.new(1, -20, 0, 14),
	}), React.createElement(Text, {
		value = `Mined in {info.region}`,
		size = 10,
		color = Palette.muted,
		position = UDim2.fromOffset(12, 52),
		sizeConstraint = UDim2.new(1, -20, 0, 14),
	}))
end

local function CostChips(props)
	local chips = {
		Layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for oreId, amount in props.cost do
		local info = ORE_INFO[oreId]
		if info == nil then
			continue
		end
		local have = tonumber(props.balances[oreId]) or 0
		local short = have < amount
		-- UIListLayout + fixed gem tile — never AbsolutePosition + AutomaticSize
		-- (Scale/AABB feedback can inflate cost chips under scroll rows).
		chips[oreId] = React.createElement("frame", {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = info.order,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}), React.createElement("frame", {
			Size = UDim2.fromOffset(10, 20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, React.createElement(Gem, {
			position = UDim2.fromOffset(5, 10),
			size = 8,
			color = info.color,
		})), React.createElement("textlabel", {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Text = `{compactNumber(amount)} {info.name}`,
			TextColor3 = if short then Palette.coral else Palette.creamSoft,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment = Enum.TextXAlignment.Left,
		}))
	end
	return React.createElement("frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, chips)
end

local function UpgradeRow(props)
	local upgrade = props.upgrade
	local stack = props.stack
	local reducedMotion = props.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — UpgradeRow.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local reveal = useStagger(props.index, softMotion, 0.02, 0.14)
	local maxed = upgrade.Maxed == true
	local ready = upgrade.Affordable == true and not maxed
	local noun = EFFECT_NOUNS[upgrade.Effect] or string.lower(upgrade.Effect)
	local levelText = `Level {upgrade.Level} of {upgrade.MaxLevel}`
	local bonusText = if maxed
		then `{percent(upgrade.Bonus)} {noun} · complete`
		else `{percent(upgrade.Bonus)} → {percent(upgrade.NextBonus)} {noun}`
	local textW = if stack then 0 else -(BUY_W + 16)
	local buttonText = if maxed then "MAXED" elseif ready then "FORGE" else "NEED ORE"
	local buy = React.createElement(Button, {
		text = buttonText,
		icon = if maxed then "Check" else "Forge",
		onClick = function()
			if ready then
				props.onBuy(upgrade.Id)
			end
		end,
		color = if ready then ACCENT else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not ready,
		highlight = ready,
	})
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, if stack then ROW_H_STACK else ROW_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.index,
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = if ready then ACCENT else Palette.lineSoft,
		background = Palette.panel,
		padding = 14,
		reveal = reveal,
		highlight = ready,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = upgrade.Name,
		size = 16,
		color = if maxed then Palette.creamSoft else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, textW - 110, 0, 22),
	}), React.createElement(Text, {
		value = levelText,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, textW - 110, 0, 2),
		sizeConstraint = UDim2.new(0, 110, 0, 18),
	}), React.createElement(Text, {
		value = upgrade.Description,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, textW, 0, 18),
	}), React.createElement(Meter, {
		value = upgrade.Level / math.max(1, upgrade.MaxLevel),
		color = if maxed then Palette.mint else ACCENT,
		reducedMotion = softMotion,
		shimmer = ready,
		position = UDim2.fromOffset(0, 48),
		size = UDim2.new(1, textW, 0, 5),
	}), React.createElement(Text, {
		value = bonusText,
		size = 12,
		color = if maxed then Palette.mint else Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, 58),
		sizeConstraint = UDim2.new(1, textW, 0, 18),
	}), not maxed and React.createElement(CostChips, {
		cost = upgrade.Cost,
		balances = props.balances,
		position = UDim2.fromOffset(0, 78),
		size = UDim2.new(1, textW, 0, 20),
	}), React.createElement("frame", {
		Name = "FoundryClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(BUY_W, TapTarget),
		Position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -BUY_W, 0.5, -TapTarget / 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = props.claimRef,
	}, buy)))
end

local function FoundryViewComponent(_param)
	local state, dispatch, reducedMotion = _param.state, _param.dispatch, _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local ore = if type(state.Ore) == "table" then state.Ore else {}
	local balances = if type(ore.Balances) == "table" then ore.Balances else {}
	local upgrades = if type(ore.Upgrades) == "table" then ore.Upgrades else {}
	local headerReveal = useStagger(0, softMotion)
	local claimRef = React.useRef(nil)

	local total = 0
	for _, amount in balances do
		total += tonumber(amount) or 0
	end
	local firstReady = nil
	for index, upgrade in upgrades do
		if upgrade.Affordable == true and upgrade.Maxed ~= true then
			firstReady = index
			break
		end
	end

	-- Gamepad: park Selection on the first upgrade that can be forged.
	React.useEffect(function()
		if firstReady == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimRef.current
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
	end, { firstReady })

	local onBuy = function(id)
		return dispatch("BuyOreUpgrade", { Id = id })
	end
	local gap = if stack then chrome.panelGap else Layout.panelGap
	local rowH = if stack then ROW_H_STACK else ROW_H
	local oreTileH = 72
	local oreRow = if stack then oreTileH * 3 + 16 else oreTileH
	local heroH = (if stack then 96 else 86) + oreRow + 16

	local oreTiles = {
		Layout = React.createElement("uilistlayout", {
			FillDirection = if stack then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, oreType in SanctuaryConfig.Ore.Types do
		oreTiles[oreType.Id] = React.createElement(OreBalance, {
			id = oreType.Id,
			amount = tonumber(balances[oreType.Id]) or 0,
			size = if stack then UDim2.new(1, 0, 0, oreTileH) else UDim2.new(1 / 3, -6, 0, oreTileH),
		})
	end

	local rows = {
		Layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, upgrade in upgrades do
		rows[upgrade.Id] = React.createElement(UpgradeRow, {
			upgrade = upgrade,
			balances = balances,
			index = index,
			stack = stack,
			reducedMotion = reducedMotion,
			onBuy = onBuy,
			claimRef = if index == firstReady then claimRef else nil,
		})
	end
	local listH = #upgrades * rowH + math.max(0, #upgrades - 1) * gap

	local sections = {
		{
			id = "hero",
			height = heroH,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = ACCENT,
				background = Palette.panelRaised,
				padding = if stack then 14 else 16,
				reveal = headerReveal,
				clips = false,
			}, React.createElement(IconTile, {
				kind = "Artifact",
				accent = ACCENT,
				size = 44,
				radius = 12,
				spin = false,
				reducedMotion = softMotion,
			}), React.createElement(Text, {
				value = "FOUNDRY",
				size = 10,
				color = ACCENT,
				weight = Enum.FontWeight.Heavy,
				position = UDim2.fromOffset(58, 2),
				sizeConstraint = UDim2.new(1, -58, 0, 14),
			}), React.createElement(Text, {
				value = "Turn sanctuary ore into lasting upgrades",
				size = if stack then 16 else 19,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				wrap = true,
				position = UDim2.fromOffset(58, 18),
				sizeConstraint = UDim2.new(1, -58, 0, if stack then 40 else 24),
			}), React.createElement(Text, {
				value = if total > 0
					then "Upgrades here stay through rebirth."
					else "Enter the sanctuary and hold E at a glowing outcrop to mine your first ore.",
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				position = UDim2.fromOffset(58, if stack then 60 else 46),
				sizeConstraint = UDim2.new(1, -58, 0, 30),
			}), React.createElement("frame", {
				Position = UDim2.new(0, 0, 1, -oreRow),
				Size = UDim2.new(1, 0, 0, oreRow),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, oreTiles)),
		},
		{
			id = "upgrades",
			height = math.max(rowH, listH),
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, rows),
		},
	}
	return React.createElement(PageScaffold, {
		gap = gap,
		tailPad = scrollTail(stack, chrome.bottomSafe, 48),
		scrollBarColor = ACCENT,
		scrollBarThickness = 4,
		sections = sections,
	})
end

local FoundryView = React.memo(FoundryViewComponent, function(previous, incoming)
	return previous.dispatch == incoming.dispatch
		and previous.reducedMotion == incoming.reducedMotion
		and previous.state.Ore == incoming.state.Ore
end)

return { FoundryView = FoundryView }
