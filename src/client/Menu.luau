--!strict
-- Botões laterais (meio da tela, à esquerda): SHOP, INDEX, LURE, GIFTS e FRANCHISE. Abrem as janelas sem precisar
-- andar até o terminal. O botão de presentes ganha um "!" quando tem algo para pegar.
-- Tamanho em escala com mínimo em pixels, para dar para tocar no celular.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)
local FranchiseUi = require(script.Parent.FranchiseUi)
local IndexUi = require(script.Parent.IndexUi)
local LureUi = require(script.Parent.LureUi)
local RewardsUi = require(script.Parent.RewardsUi)
local UpgradesUi = require(script.Parent.UpgradesUi)

local player = Players.LocalPlayer

local Menu = {}

type Entry = { label: string, color: Color3, toggle: () -> (), icon: string }

local ENTRIES: { Entry } = {
	{ label = "SHOP", color = Ui.GREEN, toggle = UpgradesUi.toggle, icon = "Shop" },
	{ label = "INDEX", color = Color3.fromRGB(140, 90, 210), toggle = IndexUi.toggle, icon = "Index" },
	{ label = "LURE", color = Color3.fromRGB(90, 60, 200), toggle = LureUi.toggle, icon = "Lure" },
	{ label = "GIFTS", color = Ui.GOLD, toggle = RewardsUi.toggle, icon = "Gifts" },
	{
		label = "FRANCHISE",
		color = Color3.fromRGB(210, 70, 90),
		toggle = FranchiseUi.toggle,
		icon = "Franchise",
	},
}

function Menu.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.fromScale(0.01, 0.42) -- um pouco acima do meio: embaixo fica o direcional do celular
	column.Size = UDim2.fromScale(0.11, 0.42)
	column.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(84, 250)
	constraint.MaxSize = Vector2.new(150, 400)
	constraint.Parent = column
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column

	local badge: TextLabel? = nil
	for index, entry in ENTRIES do
		local button = Ui.button(column, UDim2.fromScale(1, 0.17), UDim2.new(), entry.color)
		button.LayoutOrder = index
		button.Text = entry.label
		button.Activated:Connect(entry.toggle)
		-- Com ícone: ícone à esquerda e texto encostado à direita.
		if Ui.icon(button, entry.icon, UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0, 0.1)) then
			button.TextXAlignment = Enum.TextXAlignment.Right
		end
		if entry.toggle == RewardsUi.toggle then
			local mark = Ui.text(
				button,
				"!",
				UDim2.fromScale(0.28, 0.6),
				UDim2.fromScale(0.8, -0.2),
				Enum.TextXAlignment.Center
			)
			mark.BackgroundTransparency = 0
			mark.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
			mark.Visible = false
			Ui.round(mark, 1)
			badge = mark
		end
	end

	-- O "!" depende do relógio (presentes por tempo), então confere a cada segundo.
	task.spawn(function()
		while gui.Parent do
			if badge then
				badge.Visible = RewardsUi.hasSomething()
			end
			task.wait(1)
		end
	end)
end

return Menu
