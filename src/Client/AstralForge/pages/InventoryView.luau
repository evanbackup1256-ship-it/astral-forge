local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local Audio = require(script.Parent.Parent.audio).Audio
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local itemIconKind = require(script.Parent.Parent.Icon).itemIconKind
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local _motion = require(script.Parent.Parent.motion)
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local contrastOn = _theme.contrastOn
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local InventoryMath = require(script.Parent.Parent.inventoryMath)
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local SCROLL_EDGE = _ui.SCROLL_EDGE
local ScrollPads = _ui.ScrollPads
local SearchField = _ui.SearchField
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
-- Relic bay virtualizes through FlatList so InventoryLimit (~100) rows never all mount at once.
-- Panel entrance springs are still skipped via a shared static reveal binding — virtualization cuts
-- the mount count, the binding keeps any visible row from spinning up a per-instance flipper.
-- Inspect stays in its own PageScaffold section so row height stays fixed for the window.
local RELIC_ROW_SHOWN = React.createBinding(1)
local TABS = { "Relics", "Crates", "Market", "Loadout" }
-- ▼ ReadonlyArray.map ▼
local _newValue = table.create(#TABS)
local _callback = function(id)
	return {
		id = id,
		label = string.upper(id),
	}
end
for _k, _v in TABS do
	_newValue[_k] = _callback(_v, _k - 1, TABS)
end
-- ▲ ReadonlyArray.map ▲
local TAB_OPTIONS = _newValue
local FILTERS = { {
	id = "All",
	label = "All relics",
}, {
	id = "Machine",
	label = "Machine slot",
}, {
	id = "Research",
	label = "Research slot",
}, {
	id = "Equipped",
	label = "Equipped only",
}, {
	id = "Unequipped",
	label = "Unequipped only",
}, {
	id = "Protected",
	label = "Protected only",
} }
local SORTS = { {
	id = "Rarity",
	label = "Rarity first",
}, {
	id = "Power",
	label = "Highest power",
}, {
	id = "Level",
	label = "Highest level",
}, {
	id = "Newest",
	label = "Newest first",
}, {
	id = "Name",
	label = "Name A-Z",
} }
local RARITY_FILTERS = { {
	id = "Any",
	label = "Any rarity",
}, {
	id = "Common",
	label = "Common",
}, {
	id = "Uncommon",
	label = "Uncommon",
}, {
	id = "Rare",
	label = "Rare",
}, {
	id = "Epic",
	label = "Epic",
}, {
	id = "Legendary",
	label = "Legendary",
}, {
	id = "Mythic",
	label = "Mythic",
} }
local AUTO_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local HERO_H = 96
local HERO_H_STACK = 124
local ROW_H = 112
local ROW_H_STACK = 132
local ROW_GAP = 10
local SCROLL_PAD = 24 + 16
local TOOL_FIELD_DESK = 50
local STATS_H = 36
local BULK_DOCK_H = 58
local function relicRowHeight(stack)
	return InventoryMath.RelicRowHeight(stack)
end
local function rarityColor(config, rarity)
	return InventoryMath.RarityColor(config, rarity, Palette.muted)
end
local function rarityRank(config, rarity)
	return InventoryMath.RarityRank(config, rarity)
end
local function effectAtLevel(definition, level)
	return InventoryMath.EffectAtLevel(definition, level)
end
local function effectLabel(definition, level)
	return InventoryMath.EffectLabel(definition, level)
end
local function upgradeCost(definition, level)
	return InventoryMath.UpgradeCost(definition, level)
end
local function salvagePreview(config, definition, level)
	return InventoryMath.SalvagePreview(config, definition, level)
end
local function socketLabel(target)
	return InventoryMath.SocketLabel(target)
end
local function collectOwned(state, config)
	return InventoryMath.CollectOwned(state, config)
end
local function sortOwned(list, config, sort)
	return InventoryMath.SortOwned(list, config, sort)
end
local function filterOwned(list, filter)
	return InventoryMath.FilterOwned(list, filter)
end
local function searchOwned(list, query, rarity)
	return InventoryMath.SearchOwned(list, query, rarity)
end
local function socketTargets(state, config, definition)
	return InventoryMath.SocketTargets(state, config, definition)
end
local function ChipRow(_param)
	local options = _param.options
	local value = _param.value
	local onChange = _param.onChange
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local chrome = chromeFor(useViewport())
	local rowH = if chrome.mobile then TapTarget else 48
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#options)
	local _callback_1 = function(option, index)
		local active = option.id == value
		return React.createElement("frame", {
			key = option.id,
			Size = UDim2.fromOffset(0, rowH),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, React.createElement(Button, {
			text = option.label,
			onClick = function()
				return onChange(option.id)
			end,
			sound = "filterPick",
			color = if active then accent else Palette.panelSoft,
			textColor = if active then nil else Palette.creamSoft,
			size = UDim2.fromOffset(0, rowH),
			hug = true,
			reducedMotion = reducedMotion,
			highlight = active,
			outline = not active,
		}))
	end
	for _k, _v in options do
		_newValue_1[_k] = _callback_1(_v, _k - 1, options)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if chrome.mobile then TapTarget else 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp, _newValue_1)
end
local function autoSalvageSignature(rules)
	return InventoryMath.AutoSalvageSignature(rules, AUTO_RARITIES)
end
local function InventoryTools(_param)
	local search = _param.search
	local setSearch = _param.setSearch
	local filter = _param.filter
	local setFilter = _param.setFilter
	local rarity = _param.rarity
	local setRarity = _param.setRarity
	local sort = _param.sort
	local setSort = _param.setSort
	local bulkMode = _param.bulkMode
	local setBulkMode = _param.setBulkMode
	local autoOpen = _param.autoOpen
	local setAutoOpen = _param.setAutoOpen
	local equipBest = _param.equipBest
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local filled = _param.filled
	local limit = _param.limit
	local essence = _param.essence
	local fieldH = if stack then math.max(TapTarget, 52) else TOOL_FIELD_DESK
	local gap = if stack then 8 else 10
	local pad = if stack then 8 else 12
	local filterOptions = FILTERS
	local rarityOptions = RARITY_FILTERS
	local sortOptions = SORTS
	local bagW = if stack then 100 else 104
	local essW = if stack then 112 else 116
	local metaW = bagW + essW + gap
	local filterH = if stack then fieldH * 2 + gap else fieldH
	local actionW = UDim2.new(1 / 3, -math.ceil((gap * 2) / 3), 0, fieldH)
	local accent = if bulkMode then Palette.coral elseif autoOpen then Palette.mango else Palette.violet
	local bagBadge = React.createElement(Badge, {
		value = `{filled} / {limit} BAG`,
		accent = Palette.violet,
		filled = true,
		size = UDim2.fromOffset(bagW, 26),
	})
	local essBadge = React.createElement(Badge, {
		value = `{compactNumber(essence)} ESS`,
		accent = Palette.mango,
		size = UDim2.fromOffset(essW, 26),
	})
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.28,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, pad),
		PaddingBottom = UDim.new(0, pad),
		PaddingLeft = UDim.new(0, pad + 2),
		PaddingRight = UDim.new(0, pad + 2),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	}), stack and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), bagBadge, essBadge), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, filterH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, if stack then React.createElement(React.Fragment, nil, React.createElement(SearchField, {
		value = search,
		onChange = setSearch,
		placeholder = "Search relics, effects, or ID",
		accent = Palette.violet,
		size = UDim2.new(1, 0, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 62,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = Palette.violet,
		position = UDim2.fromOffset(0, fieldH + gap),
		size = UDim2.new(1 / 3, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 61,
	}), React.createElement(Dropdown, {
		options = rarityOptions,
		value = rarity,
		onChange = setRarity,
		accent = Palette.mango,
		position = UDim2.new(1 / 3, 2, 0, fieldH + gap),
		size = UDim2.new(1 / 3, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 60,
	}), React.createElement(Dropdown, {
		options = sortOptions,
		value = sort,
		onChange = setSort,
		accent = Palette.cyan,
		position = UDim2.new(2 / 3, 4, 0, fieldH + gap),
		size = UDim2.new(1 / 3, -4, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 59,
	})) else React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.fromOffset(metaW, fieldH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), bagBadge, essBadge), React.createElement("frame", {
		Size = UDim2.new(1, -(metaW + gap), 0, fieldH),
		Position = UDim2.fromOffset(metaW + gap, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(SearchField, {
		value = search,
		onChange = setSearch,
		placeholder = "Search relics, effects, or ID",
		accent = Palette.violet,
		size = UDim2.new(0.4, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 62,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = Palette.violet,
		position = UDim2.new(0.4, 0, 0, 0),
		size = UDim2.new(0.2, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 61,
	}), React.createElement(Dropdown, {
		options = rarityOptions,
		value = rarity,
		onChange = setRarity,
		accent = Palette.mango,
		position = UDim2.new(0.6, 0, 0, 0),
		size = UDim2.new(0.2, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 60,
	}), React.createElement(Dropdown, {
		options = sortOptions,
		value = sort,
		onChange = setSort,
		accent = Palette.cyan,
		position = UDim2.new(0.8, 0, 0, 0),
		size = UDim2.new(0.2, 0, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 59,
	})))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, fieldH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if stack then "BEST" else "EQUIP BEST",
		icon = "Loadout",
		onClick = equipBest,
		color = Palette.mint,
		textColor = Palette.ink,
		size = actionW,
		reducedMotion = reducedMotion,
		highlight = true,
	}), React.createElement(Button, {
		text = if bulkMode then "DONE" elseif stack then "SELECT" else "MULTI SALVAGE",
		icon = if bulkMode then "Check" else "Dust",
		onClick = function()
			setBulkMode(not bulkMode)
			setAutoOpen(false)
		end,
		color = if bulkMode then Palette.coral else Palette.panelSoft,
		textColor = if bulkMode then Palette.ink else Palette.creamSoft,
		size = actionW,
		reducedMotion = reducedMotion,
		outline = not bulkMode,
	}), React.createElement(Button, {
		text = if stack then "RECYCLE" else "AUTO-SALVAGE",
		icon = "Inventory",
		onClick = function()
			setAutoOpen(not autoOpen)
			setBulkMode(false)
		end,
		color = if autoOpen then Palette.mango else Palette.panelSoft,
		textColor = if autoOpen then Palette.ink else Palette.creamSoft,
		size = actionW,
		reducedMotion = reducedMotion,
		outline = not autoOpen,
	})))
end
local function BulkDock(_param)
	local selectedCount = _param.selectedCount
	local selectableCount = _param.selectableCount
	local selectionEssence = _param.selectionEssence
	local selectVisible = _param.selectVisible
	local clearSelection = _param.clearSelection
	local salvageSelected = _param.salvageSelected
	local bulkBusy = _param.bulkBusy
	local reducedMotion = _param.reducedMotion
	-- Sized by the parent PageScaffold section — do not absolute-anchor to the viewport
	-- bottom (that class of layout collapses the list height on short screens).
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 30,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.coral,
		Thickness = 1.5,
		Transparency = 0.28,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Button, {
		text = if selectableCount > 0 then `SELECT {math.min(25, selectableCount)}` else "NONE TO PICK",
		icon = "Check",
		onClick = selectVisible,
		color = Palette.violet,
		textColor = Palette.cream,
		size = UDim2.new(0.42, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = selectableCount == 0,
		outline = true,
	}), React.createElement(Button, {
		text = if bulkBusy then "SALVAGING" elseif selectedCount > 0 then `DELETE {selectedCount}  +{compactNumber(selectionEssence)} ESS` else "CLEAR PICKS",
		icon = "Dust",
		onClick = if selectedCount > 0 then salvageSelected else clearSelection,
		color = if selectedCount > 0 then Palette.coral else Palette.panelSoft,
		textColor = if selectedCount > 0 then Palette.ink else Palette.muted,
		size = UDim2.new(0.58, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = bulkBusy,
		highlight = selectedCount > 0,
	}))
end
local function AutoSalvageSheet(_param)
	local passOwned = _param.passOwned
	local rules = _param.rules
	local updateRules = _param.updateRules
	local autoBusy = _param.autoBusy
	local openShop = _param.openShop
	local runNow = _param.runNow
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local config = _param.config
	local onClose = _param.onClose
	local sheetHostRef = React.useRef(nil)
	local fieldH = if stack then math.max(TapTarget, 52) else TOOL_FIELD_DESK
	local rarityH = if stack then TapTarget else 36
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = sheetHostRef.current
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
	end, { passOwned, autoBusy })
	local toggleAutoRarity = function(entry)
		if entry == "Any" then
			return nil
		end
		local updated = {}
		for key, value in pairs(rules.Rarities) do
			updated[key] = value
		end
		if rules.Rarities[entry] == true then
			local _entry = entry
			updated[_entry] = nil
		else
			local _entry = entry
			updated[_entry] = true
		end
		local packed = {}
		-- ▼ ReadonlyMap.forEach ▼
		local _callback_1 = function(value, key)
			packed[key] = value
		end
		for _k, _v in updated do
			_callback_1(_v, _k, updated)
		end
		-- ▲ ReadonlyMap.forEach ▲
		local _object = table.clone(rules)
		setmetatable(_object, nil)
		_object.Rarities = packed
		updateRules(_object)
	end
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if passOwned then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.4,
	})
	local _exp_2 = React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})
	local _exp_3 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, React.createElement(Text, {
		value = "AUTO-SALVAGE",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -44, 1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -28, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = onClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})))
	local _result
	if not passOwned then
		_result = React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = "Pick rarities once. Later crate drops of those rarities turn into essence.",
			size = 11,
			color = Palette.creamSoft,
			wrap = true,
			layoutOrder = 1,
			sizeConstraint = UDim2.new(1, 0, 0, if stack then 32 else 18),
		}), React.createElement(Button, {
			text = "VIEW PASS",
			icon = "Shop",
			onClick = openShop,
			color = Palette.mango,
			textColor = Palette.ink,
			size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(132, TapTarget),
			reducedMotion = reducedMotion,
			highlight = true,
		}))
	else
		local _exp_5 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, fieldH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement(Button, {
			text = if autoBusy then "SAVING" elseif rules.Enabled then "ON" else "OFF",
			icon = if rules.Enabled then "Check" else "Inventory",
			onClick = function()
				local _object = table.clone(rules)
				setmetatable(_object, nil)
				_object.Enabled = not rules.Enabled
				return updateRules(_object)
			end,
			color = if rules.Enabled then Palette.mint else Palette.panelSoft,
			textColor = if rules.Enabled then Palette.ink else Palette.creamSoft,
			size = UDim2.new(0.28, -6, 0, fieldH),
			reducedMotion = reducedMotion,
			disabled = autoBusy,
			outline = not rules.Enabled,
		}), React.createElement(Button, {
			text = if rules.KeepNew then "KEEP NEW" else "RECYCLE NEW",
			icon = if rules.KeepNew then "Lock" else "Dust",
			onClick = function()
				local _object = table.clone(rules)
				setmetatable(_object, nil)
				_object.KeepNew = not rules.KeepNew
				return updateRules(_object)
			end,
			color = if rules.KeepNew then Palette.violet else Palette.coral,
			textColor = if rules.KeepNew then Palette.cream else Palette.ink,
			size = UDim2.new(0.44, -6, 0, fieldH),
			reducedMotion = reducedMotion,
			disabled = autoBusy,
			outline = true,
		}), React.createElement(Button, {
			text = "RUN",
			icon = "Dust",
			onClick = runNow,
			color = Palette.mango,
			textColor = Palette.ink,
			size = UDim2.new(0.28, -6, 0, fieldH),
			reducedMotion = reducedMotion,
			disabled = autoBusy or not rules.Enabled,
			highlight = rules.Enabled,
		}))
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#AUTO_RARITIES)
		local _callback_1 = function(entry, index)
			local active = rules.Rarities[entry] == true
			local cols = if stack then 3 else 6
			local col = index % cols
			local row = math.floor(index / cols)
			local label = if stack and entry == "Legendary" then "LEGEND" else string.upper(entry)
			return React.createElement(Button, {
				key = entry,
				text = label,
				onClick = function()
					return toggleAutoRarity(entry)
				end,
				color = if active then rarityColor(config, entry) else Palette.panelSoft,
				textColor = if active then Palette.ink else Palette.muted,
				position = UDim2.new(col / cols, if col == 0 then 0 else 4, 0, row * (rarityH + 8)),
				size = UDim2.new(1 / cols, -6, 0, rarityH),
				reducedMotion = reducedMotion,
				disabled = autoBusy,
				outline = not active,
			})
		end
		for _k, _v in AUTO_RARITIES do
			_newValue_1[_k] = _callback_1(_v, _k - 1, AUTO_RARITIES)
		end
		-- ▲ ReadonlyArray.map ▲
		_result = React.createElement(React.Fragment, nil, _exp_5, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, if stack then rarityH * 2 + 8 else rarityH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			ClipsDescendants = false,
		}, _newValue_1))
	end
	return React.createElement("frame", {
		ref = sheetHostRef,
		Name = "AutoSalvageSheet",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 40,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Name = "AutoSalvageClaim",
		Size = UDim2.new(1, -8, 0, 0),
		Position = UDim2.fromOffset(4, 6),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 41,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _result))
end
local function RelicRow(_param)
	local item = _param.item
	local config = _param.config
	local selected = _param.selected
	local bulkSelected = _param.bulkSelected
	local bulkMode = _param.bulkMode
	local onSelect = _param.onSelect
	local reducedMotion = _param.reducedMotion
	local y = _param.y
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local stack = _param.stack
	if stack == nil then
		stack = false
	end
	local accent = rarityColor(config, item.definition.Rarity)
	local textW = if stack then -(58 + 8) else -176
	local locked = item.instance.Locked == true
	local height = relicRowHeight(stack)
	return React.createElement("imagebutton", {
		Size = UDim2.new(1, 0, 0, height),
		Position = if y ~= nil then UDim2.fromOffset(0, y) else nil,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play("tick")
				onSelect()
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
			SelectionGained = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = if bulkSelected then Palette.coral else accent,
		background = if selected or bulkSelected then Palette.panelRaised else Palette.panel,
		padding = if stack then 12 else 14,
		interactive = true,
		highlight = selected or bulkSelected,
		reducedMotion = reducedMotion,
		reveal = RELIC_ROW_SHOWN,
		clips = true,
	}, React.createElement(IconTile, {
		kind = itemIconKind(item.instance.DefinitionId, item.definition.Slot),
		accent = accent,
		size = if stack then 44 else 46,
		radius = 11,
		position = UDim2.fromOffset(0, if stack then 4 else 8),
		reducedMotion = reducedMotion,
		glow = selected,
	}), React.createElement(Text, {
		value = item.definition.Name,
		size = if stack then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(58, 0),
		sizeConstraint = UDim2.new(1, textW, 0, 22),
	}), React.createElement(Text, {
		value = `{item.definition.Description}  ·  {effectLabel(item.definition, item.instance.Level)}`,
		size = 11,
		color = accent,
		wrap = false,
		position = UDim2.fromOffset(58, 24),
		sizeConstraint = UDim2.new(1, textW, 0, 18),
	}), React.createElement(Text, {
		value = if item.equippedOn ~= nil then `On {socketLabel(item.equippedOn)}` elseif locked then "Protected" else `{item.definition.Slot} relic`,
		size = 11,
		color = if item.equippedOn ~= nil then Palette.mint elseif locked then Palette.mango else Palette.creamSoft,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(58, 44),
		sizeConstraint = UDim2.new(1, textW, 0, 16),
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, -(58 + 8), 0, 22) else UDim2.fromOffset(84, 86),
		Position = if stack then UDim2.fromOffset(58, 68) else UDim2.new(1, -84, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, if stack then React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) else React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = string.upper(item.definition.Rarity),
		accent = accent,
		filled = true,
		size = if stack then UDim2.fromOffset(78, 20) else UDim2.fromOffset(84, 20),
	}), React.createElement(Badge, {
		value = `LV {item.instance.Level}`,
		accent = Palette.mango,
		size = if stack then UDim2.fromOffset(56, 20) else UDim2.fromOffset(84, 20),
	}), not stack and React.createElement(Badge, {
		value = `#{string.sub(item.uid, -4)}`,
		accent = Palette.lineSoft,
		size = UDim2.fromOffset(84, 20),
	}), locked and not bulkMode and stack and React.createElement(Badge, {
		value = "LOCK",
		accent = Palette.mango,
		filled = true,
		size = UDim2.fromOffset(44, 20),
	}), bulkMode and React.createElement(Badge, {
		value = if bulkSelected then "ON" elseif locked then "LOCK" elseif item.equippedOn ~= nil then "USED" else "PICK",
		accent = if bulkSelected then Palette.coral elseif locked or item.equippedOn ~= nil then Palette.lineSoft else accent,
		filled = bulkSelected,
		size = if stack then UDim2.fromOffset(52, 20) else UDim2.fromOffset(84, 20),
	}))))
end
local INSPECT_PAD = InventoryMath.INSPECT_PAD
local INSPECT_BTN_GAP = InventoryMath.INSPECT_BTN_GAP
local INSPECT_FOOTER_H = InventoryMath.INSPECT_FOOTER_H
local ACTION_BTN = InventoryMath.ACTION_BTN
local function inspectSocketBlock(equipped, targetCount, chipRows, stack)
	return InventoryMath.InspectSocketBlock(equipped, targetCount, chipRows, stack, TapTarget)
end
local function inspectActionsHeight(stack)
	return InventoryMath.InspectActionsHeight(stack)
end
local function inspectPanelHeight(socketBlock, stack)
	return InventoryMath.InspectPanelHeight(socketBlock, stack)
end
local function DetailPanel(_param)
	local item = _param.item
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	if stack == nil then
		stack = false
	end
	local fill = _param.fill
	if fill == nil then
		fill = false
	end
	local inspectActionsHostRef = React.useRef(nil)
	local accent = rarityColor(config, item.definition.Rarity)
	local _result = state.Items
	if _result ~= nil then
		_result = _result.Essence
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local essence = _condition
	local cost = upgradeCost(item.definition, item.instance.Level)
	local maxed = item.instance.Level >= item.definition.MaxLevel
	local canUpgrade = not maxed and essence >= cost
	local targets = React.useMemo(function()
		return socketTargets(state, config, item.definition)
	end, { config, item.definition, state.Machines, state.Research })
	local _condition_1 = item.equippedOn
	if _condition_1 == nil then
		local _result_1 = targets[1]
		if _result_1 ~= nil then
			_result_1 = _result_1.id
		end
		_condition_1 = _result_1
		if _condition_1 == nil then
			_condition_1 = ""
		end
	end
	local target, setTarget = React.useState(_condition_1)
	React.useEffect(function()
		setTarget(function(current)
			if item.equippedOn ~= nil then
				return item.equippedOn
			end
			-- ▼ ReadonlyArray.some ▼
			local _result_1 = false
			local _callback_1 = function(candidate)
				return candidate.id == current
			end
			for _k, _v in targets do
				if _callback_1(_v, _k - 1, targets) then
					_result_1 = true
					break
				end
			end
			-- ▲ ReadonlyArray.some ▲
			if _result_1 then
				return current
			end
			local _result_2 = targets[1]
			if _result_2 ~= nil then
				_result_2 = _result_2.id
			end
			local _condition_2 = _result_2
			if _condition_2 == nil then
				_condition_2 = ""
			end
			return _condition_2
		end)
	end, { item.uid, item.equippedOn, targets })
	local salvage = salvagePreview(config, item.definition, item.instance.Level)
	local equipped = item.equippedOn ~= nil
	local locked = item.instance.Locked == true
	local chipCols = if stack then 2 else 3
	local chipRows = math.max(1, math.ceil(#targets / chipCols))
	local socketBlock = inspectSocketBlock(equipped, #targets, chipRows, stack)
	local chipHeight = if stack then TapTarget else 40
	local chipStep = if stack then TapTarget + 6 else 42
	local actionsH = inspectActionsHeight(stack)
	local detailH = inspectPanelHeight(socketBlock, stack)
	local actionSize = if stack then UDim2.new(0.5, -5, 0, ACTION_BTN) else UDim2.new(0.25, -7, 0, ACTION_BTN)
	-- Gamepad: park Selection on SOCKET/UPGRADE when inspect mounts (FocusClaim prefers Claim-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = inspectActionsHostRef.current
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
	end, { item.uid, equipped, locked, canUpgrade, target })
	local socketBtn = function(size, position)
		return if equipped then React.createElement(Button, {
			text = "DETACH",
			icon = "Close",
			onClick = function()
				return dispatch("UnequipItem", {
					Target = item.equippedOn,
				})
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			outline = true,
		}) else React.createElement(Button, {
			text = "SOCKET",
			icon = "Loadout",
			onClick = function()
				if target ~= "" then
					dispatch("EquipItem", {
						Uid = item.uid,
						Target = target,
					})
				end
			end,
			color = Palette.mint,
			textColor = Palette.ink,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			disabled = target == "",
			highlight = target ~= "",
		})
	end
	local upgradeBtn = function(size, position)
		return React.createElement(Button, {
			text = if maxed then "MAXED" else `UPGRADE  {compactNumber(cost)}`,
			icon = "StarGrid",
			onClick = function()
				return dispatch("UpgradeItem", {
					Uid = item.uid,
				})
			end,
			color = if canUpgrade then Palette.mango else Palette.panelSoft,
			textColor = if canUpgrade then Palette.ink else Palette.muted,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			disabled = not canUpgrade,
			highlight = canUpgrade,
		})
	end
	local salvageBtn = function(size, position)
		return React.createElement(Button, {
			text = `SALVAGE  +{salvage}`,
			icon = "Dust",
			onClick = function()
				return dispatch("SalvageItem", {
					Uid = item.uid,
				})
			end,
			color = if equipped or locked then Palette.panelSoft else Palette.coral,
			textColor = if equipped or locked then Palette.muted else Palette.ink,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			disabled = equipped or locked,
			outline = equipped or locked,
		})
	end
	local lockBtn = function(size, position)
		return React.createElement(Button, {
			text = if locked then "UNPROTECT" else "PROTECT",
			icon = "Lock",
			onClick = function()
				return dispatch("ToggleItemLock", {
					Uid = item.uid,
				})
			end,
			color = if locked then Palette.mango else Palette.panelSoft,
			textColor = if locked then Palette.ink else Palette.creamSoft,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			outline = not locked,
		})
	end
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, INSPECT_BTN_GAP),
	})
	local _exp_1 = equipped and React.createElement(Text, {
		value = `Socketed on {socketLabel(item.equippedOn)}`,
		size = 13,
		color = Palette.mint,
		weight = Enum.FontWeight.Bold,
		fit = false,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	})
	local _condition_2 = not equipped and #targets > 0
	if _condition_2 then
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#targets)
		local _callback_1 = function(entry, index)
			local active = entry.id == target
			local col = index % chipCols
			local row = math.floor(index / chipCols)
			return React.createElement("imagebutton", {
				key = entry.id,
				Size = UDim2.new(1 / chipCols, -6, 0, chipHeight),
				Position = UDim2.new(col / chipCols, 0, 0, row * chipStep),
				BackgroundColor3 = if active then accent else Palette.panelSoft,
				BackgroundTransparency = if active then 0.15 else 0.2,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Active = true,
				Selectable = true,
				Event = {
					Activated = function()
						setTarget(entry.id)
						Audio:play("tick")
					end,
					MouseEnter = function()
						return Audio:play("hover")
					end,
					SelectionGained = function()
						return Audio:play("hover")
					end,
				},
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 8),
			}), React.createElement("uistroke", {
				Color = if active then accent else Palette.lineSoft,
				Thickness = 1,
				Transparency = if active then 0.2 else 0.55,
			}), React.createElement(Text, {
				value = entry.label,
				size = 12,
				color = if active then contrastOn(accent) else Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				fit = false,
				position = UDim2.fromOffset(6, 0),
				sizeConstraint = UDim2.new(1, -12, 1, 0),
			}))
		end
		for _k, _v in targets do
			_newValue_1[_k] = _callback_1(_v, _k - 1, targets)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_2 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, chipRows * chipStep),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 0,
		}, _newValue_1)
	end
	return React.createElement(Panel, {
		size = if fill then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, detailH),
		accent = accent,
		background = Palette.panelRaised,
		padding = INSPECT_PAD,
		layoutOrder = layoutOrder,
		-- SOCKET/UPGRADE/PROTECT/SALVAGE sit on the panel floor — clipping them was a short-phone CTA footgun.
		clips = false,
		zIndex = 20,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp, _exp_1, _condition_2, not equipped and #targets == 0 and React.createElement(Text, {
		value = "Unlock a matching machine/research to socket this.",
		size = 12,
		color = Palette.mango,
		wrap = true,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement("frame", {
		ref = inspectActionsHostRef,
		Name = "InspectClaimActions",
		Size = UDim2.new(1, 0, 0, actionsH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, if stack then React.createElement(React.Fragment, nil, React.createElement("frame", {
		Name = "InspectSocketClaim",
		Size = actionSize,
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, socketBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectUpgradeClaim",
		Size = actionSize,
		Position = UDim2.new(0.5, 5, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, upgradeBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectProtect",
		Size = actionSize,
		Position = UDim2.fromOffset(0, ACTION_BTN + INSPECT_BTN_GAP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, lockBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectSalvage",
		Size = actionSize,
		Position = UDim2.new(0.5, 5, 0, ACTION_BTN + INSPECT_BTN_GAP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, salvageBtn(UDim2.fromScale(1, 1), nil))) else React.createElement(React.Fragment, nil, React.createElement("frame", {
		Name = "InspectSocketClaim",
		Size = actionSize,
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, socketBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectUpgradeClaim",
		Size = actionSize,
		Position = UDim2.new(0.25, 2, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, upgradeBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectProtect",
		Size = actionSize,
		Position = UDim2.new(0.5, 4, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, lockBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectSalvage",
		Size = actionSize,
		Position = UDim2.new(0.75, 6, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, salvageBtn(UDim2.fromScale(1, 1), nil)))), React.createElement(Text, {
		value = if equipped then "Detach before salvaging." elseif locked then "Protected relics cannot be salvaged." else `Essence bank: {compactNumber(essence)}`,
		size = 12,
		color = Palette.muted,
		fit = false,
		layoutOrder = 3,
		sizeConstraint = UDim2.new(1, 0, 0, INSPECT_FOOTER_H),
	})))
end
local function CrateCard(_param)
	local crate = _param.crate
	local keys = _param.keys
	local pity = _param.pity
	local onOpen = _param.onOpen
	local busy = _param.busy
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(layoutOrder, reducedMotion)
	local cardH = if stack then 248 else 160
	local actions = if stack then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget * 2 + 8),
		Position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 14)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 1",
		icon = "Crate",
		onClick = function()
			return onOpen(1)
		end,
		sound = "open",
		color = if keys >= 1 and not busy then crate.Color else Palette.panelSoft,
		textColor = if keys >= 1 and not busy then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = keys < 1 or busy,
		highlight = keys >= 1 and not busy,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 5",
		icon = "Crate",
		onClick = function()
			return onOpen(5)
		end,
		sound = "open",
		color = if keys >= 5 and not busy then Palette.mango else Palette.panelSoft,
		textColor = if keys >= 5 and not busy then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = keys < 5 or busy,
		highlight = keys >= 5 and not busy,
	})) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 1",
		icon = "Crate",
		onClick = function()
			return onOpen(1)
		end,
		sound = "open",
		color = if keys >= 1 and not busy then crate.Color else Palette.panelSoft,
		textColor = if keys >= 1 and not busy then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = keys < 1 or busy,
		highlight = keys >= 1 and not busy,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 5",
		icon = "Crate",
		onClick = function()
			return onOpen(5)
		end,
		sound = "open",
		color = if keys >= 5 and not busy then Palette.mango else Palette.panelSoft,
		textColor = if keys >= 5 and not busy then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = keys < 5 or busy,
		highlight = keys >= 5 and not busy,
	}))
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, cardH),
		accent = crate.Color,
		background = Palette.panelRaised,
		padding = if stack then 16 else 18,
		layoutOrder = layoutOrder,
		reveal = reveal,
		highlight = keys >= 1 and not busy,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Crate",
		accent = crate.Color,
		size = 48,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 8 else 24),
		reducedMotion = reducedMotion,
		glow = keys >= 1,
	}), React.createElement(Text, {
		value = crate.Name,
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(60, 4),
		sizeConstraint = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 24),
	}), React.createElement(Text, {
		value = crate.Description,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(60, 34),
		sizeConstraint = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 40),
	}), React.createElement(Text, {
		value = `{keys} keys  ·  pity {pity}/{crate.PityAfter} → {crate.PityRarity}`,
		size = 12,
		color = crate.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(60, 84),
		sizeConstraint = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 18),
	}), actions)
end
local function restockClock(seconds)
	return InventoryMath.RestockClock(seconds)
end
local function offerStock(offer)
	return InventoryMath.OfferStock(offer)
end
local MARKET_BANNER_H = 126
local MARKET_CARD_H = 176
local MARKET_CARD_H_STACK = 210
local function MarketBanner(_param)
	local refreshText = _param.refreshText
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, if stack then 132 else MARKET_BANNER_H),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = if stack then 14 else 16,
		layoutOrder = layoutOrder,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Shop",
		accent = Palette.mango,
		size = if stack then 44 else 48,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 6 else 12),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = "MARKET DOCK",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 56 else 64, 0),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -16, 0, 14),
	}), React.createElement(Text, {
		value = refreshText,
		size = if stack then 16 else 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 56 else 64, 18),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -16, 0, 24),
	}), React.createElement(Text, {
		value = "Daily keys restock at UTC midnight. Rarer offers keep live stock that drips back slowly.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(if stack then 56 else 64, 48),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -16, 0, if stack then 44 else 36),
	}), not stack and React.createElement(React.Fragment, nil, React.createElement(Badge, {
		value = "DAILY KEYS",
		accent = Palette.cyan,
		filled = true,
		position = UDim2.new(1, -208, 1, -30),
		size = UDim2.fromOffset(98, 24),
	}), React.createElement(Badge, {
		value = "LIVE STOCK",
		accent = Palette.violet,
		position = UDim2.new(1, -100, 1, -30),
		size = UDim2.fromOffset(92, 24),
	})), stack and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = "DAILY KEYS",
		accent = Palette.cyan,
		filled = true,
		size = UDim2.fromOffset(98, 24),
	}), React.createElement(Badge, {
		value = "LIVE STOCK",
		accent = Palette.violet,
		size = UDim2.fromOffset(92, 24),
	})))
end
local function MarketCard(_param)
	local offer = _param.offer
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local cash = _param.cash
	local stardust = _param.stardust
	local cores = _param.cores
	local refreshShort = _param.refreshShort
	local stack = _param.stack
	if stack == nil then
		stack = false
	end
	local balance = if offer.Currency == "Cash" then asFlux(cash) elseif offer.Currency == "Stardust" then stardust else cores
	local _binding = offerStock(offer)
	local stock = _binding.stock
	local stockMax = _binding.stockMax
	local soldOut = _binding.soldOut
	local daily = _binding.daily
	local canBuy = not soldOut and balance >= offer.Price
	local priceLabel = if offer.Price <= 0 then "FREE" else `{compactNumber(offer.Price)} {offer.Currency}`
	local accent = if soldOut then Palette.muted else offer.Color
	local stockBadge = if daily then (if soldOut then (if offer.Price <= 0 then "CLAIMED" else "BOUGHT") elseif stockMax > 1 then `DAILY {stock}/{stockMax}` else "DAILY") else (if soldOut then "SOLD OUT" else `STOCK {stock}`)
	local stockBadgeAccent = if soldOut then Palette.coral elseif daily then Palette.cyan else Palette.violet
	local statusLine = if daily then (if soldOut then (if offer.Price <= 0 then "Claimed for today — free key returns at restock." else "Daily buy used — comes back at restock.") else `Refreshes daily · {stock} of {stockMax} left`) else (if soldOut then "Scarce offer empty — wait for drip restock." else `Limited stock · {stock} of {stockMax} remaining`)
	local buttonText = if soldOut then (if daily then "WAIT FOR RESTOCK" else "SOLD OUT") else "BUY"
	local cardH = if stack then MARKET_CARD_H_STACK else MARKET_CARD_H
	local textReserve = if stack then -(56 + 16) else -240
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, cardH),
		accent = accent,
		background = if soldOut then Palette.panelSoft else Palette.panelRaised,
		padding = if stack then 16 else 18,
		layoutOrder = layoutOrder,
		clips = false,
		highlight = canBuy,
		reducedMotion = reducedMotion,
	}, React.createElement(IconTile, {
		kind = if offer.Kind == "Essence" then "Dust" elseif offer.Kind == "Key" then "Gift" else "Loadout",
		accent = accent,
		size = 44,
		radius = 11,
		position = UDim2.fromOffset(0, if stack then 8 else 32),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = offer.Name,
		size = 16,
		color = if soldOut then Palette.creamSoft else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(56, 4),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 16) else -260, 0, 22),
	}), if stack then React.createElement(Badge, {
		value = stockBadge,
		accent = stockBadgeAccent,
		filled = not soldOut,
		position = UDim2.fromOffset(56, 28),
		size = UDim2.fromOffset(140, 24),
	}) else React.createElement(Badge, {
		value = stockBadge,
		accent = stockBadgeAccent,
		filled = not soldOut,
		position = UDim2.new(1, -150, 0, 4),
		size = UDim2.fromOffset(140, 26),
	}), React.createElement(Text, {
		value = offer.Description,
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(56, if stack then 56 else 30),
		sizeConstraint = UDim2.new(1, textReserve, 0, 34),
	}), React.createElement(Text, {
		value = priceLabel,
		size = 13,
		color = if soldOut then Palette.muted else offer.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 94 else 70),
		sizeConstraint = UDim2.new(1, textReserve, 0, 18),
	}), React.createElement(Text, {
		value = statusLine,
		size = 10,
		color = if soldOut then Palette.coral else Palette.muted,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 114 else 94),
		sizeConstraint = UDim2.new(1, textReserve, 0, 28),
	}), soldOut and daily and refreshShort ~= nil and (React.createElement(Text, {
		value = refreshShort,
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 142 else 124),
		sizeConstraint = UDim2.new(1, textReserve, 0, 14),
	})), if stack then React.createElement(Button, {
		text = buttonText,
		icon = if soldOut then "Lock" else "Shop",
		onClick = function()
			return dispatch("BuyItemOffer", {
				Id = offer.Id,
			})
		end,
		color = if canBuy then offer.Color else Palette.panelSoft,
		textColor = if canBuy then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		reducedMotion = reducedMotion,
		disabled = not canBuy,
		highlight = canBuy,
	}) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = buttonText,
		icon = if soldOut then "Lock" else "Shop",
		onClick = function()
			return dispatch("BuyItemOffer", {
				Id = offer.Id,
			})
		end,
		color = if canBuy then offer.Color else Palette.panelSoft,
		textColor = if canBuy then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(0, 48),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = not canBuy,
		highlight = canBuy,
	})))
end
local function LoadoutBoard(_param)
	local state = _param.state
	local config = _param.config
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local items = state.Items
	local _effects = items
	if _effects ~= nil then
		_effects = _effects.Effects
	end
	local effects = _effects
	local _object = {
		id = "Production",
		label = "Production",
	}
	local _left = "value"
	local _result = effects
	if _result ~= nil then
		_result = _result.Production
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	_object[_left] = _condition
	_object.color = Palette.green
	local _object_1 = {
		id = "Capacity",
		label = "Vault",
	}
	local _left_1 = "value"
	local _result_1 = effects
	if _result_1 ~= nil then
		_result_1 = _result_1.Capacity
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 0
	end
	_object_1[_left_1] = _condition_1
	_object_1.color = Palette.cyan
	local _object_2 = {
		id = "Tap",
		label = "Overcharge",
	}
	local _left_2 = "value"
	local _result_2 = effects
	if _result_2 ~= nil then
		_result_2 = _result_2.Tap
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 0
	end
	_object_2[_left_2] = _condition_2
	_object_2.color = Palette.mango
	local _object_3 = {
		id = "Critical",
		label = "Critical",
	}
	local _left_3 = "value"
	local _result_3 = effects
	if _result_3 ~= nil then
		_result_3 = _result_3.Critical
	end
	local _condition_3 = _result_3
	if _condition_3 == nil then
		_condition_3 = 0
	end
	_object_3[_left_3] = _condition_3
	_object_3.color = Palette.pink
	local _object_4 = {
		id = "Automation",
		label = "Auto",
	}
	local _left_4 = "value"
	local _result_4 = effects
	if _result_4 ~= nil then
		_result_4 = _result_4.Automation
	end
	local _condition_4 = _result_4
	if _condition_4 == nil then
		_condition_4 = 0
	end
	_object_4[_left_4] = _condition_4
	_object_4.color = Palette.mint
	local _object_5 = {
		id = "Offline",
		label = "Offline",
	}
	local _left_5 = "value"
	local _result_5 = effects
	if _result_5 ~= nil then
		_result_5 = _result_5.Offline
	end
	local _condition_5 = _result_5
	if _condition_5 == nil then
		_condition_5 = 0
	end
	_object_5[_left_5] = _condition_5
	_object_5.color = Palette.violet
	local lines = { _object, _object_1, _object_2, _object_3, _object_4, _object_5 }
	local equipped = {}
	local byId = {}
	local _result_6 = config.Items
	if _result_6 ~= nil then
		_result_6 = _result_6.Definitions
	end
	local _condition_6 = _result_6
	if _condition_6 == nil then
		_condition_6 = {}
	end
	for _, definition in _condition_6 do
		local _id = definition.Id
		byId[_id] = definition
	end
	if items ~= nil then
		for target, uid in pairs(items.Equipped) do
			if not (type(uid) == "string") then
				continue
			end
			local instance = items.Inventory[uid]
			local _result_7
			if instance ~= nil then
				local _definitionId = instance.DefinitionId
				_result_7 = byId[_definitionId]
			else
				_result_7 = nil
			end
			local definition = _result_7
			if definition == nil then
				continue
			end
			local _arg0 = {
				target = target,
				name = `{definition.Name} LV{instance.Level}`,
				rarity = definition.Rarity,
			}
			table.insert(equipped, _arg0)
		end
	end
	local cols = if stack then 2 else 3
	local tileH = if stack then 58 else 54
	local tileGap = 8
	local gridH = math.ceil(#lines / cols) * (tileH + tileGap)
	local listH = 28 + math.max(1, #equipped) * 32
	local _exp = React.createElement(Text, {
		value = "ACTIVE BONUSES",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#lines)
	local _callback_1 = function(line, index)
		local col = index % cols
		local row = math.floor(index / cols)
		return React.createElement("frame", {
			key = line.id,
			Size = UDim2.new(1 / cols, -tileGap, 0, tileH),
			Position = UDim2.new(col / cols, if col == 0 then 0 else tileGap / 2, 0, row * (tileH + tileGap)),
			BackgroundColor3 = Palette.panelSoft,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Color = if line.value > 0 then line.color else Palette.lineSoft,
			Transparency = 0.28,
			Thickness = 1.5,
		}), React.createElement(Text, {
			value = line.label,
			size = 10,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 8),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}), React.createElement(Text, {
			value = `+{math.floor(line.value * 1000 + 0.5) / 10}%`,
			size = 16,
			color = if line.value > 0 then line.color else Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(10, 24),
			sizeConstraint = UDim2.new(1, -20, 0, 22),
		}))
	end
	for _k, _v in lines do
		_newValue_1[_k] = _callback_1(_v, _k - 1, lines)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, gridH),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue_1)
	local _exp_2 = React.createElement(Text, {
		value = "SOCKETED RELICS",
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 28 + gridH),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})
	local _exp_3 = #equipped == 0 and React.createElement(Text, {
		value = "No relics socketed yet.",
		size = 12,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 48 + gridH),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#equipped)
	local _callback_2 = function(entry, index)
		return React.createElement("frame", {
			key = entry.target,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 48 + gridH + index * 32),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 8),
		}), React.createElement(Text, {
			value = `{socketLabel(entry.target)}  ·  {entry.name}`,
			size = 12,
			color = rarityColor(config, entry.rarity),
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 0),
			sizeConstraint = UDim2.new(1, -20, 1, 0),
		}))
	end
	for _k, _v in equipped do
		_newValue_2[_k] = _callback_2(_v, _k - 1, equipped)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 40 + gridH + 22 + listH),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = if stack then 14 else 18,
		layoutOrder = layoutOrder,
		clips = false,
		highlight = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _newValue_2)
end
local function InventoryView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local crateRevealActive = _param.crateRevealActive
	if crateRevealActive == nil then
		crateRevealActive = false
	end
	local onCrateReveal = _param.onCrateReveal
	local openShop = _param.openShop
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Inventory mounts tab springs + hero shimmer together; snap when antilag already cut ambient.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local touchLayout = chrome.mobile
	local headerReveal = useStagger(0, softMotion)
	local tab, setTab = React.useState("Relics")
	local activeTabIndex = math.max(0, (table.find(TABS, tab) or 0) - 1)
	local paneTravel = useFlipperSpring(activeTabIndex, softMotion, 1540, 40)
	local panePosition = paneTravel:map(function(position)
		return UDim2.new(0, math.round(math.clamp(position - activeTabIndex, -1, 1) * 22), 0, 0)
	end)
	local filter, setFilter = React.useState("All")
	local sort, setSort = React.useState("Rarity")
	local rarity, setRarity = React.useState("Any")
	local search, setSearch = React.useState("")
	local bulkMode, setBulkModeState = React.useState(false)
	local bulkSelected, setBulkSelected = React.useState({})
	local bulkBusy, setBulkBusy = React.useState(false)
	local autoOpen, setAutoOpen = React.useState(false)
	local autoBusy, setAutoBusy = React.useState(false)
	local autoDraft, setAutoDraft = React.useState()
	local selectedUid, setSelectedUid = React.useState(nil)
	local crateBusy, setCrateBusy = React.useState(false)
	local mountedRef = React.useRef(true)
	local crateAttemptRef = React.useRef(0)
	React.useEffect(function()
		return function()
			mountedRef.current = false
			crateAttemptRef.current += 1
		end
	end, {})
	local items = state.Items
	local _exp = function()
		return collectOwned(state, config)
	end
	local _exp_1 = config.Items
	local _result = items
	if _result ~= nil then
		_result = _result.Equipped
	end
	local _result_1 = items
	if _result_1 ~= nil then
		_result_1 = _result_1.Inventory
	end
	local owned = React.useMemo(_exp, { _exp_1, _result, _result_1 })
	local filtered = React.useMemo(function()
		return sortOwned(searchOwned(filterOwned(owned, filter), search, rarity), config, sort)
	end, { config.Items, filter, owned, rarity, search, sort })
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(entry)
		return entry.uid == selectedUid
	end
	local _result_2
	for _i, _v in filtered do
		if _callback_1(_v, _i - 1, filtered) == true then
			_result_2 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result_2
	if _condition == nil then
		_condition = filtered[1]
	end
	local selected = _condition
	local relicListRef = React.useRef()
	local relicRowStride = relicRowHeight(stack) + ROW_GAP
	React.useEffect(function()
		if selected ~= nil and selected.uid ~= selectedUid then
			setSelectedUid(selected.uid)
		end
		if #filtered == 0 then
			setSelectedUid(nil)
		end
	end, { filtered, selected, selectedUid })
	local _exp_2 = function()
		local frame = relicListRef.current
		if frame == nil or selected == nil or bulkMode or tab ~= "Relics" then
			return nil
		end
		local selectedIndex = 0
		for index, item in filtered do
			if item.uid == selected.uid then
				selectedIndex = index - 1
				break
			end
		end
		local top = SCROLL_PAD + selectedIndex * relicRowStride
		local block = relicRowHeight(stack)
		local view = frame.AbsoluteWindowSize.Y
		if view <= 1 then
			return nil
		end
		local pos = frame.CanvasPosition.Y
		if top < pos + 8 then
			frame.CanvasPosition = Vector2.new(0, math.max(0, top - 8))
		elseif top + block > pos + view - 8 then
			frame.CanvasPosition = Vector2.new(0, math.max(0, top + block - view + 8))
		end
		-- Deliberately narrow: `config`/`state.Machines`/`state.Research`/`filtered` are
		-- recreated on every store tick (machine production, essence, etc.), and keying
		-- off them here re-fires this effect continuously, yanking the user's scroll
		-- position while they're mid-scroll. Only the inputs that can actually change
		-- the selected row's position belong in this list.
	end
	local _exp_3 = #filtered
	local _result_3 = selected
	if _result_3 ~= nil then
		_result_3 = _result_3.uid
	end
	React.useEffect(_exp_2, { bulkMode, filter, _exp_3, rarity, relicRowStride, search, _result_3, sort, stack, tab })
	local _exp_4 = function()
		local present = {}
		for _, item in owned do
			local _uid = item.uid
			present[_uid] = true
		end
		setBulkSelected(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue_1 = {}
			local _callback_2 = function(uid)
				local _uid = uid
				return present[_uid] ~= nil
			end
			local _length = 0
			for _k, _v in current do
				if _callback_2(_v, _k - 1, current) == true then
					_length += 1
					_newValue_1[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue_1
		end)
	end
	local _result_4 = items
	if _result_4 ~= nil then
		_result_4 = _result_4.Inventory
	end
	React.useEffect(_exp_4, { _result_4 })
	local filled = #owned
	local _result_5 = items
	if _result_5 ~= nil then
		_result_5 = _result_5.InventoryLimit
	end
	local _condition_1 = _result_5
	if _condition_1 == nil then
		local _result_6 = config.Items
		if _result_6 ~= nil then
			_result_6 = _result_6.InventoryLimit
		end
		_condition_1 = _result_6
		if _condition_1 == nil then
			_condition_1 = 100
		end
	end
	local limit = _condition_1
	local _result_6 = items
	if _result_6 ~= nil then
		_result_6 = _result_6.Essence
	end
	local _condition_2 = _result_6
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local essence = _condition_2
	local heroH = if stack then HERO_H_STACK else HERO_H
	local pageGap = if stack then ROW_GAP else Layout.panelGap
	local toolPad = if stack then 8 else 12
	local toolGap = if stack then 8 else 10
	local tabH = if touchLayout then 54 else 56
	local fieldH = if stack then math.max(TapTarget, 52) else TOOL_FIELD_DESK
	local toolsH = if tab == "Relics" then toolPad * 2 + (if stack then 26 + toolGap else 0) + (if stack then fieldH * 2 + toolGap else fieldH) + toolGap + fieldH else 0
	local _exp_5 = function()
		return if selected ~= nil then socketTargets(state, config, selected.definition) else {}
	end
	local _result_7 = selected
	if _result_7 ~= nil then
		_result_7 = _result_7.uid
	end
	local targetsForSelected = React.useMemo(_exp_5, { config, _result_7, state.Machines, state.Research })
	local chipRows = if selected ~= nil and selected.equippedOn == nil and #targetsForSelected > 0 then math.max(1, math.ceil(#targetsForSelected / (if stack then 2 else 3))) else 0
	local inspectPanelH = if tab == "Relics" and selected ~= nil and not bulkMode then inspectPanelHeight(inspectSocketBlock(selected.equippedOn ~= nil, #targetsForSelected, chipRows, stack), stack) else 0
	local detailH = if inspectPanelH > 0 then inspectPanelH + ROW_GAP else 0
	local listH = math.max(1, #filtered) * relicRowStride
	local listStart = heroH + pageGap + tabH + pageGap + toolsH + detailH + SCROLL_EDGE
	local _result_8 = config.Items
	if _result_8 ~= nil then
		_result_8 = _result_8.Crates
	end
	local _condition_3 = _result_8
	if _condition_3 == nil then
		_condition_3 = {}
	end
	local crates = _condition_3
	local _result_9 = items
	if _result_9 ~= nil then
		_result_9 = _result_9.Shop
	end
	local _condition_4 = _result_9
	if _condition_4 == nil then
		_condition_4 = {}
	end
	local shopOffers = _condition_4
	local marketNow = useWallClock(tab == "Market")
	local _result_10 = items
	if _result_10 ~= nil then
		_result_10 = _result_10.ShopRefreshAt
	end
	local _condition_5 = _result_10
	if _condition_5 == nil then
		_condition_5 = 0
	end
	local shopRefreshAt = _condition_5
	local marketBannerH = if stack then 132 else MARKET_BANNER_H
	local keysRefreshText = marketNow:map(function(timestamp)
		local remaining = math.max(0, shopRefreshAt - timestamp)
		return if remaining > 0 then `Keys refresh in {restockClock(remaining)}` else "Keys refreshing now…"
	end)
	local refreshShort = marketNow:map(function(timestamp)
		local remaining = math.max(0, shopRefreshAt - timestamp)
		return if remaining > 0 then `Restock in {restockClock(remaining)}` else "Restocking…"
	end)
	local selectedForBulk = React.useMemo(function()
		-- ▼ ReadonlyArray.filter ▼
		local _newValue_1 = {}
		local _callback_2 = function(item)
			local _uid = item.uid
			local _condition_6 = (table.find(bulkSelected, _uid) or 0) - 1 >= 0
			if _condition_6 then
				_condition_6 = item.equippedOn == nil and item.instance.Locked ~= true
			end
			return _condition_6
		end
		local _length = 0
		for _k, _v in owned do
			if _callback_2(_v, _k - 1, owned) == true then
				_length += 1
				_newValue_1[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		return _newValue_1
	end, { bulkSelected, owned })
	local selectableVisible = React.useMemo(function()
		-- ▼ ReadonlyArray.filter ▼
		local _newValue_1 = {}
		local _callback_2 = function(item)
			return item.equippedOn == nil and item.instance.Locked ~= true
		end
		local _length = 0
		for _k, _v in filtered do
			if _callback_2(_v, _k - 1, filtered) == true then
				_length += 1
				_newValue_1[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		return _newValue_1
	end, { filtered })
	local selectionEssence = 0
	for _, item in selectedForBulk do
		selectionEssence += salvagePreview(config, item.definition, item.instance.Level)
	end
	local _result_11 = state.Shop
	if _result_11 ~= nil then
		_result_11 = _result_11.OwnedPasses.AutoSalvage
	end
	local passOwned = _result_11 == true
	local _result_12 = items
	if _result_12 ~= nil then
		_result_12 = _result_12.AutoSalvage
	end
	local _condition_6 = _result_12
	if _condition_6 == nil then
		_condition_6 = {
			Enabled = false,
			KeepNew = true,
			Rarities = {
				Common = true,
				Uncommon = true,
			},
		}
	end
	local serverAutoRules = _condition_6
	local autoRules = autoDraft or serverAutoRules
	local serverAutoSignature = autoSalvageSignature(serverAutoRules)
	local draftAutoSignature = if autoDraft ~= nil then autoSalvageSignature(autoDraft) else nil
	React.useEffect(function()
		if draftAutoSignature ~= nil and draftAutoSignature == serverAutoSignature then
			setAutoDraft(nil)
		end
	end, { draftAutoSignature, serverAutoSignature })
	local setBulkMode = function(value)
		setBulkModeState(value)
		if not value then
			setBulkSelected({})
		end
	end
	local toggleBulkItem = function(item)
		if item.equippedOn ~= nil or item.instance.Locked == true then
			Audio:play("error")
			return nil
		end
		setBulkSelected(function(current)
			local _current = current
			local _uid = item.uid
			local index = (table.find(_current, _uid) or 0) - 1
			if index >= 0 then
				-- ▼ ReadonlyArray.filter ▼
				local _newValue_1 = {}
				local _callback_2 = function(uid)
					return uid ~= item.uid
				end
				local _length = 0
				for _k, _v in current do
					if _callback_2(_v, _k - 1, current) == true then
						_length += 1
						_newValue_1[_length] = _v
					end
				end
				-- ▲ ReadonlyArray.filter ▲
				return _newValue_1
			end
			if #current >= 25 then
				return current
			end
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			_array[_length + 1] = item.uid
			return _array
		end)
	end
	local selectVisible = function()
		-- ▼ ReadonlyArray.filter ▼
		local _newValue_1 = {}
		local _callback_2 = function(_, index)
			return index < 25
		end
		local _length = 0
		for _k, _v in selectableVisible do
			if _callback_2(_v, _k - 1, selectableVisible) == true then
				_length += 1
				_newValue_1[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		-- ▼ ReadonlyArray.map ▼
		local _newValue_2 = table.create(#_newValue_1)
		local _callback_3 = function(item)
			return item.uid
		end
		for _k, _v in _newValue_1 do
			_newValue_2[_k] = _callback_3(_v, _k - 1, _newValue_1)
		end
		-- ▲ ReadonlyArray.map ▲
		setBulkSelected(_newValue_2)
		Audio:play("filterPick")
	end
	local clearSelection = function()
		return setBulkSelected({})
	end
	local runAutoNow = function()
		if autoBusy or bulkBusy or not passOwned or not autoRules.Enabled then
			return nil
		end
		local uids = {}
		for _, item in owned do
			if item.equippedOn ~= nil or item.instance.Locked == true then
				continue
			end
			if autoRules.Rarities[item.definition.Rarity] ~= true then
				continue
			end
			local _uid = item.uid
			table.insert(uids, _uid)
			if #uids >= 25 then
				break
			end
		end
		if #uids == 0 then
			Audio:play("error")
			return nil
		end
		setBulkBusy(true)
		dispatch("BulkSalvageItems", {
			Uids = uids,
		}, function(response)
			if not mountedRef.current then
				return nil
			end
			setBulkBusy(false)
			if response.ok then
				Audio:play("reward")
			end
		end)
	end
	local salvageSelected = function()
		if #selectedForBulk == 0 or bulkBusy then
			return nil
		end
		setBulkBusy(true)
		local _object = {}
		local _left = "Uids"
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#selectedForBulk)
		local _callback_2 = function(item)
			return item.uid
		end
		for _k, _v in selectedForBulk do
			_newValue_1[_k] = _callback_2(_v, _k - 1, selectedForBulk)
		end
		-- ▲ ReadonlyArray.map ▲
		_object[_left] = _newValue_1
		dispatch("BulkSalvageItems", _object, function(response)
			if not mountedRef.current then
				return nil
			end
			setBulkBusy(false)
			if response.ok then
				setBulkSelected({})
				Audio:play("reward")
			end
		end)
	end
	local updateAutoRules = function(updatedRules)
		if autoBusy or not passOwned then
			return nil
		end
		local rarities = {}
		for _, entry in AUTO_RARITIES do
			if entry ~= "Any" and updatedRules.Rarities[entry] == true then
				table.insert(rarities, entry)
			end
		end
		if updatedRules.Enabled and #rarities == 0 then
			table.insert(rarities, "Common")
			table.insert(rarities, "Uncommon")
			local _object = table.clone(updatedRules)
			setmetatable(_object, nil)
			local _left = "Rarities"
			local _object_1 = table.clone(updatedRules.Rarities)
			setmetatable(_object_1, nil)
			_object_1.Common = true
			_object_1.Uncommon = true
			_object[_left] = _object_1
			updatedRules = _object
		end
		setAutoDraft(updatedRules)
		setAutoBusy(true)
		dispatch("SetItemAutoSalvage", {
			Enabled = updatedRules.Enabled,
			KeepNew = updatedRules.KeepNew,
			Rarities = rarities,
		}, function(response)
			if not mountedRef.current then
				return nil
			end
			setAutoBusy(false)
			if not response.ok then
				setAutoDraft(nil)
			else
				Audio:play("filterPick")
			end
		end)
	end
	local canvasHeight = listStart + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	if tab == "Relics" then
		canvasHeight = listStart + listH + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	elseif tab == "Crates" then
		canvasHeight = listStart + #crates * ((if stack then 248 else 160) + pageGap) + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	elseif tab == "Market" then
		local marketCardH = if stack then MARKET_CARD_H_STACK else MARKET_CARD_H
		canvasHeight = listStart + marketBannerH + pageGap + math.max(1, #shopOffers) * (marketCardH + pageGap) + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	else
		local equippedCount = 0
		if items ~= nil then
			for _, uid in pairs(items.Equipped) do
				if type(uid) == "string" and items.Inventory[uid] ~= nil then
					equippedCount += 1
				end
			end
		end
		local cols = if stack then 2 else 3
		local gridH = math.ceil(6 / cols) * (if stack then 66 else 62)
		canvasHeight = listStart + 54 + gridH + 18 + 28 + math.max(1, equippedCount) * 32 + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	end
	local paneHeight = math.max(1, canvasHeight - heroH - tabH - pageGap * 2)
	local openCrate = function(crate, count)
		if crateBusy or crateRevealActive then
			return nil
		end
		local attempt = crateAttemptRef.current + 1
		crateAttemptRef.current = attempt
		setCrateBusy(true)
		dispatch("OpenItemCrate", {
			Id = crate.Id,
			Count = count,
		}, function(response)
			if not mountedRef.current or crateAttemptRef.current ~= attempt then
				return nil
			end
			setCrateBusy(false)
			if not response.ok then
				return nil
			end
			local rolls = response.Rolls
			if rolls == nil or #rolls == 0 then
				return nil
			end
			onCrateReveal({
				crateId = crate.Id,
				crateName = crate.Name,
				accent = crate.Color,
				rolls = rolls,
			})
			setTab("Relics")
		end)
	end
	local tabsBar = React.createElement(SegmentedTabs, {
		options = TAB_OPTIONS,
		value = tab,
		onChange = function(entry)
			setTab(entry)
			if entry ~= "Relics" then
				setBulkMode(false)
				setAutoOpen(false)
			end
		end,
		accent = Palette.violet,
		columns = #TABS,
		gap = pageGap,
		size = UDim2.new(1, 0, 0, tabH),
		layoutOrder = 1,
		reducedMotion = reducedMotion,
	})
	local toolsBar = React.createElement(InventoryTools, {
		search = search,
		setSearch = setSearch,
		filter = filter,
		setFilter = setFilter,
		rarity = rarity,
		setRarity = setRarity,
		sort = sort,
		setSort = setSort,
		bulkMode = bulkMode,
		setBulkMode = setBulkMode,
		autoOpen = autoOpen,
		setAutoOpen = setAutoOpen,
		equipBest = function()
			return dispatch("EquipBestItems")
		end,
		reducedMotion = reducedMotion,
		stack = stack,
		filled = filled,
		limit = limit,
		essence = essence,
	})
	local heroPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = if stack then 14 else 18,
		layoutOrder = 0,
		reveal = headerReveal,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Loadout",
		accent = Palette.violet,
		size = if stack then 38 else 44,
		radius = 11,
		position = UDim2.fromOffset(0, if stack then 4 else 6),
		spin = false,
		reducedMotion = reducedMotion,
		glow = true,
	}), React.createElement(Text, {
		value = "INVENTORY",
		size = 12,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 50 else 56, 2),
		sizeConstraint = UDim2.new(1, if stack then -58 else -20, 0, 16),
	}), React.createElement(ShimmerText, {
		value = "Relics, crates, and sockets.",
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 50 else 56, 20),
		sizeConstraint = UDim2.new(1, if stack then -58 else -20, 0, 26),
		enabled = not softMotion,
		periodSeconds = 4.8,
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 28) else UDim2.fromOffset(220, 30),
		Position = if stack then UDim2.new(0, 0, 1, -28) else UDim2.new(1, -220, 0.5, -15),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if stack then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = `{filled} / {limit} BAG`,
		accent = Palette.violet,
		filled = true,
		size = UDim2.fromOffset(if stack then 108 else 118, 28),
	}), React.createElement(Badge, {
		value = `{compactNumber(essence)} ESS`,
		accent = Palette.mango,
		size = UDim2.fromOffset(if stack then 100 else 112, 28),
	})))
	if tab == "Relics" then
		local listPane = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(SectionLabel, {
			value = if bulkMode then "SELECT RELICS" else "RELIC BAY",
			color = if bulkMode then Palette.coral else Palette.violet,
		}), React.createElement(FlatList, {
			data = filtered,
			itemHeight = relicRowStride,
			headerHeight = SCROLL_PAD,
			overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
			canvasTail = SCROLL_PAD,
			frameRef = relicListRef,
			Size = UDim2.new(1, 0, 1, -34),
			Position = UDim2.fromOffset(0, 34),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			scrollBarTransparency = 0.22,
			keyExtractor = function(item)
				return item.uid
			end,
			renderItem = function(_param_1)
				local item = _param_1.item
				local _attributes = {
					item = item,
					config = config,
				}
				local _result_13 = selected
				if _result_13 ~= nil then
					_result_13 = _result_13.uid
				end
				_attributes.selected = _result_13 == item.uid
				local _uid = item.uid
				_attributes.bulkSelected = (table.find(bulkSelected, _uid) or 0) - 1 >= 0
				_attributes.bulkMode = bulkMode
				_attributes.onSelect = function()
					Audio:play("tick")
					if bulkMode then
						toggleBulkItem(item)
					else
						setSelectedUid(item.uid)
					end
				end
				_attributes.reducedMotion = reducedMotion
				_attributes.layoutOrder = 0
				_attributes.stack = stack
				return React.createElement(RelicRow, _attributes)
			end,
			ListEmptyComponent = React.createElement(EmptyState, {
				icon = "Loadout",
				title = if #owned == 0 then "No relics yet" else "Nothing matches",
				body = if #owned == 0 then ((config.ClientPageGuides and config.ClientPageGuides.Inventory and config.ClientPageGuides.Inventory.EmptyItems) or "Open crates or buy a starter coupler from the Market tab.") else "Clear the search or set the filters back to All relics.",
				accent = Palette.violet,
				layoutOrder = 0,
			}),
		}))
		local sections = {
			{
				id = "hero",
				height = heroH,
				element = heroPanel,
			},
			{
				id = "tabs",
				height = tabH,
				element = tabsBar,
			},
			{
				id = "tools",
				height = toolsH,
				element = toolsBar,
			},
		}
		if inspectPanelH > 0 and selected ~= nil then
			table.insert(sections, {
				id = "inspect",
				height = inspectPanelH,
				element = React.createElement(DetailPanel, {
					item = selected,
					state = state,
					config = config,
					dispatch = dispatch,
					reducedMotion = softMotion,
					layoutOrder = 0,
					stack = stack,
					fill = true,
				}),
			})
		end
		table.insert(sections, {
			id = "list",
			fill = true,
			minHeight = math.max(160, relicRowHeight(stack) + 48),
			element = listPane,
		})
		if bulkMode then
			table.insert(sections, {
				id = "bulk",
				height = BULK_DOCK_H,
				element = React.createElement(BulkDock, {
					selectedCount = #selectedForBulk,
					selectableCount = #selectableVisible,
					selectionEssence = selectionEssence,
					selectVisible = selectVisible,
					clearSelection = clearSelection,
					salvageSelected = salvageSelected,
					bulkBusy = bulkBusy,
					reducedMotion = reducedMotion,
				}),
			})
		end
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(PageScaffold, {
			gap = pageGap,
			tailPad = if stack then 10 else 14,
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			sections = sections,
		}), autoOpen and React.createElement(AutoSalvageSheet, {
			passOwned = passOwned,
			rules = autoRules,
			updateRules = updateAutoRules,
			autoBusy = autoBusy,
			openShop = openShop,
			runNow = runAutoNow,
			reducedMotion = reducedMotion,
			stack = stack,
			config = config,
			onClose = function()
				return setAutoOpen(false)
			end,
		}))
	end
	-- Crates / Market / Loadout: PageScaffold so desktop pageGap vs ROW_GAP cannot clip lists
	-- the way the old absolute canvasHeight + nested pane math did.
	local sections = {
		{
			id = "hero",
			height = heroH,
			element = heroPanel,
		},
		{
			id = "tabs",
			height = tabH,
			element = tabsBar,
		},
	}
	if tab == "Crates" then
		-- Virtualize crate channels the same way Market virtualizes dock offers.
		local crateCardH = if stack then 248 else 160
		local crateStride = crateCardH + pageGap
		local crateLabelH = 28
		local crateList = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(FlatList, {
			data = crates,
			itemHeight = crateStride,
			headerHeight = crateLabelH + pageGap,
			overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
			canvasTail = SCROLL_PAD,
			Size = UDim2.fromScale(1, 1),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			scrollBarTransparency = 0.22,
			keyExtractor = function(crate)
				return crate.Id
			end,
			renderItem = function(_param_1)
				local crate = _param_1.item
				local keysTable = if items ~= nil then items.Keys else nil
				local pityTable = if items ~= nil then items.Pity else nil
				local keyCount = if type(keysTable) == "table" then keysTable[crate.Id] else nil
				local pityCount = if type(pityTable) == "table" then pityTable[crate.Id] else nil
				return React.createElement(CrateCard, {
					crate = crate,
					keys = if type(keyCount) == "number" then keyCount else 0,
					pity = if type(pityCount) == "number" then pityCount else 0,
					onOpen = function(count)
						return openCrate(crate, count)
					end,
					busy = crateBusy,
					reducedMotion = reducedMotion,
					layoutOrder = 0,
					stack = stack,
				})
			end,
			ListHeaderComponent = React.createElement(SectionLabel, {
				value = "CRATE CHANNELS",
				color = Palette.violet,
				layoutOrder = 0,
			}),
			ListEmptyComponent = React.createElement(EmptyState, {
				icon = "Crate",
				title = "No crate channels",
				body = "Crate channels unlock as you progress — check back after more story and lab work.",
				accent = Palette.violet,
				layoutOrder = 0,
				reducedMotion = reducedMotion,
			}),
		}))
		table.insert(sections, {
			id = "crates",
			fill = true,
			minHeight = math.max(160, crateLabelH + crateCardH + pageGap * 2),
			element = crateList,
		})
	elseif tab == "Market" then
		local marketCardH = if stack then MARKET_CARD_H_STACK else MARKET_CARD_H
		local marketStride = marketCardH + pageGap
		local marketList = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(FlatList, {
			data = shopOffers,
			itemHeight = marketStride,
			headerHeight = marketBannerH + pageGap,
			overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
			canvasTail = SCROLL_PAD,
			Size = UDim2.fromScale(1, 1),
			scrollBarColor = Palette.mango,
			scrollBarThickness = 4,
			scrollBarTransparency = 0.22,
			keyExtractor = function(offer)
				return offer.Id
			end,
			renderItem = function(_param_1)
				local offer = _param_1.item
				return React.createElement(MarketCard, {
					offer = offer,
					dispatch = dispatch,
					reducedMotion = reducedMotion,
					layoutOrder = 0,
					cash = state.Cash,
					stardust = state.Stardust,
					cores = state.Cores,
					refreshShort = refreshShort,
					stack = stack,
				})
			end,
			ListHeaderComponent = React.createElement(MarketBanner, {
				refreshText = keysRefreshText,
				reducedMotion = reducedMotion,
				layoutOrder = 0,
				stack = stack,
			}),
			ListEmptyComponent = React.createElement(EmptyState, {
				icon = "Shop",
				title = "Market offline",
				body = ((config.ClientPageGuides and config.ClientPageGuides.Inventory and config.ClientPageGuides.Inventory.EmptyMarket) or "No dock offers right now — check back after the next restock."),
				accent = Palette.mango,
				layoutOrder = 0,
				reducedMotion = reducedMotion,
			}),
		}))
		table.insert(sections, {
			id = "market",
			fill = true,
			minHeight = math.max(160, marketBannerH + marketCardH + pageGap * 2),
			element = marketList,
		})
	else
		local equippedCount = 0
		if items ~= nil then
			for _, uid in pairs(items.Equipped) do
				if type(uid) == "string" and items.Inventory[uid] ~= nil then
					equippedCount += 1
				end
			end
		end
		local cols = if stack then 2 else 3
		local tileH = if stack then 58 else 54
		local tileGap = 8
		local gridH = math.ceil(6 / cols) * (tileH + tileGap)
		-- Must match LoadoutBoard panel: 40 + gridH + 22 + listH
		local loadoutH = 40 + gridH + 22 + 28 + math.max(1, equippedCount) * 32
		table.insert(sections, {
			id = "loadout-label",
			height = 28,
			element = React.createElement(SectionLabel, {
				value = "SOCKET SUMMARY",
				color = Palette.mint,
				layoutOrder = 0,
			}),
		})
		table.insert(sections, {
			id = "loadout",
			height = loadoutH,
			element = React.createElement(LoadoutBoard, {
				state = state,
				config = config,
				reducedMotion = reducedMotion,
				layoutOrder = 0,
				stack = stack,
			}),
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = if stack then 10 else 14,
		scrollBarColor = if tab == "Market" then Palette.mango else Palette.violet,
		scrollBarThickness = 4,
		sections = sections,
	}))
end
return {
	InventoryView = InventoryView,
}
