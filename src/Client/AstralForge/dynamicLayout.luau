--!strict
-- Dynamic layout motion.
-- Chrome and page sections share one spring and always ease. Nothing in this
-- path snaps or waits for a reduced-motion gate.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useFlipperSpring = require(script.Parent.motion).useFlipperSpring

local LAYOUT_STIFFNESS = 520
local LAYOUT_DAMPING = 46

local function useDynamicLayoutNumber(goal: number, _reducedMotion: boolean?): React.Binding<number>
	return useFlipperSpring(goal, false, LAYOUT_STIFFNESS, LAYOUT_DAMPING)
end

return {
	LAYOUT_STIFFNESS = LAYOUT_STIFFNESS,
	LAYOUT_DAMPING = LAYOUT_DAMPING,
	useDynamicLayoutNumber = useDynamicLayoutNumber,
}
