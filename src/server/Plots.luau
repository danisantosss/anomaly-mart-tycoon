--!strict
-- Distribui os terrenos: cada jogador que entra recebe o primeiro terreno livre e uma loja nova.
-- Quando ele sai, a loja é destruída e o terreno volta a ficar livre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Street.Layout)
local StoreBuilder = require(script.Parent.Street.StoreBuilder)
local StreetBuilder = require(script.Parent.Street.StreetBuilder)

local Plots = {}

local plotModels: { [number]: Model } = {}
local ownerByPlot: { [number]: Player } = {}
local plotByPlayer: { [Player]: number } = {}

local function setAvailableSign(plot: Model, visible: boolean)
	local sign = plot:FindFirstChild("AvailableSign")
	if sign and sign:IsA("BasePart") then
		sign.Transparency = if visible then 0 else 1
		sign.CanCollide = visible
		local gui = sign:FindFirstChild("Label")
		if gui and gui:IsA("SurfaceGui") then
			gui.Enabled = visible
		end
	end
end

local function firstFreePlot(): number?
	for index = 1, Config.Street.PLOT_COUNT do
		if ownerByPlot[index] == nil then
			return index
		end
	end
	return nil
end

-- Loja do jogador, ou nil se ele não tem terreno (servidor cheio).
function Plots.getStore(player: Player): Model?
	local index = plotByPlayer[player]
	if index == nil then
		return nil
	end
	local store = plotModels[index]:FindFirstChild("Store")
	return if store and store:IsA("Model") then store else nil
end

-- CFrame do terreno do jogador (centro, no chão, olhando para a rua). Ver Street/Layout.luau.
function Plots.getOrigin(player: Player): CFrame?
	local index = plotByPlayer[player]
	return if index then Layout.plotCFrame(index) else nil
end

function Plots.getPlotIndex(player: Player): number?
	return plotByPlayer[player]
end

function Plots.getOwner(plotIndex: number): Player?
	return ownerByPlot[plotIndex]
end

-- Funções que preparam a loja de um jogador (prateleiras, caixa, porta...). Ver Plots.onStoreReady.
local storeReadyCallbacks: { (Player) -> () } = {}

-- Chama `callback(player)` para cada loja já construída e para cada loja nova, logo depois de construída.
-- Use isto em vez de Players.PlayerAdded: o Roblox não garante a ordem dos PlayerAdded, então outro sistema
-- poderia rodar antes da loja existir.
function Plots.onStoreReady(callback: (Player) -> ())
	table.insert(storeReadyCallbacks, callback)
	for player in plotByPlayer do
		task.spawn(callback, player)
	end
end

local function teleportToStore(player: Player, character: Model)
	local store = Plots.getStore(player)
	if store == nil then
		return
	end
	local spawnPoint = store:FindFirstChild("SpawnPoint")
	if spawnPoint and spawnPoint:IsA("BasePart") then
		character:WaitForChild("HumanoidRootPart")
		character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
	end
end

local function onPlayerAdded(player: Player)
	local index = firstFreePlot()
	if index == nil then
		warn(`[Plots] sem terreno livre para {player.Name}`)
		return
	end

	ownerByPlot[index] = player
	plotByPlayer[player] = index
	player:SetAttribute("PlotIndex", index)

	local plot = plotModels[index]
	plot:SetAttribute("OwnerUserId", player.UserId)
	setAvailableSign(plot, false)
	StoreBuilder.build(Layout.plotCFrame(index), player, plot)
	for _, callback in storeReadyCallbacks do
		task.spawn(callback, player)
	end

	player.CharacterAdded:Connect(function(character)
		teleportToStore(player, character)
	end)
	if player.Character then
		teleportToStore(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local index = plotByPlayer[player]
	if index == nil then
		return
	end

	plotByPlayer[player] = nil
	ownerByPlot[index] = nil

	local plot = plotModels[index]
	plot:SetAttribute("OwnerUserId", nil)
	local store = plot:FindFirstChild("Store")
	if store then
		store:Destroy()
	end
	setAvailableSign(plot, true)
end

function Plots.start()
	local street = StreetBuilder.build()
	local plotsFolder = street:FindFirstChild("Plots") :: Folder
	for index = 1, Config.Street.PLOT_COUNT do
		plotModels[index] = plotsFolder:FindFirstChild(`Plot{index}`) :: Model
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Jogadores que entraram antes deste script rodar (acontece no Play Solo do Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Plots
