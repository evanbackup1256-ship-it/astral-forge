--!strict
-- Radial layout for the Domain tree. Pure (no services) so Lune can check it.
--
-- The Domain core sits at the centre. Each root node owns a sector of the circle; every node
-- belongs to the sector of its first prerequisite's root, sits on the ring for its depth (its
-- longest prerequisite chain) and is spread evenly inside its sector on that ring, ordered by
-- the angle of its parents so links cross as little as possible.

local Math = {} :: any

Math.CORE_RADIUS = 70 -- the empty middle where the core orb sits
Math.RING_GAP = 100 -- distance between depth rings
Math.READABLE_ZOOM = 0.85 -- the tree opens no smaller than this so labels stay legible; FIT shows it all
Math.SECTOR_FILL = 0.78 -- share of a sector the nodes on one ring may spread across

export type Node = { Id: string, Requires: { string }? }
export type Placement = { x: number, y: number, angle: number, depth: number, root: string }
export type Layout = { positions: { [string]: Placement }, rings: number, radius: number, sectors: { [string]: { from: number, to: number } } }

function Math.build(tree: { Node }): Layout
	local byId: { [string]: Node } = {}
	for _, node in tree do
		byId[node.Id] = node
	end
	local depth: { [string]: number } = {}
	local function depthOf(id: string, guard: { [string]: boolean }): number
		if depth[id] ~= nil then return depth[id] end
		if guard[id] then return 0 end
		guard[id] = true
		local d = 0
		for _, parent in (byId[id] and byId[id].Requires) or {} do
			if byId[parent] then d = math.max(d, depthOf(parent, guard) + 1) end
		end
		depth[id] = d
		return d
	end
	local rootOf: { [string]: string } = {}
	local function rootFor(id: string, guard: { [string]: boolean }): string
		if rootOf[id] then return rootOf[id] end
		if guard[id] then return id end
		guard[id] = true
		local first = nil
		for _, parent in (byId[id] and byId[id].Requires) or {} do
			if byId[parent] then first = parent break end
		end
		rootOf[id] = if first then rootFor(first, guard) else id
		return rootOf[id]
	end
	local roots = {}
	local maxDepth = 0
	for _, node in tree do
		local d = depthOf(node.Id, {})
		maxDepth = math.max(maxDepth, d)
		if rootFor(node.Id, {}) == node.Id then table.insert(roots, node.Id) end
	end
	local sectors = {}
	local width = 360 / math.max(1, #roots)
	for index, id in roots do
		sectors[id] = { from = (index - 1) * width, to = index * width }
	end
	local positions: { [string]: Placement } = {}
	for ring = 0, maxDepth do
		local groups: { [string]: { string } } = {}
		for _, node in tree do
			if depth[node.Id] == ring then
				local root = rootOf[node.Id]
				groups[root] = groups[root] or {}
				table.insert(groups[root], node.Id)
			end
		end
		for root, ids in groups do
			local sector = sectors[root]
			local mid = (sector.from + sector.to) / 2
			local function parentAngle(id: string): number
				local sum, count = 0, 0
				for _, parent in byId[id].Requires or {} do
					local placed = positions[parent]
					if placed then sum += placed.angle; count += 1 end
				end
				return if count > 0 then sum / count else mid
			end
			table.sort(ids, function(a, b)
				local pa, pb = parentAngle(a), parentAngle(b)
				if pa ~= pb then return pa < pb end
				return a < b
			end)
			local span = (sector.to - sector.from) * Math.SECTOR_FILL
			for index, id in ids do
				local angle = if #ids == 1 then mid else mid - span / 2 + (index - 1) * span / (#ids - 1)
				local radius = Math.CORE_RADIUS + (ring + 1) * Math.RING_GAP
				local radians = math.rad(angle - 90)
				positions[id] = { x = math.cos(radians) * radius, y = math.sin(radians) * radius, angle = angle, depth = ring, root = root }
			end
		end
	end
	return {
		positions = positions,
		rings = maxDepth + 1,
		radius = Math.CORE_RADIUS + (maxDepth + 1) * Math.RING_GAP,
		sectors = sectors,
	}
end

-- Smallest distance between any two placed nodes (layout checks keep orbs from overlapping).
function Math.minSpacing(layout: Layout): number
	local best = math.huge
	local list = {}
	for _, placed in layout.positions do table.insert(list, placed) end
	for i = 1, #list do
		for j = i + 1, #list do
			local dx, dy = list[i].x - list[j].x, list[i].y - list[j].y
			best = math.min(best, math.sqrt(dx * dx + dy * dy))
		end
	end
	return best
end

-- Zoom that fits the whole constellation (plus a margin for labels) in a view of the given size.
function Math.fitZoom(layout: Layout, viewW: number, viewH: number): number
	local diameter = (layout.radius + 70) * 2
	return math.clamp(math.min(viewW, viewH) / diameter, 0.35, 1.6)
end

return table.freeze(Math)
