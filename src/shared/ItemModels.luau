local Config = require(script.Parent.Config)

-- Models of the shop items, shared so the server (swords in hand, dummies at the bases) and the
-- client (pictures in the shop window) build the same thing. Every part is anchored; the caller
-- unanchors and welds when it needs physics.
local ItemModels = {}

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A sword around its Handle at `at`; the blade points along the Handle's +Y.
function ItemModels.sword(tier: number, at: CFrame?): Model
	local info = Config.Swords[tier]
	local base = at or CFrame.new()
	local model = Instance.new("Model")
	model.Name = info.name
	local handle = part(model, "Handle", Vector3.new(0.4, 1.3, 0.4), base, Color3.fromRGB(90, 60, 40), Enum.Material.WoodPlanks)
	part(model, "Guard", Vector3.new(1.6, 0.3, 0.5), base * CFrame.new(0, 0.75, 0), Color3.fromRGB(60, 50, 45), Enum.Material.Metal)
	local blade = part(model, "Blade", Vector3.new(0.25, 3.6, 0.7), base * CFrame.new(0, 2.7, 0), info.color, if tier == 1 then Enum.Material.WoodPlanks else Enum.Material.Metal)
	if tier >= 7 then
		blade.Material = Enum.Material.Neon -- the top swords glow
	end
	model.PrimaryPart = handle
	return model
end

-- A training dummy standing on `at` (its pivot is on the ground), facing -Z.
function ItemModels.dummy(tier: number, at: Vector3?): Model
	local info = Config.Dummies[tier]
	local base = at or Vector3.zero
	local model = Instance.new("Model")
	model.Name = info.name
	local dark = info.color:Lerp(Color3.new(0, 0, 0), 0.35)
	local material = if tier >= 7 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local post = part(model, "Post", Vector3.new(0.6, 2.4, 0.6), CFrame.new(base + Vector3.new(0, 1.2, 0)), dark, Enum.Material.WoodPlanks)
	part(model, "Body", Vector3.new(2.4, 2.6, 1.2), CFrame.new(base + Vector3.new(0, 3.7, 0)), info.color, material)
	part(model, "Arms", Vector3.new(4.4, 0.6, 0.6), CFrame.new(base + Vector3.new(0, 4.3, 0)), dark, Enum.Material.WoodPlanks)
	part(model, "Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(base + Vector3.new(0, 5.8, 0)), info.color, material)
	model.PrimaryPart = post
	model.WorldPivot = CFrame.new(base)
	return model
end

return ItemModels
