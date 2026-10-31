--!strict
-- Janela da Isca da Fenda (docs/V3.md, seção 8): lista os monstros da rua que dá para chamar com Robux.
-- O jogador escolhe um monstro certo antes de pagar (nada sorteado). O servidor confere e só então manda abrir
-- a compra (LureApproved). No Studio, com Config.Debug.STUDIO_FREE_LURES, o monstro sai na hora.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

type Product = { id: number, price: number, rarities: { string } }

local PRODUCTS = Config.RiftLure.PRODUCTS :: { [string]: Product }

local player = Players.LocalPlayer

local LureUi = {}

local window: Ui.Window

function LureUi.toggle()
	window.toggle()
end

local function productFor(rarity: string): Product?
	for _, product in PRODUCTS do
		if table.find(product.rarities, rarity) then
			return product
		end
	end
	return nil
end

function LureUi.start()
	window = Ui.window("RiftLure", "RIFT LURE")
	local free = RunService:IsStudio() and Config.Debug.STUDIO_FREE_LURES

	local header = Ui.row(window, 0, 54)
	header.BackgroundTransparency = 1
	Ui.text(
		header,
		`Pick a monster. It climbs out of the sewer next to your store and is yours to catch for {Config.RiftLure.RESERVE_SECONDS}s (you still pay its $ price).`,
		UDim2.fromScale(0.96, 0.9),
		UDim2.fromScale(0.02, 0.05),
		Enum.TextXAlignment.Center
	).TextColor3 =
		Color3.fromRGB(255, 220, 120)

	local chooseRemote = Remotes.get("ChooseLure")
	for order, definition in Anomalies.STREET do
		local product = productFor(definition.rarity)
		if product == nil then
			continue
		end
		local row = Ui.row(window, order, 86)
		local name =
			Ui.text(row, definition.displayName, UDim2.fromScale(0.6, 0.34), UDim2.fromScale(0.03, 0.06))
		name.TextColor3 = Anomalies.RARITY_COLORS[definition.rarity]
		Ui.text(
			row,
			`{definition.rarity} · {NumberFormat.cash(definition.incomePerSecond)}/s · costs {NumberFormat.cash(
				definition.captureCost or 0
			)}`,
			UDim2.fromScale(0.6, 0.24),
			UDim2.fromScale(0.03, 0.42)
		).TextColor3 =
			Ui.MUTED
		Ui.text(row, definition.power or "", UDim2.fromScale(0.6, 0.22), UDim2.fromScale(0.03, 0.7)).TextColor3 =
			Color3.fromRGB(150, 255, 200)

		local buy = Ui.button(row, UDim2.fromScale(0.3, 0.6), UDim2.fromScale(0.67, 0.2))
		if free then
			buy.Text = "FREE (Studio)"
			buy.BackgroundColor3 = Ui.GREEN
		elseif product.id == 0 then
			buy.Text = "SOON"
			buy.BackgroundColor3 = Ui.DISABLED
		else
			buy.Text = `R$ {product.price}`
			buy.BackgroundColor3 = Ui.BLUE
		end
		buy.Activated:Connect(function()
			if free or product.id ~= 0 then
				chooseRemote:FireServer(definition.id)
				window.close()
			end
		end)
	end

	Remotes.get("LureApproved").OnClientEvent:Connect(function(productId)
		if typeof(productId) == "number" then
			MarketplaceService:PromptProductPurchase(player, productId)
		end
	end)
end

return LureUi
