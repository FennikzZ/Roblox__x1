-- A simple four-legged animal made of blocks, used for the zone guardians and the hatched animals.
-- The model's pivot is on the ground under its body and it looks along -Z (like CFrame.lookAt),
-- so `model:PivotTo(CFrame.lookAt(pos, pos + direction))` stands it on `pos` facing `direction`.
local BlockAnimal = {}

-- size and center of every part for scale 1
local PARTS = {
	{ "Body", Vector3.new(2.6, 2, 4), Vector3.new(0, 2.2, 0), "main" },
	{ "Head", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 3.2, -2.6), "main" },
	{ "Eye", Vector3.new(0.4, 0.5, 0.1), Vector3.new(-0.5, 3.5, -3.72), "eye" },
	{ "Eye", Vector3.new(0.4, 0.5, 0.1), Vector3.new(0.5, 3.5, -3.72), "eye" },
	{ "Nose", Vector3.new(0.8, 0.6, 0.4), Vector3.new(0, 2.9, -3.85), "accent" },
	{ "Ear", Vector3.new(0.5, 0.7, 0.4), Vector3.new(-0.7, 4.6, -2.4), "accent" },
	{ "Ear", Vector3.new(0.5, 0.7, 0.4), Vector3.new(0.7, 4.6, -2.4), "accent" },
	{ "Leg", Vector3.new(0.8, 1.2, 0.8), Vector3.new(-0.85, 0.6, -1.4), "accent" },
	{ "Leg", Vector3.new(0.8, 1.2, 0.8), Vector3.new(0.85, 0.6, -1.4), "accent" },
	{ "Leg", Vector3.new(0.8, 1.2, 0.8), Vector3.new(-0.85, 0.6, 1.4), "accent" },
	{ "Leg", Vector3.new(0.8, 1.2, 0.8), Vector3.new(0.85, 0.6, 1.4), "accent" },
	{ "Tail", Vector3.new(0.4, 0.4, 1.2), Vector3.new(0, 2.8, 2.4), "accent" },
}
BlockAnimal.HEIGHT = 5 -- top of the ears at scale 1

function BlockAnimal.build(name: string, color: Color3, scale: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local accent = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, info in PARTS do
		local p = Instance.new("Part")
		p.Name = info[1]
		p.Size = info[2] * scale
		p.CFrame = CFrame.new(info[3] * scale)
		p.Color = if info[4] == "eye" then Color3.new(0.05, 0.05, 0.05) elseif info[4] == "accent" then accent else color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	model.WorldPivot = CFrame.new()
	return model
end

-- name tag floating above the animal; returns the label so its text can change
function BlockAnimal.label(model: Model, text: string, color: Color3, scale: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(160, 44)
	-- the offset is from the body's center, which is 2.2 studs up at scale 1
	gui.StudsOffsetWorldSpace = Vector3.new(0, (BlockAnimal.HEIGHT - 2.2) * scale + 1.5, 0)
	gui.Adornee = model.PrimaryPart
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	return label
end

return BlockAnimal
