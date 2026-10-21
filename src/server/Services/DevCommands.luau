local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)

-- Chat commands for testing. They work for everyone in Studio, and in a live server only for the
-- game's owner and the user ids in DEV_USER_IDS.
--   /speed [n]     walk at n (default 60), ignoring Strength
--   /cash [n]      add n coins (default 1M)
--   /attack [n]    every hit does n damage (default 1000), ignoring your sword (/attck works too)
--   /reset speed   back to a new player's speed: Strength 0, no /speed
--   /reset cash    coins back to 0
--   /reset attack  back to a new player's damage: Wooden Sword, no /attack
local DevCommands = {}

local DEV_USER_IDS: { number } = {}

local DEFAULT_SPEED = 60
local DEFAULT_CASH = 1_000_000
local DEFAULT_DAMAGE = 1000

local function isDev(player: Player): boolean
	if RunService:IsStudio() or table.find(DEV_USER_IDS, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

function DevCommands.start(PlotService, TrainingService, SwordService, notify: (Player, string, string?) -> ())
	local function coinsOf(player: Player): NumberValue?
		local stats = player:FindFirstChild("leaderstats")
		return stats and stats:FindFirstChild("Coins") :: NumberValue?
	end

	local commands = {
		speed = function(player: Player, arg: string?)
			local speed = math.clamp(tonumber(arg) or DEFAULT_SPEED, 0, 500)
			player:SetAttribute("DevSpeed", speed)
			PlotService.applySpeed(player)
			notify(player, `[dev] speed {speed}`, "good")
		end,
		cash = function(player: Player, arg: string?)
			local coins = coinsOf(player)
			if coins then
				local amount = tonumber(arg) or DEFAULT_CASH
				coins.Value = math.max(0, coins.Value + amount)
				notify(player, `[dev] +{Config.format(amount)} coins`, "good")
			end
		end,
		attack = function(player: Player, arg: string?)
			local damage = math.max(1, tonumber(arg) or DEFAULT_DAMAGE)
			player:SetAttribute("DevDamage", damage)
			notify(player, `[dev] every hit does {Config.format(damage)} damage`, "good")
		end,
		reset = function(player: Player, arg: string?)
			if arg == "speed" then
				player:SetAttribute("DevSpeed", nil)
				TrainingService.setStrength(player, 0)
				notify(player, `[dev] speed reset to {Config.playerSpeed(player)}`, "good")
			elseif arg == "attack" or arg == "attck" then
				player:SetAttribute("DevDamage", nil)
				player:SetAttribute("SwordTier", 1)
				SwordService.give(player)
				notify(player, `[dev] damage reset to {Config.playerDamage(player)}`, "good")
			elseif arg == "cash" then
				local coins = coinsOf(player)
				if coins then
					coins.Value = 0
				end
				notify(player, "[dev] coins reset to 0", "good")
			else
				notify(player, "[dev] use /reset speed, /reset cash or /reset attack")
			end
		end,
	}
	local aliases = { attck = "attack" } -- extra names for a command

	local function run(player: Player, text: string)
		local words = string.split(string.lower(text), " ")
		local name = string.sub(words[1], 2) -- "/speed" -> "speed"
		local command = commands[aliases[name] or name]
		if command and isDev(player) then
			command(player, words[2])
		end
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		-- registered commands are not shown in chat
		for name in commands do
			local command = Instance.new("TextChatCommand")
			command.Name = `Dev_{name}`
			command.PrimaryAlias = `/{name}`
			for alias, target in aliases do
				if target == name then
					command.SecondaryAlias = `/{alias}`
				end
			end
			command.Parent = TextChatService
			command.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, text)
				end
			end)
		end
	else
		local function hook(player: Player)
			player.Chatted:Connect(function(text)
				if string.sub(text, 1, 1) == "/" then
					run(player, text)
				end
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in Players:GetPlayers() do
			hook(player)
		end
	end
end

return DevCommands
