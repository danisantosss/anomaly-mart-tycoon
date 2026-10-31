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
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local BuildCatalog = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnomalyLooks = require(script.Parent.AnomalyLooks)
local Builds = require(script.Parent.Builds)
local Cells = require(script.Parent.Cells)
local CustomerModel = require(script.Parent.CustomerModel)
local Data = require(script.Parent.Data)
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
	price: number, -- preço de cada item, vindo do móvel onde ele pegou (geladeira 2x, comida 4x)
	state: State,
	escapes: number,
	tutorial: boolean, -- primeira anomalia do jogador novo: dá para capturar de dia e não foge
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
	nextSelfCheckoutAt: number,
	penaltyUntil: number,
	sales: number, -- clientes humanos cobrados nesta sessão
	graceLeft: number, -- erros que ainda saem de graça nesta sessão (Config.Anomalies.MISTAKE_GRACE)
	tutorialDone: boolean,
}

local Customers = {}

local stores: { [Player]: StoreState } = {}
local random = Random.new()
local notify: RemoteEvent

local function clueOf(customer: Customer): string
	local definition = Anomalies.get(customer.kind)
	return if definition then definition.clue else ""
end

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

-- Tem alguma prateleira (ou outro móvel da loja) ocupando este ponto do chão?
local function isBlocked(state: StoreState, position: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { state.store }
	for _, part in workspace:GetPartBoundsInRadius(position, 1.2, params) do
		if part.CanCollide and part.Size.Y > 1 and not part:IsDescendantOf(state.folder) then
			return true
		end
	end
	return false
end

-- Onde o cliente fica para pegar itens: na frente da prateleira (lado -X), ou do outro lado se esse estiver
-- encostado em outro móvel. Assim ninguém fica preso numa quina.
local function shelfSpot(state: StoreState, shelf: BasePart): Vector3
	local localPos = state.origin:PointToObjectSpace(shelf.Position)
	local gap = shelf.Size.X / 2 + 1.5
	local candidates = {
		point(state, localPos.X - gap, localPos.Z),
		point(state, localPos.X + gap, localPos.Z),
		point(state, localPos.X, localPos.Z - shelf.Size.Z / 2 - 1.5),
	}
	for _, candidate in candidates do
		if not isBlocked(state, candidate) then
			return candidate
		end
	end
	return candidates[1]
end

-- Lugar `slot` da fila (0 = na frente do caixa). A fila cresce em direção à porta.
local function queueSpot(state: StoreState, slot: number): Vector3
	local localPos = state.origin:PointToObjectSpace(state.counter.Position)
	return point(state, localPos.X + slot * 2.5, localPos.Z - state.counter.Size.Z / 2 - 1.5)
end

-- Anda em linha reta até `position`, desistindo depois de `timeout` segundos.
local function moveStraight(customer: Customer, position: Vector3, timeout: number)
	local arrived = false
	local connection = customer.humanoid.MoveToFinished:Once(function()
		arrived = true
	end)
	customer.humanoid:MoveTo(position)

	local started = os.clock()
	while not arrived and customer.model.Parent ~= nil and os.clock() - started < timeout do
		task.wait(0.1)
	end
	connection:Disconnect()
end

local pathParams = {
	AgentRadius = 1.5,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 4,
}

-- Anda até `position` desviando de prateleiras e paredes (PathfindingService). Se não achar caminho, tenta
-- em linha reta. Devolve false se o cliente sumiu no caminho (loja fechou, foi capturado).
local function walk(customer: Customer, position: Vector3): boolean
	local root = customer.model.PrimaryPart
	if customer.model.Parent == nil or root == nil then
		return false
	end

	local path = PathfindingService:CreatePath(pathParams)
	local ok = pcall(path.ComputeAsync, path, root.Position, position)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for index = 2, #waypoints do
			if customer.model.Parent == nil then
				return false
			end
			moveStraight(customer, waypoints[index].Position, 3)
		end
	else
		moveStraight(customer, position, WALK_TIMEOUT)
	end
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

-- Gasta um erro de graça, se ainda tiver. Devolve true se o erro deve ser perdoado.
local function forgive(state: StoreState): boolean
	if state.graceLeft > 0 then
		state.graceLeft -= 1
		return true
	end
	return false
end

-- Humano recusado ou assustado: menos clientes por um tempo (ou só um aviso, nos primeiros erros).
local function wrongHuman(state: StoreState, text: string)
	if forgive(state) then
		tell(state.owner, `{text} Careful next time!`, INFO)
		return
	end
	state.penaltyUntil = os.clock() + AnomalySettings.REFUSED_HUMAN_PENALTY_SECONDS
	tell(state.owner, `{text} Fewer people will come for a bit.`, BAD)
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
		flickerLights(state)
		if customer.tutorial or forgive(state) then
			tell(
				state.owner,
				`That was a {nameOf(customer)}! {clueOf(customer)} Refuse or capture it next time.`,
				INFO
			)
		else
			local maxLoss =
				math.max(100, Cells.totalIncome(state.owner) * AnomalySettings.BAD_SERVE_MAX_LOSS_SECONDS)
			local lost = Economy.takeFromSafe(state.owner, AnomalySettings.BAD_SERVE_SAFE_LOSS, maxLoss)
			floatingText(state.counter, "-" .. NumberFormat.cash(lost), BAD)
			tell(
				state.owner,
				`That was a {nameOf(customer)}! It took {NumberFormat.cash(lost)} from your safe. {clueOf(
					customer
				)}`,
				BAD
			)
		end
	else
		local multiplier = (if DayNight.isNight() then Settings.NIGHT_PRICE_MULTIPLIER else 1)
			* StoreUpgrades.priceMultiplier(state.owner)
		local amount = Economy.addToSafe(state.owner, customer.items * customer.price * multiplier)
		floatingText(state.counter, "+" .. NumberFormat.cash(amount), GOOD)
		state.sales += 1
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
		tell(state.owner, `Good call! That was a {nameOf(customer)}. {clueOf(customer)}`, GOOD)
	else
		wrongHuman(state, "That was a real customer...")
	end

	task.spawn(leave, state, customer)
end

local function capture(state: StoreState, customer: Customer)
	if customer.state == "Leaving" or customer.state == "Gone" then
		return
	end

	if not isAnomaly(customer) then
		wrongHuman(state, "You scared a real customer!")
		task.spawn(leave, state, customer)
		return
	end

	-- Primeira captura do tutorial sem sala dos fundos: a sala vem de presente, para ter onde guardar.
	if customer.tutorial and Cells.capacity(state.owner) == 0 then
		Builds.grant(state.owner, "Backroom")
		tell(state.owner, "Your first anomaly needs a home: the Back Room is on the house!", INFO)
	end

	if not Cells.tryAdd(state.owner, customer.kind, customer.variant) then
		tell(state.owner, "No free cell! Upgrade your cells or refuse it.", INFO)
		return
	end

	local data = Data.get(state.owner)
	if data then
		data.TotalCaptured += 1
	end
	tell(state.owner, `Captured: {nameOf(customer)}!`, GOOD)
	vanish(state, customer)
end

-- Botão "Capture" no próprio cliente, só para o dono da loja onde ele está. Só existe em quem chega de
-- madrugada (de dia não aparecem anomalias), menos a anomalia do tutorial.
local function addCapturePrompt(state: StoreState, customer: Customer)
	local root = customer.model.PrimaryPart
	if root == nil then
		return
	end
	local old = root:FindFirstChild("CapturePrompt")
	if old then
		old:Destroy()
	end
	if not (DayNight.isNight() or customer.tutorial) then
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
		if who == state.owner and (DayNight.isNight() or customer.tutorial) then
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
	customer.price = Settings.ITEM_PRICE * Shelves.priceMultiplier(shelf)
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
			if isAnomaly(customer) and customer.escapes == 0 and not customer.tutorial then
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
	local chance = if RunService:IsStudio() and studio > 0 then studio else AnomalySettings.NIGHT_CHANCE
	if DayNight.isRedMoon() then
		chance =
			math.min(chance * Config.RedMoon.ANOMALY_CHANCE_MULTIPLIER, Config.RedMoon.ANOMALY_CHANCE_MAX)
	end
	return chance
end

-- Jogador novo (sem nenhuma cela) que já cobrou alguns clientes de dia: hora da primeira anomalia.
local function wantsTutorialAnomaly(state: StoreState): boolean
	if state.tutorialDone or DayNight.isNight() then
		return false
	end
	if Cells.count(state.owner) > 0 then
		state.tutorialDone = true
		return false
	end
	return state.sales >= Config.Tutorial.SALES_BEFORE_ANOMALY
end

local function spawnCustomer(state: StoreState)
	local kind = HUMAN
	local variant = "Normal"
	local tutorial = false
	if wantsTutorialAnomaly(state) then
		kind = Config.Tutorial.ANOMALY
		tutorial = true
		state.tutorialDone = true
	elseif DayNight.isNight() and random:NextNumber() < anomalyChance() then
		kind = Anomalies.pickDefinition(random).id
		variant = Anomalies.pickVariant(
			random,
			if DayNight.isRedMoon() then Config.RedMoon.RARE_VARIANT_LUCK else nil
		).id
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
	CustomerModel.animate(model)

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
		price = Settings.ITEM_PRICE,
		state = "Shopping",
		escapes = 0,
		tutorial = tutorial,
	}
	table.insert(state.customers, customer)
	addCapturePrompt(state, customer)
	if tutorial then
		tell(
			state.owner,
			"A strange customer just walked in... look closely. Hold C on it to capture it!",
			INFO
		)
	end
	shop(state, customer)

	-- Se a do tutorial foi embora sem ser capturada, outra aparece depois de mais algumas vendas.
	if tutorial and Cells.count(state.owner) == 0 then
		state.tutorialDone = false
		state.sales = 0
	end
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
		nextSelfCheckoutAt = 0,
		penaltyUntil = 0,
		sales = 0,
		graceLeft = AnomalySettings.MISTAKE_GRACE,
		tutorialDone = false,
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

-- Self-checkout comprado: cobra sozinho o primeiro da fila se for humano. Anomalia trava a fila até o dono
-- decidir, então ainda vale ficar de olho no caixa.
local function selfCheckout(owner: Player, state: StoreState, now: number)
	local data = Data.get(owner)
	local interval = data and BuildCatalog.selfCheckoutInterval(data.Builds)
	if interval == nil or now < state.nextSelfCheckoutAt then
		return
	end
	state.nextSelfCheckoutAt = now + interval
	local first = state.queue[1]
	if first and not isAnomaly(first) then
		chargeOne(state)
	end
end

local function spawnLoop()
	while true do
		task.wait(0.5)
		local now = os.clock()
		local total = 0
		for _, state in stores do
			total += #state.customers
		end
		for owner, state in stores do
			if state.store.Parent == nil then
				stores[owner] = nil
			elseif
				now >= state.nextSpawnAt
				and #state.customers < Settings.MAX_IN_STORE
				and total < Settings.MAX_IN_SERVER
			then
				total += 1
				local interval = if DayNight.isNight() then Settings.NIGHT_INTERVAL else Settings.DAY_INTERVAL
				if now < state.penaltyUntil then
					interval *= 2
				end
				interval /= StoreUpgrades.customerRate(owner)
				state.nextSpawnAt = now + interval
				task.spawn(spawnCustomer, state)
			end
			selfCheckout(owner, state, now)
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

	Plots.onStoreReady(setupStore)
	Players.PlayerRemoving:Connect(function(player)
		stores[player] = nil
	end)

	task.spawn(spawnLoop)
end

return Customers
