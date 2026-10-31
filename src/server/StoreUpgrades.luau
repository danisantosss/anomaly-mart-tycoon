--!strict
-- Compra e efeitos dos upgrades da loja (docs/V1.md, seção 7). O catálogo e os preços ficam em
-- Shared/Upgrades.luau; aqui o servidor valida a compra, salva o nível e aplica o efeito.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Cells = require(script.Parent.Cells)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Plots = require(script.Parent.Plots)
local Shelves = require(script.Parent.Shelves)
local StoreBuilder = require(script.Parent.Street.StoreBuilder)

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

-- Quantos clientes um "Charge" atende de uma vez.
function StoreUpgrades.chargeBatch(player: Player): number
	return 1 + StoreUpgrades.level(player, "FastRegister")
end

-- Multiplica a chegada de clientes (1.1 = 10% a mais).
function StoreUpgrades.customerRate(player: Player): number
	return 1 + StoreUpgrades.level(player, "Sign") * Effects.SIGN_CUSTOMERS_PER_LEVEL
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Quem está carregando uma anomalia roubada fica lento; o Steal.luau devolve a velocidade depois.
	if humanoid and player:GetAttribute("CarryingStolen") ~= true then
		humanoid.WalkSpeed = StoreUpgrades.walkSpeed(player)
	end
end

-- Cria as prateleiras que faltam para o nível atual.
local function applyShelves(player: Player)
	local store = Plots.getStore(player)
	local origin = Plots.getOrigin(player)
	local folder = store and store:FindFirstChild("Shelves")
	if store == nil or origin == nil or folder == nil then
		return
	end
	local wanted = math.min(
		Config.Street.START_SHELVES + StoreUpgrades.level(player, "Shelves"),
		Config.Street.MAX_SHELVES
	)
	for index = 1, wanted do
		if folder:FindFirstChild(`Shelf{index}`) == nil then
			Shelves.setup(player, StoreBuilder.addShelf(origin, store, index))
		end
	end
end

local function publishLevels(player: Player)
	for _, definition in Upgrades.LIST do
		player:SetAttribute(Upgrades.attributeName(definition.id), StoreUpgrades.level(player, definition.id))
	end
end

local function applyAll(player: Player)
	publishLevels(player)
	applyShelves(player)
	applySpeed(player)
	Cells.render(player)
end

function StoreUpgrades.buy(player: Player, id: string)
	local definition = Upgrades.get(id)
	local data = Data.get(player)
	if definition == nil or data == nil then
		return
	end

	local current = data.Upgrades[id] or 0
	if current >= definition.maxLevel then
		notify:FireClient(player, `{definition.displayName} is already maxed!`, Color3.fromRGB(255, 230, 140))
		return
	end
	if not Economy.trySpend(player, Upgrades.cost(id, current)) then
		notify:FireClient(player, "Not enough cash! Collect your safe.", Color3.fromRGB(255, 100, 100))
		return
	end

	data.Upgrades[id] = current + 1
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

local function onPlayerAdded(player: Player)
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

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return StoreUpgrades
