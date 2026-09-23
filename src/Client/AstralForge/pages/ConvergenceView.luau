local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _format = require(script.Parent.Parent.format)
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.motion)
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local useWallClock = _motion.useWallClock
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local SECTION_LABEL_H = 28
local function ConvergenceView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local event = state.Convergence
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ConvergenceView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local now = useWallClock(event ~= nil)
	local enter = useEntrance(softMotion)
	local reveal = useStagger(0, softMotion)
	local revealTiers = useStagger(1, softMotion)
	-- Canonical softMotion antilag gate — ConvergenceTier.
	local revealClaim = useStagger(2, softMotion)
	-- Canonical softMotion antilag gate — ConvergenceHero.
	local revealHero = useStagger(3, softMotion)
	-- Canonical softMotion antilag gate — ConvergenceFill.
	local revealFill = useStagger(4, softMotion)
	local convergenceSoft = softMotion or revealHero == nil or revealFill == nil
	if event == nil then
		return React.createElement(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = Palette.mango,
			padding = 22,
			reveal = if softMotion then revealHero else enter,
			highlight = not convergenceSoft,
			reducedMotion = softMotion,
		}, React.createElement(Text, {
			value = "FORGE CONVERGENCE",
			size = 26,
			weight = Enum.FontWeight.Heavy,
		}), React.createElement(Text, {
			value = "Getting this week's shared forge ready…",
			size = 12,
			color = Palette.muted,
			position = UDim2.fromOffset(0, 42),
			sizeConstraint = UDim2.new(1, 0, 0, 30),
		}))
	end
	local globalFill = math.clamp(event.GlobalContribution / math.max(1, event.GlobalTarget), 0, 1)
	local tiers = event.Tiers or {}
	local heroHeight = if stack then 226 else 198
	local tierHeight = if stack then 154 else 94
	local pageGap = 12
	local tiersH = if #tiers > 0 then #tiers * tierHeight + math.max(0, #tiers - 1) * pageGap else 0
	local claimHostRef = React.useRef(nil)
	local firstClaimTier = nil
	for _, tier in tiers do
		if tier.CanClaim then
			firstClaimTier = tier.Tier
			break
		end
	end
	-- Gamepad: park Selection on the first claimable personal tier CTA.
	React.useEffect(function()
		if firstClaimTier == nil or not UserInputService.GamepadEnabled then
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
			task.cancel(selectJob)
		end
	end, { firstClaimTier, event.EventId })
	local _exp_2 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = 16,
		reveal = reveal,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "WEEKLY COOPERATIVE EVENT",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -120, 0, 16),
	}), React.createElement(Text, {
		value = event.Name,
		size = if stack then 25 else 31,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 18,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, -8, 0, 42),
	}), React.createElement(Text, {
		value = "Everyone contributes to the same weekly forge. Finish each phase together to unlock a global production boost.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 68),
		sizeConstraint = UDim2.new(1, -8, 0, 38),
	}), React.createElement(Badge, {
		value = event.PhaseName,
		accent = Palette.mango,
		filled = true,
		position = UDim2.new(0, 0, 1, -68),
		size = UDim2.fromOffset(112, 28),
	}), React.createElement(Text, {
		value = now:map(function(timestamp)
			return `{clockText(math.max(0, event.EndsAt - timestamp))} LEFT`
		end),
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -150, 1, -68),
		sizeConstraint = UDim2.fromOffset(150, 28),
	}), React.createElement(Meter, {
		value = globalFill,
		color = Palette.mango,
		position = UDim2.new(0, 0, 1, -28),
		size = UDim2.new(1, 0, 0, 9),
		reducedMotion = softMotion,
		shimmer = true,
	}), React.createElement(Text, {
		value = `{compactNumber(event.GlobalContribution)} / {compactNumber(event.GlobalTarget)}  •  {string.format("%.2fx", event.ProductionMultiplier)} PRODUCTION`,
		size = 10,
		color = Palette.creamSoft,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 0, 1, -18),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#tiers)
	local _callback = function(tier, index)
		local progress = math.clamp(event.PersonalContribution / math.max(1, tier.Required), 0, 1)
		local buttonColor = if tier.CanClaim then Palette.mint elseif tier.Claimed then Palette.panelSoft else Palette.violet
		local tierReveal = if tier.CanClaim then revealClaim else revealTiers
		return React.createElement(Panel, {
			key = `tier-{tier.Tier}`,
			size = UDim2.new(1, 0, 0, tierHeight),
			accent = if tier.CanClaim then Palette.mint else Palette.violet,
			padding = 13,
			layoutOrder = index,
			reveal = tierReveal,
			interactive = tier.CanClaim,
			reducedMotion = softMotion,
			clips = false,
		}, React.createElement(Text, {
			value = `TIER {tier.Tier}  •  {compactNumber(event.PersonalContribution)} / {compactNumber(tier.Required)}`,
			size = 11,
			color = if tier.CanClaim then Palette.mint else Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 8,
			sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 19),
		}), React.createElement(Text, {
			value = formatReward(tier.Reward),
			size = 10,
			color = Palette.muted,
			fit = true,
			minSize = 8,
			position = UDim2.fromOffset(0, 25),
			sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 18),
		}), React.createElement(Meter, {
			value = progress,
			color = if tier.CanClaim then Palette.mint else Palette.violet,
			position = if stack then UDim2.fromOffset(0, 54) else UDim2.new(0, 0, 1, -12),
			size = UDim2.new(1, if stack then 0 else -170, 0, 6),
			reducedMotion = softMotion,
			shimmer = tier.CanClaim and not softMotion,
		}), React.createElement("frame", {
			Name = "ConvergenceClaimActions",
			Size = if stack then UDim2.new(1, 0, 0, 48) else UDim2.fromOffset(150, 48),
			Position = if stack then UDim2.new(0, 0, 1, -48) else UDim2.new(1, -150, 0.5, -24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = if tier.Tier == firstClaimTier then claimHostRef else nil,
		}, React.createElement(Button, {
			text = if tier.Claimed then "CLAIMED" elseif tier.CanClaim then "CLAIM" else "LOCKED",
			icon = if tier.Claimed then "Check" else "Gift",
			onClick = function()
				if tier.CanClaim then
					dispatch("ClaimConvergenceReward", {
						Tier = tier.Tier,
					})
				end
			end,
			color = buttonColor,
			textColor = if tier.CanClaim then Palette.ink else Palette.creamSoft,
			disabled = not tier.CanClaim,
			size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
			highlight = tier.CanClaim and not softMotion,
		})))
	end
	for _k, _v in tiers do
		_newValue[_k] = _callback(_v, _k - 1, tiers)
	end
	-- ▲ ReadonlyArray.map ▲
	local sections = {
		{
			id = "hero",
			height = heroHeight,
			element = _exp_2,
		},
		{
			id = "tiers-label",
			height = SECTION_LABEL_H,
			element = React.createElement(SectionLabel, {
				value = "YOUR CONTRIBUTION REWARDS",
				color = Palette.violet,
			}),
		},
	}
	if tiersH > 0 then
		table.insert(sections, {
			id = "tiers",
			height = tiersH,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, pageGap),
			}), _newValue),
		})
	end
	return React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 80),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 4,
		sections = sections,
	})
end
return {
	ConvergenceView = ConvergenceView,
}
