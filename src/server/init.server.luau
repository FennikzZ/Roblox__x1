local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- map building (src/server/World)
local PathBuilder = require(script.World.PathBuilder)
-- game systems (src/server/Services)
local EggService = require(script.Services.EggService)
local GuardianService = require(script.Services.GuardianService)
local PlotService = require(script.Services.PlotService)
local TrainingService = require(script.Services.TrainingService)
local SwordService = require(script.Services.SwordService)
local ShopService = require(script.Services.ShopService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

-- server -> client messages: (text, kind) where kind is nil, "good" or "danger"
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local function notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind)
end

PathBuilder.build(workspace)
EggService.start(notify)
GuardianService.start(EggService, notify)
-- PlotService first: it makes every player's leaderstats and attributes the others read
PlotService.start(workspace, EggService, notify)
TrainingService.start(PlotService, notify)
SwordService.start(EggService, TrainingService)
ShopService.start(workspace, remotes, PlotService)
require(script.Services.DevCommands).start(PlotService, TrainingService, SwordService, notify)
