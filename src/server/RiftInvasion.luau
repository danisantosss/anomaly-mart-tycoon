--!strict
-- Invasão da Fenda (docs/V3.md, seção 7): o chefe cooperativo da Avenida.
--
-- Em algumas madrugadas (sempre na Lua Vermelha) a Fenda se abre de vez e sai o Colosso da Fenda, um monstro
-- gigante que anda devagar pela faixa até o Ralo. Enquanto ele está vivo, a renda de todo mundo cai 20%
-- (Economy.incomeMultiplier). Todo mundo pode chegar perto e apertar "Zap"
-- para tirar vida dele. De tempos em tempos ele ergue os braços e bate no chão: quem estiver perto fica uns
-- segundos sem conseguir dar Zap.
--
-- Se ele morrer antes do Ralo:
--   * quem ajudou ganha REWARD_SECONDS da própria renda (quem mais bateu ganha o dobro);
--   * caem LOOT_COUNT monstros com sorte extra onde ele morreu, para qualquer um capturar.
-- Se chegar no Ralo, ele some e ninguém ganha nada (mas também ninguém perde nada).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local DayNight = require(script.Parent.DayNight)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local Models = require(script.Parent.Monsters.Models)
local StreetMonsters = require(script.Parent.StreetMonsters)

local Settings = Config.RiftInvasion

local BOSS_KIND = "RiftColossus"
local BOSS_NAME = "RIFT COLOSSUS"
local BASE_HEIGHT = 7 -- altura da raiz no modelo sem escala (Models.luau)
local PURPLE = Color3.fromRGB(190, 90, 255)
local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 100, 100)

type Boss = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	health: number,
	maxHealth: number,
	hits: { [Player]: number },
	lastZap: { [Player]: number },
	stunnedUntil: { [Player]: number },
	bar: Frame,
	healthText: TextLabel,
	topText: TextLabel,
	alive: boolean,
}

local RiftInvasion = {}

local notify: RemoteEvent
local current: Boss? = nil
local random = Random.new()

local function setActive(value: boolean)
	ReplicatedStorage:SetAttribute("InvasionActive", value)
end

local function makeBillboard(boss: Boss)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BossBillboard"
	billboard.Size = UDim2.fromOffset(320, 84)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9 * Settings.SCALE, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 600
	billboard.Parent = boss.root

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.3)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = PURPLE
	title.TextStrokeTransparency = 0.2
	title.Text = BOSS_NAME
	title.Parent = billboard

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 0.28)
	back.Position = UDim2.fromScale(0, 0.32)
	back.BackgroundColor3 = Color3.fromRGB(25, 15, 35)
	back.BorderSizePixel = 0
	back.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = back

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(200, 60, 255)
	bar.BorderSizePixel = 0
	bar.Parent = back
	corner:Clone().Parent = bar

	local healthText = Instance.new("TextLabel")
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.FredokaOne
	healthText.TextScaled = true
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextStrokeTransparency = 0.3
	healthText.ZIndex = 2
	healthText.Parent = back

	local topText = title:Clone()
	topText.Size = UDim2.fromScale(1, 0.34)
	topText.Position = UDim2.fromScale(0, 0.64)
	topText.TextColor3 = Color3.fromRGB(255, 230, 140)
	topText.Text = "Press Zap to fight it together!"
	topText.Parent = billboard

	boss.bar = bar
	boss.healthText = healthText
	boss.topText = topText
end

local function refreshBillboard(boss: Boss)
	boss.bar.Size = UDim2.fromScale(math.clamp(boss.health / boss.maxHealth, 0, 1), 1)
	boss.healthText.Text = `{math.ceil(boss.health)} / {boss.maxHealth}`
	local ranking = {}
	for player, hits in boss.hits do
		if player.Parent then
			table.insert(ranking, { name = player.DisplayName, hits = hits })
		end
	end
	table.sort(ranking, function(a, b)
		return a.hits > b.hits
	end)
	if #ranking > 0 then
		local parts = {}
		for index = 1, math.min(3, #ranking) do
			table.insert(parts, `{index}. {ranking[index].name} ({ranking[index].hits})`)
		end
		boss.topText.Text = table.concat(parts, "   ")
	end
end

-- Raio roxo da mão do jogador até o Colosso, só para dar a sensação de acerto.
local function zapBeam(player: Player, boss: Boss)
	local character = player.Character
	local hand = character
		and (character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart"))
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	local from = Instance.new("Attachment")
	from.Parent = hand
	local to = Instance.new("Attachment")
	to.Position = Vector3.new(random:NextNumber(-3, 3), random:NextNumber(-2, 4), 0)
	to.Parent = boss.root
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(Color3.fromRGB(150, 255, 255), PURPLE)
	beam.LightEmission = 1
	beam.Width0 = 0.4
	beam.Width1 = 1.2
	beam.CurveSize0 = random:NextNumber(-4, 4)
	beam.FaceCamera = true
	beam.Parent = hand
	Debris:AddItem(beam, 0.15)
	Debris:AddItem(from, 0.15)
	Debris:AddItem(to, 0.15)
end

-- Onda de choque no chão quando ele bate.
local function shockwave(position: Vector3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = PURPLE
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.4, 4, 4)
	ring.CFrame = CFrame.new(position.X, 0.3, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local diameter = Settings.SLAM_RADIUS * 2
	TweenService:Create(
		ring,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.4, diameter, diameter), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.6)
end

local function slam(boss: Boss)
	-- O cliente ergue os braços 1 s antes da batida (MonsterAnimator.luau): dá tempo de fugir.
	boss.model:SetAttribute("SlamAt", workspace:GetServerTimeNow() + 1)
	task.wait(1)
	if not boss.alive then
		return
	end
	local center = boss.root.Position
	shockwave(center)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			if flat.Magnitude <= Settings.SLAM_RADIUS then
				boss.stunnedUntil[player] = now + Settings.SLAM_STUN_SECONDS
				notify:FireClient(
					player,
					"SLAMMED! You're dazed for a moment. Back off when it raises its arms!",
					BAD
				)
			end
		end
	end
end

local function finish(boss: Boss, defeated: boolean)
	if not boss.alive then
		return
	end
	boss.alive = false
	current = nil
	setActive(false)
	local position = boss.root.Position

	if defeated then
		notify:FireAllClients(`The {BOSS_NAME} has been defeated! Monsters are spilling out!`, GOOD)
		-- Prêmio para quem ajudou; quem mais bateu ganha o dobro.
		local mvp: Player? = nil
		local best = 0
		for player, hits in boss.hits do
			if hits > best and player.Parent then
				mvp, best = player, hits
			end
		end
		for player, hits in boss.hits do
			if player.Parent == nil or hits < Settings.MIN_HITS then
				continue
			end
			local perSecond = player:GetAttribute("IncomePerSecond")
			local income = if typeof(perSecond) == "number" then perSecond else 0
			local reward = math.max(Settings.REWARD_MIN, math.floor(income * Settings.REWARD_SECONDS))
			if player == mvp then
				reward *= Settings.MVP_MULTIPLIER
			end
			Economy.addCash(player, reward)
			Analytics.earn(player, reward, "Gameplay", "RiftInvasion")
			notify:FireClient(
				player,
				if player == mvp
					then `MVP! You hit it the most: +{NumberFormat.cash(reward)}`
					else `Invasion reward: +{NumberFormat.cash(reward)}`,
				GOOD
			)
		end
		if mvp then
			notify:FireAllClients(
				`{mvp.DisplayName} was the MVP of the invasion!`,
				Color3.fromRGB(255, 220, 90)
			)
		end
		StreetMonsters.lootRain(position.X, Settings.LOOT_COUNT, Settings.LOOT_LUCK)
	else
		notify:FireAllClients(`The {BOSS_NAME} escaped into the Containment Drain...`, BAD)
	end

	-- Afunda girando, igual aos monstros que chegam no Ralo.
	local model = boss.model
	boss.root.Anchored = true
	local start = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(alpha)
		if model.Parent then
			model:PivotTo(start * CFrame.new(0, -alpha * 25, 0) * CFrame.Angles(0, alpha * math.pi * 2, 0))
		end
	end)
	local tween =
		TweenService:Create(value, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Value = 1,
		})
	tween.Completed:Connect(function()
		value:Destroy()
		model:Destroy()
	end)
	tween:Play()
end

-- `amount` e `maxDistance` mudam no golpe do bastão (RiftInvasion.hit); o botão Zap usa os padrões.
local function onZap(boss: Boss, player: Player, amount: number?, maxDistance: number?): boolean
	if not boss.alive then
		return false
	end
	local now = os.clock()
	if now - (boss.lastZap[player] or 0) < Settings.ZAP_COOLDOWN then
		return false
	end
	if now < (boss.stunnedUntil[player] or 0) then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local flat =
		Vector3.new(root.Position.X - boss.root.Position.X, 0, root.Position.Z - boss.root.Position.Z)
	if flat.Magnitude > (maxDistance or Settings.ZAP_DISTANCE + 6) then
		return false
	end
	local dealt = amount or Settings.ZAP_DAMAGE
	boss.lastZap[player] = now
	boss.hits[player] = (boss.hits[player] or 0) + dealt
	boss.health -= dealt
	zapBeam(player, boss)
	refreshBillboard(boss)
	if boss.health <= 0 then
		finish(boss, true)
	end
	return true
end

-- Golpe do bastão de choque (Weapons.luau): só vale de perto. Devolve true se acertou o Colosso.
function RiftInvasion.hit(player: Player, amount: number): boolean
	local boss = current
	if boss == nil then
		return false
	end
	return onZap(boss, player, amount, 9 * Settings.SCALE)
end

local function walk(boss: Boss)
	local step = 20
	local x = boss.root.Position.X
	while boss.alive and x < Layout.DRAIN_X do
		x = math.min(x + step, Layout.DRAIN_X)
		boss.humanoid:MoveTo(Vector3.new(x, 0, 0))
		local deadline = os.clock() + step / Settings.WALK_SPEED + 4
		while boss.alive and os.clock() < deadline and math.abs(boss.root.Position.X - x) > 2 do
			task.wait(0.25)
		end
	end
	finish(boss, false)
end

local function spawnBoss()
	local playerCount = #Players:GetPlayers()
	if playerCount == 0 or current then
		return
	end
	local model = Models.build(BOSS_KIND, "Normal", true)
	model:ScaleTo(Settings.SCALE)
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.HipHeight = (BASE_HEIGHT - 1) * Settings.SCALE
	humanoid.WalkSpeed = Settings.WALK_SPEED
	model:PivotTo(
		CFrame.lookAt(
			Vector3.new(Layout.RIFT_X, humanoid.HipHeight + 1 * Settings.SCALE, 0),
			Vector3.new(Layout.DRAIN_X, humanoid.HipHeight + 1 * Settings.SCALE, 0)
		)
	)
	model.Parent = workspace

	local maxHealth = Settings.HEALTH_BASE + Settings.HEALTH_PER_EXTRA_PLAYER * (playerCount - 1)
	local boss: Boss = {
		model = model,
		root = root,
		humanoid = humanoid,
		health = maxHealth,
		maxHealth = maxHealth,
		hits = {},
		lastZap = {},
		stunnedUntil = {},
		bar = nil :: any,
		healthText = nil :: any,
		topText = nil :: any,
		alive = true,
	}
	makeBillboard(boss)
	refreshBillboard(boss)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZapPrompt"
	prompt.ActionText = "Zap!"
	prompt.ObjectText = "Rift Colossus"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Settings.ZAP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		onZap(boss, player)
	end)

	root:SetNetworkOwner(nil)
	current = boss
	setActive(true)
	local burst = workspace:FindFirstChild("RiftBurst", true)
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(80)
	end
	notify:FireAllClients(
		`The {BOSS_NAME} broke through! Press F near it to Zap it before it reaches the Drain! (-20% income while it lives)`,
		PURPLE
	)

	task.spawn(walk, boss)
	task.spawn(function()
		while boss.alive do
			task.wait(Settings.SLAM_EVERY_SECONDS)
			if boss.alive then
				slam(boss)
			end
		end
	end)
end

-- Avisa, espera e solta o Colosso.
function RiftInvasion.begin()
	if current then
		return
	end
	notify:FireAllClients("The Rift is tearing open... something HUGE is coming!", PURPLE)
	task.wait(Settings.WARNING_SECONDS)
	if DayNight.isNight() then
		spawnBoss()
	end
end

local function nightChance(): number
	if DayNight.isRedMoon() then
		return 1
	end
	return if RunService:IsStudio() then Settings.STUDIO_NIGHT_CHANCE else Settings.NIGHT_CHANCE
end

-- Precisa rodar depois de DayNight e StreetMonsters.
function RiftInvasion.start()
	notify = Remotes.get("Notify")
	setActive(false)
	DayNight.onPhaseChanged(function(phase)
		if phase ~= "Night" or random:NextNumber() >= nightChance() then
			return
		end
		task.wait(Settings.DELAY_SECONDS)
		if DayNight.isNight() then
			RiftInvasion.begin()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local boss = current
		if boss then
			boss.hits[player] = nil
			boss.lastZap[player] = nil
			boss.stunnedUntil[player] = nil
		end
	end)
end

return RiftInvasion
