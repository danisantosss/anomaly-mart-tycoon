--!strict
-- Eventos aleatórios do servidor (docs/V3.md, seção 10), como nos tycoons clássicos: de tempos em tempos
-- acontece alguma coisa na Avenida para todo mundo ao mesmo tempo. Ninguém paga nada por eles.
--
--   Cash Rain     moedas caem na rua; quem encosta pega (cada uma vale uns segundos da própria renda)
--   Golden Hour   os clientes pagam o dobro por um minuto
--   Rift Storm    a Fenda solta monstros 3x mais rápido
--   Stampede      uma manada de monstros sai da Fenda de uma vez
--   Supply Drop   uma caixa cai do céu num lugar da rua; o primeiro que abrir ganha 1 minuto de renda
--
-- O evento atual fica nos atributos "EventName" e "EventEndsAt" do ReplicatedStorage (a HUD mostra).
-- Não acontece evento durante a Invasão da Fenda.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local StreetMonsters = require(script.Parent.StreetMonsters)

local Settings = Config.Events
local GOLD = Color3.fromRGB(255, 210, 60)

local RandomEvents = {}

local notify: RemoteEvent
local random = Random.new()

-- Quanto vale `seconds` da renda atual do jogador (nunca menos que `minimum`).
local function incomeReward(player: Player, seconds: number, minimum: number): number
	local perSecond = player:GetAttribute("IncomePerSecond")
	local income = if typeof(perSecond) == "number" then perSecond else 0
	return math.max(minimum, math.floor(income * seconds))
end

local function randomStreetPoint(): Vector3
	return Vector3.new(
		random:NextNumber(Layout.RIFT_X + 20, Layout.DRAIN_X - 20),
		0,
		random:NextNumber(-Config.Street.ROAD_WIDTH / 2 + 3, Config.Street.ROAD_WIDTH / 2 - 3)
	)
end

local function coin(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "EventCoin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 2.4, 2.4)
	part.Color = GOLD
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	-- Moeda em pé (o eixo do cilindro fica deitado), virada para um lado qualquer.
	local facing = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	part.CFrame = CFrame.new(position + Vector3.new(0, 40, 0)) * facing
	part.Parent = workspace
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 8
	glow.Parent = part
	-- Cai do céu quicando no chão.
	TweenService:Create(part, TweenInfo.new(random:NextNumber(0.8, 1.6), Enum.EasingStyle.Bounce), {
		CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0)) * facing,
	}):Play()

	local taken = false
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player == nil or taken then
			return
		end
		taken = true
		local reward = incomeReward(player, Settings.CASH_RAIN_SECONDS_OF_INCOME, Settings.COIN_MIN)
		Economy.addCash(player, reward)
		Analytics.earn(player, reward, "Gameplay", "CashRain")
		Remotes.get("CashCollected"):FireClient(player, reward)
		part:Destroy()
	end)
	Debris:AddItem(part, Settings.DURATION_SECONDS)
end

local function supplyDrop()
	local position = randomStreetPoint()
	local crate = Instance.new("Part")
	crate.Name = "SupplyDrop"
	crate.Size = Vector3.new(5, 4, 5)
	crate.Color = Color3.fromRGB(70, 140, 255)
	crate.Material = Enum.Material.DiamondPlate
	crate.Anchored = true
	crate.CanCollide = true
	crate.Position = position + Vector3.new(0, 80, 0)
	crate.Parent = workspace
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(1, 120, 1)
	beacon.Color = Color3.fromRGB(120, 200, 255)
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.5
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Position = position + Vector3.new(0, 60, 0)
	beacon.Parent = crate
	TweenService:Create(crate, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = position + Vector3.new(0, 2, 0),
	}):Play()

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Supply Drop"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	prompt.Triggered:Connect(function(player)
		if crate.Parent == nil then
			return
		end
		crate:Destroy()
		local reward = incomeReward(player, Settings.SUPPLY_DROP_SECONDS_OF_INCOME, 1000)
		Economy.addCash(player, reward)
		Analytics.earn(player, reward, "Gameplay", "SupplyDrop")
		notify:FireAllClients(
			`{player.DisplayName} opened the Supply Drop: +{NumberFormat.cash(reward)}!`,
			GOLD
		)
	end)
	Debris:AddItem(crate, Settings.DURATION_SECONDS + 30)
end

type Event = {
	name: string,
	text: string, -- aviso no meio da tela
	run: () -> (), -- começa o evento
	stop: (() -> ())?, -- termina (se precisar desfazer algo)
}

local EVENTS: { Event } = {
	{
		name = "CASH RAIN",
		text = "CASH RAIN! Grab the coins on the street!",
		run = function()
			for _ = 1, Settings.CASH_RAIN_COINS do
				coin(randomStreetPoint())
				task.wait(0.15)
			end
		end,
	},
	{
		name = "GOLDEN HOUR",
		text = "GOLDEN HOUR! Customers pay double for 1 minute!",
		run = function()
			ReplicatedStorage:SetAttribute("GoldenHour", true)
		end,
		stop = function()
			ReplicatedStorage:SetAttribute("GoldenHour", nil)
		end,
	},
	{
		name = "RIFT STORM",
		text = "RIFT STORM! Monsters are pouring out of the Rift!",
		run = function()
			StreetMonsters.setSpawnBoost(Settings.RIFT_STORM_SPAWN)
		end,
		stop = function()
			StreetMonsters.setSpawnBoost(1)
		end,
	},
	{
		name = "STAMPEDE",
		text = "STAMPEDE! A herd of monsters just burst out of the Rift!",
		run = function()
			StreetMonsters.lootRain(Layout.RIFT_X + 30, Settings.STAMPEDE_COUNT, 1)
		end,
	},
	{
		name = "SUPPLY DROP",
		text = "SUPPLY DROP incoming! First one to open it gets the cash!",
		run = supplyDrop,
	},
}

local function play(event: Event)
	ReplicatedStorage:SetAttribute("EventName", event.name)
	ReplicatedStorage:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + Settings.DURATION_SECONDS)
	notify:FireAllClients(event.text, GOLD)
	task.spawn(event.run)
	task.wait(Settings.DURATION_SECONDS)
	if event.stop then
		event.stop()
	end
	ReplicatedStorage:SetAttribute("EventName", nil)
	ReplicatedStorage:SetAttribute("EventEndsAt", nil)
end

-- Começa um evento pelo nome (ou o primeiro da lista).
-- Para testar no Studio, NÃO dê require pela barra de comandos (isso cria outra cópia do módulo). Use:
--   workspace:SetAttribute("DebugEvent", "CASH RAIN")
function RandomEvents.trigger(name: string?)
	for _, event in EVENTS do
		if name == nil or event.name == name then
			task.spawn(play, event)
			return
		end
	end
end

function RandomEvents.start()
	notify = Remotes.get("Notify")
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("DebugEvent"):Connect(function()
			local name = workspace:GetAttribute("DebugEvent")
			if typeof(name) == "string" and name ~= "" then
				workspace:SetAttribute("DebugEvent", nil)
				RandomEvents.trigger(name)
			end
		end)
	end
	task.spawn(function()
		local last: Event? = nil
		while true do
			local range = if RunService:IsStudio()
				then Settings.STUDIO_EVERY_SECONDS
				else Settings.EVERY_SECONDS
			task.wait(random:NextNumber(range[1], range[2]))
			if #Players:GetPlayers() == 0 or ReplicatedStorage:GetAttribute("InvasionActive") == true then
				continue
			end
			-- Sorteia um evento diferente do anterior.
			local event = EVENTS[random:NextInteger(1, #EVENTS)]
			if event == last then
				event = EVENTS[(table.find(EVENTS, event) :: number) % #EVENTS + 1]
			end
			last = event
			play(event)
		end
	end)
end

return RandomEvents
