--!strict
-- The shape of the sanctuary: a hub of floating stone around the forge altar,
-- four island regions reached by long sky bridges, waystones to travel between
-- them, ore outcrop sites and the Riftmaw arena.
--
--                    Starsteel Spire (N, high)
--                            |
--   Voidglass Hollows (W) -- Forge Heart -- Emberreach (E)
--                            |
--                    The Riftmaw (S, arena)
--
-- Pure data + math on plain {X, Y, Z} tables (no Vector3), relative to ORIGIN,
-- so the world builder (WorldService), the ore and boss services, the client
-- and the Lune tests (scripts/verify_sanctuary_world.luau) all read one map.

export type Point = { X: number, Y: number, Z: number }

export type Region = {
	Id: string,
	Name: string,
	Center: Point,
	-- Radius of the walkable plateau; its top surface is at Center.Y.
	Radius: number,
	-- Terrain materials for the plateau top and the rock beneath.
	Top: string,
	Under: string,
	-- Ore that grows here (nil for the hub and the arena).
	Ore: string?,
	OreSites: number,
}

export type Bridge = {
	Region: string,
	From: Point,
	To: Point,
	Control: Point,
	Width: number,
}

export type Waystone = { Id: string, Name: string, Region: string, Position: Point }
export type OreSite = { Id: string, Region: string, Ore: string, Position: Point }

local Layout = {}

Layout.ORIGIN = table.freeze({ X = 1680, Y = 248, Z = -220 })

-- The hub is the original hand-built forge deck. A terrain ring widens it; its
-- surface sits a little below the deck parts so they stand on top of it.
Layout.HUB_RADIUS = 62
Layout.HUB_TOP = -1.5
-- Everything walkable lies within this horizontal radius of the origin.
Layout.WORLD_RADIUS = 520
-- A character this far below the origin has fallen off the world.
Layout.KILL_DEPTH = 230

local REGIONS: { Region } = {
	{
		Id = "Heart",
		Name = "Forge Heart",
		Center = { X = 0, Y = -1.5, Z = 0 },
		Radius = 62,
		Top = "Slate",
		Under = "Basalt",
		Ore = nil,
		OreSites = 0,
	},
	{
		Id = "Emberreach",
		Name = "Emberreach",
		Center = { X = 312, Y = 10, Z = -72 },
		Radius = 112,
		Top = "Basalt",
		Under = "Rock",
		Ore = "Emberite",
		OreSites = 12,
	},
	{
		Id = "Hollows",
		Name = "Voidglass Hollows",
		Center = { X = -312, Y = -2, Z = -48 },
		Radius = 112,
		Top = "Glacier",
		Under = "Rock",
		Ore = "Voidglass",
		OreSites = 12,
	},
	{
		Id = "Spire",
		Name = "Starsteel Spire",
		Center = { X = 0, Y = 58, Z = -362 },
		Radius = 66,
		Top = "Limestone",
		Under = "Rock",
		Ore = "Starsteel",
		OreSites = 7,
	},
	{
		Id = "Riftmaw",
		Name = "The Riftmaw",
		Center = { X = 0, Y = -8, Z = 362 },
		Radius = 98,
		Top = "Asphalt",
		Under = "Rock",
		Ore = nil,
		OreSites = 0,
	},
}
for _, region in REGIONS do
	table.freeze(region.Center)
	table.freeze(region)
end
table.freeze(REGIONS)

local BY_ID: { [string]: Region } = {}
for _, region in REGIONS do
	BY_ID[region.Id] = region
end

local function point(x: number, y: number, z: number): Point
	return { X = x, Y = y, Z = z }
end

local function horizontal(a: Point, b: Point): number
	local dx, dz = b.X - a.X, b.Z - a.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Unit direction on the ground plane from a to b.
local function heading(a: Point, b: Point): (number, number)
	local length = horizontal(a, b)
	if length < 1e-6 then
		return 0, -1
	end
	return (b.X - a.X) / length, (b.Z - a.Z) / length
end

function Layout.regions(): { Region }
	return REGIONS
end

function Layout.region(id: string): Region?
	return BY_ID[id]
end

function Layout.distance(a: Point, b: Point): number
	return horizontal(a, b)
end

-- Where the bridge from the hub meets a region's plateau, and the direction it
-- arrives from (pointing from the region toward the hub).
function Layout.landing(region: Region): (Point, number, number)
	local hub = REGIONS[1].Center
	local dx, dz = heading(region.Center, hub)
	local rim = region.Radius - 4
	return point(region.Center.X + dx * rim, region.Center.Y, region.Center.Z + dz * rim), dx, dz
end

-- The sky bridges: one from the hub rim to each outer region, bowed gently to
-- one side so the walk reads as a path rather than a ruler line.
function Layout.bridges(): { Bridge }
	local hub = REGIONS[1]
	local result: { Bridge } = {}
	for index, region in REGIONS do
		if region.Id == hub.Id then
			continue
		end
		local dx, dz = heading(hub.Center, region.Center)
		local from = point(hub.Center.X + dx * (Layout.HUB_RADIUS - 6), Layout.HUB_TOP, hub.Center.Z + dz * (Layout.HUB_RADIUS - 6))
		local to = Layout.landing(region)
		local span = horizontal(from, to)
		local side = if index % 2 == 0 then 1 else -1
		-- Perpendicular on the ground plane.
		local px, pz = -dz, dx
		local control = point(
			(from.X + to.X) / 2 + px * span * 0.1 * side,
			(from.Y + to.Y) / 2,
			(from.Z + to.Z) / 2 + pz * span * 0.1 * side
		)
		table.insert(result, {
			Region = region.Id,
			From = from,
			To = to,
			Control = control,
			Width = if region.Id == "Riftmaw" then 16 else 12,
		})
	end
	return result
end

-- Points along a bridge's curve, roughly `spacing` studs apart, ends included.
function Layout.bridgePoints(bridge: Bridge, spacing: number): { Point }
	local span = horizontal(bridge.From, bridge.To) + math.abs(bridge.To.Y - bridge.From.Y)
	local steps = math.max(2, math.ceil(span / math.max(4, spacing)))
	local points: { Point } = {}
	for step = 0, steps do
		local t = step / steps
		local u = 1 - t
		table.insert(
			points,
			point(
				u * u * bridge.From.X + 2 * u * t * bridge.Control.X + t * t * bridge.To.X,
				u * u * bridge.From.Y + 2 * u * t * bridge.Control.Y + t * t * bridge.To.Y,
				u * u * bridge.From.Z + 2 * u * t * bridge.Control.Z + t * t * bridge.To.Z
			)
		)
	end
	return points
end

-- One waystone per region, just inside the bridge landing and off to its side
-- so it never blocks the path. The hub's stands beside the spawn causeway.
function Layout.waystones(): { Waystone }
	local result: { Waystone } = {
		{ Id = "Heart", Name = "Forge Heart", Region = "Heart", Position = point(24, Layout.HUB_TOP, 24) },
	}
	for _, region in REGIONS do
		if region.Id == "Heart" then
			continue
		end
		local landing, dx, dz = Layout.landing(region)
		local px, pz = -dz, dx
		table.insert(result, {
			Id = region.Id,
			Name = region.Name,
			Region = region.Id,
			Position = point(landing.X - dx * 20 + px * 16, region.Center.Y, landing.Z - dz * 20 + pz * 16),
		})
	end
	return result
end

-- Ore outcrops: an inner and an outer ring on each ore region's plateau, with
-- a clear corridor left where the bridge lands and around the waystone.
function Layout.oreSites(): { OreSite }
	local result: { OreSite } = {}
	for _, region in REGIONS do
		local ore = region.Ore
		if ore == nil or region.OreSites <= 0 then
			continue
		end
		local _, dx, dz = Layout.landing(region)
		local landingAngle = math.atan2(dz, dx)
		local inner = math.floor(region.OreSites * 0.4 + 0.5)
		local rings = {
			{ count = inner, radius = region.Radius * 0.42, offset = 0.35 },
			{ count = region.OreSites - inner, radius = region.Radius * 0.74, offset = 0 },
		}
		local index = 0
		for _, ring in rings do
			-- Spread the ring's sites over the arc that avoids the landing corridor.
			local clear = math.rad(34)
			local arc = 2 * math.pi - clear * 2
			for k = 1, ring.count do
				local angle = landingAngle + clear + arc * ((k - 1 + 0.5 + ring.offset * 0.5) / ring.count)
				index += 1
				table.insert(result, {
					Id = `{region.Id}-{index}`,
					Region = region.Id,
					Ore = ore,
					Position = point(
						region.Center.X + math.cos(angle) * ring.radius,
						region.Center.Y,
						region.Center.Z + math.sin(angle) * ring.radius
					),
				})
			end
		end
	end
	return result
end

-- The Riftmaw arena: where the Rift Warden hovers and where strikes count.
function Layout.arena(): { Center: Point, Radius: number, Hover: Point, PillarRadius: number }
	local maw = BY_ID.Riftmaw
	return {
		Center = maw.Center,
		Radius = maw.Radius - 10,
		Hover = point(maw.Center.X, maw.Center.Y + 26, maw.Center.Z),
		PillarRadius = maw.Radius - 12,
	}
end

-- The region a point stands in, or nil out on a bridge.
function Layout.regionAt(p: Point): Region?
	for _, region in REGIONS do
		if horizontal(p, region.Center) <= region.Radius + 6 then
			return region
		end
	end
	return nil
end

function Layout.nearestWaystone(p: Point): Waystone
	local best: Waystone? = nil
	local bestDistance = math.huge
	for _, stone in Layout.waystones() do
		local d = horizontal(p, stone.Position)
		if d < bestDistance then
			best, bestDistance = stone, d
		end
	end
	return best :: Waystone
end

function Layout.waystone(id: string): Waystone?
	for _, stone in Layout.waystones() do
		if stone.Id == id then
			return stone
		end
	end
	return nil
end

-- Inside the walkable world (and not fallen through it)?
function Layout.inBounds(p: Point): boolean
	return horizontal(p, point(0, 0, 0)) <= Layout.WORLD_RADIUS and p.Y > -Layout.KILL_DEPTH
end

return Layout
