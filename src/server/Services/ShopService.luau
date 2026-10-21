local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local ShopBuilder = require(script.Parent.Parent.World.ShopBuilder)

-- The sword shop and the dummy shop (Config.Shops). The stalls only open the shop window on the
-- client (client Panels/ShopPanel); buying and equipping go through the Shop remote:
--   Shop:InvokeServer(shopName, "buy" | "equip", tier) -> (ok, message)
-- Buying an item also equips it. What a player owns lives in attributes (see Config.Shops); the
-- services react to the equipped attribute changing (SwordService, TrainingService).
local ShopService = {}

local PlotService

local function ownedText(owned: { [number]: boolean }): string
	local tiers = {}
	for tier in owned do
		table.insert(tiers, tier)
	end
	table.sort(tiers)
	return table.concat(tiers, ",")
end

local function handle(player: Player, shopName: string, action: string, tier: number): (boolean, string)
	local shop = Config.Shops[shopName]
	local item = shop and shop.items[tier]
	if not item then
		return false, "Unknown item"
	end
	local owned = Config.parseOwned(player:GetAttribute(shop.owned))

	if action == "equip" then
		if not owned[tier] then
			return false, "You don't own that yet"
		end
		player:SetAttribute(shop.equipped, tier)
		return true, `Equipped {item.name}`
	elseif action == "buy" then
		if owned[tier] then
			return false, "You already own that"
		end
		local coins = PlotService.coinsOf(player)
		if not coins or coins.Value < item.cost then
			return false, `You need ${Config.format(item.cost)}`
		end
		coins.Value -= item.cost
		owned[tier] = true
		player:SetAttribute(shop.owned, ownedText(owned))
		player:SetAttribute(shop.equipped, tier)
		return true, `You bought the {item.name}!`
	end
	return false, "Unknown action"
end

function ShopService.start(parent: Instance, remotes: Folder, plotService)
	PlotService = plotService
	ShopBuilder.build(parent, "Swords", Config.Shops.Swords.title, Layout.SWORD_SHOP, Color3.fromRGB(70, 130, 220))
	ShopBuilder.build(parent, "Dummies", Config.Shops.Dummies.title, Layout.DUMMY_SHOP, Color3.fromRGB(230, 110, 60))

	local remote = Instance.new("RemoteFunction")
	remote.Name = "Shop"
	remote.Parent = remotes
	remote.OnServerInvoke = function(player: Player, shopName: any, action: any, tier: any)
		if typeof(shopName) ~= "string" or typeof(action) ~= "string" or typeof(tier) ~= "number" then
			return false, "Bad request"
		end
		return handle(player, shopName, action, tier)
	end
end

return ShopService
