--!strict
-- Estoque das prateleiras (docs/V1.md, seção 4).
--
-- Cada prateleira guarda o estoque no atributo "Stock". O cliente tira itens dela; o dono repõe segurando o
-- botão "Restock". Uma plaquinha em cima mostra quanto tem.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Passes = require(script.Parent.Passes)
local Plots = require(script.Parent.Plots)

local Customers = Config.Customers

local Shelves = {}

local function stockLabel(shelf: BasePart): TextLabel?
	local billboard = shelf:FindFirstChild("StockBillboard")
	local label = billboard and billboard:FindFirstChild("Text")
	return if label and label:IsA("TextLabel") then label else nil
end

local function setStock(shelf: BasePart, stock: number)
	shelf:SetAttribute("Stock", stock)
	local label = stockLabel(shelf)
	if label then
		label.Text = if stock > 0 then `{stock}/{Customers.SHELF_CAPACITY}` else "EMPTY"
		label.TextColor3 = if stock > 0 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 90, 90)
	end
end

function Shelves.getStock(shelf: BasePart): number
	local stock = shelf:GetAttribute("Stock")
	return if typeof(stock) == "number" then stock else 0
end

-- Tira até `amount` itens. Devolve quantos conseguiu tirar.
function Shelves.take(shelf: BasePart, amount: number): number
	local taken = math.min(amount, Shelves.getStock(shelf))
	setStock(shelf, Shelves.getStock(shelf) - taken)
	return taken
end

function Shelves.refill(shelf: BasePart)
	setStock(shelf, Customers.SHELF_CAPACITY)
end

function Shelves.list(store: Model): { BasePart }
	local result = {}
	local folder = store:FindFirstChild("Shelves")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(result, child)
			end
		end
	end
	return result
end

-- Prepara uma prateleira: plaquinha de estoque, botão de repor e estoque cheio.
function Shelves.setup(owner: Player, shelf: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StockBillboard"
	billboard.Size = UDim2.fromOffset(90, 30)
	billboard.StudsOffset = Vector3.new(0, shelf.Size.Y / 2 + 1, 0)
	billboard.MaxDistance = 50
	billboard.Parent = shelf

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RestockPrompt"
	prompt.ActionText = "Restock"
	prompt.ObjectText = "Shelf"
	prompt.HoldDuration = Customers.RESTOCK_HOLD_SECONDS
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", owner.UserId) -- o cliente esconde o botão para quem não é dono
	prompt.Parent = shelf

	prompt.Triggered:Connect(function(who)
		if who == owner then
			Shelves.refill(shelf)
		end
	end)

	Shelves.refill(shelf)
end

local function setupStore(player: Player)
	local store = Plots.getStore(player)
	if store == nil then
		return
	end
	for _, shelf in Shelves.list(store) do
		Shelves.setup(player, shelf)
	end
end

-- Gamepass Restock Robot: repõe todas as prateleiras do dono de tempos em tempos.
local function restockRobotLoop()
	while true do
		task.wait(Config.RESTOCK_ROBOT_INTERVAL)
		for _, player in Players:GetPlayers() do
			local store = Plots.getStore(player)
			if store and Passes.has(player, "RestockRobot") then
				for _, shelf in Shelves.list(store) do
					Shelves.refill(shelf)
				end
			end
		end
	end
end

-- Precisa rodar depois de Plots.start() e Passes.start().
function Shelves.start()
	Plots.onStoreReady(setupStore)
	task.spawn(restockRobotLoop)
end

return Shelves
