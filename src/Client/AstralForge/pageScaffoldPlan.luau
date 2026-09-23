--!strict
-- Pure PageScaffold fill planner for offline CI (no React / Roblox runtime).

local function planFillHeight(sections: { any }, availableHeight: number, gap: number?, tailPad: number?): number
	local resolvedGap = if gap == nil then 10 else gap
	local resolvedTail = if tailPad == nil then 8 else tailPad
	local fillSection = nil
	local fixedTotal = 0
	for _, section in sections do
		if section.fill == true then
			fillSection = section
		else
			local height = section.height
			if height == nil then
				height = 0
			end
			fixedTotal += height
		end
	end
	if fillSection == nil then
		return 0
	end
	local gapsTotal = resolvedGap * math.max(0, #sections - 1)
	local minHeight = fillSection.minHeight
	if minHeight == nil then
		minHeight = 120
	end
	-- Optional intrinsic `height` on a fill section is a content floor: VirtualGrid /
	-- hostRef lists need the section tall enough for every row, while still expanding
	-- into leftover viewport when the list is shorter than the pane.
	local contentFloor = fillSection.height
	if contentFloor == nil then
		contentFloor = 0
	end
	return math.max(minHeight, contentFloor, availableHeight - fixedTotal - gapsTotal - resolvedTail)
end

return {
	planFillHeight = planFillHeight,
}
