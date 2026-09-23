--!strict
-- Pure PageRouter board row heights (machine / world / visit). No Roblox
-- services — PageRouter and Lune verify scripts share this so VirtualGrid
-- budgets stay testable without Studio.

local PageBoardHeights = {}

PageBoardHeights.MACHINE = 120
PageBoardHeights.MACHINE_STACK = 188
PageBoardHeights.WORLD = 148
PageBoardHeights.WORLD_STACK = 218
PageBoardHeights.VISIT = 268
PageBoardHeights.VISIT_STACK = 380

function PageBoardHeights.Machine(stack: boolean?): number
	return if stack then PageBoardHeights.MACHINE_STACK else PageBoardHeights.MACHINE
end

function PageBoardHeights.World(stack: boolean?): number
	return if stack then PageBoardHeights.WORLD_STACK else PageBoardHeights.WORLD
end

function PageBoardHeights.Visit(stack: boolean?): number
	return if stack then PageBoardHeights.VISIT_STACK else PageBoardHeights.VISIT
end

return table.freeze(PageBoardHeights)
