local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs

local tree = require(StoryKit.client:WaitForChild("UiOverlays"))("DomainSkillTree")

return StoryKit.story({
	name = "Domain lattice",
	summary = "The Domain skill tree, built from GameConfig.Domain.Tree.",
	controls = {
		Points = UILabs.Slider(6, 0, 40, 1),
		Bound = UILabs.Slider(5, 0, 20, 1),
	},
}, function(controls, kit)
	local nodes = {}
	local count = 0
	for _, node in kit.config.Domain.Tree do
		if count >= controls.Bound then
			break
		end
		local ready = true
		for _, id in node.Requires or {} do
			if not nodes[id] then
				ready = false
			end
		end
		if ready then
			nodes[node.Id] = true
			count += 1
		end
	end
	return React.createElement(tree.DomainSkillTree, {
		domain = { Rank = 7, SkillPoints = controls.Points, Nodes = nodes },
		dispatch = kit.dispatch,
		reducedMotion = kit.reducedMotion,
		onClose = function()
			print("[story] lattice closed")
		end,
	})
end)
