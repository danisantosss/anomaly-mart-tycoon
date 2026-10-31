--!strict
-- Compra e efeitos dos upgrades do terminal (docs/V2.md). O catálogo e os preços ficam em
-- Shared/Upgrades.luau; aqui o servidor valida a compra, salva o nível e aplica o efeito.
-- As funções de efeito também somam o que vem das partes compradas da loja (shared/Builds.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Plots = require(script.Parent.Plots)
local Shelves = require(script.Parent.Shelves)

local Effects = Config.UpgradeEffects

local StoreUpgrades = {}

local notify: RemoteEvent

function StoreUpgrades.level(player: Player, id: string): number
	local data = Data.get(player)
	return if data then data.Upgrades[id] or 0 else 0
end

function StoreUpgrades.walkSpeed(player: Player): number
	return Config.Steal.NORMAL_SPEED
		+ StoreUpgrades.level(player, "Sneakers") * Effects.SNEAKERS_SPEED_PER_LEVEL
end

function StoreUpgrades.captureHoldSeconds(player: Player): number
	local hold = Config.Anomalies.CAPTURE_HOLD_SECONDS
		- StoreUpgrades.level(player, "Flashlight") * Effects.FLASHLIGHT_HOLD_PER_LEVEL
	return math.max(hold, Effects.FLASHLIGHT_MIN_HOLD)
end

local function owned(player: Player): { [string]: boolean }
	local data = Data.get(player)
	return if data then data.Builds else {}
end

-- Quantos clientes um "Charge" atende de uma vez.
function StoreUpgrades.chargeBatch(player: Player): number
	return 1 + StoreUpgrades.level(player, "FastRegister") + Builds.sum(owned(player), "chargeBatch")
end

-- Multiplica a chegada de clientes (1.1 = 10% a mais): upgrade de propaganda + decoração da loja.
function StoreUpgrades.customerRate(player: Player): number
	return 1
		+ StoreUpgrades.level(player, "Advertising") * Effects.ADVERTISING_CUSTOMERS_PER_LEVEL
		+ Builds.sum(owned(player), "customers")
end

-- Multiplica o preço dos itens vendidos (Premium Products).
function StoreUpgrades.priceMultiplier(player: Player): number
	return 1 + StoreUpgrades.level(player, "PremiumProducts") * Effects.PREMIUM_PRICE_PER_LEVEL
end

function StoreUpgrades.doorLockSeconds(player: Player): number
	return Config.Door.LOCK_SECONDS
		+ StoreUpgrades.level(player, "DoorLock") * Effects.DOOR_LOCK_SECONDS_PER_LEVEL
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Quem está carregando uma anomalia roubada fica lento; o Steal.luau devolve a velocidade depois.
	if humanoid and player:GetAttribute("CarryingStolen") ~= true then
		humanoid.WalkSpeed = StoreUpgrades.walkSpeed(player)
	end
end

-- Bigger Shelves: o bônus de estoque fica num atributo da loja, que o Shelves.luau soma em cada móvel.
local function applyShelfBonus(player: Player)
	local store = Plots.getStore(player)
	if store then
		store:SetAttribute(
			"ShelfBonus",
			StoreUpgrades.level(player, "BigShelves") * Effects.BIG_SHELVES_CAPACITY_PER_LEVEL
		)
		Shelves.refreshLabels(store)
	end
end

local function publishLevels(player: Player)
	for _, definition in Upgrades.LIST do
		player:SetAttribute(Upgrades.attributeName(definition.id), StoreUpgrades.level(player, definition.id))
	end
end

local function applyAll(player: Player)
	publishLevels(player)
	applyShelfBonus(player)
	applySpeed(player)
end

function StoreUpgrades.buy(player: Player, id: string)
	local definition = Upgrades.get(id)
	local data = Data.get(player)
	if definition == nil or data == nil then
		return
	end

	local current = data.Upgrades[id] or 0
	if definition.requiresBuild and not data.Builds[definition.requiresBuild] then
		local piece = Builds.get(definition.requiresBuild)
		local name = if piece then piece.displayName else definition.requiresBuild
		notify:FireClient(player, `Build the {name} first!`, Color3.fromRGB(255, 230, 140))
		return
	end
	if current >= definition.maxLevel then
		notify:FireClient(player, `{definition.displayName} is already maxed!`, Color3.fromRGB(255, 230, 140))
		return
	end
	local cost = Upgrades.cost(id, current)
	if not Economy.trySpend(player, cost) then
		notify:FireClient(player, "Not enough cash! Collect your safe.", Color3.fromRGB(255, 100, 100))
		return
	end

	data.Upgrades[id] = current + 1
	Analytics.step(player, "FirstUpgrade")
	Analytics.spend(player, cost, "Shop", `Upgrade_{id}_{current + 1}`)
	applyAll(player)
	notify:FireClient(
		player,
		`{definition.displayName} upgraded to level {current + 1}!`,
		Color3.fromRGB(120, 255, 140)
	)
end

local function setupTerminal(player: Player)
	local store = Plots.getStore(player)
	local terminal = store and store:FindFirstChild("UpgradeTerminal")
	if terminal == nil or not terminal:IsA("BasePart") then
		return
	end
	-- O cliente abre a janela de upgrades quando este botão é usado (client/UpgradesUi.luau).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Terminal"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Parent = terminal
end

-- Chamado de novo pelo Builds depois de a loja ser reconstruída (Franquia).
function StoreUpgrades.applyAll(player: Player)
	applyAll(player)
end

local function onStoreReady(player: Player)
	setupTerminal(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applySpeed(player)
	end)
	if Data.waitFor(player) then
		applyAll(player)
	end
end

-- Precisa rodar depois de Plots, Economy, Shelves e Cells.
function StoreUpgrades.start()
	notify = Remotes.get("Notify")

	Remotes.get("BuyUpgrade").OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" then
			StoreUpgrades.buy(player, id)
		end
	end)

	Plots.onStoreReady(onStoreReady)
end

return StoreUpgrades
