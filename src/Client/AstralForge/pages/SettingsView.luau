local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local MobileControls = require(script.Parent.Parent.MobileControls).MobileControls
local _mobileLayout = require(script.Parent.Parent.mobileLayout)
local fitTouchGridWidth = _mobileLayout.fitTouchGridWidth
local moreDockHeight = _mobileLayout.moreDockHeight
local _motion = require(script.Parent.Parent.motion)
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _ui = require(script.Parent.Parent.ui)
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
	description = "The soundtrack while you play.",
	accent = Palette.mint,
	section = "audio",
	kind = "toggle",
}, {
	id = "MusicCrossfade",
	label = "Music crossfade",
	description = "How long beds blend when you change pages.",
	accent = Palette.mint,
	section = "audio",
}, {
	id = "SoundVariation",
	label = "Sound variation",
	description = "Slight pitch change so clicks don't all sound identical.",
	accent = Palette.violet,
	section = "audio",
}, {
	id = "PageStingers",
	label = "View opening cues",
	description = "A short sting when you open a new page.",
	accent = Palette.blue,
	section = "audio",
	kind = "toggle",
}, {
	id = "MotionIntensity",
	label = "Animation amount",
	description = "How much menus bounce and slide. Zero is still.",
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
	label = "Next unlock bar",
	description = "Always show the next feature unlock under the page title.",
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
	UiVolume = 0.9,
	GameplayVolume = 1,
	RewardVolume = 1,
	AmbientVolume = 0.75,
	HoverSounds = 1,
	NotificationSounds = 1,
	PageMusic = 1,
	MusicCrossfade = 0.62,
	SoundVariation = 0.7,
	PageStingers = 1,
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
			MusicVolume = 0.22,
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
			MusicVolume = 0.38,
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
			MusicVolume = 0.32,
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
	local reveal = useStagger(math.min(index, 5), reducedMotion, 0.01, 0.14)
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
		_attributes.reducedMotion = reducedMotion
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
			reducedMotion = reducedMotion,
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
			reducedMotion = reducedMotion,
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
		reducedMotion = reducedMotion,
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
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
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
			task.cancel(selectJob)
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
	local headerH = if stack then 232 else 156
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
	local tabsH = tabRows * (TapTarget + 8) + 20
	local editorH = if mobileHudAvailable and activeSection == "mobile" then (if stack then 138 else 92) else 0
	local paneH = 42 + #visibleRows * rowStride + editorH
	local headerReveal = useStagger(0, softMotion)
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
		reveal = headerReveal,
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
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(300, 42),
		Position = if stack then UDim2.fromOffset(0, 70) else UDim2.new(1, -300, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
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
		reducedMotion = reducedMotion,
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
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(300, 42),
		Position = if stack then UDim2.fromOffset(0, 70 + TapTarget + 10) else UDim2.new(1, -300, 0, 62),
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
		reducedMotion = reducedMotion,
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
		reducedMotion = reducedMotion,
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
		reducedMotion = reducedMotion,
		highlight = preset == "high",
	})))
	local _exp_3 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = SECTION_META[activeSection].accent,
		background = Palette.panelRaised,
		padding = 10,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(SegmentedTabs, {
		options = sectionOptions,
		value = activeSection,
		onChange = setActiveSection,
		accent = SECTION_META[activeSection].accent,
		columns = tabCols,
		gap = 8,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))
	local _exp_3b = controllerHintsH > 0 and React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panelRaised,
		padding = 14,
		reducedMotion = reducedMotion,
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
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#visibleRows)
	local _callback_3 = function(data, index)
		return React.createElement(SettingRow, {
			key = data.id,
			data = data,
			index = index,
			state = state,
			dispatch = dispatch,
			reducedMotion = reducedMotion,
			layoutOrder = index + 1,
			stack = touchRows,
			touch = touch,
		})
	end
	for _k, _v in visibleRows do
		_newValue_2[_k] = _callback_3(_v, _k - 1, visibleRows)
	end
	-- ▲ ReadonlyArray.map ▲
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
	}), _exp_5, _newValue_2, mobileHudAvailable and activeSection == "mobile" and React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, if stack then 128 else 82),
		accent = Palette.cyan,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = #visibleRows + 1,
		reducedMotion = reducedMotion,
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
		reducedMotion = reducedMotion,
	}))))
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
		reducedMotion = reducedMotion,
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
