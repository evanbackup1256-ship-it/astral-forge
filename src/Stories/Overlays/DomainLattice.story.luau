local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs

local chamber = require(StoryKit.client:WaitForChild("UiOverlays"))("DomainChamber")
local DomainLattice = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("DomainLattice"))

return StoryKit.story({
	name = "Domain lattice",
	summary = "The lattice: etch links out from the Hearth, close facets, read what it gives.",
	controls = {
		Points = UILabs.Slider(6, 0, 40, 1),
		Etched = UILabs.Slider(8, 0, 30, 1),
	},
}, function(controls, kit)
	-- grow a connected set of links out from the Hearth, in figure order
	local links = {}
	local count = 0
	local grew = true
	while grew and count < controls.Etched do
		grew = false
		local degree = DomainLattice.degrees(links)
		for _, e in DomainLattice.EDGES do
			if count >= controls.Etched then
				break
			end
			if not links[e.key] and (e.a == DomainLattice.HEARTH or (degree[e.a] or 0) > 0 or (degree[e.b] or 0) > 0) then
				links[e.key] = true
				count += 1
				grew = true
				break
			end
		end
	end
	return React.createElement(chamber.DomainChamber, {
		mode = "lattice",
		domain = { Rank = 7, SkillPoints = controls.Points, Links = links, ProductionMultiplier = 1 + 7 * 1.5, LatticeClearedAtRank = 0 },
		dispatch = kit.dispatch,
		reducedMotion = kit.reducedMotion,
		onConfirm = function() end,
		onMode = function(mode)
			print("[story] mode", mode)
		end,
		onClose = function()
			print("[story] lattice closed")
		end,
	})
end)
