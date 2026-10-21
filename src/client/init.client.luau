local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Layout = require(Shared:WaitForChild("Layout"))
local notifyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer

-- HUD: the zone you are in (top), what to do with your egg (under it) and messages (bottom)
local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent: Instance, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Parent = parent
	return l
end

local zoneLabel = label(gui, UDim2.new(0.6, 0, 0, 40), UDim2.new(0.5, 0, 0, 52))
local statusLabel = label(gui, UDim2.new(0.7, 0, 0, 30), UDim2.new(0.5, 0, 0, 96))

local toasts = Instance.new("Frame")
toasts.AnchorPoint = Vector2.new(0.5, 1)
toasts.Size = UDim2.new(0.8, 0, 0, 200)
toasts.Position = UDim2.new(0.5, 0, 1, -110)
toasts.BackgroundTransparency = 1
toasts.Parent = gui
local list = Instance.new("UIListLayout")
list.VerticalAlignment = Enum.VerticalAlignment.Bottom
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = toasts

local TOAST_COLORS = {
	good = Color3.fromRGB(120, 230, 110),
	danger = Color3.fromRGB(255, 90, 80),
}
local lastToast = { text = "", at = 0 }
local toastOrder = 0

notifyEvent.OnClientEvent:Connect(function(text: string, kind: string?)
	-- the same message again right away (e.g. touching a pad many times) is shown once
	local now = os.clock()
	if text == lastToast.text and now - lastToast.at < 2 then
		return
	end
	lastToast.text, lastToast.at = text, now
	toastOrder += 1

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 30)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = TOAST_COLORS[kind or ""] or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Text = text
	l.LayoutOrder = toastOrder
	l.Parent = toasts
	task.delay(3.5, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(l, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.5)
		l:Destroy()
	end)
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local zone = Layout.zoneAt(root.Position.Z)
		if zone == 0 then
			zoneLabel.Text = "START · safe zone"
			zoneLabel.TextColor3 = Color3.new(1, 1, 1)
		else
			local info = Config.Zones[zone]
			zoneLabel.Text = `ZONE {zone} · {string.upper(info.name)}`
			zoneLabel.TextColor3 = info.egg
		end
	end

	local carrying = player:GetAttribute("CarryingZone") or 0
	local chasedBy = player:GetAttribute("ChasedBy") or ""
	if chasedBy ~= "" then
		statusLabel.Text = `RUN! The {chasedBy}s are chasing you!`
		-- blink red and white
		statusLabel.TextColor3 = if math.floor(os.clock() * 4) % 2 == 0 then Color3.fromRGB(255, 70, 60) else Color3.new(1, 1, 1)
	elseif carrying > 0 and player:GetAttribute("EggSecured") then
		statusLabel.Text = "Take your egg to an incubator at your base"
		statusLabel.TextColor3 = Color3.fromRGB(120, 230, 110)
	elseif carrying > 0 then
		statusLabel.Text = "Run back to the START!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		statusLabel.Text = "Equip your sword (1) and hit an egg on the path"
		statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	end
end)
