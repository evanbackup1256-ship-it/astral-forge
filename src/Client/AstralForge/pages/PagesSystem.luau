--!nonstrict
--[=[
	PagesSystem: merged module suite.
	Members (5): SettingsView, CommandView, AdminView, AnomalyView, LeaderboardsView.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

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

-- ======================================================================
-- Module: SettingsView   (merged from SettingsView.luau, 1365 lines)
-- ======================================================================
__defs["SettingsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local MobileControls = require(script.Parent.Parent.UiOverlays)("MobileControls").MobileControls
local _mobileLayout = require(script.Parent.Parent.CoreKit)("mobileLayout")
local fitTouchGridWidth = _mobileLayout.fitTouchGridWidth
local moreDockHeight = _mobileLayout.moreDockHeight
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local SECTION_LABEL_H = 28
local SCROLL_BAR = 4
-- FlatList long section catalogs once they would otherwise map-mount every row under PageScaffold.
local VIRT_SETTINGS_MIN = 6
local VIRT_SETTINGS_VISIBLE = 5
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Slider = _ui.Slider
local Text = _ui.Text
local SETTINGS = { {
	id = "SoundVolume",
	label = "All sound",
	description = "Master volume.",
	accent = Palette.green,
	section = "audio",
}, {
	id = "MusicVolume",
	label = "Music",
	description = "Set how loud the background music plays.",
	accent = Palette.mint,
	section = "audio",
}, {
	id = "SfxVolume",
	label = "Sound effects",
	description = "Buttons, rewards, machines, hits.",
	accent = Palette.cyan,
	section = "audio",
}, {
	id = "UiVolume",
	label = "Menu sounds",
	description = "Clicks when you tap around the menus.",
	accent = Palette.cyan,
	section = "audio",
}, {
	id = "GameplayVolume",
	label = "Gameplay sounds",
	description = "Machines, reactor, travel, arcade.",
	accent = Palette.coral,
	section = "audio",
}, {
	id = "RewardVolume",
	label = "Reward sounds",
	description = "Claims, crates, wheel, rebirths.",
	accent = Palette.mango,
	section = "audio",
}, {
	id = "AmbientVolume",
	label = "Background ambience",
	description = "The quiet shop noise under the music.",
	accent = Palette.violet,
	section = "audio",
}, {
	id = "HoverSounds",
	label = "Hover sounds",
	description = "A little tick when you hover a button.",
	accent = Palette.blue,
	section = "audio",
	kind = "toggle",
}, {
	id = "NotificationSounds",
	label = "Alert sounds",
	description = "Mail, unlocks, and other pings.",
	accent = Palette.pink,
	section = "audio",
	kind = "toggle",
}, {
	id = "PageMusic",
	label = "Background music",
	description = "One soundtrack that plays through the whole game.",
	accent = Palette.mint,
	section = "audio",
	kind = "toggle",
}, {
	id = "SoundVariation",
	label = "Sound variation",
	description = "Slight pitch change so clicks don't all sound identical.",
	accent = Palette.violet,
	section = "audio",
}, {
	id = "MotionIntensity",
	label = "Animation amount",
	description = "How lively menus feel. Low settings stay smooth: gentler, slower, no bounce.",
	accent = Palette.violet,
	section = "motion",
}, {
	id = "ViewportSpeed",
	label = "Icon speed",
	description = "How fast icons spin and tilt.",
	accent = Palette.mango,
	section = "motion",
}, {
	id = "PanelHover",
	label = "Card hover lift",
	description = "Cards lift a bit when you hover.",
	accent = Palette.cyan,
	section = "motion",
	kind = "toggle",
}, {
	id = "PanelEntrances",
	label = "Card entrances",
	description = "New cards fade in instead of popping.",
	accent = Palette.violet,
	section = "motion",
	kind = "toggle",
}, {
	id = "AnimatedTitles",
	label = "Animated titles",
	description = "Title text keeps moving.",
	accent = Palette.pink,
	section = "motion",
	kind = "toggle",
}, {
	id = "IconAnimations",
	label = "Animated icons",
	description = "Big icons spin and orbit.",
	accent = Palette.blue,
	section = "motion",
	kind = "toggle",
}, {
	id = "NumberAnimations",
	label = "Rolling numbers",
	description = "Counters roll when they jump.",
	accent = Palette.green,
	section = "motion",
	kind = "toggle",
}, {
	id = "ReactorMotion",
	label = "Reactor motion",
	description = "How busy the reactor looks.",
	accent = Palette.pink,
	section = "motion",
}, {
	id = "EffectsIntensity",
	label = "Effect amount",
	description = "Sparks, pops, flashes.",
	accent = Palette.pink,
	section = "visual",
}, {
	id = "BackgroundDetail",
	label = "Background detail",
	description = "Stars and glow behind the menus.",
	accent = Palette.mint,
	section = "visual",
}, {
	id = "ShimmerIntensity",
	label = "Shimmer strength",
	description = "White sweep on buttons.",
	accent = Palette.cream,
	section = "visual",
}, {
	id = "GlowIntensity",
	label = "Glow strength",
	description = "Bloom around rewards and live stuff.",
	accent = Palette.violet,
	section = "visual",
}, {
	id = "ParticleDensity",
	label = "Particle density",
	description = "Sparks, confetti, debris.",
	accent = Palette.mango,
	section = "visual",
}, {
	id = "ButtonShimmers",
	label = "Button shimmers",
	description = "A light sweep on hovered buttons.",
	accent = Palette.cream,
	section = "visual",
	kind = "toggle",
}, {
	id = "ConfettiEnabled",
	label = "Celebration effects",
	description = "Confetti and sparks on big wins.",
	accent = Palette.mango,
	section = "visual",
	kind = "toggle",
}, {
	id = "ScreenFlashes",
	label = "Impact flashes",
	description = "Flash the screen on big moments.",
	accent = Palette.pink,
	section = "visual",
	kind = "toggle",
}, {
	id = "BackgroundStars",
	label = "Background stars",
	description = "Stars behind the pages.",
	accent = Palette.blue,
	section = "visual",
	kind = "toggle",
}, {
	id = "AmbientGlow",
	label = "Ambient glows",
	description = "Soft colored light behind the UI.",
	accent = Palette.violet,
	section = "visual",
	kind = "toggle",
}, {
	id = "OfflineRewardEffects",
	label = "Welcome-back effects",
	description = "Glow when you come back to offline cash.",
	accent = Palette.mint,
	section = "visual",
	kind = "toggle",
}, {
	id = "ToastDensity",
	label = "Notification stack",
	description = "How many alerts sit on screen at once.",
	accent = Palette.blue,
	section = "interface",
}, {
	id = "UiDensity",
	label = "Layout breathing room",
	description = "Tighter or roomier layout. Text stays sharp.",
	accent = Palette.coral,
	section = "interface",
}, {
	id = "PerformanceBias",
	label = "Favor performance",
	description = "Turn this up if the game feels heavy.",
	accent = Palette.green,
	section = "interface",
}, {
	id = "ScrollSpeed",
	label = "Mouse scroll speed",
	description = "How far a wheel tick moves the list.",
	accent = Palette.blue,
	section = "interface",
}, {
	id = "ScrollMomentum",
	label = "Scroll momentum",
	description = "How long the list coasts after you let go.",
	accent = Palette.mint,
	section = "interface",
}, {
	id = "ShowFps",
	label = "FPS readout",
	description = "Show frame rate up top.",
	accent = Palette.green,
	section = "interface",
	kind = "toggle",
}, {
	id = "ShowPing",
	label = "Ping readout",
	description = "Show ping next to FPS.",
	accent = Palette.cyan,
	section = "interface",
	kind = "toggle",
}, {
	id = "ShowResourceLabels",
	label = "Resource labels",
	description = "Show DUST, CORES, FLUX above the numbers.",
	accent = Palette.mango,
	section = "interface",
	kind = "toggle",
}, {
	id = "ShowNextGoal",
	label = "Level bar",
	description = "Show your Forge Level and next goal under the page title.",
	accent = Palette.mint,
	section = "interface",
	kind = "toggle",
}, {
	id = "CompactTopBar",
	label = "Compact top bar",
	description = "Shorter header, more room below.",
	accent = Palette.violet,
	section = "interface",
	kind = "toggle",
}, {
	id = "NotificationDuration",
	label = "Notification duration",
	description = "How long alerts stay up.",
	accent = Palette.blue,
	section = "interface",
}, {
	id = "HapticIntensity",
	label = "Phone vibration",
	description = "How hard the phone buzzes on taps.",
	accent = Palette.pink,
	section = "accessibility",
}, {
	id = "HighContrast",
	label = "High contrast",
	description = "Stronger text and edges.",
	accent = Palette.cream,
	section = "accessibility",
	kind = "toggle",
}, {
	id = "ColorblindMode",
	label = "Color-safe signals",
	description = "Blue and gold instead of green and red.",
	accent = Palette.blue,
	section = "accessibility",
	kind = "toggle",
}, {
	id = "DesktopTextScale",
	label = "Desktop text size",
	description = "Bigger or smaller text. Buttons stay put.",
	accent = Palette.cyan,
	section = "accessibility",
}, {
	id = "BoldText",
	label = "Heavier body text",
	description = "Thicker descriptions.",
	accent = Palette.cream,
	section = "accessibility",
	kind = "toggle",
}, {
	id = "ReducedTransparency",
	label = "Solid surfaces",
	description = "Less see-through panels.",
	accent = Palette.violet,
	section = "accessibility",
	kind = "toggle",
}, {
	id = "LargeTouchTargets",
	label = "Large touch targets",
	description = "Bigger buttons on touch.",
	accent = Palette.green,
	section = "accessibility",
	kind = "toggle",
}, {
	id = "MobileTextScale",
	label = "Mobile text size",
	description = "Text size on phone, separate from the HUD.",
	accent = Palette.mango,
	section = "mobile",
}, {
	id = "MobileQuickScale",
	label = "Quick-action size",
	description = "Vault and overcharge button size.",
	accent = Palette.cyan,
	section = "mobile",
}, {
	id = "MobileDockScale",
	label = "Bottom menu size",
	description = "Size of the bottom menu.",
	accent = Palette.violet,
	section = "mobile",
}, {
	id = "MobileToastScale",
	label = "Notification size",
	description = "Size of alert cards.",
	accent = Palette.blue,
	section = "mobile",
}, {
	id = "MobileQuickOpacity",
	label = "Quick-action opacity",
	description = "How solid the floating buttons are.",
	accent = Palette.cyan,
	section = "mobile",
}, {
	id = "MobileDockOpacity",
	label = "Navigation opacity",
	description = "How solid the bottom menu is.",
	accent = Palette.violet,
	section = "mobile",
}, {
	id = "MobileToastOpacity",
	label = "Notification opacity",
	description = "How solid the alerts are.",
	accent = Palette.blue,
	section = "mobile",
}, {
	id = "MobileButtonSpacing",
	label = "Touch spacing",
	description = "More space between thumb buttons.",
	accent = Palette.green,
	section = "mobile",
}, {
	id = "MobileQuickReverse",
	label = "Primary thumb side",
	description = "Overcharge on the left or right.",
	accent = Palette.mango,
	section = "mobile",
	kind = "toggle",
	onLabel = "TAP LEFT",
	offLabel = "TAP RIGHT",
}, {
	id = "MobileQuickVisible",
	label = "Quick actions",
	description = "Vault and overcharge above the dock.",
	accent = Palette.cyan,
	section = "mobile",
	kind = "toggle",
	onLabel = "VISIBLE",
	offLabel = "HIDDEN",
}, {
	id = "MobileDockVisible",
	label = "Bottom navigation",
	description = "Show the bottom menu. The drawer still works.",
	accent = Palette.violet,
	section = "mobile",
	kind = "toggle",
	onLabel = "VISIBLE",
	offLabel = "HIDDEN",
}, {
	id = "MobileToastVisible",
	label = "Notifications",
	description = "Show floating alerts on phone.",
	accent = Palette.blue,
	section = "mobile",
	kind = "toggle",
	onLabel = "VISIBLE",
	offLabel = "HIDDEN",
}, {
	id = "MobileCompactHeaders",
	label = "Compact page headers",
	description = "Shorter titles so the page has more room.",
	accent = Palette.cyan,
	section = "mobile",
	kind = "toggle",
}, {
	id = "MobileAutoHideDock",
	label = "Auto-hide navigation",
	description = "Hide the dock while you type or play arcade.",
	accent = Palette.violet,
	section = "mobile",
	kind = "toggle",
}, {
	id = "MobileLandscapeCompact",
	label = "Compact landscape",
	description = "Drop extra headers when the phone is sideways.",
	accent = Palette.mint,
	section = "mobile",
	kind = "toggle",
}, {
	id = "MobileKeyboardCompact",
	label = "Keyboard compact mode",
	description = "Shrink the chrome while the keyboard is up.",
	accent = Palette.mango,
	section = "mobile",
	kind = "toggle",
} }
local NEW_DEFAULTS = {
	UiVolume = 0.6,
	GameplayVolume = 1,
	RewardVolume = 1,
	AmbientVolume = 0.75,
	HoverSounds = 1,
	NotificationSounds = 1,
	PageMusic = 1,
	SoundVariation = 0.7,
	ReactorMotion = 0.8,
	OfflineRewardEffects = 1,
	ShimmerIntensity = 0.8,
	GlowIntensity = 0.75,
	ParticleDensity = 0.75,
	ButtonShimmers = 1,
	PanelHover = 1,
	PanelEntrances = 1,
	AnimatedTitles = 1,
	IconAnimations = 1,
	NumberAnimations = 1,
	ConfettiEnabled = 1,
	ScreenFlashes = 0.8,
	BackgroundStars = 1,
	AmbientGlow = 1,
	ShowFps = 1,
	ShowPing = 1,
	ShowResourceLabels = 1,
	ShowNextGoal = 1,
	CompactTopBar = 0,
	NotificationDuration = 0.55,
	ScrollMomentum = 0.75,
	DesktopTextScale = 0.5,
	BoldText = 0,
	ReducedTransparency = 0,
	LargeTouchTargets = 1,
	MobileCompactHeaders = 1,
	MobileAutoHideDock = 1,
	MobileLandscapeCompact = 1,
	MobileKeyboardCompact = 1,
}
local FX_PRESETS = {
	low = {
		label = "LOW FX",
		notice = "LOW FX is on. Motion is light, button sweeps are off.",
		values = {
			MusicVolume = 0.5,
			SfxVolume = 1,
			UiVolume = 1,
			MotionIntensity = 0.18,
			EffectsIntensity = 0.22,
			ParticleDensity = 0.12,
			ButtonShimmers = 0,
			ShimmerIntensity = 0.2,
			GlowIntensity = 0.2,
			ConfettiEnabled = 0,
			ScreenFlashes = 0.15,
			PanelHover = 0.35,
			PanelEntrances = 0.4,
			AnimatedTitles = 0,
			IconAnimations = 0.25,
			PerformanceBias = 1,
		},
	},
	normal = {
		label = "NORMAL",
		notice = "NORMAL is on. Sweeps, ripples, and motion are back to default.",
		values = {
			MusicVolume = 0.7,
			SfxVolume = 1,
			UiVolume = 1,
			MotionIntensity = 0.62,
			EffectsIntensity = 0.7,
			ParticleDensity = 0.6,
			ButtonShimmers = 1,
			ShimmerIntensity = 0.8,
			GlowIntensity = 0.75,
			ConfettiEnabled = 1,
			ScreenFlashes = 0.8,
			PanelHover = 1,
			PanelEntrances = 1,
			AnimatedTitles = 1,
			IconAnimations = 1,
			PerformanceBias = 0.35,
		},
	},
	high = {
		label = "HIGH FX",
		notice = "HIGH FX is on. Full motion, sweeps, and flashes.",
		values = {
			MusicVolume = 0.7,
			SfxVolume = 1,
			UiVolume = 1,
			MotionIntensity = 1,
			EffectsIntensity = 1,
			ParticleDensity = 1,
			ButtonShimmers = 1,
			ShimmerIntensity = 1,
			GlowIntensity = 1,
			ConfettiEnabled = 1,
			ScreenFlashes = 1,
			PanelHover = 1,
			PanelEntrances = 1,
			AnimatedTitles = 1,
			IconAnimations = 1,
			PerformanceBias = 0,
		},
	},
}
local function matchingPreset(settings)
	local _condition = settings.MotionIntensity
	if _condition == nil then
		_condition = 1
	end
	local motion = _condition
	local _condition_1 = settings.ButtonShimmers
	if _condition_1 == nil then
		_condition_1 = 1
	end
	local shimmers = _condition_1
	local _condition_2 = settings.PerformanceBias
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local bias = _condition_2
	if shimmers < 0.5 and bias >= 0.85 then
		return "low"
	end
	if motion >= 0.92 and shimmers >= 0.5 and bias <= 0.12 then
		return "high"
	end
	if motion >= 0.5 and motion <= 0.75 and shimmers >= 0.5 then
		return "normal"
	end
	return nil
end
local MOBILE_DOCK_DESTINATIONS = { "Overview", "Workshop", "Inventory", "Research", "Shop", "Settings" }
local SECTION_META = {
	audio = {
		label = "AUDIO",
		accent = Palette.green,
	},
	motion = {
		label = "MOTION",
		accent = Palette.violet,
	},
	visual = {
		label = "VISUALS",
		accent = Palette.pink,
	},
	interface = {
		label = "INTERFACE",
		accent = Palette.cyan,
	},
	accessibility = {
		label = "ACCESS",
		accent = Palette.mango,
	},
	mobile = {
		label = "MOBILE",
		accent = Palette.blue,
	},
}
local function savedValue(settings, id)
	local value = settings[id]
	if type(value) == "number" then
		return math.clamp(value, 0, 1)
	end
	local addedDefault = NEW_DEFAULTS[id]
	if addedDefault ~= nil then
		return addedDefault
	end
	if id == "SoundVolume" then
		return 0.75
	end
	if id == "ToastDensity" or id == "UiDensity" or id == "MobileTextScale" or id == "MobileButtonSpacing" then
		return 0.5
	end
	if id == "PerformanceBias" then
		return 0.5
	end
	if id == "BackgroundDetail" then
		return 0.8
	end
	if id == "ScrollSpeed" or id == "HapticIntensity" then
		return 0.65
	end
	if id == "MobileQuickScale" or id == "MobileDockScale" then
		local _condition = settings.MobileHudScale
		if _condition == nil then
			_condition = 0.5
		end
		return _condition
	end
	if id == "MobileToastScale" then
		local _condition = settings.MobileHudScale
		if _condition == nil then
			_condition = 0.5
		end
		return _condition
	end
	if id == "MobileQuickOpacity" or id == "MobileDockOpacity" or id == "MobileToastOpacity" then
		local _condition = settings.MobileHudOpacity
		if _condition == nil then
			_condition = 0.85
		end
		return _condition
	end
	if id == "MobileQuickReverse" then
		return 0
	end
	if id == "HighContrast" or id == "ColorblindMode" then
		return 0
	end
	if id == "MobileQuickVisible" or id == "MobileDockVisible" or id == "MobileToastVisible" then
		return 1
	end
	return 1
end
local function SettingRow(_param)
	local data = _param.data
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local motionSoft = _param.softMotion or reducedMotion
	local layoutOrder = _param.layoutOrder
	local index = _param.index
	local stack = _param.stack
	local touch = _param.touch
	local saved = savedValue(state.Settings, data.id)
	local draft, setDraft = React.useState(saved)
	React.useEffect(function()
		return setDraft(saved)
	end, { saved })
	local commit = React.useCallback(function(value)
		dispatch("SetSetting", {
			Key = data.id,
			Value = value,
		})
	end, { data.id, dispatch })
	local reveal = useStagger(math.min(index, 5), motionSoft, 0.01, 0.14)
	local rowH = if stack then 112 else 96
	local toggle = data.kind == "toggle"
	local directionalToggle = data.id == "MobileQuickReverse"
	local _exp = React.createElement(Text, {
		value = data.label,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		sizeConstraint = UDim2.new(1, if stack then -28 else -244, 0, 22),
	})
	local _exp_1 = React.createElement(Text, {
		value = data.description,
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, if stack then -8 else -244, 0, if stack then 34 else 36),
	})
	local _result
	if toggle then
		local _attributes = {}
		local _result_1
		if draft >= 0.5 then
			local _condition = data.onLabel
			if _condition == nil then
				_condition = "ON"
			end
			_result_1 = _condition
		else
			local _condition = data.offLabel
			if _condition == nil then
				_condition = "OFF"
			end
			_result_1 = _condition
		end
		_attributes.text = _result_1
		_attributes.icon = if directionalToggle then (if draft >= 0.5 then "Back" else "Chevron") elseif draft >= 0.5 then "Check" elseif data.offLabel == "HIDDEN" then "Hide" else "Close"
		_attributes.onClick = function()
			local updated = if draft >= 0.5 then 0 else 1
			setDraft(updated)
			commit(updated)
		end
		_attributes.sound = if draft >= 0.5 then "toggleOff" else "toggleOn"
		_attributes.color = if directionalToggle then data.accent elseif draft >= 0.5 then data.accent else Palette.panelSoft
		_attributes.textColor = if directionalToggle or draft >= 0.5 then Palette.ink else Palette.creamSoft
		_attributes.outline = not directionalToggle and draft < 0.5
		_attributes.size = UDim2.fromScale(1, 1)
		_attributes.reducedMotion = motionSoft
		_result = React.createElement("frame", {
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(170, TapTarget),
			Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -170, 0.5, -TapTarget / 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, _attributes))
	else
		_result = if stack then React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, TapTarget),
			Position = UDim2.new(0, 0, 1, -(TapTarget + 4)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Slider, {
			value = draft,
			accent = data.accent,
			reducedMotion = motionSoft,
			size = UDim2.new(1, -58, 0, TapTarget),
			onChange = setDraft,
			onCommit = commit,
		}), React.createElement(Text, {
			value = `{math.floor(draft * 100 + 0.5)}%`,
			size = 11,
			color = data.accent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.new(1, -52, 0, 0),
			sizeConstraint = UDim2.new(0, 52, 0, TapTarget),
			align = Enum.TextXAlignment.Right,
		})) else React.createElement("frame", {
			Size = UDim2.fromOffset(222, if touch then TapTarget else 30),
			Position = UDim2.new(1, -222, 0.5, if touch then -TapTarget / 2 else -15),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Slider, {
			value = draft,
			accent = data.accent,
			reducedMotion = motionSoft,
			size = UDim2.fromOffset(172, if touch then TapTarget else 30),
			onChange = setDraft,
			onCommit = commit,
		}), React.createElement(Text, {
			value = `{math.floor(draft * 100 + 0.5)}%`,
			size = 11,
			color = data.accent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(178, 0),
			sizeConstraint = UDim2.new(0, 44, 0, if touch then TapTarget else 30),
			align = Enum.TextXAlignment.Right,
		}))
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		accent = data.accent,
		background = Palette.panel,
		padding = 13,
		layoutOrder = layoutOrder,
		reveal = reveal,
		interactive = true,
		reducedMotion = motionSoft,
		clips = false,
	}, _exp, _exp_1, _result)
end
local function SettingsView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local mobileEdit, setMobileEdit = React.useState(false)
	local activeSection, setActiveSection = React.useState("audio")
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local audioReveal = useStagger(0, softMotion)
	local motionReveal = useStagger(1, softMotion)
	local visualReveal = useStagger(2, softMotion)
	local navReveal = useStagger(3, softMotion)
	local settingsSoft = softMotion or audioReveal == nil or motionReveal == nil or visualReveal == nil or navReveal == nil
	-- isTouchDevice() (called with no viewport args) re-derives its own desktop/mobile guess from
	-- the raw camera ViewportSize instead of trusting the already-computed, correctly-scaled
	-- `viewport.desktop` that AutoScale produced -- the two can disagree (most visibly in Roblox
	-- Studio's device emulator, which always has real mouse/keyboard hardware attached), which is
	-- exactly what silently hid the whole "mobile" settings section and its Phone HUD editor even
	-- while chrome.stack correctly said the layout was in mobile mode.
	local touch = not viewport.desktop and UserInputService.TouchEnabled
	local stack = chrome.contentStack
	local mobileHudAvailable = touch and chrome.stack
	local touchRows = stack
	local availableSections = if mobileHudAvailable then { "audio", "motion", "visual", "interface", "accessibility", "mobile" } else { "audio", "motion", "visual", "interface", "accessibility" }
	local settingsClaimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on GUIDE/UPDATES (FocusClaim prefers Claim-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = settingsClaimHostRef.current
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
	end, { activeSection })
	React.useEffect(function()
		if not mobileHudAvailable and activeSection == "mobile" then
			setActiveSection("interface")
		end
	end, { activeSection, mobileHudAvailable })
	local activeSectionIndex = math.max(0, (table.find(availableSections, activeSection) or 0) - 1)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#availableSections)
	local _callback = function(id)
		return {
			id = id,
			label = SECTION_META[id].label,
			accent = SECTION_META[id].accent,
		}
	end
	for _k, _v in availableSections do
		_newValue[_k] = _callback(_v, _k - 1, availableSections)
	end
	-- ▲ ReadonlyArray.map ▲
	local sectionOptions = _newValue
	local paneTravel = useFlipperSpring(activeSectionIndex, softMotion, 1540, 40)
	local panePosition = paneTravel:map(function(position)
		return UDim2.new(0, math.round(math.clamp(position - activeSectionIndex, -1, 1) * 14), 0, 0)
	end)
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_1 = {}
	local _callback_1 = function(row)
		return row.section == activeSection and (row.section ~= "mobile" or mobileHudAvailable)
	end
	local _length = 0
	for _k, _v in SETTINGS do
		if _callback_1(_v, _k - 1, SETTINGS) == true then
			_length += 1
			_newValue_1[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local visibleRows = _newValue_1
	local rowStride = if touchRows then 124 else 108
	local headerH = if stack then 176 else 156
	local preset = matchingPreset(state.Settings)
	local applyPreset = function(id)
		local entry = FX_PRESETS[id]
		dispatch("SetSetting", {
			Values = entry.values,
			Label = entry.notice,
		})
	end
	local tabCols = if stack then 2 else #availableSections
	local tabRows = math.ceil(#availableSections / tabCols)
	local tabButtonH = if stack then 40 else TapTarget
	local tabsH = tabRows * (tabButtonH + 8) + 16
	local editorH = if mobileHudAvailable and activeSection == "mobile" then (if stack then 138 else 92) else 0
	-- Long section catalogs virtualize inside a fixed viewport so PageScaffold stays scrollable.
	local virtSettings = #visibleRows >= VIRT_SETTINGS_MIN
	local settingsListH = if virtSettings
		then math.min(#visibleRows, VIRT_SETTINGS_VISIBLE) * rowStride
		else #visibleRows * rowStride
	local paneH = SECTION_LABEL_H + 14 + settingsListH + editorH
	local headerReveal = useStagger(0, softMotion)
	local _ = headerReveal
	local quickScale = savedValue(state.Settings, "MobileQuickScale")
	local dockScale = savedValue(state.Settings, "MobileDockScale")
	local toastScale = savedValue(state.Settings, "MobileToastScale")
	local hudSafeTop = viewport.topInset + chrome.topbarRows + 12
	local _condition = state.Settings.UiDensity
	if _condition == nil then
		_condition = 0.55
	end
	local densityScale = 0.82 + _condition * 0.36
	local hudEdgePad = math.max(8, math.floor(chrome.pagePadding * densityScale))
	local spacing = savedValue(state.Settings, "MobileButtonSpacing")
	local dockGap = if chrome.landscape then 3 else 3 + math.floor(spacing * 5)
	local touchTargetFloor = if savedValue(state.Settings, "LargeTouchTargets") >= 0.5 then TapTarget + 6 else TapTarget
	local dockCellH = math.max(touchTargetFloor, math.floor(chrome.moreCellH * (0.88 + dockScale * 0.16)))
	local quickWidth = math.max(200, (viewport.width - math.max(hudEdgePad, chrome.sideSafe) * 2) * (0.72 + quickScale * 0.28))
	local quickHeight = math.max(TapTarget + 8, math.floor(chrome.quickBarH * (0.86 + quickScale * 0.22)))
	local dockWidth = fitTouchGridWidth(viewport.width, hudEdgePad, chrome.sideSafe, chrome.moreCols, dockGap, 0.72 + dockScale * 0.28)
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback_2 = function(count, id)
		-- MOBILE_DOCK_DESTINATIONS never includes "Admin" — this list is the fixed set of
		-- preview destinations shown while sizing the mobile dock in the HUD editor.
		local _result_1 = state.FeatureUnlocks
		if _result_1 ~= nil then
			_result_1 = _result_1[id]
			if _result_1 ~= nil then
				_result_1 = _result_1.Unlocked
			end
		end
		return if _result_1 == false then count else count + 1
	end
	for _i = 1, #MOBILE_DOCK_DESTINATIONS do
		_result = _callback_2(_result, MOBILE_DOCK_DESTINATIONS[_i], _i - 1, MOBILE_DOCK_DESTINATIONS)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local dockCount = _result
	local dockHeight = moreDockHeight(true, math.max(1, dockCount), chrome.moreCols, dockCellH, dockGap)
	local toastWidth = math.min(220, math.max(180, viewport.width - 48)) * (0.8 + toastScale * 0.2)
	local toastHeight = 2 * (48 + 4)
	local mobileSlots = React.useMemo(function()
		local slots = {}
		-- v2 mobile shell: navigation lives in a fixed bottom tab bar and quick actions live in
		-- the header, neither of which is a floating draggable HUD element anymore — only the
		-- notification toast stack is still user-repositionable.
		if chrome.quickBarH > 0 then
			local _object = {
				id = "quick",
				label = "QUICK ACTIONS",
				xKey = "MobileQuickX",
				yKey = "MobileQuickY",
			}
			local _left = "x"
			local _condition_1 = state.Settings.MobileQuickX
			if _condition_1 == nil then
				_condition_1 = 0.5
			end
			_object[_left] = _condition_1
			local _left_1 = "y"
			local _condition_2 = state.Settings.MobileQuickY
			if _condition_2 == nil then
				_condition_2 = 0.70
			end
			_object[_left_1] = _condition_2
			_object.defaultX = 0.5
			_object.defaultY = 0.70
			_object.width = math.floor(quickWidth)
			_object.height = math.floor(quickHeight)
			_object.safeTop = hudSafeTop
			table.insert(slots, _object)
		end
		if chrome.stack and viewport.height >= 480 and chrome.quickBarH > 0 then
			local _object = {
				id = "dock",
				label = "NAVIGATION",
				xKey = "MobileDockX",
				yKey = "MobileDockY",
			}
			local _left = "x"
			local _condition_1 = state.Settings.MobileDockX
			if _condition_1 == nil then
				_condition_1 = 0.5
			end
			_object[_left] = _condition_1
			local _left_1 = "y"
			local _condition_2 = state.Settings.MobileDockY
			if _condition_2 == nil then
				_condition_2 = 0.92
			end
			_object[_left_1] = _condition_2
			_object.defaultX = 0.5
			_object.defaultY = 0.92
			_object.width = math.floor(dockWidth)
			_object.height = math.floor(dockHeight)
			_object.safeTop = hudSafeTop
			table.insert(slots, _object)
		end
		local _object = {
			id = "toasts",
			label = "NOTIFICATIONS",
			xKey = "MobileToastX",
			yKey = "MobileToastY",
		}
		local _left = "x"
		local _condition_1 = state.Settings.MobileToastX
		if _condition_1 == nil then
			_condition_1 = 0.84
		end
		_object[_left] = _condition_1
		local _left_1 = "y"
		local _condition_2 = state.Settings.MobileToastY
		if _condition_2 == nil then
			_condition_2 = 0.27
		end
		_object[_left_1] = _condition_2
		_object.defaultX = 0.84
		_object.defaultY = 0.27
		_object.width = math.floor(toastWidth)
		_object.height = toastHeight
		_object.anchorY = 0
		_object.safeTop = hudSafeTop
		table.insert(slots, _object)
		return slots
	end, { chrome.quickBarH, chrome.stack, dockHeight, dockWidth, hudSafeTop, quickHeight, quickWidth, state.Settings.MobileDockX, state.Settings.MobileDockY, state.Settings.MobileQuickX, state.Settings.MobileQuickY, state.Settings.MobileToastX, state.Settings.MobileToastY, toastHeight, toastWidth, viewport.height })
	local controllerHints = UserInputService.GamepadEnabled
	local controllerHintsH = if controllerHints and activeSection == "interface" then (if stack then 96 else 78) else 0
	local _exp_2 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = 16,
		reveal = if reducedMotion then audioReveal else enter,
		highlight = not settingsSoft,
			reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "SETTINGS",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 14),
	}), React.createElement(Text, {
		value = "Sound, motion, display.",
		size = if stack then 20 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 15,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 30),
	}), React.createElement(Text, {
		value = `v{state.Game.Version}  ·  GUIDE replays the tutorial  ·  UPDATES shows patch notes`,
		size = 10,
		color = Palette.muted,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, 46),
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 16),
	}), React.createElement("frame", {
		Name = "SettingsClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.fromOffset(300, 42),
		Position = if stack then UDim2.fromOffset(0, 66) else UDim2.new(1, -300, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 6,
		ref = settingsClaimHostRef,
	}, React.createElement(Button, {
		text = "GUIDE",
		icon = "Guide",
		onClick = function()
			return dispatch("ReplayTutorial")
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(0.5, -4, 1, 0),
			reducedMotion = softMotion,
		highlight = true,
	}), React.createElement(Button, {
		text = "UPDATES",
		icon = "Gift",
		onClick = function()
			return dispatch("OpenRelease")
		end,
		color = Palette.violet,
		textColor = Palette.ink,
		size = UDim2.new(0.5, -4, 1, 0),
		position = UDim2.new(0.5, 4, 0, 0),
			reducedMotion = softMotion,
	})), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.fromOffset(300, 42),
		Position = if stack then UDim2.fromOffset(0, 114) else UDim2.new(1, -300, 0, 62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, React.createElement(Button, {
		text = "LOW FX",
		onClick = function()
			return applyPreset("low")
		end,
		color = Palette.green,
		textColor = Palette.ink,
		size = UDim2.new(1 / 3, -4, 1, 0),
			reducedMotion = softMotion,
		highlight = preset == "low",
	}), React.createElement(Button, {
		text = "NORMAL",
		onClick = function()
			return applyPreset("normal")
		end,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.new(1 / 3, -4, 1, 0),
		position = UDim2.new(1 / 3, 2, 0, 0),
			reducedMotion = softMotion,
		highlight = preset == "normal",
	}), React.createElement(Button, {
		text = "HIGH FX",
		onClick = function()
			return applyPreset("high")
		end,
		color = Palette.violet,
		textColor = Palette.ink,
		size = UDim2.new(1 / 3, -4, 1, 0),
		position = UDim2.new(2 / 3, 4, 0, 0),
			reducedMotion = softMotion,
		highlight = preset == "high",
	})))
	local _exp_3 = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, tabsH),
		accent = SECTION_META[activeSection].accent,
		background = Palette.panelRaised,
		padding = 8,
			reducedMotion = softMotion,
		clips = false,
	}, React.createElement(SegmentedTabs, {
		options = sectionOptions,
		value = activeSection,
		onChange = setActiveSection,
		accent = SECTION_META[activeSection].accent,
		columns = tabCols,
		gap = 8,
		size = UDim2.new(1, 0, 0, math.max(36, tabsH - 16)),
			reducedMotion = softMotion,
	}))
	local _exp_3b = controllerHintsH > 0 and React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panelRaised,
		padding = 14,
			reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "CONTROLLER",
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = "LB / RB switch pages · Y vault · X overcharge · LT / RT buy amount · B back · Start opens Settings",
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, if stack then 52 else 40),
	}))
	local _exp_5 = React.createElement(SectionLabel, {
		value = `{SECTION_META[activeSection].label}  ·  {#visibleRows}`,
		color = SECTION_META[activeSection].accent,
		layoutOrder = 0,
	})
	local settingsRows
	if virtSettings then
		settingsRows = React.createElement(FlatList, {
			data = visibleRows,
			itemHeight = rowStride,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 8,
			Size = UDim2.new(1, 0, 0, settingsListH),
			scrollBarColor = SECTION_META[activeSection].accent,
			scrollBarThickness = SCROLL_BAR,
			layoutOrder = 1,
			keyExtractor = function(data)
				return data.id
			end,
			renderItem = function(_param_1)
				local data = _param_1.item
				local index = _param_1.index
				return React.createElement(SettingRow, {
					data = data,
					index = index,
					state = state,
					dispatch = dispatch,
					reducedMotion = softMotion,
					softMotion = softMotion,
					layoutOrder = index + 1,
					stack = touchRows,
					touch = touch,
				})
			end,
		})
	else
		-- ▼ ReadonlyArray.map ▼
		local _newValue_2 = table.create(#visibleRows)
		local _callback_3 = function(data, index)
			return React.createElement(SettingRow, {
				key = data.id,
				data = data,
				index = index,
				state = state,
				dispatch = dispatch,
				reducedMotion = softMotion,
				softMotion = softMotion,
				layoutOrder = index + 1,
				stack = touchRows,
				touch = touch,
			})
		end
		for _k, _v in visibleRows do
			_newValue_2[_k] = _callback_3(_v, _k - 1, visibleRows)
		end
		-- ▲ ReadonlyArray.map ▲
		settingsRows = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, settingsListH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			LayoutOrder = 1,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}), _newValue_2)
	end
	local mobileEditor = mobileHudAvailable and activeSection == "mobile" and React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, if stack then 128 else 82),
		accent = Palette.cyan,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = 2,
			reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "Phone HUD",
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		sizeConstraint = UDim2.new(1, if stack then 0 else -132, 0, 22),
	}), React.createElement(Text, {
		value = "Drag the bars, or pick a one-handed layout.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, if stack then 0 else -132, 0, if stack then 28 else 34),
	}), React.createElement(Button, {
		text = "CUSTOMIZE",
		icon = "Settings",
		onClick = function()
			return setMobileEdit(true)
		end,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(120, TapTarget),
		position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -120, 0.5, -TapTarget / 2),
		reducedMotion = softMotion,
	}))
	local paneElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = panePosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}), _exp_5, settingsRows, mobileEditor))
	local sections = {
		{
			id = "hero",
			height = headerH,
			element = _exp_2,
		},
		{
			id = "tabs",
			height = tabsH,
			element = _exp_3,
		},
	}
	if controllerHintsH > 0 then
		table.insert(sections, {
			id = "controller",
			height = controllerHintsH,
			element = _exp_3b,
		})
	end
	table.insert(sections, {
		id = "pane",
		height = paneH,
		element = paneElement,
	})
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(PageScaffold, {
		gap = 12,
		tailPad = scrollTail(stack, chrome.bottomSafe, 64),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		sections = sections,
	}), mobileHudAvailable and activeSection == "mobile" and React.createElement(MobileControls, {
		visible = mobileEdit,
		dispatch = dispatch,
		reducedMotion = softMotion,
		onClose = function()
			return setMobileEdit(false)
		end,
		slots = mobileSlots,
		scales = {
			quick = savedValue(state.Settings, "MobileQuickScale"),
			dock = savedValue(state.Settings, "MobileDockScale"),
			toasts = savedValue(state.Settings, "MobileToastScale"),
		},
		opacities = {
			quick = savedValue(state.Settings, "MobileQuickOpacity"),
			dock = savedValue(state.Settings, "MobileDockOpacity"),
			toasts = savedValue(state.Settings, "MobileToastOpacity"),
		},
	}))
end
return {
	SettingsView = SettingsView,
}
end

-- ======================================================================
-- Module: CommandView   (merged from CommandView.luau, 1586 lines)
-- ======================================================================
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
-- ▼ ReadonlyArray.map ▼
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
-- ▲ ReadonlyArray.map ▲
local TAB_OPTIONS = _newValue
-- ▼ ReadonlyArray.map ▼
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
-- ▲ ReadonlyArray.map ▲
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
	return React.createElement(SegmentedTabs, {
		options = if stack then TAB_OPTIONS_SHORT else TAB_OPTIONS,
		value = active,
		onChange = setActive,
		accent = Palette.cyan,
		columns = #TABS,
		gap = 4,
		size = UDim2.new(1, 0, 0, if stack then 52 else 48),
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
	_attributes.sizeConstraint = UDim2.new(1, -18, 0, if props.stack then 27 else 23)
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
local function CommandView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onSectionChange = _param.onSectionChange
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	-- meters, and claim CTAs all snap when tier<=1 or ambient is off (parity with Shop/Trade).
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
	local now, setNow = React.useState(os.time())
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
				setNow(os.time())
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
	local statusLine = if activeId == "" then "Launch an unlocked adventure below." elseif expeditionReady then "Crew is home — collect rewards." else `Back in {clockText(math.max(0, activeEnds - now))}`
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
	-- Gamepad: park Selection on the highest-priority Command claim CTA for the active tab.
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
	-- ▼ ReadonlyArray.find ▼
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
	-- ▲ ReadonlyArray.find ▲
	local activeConfig = _result_3
	local _exp_1 = ops.Artifacts
	-- ▼ ReadonlyArray.filter ▼
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
	-- ▲ ReadonlyArray.filter ▲
	local ownedArtifacts = #_newValue_2
	local _exp_2 = ops.SeasonTiers
	-- ▼ ReadonlyArray.find ▼
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
	-- ▲ ReadonlyArray.find ▲
	local nextTier = _result_4
	local seasonFill = if nextTier then meterFill(command.SeasonXP, math.max(1, nextTier.RequiredXP)) else 1
	local seasonStatus = if nextTier then if command.SeasonXP >= nextTier.RequiredXP then `Gift {nextTier.Tier} is ready` else `{compactNumber(nextTier.RequiredXP - command.SeasonXP)} XP to gift {nextTier.Tier}` else "All season gifts claimed"
	local budget = chrome.contentBudget
	local panelPad = 14
	local gridGap = 8
	local heroH = if stack then 156 else fitPanelHeight(168, budget, 168, if chrome.landscape then 0.4 else 0.5)
	local crewCols = if stack then 1 else 3
	local crewCellH = if stack then 108 else 120
	local crewRows = math.max(1, math.ceil(#CREW_ROLES / crewCols))
	local crewH = gridPanelHeight(54, crewRows, crewCellH, gridGap, panelPad)
	local weeklyItemH = if stack then 148 else 92
	local weeklyStride = if stack then 156 else 100
	local weeklyCount = math.max(1, #command.Weekly)
	local weeklyH = panelPad * 2 + 36 + (weeklyCount - 1) * weeklyStride + weeklyItemH
	local titleCols = if stack then 1 else 4
	local titleCellH = if stack then 142 else 126
	local titleRows = math.max(1, math.ceil(math.max(1, #command.Titles) / titleCols))
	local titlesH = if titlesEnabled then gridPanelHeight(52, titleRows, titleCellH, gridGap, panelPad) else 112
	local shopCols = if stack then 2 else 4
	local shopCellH = if stack then 150 else 160
	local shopRows = math.max(1, math.ceil(math.max(1, #command.Shop) / shopCols))
	local shopH = gridPanelHeight(36, shopRows, shopCellH, gridGap, panelPad)
	local masteryCols = if stack then 2 else 3
	local masteryCellH = 64
	local masteryRows = math.max(1, math.ceil(math.max(1, #config.Machines) / masteryCols))
	local masteryH = gridPanelHeight(36, masteryRows, masteryCellH, gridGap, panelPad)
	local expeditionHeroH = fitPanelHeight(if stack then 180 else 140, budget, 120, 0.4)
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
	local tabsH = if stack then 52 else 48
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
			position = UDim2.fromOffset(0, if stack then 100 else 112),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}), React.createElement("frame", {
			-- FocusClaim prefers Claim-named hosts; commander rank gift is the Overview primary CTA.
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
		-- ▼ ReadonlyArray.map ▼
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
		-- ▲ ReadonlyArray.map ▲
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
		-- VirtualGrid long Weekly catalogs so Overview never map-mounts every directive.
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
					-- FocusClaim prefers Claim-named hosts; weekly CLAIM is the Overview job CTA.
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
			-- FocusClaim prefers Claim-named hosts; COLLECT is the expedition claim CTA.
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
		}))), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #ops.Expeditions,
			columns = 1,
			cellHeight = expeditionRowH,
			gap = Layout.panelGap,
			overscanRows = if softMotion then 0 else 1,
			layoutOrder = nextOrder(),
			itemKey = function(index)
				local expedition = ops.Expeditions[index + 1]
				return if expedition ~= nil then expedition.Id else `expedition-{index}`
			end,
			renderItem = function(index)
				local expedition = ops.Expeditions[index + 1]
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
					value = `Lv {expedition.RequiredLevel}  ·  {clockText(expedition.Duration)}`,
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
			}, React.createElement(IconTile, {
				kind = artifactIcon(artifact.Id),
				accent = if owned then artifact.Color else Palette.muted,
				size = 46,
				radius = 12,
				position = UDim2.fromOffset(0, if stack then 6 else 18),
				reducedMotion = reducedMotion,
			}), React.createElement(Text, {
				value = if owned then `{artifact.Rarity}  ·  Lv {owned.Level}/10` else artifact.Rarity,
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
	-- Fill body expands into leftover viewport when the tab is short; intrinsic height
	-- (content floor) keeps hostRef VirtualGrid rows reachable when the list is long.
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
return {
	CommandView = CommandView,
}
end

-- ======================================================================
-- Module: AdminView   (merged from AdminView.luau, 943 lines)
-- ======================================================================
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

-- Admin is the one page that is deliberately desktop-only: a fixed three-column
-- console instead of the stacked/reflow layout every other page uses. On small
-- windows the columns get narrow but never reflow — the owner tooling stays
-- predictable instead of rearranging under the cursor. PageScaffold owns the
-- outer Y scroll; FlatList owns the long player/command catalogs.
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
	return (string.find(string.lower(hay), string.lower(needle), 1, true)) ~= nil
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

-- Stat tile for the target inspect grid.
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

local function AdminView(_param)
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
	local shakeToken, setShakeToken = React.useState(0)
	local lastNote, setLastNote = React.useState((admin and admin.LastAction and admin.LastAction.Message) or "")
	local lastOk, setLastOk = React.useState((admin and admin.LastAction and admin.LastAction.Ok) or true)
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
	end, { admin and admin.Banned, admin and admin.Commands, command, config })

	React.useEffect(function()
		if not (admin and admin.LastAction) then return end
		setLastNote(admin.LastAction.Message)
		setLastOk(admin.LastAction.Ok)
	end, { admin and admin.LastAction })

	if not (admin and admin.Access == true) then
		return React.createElement(EmptyState, {
			icon = "Lock",
			title = "Owner tools locked",
			body = "Only the game owner can open this page.",
			accent = Palette.coral,
		})
	end

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

	local execute = function()
		if busy then return end
		if needsArm and not armed then
			setArmed(true)
			Audio:play("adminArm")
			return
		end
		setBusy(true)
		local attempt = executeAttempt.current + 1
		executeAttempt.current = attempt
		Audio:play("adminExecute")
		local sendAmount = if amount == "Permanent" then "1" else (if amount ~= "" then amount else "1")
		local sendOption = if amount == "Permanent" then "Permanent" else option
		local sendTarget = if fields.overridesTarget then (tonumber(amount) or targetId) else targetId
		dispatch("AdminExecute", {
			TargetUserId = sendTarget,
			Command = command,
			Amount = sendAmount,
			Option = sendOption,
			Reason = reason,
			Nonce = HttpService:GenerateGUID(false),
		}, function(response)
			if not mountedRef.current or executeAttempt.current ~= attempt then return end
			setBusy(false)
			setArmed(false)
			setLastOk(response.ok == true)
			setLastNote(if response.ok == true then (response.message or "Done.") else (response.error or "Failed."))
			if response.ok ~= true then
				setShakeToken(function(t) return t + 1 end)
			end
		end)
	end

	local runDisabled = busy or (if fields.overridesTarget then #fields.amountChoices == 0 else targetId == 0) or (needsArm and #reason < 3)
	local runLabel = if busy then "APPLYING…" elseif needsArm and not armed then "ARM" else "RUN"
	local runColor = if busy then Palette.panelSoft elseif needsArm and armed then Palette.coral elseif needsArm then Palette.mango else Palette.mint

	-- Fixed geometry. The page area is always treated as a desktop console:
	-- header on top, three columns below, no reflow.
	local FIELD_H = 50
	local EXEC_TITLE = 40
	local EXEC_BUTTON = 46
	local EXEC_NOTE = 36
	local executeH = EXEC_TITLE + math.max(0, fieldSlots) * FIELD_H + EXEC_BUTTON + EXEC_NOTE + 20

	local INSPECT_TITLE = 34
	local STAT_H = 40
	local STAT_GAP = 8
	local inspectH = INSPECT_TITLE + STAT_H * 2 + STAT_GAP + 26

	-- Header bar.
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

	-- Column 1: players.
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

	-- Column 2: commands.
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

	-- Column 3 top: target inspect.
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

	-- Column 3 middle: execute dock.
	local executeActionsHostRef = React.useRef(nil)
	-- Gamepad: park Selection on ARM/RUN (FocusClaim prefers Confirm-named hosts).
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
		-- FocusClaim ARM/RUN must not clip CTA overshoot.
		ClipsDescendants = false,
		ref = executeActionsHostRef,
	}, React.createElement("frame", {
		Name = "AdminConfirmRun",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- FocusClaim ARM/RUN must not clip CTA overshoot.
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = runLabel,
		icon = "Lock",
		onClick = execute,
		color = runColor,
		textColor = Palette.ink,
		size = UDim2.fromOffset(200, 36),
		position = UDim2.new(0.5, -100, 0.5, -18),
		disabled = runDisabled,
		loading = busy,
		shakeToken = shakeToken,
		highlight = armed or not needsArm,
			reducedMotion = softMotion,
	}))), React.createElement(Text, {
		value = if lastNote ~= "" then lastNote else (if needsArm then "Arm first. Dangerous commands need a second tap." else "Economy, progress, and item grants run on one tap."),
		size = 9,
		color = if lastNote ~= "" then (if lastOk then Palette.mint else Palette.coral) else Palette.muted,
		wrap = true,
		fit = false,
		position = UDim2.new(0, 0, 1, -EXEC_NOTE + 4),
		sizeConstraint = UDim2.new(1, 0, 0, EXEC_NOTE - 4),
	}))

	-- Column 3 bottom: recent audit feed fills whatever is left.
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

	-- Fixed three-column console: PLAYERS | COMMANDS | TARGET+EXECUTE+RECENT.
	-- PageScaffold owns outer Y scroll when the viewport is shorter than the console
	-- body; UISizeConstraint keeps the owner console at CONSOLE_W so columns never reflow.
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

return {
	AdminView = AdminView,
}
end

-- ======================================================================
-- Module: AnomalyView   (merged from AnomalyView.luau, 572 lines)
-- ======================================================================
__defs["AnomalyView"] = function()
-- Shift Plan
-- One card tells you the single best action for progress. Under it, the same
-- reactor actions stay available in plain language: pulse, bank, one boost,
-- permanent upgrades, and today's jobs.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local scaledCost = _format.scaledCost
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text

local PROTOCOL_ROW = 72

local function protocolLevel(anomaly, id)
	local levels = anomaly.Protocols
	if type(levels) ~= "table" then
		return 0
	end
	local level = levels[id]
	if type(level) ~= "number" then
		return 0
	end
	return level
end

local function loadoutHas(anomaly, id)
	local loadout = anomaly.Loadout
	if type(loadout) ~= "table" then
		return anomaly.Channel == id
	end
	for _, entry in loadout do
		if entry == id then
			return true
		end
	end
	return anomaly.Channel == id
end

local function claimableDirective(anomaly)
	local directives = anomaly.Directives
	if type(directives) ~= "table" then
		return nil
	end
	for _, directive in directives do
		if directive.Claimed ~= true and (tonumber(directive.Progress) or 0) >= (tonumber(directive.Target) or 1) then
			return directive
		end
	end
	return nil
end

local function cheapestProtocol(anomaly, protocols)
	local best = nil
	local bestCost = math.huge
	for _, protocol in protocols do
		local level = protocolLevel(anomaly, protocol.Id)
		local maxLevel = protocol.MaxLevel
		if maxLevel == nil or level < maxLevel then
			local cost = scaledCost(protocol.BaseCost, protocol.CostScale, level)
			local numeric = tonumber(cost)
			if numeric ~= nil and numeric < bestCost and gteFlux(anomaly.Fragments, cost) then
				best = protocol
				bestCost = numeric
			end
		end
	end
	return best
end

local function readyMilestone(anomaly)
	local milestones = anomaly.Milestones
	if type(milestones) ~= "table" then
		return nil
	end
	local done = tonumber(anomaly.Stabilizations) or 0
	for _, entry in milestones do
		if entry.Claimed ~= true and done >= (tonumber(entry.Required) or 1) then
			return entry
		end
	end
	return nil
end

local function nextStep(anomaly, config)
	local milestone = readyMilestone(anomaly)
	if milestone ~= nil then
		return {
			title = "Claim the rank reward",
			body = `You have banked enough charges for tier {compactNumber(milestone.Tier)}. Claim it before you spend fragments.`,
			accent = Palette.mango,
		}
	end
	local job = claimableDirective(anomaly)
	if job ~= nil then
		return {
			title = "Claim today's job",
			body = `{job.Name} is finished. Claiming it pays fragments you can spend on a permanent upgrade.`,
			accent = Palette.mint,
		}
	end
	if anomaly.Ready == true then
		return {
			title = "Bank the charge",
			body = "The bar is full. Banking pays rewards and starts a fresh charge. Do this before you pulse again.",
			accent = Palette.mango,
		}
	end
	local protocol = cheapestProtocol(anomaly, config.Protocols or {})
	if protocol ~= nil then
		return {
			title = `Buy {protocol.Name}`,
			body = `{protocol.Description} Permanent upgrades beat another pulse when you can already afford one.`,
			accent = Palette.cyan,
		}
	end
	local charge = math.clamp((tonumber(anomaly.Charge) or 0) / math.max(1, tonumber(anomaly.Target) or 1), 0, 1)
	return {
		title = "Pulse the charge",
		body = `The bar is {math.floor(charge * 100)}% full. Each pulse fills it. Bank it when it hits 100%.`,
		accent = Palette.pink,
	}
end

local function StepCard(props)
	local step = props.step
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = step.accent,
		background = Palette.panelRaised,
		padding = 16,
		highlight = true,
			reducedMotion = props.reducedMotion,
	}, React.createElement(Text, {
		value = "DO THIS NEXT",
		size = 11,
		color = step.accent,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Text, {
		value = step.title,
		size = 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Text, {
		value = step.body,
		size = 14,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 58),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
		reducedMotion = props.reducedMotion,
	}))
end

local function ActionRow(props)
	return React.createElement("frame", {
		Size = UDim2.new(if props.wide then 1 else 0.5, if props.wide then 0 else -4, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, React.createElement(Button, {
		text = props.text,
		size = UDim2.fromScale(1, 1),
		color = if props.highlight then (props.color or Palette.cyan) else Palette.panelSoft,
		textColor = if props.highlight then Palette.ink else Palette.cream,
		disabled = props.disabled,
		highlight = false,
		reducedMotion = props.reducedMotion,
		onClick = props.onClick,
	}))
end

local function ProtocolRow(props)
	local protocol = props.protocol
	local level = protocolLevel(props.anomaly, protocol.Id)
	local cost = scaledCost(protocol.BaseCost, protocol.CostScale, level)
	local affordable = gteFlux(props.anomaly.Fragments, cost)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, PROTOCOL_ROW - 8),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Text, {
		value = `{protocol.Name}  ·  level {compactNumber(level)}`,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 6),
		sizeConstraint = UDim2.new(1, -150, 0, 18),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Text, {
		value = protocol.Description,
		size = 12,
		color = Palette.creamSoft,
		position = UDim2.fromOffset(10, 28),
		sizeConstraint = UDim2.new(1, -150, 0, 18),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Button, {
		text = `BUY {compactNumber(cost)}`,
		disabled = not affordable,
		highlight = affordable,
		reducedMotion = props.reducedMotion,
		position = UDim2.new(1, -132, 0.5, -18),
		size = UDim2.fromOffset(122, 36),
		onClick = function()
			props.dispatch("BuyAnomalyProtocol", { Id = protocol.Id })
		end,
	}))
end

local function channelRows(config)
	local rows = {}
	local channels = config.Channels or {}
	for id, channel in channels do
		table.insert(rows, {
			id = id,
			name = channel.Name or id,
			description = channel.Description or "",
		})
	end
	table.sort(rows, function(left, right)
		return left.name < right.name
	end)
	return rows
end

local function ShiftPlan(_param)
	local anomaly = _param.anomaly
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local claimRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { anomaly.Ready, anomaly.Charge })
	local step = nextStep(anomaly, config)
	local charge = math.clamp((tonumber(anomaly.Charge) or 0) / math.max(1, tonumber(anomaly.Target) or 1), 0, 1)
	local protocols = config.Protocols or {}
	local channels = channelRows(config)
	local job = claimableDirective(anomaly)
	local milestone = readyMilestone(anomaly)
	local channelH = 36 + #channels * 40
	local sectionGap = if stack then chrome.panelGap else Layout.panelGap
	local sections = {
		{
			id = "step",
			height = 132,
			element = React.createElement(StepCard, {
				step = step,
				reducedMotion = reducedMotion,
			}),
		},
		{
			id = "actions",
			height = 80 + (if stack then TapTarget * 2 + 8 else TapTarget),
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.pink,
				background = Palette.panel,
				padding = 12,
				reducedMotion = softMotion,
				clips = false,
			}, React.createElement(Text, {
				value = `Charge {math.floor(charge * 100)}%    ·    {compactNumber(anomaly.Fragments)} fragments`,
				size = 13,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 18),
				reducedMotion = softMotion,
			}), React.createElement(Meter, {
				value = charge,
				color = Palette.pink,
				reducedMotion = softMotion,
				position = UDim2.fromOffset(0, 24),
				size = UDim2.new(1, 0, 0, 8),
			}), React.createElement("frame", {
				Name = "AnomalyClaimActions",
				Size = UDim2.new(1, 0, 0, if stack then TapTarget * 2 + 8 else TapTarget),
				Position = UDim2.fromOffset(0, 44),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ref = claimRef,
			}, React.createElement("uilistlayout", {
				FillDirection = if stack then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}), React.createElement(ActionRow, {
				order = 0,
				wide = stack,
				text = "PULSE",
				color = Palette.pink,
				highlight = anomaly.Ready ~= true,
				reducedMotion = softMotion,
				onClick = function()
					dispatch("PulseAnomaly", {})
				end,
			}), React.createElement(ActionRow, {
				order = 1,
				wide = stack,
				text = "BANK",
				color = Palette.mint,
				disabled = anomaly.Ready ~= true,
				highlight = anomaly.Ready == true,
				reducedMotion = softMotion,
				onClick = function()
					dispatch("StabilizeAnomaly", {})
				end,
			}))),
		},
		{
			id = "boost",
			height = channelH + 28,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.cyan,
				background = Palette.panelRaised,
				padding = 12,
				reducedMotion = softMotion,
			}, React.createElement(Text, {
				value = "ONE BOOST  ·  switch it when your goal changes",
				size = 11,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 16),
				reducedMotion = softMotion,
			}), (function()
				local children = {}
				for index, channel in channels do
					local on = loadoutHas(anomaly, channel.id)
					children[index] = React.createElement(Button, {
						key = channel.id,
						text = if on then `{channel.name}  ON` else channel.name,
						color = if on then Palette.cyan else Palette.panelSoft,
						textColor = if on then Palette.ink else Palette.cream,
						highlight = false,
						reducedMotion = softMotion,
						position = UDim2.fromOffset(0, 24 + (index - 1) * 40),
						size = UDim2.new(1, 0, 0, 34),
						onClick = function()
							dispatch("SetAnomalyLoadout", {
								Loadout = { channel.id },
							})
						end,
					})
				end
				return React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, table.unpack(children))
			end)()),
		},
		{
			id = "upgrades",
			height = 36 + math.max(1, #protocols) * PROTOCOL_ROW,
			element = React.createElement(FlatList, {
				data = protocols,
				itemHeight = PROTOCOL_ROW,
				headerHeight = 28,
				overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
				canvasTail = 8,
				Size = UDim2.fromScale(1, 1),
				scrollBarColor = Palette.cyan,
				scrollBarThickness = 3,
				keyExtractor = function(protocol)
					return protocol.Id
				end,
				renderItem = function(row)
					return React.createElement(ProtocolRow, {
						protocol = row.item,
						anomaly = anomaly,
						dispatch = dispatch,
						reducedMotion = softMotion,
					})
				end,
				ListHeaderComponent = React.createElement("frame", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(Text, {
					value = "PERMANENT UPGRADES  ·  bought with fragments",
					size = 11,
					color = Palette.muted,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
						reducedMotion = softMotion,
				})),
			}),
		},
	}
	if milestone ~= nil then
		table.insert(sections, 3, {
			id = "milestone",
			height = 88,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.mango,
				background = Palette.panelRaised,
				padding = 12,
				reducedMotion = reducedMotion,
			}, React.createElement(Text, {
				value = `Tier {compactNumber(milestone.Tier)} reward is ready`,
				size = 16,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, -140, 0, 22),
				reducedMotion = reducedMotion,
			}), React.createElement(Button, {
				text = "CLAIM",
				highlight = true,
				reducedMotion = reducedMotion,
				position = UDim2.new(1, -120, 0.5, -18),
				size = UDim2.fromOffset(110, 36),
				onClick = function()
					dispatch("ClaimAnomalyMilestone", { Tier = milestone.Tier })
				end,
			})),
		})
	end
	if job ~= nil then
		table.insert(sections, 3, {
			id = "job",
			height = 88,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.mint,
				background = Palette.panelRaised,
				padding = 12,
				reducedMotion = reducedMotion,
			}, React.createElement(Text, {
				value = job.Name,
				size = 16,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, -140, 0, 22),
				reducedMotion = reducedMotion,
			}), React.createElement(Button, {
				text = "CLAIM",
				highlight = true,
				reducedMotion = reducedMotion,
				position = UDim2.new(1, -120, 0.5, -18),
				size = UDim2.fromOffset(110, 36),
				onClick = function()
					dispatch("ClaimAnomalyDirective", { Id = job.Id })
				end,
			})),
		})
	end
	return React.createElement(PageScaffold, {
		gap = sectionGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, if stack then 56 else 40),
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = sections,
	})
end

local function loadoutKey(anomaly)
	if type(anomaly.Loadout) ~= "table" then
		return tostring(anomaly.Channel)
	end
	return table.concat(anomaly.Loadout, ",")
end

local function protocolKey(anomaly)
	if type(anomaly.Protocols) ~= "table" then
		return ""
	end
	local parts = {}
	for id, level in anomaly.Protocols do
		table.insert(parts, `{id}:{level}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function AnomalyViewComponent(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	if state.Anomaly == nil or config.Anomalies == nil then
		return React.createElement(EmptyState, {
			icon = "Anomaly",
			title = "Shift plan resting",
			body = "Come back when the next charge window starts.",
			accent = Palette.pink,
		})
	end
	return React.createElement(ShiftPlan, {
		anomaly = state.Anomaly,
		config = config.Anomalies,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
	})
end

local AnomalyView = React.memo(AnomalyViewComponent, function(previous, incoming)
	local left = previous.state.Anomaly
	local right = incoming.state.Anomaly
	if left == right then
		return previous.reducedMotion == incoming.reducedMotion and previous.config == incoming.config and previous.dispatch == incoming.dispatch
	end
	if left == nil or right == nil then
		return false
	end
	return previous.config == incoming.config
		and previous.dispatch == incoming.dispatch
		and previous.reducedMotion == incoming.reducedMotion
		and left.Charge == right.Charge
		and left.Target == right.Target
		and left.Ready == right.Ready
		and left.Fragments == right.Fragments
		and left.Channel == right.Channel
		and loadoutKey(left) == loadoutKey(right)
		and protocolKey(left) == protocolKey(right)
		and left.Stabilizations == right.Stabilizations
		and #(left.Directives or {}) == #(right.Directives or {})
		and #(left.Milestones or {}) == #(right.Milestones or {})
end)

return {
	AnomalyView = AnomalyView,
}
end

-- ======================================================================
-- Module: LeaderboardsView   (merged from LeaderboardsView.luau, 1276 lines)
-- ======================================================================
__defs["LeaderboardsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _Icon = require(script.Parent.Parent.ArtKit)("Icon")
local Icon = _Icon.Icon
local PlayerMark = _Icon.PlayerMark
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _ui = require(script.Parent.Parent.UiCore)("ui")
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
				pcall(task.cancel, timer)
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
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local boardReveal = useStagger(0, softMotion)
	local scopeReveal = useStagger(1, softMotion)
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
			pcall(task.cancel, selectJob)
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
			pcall(task.cancel, queuedRefresh.current)
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
				pcall(task.cancel, refreshTimer)
			end
			if queuedRefresh.current ~= nil then
				pcall(task.cancel, queuedRefresh.current)
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
			reducedMotion = reducedMotion,
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
					reducedMotion = reducedMotion,
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
					reducedMotion = reducedMotion,
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
				reducedMotion = reducedMotion,
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
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
