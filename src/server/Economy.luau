--!strict
-- Dinheiro do jogador: saldo (Cash), cofre da loja (SafeBalance), placar e coleta.
--
-- Regra do tycoon: toda renda (vendas, celas) entra no COFRE. O jogador precisa tocar no cofre para passar
-- o dinheiro para o saldo, que é o que ele gasta. Só este módulo mexe nesses valores, e só no servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)
local Plots = require(script.Parent.Plots)

local Economy = {}

local cashCollected: RemoteEvent
local safeLabels: { [Player]: TextLabel } = {}
local lastCollect: { [Player]: number } = {}

-- Mostra os valores atuais no placar (Tab), no atributo lido pela HUD e na plaquinha do cofre.
local function refresh(player: Player)
	local data = Data.get(player)
	if data == nil then
		return
	end

	player:SetAttribute("Cash", data.Cash)

	local leaderstats = player:FindFirstChild("leaderstats")
	local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashStat and cashStat:IsA("StringValue") then
		cashStat.Value = NumberFormat.cash(data.Cash)
	end

	local safeLabel = safeLabels[player]
	if safeLabel then
		safeLabel.Text = NumberFormat.cash(data.SafeBalance)
	end
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	-- StringValue para o placar já mostrar "$1.2M" em vez de 1200000.
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats

	leaderstats.Parent = player
end

-- Plaquinha flutuando em cima do cofre com quanto tem para coletar.
local function attachSafeLabel(player: Player, safe: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SafeBillboard"
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 80
	billboard.Parent = safe

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	safeLabels[player] = label
end

function Economy.getCash(player: Player): number
	local data = Data.get(player)
	return if data then data.Cash else 0
end

-- Põe dinheiro direto no saldo (prêmios, ganho offline).
function Economy.addCash(player: Player, amount: number)
	local data = Data.get(player)
	if data == nil or amount <= 0 then
		return
	end
	data.Cash += amount
	refresh(player)
end

-- Tenta gastar. Devolve false (e não gasta nada) se o jogador não tem o bastante.
function Economy.trySpend(player: Player, amount: number): boolean
	local data = Data.get(player)
	if data == nil or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	refresh(player)
	return true
end

-- Toda renda da loja entra por aqui.
function Economy.addToSafe(player: Player, amount: number)
	local data = Data.get(player)
	if data == nil or amount <= 0 then
		return
	end
	data.SafeBalance += amount
	refresh(player)
end

-- Tira uma fração do cofre (ex.: anomalia atendida leva 10%). Devolve quanto saiu.
function Economy.takeFromSafe(player: Player, fraction: number): number
	local data = Data.get(player)
	if data == nil then
		return 0
	end
	local amount = data.SafeBalance * math.clamp(fraction, 0, 1)
	data.SafeBalance -= amount
	refresh(player)
	return amount
end

function Economy.collectSafe(player: Player)
	local data = Data.get(player)
	if data == nil then
		return
	end

	local now = os.clock()
	if now - (lastCollect[player] or 0) < Config.Economy.SAFE_COLLECT_COOLDOWN then
		return
	end

	-- Só coleta valores inteiros; os centavos do $/s ficam no cofre para a próxima.
	local amount = math.floor(data.SafeBalance)
	if amount <= 0 then
		return
	end

	lastCollect[player] = now
	data.SafeBalance -= amount
	data.Cash += amount
	refresh(player)
	cashCollected:FireClient(player, amount)
end

local function connectSafe(player: Player)
	local store = Plots.getStore(player)
	local safe = store and store:FindFirstChild("Safe")
	if safe == nil or not safe:IsA("BasePart") then
		return
	end

	attachSafeLabel(player, safe)

	safe.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character and Players:GetPlayerFromCharacter(character) == player then
			Economy.collectSafe(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	createLeaderstats(player)

	local data = Data.load(player)
	if data == nil then
		return
	end

	connectSafe(player)
	refresh(player)
end

local function onPlayerRemoving(player: Player)
	Data.release(player)
	safeLabels[player] = nil
	lastCollect[player] = nil
end

-- Renda de teste do Studio (Config.Debug). Some quando o valor for 0.
local function startStudioIncome()
	local perSecond = Config.Debug.STUDIO_SAFE_INCOME_PER_SECOND
	if not RunService:IsStudio() or perSecond <= 0 then
		return
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				Economy.addToSafe(player, perSecond)
			end
		end
	end)
end

-- Precisa rodar depois de Plots.start(), porque usa a loja do jogador.
function Economy.start()
	cashCollected = Remotes.get("CashCollected")

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	startStudioIncome()
end

return Economy
