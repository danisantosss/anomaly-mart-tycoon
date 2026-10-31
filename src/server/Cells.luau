--!strict
-- Celas de contenção (docs/V1.md, seção 6).
--
-- As anomalias capturadas ficam salvas em Data.Cells (uma por cela, na ordem) e aparecem dentro das celas
-- de vidro da sala dos fundos. Cada uma gera $/s, que cai no cofre a cada segundo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnomalyLooks = require(script.Parent.AnomalyLooks)
local CustomerModel = require(script.Parent.CustomerModel)
local Models = require(script.Parent.Monsters.Models)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Plots = require(script.Parent.Plots)
local StoreBuilder = require(script.Parent.Street.StoreBuilder)

local Street = Config.Street

local Cells = {}

local DISPLAY_SCALE = 0.6 -- boneco menor, para caber na cela

-- Criar o boneco demora um instante. Se as celas forem redesenhadas nesse meio-tempo, o boneco atrasado
-- é descartado (comparando com a versão atual).
local renderVersion: { [Player]: number } = {}

-- Anomalias sendo carregadas por um ladrão neste momento: somem da cela e não rendem, mas continuam nos dados
-- do dono até o roubo dar certo (ver Steal.luau). Chave fraca: some sozinho quando a cela é removida.
local hidden: { [Data.CellData]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Celas compradas: a sala dos fundos vem com uma e cada botão "Cell #N" soma mais uma (shared/Builds.luau).
function Cells.capacity(player: Player): number
	local data = Data.get(player)
	local cells = if data then Builds.sum(data.Builds, "cells") else 0
	return math.min(cells, Street.MAX_CELLS)
end

-- Renda das máquinas da loja (vending, café, arcade...), que cai no cofre junto com a das celas.
function Cells.passiveIncome(player: Player): number
	local data = Data.get(player)
	return if data then Builds.sum(data.Builds, "passive") else 0
end

function Cells.count(player: Player): number
	local data = Data.get(player)
	return if data then #data.Cells else 0
end

function Cells.totalIncome(player: Player): number
	local data = Data.get(player)
	if data == nil then
		return 0
	end
	local total = 0
	for _, cell in data.Cells do
		if not hidden[cell] then
			total += Anomalies.income(cell.Kind, cell.Variant)
		end
	end
	return total
end

local function cellPart(store: Model, index: number): BasePart?
	local folder = store:FindFirstChild("Cells")
	local part = folder and folder:FindFirstChild(`Cell{index}`)
	return if part and part:IsA("BasePart") then part else nil
end

local function clearDisplay(cell: BasePart)
	for _, name in { "Occupant", "CellBillboard", "StealPrompt" } do
		local old = cell:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

-- Monstro da rua: diminui até caber na cela (os grandes ficam "comprimidos" lá dentro).
local function buildMonster(cell: BasePart, kind: string, variant: string): Model
	local model = Models.build(kind, variant, false)
	local _, size = model:GetBoundingBox()
	local fit = math.min((cell.Size.Y - 0.6) / size.Y, (cell.Size.X - 0.4) / math.max(size.X, size.Z))
	model:ScaleTo(model:GetScale() * math.min(1, fit))
	return model
end

local function showOccupant(player: Player, version: number, cell: BasePart, kind: string, variant: string)
	local isMonster = Models.has(kind)
	local model = if isMonster then buildMonster(cell, kind, variant) else CustomerModel.build()
	if renderVersion[player] ~= version or cell.Parent == nil then
		model:Destroy()
		return
	end
	model.Name = "Occupant"
	if not isMonster then
		AnomalyLooks.apply(model, kind, variant)
		model:ScaleTo(model:GetScale() * DISPLAY_SCALE)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Monstro: só a raiz fica ancorada, para o cliente conseguir mexer as juntas (animação).
			descendant.Anchored = not isMonster or descendant == model.PrimaryPart
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	local _, size = model:GetBoundingBox()
	local floor = cell.CFrame * CFrame.new(0, -cell.Size.Y / 2, 0)
	model:PivotTo(floor * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0))
	model.Parent = cell

	local definition = Anomalies.get(kind)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CellBillboard"
	billboard.Size = UDim2.fromOffset(170, 46)
	billboard.StudsOffset = Vector3.new(0, cell.Size.Y / 2 + 1, 0)
	billboard.MaxDistance = 40
	billboard.Parent = cell

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = if definition then Anomalies.RARITY_COLORS[definition.rarity] else Color3.new(1, 1, 1)
	label.Text = `{Anomalies.fullName(kind, variant)}\n{NumberFormat.cash(Anomalies.income(kind, variant))}/s`
	label.Parent = billboard
end

-- Botão "Steal" na cela ocupada: aparece para todo mundo menos o dono. O Steal.luau trata o clique.
local function addStealPrompt(owner: Player, cell: BasePart, index: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = "Cell"
	prompt.HoldDuration = Config.Steal.HOLD_SECONDS
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ExcludeUserId", owner.UserId)
	prompt:SetAttribute("CellIndex", index)
	prompt.Parent = cell
end

local function updateLeaderstat(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Anomalies")
	if stat and stat:IsA("IntValue") then
		stat.Value = Cells.count(player)
	end
	local multiplier = Economy.incomeMultiplier(player)
	player:SetAttribute(
		"IncomePerSecond",
		(Cells.totalIncome(player) + Cells.passiveIncome(player)) * multiplier
	)
end

-- Atualiza o placar e o $/s da HUD (depois de comprar uma máquina, ganhar um bônus...).
function Cells.refreshIncome(player: Player)
	updateLeaderstat(player)
end

-- Redesenha todas as celas da loja a partir dos dados salvos.
function Cells.render(player: Player)
	local data = Data.get(player)
	local store = Plots.getStore(player)
	local origin = Plots.getOrigin(player)
	if data == nil or store == nil or origin == nil then
		return
	end

	local version = (renderVersion[player] or 0) + 1
	renderVersion[player] = version

	for index = 1, Cells.capacity(player) do
		local cell = cellPart(store, index) or StoreBuilder.addCell(origin, store, index)
		clearDisplay(cell)
		local occupant = data.Cells[index]
		if occupant and not hidden[occupant] then
			task.spawn(showOccupant, player, version, cell, occupant.Kind, occupant.Variant)
			addStealPrompt(player, cell, index)
		end
	end
	updateLeaderstat(player)
end

-- Põe uma anomalia na primeira cela livre. Devolve false se não tem cela livre.
function Cells.tryAdd(player: Player, kind: string, variant: string): boolean
	local data = Data.get(player)
	if data == nil or #data.Cells >= Cells.capacity(player) then
		return false
	end
	table.insert(data.Cells, { Kind = kind, Variant = variant })
	-- Index: guarda cada combinação tipo + variante já conseguida.
	local key = `{kind}:{variant}`
	if not data.Index[key] then
		data.Index[key] = true
		player:SetAttribute(Anomalies.indexAttribute(kind, variant), true)
	end
	Cells.render(player)
	return true
end

function Cells.get(player: Player, index: number): Data.CellData?
	local data = Data.get(player)
	return if data then data.Cells[index] else nil
end

function Cells.isHidden(cell: Data.CellData): boolean
	return hidden[cell] == true
end

-- Esconde (ou mostra de novo) uma anomalia que está sendo roubada.
function Cells.setHidden(owner: Player, cell: Data.CellData, value: boolean)
	hidden[cell] = if value then true else nil
	Cells.render(owner)
end

-- Tira a anomalia dos dados do dono (roubo concluído). As de trás andam uma cela para frente.
function Cells.removeCell(owner: Player, cell: Data.CellData): boolean
	local data = Data.get(owner)
	local index = data and table.find(data.Cells, cell)
	if data == nil or index == nil then
		return false
	end
	table.remove(data.Cells, index)
	hidden[cell] = nil
	Cells.render(owner)
	return true
end

function Cells.hasFreeCell(player: Player): boolean
	return Data.get(player) ~= nil and Cells.count(player) < Cells.capacity(player)
end

-- Ganho offline: uma parte do $/s das celas pelo tempo fora, com limite (docs/V1.md, seção 3).
local function payOffline(player: Player, data: Data.PlayerData)
	local settings = Config.Offline
	local away = if data.LastLogout > 0 then os.time() - data.LastLogout else 0
	-- Marca "agora" já, para um servidor que cair não pagar o mesmo período duas vezes.
	data.LastLogout = os.time()
	if away < settings.MIN_SECONDS then
		return
	end

	local seconds = math.min(away, settings.MAX_HOURS * 3600)
	local perSecond = Cells.totalIncome(player) + Cells.passiveIncome(player)
	local earned = Economy.addToSafe(player, perSecond * settings.FRACTION * seconds)
	if earned >= 1 then
		Remotes.get("Notify"):FireClient(
			player,
			`While you were away, your anomalies made {NumberFormat.cash(earned)}! Collect it at your safe.`,
			Color3.fromRGB(120, 255, 140)
		)
	end
end

local function onStoreReady(player: Player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats and leaderstats:FindFirstChild("Anomalies") == nil then
		local stat = Instance.new("IntValue")
		stat.Name = "Anomalies"
		stat.Parent = leaderstats
	end

	local data = Data.waitFor(player)
	if data then
		for key in data.Index do
			local kind, variant = string.match(key, "^(%w+):(%w+)$")
			if kind and variant then
				player:SetAttribute(Anomalies.indexAttribute(kind, variant), true)
			end
		end
		Cells.render(player)
		payOffline(player, data)
	end
end

local function incomeLoop()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			Economy.publishMultiplier(player)
			updateLeaderstat(player)
			local income = Cells.totalIncome(player) + Cells.passiveIncome(player)
			if income > 0 then
				Economy.addToSafe(player, income)
			end
		end
	end
end

-- Precisa rodar depois de Plots.start() e Economy.start().
function Cells.start()
	Plots.onStoreReady(onStoreReady)
	Players.PlayerRemoving:Connect(function(player)
		renderVersion[player] = nil
	end)
	task.spawn(incomeLoop)
end

return Cells
