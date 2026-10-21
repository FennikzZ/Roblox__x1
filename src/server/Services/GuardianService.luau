local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local BlockAnimal = require(script.Parent.Parent.World.BlockAnimal)

-- The animals guarding each zone. They wander around their zone; when someone cracks one of the
-- zone's eggs they all chase that player, until the player is back over the safe line (then they
-- walk home) or one of them catches the player (the egg is lost).
-- A chased player gets the attribute ChasedBy (the guardian's name, "" when nobody chases them).
local GuardianService = {}

type Guardian = {
	model: Model,
	zone: number,
	pos: Vector3,
	facing: Vector3,
	state: "idle" | "chase" | "return",
	goal: Vector3,
	waitUntil: number,
	eyes: { BasePart },
	tag: TextLabel,
}

local IDLE_SPEED = 0.35 -- share of the full speed while wandering
local RETURN_SPEED = 0.7 -- share of the full speed while walking home
local EYE_CALM = Color3.new(0.05, 0.05, 0.05)
local EYE_ANGRY = Color3.fromRGB(255, 40, 40)

local guardians: { Guardian } = {}
local rng = Random.new()

local function newGoal(g: Guardian)
	g.goal = Layout.randomPointInZone(g.zone, rng, 3)
end

-- moves g towards goal on the ground; true once it is there
local function moveToward(g: Guardian, goal: Vector3, speed: number, dt: number): boolean
	local delta = Vector3.new(goal.X - g.pos.X, 0, goal.Z - g.pos.Z)
	local dist = delta.Magnitude
	if dist < 0.5 then
		return true
	end
	local dir = delta / dist
	g.pos += dir * math.min(dist, speed * dt)
	g.facing = dir
	return dist <= speed * dt + 0.5
end

local function setAngry(g: Guardian, angry: boolean)
	for _, eye in g.eyes do
		eye.Color = if angry then EYE_ANGRY else EYE_CALM
		eye.Material = if angry then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	local name = Config.Zones[g.zone].guardian.name
	g.tag.Text = if angry then `{name} !` else name
	g.tag.TextColor3 = if angry then EYE_ANGRY else Color3.new(1, 1, 1)
end

-- the closest player carrying an unsecured egg of this guardian's zone
local function findTarget(g: Guardian, carriers): (Player?, BasePart?)
	local best, bestRoot, bestDist = nil, nil, math.huge
	for player, carry in carriers do
		if carry.zone == g.zone and not carry.secured then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Z >= Layout.SAFE_Z then
				local dist = (root.Position - g.pos).Magnitude
				if dist < bestDist then
					best, bestRoot, bestDist = player, root, dist
				end
			end
		end
	end
	return best, bestRoot
end

local function catch(player: Player, g: Guardian, EggService, notify)
	EggService.drop(player)
	local name = Config.Zones[g.zone].guardian.name
	notify(player, `The {name} caught you and took the egg back!`, "danger")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		task.delay(Config.CAUGHT_STUN_SECONDS, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = Config.playerSpeed(player)
			end
		end)
	end
end

function GuardianService.start(EggService, notify: (Player, string, string?) -> ())
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace

	for zoneIndex, zone in Config.Zones do
		local info = zone.guardian
		for _ = 1, info.count do
			local model = BlockAnimal.build(info.name, info.color, info.scale)
			local eyes = {}
			for _, p in model:GetChildren() do
				if p.Name == "Eye" then
					table.insert(eyes, p :: BasePart)
				end
			end
			local g: Guardian = {
				model = model,
				zone = zoneIndex,
				pos = Layout.randomPointInZone(zoneIndex, rng, 3),
				facing = Vector3.new(0, 0, -1),
				state = "idle",
				goal = Vector3.zero,
				waitUntil = 0,
				eyes = eyes,
				tag = BlockAnimal.label(model, info.name, Color3.new(1, 1, 1), info.scale),
			}
			newGoal(g)
			model:PivotTo(CFrame.lookAt(g.pos, g.pos + g.facing))
			model.Parent = folder
			table.insert(guardians, g)
		end
	end

	local chasedBy: { [Player]: string } = {}
	local halfWidth = Layout.PATH_WIDTH / 2 - 2

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local carriers = EggService.carriers()
		local chasedNow: { [Player]: string } = {}

		for _, g in guardians do
			local info = Config.Zones[g.zone].guardian
			local target, root = findTarget(g, carriers)
			local moving = true

			if target and root then
				if g.state ~= "chase" then
					g.state = "chase"
					setAngry(g, true)
				end
				chasedNow[target] = info.name
				moveToward(g, root.Position, info.speed, dt)
				local flat = Vector3.new(root.Position.X - g.pos.X, 0, root.Position.Z - g.pos.Z)
				if flat.Magnitude < 2 + 2 * info.scale then
					catch(target, g, EggService, notify)
				end
			else
				if g.state == "chase" then
					g.state = "return"
					setAngry(g, false)
					newGoal(g)
				end
				if g.state == "return" then
					if moveToward(g, g.goal, info.speed * RETURN_SPEED, dt) then
						g.state = "idle"
						g.waitUntil = now + rng:NextNumber(1, 3)
					end
				elseif now < g.waitUntil then
					moving = false
				elseif moveToward(g, g.goal, info.speed * IDLE_SPEED, dt) then
					newGoal(g)
					g.waitUntil = now + rng:NextNumber(1, 4)
				end
			end

			-- stay on the path and out of the start area
			g.pos = Vector3.new(math.clamp(g.pos.X, -halfWidth, halfWidth), 0, math.clamp(g.pos.Z, Layout.SAFE_Z + 2, Layout.pathEnd() - 2))
			local bob = if moving then math.abs(math.sin(now * 10)) * 0.4 * info.scale else 0
			local at = g.pos + Vector3.new(0, bob, 0)
			g.model:PivotTo(CFrame.lookAt(at, at + g.facing))
		end

		-- tell players who is chasing them (only when it changes)
		for player, name in chasedNow do
			if chasedBy[player] ~= name then
				player:SetAttribute("ChasedBy", name)
			end
		end
		for player in chasedBy do
			if not chasedNow[player] and player.Parent then
				player:SetAttribute("ChasedBy", "")
			end
		end
		chasedBy = chasedNow
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("ChasedBy", "")
	end)
end

return GuardianService
