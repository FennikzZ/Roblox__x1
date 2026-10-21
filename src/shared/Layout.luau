local Config = require(script.Parent.Config)

-- Where everything is on the map. Shared so the client can tell which zone the player is in.
--
--   z < 0      the start area: spawn and the player bases (safe, guardians never come here)
--   z >= 0     the long path going +Z, cut into Config.Zones, each ZONE_LENGTH long
local Layout = {}

Layout.PATH_WIDTH = 40
Layout.ZONE_LENGTH = 150
Layout.SAFE_Z = 0 -- the line between the start area and zone 1

Layout.START_HALF_WIDTH = 100 -- the start area goes from x = -100 to 100
Layout.START_DEPTH = 115 -- and from z = -115 to SAFE_Z
Layout.SPAWN = Vector3.new(0, 0, -25)

Layout.PLOT_SIZE = Vector3.new(26, 1, 36)
local PLOT_XS = { -75, -45, -15, 15, 45, 75 }
local PLOT_Z = -84
Layout.PLOT_COUNT = #PLOT_XS

-- the two shop stalls between the bases and the path (swords left, dummies right), facing +Z
Layout.SWORD_SHOP = Vector3.new(-60, 0, -36)
Layout.DUMMY_SHOP = Vector3.new(60, 0, -36)

-- every base's training dummy, relative to the plot's center: the front left corner
Layout.PLOT_DUMMY = Vector3.new(-10, 0, 13)

-- center of the plot's floor (y = 0 is the ground)
function Layout.plotCenter(index: number): Vector3
	return Vector3.new(PLOT_XS[index], 0, PLOT_Z)
end

function Layout.zoneStart(index: number): number
	return Layout.SAFE_Z + (index - 1) * Layout.ZONE_LENGTH
end

function Layout.zoneEnd(index: number): number
	return Layout.zoneStart(index) + Layout.ZONE_LENGTH
end

function Layout.pathEnd(): number
	return Layout.zoneEnd(#Config.Zones)
end

-- 0 in the start area, otherwise the zone number
function Layout.zoneAt(z: number): number
	if z < Layout.SAFE_Z then
		return 0
	end
	return math.clamp(math.floor((z - Layout.SAFE_Z) / Layout.ZONE_LENGTH) + 1, 1, #Config.Zones)
end

-- a random spot on the ground of a zone, at least `margin` studs from its edges
function Layout.randomPointInZone(index: number, rng: Random, margin: number): Vector3
	local halfX = Layout.PATH_WIDTH / 2 - margin
	return Vector3.new(
		rng:NextNumber(-halfX, halfX),
		0,
		rng:NextNumber(Layout.zoneStart(index) + margin, Layout.zoneEnd(index) - margin)
	)
end

return Layout
