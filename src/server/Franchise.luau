--!strict
-- Franquia: o "rebirth" do Anomaly Mart (docs/V2.md, seção 4).
--
-- Com saldo suficiente, o jogador abre uma Franquia: a loja volta a ser uma barraquinha e o dinheiro e os
-- upgrades zeram, mas ele ganha +50% de renda para sempre e libera partes novas no catálogo. As anomalias,
-- a sala dos fundos, as celas e a segurança continuam (não dá para perder a coleção).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildCatalog = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Plots = require(script.Parent.Plots)

local Settings = Config.Franchise

local Franchise = {}

local notify: RemoteEvent

-- Saldo necessário para abrir a próxima Franquia.
function Franchise.cost(level: number): number
	return Settings.BASE_COST * Settings.COST_GROWTH ^ level
end

local function publish(player: Player)
	local data = Data.get(player)
	if data == nil then
		return
	end
	player:SetAttribute("Franchise", data.Franchise)
	player:SetAttribute("FranchiseCost", Franchise.cost(data.Franchise))
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Franchise")
	if stat and stat:IsA("IntValue") then
		stat.Value = data.Franchise
	end
end

local function open(player: Player)
	local data = Data.get(player)
	if data == nil then
		return
	end
	if data.Franchise >= Settings.MAX then
		notify:FireClient(player, "You already own every franchise!", Color3.fromRGB(255, 230, 140))
		return
	end
	local cost = Franchise.cost(data.Franchise)
	if data.Cash < cost then
		notify:FireClient(
			player,
			`You need {NumberFormat.cash(cost)} in cash to open a franchise.`,
			Color3.fromRGB(255, 100, 100)
		)
		return
	end

	-- Zera o que é da loja e guarda o que é da coleção.
	local kept: { [string]: boolean } = {}
	for id in data.Builds do
		local piece = BuildCatalog.get(id)
		if piece and piece.keepOnFranchise then
			kept[id] = true
		end
		player:SetAttribute(`Build_{id}`, nil)
	end
	data.Builds = kept
	data.Cash = 0
	data.SafeBalance = 0
	data.Upgrades = {}
	for _, definition in Upgrades.LIST do
		player:SetAttribute(Upgrades.attributeName(definition.id), 0)
	end
	data.Franchise += 1
	Economy.refreshDisplay(player)
	Analytics.spend(player, cost, "Gameplay", "Franchise")
	Analytics.event(player, "FranchiseOpened", data.Franchise)

	publish(player)
	Plots.rebuildStore(player)
	notify:FireClient(
		player,
		`Franchise #{data.Franchise} opened! +{math.floor(data.Franchise * Settings.INCOME_BONUS * 100)}% income forever.`,
		Color3.fromRGB(255, 220, 80)
	)
end

local function onStoreReady(player: Player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats and leaderstats:FindFirstChild("Franchise") == nil then
		local stat = Instance.new("IntValue")
		stat.Name = "Franchise"
		stat.Parent = leaderstats
	end
	if Data.waitFor(player) then
		publish(player)
	end
end

function Franchise.start()
	notify = Remotes.get("Notify")
	Remotes.get("OpenFranchise").OnServerEvent:Connect(open)
	Plots.onStoreReady(onStoreReady)
end

return Franchise
