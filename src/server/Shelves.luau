--!strict
-- Estoque das prateleiras (docs/V1.md, seção 4).
--
-- Cada prateleira guarda o estoque no atributo "Stock". O cliente tira itens dela; o dono repõe segurando o
-- botão "Restock". Uma plaquinha em cima mostra quanto tem.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local Passes = require(script.Parent.Passes)
local Plots = require(script.Parent.Plots)

local Customers = Config.Customers

local Shelves = {}

local function stockLabel(shelf: BasePart): TextLabel?
	local billboard = shelf:FindFirstChild("StockBillboard")
	local label = billboard and billboard:FindFirstChild("Text")
	return if label and label:IsA("TextLabel") then label else nil
end

-- Quantos itens cabem no móvel: o do próprio móvel (atributo "Capacity", ver Street/Pieces.luau) mais o
-- bônus do upgrade Bigger Shelves (atributo "ShelfBonus" da loja).
function Shelves.capacity(shelf: BasePart): number
	local base = shelf:GetAttribute("Capacity")
	local store = shelf:FindFirstAncestor("Store")
	local bonus = store and store:GetAttribute("ShelfBonus")
	return (if typeof(base) == "number" then base else Customers.SHELF_CAPACITY)
		+ (if typeof(bonus) == "number" then bonus else 0)
end

-- Multiplica o preço dos itens deste móvel (geladeira 2x, comida quente 4x).
function Shelves.priceMultiplier(shelf: BasePart): number
	local multiplier = shelf:GetAttribute("PriceMultiplier")
	return if typeof(multiplier) == "number" then multiplier else 1
end

-- Os produtos de enfeite somem conforme o estoque cai, para dar para ver de longe o que precisa repor.
local function showProducts(shelf: BasePart, stock: number, capacity: number)
	local products = {}
	for _, child in shelf:GetChildren() do
		if child.Name == "Product" and child:IsA("BasePart") then
			table.insert(products, child)
		end
	end
	local visible = math.ceil(#products * math.clamp(stock / math.max(capacity, 1), 0, 1))
	for index, part in products do
		part.Transparency = if index <= visible then 0 else 1
	end
end

local function setStock(shelf: BasePart, stock: number)
	local capacity = Shelves.capacity(shelf)
	shelf:SetAttribute("Stock", stock)
	local label = stockLabel(shelf)
	if label then
		label.Text = if stock > 0 then `{stock}/{capacity}` else "EMPTY"
		label.TextColor3 = if stock > capacity * 0.3
			then Color3.new(1, 1, 1)
			elseif stock > 0 then Color3.fromRGB(255, 200, 80)
			else Color3.fromRGB(255, 90, 90)
	end
	showProducts(shelf, stock, capacity)
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
	setStock(shelf, Shelves.capacity(shelf))
end

-- Atualiza as plaquinhas depois de mudar a capacidade (upgrade Bigger Shelves).
function Shelves.refreshLabels(store: Model)
	for _, shelf in Shelves.list(store) do
		setStock(shelf, Shelves.getStock(shelf))
	end
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

-- Prepara um móvel que vende: plaquinha de estoque, botão de repor e estoque cheio. Não faz nada se ele já
-- foi preparado.
function Shelves.setup(owner: Player, shelf: BasePart)
	if shelf:FindFirstChild("RestockPrompt") then
		return
	end
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
	prompt.ObjectText = if shelf:GetAttribute("SellerKind") == "Fridge"
		then "Fridge"
		elseif shelf:GetAttribute("SellerKind") == "HotFood" then "Hot Food"
		else "Shelf"
	prompt.HoldDuration = Customers.RESTOCK_HOLD_SECONDS
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", owner.UserId) -- o cliente esconde o botão para quem não é dono
	prompt.Parent = shelf

	prompt.Triggered:Connect(function(who)
		if who == owner then
			Shelves.refill(shelf)
			Analytics.step(owner, "FirstRestock")
		end
	end)

	Shelves.refill(shelf)
end

-- Prepara todos os móveis da loja que ainda não foram preparados (chamado também depois de cada compra).
function Shelves.setupAll(player: Player)
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
	Plots.onStoreReady(Shelves.setupAll)
	task.spawn(restockRobotLoop)
end

return Shelves
