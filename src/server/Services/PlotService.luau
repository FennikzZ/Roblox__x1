local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local BaseBuilder = require(script.Parent.Parent.World.BaseBuilder)
local BlockAnimal = require(script.Parent.Parent.World.BlockAnimal)

-- Player bases: every player gets a free plot. Walking onto an incubator with a secured egg starts
-- hatching it; the hatched animal stands on the base and earns coins every second.
-- Also makes every player's leaderstats (Coins, Strength, Hatched) and starting attributes.
local PlotService = {}

type Animal = { model: Model, income: number }
type Incubator = { pad: BasePart, label: TextLabel, busy: boolean }
type Owned = {
	plot: BaseBuilder.Plot,
	incubators: { Incubator },
	animals: { [number]: Animal }, -- by slot
	generation: number, -- bumped when the owner leaves, so running hatch timers stop
}

local ANIMAL_SCALE = 0.55
local INCUBATOR_TEXT = "Incubator\nbring an egg"

local plots: { BaseBuilder.Plot } = {}
local owners: { [number]: Player } = {} -- plot index -> owner
local owned: { [Player]: Owned } = {}
local rng = Random.new()
local NotifyFn = nil :: (Player, string, string?) -> ()

local function coinsOf(player: Player): NumberValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins") :: NumberValue?
end

local function freeSlot(data: Owned): number?
	for i = 1, Config.BASE_SLOTS do
		if not data.animals[i] then
			return i
		end
	end
	return nil
end

local function busyIncubators(data: Owned): number
	local n = 0
	for _, inc in data.incubators do
		if inc.busy then
			n += 1
		end
	end
	return n
end

local function animalCount(data: Owned): number
	local n = 0
	for _ in data.animals do
		n += 1
	end
	return n
end

local function pickAnimal(zone: number): number
	local animals = Config.Zones[zone].animals
	local total = 0
	for _, a in animals do
		total += a.weight
	end
	local roll = rng:NextNumber(0, total)
	for i, a in animals do
		roll -= a.weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

local function placeAnimal(player: Player, data: Owned, zone: number, index: number)
	local slot = freeSlot(data)
	if not slot then
		return -- can't happen: room is checked before an egg goes in
	end
	local info = Config.Zones[zone].animals[index]
	local rarity = Config.Rarities[index]
	local model = BlockAnimal.build(info.name, info.color, ANIMAL_SCALE)
	local pos = data.plot.slots[slot]
	model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))) -- facing the path
	BlockAnimal.label(model, `{info.name}\n+{Config.format(info.income)}/s`, rarity.color, ANIMAL_SCALE * 1.6)
	model.Parent = data.plot.model
	data.animals[slot] = { model = model, income = info.income }

	local hatched = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Hatched") :: IntValue?
	if hatched then
		hatched.Value += 1
	end
	NotifyFn(player, `You hatched a {rarity.name} {info.name}! +{Config.format(info.income)} coins/s`, "good")
end

local function hatch(player: Player, data: Owned, inc: Incubator, zone: number)
	inc.busy = true
	local generation = data.generation
	local zoneInfo = Config.Zones[zone]

	local egg = Instance.new("Part")
	egg.Name = "HatchingEgg"
	egg.Anchored = true
	egg.CanCollide = false
	egg.Size = Vector3.new(2.4, 3, 2.4)
	egg.Color = zoneInfo.egg
	egg.Material = Enum.Material.SmoothPlastic
	egg.Position = inc.pad.Position + Vector3.new(0, 0.4 + 1.5, 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	egg.Parent = data.plot.model

	task.spawn(function()
		for left = zoneInfo.hatchSeconds, 1, -1 do
			if data.generation ~= generation then
				egg:Destroy()
				return
			end
			inc.label.Text = `{zoneInfo.name} egg\nhatching in {left}s`
			egg.CFrame = CFrame.new(egg.Position) * CFrame.Angles(0, 0, math.rad(if left % 2 == 0 then 6 else -6))
			task.wait(1)
		end
		egg:Destroy()
		if data.generation ~= generation then
			return
		end
		inc.busy = false
		inc.label.Text = INCUBATOR_TEXT
		placeAnimal(player, data, zone, pickAnimal(zone))
	end)
end

local function onIncubatorTouched(plotIndex: number, inc: Incubator, hit: BasePart)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or inc.busy then
		return
	end
	local EggService = PlotService.EggService
	local carry = EggService.carryOf(player)
	if not carry then
		return
	end
	if owners[plotIndex] ~= player then
		NotifyFn(player, "That's not your base! Find the one with your name.")
		return
	end
	local data = owned[player]
	if animalCount(data) + busyIncubators(data) >= Config.BASE_SLOTS then
		NotifyFn(player, "Your base is full!")
		return
	end
	local zone = EggService.take(player)
	if zone then
		hatch(player, data, inc, zone)
	end
end

-- sets the character's walk speed from the player's Strength (or dev speed)
function PlotService.applySpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.playerSpeed(player)
	end
end

PlotService.coinsOf = coinsOf

-- the base the player owns, if any
function PlotService.plotOf(player: Player): BaseBuilder.Plot?
	local data = owned[player]
	return data and data.plot
end

local function claim(player: Player)
	for i, plot in plots do
		if not owners[i] then
			owners[i] = player
			local incubators = {}
			for _, inc in plot.incubators do
				table.insert(incubators, { pad = inc.pad, label = inc.label, busy = false })
			end
			owned[player] = { plot = plot, incubators = incubators, animals = {}, generation = 0 }
			BaseBuilder.setOwner(plot, player)
			return
		end
	end
	warn(`[PlotService] no free base for {player.Name}`)
end

local function release(player: Player)
	local data = owned[player]
	if not data then
		return
	end
	owned[player] = nil
	data.generation += 1
	for _, animal in data.animals do
		animal.model:Destroy()
	end
	for _, inc in data.incubators do
		inc.label.Text = INCUBATOR_TEXT
	end
	for i, owner in owners do
		if owner == player then
			owners[i] = nil
			BaseBuilder.setOwner(data.plot, nil)
		end
	end
end

local function onPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local strength = Instance.new("NumberValue")
	strength.Name = "Strength"
	strength.Parent = stats
	local hatched = Instance.new("IntValue")
	hatched.Name = "Hatched"
	hatched.Parent = stats
	stats.Parent = player
	player:SetAttribute("Strength", 0) -- see TrainingService
	-- shop items (see Config.Shops): item 1 of each shop is free and equipped
	player:SetAttribute("OwnedSwords", "1")
	player:SetAttribute("SwordTier", 1)
	player:SetAttribute("OwnedDummies", "1")
	player:SetAttribute("DummyTier", 1)
	claim(player)

	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.WalkSpeed = Config.playerSpeed(player)
		local data = owned[player]
		if data then
			-- spawn in front of your own base, facing the path
			local pos = data.plot.center + Vector3.new(0, 4, Layout.PLOT_SIZE.Z / 2 + 4)
			task.defer(function()
				character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function PlotService.start(parent: Instance, EggService, notify: (Player, string, string?) -> ())
	PlotService.EggService = EggService
	NotifyFn = notify
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = parent

	for i = 1, Layout.PLOT_COUNT do
		local plot = BaseBuilder.build(folder, i)
		plots[i] = plot
		for n, inc in plot.incubators do
			inc.pad.Touched:Connect(function(hit)
				local data = owners[i] and owned[owners[i]]
				-- the owner's incubator state lives in `owned`; strangers only get the "not yours" hint
				local state = if data then data.incubators[n] else { pad = inc.pad, label = inc.label, busy = false }
				onIncubatorTouched(i, state, hit)
			end)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(release)

	-- income: every animal on a base pays its owner each second
	task.spawn(function()
		while true do
			task.wait(1)
			for player, data in owned do
				local income = 0
				for _, animal in data.animals do
					income += animal.income
				end
				local coins = coinsOf(player)
				if coins and income > 0 then
					coins.Value += income
				end
			end
		end
	end)
end

return PlotService
