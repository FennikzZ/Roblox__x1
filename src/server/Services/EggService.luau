local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

-- Eggs lying on the path: spawning, hitting them until they crack, and carrying the cracked egg.
-- A player carries at most one egg. While carrying they have the attributes
--   CarryingZone  the zone the egg is from (0 when not carrying)
--   EggSecured    true once they got back over the safe line (the guardians stop chasing)
local EggService = {}

export type Carry = { zone: number, part: BasePart, secured: boolean }

local NotifyFn = nil :: (Player, string, string?) -> ()
local carrying: { [Player]: Carry } = {}
local eggCount: { [number]: number } = {}
local restingCFrame: { [BasePart]: CFrame } = {}
local shakes: { [BasePart]: Tween } = {}
local bars: { [BasePart]: { fill: Frame, label: TextLabel } } = {} -- hp bar of every egg on the path
local savedC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local rng = Random.new()
local eggsFolder: Folder

-- where the egg sits, relative to the HumanoidRootPart: in front of the chest, between the hands
local HOLD_OFFSET = CFrame.new(0, 0.9, -2.4)
local ARM_JOINTS = { "RightShoulder", "LeftShoulder", "Right Shoulder", "Left Shoulder" } -- R15 and R6
local SHAKE = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

-- The carry pose: both arms stretched forward. Works on R15 and R6 by turning each shoulder joint
-- around the torso's X axis.
local function setHoldPose(character: Model, on: boolean)
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and table.find(ARM_JOINTS, joint.Name) then
			if on then
				savedC0[joint] = savedC0[joint] or joint.C0
				local c0 = savedC0[joint]
				joint.C0 = CFrame.new(c0.Position) * CFrame.Angles(math.rad(85), 0, 0) * c0.Rotation
			elseif savedC0[joint] then
				joint.C0 = savedC0[joint]
				savedC0[joint] = nil
			end
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function hpBar(egg: BasePart): (Frame, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Hp"
	gui.Size = UDim2.fromOffset(110, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, egg.Size.Y / 2 + 1.2, 0)
	gui.MaxDistance = 60
	gui.Parent = egg
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.Parent = gui
	Instance.new("UICorner").Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 220, 90)
	fill.Parent = back
	Instance.new("UICorner").Parent = fill
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.ZIndex = 2
	label.Parent = back
	return fill, label
end

-- clears the carry state and the pose; the caller decides what happens to the egg part
local function release(player: Player): Carry?
	local carry = carrying[player]
	if not carry then
		return nil
	end
	carrying[player] = nil
	if player.Character then
		setHoldPose(player.Character, false)
	end
	player:SetAttribute("CarryingZone", 0)
	player:SetAttribute("EggSecured", false)
	return carry
end

local function pickUp(player: Player, egg: BasePart)
	local root = rootOf(player)
	if not root then
		return
	end
	local zone = egg:GetAttribute("Zone") :: number
	eggCount[zone] -= 1
	restingCFrame[egg] = nil
	if shakes[egg] then
		-- a running shake would keep moving the egg, and with it the player once it is welded
		shakes[egg]:Cancel()
		shakes[egg] = nil
	end
	for _, child in egg:GetChildren() do
		if not child:IsA("SpecialMesh") then
			child:Destroy() -- the hp bar
		end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end

	egg.Anchored = false
	egg.CanCollide = false
	egg.CanQuery = false
	egg.Massless = true
	egg.CFrame = root.CFrame * HOLD_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = egg
	weld.Parent = egg
	egg.Parent = player.Character
	setHoldPose(player.Character :: Model, true)

	carrying[player] = { zone = zone, part = egg, secured = false }
	player:SetAttribute("CarryingZone", zone)
	player:SetAttribute("EggSecured", false)
	local guardian = Config.Zones[zone].guardian.name
	NotifyFn(player, `You cracked a {Config.Zones[zone].name} egg! Run back to the start before the {guardian}s catch you!`, "danger")
end

local function hit(player: Player, egg: BasePart)
	local maxHp = egg:GetAttribute("MaxHp") :: number
	local hp = (egg:GetAttribute("Hp") :: number) - Config.playerDamage(player)
	if hp <= 0 then
		bars[egg] = nil
		pickUp(player, egg)
		return
	end
	egg:SetAttribute("Hp", hp)
	local bar = bars[egg]
	bar.fill.Size = UDim2.fromScale(hp / maxHp, 1)
	bar.label.Text = `{Config.format(hp)} / {Config.format(maxHp)}`

	local rest = restingCFrame[egg]
	if rest then
		egg.CFrame = rest
		local tilt = if rng:NextNumber() < 0.5 then -12 else 12
		if shakes[egg] then
			shakes[egg]:Cancel()
		end
		shakes[egg] = TweenService:Create(egg, SHAKE, { CFrame = rest * CFrame.Angles(0, 0, math.rad(tilt)) })
		shakes[egg]:Play()
	end
end

local function spawnEgg(zoneIndex: number)
	local zone = Config.Zones[zoneIndex]
	local scale = 1 + 0.12 * (zoneIndex - 1)
	local egg = Instance.new("Part")
	egg.Name = `Egg{zoneIndex}`
	egg.Size = Vector3.new(2.4, 3, 2.4) * scale
	egg.Color = zone.egg
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- a Sphere mesh follows the part's size: an egg shape
	mesh.Parent = egg
	local pos = Layout.randomPointInZone(zoneIndex, rng, 4)
	egg.CFrame = CFrame.new(pos + Vector3.new(0, egg.Size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	restingCFrame[egg] = egg.CFrame
	egg:SetAttribute("Zone", zoneIndex)
	egg:SetAttribute("Hp", zone.eggHp)
	egg:SetAttribute("MaxHp", zone.eggHp)

	local fill, label = hpBar(egg)
	label.Text = `{Config.format(zone.eggHp)} / {Config.format(zone.eggHp)}`
	bars[egg] = { fill = fill, label = label }

	egg.Parent = eggsFolder
	eggCount[zoneIndex] += 1
end

-- A sword swing (see SwordService): hits the closest egg within reach. Returns false when there is
-- none, so the swing can go to something else.
function EggService.tryHit(player: Player, root: BasePart): boolean
	local best, bestDist = nil, math.huge
	for _, egg in eggsFolder:GetChildren() do
		if egg:IsA("BasePart") then
			local offset = egg.Position - root.Position
			local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude - egg.Size.X / 2
			if dist <= Config.HIT_RANGE and dist < bestDist then
				best, bestDist = egg, dist
			end
		end
	end
	if not best then
		return false
	end
	if carrying[player] then
		NotifyFn(player, "Your hands are full! Bring your egg back first.")
	else
		hit(player, best)
	end
	return true
end

-- the player's carried egg, if any
function EggService.carryOf(player: Player): Carry?
	return carrying[player]
end

function EggService.carriers(): { [Player]: Carry }
	return carrying
end

-- the egg is lost (caught, died, left)
function EggService.drop(player: Player)
	local carry = release(player)
	if carry then
		carry.part:Destroy()
	end
end

-- the egg goes into an incubator: returns its zone
function EggService.take(player: Player): number?
	local carry = release(player)
	if not carry then
		return nil
	end
	carry.part:Destroy()
	return carry.zone
end

function EggService.start(notify: (Player, string, string?) -> ())
	NotifyFn = notify
	eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "Eggs"
	eggsFolder.Parent = workspace

	for i in Config.Zones do
		eggCount[i] = 0
		for _ = 1, Config.EGGS_PER_ZONE do
			spawnEgg(i)
		end
	end
	task.spawn(function()
		while true do
			task.wait(Config.EGG_RESPAWN_SECONDS)
			for i in Config.Zones do
				if eggCount[i] < Config.EGGS_PER_ZONE then
					spawnEgg(i)
				end
			end
		end
	end)

	-- back over the safe line with an egg: it is yours, the guardians give up
	RunService.Heartbeat:Connect(function()
		for player, carry in carrying do
			local root = rootOf(player)
			if not carry.secured and root and root.Position.Z < Layout.SAFE_Z then
				carry.secured = true
				player:SetAttribute("EggSecured", true)
				notify(player, "Safe! Take the egg to an incubator at your base.", "good")
			end
		end
	end)

	local function onPlayer(player: Player)
		player:SetAttribute("CarryingZone", 0)
		player:SetAttribute("EggSecured", false)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				EggService.drop(player)
			end)
			-- both hands hold the egg: no sword while carrying
			character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and carrying[player] then
					task.defer(humanoid.UnequipTools, humanoid)
				end
			end)
		end)
		player.CharacterRemoving:Connect(function()
			EggService.drop(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		EggService.drop(player)
	end)
end

return EggService
