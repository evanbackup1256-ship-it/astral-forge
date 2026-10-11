--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesSystem: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesSystem: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["SettingsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local MobileControls = require(script.Parent.Parent.UiOverlays)("MobileControls").MobileControls
local _mobileLayout = require(script.Parent.Parent.CoreKit)("mobileLayout")
local fitTouchGridWidth = _mobileLayout.fitTouchGridWidth
local moreDockHeight = _mobileLayout.moreDockHeight
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local Panel = _ui.Panel
local SearchField = _ui.SearchField
local Slider = _ui.Slider
local Text = _ui.Text
local Schema = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("SettingsSchema")
local Browse = require(script.Parent.Parent.BrowseKit)

local ROW_H = 60
local ROW_H_STACK = 110
local NAV_W = 196
local MOBILE_DOCK_DESTINATIONS = { "Overview", "Workshop", "Inventory", "Research", "Shop", "Settings" }

local function accentOf(section)
	return Palette[section.accent] or Palette.cyan
end
local SECTION_BY_ID = {}
for _, section in Schema.SECTIONS do
	SECTION_BY_ID[section.id] = section
end

local function Switch(_param)
	local on = _param.on
	local accent = _param.accent
	local softMotion = _param.softMotion
	local knob = useFlipperSpring(if on then 1 else 0, softMotion, 640, 34)
	local anchor = _param.anchorPoint or Vector2.zero
	local trackX = if anchor.X >= 0.5 then 1 else 0
	return React.createElement("textbutton", {
		Size = UDim2.fromOffset(60, TapTarget),
		Position = _param.position,
		AnchorPoint = anchor,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play(if on then "toggleOff" else "toggleOn")
				_param.onToggle()
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(50, 28),
		Position = UDim2.fromScale(trackX, 0.5),
		AnchorPoint = Vector2.new(trackX, 0.5),
		BackgroundColor3 = if on then accent else Palette.graphite,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = if on then accent else Palette.lineSoft,
		Transparency = if on then 0.2 else 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = knob:map(function(amount)
			return UDim2.new(0, 3 + math.clamp(amount, -0.1, 1.1) * 22, 0.5, 0)
		end),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = if on then Palette.ink else Palette.creamSoft,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))
end

local function Choice(_param)
	local choices = _param.choices
	local value = _param.value
	local accent = _param.accent
	local cells = {
		layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, option in choices do
		local picked = math.abs(option.value - value) < 0.02
		cells["c" .. index] = React.createElement("frame", {
			Size = UDim2.new(1 / #choices, -math.ceil(4 * (#choices - 1) / #choices), 1, 0),
			LayoutOrder = index,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, {
			text = "", size = UDim2.fromScale(1, 1),
			color = if picked then accent else Palette.panelSoft, highlight = picked,
			reducedMotion = _param.softMotion, sound = if picked then false else "tabSwitch",
			onClick = function() if not picked then _param.onPick(option.value) end end,
			children = React.createElement(Text, {
				value = option.label, size = 12, color = if picked then Palette.ink else Palette.creamSoft,
				weight = Enum.FontWeight.Bold, fit = true, minSize = 9, align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(4, 4), sizeConstraint = UDim2.new(1, -8, 1, -8), zIndex = 11,
			}),
		}))
	end
	return React.createElement("frame", {
		Size = _param.size,
		Position = _param.position,
		AnchorPoint = _param.anchorPoint,
		BackgroundTransparency = 1,
	}, cells)
end

local function SettingRow(_param)
	local entry = _param.entry
	local saved = _param.value
	local accent = _param.accent
	local stack = _param.stack
	local softMotion = _param.softMotion
	local dispatch = _param.dispatch
	local draft, setDraft = React.useState(saved)
	React.useEffect(function()
		setDraft(saved)
	end, { saved })
	local commit = function(value)
		setDraft(value)
		dispatch("SetSetting", { Key = entry.key, Value = value })
	end
	local controlW = if entry.kind == "toggle" then 50 elseif entry.kind == "choice" then math.min(260, 64 * #(entry.choices or {})) else 240
	local textRight = if stack then 0 else controlW + 20
	local control
	if entry.kind == "toggle" then
		control = React.createElement(Switch, {
			on = draft >= 0.5,
			accent = accent,
			softMotion = softMotion,
			position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 2)) else UDim2.new(1, 0, 0.5, 0),
			anchorPoint = if stack then Vector2.new(0, 0) else Vector2.new(1, 0.5),
			onToggle = function()
				commit(if draft >= 0.5 then 0 else 1)
			end,
		})
	elseif entry.kind == "choice" then
		control = React.createElement(Choice, {
			choices = entry.choices,
			value = draft,
			accent = accent,
			size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(controlW, TapTarget),
			position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 2)) else UDim2.new(1, 0, 0.5, 0),
			anchorPoint = if stack then Vector2.new(0, 0) else Vector2.new(1, 0.5),
			onPick = commit,
			softMotion = softMotion,
		})
	else
		control = React.createElement("frame", {
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(controlW, 32),
			Position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, 0, 0.5, 0),
			AnchorPoint = if stack then Vector2.new(0, 0) else Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
		}, React.createElement(Slider, {
			value = draft,
			accent = accent,
			reducedMotion = softMotion,
			size = UDim2.new(1, -52, 1, 0),
			onChange = setDraft,
			onCommit = function(value)
				commit(value)
			end,
		}), React.createElement(Text, {
			value = `{math.floor(draft * 100 + 0.5)}%`,
			size = 13,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -46, 0, 0),
			sizeConstraint = UDim2.new(0, 46, 1, 0),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then ROW_H_STACK else ROW_H),
		LayoutOrder = _param.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		value = if _param.tag ~= nil then `{entry.label}  ·  {_param.tag}` else entry.label,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(0, if stack then 8 else 11),
		sizeConstraint = UDim2.new(1, -textRight, 0, 20),
	}), React.createElement(Text, {
		value = entry.help,
		size = 12,
		color = Palette.muted,
		position = UDim2.fromOffset(0, if stack then 29 else 32),
		sizeConstraint = UDim2.new(1, -textRight, 0, 16),
	}), control, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
	}))
end

local function SectionButton(_param)
	local section = _param.section
	local active = _param.active
	local accent = accentOf(section)
	return React.createElement("frame", {
		Size = _param.size,
		LayoutOrder = _param.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "", size = UDim2.fromScale(1, 1), color = if active then darken(accent, 0.62) else Palette.panelSoft,
		highlight = active, reducedMotion = _param.softMotion, sound = if active then false else "tabSwitch",
		onClick = function() if not active then _param.onPick(section.id) end end,
		children = React.createElement(React.Fragment, nil, React.createElement("frame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 11,
		}, React.createElement(Icon, {
		kind = section.icon,
		color = if active then accent else Palette.muted,
		accent = accent,
		size = 18,
		position = UDim2.new(0, if _param.compact then 10 else 14, 0.5, -9),
	}), React.createElement(Text, {
		value = section.label,
		size = 14,
		color = if active then Palette.cream else Palette.creamSoft,
		weight = if active then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
		position = UDim2.fromOffset(if _param.compact then 34 else 40, 0),
		sizeConstraint = UDim2.new(1, if _param.compact then -38 else -70, 1, 0),
		zIndex = 11,
	}), not _param.compact and React.createElement(Text, {
		value = tostring(_param.count),
		size = 12,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -36, 0, 0),
		sizeConstraint = UDim2.new(0, 26, 1, 0),
		zIndex = 11,
	}))),
	}))
end

local function SettingsView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local touch = not viewport.desktop and UserInputService.TouchEnabled
	local mobileHudAvailable = touch and chrome.stack
	local settings = state.Settings or {}
	local activeSection, setActiveSection = React.useState("sound")
	local query, setQuery = Browse.useLinkedQuery("Settings")
	local changedOnly, setChangedOnly = React.useState(false)
	local advancedOpen, setAdvancedOpen = React.useState({})
	local mobileEdit, setMobileEdit = React.useState(false)
	local reveal = useStagger(0, softMotion)

	local sections = {}
	for _, section in Schema.SECTIONS do
		if not section.touchOnly or mobileHudAvailable then
			table.insert(sections, section)
		end
	end
	React.useEffect(function()
		local sectionInfo = SECTION_BY_ID[activeSection]
		if sectionInfo and sectionInfo.touchOnly and not mobileHudAvailable then
			setActiveSection("interface")
		end
	end, { activeSection, mobileHudAvailable })
	local section = SECTION_BY_ID[activeSection] or SECTION_BY_ID["interface"]
	local accent = accentOf(section)

	local settingsClaimHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = settingsClaimHostRef.current
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
	end, { activeSection })

	local searching = not string.match(query, "^%s*$")
	local function isChanged(entry)
		local current = Schema.value(settings, entry.key)
		local defaultValue = entry.default
		if typeof(current) == "number" and typeof(defaultValue) == "number" then
			return math.abs(current - defaultValue) > 0.01
		end
		return tostring(current) ~= tostring(defaultValue)
	end
	local changedEntries = {}
	for _, entry in Schema.ENTRIES do
		local home = SECTION_BY_ID[entry.section]
		if not home then
			continue
		end
		if not (home.touchOnly and not mobileHudAvailable) and isChanged(entry) then
			table.insert(changedEntries, entry)
		end
	end
	local showChanged = changedOnly and not searching
	local listing = searching or showChanged
	local rows = {}
	local hiddenAdvanced = 0
	for _, entry in Schema.ENTRIES do
		local home = SECTION_BY_ID[entry.section]
		if not home or (home.touchOnly and not mobileHudAvailable) then
			continue
		end
		if searching then
			if Browse.matches(query, entry.label, entry.help, home.label, entry.key) then
				table.insert(rows, entry)
			end
		elseif showChanged then
			if isChanged(entry) then
				table.insert(rows, entry)
			end
		elseif entry.section == activeSection then
			if entry.advanced and not advancedOpen[activeSection] then
				hiddenAdvanced += 1
			else
				table.insert(rows, entry)
			end
		end
	end
	local counts = {}
	for _, entry in Schema.ENTRIES do
		counts[entry.section] = (counts[entry.section] or 0) + 1
	end

	local preset = Schema.matchingPreset(settings)
	local applyPreset = function(entry)
		dispatch("SetSetting", { Values = entry.values, Label = entry.notice })
	end
	local resetSection = function()
		dispatch("SetSetting", { Values = Schema.sectionDefaults(activeSection), Label = `{section.label} settings reset.` })
	end

	local quickScale = Schema.value(settings, "MobileQuickScale")
	local dockScale = Schema.value(settings, "MobileDockScale")
	local toastScale = Schema.value(settings, "MobileToastScale")
	local hudSafeTop = viewport.topInset + chrome.topbarRows + 12
	local densityScale = 0.82 + Schema.value(settings, "UiDensity") * 0.36
	local hudEdgePad = math.max(8, math.floor(chrome.pagePadding * densityScale))
	local dockGap = if chrome.landscape then 3 else 3 + math.floor(Schema.value(settings, "MobileButtonSpacing") * 5)
	local touchTargetFloor = if Schema.value(settings, "LargeTouchTargets") >= 0.5 then TapTarget + 6 else TapTarget
	local dockCellH = math.max(touchTargetFloor, math.floor(chrome.moreCellH * (0.88 + dockScale * 0.16)))
	local quickWidth = math.max(200, (viewport.width - math.max(hudEdgePad, chrome.sideSafe) * 2) * (0.72 + quickScale * 0.28))
	local quickHeight = math.max(TapTarget + 8, math.floor(chrome.quickBarH * (0.86 + quickScale * 0.22)))
	local dockWidth = fitTouchGridWidth(viewport.width, hudEdgePad, chrome.sideSafe, chrome.moreCols, dockGap, 0.72 + dockScale * 0.28)
	local dockCount = 0
	for _, id in MOBILE_DOCK_DESTINATIONS do
		local unlock = state.FeatureUnlocks and state.FeatureUnlocks[id]
		if not (unlock ~= nil and unlock.Unlocked == false) then
			dockCount += 1
		end
	end
	local dockHeight = moreDockHeight(true, math.max(1, dockCount), chrome.moreCols, dockCellH, dockGap)
	local toastWidth = math.min(220, math.max(180, viewport.width - 48)) * (0.8 + toastScale * 0.2)
	local toastHeight = 2 * (48 + 4)
	local mobileSlots = React.useMemo(function()
		local slots = {}
		local function slot(id, label, xKey, yKey, dx, dy, width, height, anchorY)
			table.insert(slots, {
				id = id, label = label, xKey = xKey, yKey = yKey,
				x = settings[xKey] or dx, y = settings[yKey] or dy, defaultX = dx, defaultY = dy,
				width = math.floor(width), height = math.floor(height), anchorY = anchorY, safeTop = hudSafeTop,
			})
		end
		if chrome.quickBarH > 0 then
			slot("quick", "QUICK ACTIONS", "MobileQuickX", "MobileQuickY", 0.5, 0.70, quickWidth, quickHeight)
		end
		if chrome.stack and viewport.height >= 480 and chrome.quickBarH > 0 then
			slot("dock", "NAVIGATION", "MobileDockX", "MobileDockY", 0.5, 0.92, dockWidth, dockHeight)
		end
		slot("toasts", "NOTIFICATIONS", "MobileToastX", "MobileToastY", 0.84, 0.27, toastWidth, toastHeight, 0)
		return slots
	end, { chrome.quickBarH, chrome.stack, dockHeight, dockWidth, hudSafeTop, quickHeight, quickWidth, settings.MobileDockX, settings.MobileDockY, settings.MobileQuickX, settings.MobileQuickY, settings.MobileToastX, settings.MobileToastY, toastHeight, toastWidth, viewport.height })

	local searchH = if stack then TapTarget else 38
	local actionsY = 56
	local searchY = if stack then actionsY + 40 + 10 else 64
	local chipsY = searchY + searchH + 8
	local headerH = chipsY + Browse.CHIP_H + 32
	local header = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 16,
		reveal = reveal,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "Settings",
		size = if stack then 22 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		sizeConstraint = UDim2.new(1, if stack then 0 else -340, 0, 30),
	}), React.createElement(Text, {
		value = `Saved to your profile automatically  ·  v{state.Game.Version}`,
		size = 12,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, if stack then 0 else -340, 0, 16),
	}), React.createElement("frame", {
		Name = "SettingsClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.fromOffset(320, 40),
		Position = if stack then UDim2.fromOffset(0, actionsY) else UDim2.new(1, -320, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 6,
		ref = settingsClaimHostRef,
	}, React.createElement(Button, {
		text = "REPLAY TOUR",
		icon = "Guide",
		onClick = function()
			dispatch("ReplayTutorial")
		end,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(0.5, -4, 1, 0),
		reducedMotion = softMotion,
	}), React.createElement(Button, {
		text = "PATCH NOTES",
		icon = "Gift",
		onClick = function()
			dispatch("OpenRelease")
		end,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(0.5, -4, 1, 0),
		position = UDim2.new(0.5, 4, 0, 0),
		reducedMotion = softMotion,
	})), React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		placeholder = "Search settings",
		accent = accent,
		size = if stack then UDim2.new(1, 0, 0, searchH) else UDim2.fromOffset(340, searchH),
		position = UDim2.fromOffset(0, searchY),
		reducedMotion = softMotion,
	}), React.createElement(Browse.ChipRow, {
		options = {
			{ id = "sections", label = "By section", icon = "Settings" },
			{ id = "changed", label = "Changed from default", icon = "Refresh" },
		},
		value = if changedOnly then "changed" else "sections",
		counts = { changed = #changedEntries },
		onChange = function(id)
			if id == "changed" then
				setQuery("")
			end
			Audio:play("tabSwitch")
			setChangedOnly(id == "changed")
		end,
		accent = accent,
		position = UDim2.fromOffset(0, chipsY),
		size = UDim2.new(1, 0, 0, Browse.CHIP_H),
	}))

	local navButtons = {
		layout = React.createElement("uilistlayout", {
			FillDirection = if stack then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			Wraps = stack,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local chipW = if stack then math.floor((viewport.width - chrome.pagePadding * 2 - 24 - 12) / 3) else NAV_W - 16
	for index, entry in sections do
		navButtons[entry.id] = React.createElement(SectionButton, {
			section = entry,
			active = not listing and entry.id == activeSection,
			count = counts[entry.id] or 0,
			compact = stack,
			size = UDim2.fromOffset(chipW, if stack then TapTarget else 42),
			layoutOrder = index,
			softMotion = softMotion,
			onPick = function(id)
				setQuery("")
				setChangedOnly(false)
				setActiveSection(id)
			end,
		})
	end
	local navRows = if stack then math.ceil(#sections / 3) else #sections
	local navH = if stack then navRows * (TapTarget + 6) + 12 else #sections * 48 + 16

	local listChildren = {
		layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	}
	local rowH = if stack then ROW_H_STACK else ROW_H
	local listH = 0
	local order = 0
	local function add(key, element, height)
		order += 1
		listChildren[key] = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = order,
			BackgroundTransparency = 1,
		}, element)
		listH += height
	end
	add("title", React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = if searching then `{#rows} result{if #rows == 1 then "" else "s"} for "{query}"` elseif showChanged then `{#rows} changed setting{if #rows == 1 then "" else "s"}` else section.label,
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -110, 0, 24),
	}), React.createElement(Text, {
		value = if searching then "From every section." elseif showChanged then "Everything you set differently from the defaults." else section.blurb,
		size = 12,
		color = Palette.muted,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, -110, 0, 16),
	}), (not searching or showChanged) and React.createElement(Button, {
		text = if showChanged then "RESET ALL" else "RESET",
		icon = "Refresh",
		onClick = if showChanged then function()
			local values = {}
			for _, entry in changedEntries do
				values[entry.key] = entry.default
			end
			dispatch("SetSetting", { Values = values, Label = "Settings back to defaults." })
		end else resetSection,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromOffset(100, 34),
		position = UDim2.new(1, -100, 0, 4),
		reducedMotion = softMotion,
	})), 56)
	if not listing and activeSection == "display" then
		local presetCells = {}
		for index, entry in Schema.PRESETS do
			presetCells[entry.id] = React.createElement(Button, {
				text = string.upper(entry.label),
				onClick = function()
					applyPreset(entry)
				end,
				color = if preset == entry.id then accent else Palette.panelSoft,
				textColor = if preset == entry.id then Palette.ink else Palette.creamSoft,
				outline = preset ~= entry.id,
				highlight = preset == entry.id,
				size = UDim2.new(1 / #Schema.PRESETS, -6, 1, 0),
				position = UDim2.new((index - 1) / #Schema.PRESETS, 3, 0, 0),
				reducedMotion = softMotion,
			})
		end
		add("presets", React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = if preset == nil then "PRESET  ·  CUSTOM" else "PRESET",
			size = 11,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 38),
			Position = UDim2.fromOffset(0, 18),
			BackgroundTransparency = 1,
		}, presetCells)), 66)
	end
	for index, entry in rows do
		add("row_" .. entry.key, React.createElement(SettingRow, {
			entry = entry,
			value = Schema.value(settings, entry.key),
			accent = if listing then accentOf(SECTION_BY_ID[entry.section]) else accent,
			tag = if listing then SECTION_BY_ID[entry.section].label elseif isChanged(entry) then "changed" else nil,
			stack = stack,
			softMotion = softMotion,
			dispatch = dispatch,
			layoutOrder = index,
		}), rowH)
	end
	if listing and #rows == 0 then
		add("empty", React.createElement(Text, {
			value = if showChanged then "Everything is on its default." else "Nothing matches. Try a shorter word, like \"music\" or \"text\".",
			size = 13,
			color = Palette.muted,
			sizeConstraint = UDim2.new(1, 0, 0, 40),
		}), 40)
	end
	if not listing and (hiddenAdvanced > 0 or advancedOpen[activeSection]) then
		add("advanced", React.createElement(Button, {
			text = if advancedOpen[activeSection] then "HIDE ADVANCED" else `SHOW {hiddenAdvanced} ADVANCED`,
			icon = if advancedOpen[activeSection] then "Hide" else "Chevron",
			onClick = function()
				local nextOpen = table.clone(advancedOpen)
				nextOpen[activeSection] = not advancedOpen[activeSection]
				setAdvancedOpen(nextOpen)
			end,
			color = Palette.panelSoft,
			textColor = Palette.creamSoft,
			outline = true,
			size = UDim2.new(1, 0, 0, 38),
			position = UDim2.fromOffset(0, 12),
			reducedMotion = softMotion,
		}), 58)
	end
	if not listing and activeSection == "mobile" and mobileHudAvailable then
		add("hud", React.createElement(Button, {
			text = "MOVE PHONE BUTTONS",
			icon = "Settings",
			onClick = function()
				setMobileEdit(true)
			end,
			color = accent,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.fromOffset(0, 10),
			reducedMotion = softMotion,
		}), TapTarget + 14)
	end
	if not listing and activeSection == "interface" and UserInputService.GamepadEnabled then
		add("controller", React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = "CONTROLLER",
			size = 11,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(0, 14),
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}), React.createElement(Text, {
			value = "LB / RB pages  ·  Y vault  ·  X overcharge  ·  LT / RT amount  ·  B back  ·  Start settings",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 32),
			sizeConstraint = UDim2.new(1, 0, 0, 34),
		})), 72)
	end
	local list = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = if listing then Palette.steel else accent,
		background = Palette.panel,
		padding = if stack then 14 else 20,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, listChildren))
	local listPanelH = listH + (if stack then 28 else 40)

	local scaffold = {
		{ id = "header", height = headerH, element = header },
	}
	if stack then
		table.insert(scaffold, {
			id = "sections",
			height = navH,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, React.createElement("uipadding", {
				PaddingTop = UDim.new(0, 6),
			}), navButtons),
		})
		table.insert(scaffold, { id = "list", height = listPanelH, element = list })
	else
		local bodyH = math.max(listPanelH, navH)
		table.insert(scaffold, {
			id = "body",
			height = bodyH,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, React.createElement(Panel, {
				size = UDim2.fromOffset(NAV_W, navH),
				background = Palette.panelRaised,
				accent = accent,
				padding = 8,
				reducedMotion = softMotion,
				clips = false,
			}, navButtons), React.createElement("frame", {
				Size = UDim2.new(1, -(NAV_W + 12), 0, listPanelH),
				Position = UDim2.fromOffset(NAV_W + 12, 0),
				BackgroundTransparency = 1,
			}, list)),
		})
	end

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(PageScaffold, {
		gap = 12,
		tailPad = scrollTail(stack, chrome.bottomSafe, 64),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = scaffold,
	}), mobileHudAvailable and React.createElement(MobileControls, {
		visible = mobileEdit,
		dispatch = dispatch,
		reducedMotion = softMotion,
		onClose = function()
			setMobileEdit(false)
		end,
		slots = mobileSlots,
		savedSlots = (state.Flags or {}).MobileLayoutSlots,
		scales = {
			quick = quickScale,
			dock = dockScale,
			toasts = toastScale,
		},
		opacities = {
			quick = Schema.value(settings, "MobileQuickOpacity"),
			dock = Schema.value(settings, "MobileDockOpacity"),
			toasts = Schema.value(settings, "MobileToastOpacity"),
		},
	}))
end
return {
	SettingsView = SettingsView,
}
end

__defs["CommandView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _AnimatedTitle = require(script.Parent.Parent.ReactHosts)("AnimatedTitle")
local AnimatedTitlePreview = _AnimatedTitle.AnimatedTitlePreview
local darkTitlePlate = _AnimatedTitle.darkTitlePlate
local titleFxAccent = _AnimatedTitle.titleFxAccent
local _scrolling = require(script.Parent.Parent.LayoutKit)("scrolling")
local AutoGrid = _scrolling.AutoGrid
local VirtualGrid = _scrolling.VirtualGrid
local Browse = require(script.Parent.Parent.BrowseKit)
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local easeOutCubic = _motion.easeOutCubic
local useBoatTween = _motion.useBoatTween
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local fitPanelHeight = _theme.fitPanelHeight
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local _elementFx = require(script.Parent.Parent.ElementFx)
local ElementFx = _elementFx.ElementFx
local elementSheet = _elementFx.sheet
local function gridPanelHeight(headerH, rows, cellH, gap, pad)
	local safeRows = math.max(1, rows)
	local gridH = safeRows * cellH + math.max(0, safeRows - 1) * gap
	return pad * 2 + headerH + gridH
end
local TABS = { "Overview", "Expeditions", "Artifacts", "Season" }
local TITLE_FX_FALLBACKS = { "shimmer", "aurora", "pulse", "chrome", "wave", "glow" }
local TAB_LABEL = {
	Overview = "Overview",
	Expeditions = "Expeditions",
	Artifacts = "Artifacts",
	Season = "Rank Track",
}
local TAB_SHORT = {
	Overview = "Home",
	Expeditions = "Trips",
	Artifacts = "Relics",
	Season = "Rank",
}
local _newValue = table.create(#TABS)
local _callback = function(id)
	return {
		id = id,
		label = TAB_LABEL[id],
	}
end
for _k, _v in TABS do
	_newValue[_k] = _callback(_v, _k - 1, TABS)
end
local TAB_OPTIONS = _newValue
local _newValue_1 = table.create(#TABS)
local _callback_1 = function(id)
	return {
		id = id,
		label = TAB_SHORT[id],
	}
end
for _k, _v in TABS do
	_newValue_1[_k] = _callback_1(_v, _k - 1, TABS)
end
local TAB_OPTIONS_SHORT = _newValue_1
local TAB_TIPS = {
	Overview = "Commander rank, crew, weekly jobs, titles, and the signal shop.",
	Expeditions = "Send crews on timed trips for signals and loot.",
	Artifacts = "Equip and upgrade expedition relics.",
	Season = "Claim rank track tiers as you earn commander XP.",
}
local CREW_ROLES = { "Pilot", "Engineer", "Navigator" }
local function crewCost(base, level)
	return math.floor(base * math.pow(level, 1.55))
end
local function artifactEffect(artifact, level)
	if artifact.EffectKind == "OfflineHours" then
		return `+{string.format("%.1f", artifact.EffectPerLevel * level)}h offline`
	end
	return `+{string.format("%.0f", artifact.EffectPerLevel * level * 100)}% {artifact.EffectKind}`
end
local function artifactIcon(id)
	if id == "SolarLens" then
		return "Forge"
	end
	if id == "VaultPrism" then
		return "Vault"
	end
	if id == "PulsarCoil" then
		return "Overcharge"
	end
	if id == "EchoRelay" then
		return "Visit"
	end
	if id == "DroneCrown" then
		return "Grid"
	end
	if id == "CriticalShard" then
		return "Jackpot"
	end
	if id == "CoreStabilizer" then
		return "Core"
	end
	if id == "TimeCompass" then
		return "Timer"
	end
	if id == "MagnetarSeal" then
		return "Anomaly"
	end
	if id == "VoidKey" then
		return "Lock"
	end
	if id == "AuroraMap" then
		return "World"
	end
	if id == "CrownOfHours" then
		return "Milestone"
	end
	return "Artifact"
end
local function TabRail(_param)
	local active = _param.active
	local setActive = _param.setActive
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local columns = _param.columns
	return React.createElement(SegmentedTabs, {
		options = TAB_OPTIONS,
		value = active,
		onChange = setActive,
		accent = Palette.cyan,
		columns = columns or #TABS,
		gap = 4,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})
end
local function TabPane(_param)
	local tabKey = _param.tabKey
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local enter = useBoatTween(1, if reducedMotion then 0.01 else 0.2, reducedMotion, easeOutCubic, 0)
	return React.createElement("frame", {
		key = tabKey,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 20,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = enter:map(function(a)
			return UDim2.new(0, math.round((1 - math.clamp(a, 0, 1)) * 7), 0, 0)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	}), children))
end
local CommandTitleCard = React.memo(function(props)
	local accent = titleFxAccent(props.fx)
	local effectName = `{string.upper((string.gsub(props.fx, "-", " ")))} EFFECT`
	local equip = React.useCallback(function()
		return props.dispatch("EquipTitle", {
			Id = props.id,
		})
	end, { props.dispatch, props.id })
	local actionHeight = if props.stack then TapTarget else 36
	local actionSize = UDim2.new(1, -14, 0, actionHeight)
	local actionPosition = UDim2.new(0, 7, 1, -(actionHeight + 7))
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = if props.equipped then accent else Palette.lineSoft,
		Thickness = if props.equipped then 1.5 else 1,
		Transparency = if props.equipped then 0.16 else 0.42,
	})
	local _exp_2 = React.createElement(Text, {
		value = effectName,
		size = 9,
		minSize = 8,
		color = if props.unlocked then accent else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(8, 6),
		sizeConstraint = UDim2.new(1, -16, 0, 13),
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 21),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(AnimatedTitlePreview, {
		text = props.name,
		fx = props.fx,
		size = if props.stack then 17 else 15,
		reducedMotion = props.reducedMotion,
		preview = not props.equipped,
		transparency = if props.unlocked then 0 else 0.46,
	}))
	local _attributes = {}
	local _condition = props.description
	if _condition == nil then
		_condition = "Preview this title exactly as it appears in chat and your profile."
	end
	_attributes.value = _condition
	_attributes.size = 10
	_attributes.minSize = 9
	_attributes.color = if props.unlocked then Palette.creamSoft else Palette.muted
	_attributes.wrap = true
	_attributes.fit = false
	_attributes.align = Enum.TextXAlignment.Center
	_attributes.position = UDim2.fromOffset(9, 58)
	_attributes.sizeConstraint = UDim2.new(1, -18, 0, 52)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darkTitlePlate(props.fx),
		BackgroundTransparency = if props.equipped then 0.08 else 0.34,
		BorderSizePixel = 0,
		Active = false,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement(Text, _attributes), if props.unlocked and not props.equipped then React.createElement(Button, {
		text = "WEAR TITLE",
		icon = "Loadout",
		onClick = equip,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = actionSize,
		position = actionPosition,
		reducedMotion = props.reducedMotion,
	}) else React.createElement("frame", {
		Size = actionSize,
		Position = actionPosition,
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		Active = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement("uistroke", {
		Color = if props.equipped then accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.58,
	}), React.createElement(Text, {
		value = if props.equipped then "EQUIPPED" else "LOCKED",
		size = 11,
		minSize = 9,
		color = if props.equipped then accent else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	})))
end)
local function CommandViewReady(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onSectionChange = _param.onSectionChange
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local overviewReveal = useStagger(0, softMotion)
	local expeditionsReveal = useStagger(1, softMotion)
	local opsReveal = useStagger(2, softMotion)
	local commandSoft = softMotion or overviewReveal == nil or expeditionsReveal == nil or opsReveal == nil
	local claimHostRef = React.useRef(nil)
	local contentWidth, setContentWidth = React.useState(360)
	local stack = chrome.contentStack or contentWidth < 760
	local ops = config.Operations
	local command = state.Command
	local tab, setTab = React.useState("Overview")
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local scrollRef = React.useRef()
	React.useEffect(function()
		local host = scrollRef.current
		if not host then return nil end
		local function measure()
			if host.AbsoluteSize.X > 0 then setContentWidth(host.AbsoluteSize.X) end
		end
		measure()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function() connection:Disconnect() end
	end, {})
	React.useEffect(function()
		if tab ~= "Expeditions" then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(1)
				if not alive then
					break
				end
				setNow(workspace:GetServerTimeNow())
			end
		end)
		return function()
			alive = false
			pcall(function()
				task.cancel(worker)
			end)
		end
	end, { tab })
	React.useEffect(function()
		local frame = scrollRef.current
		if frame then
			frame.CanvasPosition = Vector2.new(0, 0)
		end
	end, { tab })
	local expeditionBrowse = Browse.useBrowse({
		id = "Expeditions",
		items = ops.Expeditions or {},
		text = function(expedition)
			return { expedition.Name, formatReward(expedition.Reward), `level {expedition.RequiredLevel}` }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Available", label = "Available", test = function(expedition)
				return command.Level >= expedition.RequiredLevel
			end },
			{ id = "Locked", label = "Locked", test = function(expedition)
				return command.Level < expedition.RequiredLevel
			end },
		},
		sorts = {
			{ id = "Level", label = "By level" },
			{ id = "Shortest", label = "Shortest trip", compare = function(a, b)
				return (tonumber(a.Duration) or 0) < (tonumber(b.Duration) or 0)
			end },
			{ id = "Relic", label = "Best relic odds", compare = function(a, b)
				return (tonumber(a.ArtifactChance) or 0) > (tonumber(b.ArtifactChance) or 0)
			end },
		},
	})
	local expeditionList = expeditionBrowse.results
	local titlesEnabled = ops.TitlesEnabled ~= false
	local maxed = command.Level >= ops.MaxCommanderLevel
	local levelProgress = if maxed then 1 else meterFill(command.XP - command.LevelFloorXP, math.max(1, command.NextLevelXP - command.LevelFloorXP))
	local nextClaim = command.ClaimableCommanderLevels[1]
	local active = command.ActiveExpedition
	local _result = active
	if _result ~= nil then
		_result = _result.Id
	end
	local _condition = _result
	if _condition == nil then
		_condition = ""
	end
	local activeId = _condition
	local _result_1 = active
	if _result_1 ~= nil then
		_result_1 = _result_1.EndsAt
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local activeEnds = _condition_1
	local _result_2 = active
	if _result_2 ~= nil then
		_result_2 = _result_2.StartedAt
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local activeStarted = _condition_2
	local expeditionReady = activeId ~= "" and now >= activeEnds
	local expeditionProgress = if activeId == "" then 0 else math.clamp((now - activeStarted) / math.max(1, activeEnds - activeStarted), 0, 1)
	local statusLine = if activeId == "" then "Launch an unlocked adventure below." elseif expeditionReady then "Crew is back. Collect their rewards." else `Back in {clockText(math.max(0, activeEnds - now))}`
	local claimLabel = if activeId == "" then "Choose below" elseif expeditionReady then "COLLECT" else clockText(math.max(0, activeEnds - now))
	local firstReadyWeeklyId = nil
	if type(command.Weekly) == "table" then
		for _, directive in command.Weekly do
			if not directive.Claimed and directive.Progress >= directive.Target then
				firstReadyWeeklyId = directive.Id
				break
			end
		end
	end
	local firstReadySeasonTier = nil
	if type(ops.SeasonTiers) == "table" and type(command.SeasonClaims) == "table" then
		for _, tier in ops.SeasonTiers do
			local claimed = command.SeasonClaims[tostring(tier.Tier)] == true
			local unlocked = command.SeasonXP >= tier.RequiredXP
			if unlocked and not claimed then
				firstReadySeasonTier = tier.Tier
				break
			end
		end
	end
	local commandClaimReady = (tab == "Overview" and (nextClaim ~= nil or firstReadyWeeklyId ~= nil))
		or (tab == "Expeditions" and expeditionReady)
		or (tab == "Season" and firstReadySeasonTier ~= nil)
	React.useEffect(function()
		if not commandClaimReady or not UserInputService.GamepadEnabled then
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
	end, { tab, nextClaim, firstReadyWeeklyId, expeditionReady, firstReadySeasonTier, commandClaimReady })
	local _exp = ops.Expeditions
	local _callback_2 = function(item)
		return item.Id == activeId
	end
	local _result_3
	for _i, _v in _exp do
		if _callback_2(_v, _i - 1, _exp) == true then
			_result_3 = _v
			break
		end
	end
	local activeConfig = _result_3
	local _exp_1 = ops.Artifacts
	local _newValue_2 = {}
	local _callback_3 = function(artifact)
		return command.Artifacts[artifact.Id] ~= nil
	end
	local _length = 0
	for _k, _v in _exp_1 do
		if _callback_3(_v, _k - 1, _exp_1) == true then
			_length += 1
			_newValue_2[_length] = _v
		end
	end
	local ownedArtifacts = #_newValue_2
	local _exp_2 = ops.SeasonTiers
	local _callback_4 = function(tier)
		return command.SeasonClaims[tostring(tier.Tier)] ~= true
	end
	local _result_4
	for _i, _v in _exp_2 do
		if _callback_4(_v, _i - 1, _exp_2) == true then
			_result_4 = _v
			break
		end
	end
	local nextTier = _result_4
	local seasonFill = if nextTier then meterFill(command.SeasonXP, math.max(1, nextTier.RequiredXP)) else 1
	local seasonStatus = if nextTier then if command.SeasonXP >= nextTier.RequiredXP then `Gift {nextTier.Tier} is ready` else `{compactNumber(nextTier.RequiredXP - command.SeasonXP)} XP to gift {nextTier.Tier}` else "All season gifts claimed"
	local budget = chrome.contentBudget
	local panelPad = 14
	local gridGap = 8
	local heroH = if stack then 196 else 168
	local crewCols = if stack then 1 else 3
	local crewCellH = 136
	local crewRows = math.max(1, math.ceil(#CREW_ROLES / crewCols))
	local crewH = gridPanelHeight(54, crewRows, crewCellH, gridGap, panelPad)
	local weeklyItemH = if stack then 148 else 92
	local weeklyStride = if stack then 156 else 100
	local weeklyCount = math.max(1, #command.Weekly)
	local weeklyH = panelPad * 2 + 36 + (weeklyCount - 1) * weeklyStride + weeklyItemH
	local titleCols = math.max(1, math.min(4, math.floor((contentWidth - panelPad * 2 + gridGap) / (210 + gridGap))))
	local titleCellH = 176
	local titleRows = math.max(1, math.ceil(math.max(1, #command.Titles) / titleCols))
	local titlesH = if titlesEnabled then gridPanelHeight(52, titleRows, titleCellH, gridGap, panelPad) else 112
	local shopCols = math.max(1, math.min(4, math.floor((contentWidth - panelPad * 2 + gridGap) / (190 + gridGap))))
	local shopCellH = 180
	local shopRows = math.max(1, math.ceil(math.max(1, #command.Shop) / shopCols))
	local shopH = gridPanelHeight(36, shopRows, shopCellH, gridGap, panelPad)
	local masteryCols = math.max(1, math.min(3, math.floor((contentWidth - panelPad * 2 + gridGap) / (210 + gridGap))))
	local masteryCellH = 64
	local masteryRows = math.max(1, math.ceil(math.max(1, #config.Machines) / masteryCols))
	local masteryH = gridPanelHeight(36, masteryRows, masteryCellH, gridGap, panelPad)
	local expeditionHeroH = if stack then 188 else 140
	local expeditionRowH = if stack then 168 else 132
	local artifactHeroH = 110
	local artifactRowH = if stack then 180 else 140
	local seasonHeroH = 130
	local seasonRowH = if stack then 148 else 112
	local heroInfoWidth = if stack then -100 else -(114 + 210 + 14)
	local tabContent = 0
	local listContent = 0
	local tabHeroH = 0
	if tab == "Overview" then
		tabContent = heroH + crewH + weeklyH + titlesH + shopH + masteryH + Layout.panelGap * 5
	elseif tab == "Expeditions" then
		tabHeroH = expeditionHeroH
		listContent = #ops.Expeditions * expeditionRowH + math.max(0, #ops.Expeditions - 1) * Layout.panelGap
	elseif tab == "Artifacts" then
		tabHeroH = artifactHeroH
		listContent = #ops.Artifacts * artifactRowH + math.max(0, #ops.Artifacts - 1) * Layout.panelGap
	else
		tabHeroH = seasonHeroH
		listContent = #ops.SeasonTiers * seasonRowH + math.max(0, #ops.SeasonTiers - 1) * Layout.panelGap
	end
	local headerH = 56
	local tabColumns = math.max(1, math.min(#TABS, math.floor((contentWidth + 4) / 140)))
	local tabRows = math.ceil(#TABS / tabColumns)
	local tabsH = tabRows * 48 + (tabRows - 1) * 4
	local commandTail = scrollTail(stack, chrome.bottomSafe, if stack then 72 else 48)
	local useFillList = tab ~= "Overview"
	local order = 0
	local nextOrder = function()
		order += 1
		return order
	end
	local changeTab = function(nextTab)
		if nextTab == tab then
			return nil
		end
		local _result_5 = onSectionChange
		if _result_5 ~= nil then
			_result_5()
		end
		setTab(nextTab)
	end
	local _exp_3 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, React.createElement(SectionLabel, {
		value = ops.SeasonName,
		color = Palette.cyan,
	}), React.createElement(Text, {
		value = "Deep Space Command",
		size = if stack then 24 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, React.createElement(TabRail, {
		active = tab,
		setActive = changeTab,
		reducedMotion = reducedMotion or commandSoft,
		stack = stack,
		columns = tabColumns,
	}))
	local _condition_3 = tab == "Overview"
	if _condition_3 then
		local _exp_6 = React.createElement("frame", {
			Size = UDim2.fromOffset(if stack then 72 else 96, if stack then 72 else 96),
			BackgroundColor3 = Palette.ink,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 14),
		}), React.createElement("uistroke", {
			Color = Palette.cyan,
			Thickness = 2,
			Transparency = 0.25,
		}), React.createElement(Text, {
			value = string.format("%02d", command.Level),
			size = if stack then 28 else 36,
			color = Palette.cyan,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, 0, 0.7, 0),
		}), React.createElement(Text, {
			value = "LVL",
			size = 11,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromScale(0, 0.68),
			sizeConstraint = UDim2.new(1, 0, 0.28, 0),
		}))
		local _attributes = {}
		local _condition_4 = command.Rank
		if _condition_4 == nil then
			_condition_4 = "Commander"
		end
		_attributes.value = _condition_4
		_attributes.size = if stack then 18 else 22
		_attributes.color = Palette.cream
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.fit = false
		_attributes.position = UDim2.fromOffset(if stack then 88 else 114, 4)
		_attributes.sizeConstraint = UDim2.new(1, heroInfoWidth, 0, 28)
		local _exp_7 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, heroH),
			accent = Palette.cyan,
			background = Palette.panelRaised,
			padding = 16,
			layoutOrder = nextOrder(),
			reducedMotion = softMotion,
		}, _exp_6, React.createElement(Text, _attributes), React.createElement(Text, {
			value = if maxed then "Top rank" else `{compactNumber(math.max(0, command.NextLevelXP - command.XP))} XP to next`,
			size = 12,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(if stack then 88 else 114, 36),
			sizeConstraint = UDim2.new(1, heroInfoWidth, 0, 18),
		}), React.createElement(Meter, {
			value = levelProgress,
			color = Palette.cyan,
			reducedMotion = softMotion,
			position = UDim2.fromOffset(if stack then 88 else 114, 60),
			size = UDim2.new(1, heroInfoWidth, 0, 8),
		}), React.createElement(Text, {
			value = `{compactNumber(command.Signals)} signals  ·  {compactNumber(command.ExpeditionsCompleted)} trips  ·  {compactNumber(command.StreakShields)} shields`,
			size = 12,
			color = Palette.creamSoft,
			fit = false,
			wrap = true,
			position = UDim2.fromOffset(0, if stack then 90 else 112),
			sizeConstraint = UDim2.new(1, 0, 0, if stack then 34 else 18),
		}), React.createElement("frame", {
			Name = "CommandClaimActions",
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(210, 46),
			Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -210, 0, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = if nextClaim ~= nil then claimHostRef else nil,
		}, React.createElement(Button, {
			text = if nextClaim ~= nil then `Claim level {nextClaim}` else "Rank gifts complete",
			icon = "Gift",
			onClick = function()
				if nextClaim ~= nil then
					dispatch("ClaimCommanderReward", {
						Level = nextClaim,
					})
				end
			end,
			color = Palette.cyan,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = nextClaim == nil,
			reducedMotion = softMotion,
			highlight = nextClaim ~= nil,
		})))
		local _exp_8 = React.createElement(Text, {
			value = "Crew",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		})
		local _exp_9 = React.createElement(Text, {
			value = "Spend signals to level Pilot, Engineer, and Navigator.",
			size = 12,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(0, 28),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		})
		local _exp_10 = React.createElement(AutoGrid, {
			columns = crewCols,
			cellHeight = crewCellH,
			rowGap = gridGap,
			columnGap = gridGap,
		})
		local _newValue_3 = table.create(#CREW_ROLES)
		local _callback_5 = function(roleId, index)
			local role = ops.Crew[roleId]
			if not role then
				return nil
			end
			local _condition_5 = command.Crew[roleId]
			if _condition_5 == nil then
				_condition_5 = 1
			end
			local level = _condition_5
			local cost = crewCost(role.BaseCost, level)
			local maxRole = level >= role.MaxLevel
			local can = not maxRole and command.Signals >= cost
			return React.createElement("frame", {
				key = roleId,
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement("uistroke", {
				Color = role.Color,
				Thickness = 1,
				Transparency = 0.4,
			}), React.createElement(Text, {
				value = role.Name,
				size = 13,
				color = role.Color,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(10, 8),
				sizeConstraint = UDim2.new(1, -20, 0, 18),
			}), React.createElement(Text, {
				value = if role.MaxLevel >= 1000000000 then `Lv {compactNumber(level)}` else `Lv {compactNumber(level)} / {compactNumber(role.MaxLevel)}`,
				size = 11,
				color = Palette.creamSoft,
				fit = false,
				position = UDim2.fromOffset(10, 30),
				sizeConstraint = UDim2.new(1, -20, 0, 16),
			}), React.createElement(Button, {
				text = if maxRole then "MAX" else `{compactNumber(cost)} sig`,
				onClick = function()
					return dispatch("UpgradeCrew", {
						Role = roleId,
					})
				end,
				color = role.Color,
				textColor = Palette.ink,
				size = UDim2.new(1, -20, 0, if stack then TapTarget else 36),
				position = UDim2.new(0, 10, 1, -(if stack then TapTarget + 8 else 44)),
				disabled = not can,
				reducedMotion = softMotion,
				highlight = can,
			}))
		end
		for _k, _v in CREW_ROLES do
			_newValue_3[_k] = _callback_5(_v, _k - 1, CREW_ROLES)
		end
		local _exp_11 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, crewH),
			accent = Palette.mango,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, _exp_8, _exp_9, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, crewRows * crewCellH + math.max(0, crewRows - 1) * gridGap),
			Position = UDim2.fromOffset(0, 54),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
		}, _exp_10, _newValue_3))
		local _exp_12 = React.createElement(Text, {
			value = "Weekly jobs",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		})
		local _exp_13 = React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #command.Weekly,
			columns = 1,
			cellHeight = weeklyItemH,
			gap = weeklyStride - weeklyItemH,
			overscanRows = if softMotion then 0 else 1,
			position = UDim2.fromOffset(0, 36),
			itemKey = function(index)
				local directive = command.Weekly[index + 1]
				return if directive ~= nil then directive.Id else `weekly-{index}`
			end,
			renderItem = function(index)
				local directive = command.Weekly[index + 1]
				if directive == nil then
					return nil
				end
				local ready = not directive.Claimed and directive.Progress >= directive.Target
				local rewardLine = formatReward(directive.Reward)
				local _exp_14 = React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 10),
				})
				local _exp_15 = React.createElement("uistroke", {
					Color = if ready then Palette.green else Palette.lineSoft,
					Thickness = 1,
					Transparency = 0.45,
				})
				local _exp_16 = React.createElement(Text, {
					value = directive.Name,
					size = 13,
					color = if ready then Palette.green else Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					position = UDim2.fromOffset(12, 8),
					sizeConstraint = UDim2.new(1, if stack then -24 else -156, 0, 18),
				})
				local _attributes_1 = {}
				local _condition_5 = directive.Description
				if _condition_5 == nil then
					_condition_5 = ""
				end
				_attributes_1.value = _condition_5
				_attributes_1.size = 11
				_attributes_1.color = Palette.muted
				_attributes_1.fit = false
				_attributes_1.position = UDim2.fromOffset(12, 28)
				_attributes_1.sizeConstraint = UDim2.new(1, if stack then -24 else -156, 0, 16)
				return React.createElement("frame", {
					Size = UDim2.new(1, 0, 0, weeklyItemH),
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
				}, _exp_14, _exp_15, _exp_16, React.createElement(Text, _attributes_1), React.createElement(Text, {
					value = if rewardLine ~= "" then rewardLine else `{compactNumber(directive.Progress)} / {compactNumber(directive.Target)}`,
					size = 10,
					color = Palette.creamSoft,
					wrap = true,
					fit = false,
					position = UDim2.fromOffset(12, 46),
					sizeConstraint = UDim2.new(1, if stack then -24 else -156, 0, 28),
				}), React.createElement(Meter, {
					value = meterFill(directive.Progress, directive.Target, directive.Claimed or ready),
					color = Palette.green,
					reducedMotion = reducedMotion,
					position = UDim2.fromOffset(12, if stack then 78 else 76),
					size = UDim2.new(1, if stack then -24 else -156, 0, 7),
				}), if stack then React.createElement("frame", {
					Name = "CommandClaimActions",
					Size = UDim2.new(1, -24, 0, TapTarget),
					Position = UDim2.new(0, 12, 1, -(TapTarget + 8)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = if ready and nextClaim == nil and directive.Id == firstReadyWeeklyId then claimHostRef else nil,
				}, React.createElement(Button, {
					text = if directive.Claimed then "DONE" elseif ready then "CLAIM" else "OPEN",
					onClick = function()
						return dispatch("ClaimWeeklyDirective", {
							Id = directive.Id,
						})
					end,
					color = Palette.green,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					disabled = directive.Claimed or not ready,
					reducedMotion = reducedMotion,
					highlight = ready,
				})) else React.createElement("frame", {
					Name = "CommandClaimActions",
					Size = UDim2.fromOffset(140, 44),
					Position = UDim2.new(1, -150, 0.5, -22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = if ready and nextClaim == nil and directive.Id == firstReadyWeeklyId then claimHostRef else nil,
				}, React.createElement(Button, {
					text = if directive.Claimed then "DONE" elseif ready then "CLAIM" else "OPEN",
					onClick = function()
						return dispatch("ClaimWeeklyDirective", {
							Id = directive.Id,
						})
					end,
					color = Palette.green,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					disabled = directive.Claimed or not ready,
					reducedMotion = reducedMotion,
					highlight = ready,
				})))
			end,
		})
		local _exp_14 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, weeklyH),
			accent = Palette.green,
			background = Palette.panel,
			padding = 14,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
			clips = false,
		}, _exp_12, _exp_13)
		local _exp_15 = React.createElement(Text, {
			value = "Title wardrobe",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, -164, 0, 24),
		})
		local _result_5
		if titlesEnabled then
			_result_5 = React.createElement(React.Fragment, nil, React.createElement(Text, {
				value = "Every card is a live preview of the name, motion, shine, and color you will wear.",
				size = 11,
				color = Palette.muted,
				fit = false,
				position = UDim2.fromOffset(0, 26),
				sizeConstraint = UDim2.new(1, 0, 0, 18),
			}), React.createElement(VirtualGrid, {
				scrollRef = scrollRef,
				count = #command.Titles,
				columns = titleCols,
				cellHeight = titleCellH,
				gap = gridGap,
				overscanRows = 1,
				position = UDim2.fromOffset(0, 52),
				itemKey = function(index)
					local title = command.Titles[index + 1]
					return if title ~= nil then title.Id else `title-{index}`
				end,
				renderItem = function(index)
					local title = command.Titles[index + 1]
					if title == nil then
						return nil
					end
					local _condition_5 = title.Fx
					if _condition_5 == nil then
						_condition_5 = TITLE_FX_FALLBACKS[index % #TITLE_FX_FALLBACKS + 1]
					end
					local titleFx = _condition_5
					return React.createElement(CommandTitleCard, {
						id = title.Id,
						name = title.Name,
						description = title.Description,
						unlocked = title.Unlocked,
						equipped = title.Equipped,
						fx = titleFx,
						stack = stack,
						reducedMotion = reducedMotion,
						dispatch = dispatch,
					})
				end,
			}))
		else
			local _exp_16 = React.createElement(Badge, {
				value = "TEMPORARILY CLOSED",
				accent = Palette.muted,
				size = UDim2.fromOffset(152, 26),
				position = UDim2.new(1, -152, 0, 0),
			})
			local _attributes_1 = {}
			local _condition_5 = ops.TitleStatus
			if _condition_5 == nil then
				_condition_5 = "Titles are temporarily unavailable."
			end
			_attributes_1.value = _condition_5
			_attributes_1.size = 12
			_attributes_1.color = Palette.muted
			_attributes_1.wrap = true
			_attributes_1.fit = false
			_attributes_1.position = UDim2.fromOffset(0, 36)
			_attributes_1.sizeConstraint = UDim2.new(1, 0, 0, 44)
			_result_5 = React.createElement(React.Fragment, nil, _exp_16, React.createElement(Text, _attributes_1))
		end
		_condition_3 = React.createElement(TabPane, {
			tabKey = "Overview",
			reducedMotion = reducedMotion,
		}, _exp_7, _exp_11, _exp_14, React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, titlesH),
			accent = if titlesEnabled then Palette.violet else Palette.muted,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, _exp_15, _result_5), React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, shopH),
			accent = Palette.mango,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, React.createElement(Text, {
			value = `Signal shop · {compactNumber(command.Signals)} ready`,
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		}), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #command.Shop,
			columns = shopCols,
			cellHeight = shopCellH,
			gap = gridGap,
			position = UDim2.fromOffset(0, 36),
			itemKey = function(index)
				local offer = command.Shop[index + 1]
				return if offer ~= nil then offer.Id else `shop-{index}`
			end,
			renderItem = function(index)
				local offer = command.Shop[index + 1]
				if offer == nil then
					return nil
				end
				local can = not offer.Purchased and command.Signals >= offer.Price
				return React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
					Active = false,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 10),
				}), React.createElement("uistroke", {
					Color = offer.Color,
					Thickness = 1,
					Transparency = 0.35,
				}), React.createElement(Text, {
					value = offer.Name,
					size = 12,
					color = offer.Color,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(8, 8),
					sizeConstraint = UDim2.new(1, -16, 0, 20),
				}), React.createElement(Text, {
					value = formatReward(offer.Reward),
					size = 11,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(8, 34),
					sizeConstraint = UDim2.new(1, -16, 0, 40),
				}), React.createElement(Button, {
					text = if offer.Purchased then "BOUGHT" else `{offer.Price} sig`,
					onClick = function()
						return dispatch("BuySignalOffer", {
							Id = offer.Id,
						})
					end,
					color = offer.Color,
					textColor = Palette.ink,
					size = UDim2.new(1, -16, 0, if stack then TapTarget else 40),
					position = UDim2.new(0, 8, 1, -(if stack then TapTarget + 8 else 48)),
					disabled = not can,
					reducedMotion = reducedMotion,
					highlight = can,
				}))
			end,
		})), React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, masteryH),
			accent = Palette.blue,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, React.createElement(Text, {
			value = "Machine mastery",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		}), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #config.Machines,
			columns = masteryCols,
			cellHeight = masteryCellH,
			gap = gridGap,
			position = UDim2.fromOffset(0, 36),
			itemKey = function(index)
				local machine = config.Machines[index + 1]
				return if machine ~= nil then machine.Id else `machine-{index}`
			end,
			renderItem = function(index)
				local machine = config.Machines[index + 1]
				if machine == nil then
					return nil
				end
				local _condition_5 = command.MachineMastery[machine.Id]
				if _condition_5 == nil then
					_condition_5 = 0
				end
				local mastery = _condition_5
				local rank = math.floor(math.sqrt(mastery))
				local nextRank = math.pow(rank + 1, 2)
				local fill = if rank >= 99 then 1 else (mastery - rank * rank) / math.max(1, nextRank - rank * rank)
				return React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
					Active = false,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 10),
				}), React.createElement(Text, {
					value = machine.Name,
					size = 12,
					color = Palette.cream,
					weight = Enum.FontWeight.Bold,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(8, 6),
					sizeConstraint = UDim2.new(1, -70, 0, 18),
				}), React.createElement(Badge, {
					value = `RANK {rank}`,
					accent = machine.Color,
					filled = true,
					position = UDim2.new(1, -58, 0, 6),
					size = UDim2.fromOffset(48, 20),
				}), React.createElement(Meter, {
					value = fill,
					color = machine.Color,
					reducedMotion = reducedMotion,
					position = UDim2.fromOffset(8, 34),
					size = UDim2.new(1, -16, 0, 6),
				}), React.createElement(Text, {
					value = `{compactNumber(mastery)} built`,
					size = 10,
					color = Palette.muted,
					fit = false,
					position = UDim2.fromOffset(8, 44),
					sizeConstraint = UDim2.new(1, -16, 0, 14),
				}))
			end,
		})))
	end
	local _condition_4 = tab == "Expeditions"
	if _condition_4 then
		local _exp_6 = React.createElement(Text, {
			value = "Active trip",
			size = 12,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 16),
		})
		local _attributes = {}
		local _result_5 = activeConfig
		if _result_5 ~= nil then
			_result_5 = _result_5.Name
		end
		local _condition_5 = _result_5
		if _condition_5 == nil then
			_condition_5 = "No trip underway"
		end
		_attributes.value = _condition_5
		_attributes.size = if stack then 18 else 22
		_attributes.color = if expeditionReady then Palette.green else Palette.cream
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.fit = false
		_attributes.position = UDim2.fromOffset(0, 22)
		_attributes.sizeConstraint = UDim2.new(1, if stack then 0 else -230, 0, 28)
		_condition_4 = React.createElement(TabPane, {
			tabKey = "Expeditions",
			reducedMotion = reducedMotion,
		}, React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, expeditionHeroH),
			accent = if expeditionReady then Palette.green else Palette.cyan,
			background = Palette.panelRaised,
			padding = 14,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, _exp_6, React.createElement(Text, _attributes), React.createElement(Text, {
			value = statusLine,
			size = 12,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(0, 54),
			sizeConstraint = UDim2.new(1, if stack then 0 else -230, 0, 18),
		}), React.createElement(Meter, {
			value = expeditionProgress,
			color = if expeditionReady then Palette.green else Palette.cyan,
			reducedMotion = reducedMotion,
			position = UDim2.fromOffset(0, 80),
			size = UDim2.new(1, if stack then 0 else -230, 0, 8),
		}), React.createElement("frame", {
			Name = "CommandClaimActions",
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(210, 48),
			Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -210, 0.5, -24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = if expeditionReady then claimHostRef else nil,
		}, React.createElement(Button, {
			text = claimLabel,
			icon = "Gift",
			onClick = function()
				return dispatch("ClaimExpedition")
			end,
			color = Palette.green,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = not expeditionReady,
			reducedMotion = reducedMotion,
			highlight = expeditionReady,
		}))), React.createElement(Browse.BrowseBar, {
			browse = expeditionBrowse,
			placeholder = "Search adventures by name or reward",
			accent = Palette.cyan,
			stack = stack,
			reducedMotion = softMotion,
			layoutOrder = nextOrder(),
			zIndex = 30,
		}), #expeditionList == 0 and React.createElement(Browse.NoResults, {
			browse = expeditionBrowse,
			noun = "adventures",
			icon = "World",
			accent = Palette.cyan,
			reducedMotion = softMotion,
			layoutOrder = nextOrder(),
		}), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #expeditionList,
			columns = 1,
			cellHeight = expeditionRowH,
			gap = Layout.panelGap,
			overscanRows = if softMotion then 0 else 1,
			layoutOrder = nextOrder(),
			itemKey = function(index)
				local expedition = expeditionList[index + 1]
				return if expedition ~= nil then expedition.Id else `expedition-{index}`
			end,
			renderItem = function(index)
				local expedition = expeditionList[index + 1]
				if expedition == nil then
					return nil
				end
				local locked = command.Level < expedition.RequiredLevel
				local busy = activeId ~= ""
				local can = not locked and not busy
				local _attributes_1 = {}
				local _condition_6 = expedition.ArtifactId
				if _condition_6 == nil then
					_condition_6 = expedition.Id
				end
				_attributes_1.kind = artifactIcon(_condition_6)
				_attributes_1.accent = expedition.Color
				_attributes_1.size = 46
				_attributes_1.radius = 12
				_attributes_1.position = UDim2.fromOffset(0, if stack then 6 else 18)
				_attributes_1.reducedMotion = reducedMotion
				return React.createElement(Panel, {
					size = UDim2.new(1, 0, 0, expeditionRowH),
					accent = expedition.Color,
					background = Palette.panel,
					padding = 14,
					interactive = true,
					highlight = can,
					reducedMotion = reducedMotion,
				}, React.createElement(IconTile, _attributes_1), React.createElement(Text, {
					value = `Lv {expedition.RequiredLevel}  ·  {clockText(math.max(10, math.floor(expedition.Duration * math.max(0.35, 1 - ((command.Crew.Pilot or 1) - 1) * 0.05))))}`,
					size = 11,
					color = expedition.Color,
					weight = Enum.FontWeight.Bold,
					fit = false,
					position = UDim2.fromOffset(58, 4),
					sizeConstraint = UDim2.new(1, if stack then -70 else -224, 0, 16),
				}), React.createElement(Text, {
					value = expedition.Name,
					size = 17,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					position = UDim2.fromOffset(58, 24),
					sizeConstraint = UDim2.new(1, if stack then -70 else -224, 0, 24),
				}), React.createElement(Text, {
					value = `{formatReward(expedition.Reward)}  ·  {string.format("%.0f", expedition.ArtifactChance * 100)}% relic`,
					size = 11,
					color = Palette.muted,
					wrap = true,
					fit = false,
					position = UDim2.fromOffset(58, 52),
					sizeConstraint = UDim2.new(1, if stack then -70 else -224, 0, 28),
				}), React.createElement(Button, {
					text = if locked then `Need lv {expedition.RequiredLevel}` elseif busy then "Crew away" else "LAUNCH",
					onClick = function()
						return dispatch("LaunchExpedition", {
							Id = expedition.Id,
						})
					end,
					color = expedition.Color,
					textColor = Palette.ink,
					size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(200, 46),
					position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -210, 0.5, -23),
					disabled = not can,
					reducedMotion = reducedMotion,
					highlight = can,
				}))
			end,
		}))
	end
	local bodyPane = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, _exp_3, _condition_3, _condition_4, tab == "Artifacts" and React.createElement(TabPane, {
		tabKey = "Artifacts",
		reducedMotion = reducedMotion,
	}, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, artifactHeroH),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = nextOrder(),
		reducedMotion = reducedMotion,
	}, React.createElement(Text, {
		value = `Relics  {ownedArtifacts}/{#ops.Artifacts}`,
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = "Equip one relic. Duplicates add spark fragments for upgrades.",
		size = 12,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Meter, {
		value = ownedArtifacts / math.max(1, #ops.Artifacts),
		color = Palette.violet,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, 68),
		size = UDim2.new(1, 0, 0, 8),
	})), React.createElement(VirtualGrid, {
		scrollRef = scrollRef,
		count = #ops.Artifacts,
		columns = 1,
		cellHeight = artifactRowH,
		gap = Layout.panelGap,
		layoutOrder = nextOrder(),
		itemKey = function(index)
			local artifact = ops.Artifacts[index + 1]
			return if artifact ~= nil then artifact.Id else `artifact-{index}`
		end,
		renderItem = function(index)
			local artifact = ops.Artifacts[index + 1]
			if artifact == nil then
				return nil
			end
			local owned = command.Artifacts[artifact.Id]
			local equipped = command.EquippedArtifact == artifact.Id
			local fragmentCost = if owned then 4 + owned.Level * 2 else 0
			local dustCost = if owned then 8 * owned.Level else 0
			local canUpgrade = owned ~= nil and owned.Level < 10 and owned.Fragments >= fragmentCost and gteFlux(state.Stardust, dustCost)
			return React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, artifactRowH),
				accent = if owned then artifact.Color else Palette.lineSoft,
				background = if owned then Palette.panel else Palette.panelSoft,
				padding = 14,
				reducedMotion = reducedMotion,
			}, React.createElement("frame", {
				Name = "ElementTile",
				Size = UDim2.fromOffset(48, 48),
				Position = UDim2.fromOffset(0, if stack then 5 else 17),
				BackgroundColor3 = Palette.void,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 12),
			}), React.createElement("uistroke", {
				Color = if owned then (elementSheet(artifact.Element) or { Color = artifact.Color }).Color else Palette.lineSoft,
				Transparency = if equipped then 0 else 0.45,
				Thickness = if equipped then 2 else 1,
			}), React.createElement(ElementFx, {
				element = artifact.Element,
				size = UDim2.fromOffset(48, 48),
				position = UDim2.fromScale(0.5, 0.5),
				-- undiscovered relics show a dim still of their element
				still = not owned,
				transparency = if owned then 0 else 0.7,
				reducedMotion = reducedMotion,
				-- discovering the relic reveals its companion
				reaction = "reveal",
				reactionKey = owned ~= nil and owned ~= false,
			})), React.createElement(Text, {
				value = if owned then `{artifact.Rarity}  ·  {(elementSheet(artifact.Element) or { Label = "" }).Label}  ·  Lv {owned.Level}/10` else artifact.Rarity,
				size = 11,
				color = if owned then artifact.Color else Palette.muted,
				weight = Enum.FontWeight.Bold,
				fit = false,
				position = UDim2.fromOffset(58, 4),
				sizeConstraint = UDim2.new(1, if stack then -70 else -286, 0, 16),
			}), React.createElement(Text, {
				value = if owned then artifact.Name else "Mystery relic",
				size = 17,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(58, 24),
				sizeConstraint = UDim2.new(1, if stack then -70 else -286, 0, 24),
			}), React.createElement(Text, {
				value = if owned then `{artifactEffect(artifact, owned.Level)}  ·  {owned.Fragments}/{fragmentCost} sparks` else "Finish its expedition to discover it.",
				size = 11,
				color = Palette.muted,
				fit = false,
				position = UDim2.fromOffset(58, 52),
				sizeConstraint = UDim2.new(1, if stack then -70 else -286, 0, 18),
			}), React.createElement("frame", {
				Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(260, 46),
				Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -270, 0.5, -23),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = if equipped then "IN USE" else "EQUIP",
				onClick = function()
					return dispatch("EquipArtifact", {
						Id = artifact.Id,
					})
				end,
				color = artifact.Color,
				textColor = Palette.ink,
				size = UDim2.new(0.5, -4, 1, 0),
				disabled = not owned or equipped,
				reducedMotion = reducedMotion,
			}), React.createElement(Button, {
				text = if not owned then "—" elseif owned.Level >= 10 then "MAX" else `{dustCost} dust`,
				onClick = function()
					return dispatch("UpgradeArtifact", {
						Id = artifact.Id,
					})
				end,
				color = Palette.mango,
				textColor = Palette.ink,
				size = UDim2.new(0.5, -4, 1, 0),
				position = UDim2.new(0.5, 4, 0, 0),
				disabled = not canUpgrade,
				reducedMotion = reducedMotion,
				highlight = canUpgrade,
			})))
		end,
	})), tab == "Season" and React.createElement(TabPane, {
		tabKey = "Season",
		reducedMotion = reducedMotion,
	}, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, seasonHeroH),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = nextOrder(),
		reducedMotion = reducedMotion,
	}, React.createElement(Text, {
		value = ops.SeasonName,
		size = 22,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = `{compactNumber(command.SeasonXP)} season XP · {#ops.SeasonTiers} gifts`,
		size = 12,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 36),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Meter, {
		value = seasonFill,
		color = Palette.mango,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, 64),
		size = UDim2.new(1, 0, 0, 9),
	}), React.createElement(Text, {
		value = seasonStatus,
		size = 12,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 82),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), React.createElement(VirtualGrid, {
		scrollRef = scrollRef,
		count = #ops.SeasonTiers,
		columns = 1,
		cellHeight = seasonRowH,
		gap = Layout.panelGap,
		overscanRows = if softMotion then 0 else 1,
		layoutOrder = nextOrder(),
		itemKey = function(index)
			local tier = ops.SeasonTiers[index + 1]
			return if tier ~= nil then tostring(tier.Tier) else `tier-{index}`
		end,
		renderItem = function(index)
			local tier = ops.SeasonTiers[index + 1]
			if tier == nil then
				return nil
			end
			local unlocked = command.SeasonXP >= tier.RequiredXP
			local claimed = command.SeasonClaims[tostring(tier.Tier)] == true
			local major = tier.Tier % 5 == 0
			local progressLabel = if claimed then "COLLECTED" elseif unlocked then "READY TO OPEN" else `{compactNumber(math.min(command.SeasonXP, tier.RequiredXP))} / {compactNumber(tier.RequiredXP)} XP`
			return React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, seasonRowH),
				accent = if major then Palette.mango elseif unlocked then Palette.green else Palette.lineSoft,
				background = if major then Palette.panelRaised else Palette.panel,
				padding = 12,
				reducedMotion = reducedMotion,
			}, React.createElement("frame", {
				Size = UDim2.fromOffset(56, 56),
				BackgroundColor3 = if claimed then Palette.green elseif unlocked then Palette.mango else Palette.panelSoft,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement(Text, {
				value = string.format("%02d", tier.Tier),
				size = 20,
				color = if claimed or unlocked then Palette.ink else Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
			})), React.createElement(Text, {
				value = if major then "Major gift" else "Rank gift",
				size = 14,
				color = if major then Palette.mango else Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(72, 8),
				sizeConstraint = UDim2.new(1, if stack then -(72 + 24) else -250, 0, 20),
			}), React.createElement(Text, {
				value = formatReward(tier.Reward),
				size = 12,
				color = Palette.muted,
				wrap = true,
				fit = false,
				position = UDim2.fromOffset(72, 32),
				sizeConstraint = UDim2.new(1, if stack then -(72 + 24) else -250, 0, 28),
			}), React.createElement(Meter, {
				value = meterFill(command.SeasonXP, tier.RequiredXP, claimed or unlocked),
				color = if major then Palette.mango else Palette.green,
				reducedMotion = reducedMotion,
				position = UDim2.fromOffset(72, if stack then 64 else 72),
				size = UDim2.new(1, if stack then -84 else -250, 0, 7),
			}), if stack then React.createElement("frame", {
				Name = "CommandClaimActions",
				Size = UDim2.new(1, -24, 0, TapTarget),
				Position = UDim2.new(0, 12, 1, -(TapTarget + 8)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ref = if unlocked and not claimed and tier.Tier == firstReadySeasonTier then claimHostRef else nil,
			}, React.createElement(Button, {
				text = if claimed then "CLAIMED" elseif unlocked then "OPEN" else "LOCKED",
				onClick = function()
					return dispatch("ClaimSeasonTier", {
						Tier = tier.Tier,
					})
				end,
				color = if major then Palette.mango else Palette.green,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				disabled = claimed or not unlocked,
				reducedMotion = reducedMotion,
				highlight = unlocked and not claimed,
			})) else React.createElement(React.Fragment, nil, React.createElement(Text, {
				value = progressLabel,
				size = 11,
				color = if unlocked then Palette.green else Palette.muted,
				fit = false,
				position = UDim2.fromOffset(72, 54),
				sizeConstraint = UDim2.new(1, -250, 0, 16),
			}), React.createElement("frame", {
				Name = "CommandClaimActions",
				Size = UDim2.fromOffset(150, 44),
				Position = UDim2.new(1, -158, 0.5, -22),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ref = if unlocked and not claimed and tier.Tier == firstReadySeasonTier then claimHostRef else nil,
			}, React.createElement(Button, {
				text = if claimed then "CLAIMED" elseif unlocked then "OPEN" else "LOCKED",
				onClick = function()
					return dispatch("ClaimSeasonTier", {
						Tier = tier.Tier,
					})
				end,
				color = if major then Palette.mango else Palette.green,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				disabled = claimed or not unlocked,
				reducedMotion = reducedMotion,
				highlight = unlocked and not claimed,
			}))))
		end,
	})))
	local bodyIntrinsic = if useFillList then tabHeroH + listContent + Layout.panelGap else tabContent
	return React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = Layout.panelGap,
		tailPad = commandTail,
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = headerH,
				element = _exp_4,
			},
			{
				id = "tabs",
				height = tabsH,
				element = _exp_5,
			},
			{
				id = "body",
				fill = true,
				minHeight = 200,
				height = bodyIntrinsic,
				element = bodyPane,
			},
		},
	})
end
local function CommandView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onSectionChange = _param.onSectionChange
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local overviewReveal = useStagger(0, softMotion)
	local expeditionsReveal = useStagger(1, softMotion)
	local opsReveal = useStagger(2, softMotion)
	local commandSoft = softMotion or overviewReveal == nil or expeditionsReveal == nil or opsReveal == nil
	local claimHostRef = React.useRef(nil)
	local stack = chrome.contentStack
	local ops = config.Operations
	local command = state.Command
	local tab, setTab = React.useState("Overview")
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local scrollRef = React.useRef()
	React.useEffect(function()
		if tab ~= "Expeditions" then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(1)
				if not alive then
					break
				end
				setNow(workspace:GetServerTimeNow())
			end
		end)
		return function()
			alive = false
			pcall(function()
				task.cancel(worker)
			end)
		end
	end, { tab })
	React.useEffect(function()
		local frame = scrollRef.current
		if frame then
			frame.CanvasPosition = Vector2.new(0, 0)
		end
	end, { tab })
	if not ops or not command then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, React.createElement(Text, {
			value = "Loading your crew…",
			size = 16,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	return React.createElement(CommandViewReady, _param)
end
return {
	CommandView = CommandView,
}
end

__defs["AdminView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local _adminFields = require(script.Parent.Parent.CoreKit)("adminFields")
local fieldsFor = _adminFields.fieldsFor
local reasonsFor = _adminFields.reasonsFor
local compactNumber = require(script.Parent.Parent.CoreKit)("format").compactNumber
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local Panel = _ui.Panel
local SearchField = _ui.SearchField
local Text = _ui.Text
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold

local GAP = 14
local HEADER_H = 92
local PLAYERS_W = 280
local DETAIL_W = 340
local CMD_MIN = 360
local CONSOLE_W = PLAYERS_W + DETAIL_W + CMD_MIN + GAP * 2
local RECENT_MIN = 200
local PLAYER_ROW = 56
local PLAYER_ROW_STRIDE = PLAYER_ROW + 6
local COMMAND_ROW = 48
local COMMAND_ROW_STRIDE = COMMAND_ROW + 6
local SCROLL_BAR = 4

local ADMIN_CATS = {
	{ id = "All", label = "ALL" },
	{ id = "Economy", label = "ECON" },
	{ id = "Progress", label = "PROG" },
	{ id = "Items", label = "ITEMS" },
	{ id = "Resets", label = "RESET" },
	{ id = "Troll", label = "TROLL" },
	{ id = "Moderation", label = "MOD" },
}

local function hayHas(hay, needle)
	if #needle == 0 then
		return true
	end
	-- exact substrings (player IDs) still match; fuzzy matching adds typos and initials
	if (string.find(string.lower(hay), string.lower(needle), 1, true)) ~= nil then
		return true
	end
	return require(script.Parent.Parent.BrowseKit).matches(needle, hay)
end

local function catAccent(category)
	if category == "Economy" then return Palette.mint end
	if category == "Progress" then return Palette.cyan end
	if category == "Items" then return Palette.violet end
	if category == "Resets" then return Palette.mango end
	if category == "Troll" then return Palette.pink end
	if category == "Moderation" then return Palette.coral end
	return Palette.steel
end

local function commandNeedsArm(entry)
	if entry == nil then return true end
	if entry.Danger == "quick" then return false end
	if entry.Danger == "arm" then return true end
	local category = entry.Category or "Economy"
	return category == "Troll" or category == "Resets" or category == "Moderation"
end

local function SectionTitle(_param)
	return React.createElement(Text, {
		value = _param.value,
		size = 10,
		color = _param.accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = _param.position or UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, -8, 0, 13),
		layoutOrder = _param.layoutOrder,
	})
end

local function StatCell(_param)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = _param.label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(10, 6),
		sizeConstraint = UDim2.new(1, -16, 0, 11),
	}), React.createElement(Text, {
		value = _param.value,
		size = 14,
		color = _param.accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, 19),
		sizeConstraint = UDim2.new(1, -16, 0, 18),
	}))
end

local function PlayerRow(_param)
	local player = _param.player
	local selected = _param.selected
	local you = _param.you
	local onClick = _param.onClick
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local accent = if selected then Palette.mint else Palette.lineSoft
	local reveal = useStagger(layoutOrder, reducedMotion)

	return React.createElement("textbutton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, PLAYER_ROW),
		BackgroundTransparency = reveal:map(function(amount)
			return (if selected then 0 else 0.12) + (1 - math.clamp(amount, 0, 1)) * (1 - (if selected then 0 else 0.12))
		end),
		BackgroundColor3 = if selected then Palette.panelRaised else Palette.panel,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play("playerlistSelect")
				onClick()
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = if selected then 0.45 else 1,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(12, 10),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Icon, {
		kind = "Crew",
		color = if selected then Palette.mint else Palette.muted,
		accent = Palette.mint,
		size = 18,
		spin = false,
		position = UDim2.fromOffset(9, 9),
	})), React.createElement(Text, {
		value = if you then `{player.DisplayName}  ·  YOU` else player.DisplayName,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(58, 9),
		sizeConstraint = UDim2.new(1, -70, 0, 17),
	}), React.createElement(Text, {
		value = `@{player.Name}  ·  {compactNumber(player.Cash or 0)}`,
		size = 10,
		color = Palette.cyan,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(58, 28),
		sizeConstraint = UDim2.new(1, -70, 0, 14),
	}), selected and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -20, 0.5, -4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end

local function CommandRow(_param)
	local entry = _param.entry
	local selected = _param.selected
	local onClick = _param.onClick
	local accent = catAccent(entry.Category)
	local arm = commandNeedsArm(entry)

	return React.createElement("textbutton", {
		Size = UDim2.new(1, -4, 0, COMMAND_ROW - 6),
		BackgroundColor3 = if selected then Palette.panelRaised else Palette.panel,
		BackgroundTransparency = if selected then 0 else 0.08,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				onClick()
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("uistroke", {
		Color = if selected then accent else Palette.line,
		Thickness = 1,
		Transparency = if selected then 0.3 else 0.78,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 4, 1, -14),
		Position = UDim2.fromOffset(0, 7),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = entry.Label,
		size = 12,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(15, 6),
		sizeConstraint = UDim2.new(1, -104, 0, 16),
	}), React.createElement(Text, {
		value = string.upper(entry.Category or "ECON"),
		size = 9,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -92, 0, 7),
		sizeConstraint = UDim2.fromOffset(80, 12),
	}), React.createElement(Text, {
		value = if arm then "ARM" else "RUN",
		size = 8,
		color = if arm then Palette.mango else Palette.mint,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -92, 0, 21),
		sizeConstraint = UDim2.fromOffset(80, 12),
	}))
end

local function AuditLine(_param)
	local record = _param.record
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = record.Command,
		size = 10,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		sizeConstraint = UDim2.new(0.42, -4, 1, 0),
	}), React.createElement(Text, {
		value = `{record.ActorName} → {record.TargetName}`,
		size = 9,
		color = Palette.cyan,
		fit = true,
		minSize = 8,
		position = UDim2.new(0.42, 4, 0, 0),
		sizeConstraint = UDim2.new(0.58, -4, 1, 0),
	}))
end

local function AdminViewReady(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local admin = state.Admin

	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion

	local targetId, setTargetId = React.useState((admin and admin.SelfUserId) or (admin and admin.Online and admin.Online[1] and admin.Online[1].UserId) or 0)
	local command, setCommand = React.useState((admin and admin.Commands and admin.Commands[1] and admin.Commands[1].Id) or "GrantFlux")
	local category, setCategory = React.useState("All")
	local playerQuery, setPlayerQuery = React.useState("")
	local commandQuery, setCommandQuery = React.useState("")
	local amount, setAmount = React.useState("1000")
	local option, setOption = React.useState("")
	local reason, setReason = React.useState(reasonsFor("GrantFlux", "Economy")[1].id)
	local armed, setArmed = React.useState(false)
	local busy, setBusy = React.useState(false)
	local busyRef = React.useRef(false)
	local shakeToken, setShakeToken = React.useState(0)
	local lastNote, setLastNote = React.useState((admin and admin.LastAction and admin.LastAction.Message) or "")
	local lastOk, setLastOk = React.useState((admin and admin.LastAction and admin.LastAction.Ok) or true)
	local previewLines, setPreviewLines = React.useState({} :: { string })
	local mountedRef = React.useRef(true)
	local executeAttempt = React.useRef(0)
	local enter = useEntrance(softMotion)
	local toolsReveal = useStagger(0, softMotion)

	React.useEffect(function()
		return function()
			mountedRef.current = false
			executeAttempt.current += 1
		end
	end, {})

	React.useEffect(function()
		if targetId == 0 and admin and admin.SelfUserId then
			setTargetId(admin.SelfUserId)
		end
	end, { admin and admin.SelfUserId, targetId })

	React.useEffect(function()
		local online = (admin and admin.Online) or {}
		if #online == 0 then return end
		local found = false
		for _, p in online do
			if p.UserId == targetId then found = true break end
		end
		if not found then
			setTargetId((admin and admin.SelfUserId) or online[1].UserId)
		end
	end, { admin and admin.Online, admin and admin.SelfUserId, targetId })

	React.useEffect(function()
		local commands = (admin and admin.Commands) or {}
		if #commands == 0 then return end
		local found = false
		for _, c in commands do
			if c.Id == command then found = true break end
		end
		if not found then
			setCommand(commands[1].Id or "GrantFlux")
		end
	end, { admin and admin.Commands, command })

	React.useEffect(function()
		setArmed(false)
		setPreviewLines({})
	end, { amount, command, option, reason, targetId })

	React.useEffect(function()
		local layout = fieldsFor(command, config, admin and admin.Banned)
		local commands = (admin and admin.Commands) or {}
		local current = nil
		for _, c in commands do
			if c.Id == command then current = c break end
		end
		local reasonChoices = reasonsFor(command, current and current.Category)
		setAmount(layout.defaultAmount)
		setOption(layout.defaultOption)
		setReason(reasonChoices[1] and reasonChoices[1].id or "Owner gameplay administration")
		if layout.overridesTarget and layout.defaultAmount ~= "" then
			local userId = tonumber(layout.defaultAmount)
			if userId then setTargetId(userId) end
		end
	end, { command })

	React.useEffect(function()
		if not (admin and admin.LastAction) then return end
		setLastNote(admin.LastAction.Message)
		setLastOk(admin.LastAction.Ok)
	end, { admin and admin.LastAction })


	local online = admin.Online or {}
	local commands = admin.Commands or {}
	local shownPlayers = {}
	for _, p in online do
		if hayHas(`{p.DisplayName} {p.Name} {p.UserId}`, playerQuery) then
			table.insert(shownPlayers, p)
		end
	end
	local shownCommands = {}
	for _, c in commands do
		local catOk = category == "All" or (c.Category or "Economy") == category
		if catOk and hayHas(`{c.Id} {c.Label} {c.Category or ""}`, commandQuery) then
			table.insert(shownCommands, c)
		end
	end
	local recent = admin.Recent or {}
	local selected = nil
	for _, c in commands do
		if c.Id == command then selected = c break end
	end
	local selectedPlayer = nil
	for _, p in online do
		if p.UserId == targetId then selectedPlayer = p break end
	end
	local fields = fieldsFor(command, config, admin.Banned)
	local needsArm = commandNeedsArm(selected)
	local accent = catAccent(selected and selected.Category)
	local integrity = admin.Integrity
	local reasonChoices = reasonsFor(command, selected and selected.Category)
	local fieldSlots = (if fields.usesAmount then 1 else 0) + (if fields.usesOption then 1 else 0) + (if needsArm then 1 else 0)

	local send = function(dryRun: boolean)
		busyRef.current = true
		setBusy(true)
		local attempt = executeAttempt.current + 1
		executeAttempt.current = attempt
		Audio:play(if dryRun then "click" else "adminExecute")
		local sendAmount = if amount == "Permanent" then "1" else (if amount ~= "" then amount else "1")
		local sendOption = if amount == "Permanent" then "Permanent" else option
		local sendTarget = if fields.overridesTarget then (tonumber(amount) or targetId) else targetId
		dispatch("AdminExecute", {
			TargetUserId = sendTarget,
			Command = command,
			Amount = sendAmount,
			Option = sendOption,
			Reason = reason,
			DryRun = dryRun,
			Nonce = HttpService:GenerateGUID(false),
		}, function(response)
			if not mountedRef.current or executeAttempt.current ~= attempt then return end
			busyRef.current = false
			setBusy(false)
			if not dryRun then setArmed(false) end
			setLastOk(response.ok == true)
			setLastNote(if response.ok == true then (response.message or "Done.") else (response.error or "Failed."))
			setPreviewLines(if dryRun and response.ok == true and type(response.Preview) == "table" then response.Preview else {})
			if response.ok ~= true then
				setShakeToken(function(t) return t + 1 end)
			end
		end)
	end

	local execute = function()
		if busyRef.current then return end
		if needsArm and not armed then
			setArmed(true)
			Audio:play("adminArm")
			return
		end
		send(false)
	end

	local preview = function()
		if busyRef.current then return end
		send(true)
	end

	local runDisabled = busy or (if fields.overridesTarget then #fields.amountChoices == 0 else targetId == 0) or (needsArm and #reason < 3)
	local runLabel = if busy then "APPLYING…" elseif needsArm and not armed then "ARM" else "RUN"
	local runColor = if busy then Palette.panelSoft elseif needsArm and armed then Palette.coral elseif needsArm then Palette.mango else Palette.mint

	local FIELD_H = 50
	local EXEC_TITLE = 120
	local EXEC_BUTTON = 46
	local EXEC_NOTE = 36 + math.min(#previewLines, 6) * 14
	local executeH = EXEC_TITLE + math.max(0, fieldSlots) * FIELD_H + EXEC_BUTTON + EXEC_NOTE + 20

	local INSPECT_TITLE = 34
	local STAT_H = 40
	local STAT_GAP = 8
	local inspectH = INSPECT_TITLE + STAT_H * 2 + STAT_GAP + 26

	local header = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, HEADER_H),
		accent = Palette.coral,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 0,
		reveal = enter,
			reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "ADMIN",
		size = 9,
		color = Palette.coral,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(0, 70, 0, 12),
	}), React.createElement(Text, {
		value = "Owner Console",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 13),
		sizeConstraint = UDim2.new(1, -340, 0, 22),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -120, 0, 22),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Badge, {
		value = admin.Role or "ADMIN",
		accent = Palette.coral,
		filled = true,
		size = UDim2.fromOffset(108, 22),
	}), React.createElement(Badge, {
		value = if (integrity and integrity.Healthy) == false then "RESTORED" else "HEALTHY",
		accent = if (integrity and integrity.Healthy) == false then Palette.mango else Palette.mint,
		filled = true,
		size = UDim2.fromOffset(84, 22),
	}), selectedPlayer and selectedPlayer.Unlimited == true and React.createElement(Badge, {
		value = "UNLIMITED",
		accent = Palette.violet,
		filled = true,
		size = UDim2.fromOffset(88, 22),
	})), React.createElement(Button, {
		text = "REFRESH",
		onClick = function() dispatch("GetAdminState") end,
		color = Palette.panelSoft,
		textColor = Palette.mint,
		outline = true,
		size = UDim2.fromOffset(104, 32),
		position = UDim2.new(1, -104, 0, 3),
			reducedMotion = softMotion,
	}))

	local playerSection = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 1,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "PLAYERS",
		accent = Palette.cyan,
	}), React.createElement(SearchField, {
		value = playerQuery,
		onChange = setPlayerQuery,
		accent = Palette.cyan,
		placeholder = "Search players…",
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 20),
			reducedMotion = softMotion,
	}), (function()
		local listSize = UDim2.new(1, 0, 1, -64)
		local listPos = UDim2.fromOffset(0, 64)
		if #shownPlayers == 0 then
			return React.createElement("frame", {
				Size = listSize,
				Position = listPos,
				BackgroundTransparency = 1,
			}, React.createElement(Text, {
				value = "No players match.",
				size = 11,
				color = Palette.muted,
			}))
		end
		return React.createElement(FlatList, {
			data = shownPlayers,
			itemHeight = PLAYER_ROW_STRIDE,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 4,
			Size = listSize,
			Position = listPos,
			scrollBarColor = Palette.cyan,
			scrollBarThickness = SCROLL_BAR,
			keyExtractor = function(player)
				return tostring(player.UserId)
			end,
			renderItem = function(_param)
				local player = _param.item
				local index = _param.index
				return React.createElement(PlayerRow, {
					player = player,
					selected = player.UserId == targetId,
					you = player.UserId == admin.SelfUserId,
					onClick = function() setTargetId(player.UserId) end,
					layoutOrder = index + 1,
					reducedMotion = softMotion,
				})
			end,
		})
	end)())

	local commandSection = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 2,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "COMMANDS",
		accent = Palette.violet,
	}), React.createElement(SearchField, {
		value = commandQuery,
		onChange = setCommandQuery,
		accent = Palette.violet,
		placeholder = "Search commands…",
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 20),
			reducedMotion = softMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 62),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), (function()
		local pills = table.create(#ADMIN_CATS)
		for i, cat in ADMIN_CATS do
			pills[i] = React.createElement(Button, {
				key = cat.id,
				text = cat.label,
				onClick = function() setCategory(cat.id) end,
				color = if category == cat.id then Palette.violet else Palette.panelSoft,
				textColor = if category == cat.id then Palette.ink else Palette.creamSoft,
				outline = category ~= cat.id,
				highlight = category == cat.id,
				size = UDim2.fromOffset(62, 28),
				reducedMotion = softMotion,
			})
		end
		return pills
	end)()), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -100),
		Position = UDim2.fromOffset(0, 100),
		BackgroundTransparency = 1,
	}, #shownCommands == 0 and React.createElement(Text, {
		value = "Nothing matches that filter.",
		size = 11,
		color = Palette.muted,
	}) or React.createElement(FlatList, {
		data = shownCommands,
		itemHeight = COMMAND_ROW_STRIDE,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 4,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.violet,
		scrollBarThickness = SCROLL_BAR,
		keyExtractor = function(entry)
			return entry.Id
		end,
		renderItem = function(_param)
			local entry = _param.item
			local index = _param.index
			return React.createElement(CommandRow, {
				entry = entry,
				selected = entry.Id == command,
				onClick = function() setCommand(entry.Id) end,
				layoutOrder = index + 1,
			})
		end,
	})))

	local inspectSection = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, inspectH),
		accent = Palette.mint,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 0,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "TARGET",
		accent = Palette.mint,
	}), React.createElement(Text, {
		value = if selectedPlayer then `{selectedPlayer.DisplayName}  ·  {selectedPlayer.UserId}` else "Select a player.",
		size = 12,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 15),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, STAT_H * 2 + STAT_GAP),
		Position = UDim2.fromOffset(0, INSPECT_TITLE),
		BackgroundTransparency = 1,
	}, React.createElement("uigridlayout", {
		CellSize = UDim2.new(0.25, -6, 0, STAT_H),
		CellPadding = UDim2.fromOffset(STAT_GAP, STAT_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
	}), React.createElement(StatCell, { label = "CASH", value = selectedPlayer and compactNumber(selectedPlayer.Cash or 0) or "--", accent = Palette.cyan }),
		React.createElement(StatCell, { label = "VAULT", value = selectedPlayer and `{compactNumber(selectedPlayer.Vault or 0)}/{compactNumber(selectedPlayer.Capacity or 0)}` or "--", accent = Palette.mint }),
		React.createElement(StatCell, { label = "CORES", value = selectedPlayer and compactNumber(selectedPlayer.Cores or 0) or "--", accent = Palette.violet }),
		React.createElement(StatCell, { label = "REBIRTHS", value = selectedPlayer and compactNumber(selectedPlayer.Rebirths or 0) or "--", accent = Palette.pink }),
		React.createElement(StatCell, { label = "WORLD", value = selectedPlayer and tostring(selectedPlayer.Zone or 1) or "--", accent = Palette.mango }),
		React.createElement(StatCell, { label = "RATE", value = selectedPlayer and `{compactNumber(selectedPlayer.Production or 0)}/s` or "--", accent = Palette.cyan }),
		React.createElement(StatCell, { label = "DUST", value = selectedPlayer and compactNumber(selectedPlayer.Stardust or 0) or "--", accent = Palette.steel }),
		React.createElement(StatCell, { label = "KEYS", value = selectedPlayer and compactNumber(selectedPlayer.Keys or 0) or "--", accent = Palette.violet })))

	local executeActionsHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = executeActionsHostRef.current
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
	end, { command, armed, busy, targetId })

	local executeDock = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, executeH),
		accent = if armed then Palette.coral else accent,
		background = Palette.panelRaised,
		padding = 12,
		layoutOrder = 1,
		highlight = armed,
		reveal = toolsReveal,
			reducedMotion = softMotion,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = if needsArm then "ARM TO RUN" else "READY",
		accent = if armed then Palette.coral else accent,
	}), React.createElement(Text, {
		value = (selected and selected.Label) or command,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, 15),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, math.max(0, fieldSlots * FIELD_H - 6)),
		Position = UDim2.fromOffset(0, EXEC_TITLE),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}), fields.usesAmount and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, FIELD_H - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		ZIndex = 52,
	}, React.createElement(Dropdown, {
		options = fields.amountChoices,
		value = amount,
		onChange = function(id)
			setAmount(id)
			if fields.overridesTarget then
				local uid = tonumber(id)
				if uid then setTargetId(uid) end
			end
		end,
		accent = Palette.mango,
		size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
		zIndex = 80,
	})), fields.usesOption and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, FIELD_H - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 51,
	}, React.createElement(Dropdown, {
		options = fields.optionChoices,
		value = option,
		onChange = setOption,
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
		zIndex = 70,
	})), needsArm and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, FIELD_H - 6),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 50,
	}, React.createElement(Dropdown, {
		options = reasonChoices,
		value = reason,
		onChange = setReason,
		accent = Palette.steel,
		size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
		zIndex = 60,
	}))), React.createElement("frame", {
		Name = "AdminExecuteActions",
		Size = UDim2.new(1, 0, 0, EXEC_BUTTON),
		Position = UDim2.fromOffset(0, EXEC_TITLE + fieldSlots * FIELD_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = executeActionsHostRef,
	}, React.createElement("frame", {
		Name = "AdminPreviewRun",
		Size = UDim2.new(0.34, -5, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = "PREVIEW",
		icon = "Search",
		onClick = preview,
		color = Palette.panelSoft,
		textColor = Palette.text,
		size = UDim2.new(1, 0, 0, 48),
		position = UDim2.new(0, 0, 0.5, -24),
		disabled = runDisabled,
			reducedMotion = softMotion,
	})), React.createElement("frame", {
		Name = "AdminConfirmRun",
		ClipsDescendants = false,
		Size = UDim2.new(0.66, -5, 1, 0),
		Position = UDim2.fromScale(0.34, 0) + UDim2.fromOffset(5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = runLabel,
		icon = "Lock",
		onClick = execute,
		color = runColor,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, 48),
		position = UDim2.new(0, 0, 0.5, -24),
		disabled = runDisabled,
		loading = busy,
		shakeToken = shakeToken,
		highlight = armed or not needsArm,
			reducedMotion = softMotion,
	}))), React.createElement(Text, {
		value = (if lastNote ~= "" then lastNote else (if needsArm then "Arm first. Dangerous commands need a second tap." else "Preview shows saved changes first. Run applies them."))
			.. (if #previewLines > 0 then "\n• " .. table.concat(previewLines, "\n• ", 1, math.min(#previewLines, 6)) else ""),
		size = 9,
		color = if lastNote ~= "" then (if lastOk then Palette.mint else Palette.coral) else Palette.muted,
		wrap = true,
		fit = false,
		position = UDim2.new(0, 0, 1, -EXEC_NOTE + 4),
		sizeConstraint = UDim2.new(1, 0, 0, EXEC_NOTE - 4),
	}))

	local recentSection = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.steel,
		background = Palette.panel,
		padding = 12,
		layoutOrder = 2,
		clips = false,
	}, React.createElement(SectionTitle, {
		value = "RECENT",
		accent = Palette.steel,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -20),
		Position = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}), #recent == 0 and React.createElement(Text, {
		value = "No commands run yet.",
		size = 11,
		color = Palette.muted,
		position = UDim2.fromOffset(0, 6),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}) or (function()
		local rows = table.create(math.min(6, #recent))
		for i = 1, math.min(6, #recent) do
			rows[i] = React.createElement(AuditLine, {
				key = recent[i].Id,
				record = recent[i],
			})
		end
		return rows
	end)()))

	local BODY_H = inspectH + GAP + executeH + GAP + RECENT_MIN
	local consoleBody = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(CONSOLE_W, BODY_H),
	}), React.createElement("frame", {
		Size = UDim2.new(0, PLAYERS_W, 1, 0),
		BackgroundTransparency = 1,
	}, playerSection), React.createElement("frame", {
		Size = UDim2.new(0, DETAIL_W, 1, 0),
		Position = UDim2.new(1, -DETAIL_W, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, inspectH),
		BackgroundTransparency = 1,
	}, inspectSection), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, executeH),
		Position = UDim2.fromOffset(0, inspectH + GAP),
		BackgroundTransparency = 1,
	}, executeDock), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -(inspectH + executeH + GAP * 2)),
		Position = UDim2.fromOffset(0, inspectH + executeH + GAP * 2),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(0, RECENT_MIN),
	}), recentSection)), React.createElement("frame", {
		Size = UDim2.new(1, -(PLAYERS_W + DETAIL_W + GAP * 2), 1, 0),
		Position = UDim2.fromOffset(PLAYERS_W + GAP, 0),
		BackgroundTransparency = 1,
	}, commandSection))

	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = 8,
		scrollBarColor = Palette.steel,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = HEADER_H,
				element = header,
			},
			{
				id = "console",
				fill = true,
				minHeight = BODY_H,
				element = consoleBody,
			},
		},
	})
end
local function AdminView(_param)
	local admin = _param.state.Admin
	if not (admin and admin.Access == true) then
		return React.createElement(EmptyState, {
			icon = "Lock",
			title = "Owner tools locked",
			body = "Only the game owner can open this page.",
			accent = Palette.coral,
		})
	end
	return React.createElement(AdminViewReady, _param)
end

return {
	AdminView = AdminView,
}
end

__defs["AnomalyView"] = function()
return { AnomalyView = require(script.Parent.Parent.PlanningViews).ShiftPlan }
end

__defs["LeaderboardsView"] = function()
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local Palette = require(script.Parent.Parent.CoreKit)("theme").Palette
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
	group = "Progression",
}, {
	id = "Crates",
	label = "Crates Opened",
	short = "CRATES",
	description = "Every sealed crate cracked open, any tier, any skin.",
	icon = "Crate",
	accent = Palette.mango,
	group = "Collection",
}, {
	id = "Finds",
	label = "Items Found",
	short = "FINDS",
	description = "Relics, tools and oddities pulled into the vault.",
	icon = "Artifact",
	accent = Palette.cyan,
	group = "Collection",
}, {
	id = "Ore",
	label = "Ore Mined",
	short = "ORE",
	description = "Raw ore hauled out of the deep veins.",
	icon = "Forge",
	accent = Palette.mango,
	group = "Activity",
}, {
	id = "Wardens",
	label = "Wardens Felled",
	short = "WARDENS",
	description = "Vault wardens brought down in combat.",
	icon = "Milestone",
	accent = Palette.pink,
	group = "Activity",
}, {
	id = "Orders",
	label = "Orders Filled",
	short = "ORDERS",
	description = "Contracts and work orders delivered on time.",
	icon = "Mission",
	accent = Palette.mint,
	group = "Activity",
}, {
	id = "Stars",
	label = "Ore Cuts",
	short = "CUTS",
	description = "Completed ore cuts. Includes progress earned before the workshop redesign.",
	icon = "Dust",
	accent = Palette.violet,
	group = "Sky",
}, {
	id = "Cipher",
	label = "Commissions Finished",
	short = "COMMISSIONS",
	description = "Daily forge commissions finished. Previous puzzle completions remain counted.",
	icon = "Forge",
	accent = Palette.cyan,
	group = "Sky",
} }
local BOARD_GROUP = {
	Flux = "Economy",
	Dust = "Economy",
	Cores = "Economy",
	Rebirths = "Progression",
	Domain = "Progression",
	PlayTime = "Activity",
}
for _, board in BOARDS do
	board.group = board.group or BOARD_GROUP[board.id] or "Progression"
end
local STAT_BOARD_KEYS = {
	Crates = "CratesOpened",
	Finds = "ItemsFound",
	Ore = "OreMined",
	Wardens = "WardenDefeats",
	Orders = "OrdersCompleted",
}
local function metaFor(id)
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
	if STAT_BOARD_KEYS[id] then
		local stats = state.Stats
		return math.max(0, math.floor(tonumber(stats and stats[STAT_BOARD_KEYS[id]]) or 0))
	end
	if id == "Stars" then
		local total = 0
		local sky = state.Sky
		if type(sky) == "table" and type(sky.Plotted) == "table" then
			for _, count in sky.Plotted do
				total += math.max(0, math.floor(tonumber(count) or 0))
			end
		end
		return total
	end
	if id == "Cipher" then
		local sky = state.Sky
		return math.max(0, math.floor(tonumber(type(sky) == "table" and type(sky.Cipher) == "table" and sky.Cipher.Solves) or 0))
	end
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
local function serverValueFor(summary, id)
	if STAT_BOARD_KEYS[id] or id == "Stars" or id == "Cipher" then
		local boards = summary.Boards
		return if type(boards) == "table" then tonumber(boards[id]) or 0 else 0
	end
	if id == "Flux" then
		local _condition = summary.LifetimeCash
		if _condition == nil then
			_condition = 0
		end
		return _condition
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
		local compare = require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath).Compare(serverValueFor(left,id) or 0,serverValueFor(right,id) or 0)
		return if compare == 0 then left.UserId < right.UserId else compare > 0
	end)
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
	return _newValue_1
end
return {
	LeaderboardsView = require(script.Parent.Parent.RankDashboard)({boards=BOARDS,metaFor=metaFor,ownValue=ownValue,formatValue=formatValue,serverEntries=serverEntries,scoreCounts=scoreCounts}),
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
