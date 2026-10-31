--!strict
-- Poderes dos monstros da rua quando estão numa cela (docs/V3.md, seção 6).
--
-- Cada monstro da rua dá um poder para a loja de quem o tem. Monstros iguais somam o poder até
-- Config.MonsterPowers.MAX_STACK. Os outros módulos perguntam aqui quanto vale cada poder:
--
--   Gloop         enche a prateleira mais vazia a cada 30 s (este módulo faz isso sozinho)
--   Mimic Crate   +2 itens em cada prateleira (atributo "MonsterShelfBonus" da loja, lido pelo Shelves)
--   Skull Hound   +1,5 s para o ladrão abrir a cela (Cells)
--   Eye Spider    captura de anomalia disfarçada 15% mais rápida (StoreUpgrades.captureHoldSeconds)
--   TV Head       +10% no preço dos itens (StoreUpgrades.priceMultiplier)
--   Static Jelly  +20% na renda das máquinas (Cells.passiveIncome)
--   Moth Monarch  +25% de clientes de madrugada (StoreUpgrades.customerRate)
--   The Tall One  ladrão carregando anomalia sua corre 30% mais devagar (Steal)
--   Rift King     +10% de renda para TODO MUNDO no servidor (Economy.incomeMultiplier)
--
-- Este módulo não pode dar require em Cells nem em Economy (eles dão require aqui).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local DayNight = require(script.Parent.DayNight)
local Plots = require(script.Parent.Plots)
local Shelves = require(script.Parent.Shelves)

local Settings = Config.MonsterPowers

local MonsterPowers = {}

-- Chamado quando o bônus do Rift King muda (a renda de todo mundo precisa ser recalculada).
local serverBonusListeners: { () -> () } = {}
local lastRiftKings = 0

-- Quantos monstros deste tipo o jogador tem nas celas, já com o limite de acúmulo.
function MonsterPowers.count(player: Player, kind: string): number
	local data = Data.get(player)
	if data == nil then
		return 0
	end
	local total = 0
	for _, cell in data.Cells do
		if cell.Kind == kind then
			total += 1
		end
	end
	local cap = if kind == "MimicCrate" then Settings.MIMIC_MAX_STACK else Settings.MAX_STACK
	return math.min(total, cap)
end

function MonsterPowers.shelfBonus(player: Player): number
	return MonsterPowers.count(player, "MimicCrate") * Settings.MIMIC_SHELF_BONUS
end

function MonsterPowers.stealHoldBonus(player: Player): number
	return MonsterPowers.count(player, "SkullHound") * Settings.HOUND_HOLD_SECONDS
end

-- Multiplica o tempo de captura (0.85 com uma Eye Spider).
function MonsterPowers.captureHoldMultiplier(player: Player): number
	return 1 - MonsterPowers.count(player, "EyeSpider") * Settings.SPIDER_CAPTURE_FASTER
end

-- Soma ao multiplicador de preço (0.1 com um TV Head).
function MonsterPowers.priceBonus(player: Player): number
	return MonsterPowers.count(player, "TVHead") * Settings.TV_PRICE_BONUS
end

function MonsterPowers.passiveMultiplier(player: Player): number
	return 1 + MonsterPowers.count(player, "StaticJelly") * Settings.JELLY_PASSIVE_BONUS
end

-- Soma à chegada de clientes, só de madrugada.
function MonsterPowers.customerBonus(player: Player): number
	if not DayNight.isNight() then
		return 0
	end
	return MonsterPowers.count(player, "MothMonarch") * Settings.MOTH_NIGHT_CUSTOMERS
end

-- Multiplica a velocidade de quem está roubando deste dono.
function MonsterPowers.thiefSpeedMultiplier(owner: Player): number
	return if MonsterPowers.count(owner, "TheTallOne") > 0 then Settings.TALL_ONE_THIEF_SLOW else 1
end

-- Rift Kings no servidor inteiro (somando todos os jogadores), com o limite de acúmulo.
local function serverRiftKings(except: Player?): number
	local total = 0
	for _, player in Players:GetPlayers() do
		if player ~= except then
			total += MonsterPowers.count(player, "RiftKing")
		end
	end
	return math.min(total, Settings.MAX_STACK)
end

-- Multiplicador de renda que todo mundo no servidor ganha (1.1 com um Rift King).
function MonsterPowers.serverMultiplier(): number
	return 1 + lastRiftKings * Settings.RIFT_KING_SERVER_BONUS
end

function MonsterPowers.onServerBonusChanged(listener: () -> ())
	table.insert(serverBonusListeners, listener)
end

local function checkServerBonus(except: Player?)
	local now = serverRiftKings(except)
	if now == lastRiftKings then
		return
	end
	lastRiftKings = now
	ReplicatedStorage:SetAttribute("RiftKingBonus", now * Settings.RIFT_KING_SERVER_BONUS)
	for _, listener in serverBonusListeners do
		task.spawn(listener)
	end
end

-- Chamado pelo Cells sempre que as celas do jogador mudam.
function MonsterPowers.refresh(player: Player)
	local store = Plots.getStore(player)
	if store then
		local bonus = MonsterPowers.shelfBonus(player)
		if store:GetAttribute("MonsterShelfBonus") ~= bonus then
			store:SetAttribute("MonsterShelfBonus", bonus)
			Shelves.refreshLabels(store)
		end
	end
	checkServerBonus()
end

-- Gloop: cada um enche a prateleira mais vazia da loja.
local function gloopRestock(player: Player)
	local gloops = MonsterPowers.count(player, "Gloop")
	local store = Plots.getStore(player)
	if gloops == 0 or store == nil then
		return
	end
	local shelves = Shelves.list(store)
	table.sort(shelves, function(a, b)
		return Shelves.getStock(a) / math.max(Shelves.capacity(a), 1)
			< Shelves.getStock(b) / math.max(Shelves.capacity(b), 1)
	end)
	for i = 1, math.min(gloops, #shelves) do
		local shelf = shelves[i]
		if Shelves.getStock(shelf) < Shelves.capacity(shelf) then
			Shelves.refill(shelf)
		end
	end
end

function MonsterPowers.start()
	Players.PlayerRemoving:Connect(function(player)
		checkServerBonus(player)
	end)
	task.spawn(function()
		while true do
			task.wait(Settings.GLOOP_RESTOCK_SECONDS)
			for _, player in Players:GetPlayers() do
				gloopRestock(player)
			end
		end
	end)
end

return MonsterPowers
