--!strict
-- Clientes e anomalias andando na loja (docs/V1.md, seções 4 e 5).
--
-- Cada loja recebe clientes de tempos em tempos. O cliente entra, pega itens de uma prateleira, entra na
-- fila do caixa e espera o dono decidir:
--   Charge  (F, no caixa)    cobra. Humano paga; anomalia leva 10% do cofre.
--   Refuse  (R, no caixa)    manda embora. Anomalia: sem estrago. Humano: menos clientes por um tempo.
--   Capture (C, no cliente)  só de madrugada. Anomalia vai para uma cela; humano foge assustado.
-- Anomalia ignorada no caixa por muito tempo foge para a loja vizinha mais perto.
--
-- Os bonecos vêm do CustomerModel (R15 com cores sorteadas) e as anomalias são "quebradas" pelo AnomalyLooks.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnomalyLooks = require(script.Parent.AnomalyLooks)
local Cells = require(script.Parent.Cells)
local CustomerModel = require(script.Parent.CustomerModel)
local DayNight = require(script.Parent.DayNight)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local Plots = require(script.Parent.Plots)
local Shelves = require(script.Parent.Shelves)
local StoreUpgrades = require(script.Parent.StoreUpgrades)

local Settings = Config.Customers
local AnomalySettings = Config.Anomalies

local HUMAN = "Human"
local WALK_TIMEOUT = 8 -- segundos tentando chegar num ponto antes de desistir dele
local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 100, 100)
local INFO = Color3.fromRGB(255, 230, 140)

type State = "Shopping" | "Queued" | "Leaving" | "Gone"

export type Customer = {
	model: Model,
	humanoid: Humanoid,
	description: HumanoidDescription,
	kind: string, -- "Human" ou o id de uma anomalia (Shared/Anomalies.luau)
	variant: string,
	items: number,
	state: State,
	escapes: number,
}

type StoreState = {
	owner: Player,
	store: Model,
	origin: CFrame,
	counter: BasePart,
	folder: Folder,
	customers: { Customer },
	queue: { Customer },
	nextSpawnAt: number,
	penaltyUntil: number,
}

local Customers = {}

local stores: { [Player]: StoreState } = {}
local random = Random.new()
local notify: RemoteEvent

local function isAnomaly(customer: Customer): boolean
	return customer.kind ~= HUMAN
end

local function nameOf(customer: Customer): string
	return Anomalies.fullName(customer.kind, customer.variant)
end

local function tell(player: Player, text: string, color: Color3)
	notify:FireClient(player, text, color)
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

-- Onde o cliente fica para pegar itens: do lado -X da prateleira, no meio dela (ver Layout.shelfOffset).
local function shelfSpot(state: StoreState, shelf: BasePart): Vector3
	local localPos = state.origin:PointToObjectSpace(shelf.Position)
	return point(state, localPos.X - shelf.Size.X / 2 - 1.5, localPos.Z)
end

-- Lugar `slot` da fila (0 = na frente do caixa). A fila cresce em direção à porta.
local function queueSpot(state: StoreState, slot: number): Vector3
	local localPos = state.origin:PointToObjectSpace(state.counter.Position)
	return point(state, localPos.X + slot * 2.5, localPos.Z - state.counter.Size.Z / 2 - 1.5)
end

-- Anda até `position`. Devolve false se o cliente sumiu no caminho (loja fechou, foi capturado).
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

-- Some com o cliente na hora (capturado ou loja fechada).
local function vanish(state: StoreState, customer: Customer)
	customer.state = "Gone"
	removeFrom(state.queue, customer)
	removeFrom(state.customers, customer)
	updateQueue(state)
	customer.model:Destroy()
end

local function leave(state: StoreState, customer: Customer)
	if customer.state == "Leaving" or customer.state == "Gone" then
		return
	end
	customer.state = "Leaving"
	removeFrom(state.queue, customer)
	updateQueue(state)

	local _ = walk(customer, doorInside(state))
		and walk(customer, doorOutside(state))
		and walk(customer, sidewalkPoint(state))

	if customer.state == "Leaving" then
		vanish(state, customer)
	end
end

local function penalize(state: StoreState)
	state.penaltyUntil = os.clock() + AnomalySettings.REFUSED_HUMAN_PENALTY_SECONDS
end

local function floatingText(parent: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 60

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard

	billboard.Parent = parent
	Debris:AddItem(billboard, 1.5)
end

-- Luz do teto piscando por um instante: o sinal de que algo errado foi atendido.
local function flickerLights(state: StoreState)
	local structure = state.store:FindFirstChild("Structure")
	local lamp = structure and structure:FindFirstChild("CeilingLight")
	local light = lamp and lamp:FindFirstChildOfClass("PointLight")
	if light == nil then
		return
	end
	task.spawn(function()
		for _ = 1, 8 do
			light.Enabled = not light.Enabled
			task.wait(random:NextNumber(0.05, 0.25))
		end
		light.Enabled = true
	end)
end

local function chargeOne(state: StoreState): boolean
	local customer = state.queue[1]
	if customer == nil then
		return false
	end

	if isAnomaly(customer) then
		local lost = Economy.takeFromSafe(state.owner, AnomalySettings.BAD_SERVE_SAFE_LOSS)
		flickerLights(state)
		floatingText(state.counter, "-" .. NumberFormat.cash(lost), BAD)
		tell(
			state.owner,
			`That was a {nameOf(customer)}! It took {NumberFormat.cash(lost)} from your safe.`,
			BAD
		)
	else
		local multiplier = if DayNight.isNight() then Settings.NIGHT_PRICE_MULTIPLIER else 1
		local amount = Economy.addToSafe(state.owner, customer.items * Settings.ITEM_PRICE * multiplier)
		floatingText(state.counter, "+" .. NumberFormat.cash(amount), GOOD)
	end

	task.spawn(leave, state, customer)
	return not isAnomaly(customer)
end

-- Cobra o primeiro da fila e, com o upgrade Fast Register, mais alguns. Para ao topar com uma anomalia.
local function charge(state: StoreState)
	for _ = 1, StoreUpgrades.chargeBatch(state.owner) do
		if not chargeOne(state) then
			return
		end
	end
end

local function refuse(state: StoreState)
	local customer = state.queue[1]
	if customer == nil then
		return
	end

	if isAnomaly(customer) then
		tell(state.owner, `Good call! That was a {nameOf(customer)}.`, GOOD)
	else
		penalize(state)
		tell(state.owner, "That was a real customer... fewer people will come for a while.", BAD)
	end

	task.spawn(leave, state, customer)
end

local function capture(state: StoreState, customer: Customer)
	if customer.state == "Leaving" or customer.state == "Gone" then
		return
	end

	if not isAnomaly(customer) then
		penalize(state)
		tell(state.owner, "You scared a real customer! Fewer people will come for a while.", BAD)
		task.spawn(leave, state, customer)
		return
	end

	if not Cells.tryAdd(state.owner, customer.kind, customer.variant) then
		tell(state.owner, "No free cell! Upgrade your cells or refuse it.", INFO)
		return
	end

	tell(state.owner, `Captured: {nameOf(customer)}!`, GOOD)
	vanish(state, customer)
end

-- Botão "Capture" no próprio cliente, só para o dono da loja onde ele está. Só existe em quem chega de
-- madrugada (de dia não aparecem anomalias).
local function addCapturePrompt(state: StoreState, customer: Customer)
	local root = customer.model.PrimaryPart
	if root == nil then
		return
	end
	local old = root:FindFirstChild("CapturePrompt")
	if old then
		old:Destroy()
	end
	if not DayNight.isNight() then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CapturePrompt"
	prompt.ActionText = "Capture"
	prompt.ObjectText = "Customer"
	prompt.KeyboardKeyCode = Enum.KeyCode.C
	prompt.HoldDuration = StoreUpgrades.captureHoldSeconds(state.owner)
	prompt.MaxActivationDistance = AnomalySettings.CAPTURE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", state.owner.UserId)
	prompt.Parent = root

	prompt.Triggered:Connect(function(who)
		if who == state.owner and DayNight.isNight() then
			capture(state, customer)
		end
	end)
end

local function nearestOtherStore(state: StoreState): StoreState?
	local best: StoreState? = nil
	local bestDistance = math.huge
	for _, other in stores do
		if other ~= state and other.store.Parent ~= nil then
			local distance = (other.origin.Position - state.origin.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = other
			end
		end
	end
	return best
end

local shop: (StoreState, Customer) -> ()

-- A anomalia ignorada sai da loja e entra na do vizinho, onde vira problema dele.
local function escape(state: StoreState, customer: Customer)
	local neighbor = nearestOtherStore(state)
	if neighbor == nil then
		leave(state, customer)
		return
	end

	customer.state = "Leaving"
	removeFrom(state.queue, customer)
	updateQueue(state)
	tell(state.owner, `A {nameOf(customer)} escaped to {neighbor.owner.DisplayName}'s store!`, BAD)

	if not (walk(customer, doorInside(state)) and walk(customer, doorOutside(state))) then
		return
	end

	removeFrom(state.customers, customer)
	customer.escapes += 1
	customer.state = "Shopping"
	customer.model.Parent = neighbor.folder
	customer.model:PivotTo(CFrame.new(sidewalkPoint(neighbor)))
	table.insert(neighbor.customers, customer)
	addCapturePrompt(neighbor, customer)
	tell(
		neighbor.owner,
		`Something escaped from {state.owner.DisplayName}'s store... watch your customers.`,
		INFO
	)

	shop(neighbor, customer)
end

function shop(state: StoreState, customer: Customer)
	if not (walk(customer, doorOutside(state)) and walk(customer, doorInside(state))) then
		return
	end

	local shelves = Shelves.list(state.store)
	if #shelves == 0 then
		leave(state, customer)
		return
	end
	local shelf = shelves[random:NextInteger(1, #shelves)]
	if not walk(customer, shelfSpot(state, shelf)) then
		return
	end
	task.wait(1.5)

	-- O Salt Buyer leva tudo o que tiver na prateleira.
	local wanted = if customer.kind == "SaltBuyer" then math.huge else customer.items
	customer.items = Shelves.take(shelf, wanted)
	if customer.items == 0 and not isAnomaly(customer) then
		leave(state, customer) -- prateleira vazia: vai embora sem comprar
		return
	end

	customer.state = "Queued"
	table.insert(state.queue, customer)
	updateQueue(state)

	local patience = if isAnomaly(customer)
		then AnomalySettings.ESCAPE_AFTER_SECONDS
		else Settings.CHECKOUT_PATIENCE
	local waitedSince = os.clock()
	while customer.state == "Queued" and customer.model.Parent ~= nil do
		if os.clock() - waitedSince > patience then
			if isAnomaly(customer) and customer.escapes == 0 then
				escape(state, customer)
			else
				leave(state, customer)
			end
			return
		end
		task.wait(0.25)
	end
end

local function anomalyChance(): number
	local studio = Config.Debug.STUDIO_NIGHT_ANOMALY_CHANCE
	return if RunService:IsStudio() and studio > 0 then studio else AnomalySettings.NIGHT_CHANCE
end

local function spawnCustomer(state: StoreState)
	local kind = HUMAN
	local variant = "Normal"
	if DayNight.isNight() and random:NextNumber() < anomalyChance() then
		kind = Anomalies.pickDefinition(random).id
		variant = Anomalies.pickVariant(random).id
	end

	-- The Twin copia a aparência de alguém que já está na loja.
	local description = CustomerModel.randomDescription()
	if kind == "Twin" and #state.customers > 0 then
		description = state.customers[random:NextInteger(1, #state.customers)].description:Clone()
	end

	local model = CustomerModel.build(description)
	if kind ~= HUMAN then
		AnomalyLooks.apply(model, kind, variant)
	end
	if state.store.Parent == nil then
		model:Destroy()
		return
	end
	model:PivotTo(CFrame.new(sidewalkPoint(state)))
	model.Parent = state.folder

	local root = model.PrimaryPart
	if root then
		root:SetNetworkOwner(nil) -- o servidor controla o movimento, sem engasgos
	end

	local customer: Customer = {
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		description = description,
		kind = kind,
		variant = variant,
		items = random:NextInteger(Settings.MIN_ITEMS, Settings.MAX_ITEMS),
		state = "Shopping",
		escapes = 0,
	}
	table.insert(state.customers, customer)
	addCapturePrompt(state, customer)
	shop(state, customer)
end

local function makeCounterPrompt(
	owner: Player,
	counter: BasePart,
	name: string,
	action: string,
	key: Enum.KeyCode
)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = "Register"
	prompt.KeyboardKeyCode = key
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Parent = counter
	return prompt
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

	local state: StoreState = {
		owner = player,
		store = store,
		origin = origin,
		counter = counter,
		folder = folder,
		customers = {},
		queue = {},
		nextSpawnAt = os.clock() + 2,
		penaltyUntil = 0,
	}
	stores[player] = state

	-- Dois botões no mesmo lugar: o Roblox mostra os dois lado a lado.
	makeCounterPrompt(player, counter, "ChargePrompt", "Charge", Enum.KeyCode.F).Triggered:Connect(
		function(who)
			if who == player then
				charge(state)
			end
		end
	)
	makeCounterPrompt(player, counter, "RefusePrompt", "Refuse", Enum.KeyCode.R).Triggered:Connect(
		function(who)
			if who == player then
				refuse(state)
			end
		end
	)
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
				if now < state.penaltyUntil then
					interval *= 2
				end
				interval /= StoreUpgrades.customerRate(owner)
				state.nextSpawnAt = now + interval
				task.spawn(spawnCustomer, state)
			end
		end
	end
end

-- Precisa rodar depois de Plots, Economy, Shelves e Cells.
function Customers.start()
	notify = Remotes.get("Notify")

	PhysicsService:RegisterCollisionGroup(CustomerModel.COLLISION_GROUP)
	PhysicsService:CollisionGroupSetCollidable(
		CustomerModel.COLLISION_GROUP,
		CustomerModel.COLLISION_GROUP,
		false
	)

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
