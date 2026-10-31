--!strict
-- Janela da Franquia (rebirth, docs/V2.md seção 4). Mostra o custo, o bônus e o que zera e o que fica. O
-- botão pede confirmação (dois cliques) porque a loja volta a ser uma barraquinha.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local FranchiseUi = {}

local window: Ui.Window

function FranchiseUi.toggle()
	window.toggle()
end

function FranchiseUi.start()
	window = Ui.window("Franchise", "FRANCHISE")
	local settings = Config.Franchise

	local status = Ui.row(window, 1, 70)
	local level = Ui.text(status, "", UDim2.fromScale(0.94, 0.5), UDim2.fromScale(0.03, 0.05))
	level.TextColor3 = Color3.fromRGB(255, 220, 120)
	local bonus = Ui.text(status, "", UDim2.fromScale(0.94, 0.38), UDim2.fromScale(0.03, 0.57))
	bonus.TextColor3 = Ui.MUTED

	local lines = {
		"Opening a franchise starts your store over as a kiosk...",
		"RESETS: cash, safe, store parts and terminal upgrades.",
		"KEEPS: your anomalies, the Index, back room, cells and security.",
		`GAIN: +{math.floor(settings.INCOME_BONUS * 100)}% income forever and new things to build.`,
	}
	for index, line in lines do
		local row = Ui.row(window, 1 + index, 40)
		row.BackgroundTransparency = 1
		Ui.text(row, line, UDim2.fromScale(0.96, 0.8), UDim2.fromScale(0.02, 0.1)).TextColor3 = if index
				== 4
			then Color3.fromRGB(120, 255, 140)
			else Color3.new(1, 1, 1)
	end

	local action = Ui.row(window, 10, 70)
	action.BackgroundTransparency = 1
	local button = Ui.button(action, UDim2.fromScale(0.7, 0.8), UDim2.fromScale(0.15, 0.1), Ui.GOLD)

	local confirming = false
	local function refresh()
		local franchise = Ui.number("Franchise")
		local cost = Ui.number("FranchiseCost")
		level.Text = `Franchises opened: {franchise}`
		bonus.Text = `Current bonus: +{math.floor(franchise * settings.INCOME_BONUS * 100)}% income`
		if franchise >= settings.MAX then
			button.Text = "ALL FRANCHISES OPENED"
			button.BackgroundColor3 = Ui.DISABLED
		elseif confirming then
			button.Text = "ARE YOU SURE? CLICK AGAIN"
			button.BackgroundColor3 = Color3.fromRGB(220, 70, 50)
		else
			button.Text = `OPEN FRANCHISE #{franchise + 1} · {NumberFormat.cash(cost)}`
			button.BackgroundColor3 = if Ui.number("Cash") >= cost then Ui.GOLD else Ui.DISABLED
		end
	end
	button.Activated:Connect(function()
		if Ui.number("Cash") < Ui.number("FranchiseCost") then
			return
		end
		if confirming then
			confirming = false
			Remotes.get("OpenFranchise"):FireServer()
			window.close()
		else
			confirming = true
			task.delay(4, function()
				confirming = false
				refresh()
			end)
		end
		refresh()
	end)
	for _, attribute in { "Franchise", "FranchiseCost", "Cash" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
end

return FranchiseUi
