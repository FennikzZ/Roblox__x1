local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Layout = require(ReplicatedStorage.Shared.Layout)

-- Training: every base has one dummy in front (Layout.PLOT_DUMMY) that looks like the owner's
-- equipped dummy (attribute DummyTier, bought in the dummy shop, see ShopService). Hitting it with
-- your sword gives that dummy's strength (attribute Strength, also in leaderstats), and Strength
-- makes you run faster (Config.strengthSpeed).
local TrainingService = {}

type Dummy = { owner: Player, model: Model, rest: CFrame }

local NotifyFn = nil :: (Player, string, string?) -> ()
local PlotService
local dummies: { [Player]: Dummy } = {}
local SHAKE = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

local function setStrength(player: Player, strength: number)
	player:SetAttribute("Strength", strength)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Strength") :: NumberValue?
	if value then
		value.Value = strength
	end
	PlotService.applySpeed(player)
end

-- (re)builds the dummy at the player's base to match their equipped dummy
local function placeDummy(player: Player)
	local old = dummies[player]
	if old then
		old.model:Destroy()
		dummies[player] = nil
	end
	local plot = PlotService.plotOf(player)
	if not plot then
		return
	end
	local tier = player:GetAttribute("DummyTier") or 1
	local model = ItemModels.dummy(tier, plot.center + Layout.PLOT_DUMMY + Vector3.new(0, 0.4, 0))
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi, 0)) -- face the path
	for _, p in model:GetChildren() do
		(p :: BasePart).CanCollide = p.Name ~= "Arms"
	end
	local info = Config.Dummies[tier]
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	tag.MaxDistance = 50
	tag.Adornee = model:FindFirstChild("Head") :: BasePart
	tag.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Config.itemRarity(tier).color
	label.TextStrokeTransparency = 0
	label.Text = `{info.name}\n+{Config.format(info.strength)} strength/hit`
	label.Parent = tag

	model.Parent = plot.model
	dummies[player] = { owner = player, model = model, rest = model:GetPivot() }
end

-- A sword swing (see SwordService): hits the closest dummy within reach.
function TrainingService.tryHit(player: Player, root: BasePart): boolean
	local best, bestDist = nil, math.huge
	for _, dummy in dummies do
		local offset = dummy.rest.Position - root.Position
		local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if dist <= Config.HIT_RANGE and dist < bestDist then
			best, bestDist = dummy, dist
		end
	end
	if not best then
		return false
	end
	if best.owner ~= player then
		NotifyFn(player, "That's someone else's dummy. Train on the one at your own base!")
		return true
	end
	local info = Config.Dummies[player:GetAttribute("DummyTier") or 1]
	setStrength(player, (player:GetAttribute("Strength") or 0) + info.strength)

	-- wobble the dummy on its base
	local rest = best.rest
	local value = Instance.new("CFrameValue")
	value.Value = rest
	value.Changed:Connect(function(cf)
		if best.model.Parent then
			best.model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(value, SHAKE, { Value = rest * CFrame.Angles(math.rad(-10), 0, 0) })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
	return true
end

-- used by the dev command /reset speed
TrainingService.setStrength = setStrength

function TrainingService.start(plotService, notify: (Player, string, string?) -> ())
	PlotService, NotifyFn = plotService, notify

	-- PlotService gives the base on join (it starts first), so the dummy can go up right away
	local function onPlayer(player: Player)
		placeDummy(player)
		player:GetAttributeChangedSignal("DummyTier"):Connect(function()
			placeDummy(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local dummy = dummies[player]
		if dummy then
			dummy.model:Destroy()
			dummies[player] = nil
		end
	end)
end

return TrainingService
