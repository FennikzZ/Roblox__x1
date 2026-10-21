-- Builds a shop stall in the start area: a counter under a striped roof with the shop's name on
-- top, facing +Z. Walking up to the counter shows a prompt; pressing it opens the shop window on
-- the client (the prompt's "Shop" attribute says which shop, see Config.Shops).
local ShopBuilder = {}

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

-- `shop` is a Config.Shops key
function ShopBuilder.build(parent: Instance, shop: string, title: string, center: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = title
	model.Parent = parent

	local wood = Color3.fromRGB(120, 85, 55)
	block(model, "Floor", Vector3.new(22, 0.4, 14), center + Vector3.new(0, 0.2, 0), Color3.fromRGB(210, 195, 170), Enum.Material.WoodPlanks)
	local counter = block(model, "Counter", Vector3.new(16, 3.5, 3), center + Vector3.new(0, 2.15, 3), wood, Enum.Material.WoodPlanks)
	block(model, "CounterTop", Vector3.new(16.6, 0.4, 3.6), center + Vector3.new(0, 4.1, 3), color, Enum.Material.SmoothPlastic)
	block(model, "Back", Vector3.new(20, 9, 1), center + Vector3.new(0, 4.9, -6), wood, Enum.Material.WoodPlanks)
	for _, x in { -10, 10 } do
		block(model, "Post", Vector3.new(1, 10, 1), center + Vector3.new(x, 5.4, 6), wood, Enum.Material.WoodPlanks)
	end
	-- striped roof
	for i = 0, 5 do
		local stripe = if i % 2 == 0 then color else Color3.new(1, 1, 1)
		local roof = block(model, "Roof", Vector3.new(22 / 6, 0.6, 14), center + Vector3.new(-11 + 22 / 12 + i * 22 / 6, 10.6, 0), stripe)
		roof.CFrame *= CFrame.Angles(math.rad(-8), 0, 0)
	end

	-- name board on the roof
	local board = block(model, "Sign", Vector3.new(18, 4, 0.6), center + Vector3.new(0, 13.4, 6), color, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = string.upper(title)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Shop", shop)
	prompt.Parent = counter

	return model
end

return ShopBuilder
