--!strict
-- Placar global (docs/V2.md, seção 5): os 10 jogadores que mais faturaram em todos os servidores, num telão
-- no fim da rua. Usa um OrderedDataStore, atualizado devagar (Config.Leaderboard) para não estourar limites.
-- No Studio sem "API Services" ligado o DataStore não funciona e o telão avisa isso.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Data = require(script.Parent.Data)
local Layout = require(script.Parent.Street.Layout)
local Parts = require(script.Parent.Street.Parts)

local Settings = Config.Leaderboard

local Leaderboards = {}

local rows: { TextLabel } = {}
local title: TextLabel

local function buildBoard()
	-- Na pracinha do lado do Ralo de Contenção, virado para a Avenida (fora da Faixa da Fenda).
	local x = Layout.DRAIN_X - 8
	local z = 52
	local board = Parts.make({
		name = "Leaderboard",
		size = Vector3.new(16, 18, 1),
		cframe = CFrame.lookAt(Vector3.new(x, 11, z), Vector3.new(0, 11, z)), -- frente virada para a rua
		color = Color3.fromRGB(20, 22, 30),
		parent = workspace,
	})
	for _, dz in { -6, 6 } do
		Parts.make({
			name = "LeaderboardLeg",
			size = Vector3.new(0.8, 4, 0.8),
			cframe = CFrame.new(x, 1, z + dz),
			color = Color3.fromRGB(60, 64, 72),
			parent = board,
		})
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board

	local list = Instance.new("Frame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.Text = "TOP EARNERS"
	title.LayoutOrder = 0
	title.Parent = list

	for index = 1, Settings.SIZE do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.085)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextColor3 = if index <= 3 then Color3.fromRGB(255, 230, 140) else Color3.new(1, 1, 1)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.LayoutOrder = index
		row.Parent = list
		rows[index] = row
	end
end

local nameCache: { [number]: string } = {}

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and typeof(name) == "string" then name else `Player {userId}`
	nameCache[userId] = result
	return result
end

local function update(store: OrderedDataStore)
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			pcall(store.SetAsync, store, tostring(player.UserId), math.floor(data.TotalEarned))
		end
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, Settings.SIZE)
	if not ok then
		title.Text = "TOP EARNERS (offline)"
		return
	end
	title.Text = "TOP EARNERS"
	local entries = (pages :: DataStorePages):GetCurrentPage()
	for index, row in rows do
		local entry = entries[index]
		if entry then
			row.Text = `  {index}. {nameOf(tonumber(entry.key) or 0)} · {NumberFormat.cash(entry.value)}`
		else
			row.Text = ""
		end
	end
end

function Leaderboards.start()
	buildBoard()
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "TopEarned_v2")
	if not ok then
		title.Text = "TOP EARNERS (offline)"
		return
	end
	task.spawn(function()
		task.wait(10)
		while true do
			update(store)
			task.wait(Settings.UPDATE_SECONDS)
		end
	end)
end

return Leaderboards
