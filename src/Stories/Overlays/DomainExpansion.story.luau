local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs

local overlay = require(StoryKit.client:WaitForChild("UiOverlays"))("DomainExpansionOverlay")

return StoryKit.story({
	name = "Domain expansion",
	summary = "The confirm screen (hold to expand) and the result cinematic.",
	controls = {
		Mode = UILabs.Choose({ "confirm", "result" }, 1),
		Ready = true,
		Replay = 0,
	},
}, function(controls, kit)
	local domain = table.clone(kit.state.Domain or {})
	domain.Rank = domain.Rank or 4
	domain.CanExpand = controls.Ready
	domain.RequiredRebirths = domain.RequiredRebirths or 20
	domain.RequiredCores = domain.RequiredCores or 500
	domain.EssenceReward = domain.EssenceReward or 24
	domain.StardustReward = domain.StardustReward or 1120
	return React.createElement(overlay.DomainExpansionOverlay, {
		key = `{controls.Mode}-{controls.Replay}`,
		mode = controls.Mode,
		domain = domain,
		currentRebirths = if controls.Ready then domain.RequiredRebirths else math.floor(domain.RequiredRebirths * 0.6),
		currentCores = if controls.Ready then domain.RequiredCores else math.floor(domain.RequiredCores * 0.3),
		result = if controls.Mode == "result" then {
			rank = domain.Rank + 1,
			essence = domain.EssenceReward,
			stardust = domain.StardustReward,
			overflow = 0,
			freeSpins = 3,
			nextRebirths = domain.RequiredRebirths * 2,
			nextCores = domain.RequiredCores * 3,
		} else nil,
		busy = false,
		reducedMotion = kit.reducedMotion,
		onConfirm = function()
			print("[story] domain expansion confirmed")
		end,
		onClose = function()
			print("[story] domain overlay closed")
		end,
	})
end)
