local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

-- Builds the start area and the long path with its zones (see Layout for the coordinates).
local PathBuilder = {}

local WALL_HEIGHT = 6
local GATE_HEIGHT = 14

local function block(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- big text on one face of a part
local function sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
end

local function buildStartArea(map: Folder)
	local half = Layout.START_HALF_WIDTH
	local depth = Layout.START_DEPTH
	local z0 = Layout.SAFE_Z
	block(map, "StartFloor", Vector3.new(half * 2, 2, depth), Vector3.new(0, -1, z0 - depth / 2), Color3.fromRGB(105, 170, 85), Enum.Material.Grass)

	-- fence around the start area, open where the path begins
	local fence = Color3.fromRGB(150, 110, 70)
	local h = 4
	block(map, "Fence", Vector3.new(half * 2, h, 2), Vector3.new(0, h / 2, z0 - depth), fence, Enum.Material.WoodPlanks)
	block(map, "Fence", Vector3.new(2, h, depth), Vector3.new(-half, h / 2, z0 - depth / 2), fence, Enum.Material.WoodPlanks)
	block(map, "Fence", Vector3.new(2, h, depth), Vector3.new(half, h / 2, z0 - depth / 2), fence, Enum.Material.WoodPlanks)
	local gap = Layout.PATH_WIDTH / 2 + 2
	local side = half - gap
	block(map, "Fence", Vector3.new(side, h, 2), Vector3.new(-(gap + side / 2), h / 2, z0), fence, Enum.Material.WoodPlanks)
	block(map, "Fence", Vector3.new(side, h, 2), Vector3.new(gap + side / 2, h / 2, z0), fence, Enum.Material.WoodPlanks)

	-- the safe line: get back behind it with an egg and the guardians give up
	local line = block(map, "SafeLine", Vector3.new(Layout.PATH_WIDTH, 0.2, 1.5), Vector3.new(0, 0.1, z0 - 0.75), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	line.CanCollide = false

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Layout.SPAWN + Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = map
end

local function buildZone(map: Folder, index: number)
	local zone = Config.Zones[index]
	local folder = Instance.new("Folder")
	folder.Name = `Zone{index}`
	folder.Parent = map

	local len = Layout.ZONE_LENGTH
	local width = Layout.PATH_WIDTH
	local midZ = Layout.zoneStart(index) + len / 2
	block(folder, "Floor", Vector3.new(width, 2, len), Vector3.new(0, -1, midZ), zone.floor, zone.floorMaterial)
	for _, x in { -(width / 2 + 1), width / 2 + 1 } do
		block(folder, "Wall", Vector3.new(2, WALL_HEIGHT, len), Vector3.new(x, WALL_HEIGHT / 2, midZ), zone.wall, zone.wallMaterial)
	end

	-- gate at the start of the zone with its name on both sides
	local z = Layout.zoneStart(index)
	for _, x in { -(width / 2 + 1.5), width / 2 + 1.5 } do
		block(folder, "Pillar", Vector3.new(3, GATE_HEIGHT, 3), Vector3.new(x, GATE_HEIGHT / 2, z), zone.wall, zone.wallMaterial)
	end
	local beam = block(folder, "GateSign", Vector3.new(width + 6, 4, 2), Vector3.new(0, GATE_HEIGHT + 2, z), zone.wall, zone.wallMaterial)
	local text = `ZONE {index} · {string.upper(zone.name)}`
	sign(beam, Enum.NormalId.Front, text, zone.egg)
	sign(beam, Enum.NormalId.Back, if index == 1 then "START" else `ZONE {index - 1} · {string.upper(Config.Zones[index - 1].name)}`, Color3.new(1, 1, 1))
end

function PathBuilder.build(parent: Instance): Folder
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = parent

	buildStartArea(map)
	for i in Config.Zones do
		buildZone(map, i)
	end
	local last = Config.Zones[#Config.Zones]
	block(map, "EndWall", Vector3.new(Layout.PATH_WIDTH + 4, WALL_HEIGHT * 2, 2), Vector3.new(0, WALL_HEIGHT, Layout.pathEnd() + 1), last.wall, last.wallMaterial)
	return map
end

return PathBuilder
