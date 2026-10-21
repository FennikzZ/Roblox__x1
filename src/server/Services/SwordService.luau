local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)

-- Swords: every player carries their equipped sword (attribute SwordTier, an index into
-- Config.Swords; bought and equipped in the sword shop, see ShopService). Clicking with it swings:
-- the swing hits the closest egg (EggService) or training dummy (TrainingService) in reach.
local SwordService = {}

local lastSwing: { [Player]: number } = {}
local EggService, TrainingService

local function buildSword(tier: number): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Swords[tier].name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.4, 0) -- hold it near the bottom of the handle
	tool.ToolTip = `{Config.format(Config.Swords[tier].damage)} damage`
	tool:SetAttribute("Sword", true)

	local model = ItemModels.sword(tier)
	local handle = model.PrimaryPart :: BasePart
	for _, p in model:GetChildren() do
		local bp = p :: BasePart
		bp.Anchored = false
		bp.Massless = true
		bp.CanQuery = false
		if bp ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = bp
			weld.Parent = bp
		end
		bp.Parent = tool
	end
	model:Destroy()
	return tool
end

local function swing(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Config.SWING_COOLDOWN then
		return
	end
	lastSwing[player] = now

	-- the default Animate script plays its slash animation when a "toolanim" value appears
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and not EggService.tryHit(player, root) then
		TrainingService.tryHit(player, root)
	end
end

-- puts the player's equipped sword in their backpack, replacing the old one
function SwordService.give(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local character = player.Character
	local wasEquipped = false
	for _, holder in { backpack, character } do
		if holder then
			for _, tool in holder:GetChildren() do
				if tool:IsA("Tool") and tool:GetAttribute("Sword") then
					wasEquipped = wasEquipped or holder == character
					tool:Destroy()
				end
			end
		end
	end

	local tool = buildSword(player:GetAttribute("SwordTier") or 1)
	tool.Activated:Connect(function()
		swing(player, tool)
	end)
	tool.Parent = backpack
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if wasEquipped and humanoid then
		humanoid:EquipTool(tool)
	end
end

function SwordService.start(eggService, trainingService)
	EggService, TrainingService = eggService, trainingService

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- a respawn makes a new Backpack; wait a moment so it is the new one
			task.defer(function()
				player:WaitForChild("Backpack")
				SwordService.give(player)
			end)
		end)
		if player.Character then
			SwordService.give(player)
		end
		player:GetAttributeChangedSignal("SwordTier"):Connect(function()
			SwordService.give(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return SwordService
