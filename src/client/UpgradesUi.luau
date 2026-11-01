--!strict
-- Janela da loja: upgrades do terminal e gamepasses. Abre no botão "Upgrades" do terminal da loja ou no botão
-- SHOP do menu lateral. O cliente só mostra e pede a compra ("BuyUpgrade"); o servidor confere e aplica.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local UpgradesUi = {}

local PASS_DESCRIPTIONS = {
	DoubleCash = "Double all your income, forever.",
	RestockRobot = "Shelves restock by themselves.",
}

local window: Ui.Window

function UpgradesUi.toggle()
	window.toggle()
end

function UpgradesUi.start()
	local buyRemote = Remotes.get("BuyUpgrade")
	window = Ui.window("Upgrades", "UPGRADES")

	local refreshers: { () -> () } = {}

	for order, definition in Upgrades.LIST do
		local frame = Ui.row(window, order)
		local title = Ui.text(frame, "", UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.03, 0.05))
		local description =
			Ui.text(frame, definition.description, UDim2.fromScale(0.62, 0.38), UDim2.fromScale(0.03, 0.57))
		description.TextColor3 = Ui.MUTED
		local buy = Ui.button(frame, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15))

		local attribute = Upgrades.attributeName(definition.id)
		local function refresh()
			local level = Ui.number(attribute)
			title.Text = `{definition.displayName}  ({level}/{definition.maxLevel})`
			local needed = definition.requiresBuild
			if needed and player:GetAttribute(`Build_{needed}`) ~= true then
				local piece = Builds.get(needed)
				buy.Text = `Needs {if piece then piece.displayName else needed}`
				buy.BackgroundColor3 = Ui.DISABLED
			elseif level >= definition.maxLevel then
				buy.Text = "MAX"
				buy.BackgroundColor3 = Ui.DISABLED
			else
				local cost = Upgrades.cost(definition.id, level)
				buy.Text = NumberFormat.cash(cost)
				buy.BackgroundColor3 = if Ui.number("Cash") >= cost then Ui.GREEN else Ui.DISABLED
			end
		end
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
		if definition.requiresBuild then
			player:GetAttributeChangedSignal(`Build_{definition.requiresBuild}`):Connect(refresh)
		end
		table.insert(refreshers, refresh)
		refresh()

		buy.Activated:Connect(function()
			buyRemote:FireServer(definition.id)
		end)
	end

	-- Gamepasses no fim da lista.
	local order = #Upgrades.LIST
	for key, pass in Config.GamePasses do
		order += 1
		local frame = Ui.row(window, order)
		Ui.text(frame, `⭐ {pass.displayName}`, UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.03, 0.05))
		Ui.text(
			frame,
			(PASS_DESCRIPTIONS :: any)[key] or "",
			UDim2.fromScale(0.62, 0.38),
			UDim2.fromScale(0.03, 0.57)
		).TextColor3 =
			Ui.MUTED
		local buy = Ui.button(frame, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15))
		Ui.robuxIcon(buy)

		local function refresh()
			if player:GetAttribute(`Pass_{key}`) == true then
				buy.Text = "OWNED"
				buy.BackgroundColor3 = Ui.DISABLED
			elseif pass.id == 0 then
				buy.Text = "SOON"
				buy.BackgroundColor3 = Ui.DISABLED
			else
				buy.Text = Ui.robuxPrice(pass.price)
				buy.BackgroundColor3 = Ui.BLUE
			end
		end
		player:GetAttributeChangedSignal(`Pass_{key}`):Connect(refresh)
		refresh()

		buy.Activated:Connect(function()
			if pass.id ~= 0 and player:GetAttribute(`Pass_{key}`) ~= true then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
	end

	-- A cor do botão depende do dinheiro atual.
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		for _, refresh in refreshers do
			refresh()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "UpgradePrompt" and prompt:GetAttribute("OwnerUserId") == player.UserId then
			window.toggle()
		end
	end)
end

return UpgradesUi
