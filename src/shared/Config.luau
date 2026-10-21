local Config = {}

-- Every number that shapes the game lives in this file.
-- The loop: walk up the long path, hit an egg with your sword until it cracks, carry it back to the
-- start before the zone's guardians catch you, then hatch it at your base. Zones further away are
-- harder: their eggs take more hits and their guardians run faster.
-- Two shops next to the bases help: better swords crack eggs faster, and better training dummies
-- (one stands at your base) build Strength faster, which makes you run faster.

-- ===== Number formatting =====
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.format(n: number): string
	n = math.floor(n)
	local value = n
	local i = 1
	while value >= 1000 and i < #SUFFIXES do
		value /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	-- "1.50K" -> "1.5K", "2.00M" -> "2M" (parentheses keep only the text, not gsub's count)
	return (string.format("%.2f%s", value, SUFFIXES[i]):gsub("%.?0+([%a]+)$", "%1"))
end

-- ===== Player =====
Config.BASE_WALK_SPEED = 16
Config.SWING_COOLDOWN = 0.35 -- seconds between two sword swings
Config.HIT_RANGE = 9 -- studs from your character an egg or dummy can be hit
Config.CAUGHT_STUN_SECONDS = 1.5 -- a guardian that catches you takes the egg and freezes you this long

-- ===== Swords (sword shop) =====
-- Every hit on an egg does the equipped sword's damage. Bought swords stay yours; equip any of them.
Config.Swords = {
	{ name = "Wooden Sword", damage = 1, cost = 0, color = Color3.fromRGB(150, 100, 60) },
	{ name = "Stone Sword", damage = 3, cost = 50, color = Color3.fromRGB(140, 140, 140) },
	{ name = "Iron Sword", damage = 8, cost = 300, color = Color3.fromRGB(200, 200, 210) },
	{ name = "Steel Sword", damage = 20, cost = 1_500, color = Color3.fromRGB(150, 175, 205) },
	{ name = "Gold Sword", damage = 50, cost = 8_000, color = Color3.fromRGB(255, 200, 60) },
	{ name = "Ruby Sword", damage = 120, cost = 40_000, color = Color3.fromRGB(220, 40, 60) },
	{ name = "Emerald Sword", damage = 300, cost = 200_000, color = Color3.fromRGB(40, 200, 100) },
	{ name = "Diamond Sword", damage = 750, cost = 1_000_000, color = Color3.fromRGB(120, 230, 255) },
	{ name = "Crystal Sword", damage = 2_000, cost = 5_000_000, color = Color3.fromRGB(190, 150, 255) },
	{ name = "Void Sword", damage = 5_000, cost = 25_000_000, color = Color3.fromRGB(110, 40, 200) },
}

-- ===== Training dummies (dummy shop) =====
-- Every base has one training dummy in front; it looks like the equipped dummy and every hit on it
-- gives that dummy's `strength`.
Config.Dummies = {
	{ name = "Straw Dummy", strength = 1, cost = 0, color = Color3.fromRGB(220, 190, 110) },
	{ name = "Wood Dummy", strength = 2, cost = 100, color = Color3.fromRGB(150, 100, 60) },
	{ name = "Stone Dummy", strength = 5, cost = 600, color = Color3.fromRGB(140, 140, 140) },
	{ name = "Iron Dummy", strength = 12, cost = 3_000, color = Color3.fromRGB(200, 200, 210) },
	{ name = "Gold Dummy", strength = 30, cost = 15_000, color = Color3.fromRGB(255, 200, 60) },
	{ name = "Ruby Dummy", strength = 75, cost = 75_000, color = Color3.fromRGB(220, 40, 60) },
	{ name = "Emerald Dummy", strength = 180, cost = 400_000, color = Color3.fromRGB(40, 200, 100) },
	{ name = "Diamond Dummy", strength = 450, cost = 2_000_000, color = Color3.fromRGB(120, 230, 255) },
	{ name = "Crystal Dummy", strength = 1_100, cost = 10_000_000, color = Color3.fromRGB(190, 150, 255) },
	{ name = "Void Dummy", strength = 2_700, cost = 50_000_000, color = Color3.fromRGB(110, 40, 200) },
}

-- ===== Shop windows =====
-- Rarity shown in the shop for item number 1-10 of Config.Swords / Config.Dummies
Config.ItemRarities = {
	{ name = "Common", color = Color3.fromRGB(200, 200, 200) },
	{ name = "Uncommon", color = Color3.fromRGB(110, 230, 90) },
	{ name = "Rare", color = Color3.fromRGB(70, 160, 255) },
	{ name = "Epic", color = Color3.fromRGB(190, 90, 255) },
	{ name = "Legendary", color = Color3.fromRGB(255, 180, 40) },
	{ name = "Mythic", color = Color3.fromRGB(255, 60, 110) },
}
local RARITY_BY_TIER = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 6 }

function Config.itemRarity(tier: number)
	return Config.ItemRarities[RARITY_BY_TIER[tier]]
end

-- The shops (see ShopService): which items a player owns is kept as a "1,3,4" string attribute,
-- the one they use as a number attribute.
Config.Shops = {
	Swords = { title = "Sword Shop", items = Config.Swords, owned = "OwnedSwords", equipped = "SwordTier" },
	Dummies = { title = "Dummy Shop", items = Config.Dummies, owned = "OwnedDummies", equipped = "DummyTier" },
}

function Config.parseOwned(text: string?): { [number]: boolean }
	local owned = {}
	for _, n in string.split(text or "1", ",") do
		local tier = tonumber(n)
		if tier then
			owned[tier] = true
		end
	end
	return owned
end

-- Strength -> walk speed: +SPEED_PER_DOUBLING every time (strength / STRENGTH_SCALE + 1) doubles.
-- 0 -> 16, 10 -> 18, 150 -> 24, 1.3K -> 30, 10K -> 36, 41K -> 40, 1M -> 49
Config.SPEED_PER_DOUBLING = 2
Config.STRENGTH_SCALE = 10

function Config.strengthSpeed(strength: number): number
	return Config.BASE_WALK_SPEED + Config.SPEED_PER_DOUBLING * math.log(1 + strength / Config.STRENGTH_SCALE, 2)
end

-- the speed a player walks at right now: from their Strength, unless a dev /speed command set DevSpeed
function Config.playerSpeed(player: Player): number
	return player:GetAttribute("DevSpeed") or Config.strengthSpeed(player:GetAttribute("Strength") or 0)
end

-- damage of one hit right now: their sword, unless a dev /attack command set DevDamage
function Config.playerDamage(player: Player): number
	local sword = Config.Swords[player:GetAttribute("SwordTier") or 1]
	return player:GetAttribute("DevDamage") or sword.damage
end

-- ===== Eggs and the base =====
Config.EGGS_PER_ZONE = 4 -- eggs lying in each zone at the same time
Config.EGG_RESPAWN_SECONDS = 3 -- how often a missing egg comes back
Config.INCUBATORS = 2 -- eggs a base can hatch at the same time
Config.BASE_SLOTS = 12 -- animals a base can hold

-- Hatched animals: 1 = common, 2 = rare, 3 = epic (the order in each zone's `animals` list)
Config.Rarities = {
	{ name = "Common", color = Color3.fromRGB(220, 220, 220) },
	{ name = "Rare", color = Color3.fromRGB(80, 170, 255) },
	{ name = "Epic", color = Color3.fromRGB(200, 100, 255) },
}

-- ===== Zones =====
-- Zone 1 starts right after the start area. Each guardian runs at `speed` studs per second
-- (a new player runs at 16, see Strength above), `count` of them guard the zone.
-- With the sword of the same number as the zone an egg takes about 5-7 hits.
Config.Zones = {
	{
		name = "Meadow",
		floor = Color3.fromRGB(124, 196, 92),
		floorMaterial = Enum.Material.Grass,
		wall = Color3.fromRGB(86, 140, 64),
		wallMaterial = Enum.Material.WoodPlanks,
		egg = Color3.fromRGB(255, 244, 214),
		eggHp = 5,
		hatchSeconds = 5,
		guardian = { name = "Dog", color = Color3.fromRGB(196, 150, 100), speed = 12, scale = 1, count = 2 },
		animals = {
			{ name = "Chick", color = Color3.fromRGB(255, 226, 90), income = 1, weight = 70 },
			{ name = "Bunny", color = Color3.fromRGB(240, 240, 240), income = 2, weight = 25 },
			{ name = "Fox", color = Color3.fromRGB(235, 130, 50), income = 5, weight = 5 },
		},
	},
	{
		name = "Forest",
		floor = Color3.fromRGB(70, 130, 60),
		floorMaterial = Enum.Material.LeafyGrass,
		wall = Color3.fromRGB(90, 64, 40),
		wallMaterial = Enum.Material.WoodPlanks,
		egg = Color3.fromRGB(170, 220, 130),
		eggHp = 15,
		hatchSeconds = 8,
		guardian = { name = "Wolf", color = Color3.fromRGB(120, 120, 130), speed = 15, scale = 1.15, count = 2 },
		animals = {
			{ name = "Deer", color = Color3.fromRGB(170, 120, 75), income = 8, weight = 70 },
			{ name = "Owl", color = Color3.fromRGB(140, 110, 80), income = 15, weight = 25 },
			{ name = "Bear Cub", color = Color3.fromRGB(110, 75, 50), income = 30, weight = 5 },
		},
	},
	{
		name = "Swamp",
		floor = Color3.fromRGB(85, 110, 60),
		floorMaterial = Enum.Material.Mud,
		wall = Color3.fromRGB(60, 75, 45),
		wallMaterial = Enum.Material.WoodPlanks,
		egg = Color3.fromRGB(150, 190, 90),
		eggHp = 45,
		hatchSeconds = 12,
		guardian = { name = "Crocodile", color = Color3.fromRGB(70, 120, 60), speed = 18, scale = 1.25, count = 3 },
		animals = {
			{ name = "Frog", color = Color3.fromRGB(110, 200, 80), income = 50, weight = 70 },
			{ name = "Turtle", color = Color3.fromRGB(90, 140, 90), income = 90, weight = 25 },
			{ name = "Heron", color = Color3.fromRGB(200, 210, 220), income = 180, weight = 5 },
		},
	},
	{
		name = "Savanna",
		floor = Color3.fromRGB(220, 190, 110),
		floorMaterial = Enum.Material.Sand,
		wall = Color3.fromRGB(180, 140, 80),
		wallMaterial = Enum.Material.Sandstone,
		egg = Color3.fromRGB(240, 200, 90),
		eggHp = 120,
		hatchSeconds = 16,
		guardian = { name = "Lion", color = Color3.fromRGB(225, 170, 70), speed = 21, scale = 1.35, count = 3 },
		animals = {
			{ name = "Zebra", color = Color3.fromRGB(235, 235, 235), income = 300, weight = 70 },
			{ name = "Giraffe", color = Color3.fromRGB(240, 190, 90), income = 550, weight = 25 },
			{ name = "Elephant", color = Color3.fromRGB(150, 150, 160), income = 1_100, weight = 5 },
		},
	},
	{
		name = "Desert",
		floor = Color3.fromRGB(235, 205, 140),
		floorMaterial = Enum.Material.Sand,
		wall = Color3.fromRGB(200, 160, 100),
		wallMaterial = Enum.Material.Sandstone,
		egg = Color3.fromRGB(255, 220, 140),
		eggHp = 300,
		hatchSeconds = 20,
		guardian = { name = "Scorpion", color = Color3.fromRGB(170, 90, 40), speed = 24, scale = 1.45, count = 3 },
		animals = {
			{ name = "Camel", color = Color3.fromRGB(210, 170, 110), income = 1_800, weight = 70 },
			{ name = "Fennec", color = Color3.fromRGB(240, 210, 160), income = 3_500, weight = 25 },
			{ name = "Sand Snake", color = Color3.fromRGB(220, 180, 90), income = 7_000, weight = 5 },
		},
	},
	{
		name = "Tundra",
		floor = Color3.fromRGB(235, 245, 255),
		floorMaterial = Enum.Material.Snow,
		wall = Color3.fromRGB(170, 200, 230),
		wallMaterial = Enum.Material.Ice,
		egg = Color3.fromRGB(180, 225, 255),
		eggHp = 800,
		hatchSeconds = 25,
		guardian = { name = "Polar Bear", color = Color3.fromRGB(245, 245, 250), speed = 27, scale = 1.55, count = 4 },
		animals = {
			{ name = "Penguin", color = Color3.fromRGB(40, 40, 50), income = 12_000, weight = 70 },
			{ name = "Seal", color = Color3.fromRGB(150, 160, 175), income = 25_000, weight = 25 },
			{ name = "Arctic Fox", color = Color3.fromRGB(250, 250, 255), income = 60_000, weight = 5 },
		},
	},
	{
		name = "Volcano",
		floor = Color3.fromRGB(60, 50, 50),
		floorMaterial = Enum.Material.Basalt,
		wall = Color3.fromRGB(90, 40, 30),
		wallMaterial = Enum.Material.CrackedLava,
		egg = Color3.fromRGB(255, 110, 50),
		eggHp = 2_000,
		hatchSeconds = 30,
		guardian = { name = "Raptor", color = Color3.fromRGB(200, 70, 40), speed = 30, scale = 1.65, count = 4 },
		animals = {
			{ name = "Salamander", color = Color3.fromRGB(255, 90, 40), income = 80_000, weight = 70 },
			{ name = "Phoenix Chick", color = Color3.fromRGB(255, 160, 40), income = 160_000, weight = 25 },
			{ name = "Lava Golem", color = Color3.fromRGB(120, 40, 30), income = 350_000, weight = 5 },
		},
	},
	{
		name = "Crystal Cave",
		floor = Color3.fromRGB(80, 70, 110),
		floorMaterial = Enum.Material.Slate,
		wall = Color3.fromRGB(120, 200, 255),
		wallMaterial = Enum.Material.Glass,
		egg = Color3.fromRGB(130, 230, 255),
		eggHp = 5_000,
		hatchSeconds = 35,
		guardian = { name = "Crystal Golem", color = Color3.fromRGB(150, 220, 255), speed = 33, scale = 1.8, count = 4 },
		animals = {
			{ name = "Gem Beetle", color = Color3.fromRGB(100, 255, 200), income = 500_000, weight = 70 },
			{ name = "Crystal Bat", color = Color3.fromRGB(170, 140, 255), income = 1_000_000, weight = 25 },
			{ name = "Geode Turtle", color = Color3.fromRGB(90, 200, 230), income = 2_200_000, weight = 5 },
		},
	},
	{
		name = "Sky Islands",
		floor = Color3.fromRGB(240, 240, 255),
		floorMaterial = Enum.Material.SmoothPlastic,
		wall = Color3.fromRGB(255, 230, 150),
		wallMaterial = Enum.Material.Marble,
		egg = Color3.fromRGB(255, 250, 200),
		eggHp = 12_000,
		hatchSeconds = 40,
		guardian = { name = "Griffin", color = Color3.fromRGB(230, 200, 120), speed = 36, scale = 1.95, count = 5 },
		animals = {
			{ name = "Cloud Sheep", color = Color3.fromRGB(250, 250, 255), income = 3_000_000, weight = 70 },
			{ name = "Sky Whale", color = Color3.fromRGB(140, 190, 255), income = 6_000_000, weight = 25 },
			{ name = "Pegasus", color = Color3.fromRGB(255, 240, 250), income = 13_000_000, weight = 5 },
		},
	},
	{
		name = "Void",
		floor = Color3.fromRGB(45, 30, 70),
		floorMaterial = Enum.Material.Slate,
		wall = Color3.fromRGB(110, 70, 190),
		wallMaterial = Enum.Material.Neon,
		egg = Color3.fromRGB(170, 90, 255),
		eggHp = 30_000,
		hatchSeconds = 45,
		guardian = { name = "Dragon", color = Color3.fromRGB(110, 60, 200), speed = 40, scale = 2.2, count = 5 },
		animals = {
			{ name = "Shadow Cat", color = Color3.fromRGB(60, 40, 90), income = 20_000_000, weight = 70 },
			{ name = "Star Whale", color = Color3.fromRGB(90, 120, 255), income = 40_000_000, weight = 25 },
			{ name = "Void Dragon", color = Color3.fromRGB(140, 60, 255), income = 90_000_000, weight = 5 },
		},
	},
}

return Config
