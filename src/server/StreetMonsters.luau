--!strict
-- Monstros da rua (docs/V3.md, seção 3).
--
-- De tempos em tempos um monstro sai da Fenda (ponta oeste da Avenida) e anda pela faixa roxa até o Ralo de
-- Contenção (ponta leste), onde some. Cada um mostra o nome, a raridade, quanto rende e quanto custa.
-- Qualquer jogador pode segurar C perto dele para capturar: paga o preço, e o monstro corre sozinho até a
-- sala dos fundos de quem pagou e entra numa cela. É a mesma ideia de comprar unidades que passam no meio do
-- mapa dos tycoons de "Steal", com o nosso tema.
--
-- Regras:
--   * só captura quem tem cela livre (contando os monstros que ainda estão a caminho);
--   * se a cela não existir mais quando ele chegar (Franquia no meio do caminho), o dinheiro volta;
--   * se o jogador sair, o monstro some (o dinheiro já foi gasto, como numa compra normal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Cells = require(script.Parent.Cells)
local Data = require(script.Parent.Data)
local DayNight = require(script.Parent.DayNight)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local Models = require(script.Parent.Monsters.Models)
local Plots = require(script.Parent.Plots)

local Settings = Config.StreetMonsters

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 100, 100)
local INFO = Color3.fromRGB(255, 230, 140)

type Wanderer = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	variant: string,
	lane: number, -- deslocamento em Z dentro da faixa
	claimedBy: Player?,
	status: TextLabel,
	tag: TextLabel, -- linha de cima do letreiro (raridade, ou "LURED BY ...")
	reservedFor: Player?, -- Isca da Fenda: só este jogador captura até `reservedUntil`
	reservedUntil: number,
	rarityText: string,
	rarityColor: Color3,
	-- Combate (Config.Combat): jeito de agir, vida e nocaute.
	behavior: Behavior,
	health: number,
	maxHealth: number, -- 0 = passivo: dá para capturar sem nocautear
	ko: boolean,
	koVersion: number, -- muda a cada nocaute, para o "acordar" atrasado não valer depois de outro nocaute
	lastAttack: number,
	standY: number, -- altura da raiz em pé
	prompt: ProximityPrompt,
	healthBar: Frame?,
}

type Behavior = {
	mode: string,
	speed: number,
	health: number?,
	damage: number?,
	aggro: number?,
	aura: number?,
}

local Combat = Config.Combat
local BEHAVIORS = Combat.BEHAVIORS :: { [string]: Behavior }
local KO_COLOR = Color3.fromRGB(255, 220, 90)

-- Isca da Fenda (RiftLure.luau): monstro escolhido e pago com Robux, que sai do bueiro mais perto da loja.
type Lure = {
	kind: string,
	manhole: number,
	player: Player,
}

local StreetMonsters = {}

local wanderers: { Wanderer } = {}
local pending: { [Player]: number } = {} -- monstros pagos ainda a caminho, por jogador
local random = Random.new()
local folder: Folder
local notify: RemoteEvent
local paused = false -- durante a Invasão da Fenda não sai monstro novo
local spawnBoost = 1 -- evento Rift Storm (RandomEvents.luau): monstros saem mais rápido

local function tell(player: Player, text: string, color: Color3)
	if player.Parent == Players then
		notify:FireClient(player, text, color)
	end
end

local function remove(wanderer: Wanderer)
	local index = table.find(wanderers, wanderer)
	if index then
		table.remove(wanderers, index)
	end
	if wanderer.model.Parent then
		wanderer.model:Destroy()
	end
end

-- Some afundando e encolhendo (no Ralo ou ao entrar na cela).
local function vanish(wanderer: Wanderer)
	local index = table.find(wanderers, wanderer)
	if index then
		table.remove(wanderers, index)
	end
	local model = wanderer.model
	if model.Parent == nil then
		return
	end
	wanderer.root.Anchored = true
	local start = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(alpha)
		if model.Parent then
			model:PivotTo(start * CFrame.new(0, -alpha * 6, 0) * CFrame.Angles(0, alpha * math.pi * 3, 0))
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		value:Destroy()
		model:Destroy()
	end)
	tween:Play()
end

local function makeBillboard(wanderer: Wanderer, height: number): (TextLabel, TextLabel)
	local definition = Anomalies.get(wanderer.kind)
	local rarity = if definition then definition.rarity else "Common"
	local color = Anomalies.RARITY_COLORS[rarity]

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.fromOffset(220, 86)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height + 1.5, 0)
	billboard.MaxDistance = 110
	billboard.LightInfluence = 0
	billboard.Parent = wanderer.root

	local function line(text: string, order: number, textColor: Color3, scale: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, scale)
		label.Position = UDim2.fromScale(0, order)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = textColor
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = billboard
		return label
	end

	local tag = line(string.upper(rarity), 0, color, 0.2)
	line(Anomalies.fullName(wanderer.kind, wanderer.variant), 0.2, Color3.new(1, 1, 1), 0.3)
	line(`{NumberFormat.cash(Anomalies.income(wanderer.kind, wanderer.variant))}/s`, 0.5, GOOD, 0.22)
	local price =
		line(NumberFormat.cash(Anomalies.captureCost(wanderer.kind, wanderer.variant)), 0.72, INFO, 0.26)
	return price, tag
end

local function freeCells(player: Player): number
	return Cells.capacity(player) - Cells.count(player) - (pending[player] or 0)
end

-- Corre até a sala dos fundos de quem pagou e entra numa cela.
local function deliver(wanderer: Wanderer, player: Player, cost: number)
	local humanoid = wanderer.humanoid
	humanoid.WalkSpeed = Settings.DELIVERY_SPEED

	local arrived = false
	for _ = 1, 30 do
		local origin = Plots.getOrigin(player)
		if origin == nil or player.Parent ~= Players or wanderer.model.Parent == nil then
			break
		end
		local target = origin:PointToWorldSpace(Layout.backroomCenter())
		if (wanderer.root.Position * Vector3.new(1, 0, 1) - target * Vector3.new(1, 0, 1)).Magnitude < 4 then
			arrived = true
			break
		end
		humanoid:MoveTo(target)
		task.wait(0.5)
	end

	pending[player] = math.max(0, (pending[player] or 1) - 1)
	if not arrived or player.Parent ~= Players then
		remove(wanderer)
		return
	end
	if Cells.tryAdd(player, wanderer.kind, wanderer.variant) then
		local data = Data.get(player)
		if data then
			data.TotalCaptured += 1
		end
		tell(player, `{Anomalies.fullName(wanderer.kind, wanderer.variant)} is in your cell!`, GOOD)
		Analytics.step(player, "FirstCapture")
	else
		Economy.addCash(player, cost)
		tell(player, "No free cell when it arrived. Your money was returned.", INFO)
	end
	vanish(wanderer)
end

local standUp: (Wanderer) -> () -- definida mais abaixo, junto do nocaute

local function capture(wanderer: Wanderer, player: Player)
	if wanderer.claimedBy ~= nil or wanderer.model.Parent == nil then
		return
	end
	if Plots.getStore(player) == nil or Data.get(player) == nil then
		return
	end
	if wanderer.maxHealth > 0 and not wanderer.ko then
		tell(player, "It's too dangerous! Knock it out with your Shock Baton first.", BAD)
		return
	end
	local reservedFor = wanderer.reservedFor
	if reservedFor and reservedFor ~= player and reservedFor.Parent == Players then
		local left = math.ceil(wanderer.reservedUntil - os.clock())
		if left > 0 then
			tell(player, `{reservedFor.DisplayName} lured this one. It's theirs for {left}s more!`, INFO)
			return
		end
	end
	if Cells.capacity(player) == 0 then
		tell(player, "Build the Back Room first: monsters need a cell!", INFO)
		return
	end
	if freeCells(player) <= 0 then
		tell(player, "All your cells are full! Buy more cells.", INFO)
		return
	end
	local cost = Anomalies.captureCost(wanderer.kind, wanderer.variant)
	if not Economy.trySpend(player, cost) then
		tell(player, `You need {NumberFormat.cash(cost)} to capture it. Collect your safe!`, BAD)
		return
	end

	wanderer.claimedBy = player
	standUp(wanderer)
	pending[player] = (pending[player] or 0) + 1
	Analytics.spend(player, cost, "Shop", `Monster_{wanderer.kind}_{wanderer.variant}`)
	local prompt = wanderer.root:FindFirstChild("CapturePrompt")
	if prompt then
		prompt:Destroy()
	end
	wanderer.status.Text = `→ {player.DisplayName}`
	wanderer.status.TextColor3 = GOOD
	tell(
		player,
		`Captured {Anomalies.fullName(wanderer.kind, wanderer.variant)}! It's running to your Back Room.`,
		GOOD
	)
	task.spawn(deliver, wanderer, player, cost)
end

-- Jogador vivo mais perto de `position` dentro de `range` (só quem está na rua ou na calçada).
local function nearestPlayer(position: Vector3, range: number): (Player?, Humanoid?, BasePart?, number)
	local best: Player?, bestHumanoid: Humanoid?, bestRoot: BasePart?, bestDistance = nil, nil, nil, range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			if math.abs(root.Position.Z) <= Combat.LEASH_Z + 8 then
				local offset = root.Position - position
				local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if distance <= bestDistance then
					best, bestHumanoid, bestRoot, bestDistance = player, humanoid, root, distance
				end
			end
		end
	end
	return best, bestHumanoid, bestRoot, bestDistance
end

-- Mantém o destino dentro da rua (não entra nas lojas nem passa da Fenda/Ralo).
local function clampToStreet(position: Vector3): Vector3
	return Vector3.new(
		math.clamp(position.X, Layout.RIFT_X + 4, Layout.DRAIN_X),
		0,
		math.clamp(position.Z, -Combat.LEASH_Z, Combat.LEASH_Z)
	)
end

local function reach(wanderer: Wanderer): number
	local _, size = wanderer.model:GetBoundingBox()
	return Combat.ATTACK_RANGE + math.max(size.X, size.Z) / 2
end

-- Ataca um jogador: o cliente anima o bote (atributo "AttackAt") e o servidor tira vida.
-- TakeDamage respeita o ForceField de quem acabou de nascer.
local function attack(wanderer: Wanderer, humanoid: Humanoid, damage: number)
	wanderer.lastAttack = os.clock()
	wanderer.model:SetAttribute("AttackAt", workspace:GetServerTimeNow())
	humanoid:TakeDamage(damage)
end

local function updateHealthBar(wanderer: Wanderer)
	local bar = wanderer.healthBar
	if bar then
		local fraction = math.clamp(wanderer.health / math.max(wanderer.maxHealth, 1), 0, 1)
		bar.Size = UDim2.fromScale(fraction, 1)
		bar.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(90, 255, 120), fraction)
	end
end

local function makeHealthBar(wanderer: Wanderer, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Health"
	billboard.Size = UDim2.fromOffset(110, 10)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height + 0.6, 0)
	billboard.MaxDistance = 110
	billboard.Parent = wanderer.root
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 25)
	back.BorderSizePixel = 0
	back.Parent = billboard
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.Parent = back
	wanderer.healthBar = bar
	updateHealthBar(wanderer)
end

-- Levanta (fim do nocaute ou capturado nocauteado). Volta a ser empurrado pelo Humanoid.
function standUp(wanderer: Wanderer)
	if not wanderer.ko then
		return
	end
	wanderer.ko = false
	wanderer.model:SetAttribute("KO", nil)
	local stars = wanderer.root:FindFirstChild("KOStars")
	if stars then
		stars:Destroy()
	end
	local position = wanderer.root.Position
	wanderer.model:PivotTo(
		CFrame.lookAt(
			Vector3.new(position.X, wanderer.standY, position.Z),
			Vector3.new(position.X + 10, wanderer.standY, position.Z)
		)
	)
	wanderer.root.Anchored = false
	wanderer.root:SetNetworkOwner(nil)
end

-- Nocaute: cai de lado, solta estrelinhas e libera a captura por Combat.KO_SECONDS.
local function knockOut(wanderer: Wanderer, by: Player)
	wanderer.ko = true
	wanderer.koVersion += 1
	local version = wanderer.koVersion
	local model = wanderer.model
	model:SetAttribute("KO", true)
	wanderer.root.Anchored = true
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(80)))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, 0.1 - (box.Position.Y - size.Y / 2), 0))

	local stars = Instance.new("ParticleEmitter")
	stars.Name = "KOStars"
	stars.Color = ColorSequence.new(KO_COLOR)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(0.6, 0)
	stars.Lifetime = NumberRange.new(0.8, 1.2)
	stars.Rate = 10
	stars.Speed = NumberRange.new(2, 4)
	stars.SpreadAngle = Vector2.new(60, 60)
	stars.Parent = wanderer.root

	wanderer.prompt.Enabled = true
	wanderer.tag.Text = "KNOCKED OUT!"
	wanderer.tag.TextColor3 = KO_COLOR
	tell(by, `Knocked out! Hold C to capture it before it wakes up ({Combat.KO_SECONDS}s).`, GOOD)

	task.delay(Combat.KO_SECONDS, function()
		if wanderer.ko and wanderer.koVersion == version and wanderer.claimedBy == nil and model.Parent then
			standUp(wanderer)
			wanderer.health = wanderer.maxHealth
			updateHealthBar(wanderer)
			wanderer.prompt.Enabled = false
			wanderer.tag.Text = wanderer.rarityText
			wanderer.tag.TextColor3 = wanderer.rarityColor
		end
	end)
end

local function damage(wanderer: Wanderer, by: Player, amount: number)
	if wanderer.maxHealth <= 0 or wanderer.ko or wanderer.claimedBy then
		return
	end
	wanderer.health -= amount
	wanderer.model:SetAttribute("HitAt", workspace:GetServerTimeNow())
	updateHealthBar(wanderer)
	if wanderer.health <= 0 then
		knockOut(wanderer, by)
	end
end

-- "Cérebro" do monstro: decide para onde ir a cada 0,3 s conforme o jeito dele (Config.Combat.BEHAVIORS).
-- Sem ninguém perto, todos andam em zigue-zague até o Ralo e somem lá.
local function brain(wanderer: Wanderer)
	local behavior = wanderer.behavior
	local humanoid = wanderer.humanoid
	local goal = wanderer.root.Position
	local pauseUntil = 0
	local chaseStarted = 0
	local lastBlink = os.clock()
	local lastAura = 0
	local bornAt = os.clock()

	while wanderer.model.Parent and wanderer.claimedBy == nil do
		task.wait(0.3)
		if wanderer.claimedBy or wanderer.model.Parent == nil then
			break
		end
		if wanderer.ko or wanderer.root.Anchored then
			continue -- nocauteado ou ainda subindo do bueiro
		end
		local position = wanderer.root.Position
		local now = os.clock()
		if position.X >= Layout.DRAIN_X - 3 or now - bornAt > 360 then
			break
		end

		-- Água-viva: dá choque em quem está perto, sem precisar ir atrás.
		if behavior.aura and now - lastAura >= Combat.AURA_EVERY_SECONDS then
			lastAura = now
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local victim = character and character:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and victim and victim.Health > 0 then
					if (root.Position - position).Magnitude <= behavior.aura then
						attack(wanderer, victim, behavior.damage or 5)
					end
				end
			end
		end

		local moved = false
		local target, victim, targetRoot, distance = nearestPlayer(position, behavior.aggro or 0)
		if target == nil then
			chaseStarted = 0
		elseif chaseStarted == 0 or now - chaseStarted > Combat.CHASE_GIVE_UP_SECONDS + 4 then
			chaseStarted = now -- começa (ou recomeça, depois de um descanso) a perseguição
		end
		local chasing = target ~= nil and now - chaseStarted < Combat.CHASE_GIVE_UP_SECONDS
		local mode = behavior.mode

		if chasing and targetRoot and victim and (mode == "Hunt" or mode == "Ambush" or mode == "Blink") then
			if mode == "Blink" and now - lastBlink >= Combat.BLINK_EVERY_SECONDS then
				-- Some e aparece atrás do jogador.
				lastBlink = now
				local behind = clampToStreet((targetRoot.CFrame * CFrame.new(0, 0, 6)).Position)
				local look = Vector3.new(targetRoot.Position.X, wanderer.standY, targetRoot.Position.Z)
				wanderer.model:PivotTo(CFrame.lookAt(Vector3.new(behind.X, wanderer.standY, behind.Z), look))
				tell(target :: Player, "Something is right behind you...", BAD)
				wanderer.lastAttack = now - Combat.ATTACK_COOLDOWN + 0.8 -- dá 0,8 s para fugir
			end
			humanoid.WalkSpeed = behavior.speed
			humanoid:MoveTo(clampToStreet(targetRoot.Position))
			moved = true
			if distance <= reach(wanderer) and now - wanderer.lastAttack >= Combat.ATTACK_COOLDOWN then
				attack(wanderer, victim, behavior.damage or 10)
			end
		elseif target and targetRoot and mode == "Flee" then
			local away = position - targetRoot.Position
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude < 0.1 then
				away = Vector3.new(1, 0, 0)
			end
			humanoid.WalkSpeed = behavior.speed
			humanoid:MoveTo(clampToStreet(position + away.Unit * 14))
			moved = true
		elseif mode == "Ambush" and target == nil and random:NextNumber() < 0.8 then
			-- Fingindo ser uma caixa: fica parado quase o tempo todo.
			humanoid:MoveTo(position)
			moved = true
		end

		if not moved then
			if now < pauseUntil then
				continue
			end
			local flat = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
			if flat.Magnitude < 3 or humanoid.MoveDirection.Magnitude < 0.05 then
				-- Próximo ponto do zigue-zague, um pouco à frente e de um lado da faixa.
				local x = math.min(position.X + random:NextNumber(10, 22), Layout.DRAIN_X)
				local z = random:NextNumber(-Layout.LANE_HALF_WIDTH + 1, Layout.LANE_HALF_WIDTH - 1)
				goal = Vector3.new(x, 0, z)
				if mode == "Wander" and random:NextNumber() < 0.25 then
					pauseUntil = now + random:NextNumber(1, 2.5) -- para e olha em volta
					humanoid:MoveTo(position)
					continue
				end
			end
			humanoid.WalkSpeed = if mode == "Wander" then behavior.speed else Settings.WALK_SPEED
			humanoid:MoveTo(goal)
		end
	end
	if wanderer.claimedBy == nil and wanderer.model.Parent then
		vanish(wanderer)
	end
end

-- Bastão de choque (Weapons.luau): acerta o monstro mais perto à frente de `origin`. Devolve true se acertou.
function StreetMonsters.hit(player: Player, origin: CFrame, range: number, amount: number): boolean
	local best: Wanderer?, bestDistance = nil, math.huge
	for _, wanderer in wanderers do
		if
			wanderer.maxHealth > 0
			and not wanderer.ko
			and wanderer.claimedBy == nil
			and wanderer.model.Parent
		then
			local _, size = wanderer.model:GetBoundingBox()
			local offset = wanderer.root.Position - origin.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude - math.max(size.X, size.Z) / 2
			local look = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
			local inFront = flat.Magnitude < 3 or look.Magnitude < 0.01 or flat.Unit:Dot(look.Unit) > 0.2
			if distance <= range and inFront and distance < bestDistance then
				best, bestDistance = wanderer, distance
			end
		end
	end
	if best == nil then
		return false
	end
	damage(best, player, amount)
	return true
end

local function luck(): (number, number)
	if DayNight.isRedMoon() then
		return Settings.LUCK_RED_MOON, Config.RedMoon.RARE_VARIANT_LUCK
	elseif DayNight.isNight() then
		return Settings.LUCK_NIGHT, Settings.VARIANT_LUCK_NIGHT
	end
	return 1, 1
end

-- `boost` multiplica a sorte de raridade; `force` ignora o limite de monstros na rua (chuva de monstros
-- depois da Invasão da Fenda).
-- `lure` = monstro chamado pela Isca da Fenda: tipo escolhido, variante normal, sai do bueiro dado.
local function spawnOne(startX: number?, boost: number?, force: boolean?, lure: Lure?)
	if #wanderers >= Settings.MAX_ON_STREET and not force then
		return
	end
	local rarityLuck, variantLuck = luck()
	rarityLuck *= boost or 1
	local definition = if lure
		then Anomalies.get(lure.kind) :: Anomalies.Definition
		else Anomalies.pickStreet(random, rarityLuck)
	local variant = if lure then "Normal" else Anomalies.pickVariant(random, variantLuck).id

	local model = Models.build(definition.id, variant, true)
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Settings.WALK_SPEED
	local behavior = BEHAVIORS[definition.id] or { mode = "Wander", speed = Settings.WALK_SPEED }
	local maxHealth = (behavior.health or 0) * (if variant == "Giant" then Combat.GIANT_HEALTH else 1)
	local lane = random:NextNumber(-Layout.LANE_HALF_WIDTH + 1.5, Layout.LANE_HALF_WIDTH - 1.5)

	-- Mede a altura antes de mover, para o letreiro ficar logo acima da cabeça.
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2 - root.Position.Y
	-- De onde sai: posição dada (monstros iniciais), um bueiro no meio da rua ou a Fenda.
	local manhole: number? = if lure then lure.manhole else nil
	if startX == nil and manhole == nil and random:NextNumber() < Settings.MANHOLE_CHANCE then
		manhole = random:NextInteger(1, #Layout.MANHOLES)
	end
	local x = startX or (if manhole then Layout.MANHOLES[manhole] else Layout.RIFT_X)
	local z = if manhole then 0 else lane
	local standing =
		CFrame.lookAt(Vector3.new(x, root.Position.Y, z), Vector3.new(x + 10, root.Position.Y, z))
	if manhole then
		-- Sobe do bueiro: começa enterrado e ancorado, e o tween levanta até a altura normal.
		root.Anchored = true
		model:PivotTo(standing * CFrame.new(0, -root.Position.Y - 4, 0))
	else
		model:PivotTo(standing)
	end
	model.Parent = folder

	local wanderer: Wanderer = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = definition.id,
		variant = variant,
		lane = lane,
		claimedBy = nil,
		status = nil :: any,
		tag = nil :: any,
		reservedFor = if lure then lure.player else nil,
		reservedUntil = os.clock() + Config.RiftLure.RESERVE_SECONDS,
		rarityText = "",
		rarityColor = Color3.new(1, 1, 1),
		behavior = behavior,
		health = maxHealth,
		maxHealth = maxHealth,
		ko = false,
		koVersion = 0,
		lastAttack = 0,
		standY = standing.Position.Y,
		prompt = nil :: any,
		healthBar = nil,
	}
	wanderer.status, wanderer.tag = makeBillboard(wanderer, top)
	wanderer.rarityText, wanderer.rarityColor = wanderer.tag.Text, wanderer.tag.TextColor3
	if maxHealth > 0 then
		makeHealthBar(wanderer, top)
	end
	if lure then
		-- Mostra de quem é a reserva e volta a mostrar a raridade quando ela acaba.
		local rarityText, rarityColor = wanderer.tag.Text, wanderer.tag.TextColor3
		wanderer.tag.Text = `LURED BY {string.upper(lure.player.DisplayName)}`
		wanderer.tag.TextColor3 = Color3.fromRGB(255, 220, 90)
		task.delay(Config.RiftLure.RESERVE_SECONDS, function()
			if wanderer.claimedBy == nil and wanderer.model.Parent and not wanderer.ko then
				wanderer.tag.Text = rarityText
				wanderer.tag.TextColor3 = rarityColor
			end
		end)
	end
	table.insert(wanderers, wanderer)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CapturePrompt"
	prompt.ActionText = "Capture"
	prompt.ObjectText = NumberFormat.cash(Anomalies.captureCost(definition.id, variant))
	prompt.KeyboardKeyCode = Enum.KeyCode.C
	prompt.HoldDuration = Settings.CAPTURE_HOLD_SECONDS
	prompt.MaxActivationDistance = 12 + boxSize.X / 2
	prompt.RequiresLineOfSight = false
	prompt.Enabled = maxHealth == 0 -- os ofensivos só liberam a captura nocauteados
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		capture(wanderer, player)
	end)
	wanderer.prompt = prompt

	-- Faísca no portal da Fenda.
	local street = workspace:FindFirstChild("Street")
	if manhole then
		local lid = street and street:FindFirstChild(`Manhole{manhole}`, true)
		local steam = lid and lid:FindFirstChild("Steam")
		if steam and steam:IsA("ParticleEmitter") then
			steam:Emit(40)
		end
	else
		local burst = street and street:FindFirstChild("RiftBurst", true)
		if startX == nil and burst and burst:IsA("ParticleEmitter") then
			burst:Emit(30)
		end
	end

	if lure then
		notify:FireAllClients(
			`{lure.player.DisplayName} lured a {definition.displayName} out of the sewer! It's theirs for {Config.RiftLure.RESERVE_SECONDS}s.`,
			Color3.fromRGB(255, 220, 90)
		)
	elseif Settings.ANNOUNCE[definition.rarity] then
		notify:FireAllClients(
			`A {string.upper(definition.rarity)} {Anomalies.fullName(definition.id, variant)} crawled out of the Rift!`,
			Anomalies.RARITY_COLORS[definition.rarity]
		)
	end

	humanoid.Died:Connect(function()
		remove(wanderer)
	end)
	task.spawn(function()
		if manhole then
			local start = model:GetPivot()
			local rise = Instance.new("NumberValue")
			rise.Changed:Connect(function(alpha)
				if model.Parent then
					model:PivotTo(start:Lerp(standing, alpha))
				end
			end)
			local tween = TweenService:Create(
				rise,
				TweenInfo.new(1.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Value = 1 }
			)
			tween:Play()
			tween.Completed:Wait()
			rise:Destroy()
			if model.Parent == nil then
				return
			end
			root.Anchored = false
		end
		root:SetNetworkOwner(nil) -- o servidor controla, sem engasgos
		brain(wanderer)
	end)
end

local function spawnInterval(): number
	local seconds = Settings.SPAWN_SECONDS_DAY
	if DayNight.isRedMoon() then
		seconds = Settings.SPAWN_SECONDS_RED_MOON
	elseif DayNight.isNight() then
		seconds = Settings.SPAWN_SECONDS_NIGHT
	end
	return seconds / spawnBoost
end

-- Multiplica a velocidade com que os monstros saem (1 = normal).
function StreetMonsters.setSpawnBoost(value: number)
	spawnBoost = math.max(value, 0.1)
end

-- Isca da Fenda: chama o monstro `kind` (variante normal) pelo bueiro mais perto da loja do jogador. Só ele
-- pode capturar nos primeiros Config.RiftLure.RESERVE_SECONDS. Devolve false se não deu para chamar.
function StreetMonsters.summon(player: Player, kind: string): boolean
	local origin = Plots.getOrigin(player)
	if origin == nil or Anomalies.get(kind) == nil then
		return false
	end
	local nearest, best = 1, math.huge
	for index, x in Layout.MANHOLES do
		local distance = math.abs(x - origin.Position.X)
		if distance < best then
			nearest, best = index, distance
		end
	end
	local ok, problem = pcall(spawnOne, nil, nil, true, { kind = kind, manhole = nearest, player = player })
	if not ok then
		warn(`[StreetMonsters] {problem}`)
	end
	return ok
end

-- Pausa (ou volta) a saída de monstros da Fenda.
function StreetMonsters.setPaused(value: boolean)
	paused = value
end

-- Solta `count` monstros com sorte extra ao redor de `x` (prêmio por derrotar o Colosso da Fenda).
function StreetMonsters.lootRain(x: number, count: number, boost: number)
	for index = 1, count do
		local startX = math.clamp(x + (index - (count + 1) / 2) * 6, Layout.RIFT_X + 6, Layout.DRAIN_X - 30)
		local ok, problem = pcall(spawnOne, startX, boost, true)
		if not ok then
			warn(`[StreetMonsters] {problem}`)
		end
	end
end

function StreetMonsters.start()
	notify = Remotes.get("Notify")
	folder = Instance.new("Folder")
	folder.Name = "StreetMonsters"
	folder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)

	task.spawn(function()
		-- Começa com alguns já andando, para a rua não estar vazia quando o primeiro jogador chega.
		local length = Layout.DRAIN_X - Layout.RIFT_X
		for index = 1, 6 do
			spawnOne(Layout.RIFT_X + length * (index - 0.5) / 7, 2.5) -- sorte extra: menos Gloop repetido
		end
		while true do
			task.wait(spawnInterval())
			if paused then
				continue
			end
			local ok, problem = pcall(spawnOne)
			if not ok then
				warn(`[StreetMonsters] {problem}`)
			end
		end
	end)
end

return StreetMonsters
