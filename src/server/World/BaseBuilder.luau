local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

-- Builds one player base (plot) in the start area: a floor, incubators at the front, pads for the
-- hatched animals. The front of a plot faces +Z, towards the path.
local BaseBuilder = {}

export type Plot = {
	model: Model,
	center: Vector3,
	sign: TextLabel,
	edges: { BasePart },
	incubators: { { pad: BasePart, label: TextLabel } },
	slots: { Vector3 }, -- where hatched animals stand
}

local FREE_COLOR = Color3.fromRGB(160, 160, 160)

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

local function text(parent: Instance, textColor: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

local function surfaceText(part: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = part
	return text(gui, Color3.new(1, 1, 1))
end

local function billboard(part: BasePart, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 80
	gui.Parent = part
	return text(gui, Color3.fromRGB(255, 230, 150))
end

function BaseBuilder.build(parent: Instance, index: number): Plot
	local center = Layout.plotCenter(index)
	local size = Layout.PLOT_SIZE
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model.Parent = parent

	block(model, "Floor", Vector3.new(size.X, 0.4, size.Z), center + Vector3.new(0, 0.2, 0), Color3.fromRGB(230, 220, 195), Enum.Material.WoodPlanks)

	-- colored edges: gray while free, the owner's color when claimed
	local edges = {}
	for _, info in {
		{ Vector3.new(size.X, 0.6, 1), Vector3.new(0, 0.3, size.Z / 2) },
		{ Vector3.new(size.X, 0.6, 1), Vector3.new(0, 0.3, -size.Z / 2) },
		{ Vector3.new(1, 0.6, size.Z), Vector3.new(size.X / 2, 0.3, 0) },
		{ Vector3.new(1, 0.6, size.Z), Vector3.new(-size.X / 2, 0.3, 0) },
	} do
		table.insert(edges, block(model, "Edge", info[1], center + info[2], FREE_COLOR, Enum.Material.Neon))
	end

	-- name board at the back, readable from the front
	local board = block(model, "Sign", Vector3.new(16, 4, 1), center + Vector3.new(0, 6, -size.Z / 2 + 1), Color3.fromRGB(90, 65, 45), Enum.Material.WoodPlanks)
	for _, x in { -7, 7 } do
		block(model, "SignPost", Vector3.new(1, 4, 1), center + Vector3.new(x, 2, -size.Z / 2 + 1), Color3.fromRGB(90, 65, 45), Enum.Material.WoodPlanks)
	end
	local sign = surfaceText(board, Enum.NormalId.Back)
	sign.Text = "Free base"

	-- incubators at the front: walk onto one while holding an egg
	local incubators = {}
	for i = 1, Config.INCUBATORS do
		local x = (i - (Config.INCUBATORS + 1) / 2) * 9
		local pad = Instance.new("Part")
		pad.Name = "Incubator"
		pad.Shape = Enum.PartType.Cylinder
		pad.Anchored = true
		pad.Size = Vector3.new(0.8, 6, 6)
		pad.CFrame = CFrame.new(center + Vector3.new(x, 0.6, size.Z / 2 - 6)) * CFrame.Angles(0, 0, math.rad(90))
		pad.Color = Color3.fromRGB(255, 200, 90)
		pad.Material = Enum.Material.Neon
		pad.Parent = model
		local label = billboard(pad, 5)
		label.Text = "Incubator\nbring an egg"
		table.insert(incubators, { pad = pad, label = label })
	end

	-- pads for the hatched animals: 4 columns, 3 rows behind the incubators
	local slots = {}
	for row = 0, 2 do
		for col = 0, 3 do
			local pos = center + Vector3.new(-9 + col * 6, 0, 3 - row * 7)
			block(model, "AnimalPad", Vector3.new(4.5, 0.2, 4.5), pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 185, 150))
			table.insert(slots, pos + Vector3.new(0, 0.6, 0))
		end
	end
	assert(#slots >= Config.BASE_SLOTS, "BaseBuilder: fewer animal pads than Config.BASE_SLOTS")

	return {
		model = model,
		center = center,
		sign = sign,
		edges = edges,
		incubators = incubators,
		slots = slots,
	}
end

function BaseBuilder.setOwner(plot: Plot, owner: Player?)
	plot.sign.Text = if owner then `{owner.DisplayName}'s base` else "Free base"
	local color = if owner then Color3.fromHSV((owner.UserId % 360) / 360, 0.6, 1) else FREE_COLOR
	for _, edge in plot.edges do
		edge.Color = color
	end
end

return BaseBuilder
