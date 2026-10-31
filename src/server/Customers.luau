--!strict
-- Clientes normais (docs/V1.md, seção 4).
--
-- Cada loja recebe clientes de tempos em tempos. O cliente entra, pega itens de uma prateleira, entra na
-- fila do caixa e espera o dono apertar "Charge". O valor da venda vai para o cofre (Economy.addToSafe).
-- Se ninguém cobrar dentro da paciência dele, vai embora sem pagar.
--
-- Os clientes são bonecos R15 criados por HumanoidDescription com cores sorteadas: nenhum modelo 3D externo.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local DayNight = require(script.Parent.DayNight)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local Plots = require(script.Parent.Plots)
local Shelves = require(script.Parent.Shelves)

local Settings = Config.Customers

local COLLISION_GROUP = "Customers"
local WALK_TIMEOUT = 8 -- segundos tentando chegar num ponto antes de desistir dele

type State = "Shopping" | "Queued" | "Leaving"

export type Customer = {
	model: Model,
	humanoid: Humanoid,
	owner: Player,
	items: number,
	state: State,
}

type StoreState = {
	store: Model,
	origin: CFrame,
	counter: BasePart,
	folder: Folder,
	customers: { Customer },
	queue: { Customer },
	nextSpawnAt: number,
}

local SKIN_TONES = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(92, 56, 32),
}

local CLOTHES = {
	Color3.fromRGB(52, 101, 164),
	Color3.fromRGB(204, 0, 0),
	Color3.fromRGB(78, 154, 6),
	Color3.fromRGB(237, 212, 0),
	Color3.fromRGB(117, 80, 123),
	Color3.fromRGB(46, 52, 54),
	Color3.fromRGB(245, 121, 0),
	Color3.fromRGB(238, 238, 236),
}

local Customers = {}

local stores: { [Player]: StoreState } = {}
local random = Random.new()

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

-- Ponto no chão da loja, a partir de coordenadas locais do terreno (ver Street/Layout.luau).
local function point(state: StoreState, x: number, z: number): Vector3
	return (state.origin * CFrame.new(x, 3, z)).Position
end

local function sidewalkPoint(state: StoreState): Vector3
	local side = if random:NextNumber() < 0.5 then -1 else 1
	return point(state, side * random:NextNumber(14, 24), Layout.STORE_FRONT_Z - 5)
end

local function doorOutside(state: StoreState): Vector3
	return point(state, 0, Layout.STORE_FRONT_Z - 3)
end

local function doorInside(state: StoreState): Vector3
	return point(state, 0, Layout.STORE_FRONT_Z + 3)
end

-- Onde o cliente fica para pegar itens: do lado da prateleira, no meio dela.
local function shelfSpot(state: StoreState, shelf: BasePart): Vector3
	local localPos = state.origin:PointToObjectSpace(shelf.Position)
	return point(state, localPos.X + shelf.Size.X / 2 + 1.5, localPos.Z)
end

-- Lugar `slot` da fila (0 = na frente do caixa). A fila cresce em direção à porta.
local function queueSpot(state: StoreState, slot: number): Vector3
	local localPos = state.origin:PointToObjectSpace(state.counter.Position)
	return point(state, localPos.X + slot * 2.5, localPos.Z - state.counter.Size.Z / 2 - 1.5)
end

local function buildModel(): Model
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKIN_TONES)
	local shirt = pick(CLOTHES)
	local pants = pick(CLOTHES)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Customer"

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Settings.WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = COLLISION_GROUP
		end
	end

	return model
end

-- Anda até `position`. Devolve false se o cliente sumiu no caminho (loja fechou).
local function walk(customer: Customer, position: Vector3): boolean
	if customer.model.Parent == nil then
		return false
	end

	local arrived = false
	local connection = customer.humanoid.MoveToFinished:Once(function()
		arrived = true
	end)
	customer.humanoid:MoveTo(position)

	local started = os.clock()
	while not arrived and customer.model.Parent ~= nil and os.clock() - started < WALK_TIMEOUT do
		task.wait(0.1)
	end
	connection:Disconnect()
	return customer.model.Parent ~= nil
end

local function removeFrom(list: { Customer }, customer: Customer)
	local index = table.find(list, customer)
	if index then
		table.remove(list, index)
	end
end

local function updateQueue(state: StoreState)
	for index, customer in state.queue do
		customer.humanoid:MoveTo(queueSpot(state, index - 1))
	end
end

local function leave(state: StoreState, customer: Customer)
	customer.state = "Leaving"
	removeFrom(state.queue, customer)
	updateQueue(state)

	local _ = walk(customer, doorInside(state))
		and walk(customer, doorOutside(state))
		and walk(customer, sidewalkPoint(state))

	removeFrom(state.customers, customer)
	customer.model:Destroy()
end

-- "+$15" flutuando em cima do caixa por um instante.
local function showSale(state: StoreState, amount: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 60

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.TextStrokeTransparency = 0.3
	label.Text = "+" .. NumberFormat.cash(amount)
	label.Parent = billboard

	billboard.Parent = state.counter
	Debris:AddItem(billboard, 1.2)
end

-- Cobra o primeiro da fila. Chamado quando o dono aperta "Charge" no caixa.
local function checkout(owner: Player)
	local state = stores[owner]
	local customer = state and state.queue[1]
	if state == nil or customer == nil then
		return
	end

	local multiplier = if DayNight.isNight() then Settings.NIGHT_PRICE_MULTIPLIER else 1
	local amount = customer.items * Settings.ITEM_PRICE * multiplier
	Economy.addToSafe(owner, amount)
	showSale(state, amount)

	task.spawn(leave, state, customer)
end

local function shop(state: StoreState, customer: Customer)
	if not (walk(customer, doorOutside(state)) and walk(customer, doorInside(state))) then
		return
	end

	local shelves = Shelves.list(state.store)
	if #shelves == 0 then
		leave(state, customer)
		return
	end
	local shelf = pick(shelves)
	if not walk(customer, shelfSpot(state, shelf)) then
		return
	end
	task.wait(1.5)

	customer.items = Shelves.take(shelf, customer.items)
	if customer.items == 0 then
		leave(state, customer) -- prateleira vazia: vai embora sem comprar
		return
	end

	customer.state = "Queued"
	table.insert(state.queue, customer)
	updateQueue(state)

	local waitedSince = os.clock()
	while customer.state == "Queued" and customer.model.Parent ~= nil do
		if os.clock() - waitedSince > Settings.CHECKOUT_PATIENCE then
			leave(state, customer) -- cansou de esperar
			return
		end
		task.wait(0.25)
	end
end

local function spawnCustomer(owner: Player, state: StoreState)
	local model = buildModel()
	model:PivotTo(CFrame.new(sidewalkPoint(state)))
	model.Parent = state.folder

	local root = model.PrimaryPart
	if root then
		root:SetNetworkOwner(nil) -- o servidor controla o movimento, sem engasgos
	end

	local customer: Customer = {
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		owner = owner,
		items = random:NextInteger(Settings.MIN_ITEMS, Settings.MAX_ITEMS),
		state = "Shopping",
	}
	table.insert(state.customers, customer)
	shop(state, customer)
end

local function setupStore(player: Player)
	local store = Plots.getStore(player)
	local origin = Plots.getOrigin(player)
	local counter = store and store:FindFirstChild("Counter")
	if store == nil or origin == nil or counter == nil or not counter:IsA("BasePart") then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = store

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChargePrompt"
	prompt.ActionText = "Charge"
	prompt.ObjectText = "Register"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Parent = counter
	prompt.Triggered:Connect(function(who)
		if who == player then
			checkout(player)
		end
	end)

	stores[player] = {
		store = store,
		origin = origin,
		counter = counter,
		folder = folder,
		customers = {},
		queue = {},
		nextSpawnAt = os.clock() + 2,
	}
end

local function spawnLoop()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for owner, state in stores do
			if state.store.Parent == nil then
				stores[owner] = nil
			elseif now >= state.nextSpawnAt and #state.customers < Settings.MAX_IN_STORE then
				local interval = if DayNight.isNight() then Settings.NIGHT_INTERVAL else Settings.DAY_INTERVAL
				state.nextSpawnAt = now + interval
				task.spawn(spawnCustomer, owner, state)
			end
		end
	end
end

-- Precisa rodar depois de Plots.start() e Shelves.start().
function Customers.start()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)

	Players.PlayerAdded:Connect(setupStore)
	Players.PlayerRemoving:Connect(function(player)
		stores[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(setupStore, player)
	end

	task.spawn(spawnLoop)
end

return Customers
