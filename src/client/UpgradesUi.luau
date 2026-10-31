--!strict
-- Janela de upgrades e gamepasses. Abre no botão "Upgrades" do terminal da loja.
-- O cliente só mostra e pede a compra (Remote "BuyUpgrade"); o servidor confere o dinheiro e aplica.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local player = Players.LocalPlayer

local UpgradesUi = {}

local PANEL = Color3.fromRGB(28, 32, 40)
local ROW = Color3.fromRGB(42, 48, 60)
local BUY = Color3.fromRGB(46, 160, 120)
local DISABLED = Color3.fromRGB(80, 84, 92)
local PASS = Color3.fromRGB(0, 120, 215)

local function text(
	parent: Instance,
	value: string,
	size: UDim2,
	position: UDim2,
	align: Enum.TextXAlignment?
)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.Size = size
	label.Position = position
	label.Text = value
	label.Parent = parent
	return label
end

local function button(parent: Instance, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Size = size
	b.Position = position
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = b
	b.Parent = parent
	return b
end

local function cash(): number
	local value = player:GetAttribute("Cash")
	return if typeof(value) == "number" then value else 0
end

function UpgradesUi.start()
	local buyRemote = Remotes.get("BuyUpgrade")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Upgrades"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromScale(0.5, 0.7)
	panel.BackgroundColor3 = PANEL
	panel.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 300)
	constraint.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.03, 0)
	corner.Parent = panel

	text(panel, "UPGRADES", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.04, 0.02))
	local close = button(panel, UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.9, 0.02))
	close.Text = "X"
	close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.03, 0.12)
	list.Size = UDim2.fromScale(0.94, 0.85)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local refreshers: { () -> () } = {}

	local function row(order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = ROW
		frame.Size = UDim2.new(1, -8, 0, 64)
		frame.LayoutOrder = order
		frame.Parent = list
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0.15, 0)
		rowCorner.Parent = frame
		return frame
	end

	for order, definition in Upgrades.LIST do
		local frame = row(order)
		local title = text(frame, "", UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.03, 0.05))
		local description =
			text(frame, definition.description, UDim2.fromScale(0.62, 0.38), UDim2.fromScale(0.03, 0.57))
		description.TextColor3 = Color3.fromRGB(190, 195, 205)
		local buy = button(frame, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15))

		local attribute = Upgrades.attributeName(definition.id)
		local function refresh()
			local raw = player:GetAttribute(attribute)
			local level = if typeof(raw) == "number" then raw else 0
			title.Text = `{definition.displayName}  ({level}/{definition.maxLevel})`
			if level >= definition.maxLevel then
				buy.Text = "MAX"
				buy.BackgroundColor3 = DISABLED
			else
				local cost = Upgrades.cost(definition.id, level)
				buy.Text = NumberFormat.cash(cost)
				buy.BackgroundColor3 = if cash() >= cost then BUY else DISABLED
			end
		end
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
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
		local frame = row(order)
		text(frame, `⭐ {pass.displayName}`, UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.03, 0.05))
		local description = if key == "DoubleCash"
			then "Double all your income."
			else "Shelves restock by themselves."
		text(frame, description, UDim2.fromScale(0.62, 0.38), UDim2.fromScale(0.03, 0.57)).TextColor3 =
			Color3.fromRGB(190, 195, 205)
		local buy = button(frame, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15))

		local function refresh()
			if player:GetAttribute(`Pass_{key}`) == true then
				buy.Text = "OWNED"
				buy.BackgroundColor3 = DISABLED
			elseif pass.id == 0 then
				buy.Text = "SOON"
				buy.BackgroundColor3 = DISABLED
			else
				buy.Text = `R$ {pass.price}`
				buy.BackgroundColor3 = PASS
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
			gui.Enabled = not gui.Enabled
		end
	end)
end

return UpgradesUi
