local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local ClientLog = require(script.Parent.Parent.log).ClientLog
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _motion = require(script.Parent.Parent.motion)
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local DEV_USERNAME = "usingINales"
local DEV_USER_ID = 10916707683
local function DevAvatarThumbnail(_param)
	local size = _param.size
	return React.createElement("imagelabel", {
		Size = size,
		BackgroundColor3 = darken(Palette.violet, 0.62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarBust&id={DEV_USER_ID}&w=420&h=420`,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 330,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		Color = Palette.violet,
		Thickness = 1.5,
		Transparency = 0.28,
	}))
end
local ROLES = { {
	label = "Design",
	detail = "Loops, screens, and Bay Seven tone",
}, {
	label = "Code",
	detail = "Client, server, and economy",
}, {
	label = "World",
	detail = "Story, missions, and docks",
} }
local function CreditsOverlay(_param)
	local version = _param.version
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local requestClose = React.useCallback(function()
		if exiting then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, exiting, onClose })
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local pad = if stack then 14 else 22
	local safeSide = math.max(8, viewport.sideInset, chrome.sideSafe)
	local safeTop = math.max(8, viewport.topInset)
	local safeBottom = math.max(8, viewport.bottomInset, chrome.bottomSafe)
	local availableWidth = math.max(220, viewport.width - safeSide * 2 - 12)
	local width = math.min(if stack then 600 else 620, availableWidth)
	local desired = if stack then 520 else 460
	local availableHeight = math.max(220, viewport.height - safeTop - safeBottom - 12)
	local height = math.min(desired, availableHeight)
	local centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2)
	local avatarSize = if stack then math.min(160, math.floor(width - pad * 2 - 8)) else 188
	local closeSize = math.max(TapTarget - 4, 44)
	local stackBodyTop = 70
	local stackBodyReserve = closeSize + 16
	local stackBodyH = math.max(120, height - pad * 2 - stackBodyTop - stackBodyReserve)
	local rolesListH = 132
	local avatarBlockH = avatarSize + 8 + 28 + 8 + 28 + 8 + 48
	local attributionH = 20
	React.useEffect(function()
		ClientLog:debug("nav", "credits opened")
		return function()
			return ClientLog:debug("nav", "credits closed")
		end
	end, {})
	local padFocus = useGamepadAutofocus(true)
	local overlayHostRef = React.useRef(nil)
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
		local host = overlayHostRef.current or padFocus.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			task.cancel(job)
		end
	end, {})
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 319,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 320,
	})
	local _exp_2 = React.createElement(Text, {
		value = "CREDITS",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 16),
		zIndex = 322,
	})
	local _exp_3 = React.createElement(Text, {
		value = "ASTRAL FORGE",
		size = if stack then 20 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 32),
		zIndex = 322,
	})
	local _exp_4 = React.createElement(Text, {
		value = `VERSION {version}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, -(closeSize + 12), 0, 14),
		zIndex = 322,
	})
	local _exp_5 = React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromOffset(closeSize, closeSize),
		position = UDim2.new(1, -closeSize, 0, 0),
		reducedMotion = softMotion,
		disabled = exiting,
		zIndex = 323,
	})
	local _result
	if stack then
		local avatarBlock = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(avatarSize, avatarSize),
			Position = UDim2.fromOffset(math.floor((width - pad * 2 - avatarSize) / 2), 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, React.createElement(DevAvatarThumbnail, {
			size = UDim2.fromScale(1, 1),
		})), React.createElement(Badge, {
			value = "SOLO DEV",
			accent = Palette.violet,
			filled = true,
			size = UDim2.fromOffset(110, 28),
			position = UDim2.fromOffset(math.floor((width - pad * 2 - 110) / 2), avatarSize + 8),
			zIndex = 322,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, avatarSize + 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = DEV_USERNAME,
			TextColor3 = Palette.cream,
			TextSize = 18,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 322,
		}), React.createElement(Text, {
			value = "Thanks for playing. Built solo — machines, worlds, and stories included.",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, avatarSize + 72),
			sizeConstraint = UDim2.new(1, 0, 0, 48),
			zIndex = 322,
		}))
		local _exp_10 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#ROLES)
		local _callback = function(role, index)
			return React.createElement("frame", {
				key = role.label,
				Size = UDim2.new(1, 0, 0, 38),
				LayoutOrder = index,
				BackgroundColor3 = Palette.panel,
				BorderSizePixel = 0,
				ZIndex = 322,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 8),
			}), React.createElement(Text, {
				value = role.label,
				size = 11,
				color = Palette.violet,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(10, 4),
				sizeConstraint = UDim2.new(1, -20, 0, 14),
				zIndex = 323,
			}), React.createElement(Text, {
				value = role.detail,
				size = 11,
				color = Palette.creamSoft,
				wrap = true,
				fit = false,
				position = UDim2.fromOffset(10, 18),
				sizeConstraint = UDim2.new(1, -20, 0, 16),
				zIndex = 323,
			}))
		end
		for _k, _v in ROLES do
			_newValue[_k] = _callback(_v, _k - 1, ROLES)
		end
		-- ▲ ReadonlyArray.map ▲
		local rolesBlock = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, _exp_10, _newValue)
		local attribution = React.createElement(Text, {
			value = "Interface icons by Flaticon / Freepik Company",
			size = 9,
			color = Palette.muted,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 16),
			zIndex = 322,
		})
		_result = React.createElement(PageScaffold, {
			size = UDim2.new(1, 0, 0, stackBodyH),
			position = UDim2.fromOffset(0, stackBodyTop),
			gap = 8,
			tailPad = 4,
			scrollBarColor = Palette.violet,
			scrollBarThickness = 3,
			zIndex = 322,
			sections = {
				{
					id = "avatar",
					height = avatarBlockH,
					element = avatarBlock,
				},
				{
					id = "roles",
					height = rolesListH,
					element = rolesBlock,
				},
				{
					id = "attribution",
					height = attributionH,
					element = attribution,
				},
			},
		})
	else
		local _exp_6 = React.createElement("frame", {
			Size = UDim2.fromOffset(avatarSize, avatarSize),
			Position = UDim2.fromOffset(0, 78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, React.createElement(DevAvatarThumbnail, {
			size = UDim2.fromScale(1, 1),
		}))
		local _exp_7 = React.createElement(Badge, {
			value = "SOLO DEV",
			accent = Palette.violet,
			filled = true,
			size = UDim2.fromOffset(110, 28),
			position = UDim2.fromOffset(avatarSize + 20, 78),
			zIndex = 322,
		})
		local _exp_8 = React.createElement("textlabel", {
			Size = UDim2.new(1, -(avatarSize + 28), 0, 34),
			Position = UDim2.fromOffset(avatarSize + 20, 110),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = DEV_USERNAME,
			TextColor3 = Palette.cream,
			TextSize = 26,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 322,
		})
		local _exp_9 = React.createElement(Text, {
			value = "Built solo · code · UI · game design",
			size = 13,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(avatarSize + 20, 148),
			sizeConstraint = UDim2.new(1, -(avatarSize + 28), 0, 36),
			zIndex = 322,
		})
		local _exp_10 = React.createElement(Text, {
			value = "One person built the forge you're running. Thanks for playing.",
			size = 13,
			color = Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(avatarSize + 20, 188),
			sizeConstraint = UDim2.new(1, -(avatarSize + 28), 0, 44),
			zIndex = 322,
		})
		local _exp_11 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#ROLES)
		local _callback = function(role, index)
			return React.createElement("frame", {
				key = role.label,
				Size = UDim2.new(1 / 3, -8, 0, 112),
				LayoutOrder = index,
				BackgroundColor3 = Palette.panel,
				BorderSizePixel = 0,
				ZIndex = 322,
				ClipsDescendants = false,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 12),
			}), React.createElement("uistroke", {
				Color = lighten(Palette.violet, 0.1),
				Thickness = 1,
				Transparency = 0.55,
			}), React.createElement(Text, {
				value = string.upper(role.label),
				size = 10,
				color = Palette.violet,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(12, 14),
				sizeConstraint = UDim2.new(1, -24, 0, 16),
				zIndex = 323,
			}), React.createElement(Text, {
				value = role.detail,
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				fit = false,
				position = UDim2.fromOffset(12, 36),
				sizeConstraint = UDim2.new(1, -24, 0, 60),
				zIndex = 323,
			}))
		end
		for _k, _v in ROLES do
			_newValue[_k] = _callback(_v, _k - 1, ROLES)
		end
		-- ▲ ReadonlyArray.map ▲
		local desktopBody = React.createElement(React.Fragment, nil, _exp_6, _exp_7, _exp_8, _exp_9, _exp_10, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 112),
			Position = UDim2.fromOffset(0, 78 + avatarSize + 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 322,
		}, _exp_11, _newValue), React.createElement(Text, {
			value = "Interface icons by Flaticon / Freepik Company",
			size = 9,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(0, 400),
			sizeConstraint = UDim2.new(1, 0, 0, 14),
			zIndex = 322,
		}))
		-- Desktop fits without nested scroll; still mount PageScaffold so HOT_PAGES stays honest.
		_result = React.createElement(PageScaffold, {
			size = UDim2.fromScale(1, 1),
			gap = 0,
			tailPad = 0,
			scrollBarThickness = 0,
			scrollBarColor = Palette.violet,
			zIndex = 322,
			sections = {
				{
					id = "desktop",
					fill = true,
					minHeight = 420,
					height = 420,
					element = desktopBody,
				},
			},
		})
	end
	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		-- FocusClaim prefers Claim-named hosts; CLOSE is the primary Credits CTA.
		Name = "CreditsClaimActions",
		ref = overlayHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount * 0.82
		end),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = true,
		ZIndex = 318,
		Visible = reveal:map(function(amount)
			return amount > 0.003
		end),
	}, _exp, React.createElement("frame", {
		ref = padFocus,
		Size = UDim2.fromOffset(width, height),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 0, centerY + math.floor((1 - amount) * 18))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 320,
		Visible = reveal:map(function(amount)
			return amount > 0.002
		end),
	}, _exp_1, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = pad,
		zIndex = 321,
		clips = false,
		reveal = reveal,
		reducedMotion = softMotion,
	}, _exp_2, _exp_3, _exp_4, _exp_5, _result, stack and React.createElement("frame", {
		Size = UDim2.fromOffset(0, closeSize),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -2),
		BackgroundTransparency = 1,
		ZIndex = 323,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "CLOSE",
		icon = "Close",
		onClick = requestClose,
		color = Palette.violet,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, closeSize),
		hug = true,
		reducedMotion = softMotion,
		disabled = exiting,
		zIndex = 324,
	}))))))
end
return {
	CreditsOverlay = CreditsOverlay,
}
