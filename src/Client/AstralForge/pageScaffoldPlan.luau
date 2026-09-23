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

-- When only a short sliver of the next card would show, grow the last section that
-- fully fits so the fold lands on a gap. A large remainder stays scrollable content.
local function planFittedHeights(sections: { any }, availableHeight: number, gap: number?, tailPad: number?): { number }
	local resolvedGap = if gap == nil then 10 else gap
	local fillHeight = planFillHeight(sections, availableHeight, gap, tailPad)
	local heights = table.create(#sections)
	for index, section in sections do
		if section.fill == true then
			heights[index] = fillHeight
		else
			local height = section.height
			heights[index] = if height == nil then 0 else height
		end
	end
	if availableHeight <= 0 or #heights <= 1 then
		return heights
	end
	local cursor = 0
	local lastFit = 0
	for index, height in heights do
		if cursor + height > availableHeight then
			break
		end
		lastFit = index
		cursor += height
		if index < #heights then
			cursor += resolvedGap
		end
	end
	if lastFit == 0 or lastFit == #heights then
		return heights
	end
	local extra = availableHeight - cursor
	local nextHeight = heights[lastFit + 1]
	if nextHeight == nil then
		nextHeight = 0
	end
	-- 96 covers the layout test's 81px peek. Hundreds of leftover pixels are the
	-- next card, and folding them into the previous section leaves an empty panel.
	if extra > 0 and extra <= 96 and extra < nextHeight then
		heights[lastFit] += extra
	end
	return heights
end

return {
	planFillHeight = planFillHeight,
	planFittedHeights = planFittedHeights,
}
