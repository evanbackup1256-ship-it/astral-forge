local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs

local chamber = require(StoryKit.client:WaitForChild("UiOverlays"))("DomainChamber")

return StoryKit.story({
	name = "Domain expansion",
	summary = "The rite (hold to expand) and the landing.",
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
	domain.Links = domain.Links or {}
	return React.createElement(chamber.DomainChamber, {
		key = `{controls.Mode}-{controls.Replay}`,
		mode = controls.Mode,
		domain = domain,
		rebirths = if controls.Ready then domain.RequiredRebirths else math.floor(domain.RequiredRebirths * 0.6),
		cores = if controls.Ready then domain.RequiredCores else math.floor(domain.RequiredCores * 0.3),
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
		dispatch = kit.dispatch,
		reducedMotion = kit.reducedMotion,
		onConfirm = function()
			print("[story] domain expansion confirmed")
		end,
		onMode = function(mode)
			print("[story] mode", mode)
		end,
		onClose = function()
			print("[story] domain overlay closed")
		end,
	})
end)
