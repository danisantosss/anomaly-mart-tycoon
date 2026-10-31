--!strict
-- Botões de compra no chão: a loja cresce peça por peça (docs/V2.md, seção 2).
--
-- Cada parte do catálogo (shared/Builds.luau) que já pode ser comprada vira um botão brilhando no chão do
-- terreno do dono, com nome e preço. O dono pisa, paga com o saldo e a peça aparece com animação. As partes
-- compradas ficam salvas em Data.Builds e são reconstruídas (sem animação) quando ele volta ao jogo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BuildCatalog = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cells = require(script.Parent.Cells)
local Data = require(script.Parent.Data)
local Door = require(script.Parent.Door)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local Pieces = require(script.Parent.Street.Pieces)
local Plots = require(script.Parent.Plots)
local Shelves = require(script.Parent.Shelves)

local Settings = Config.Pads

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 100, 100)
local PAD_COLOR = Color3.fromRGB(60, 220, 140)

local Builds = {}

local notify: RemoteEvent
local lastTouch: { [Player]: number } = {}
local listeners: { (Player, string) -> () } = {}

local function tell(player: Player, text: string, color: Color3)
	notify:FireClient(player, text, color)
end

local function owned(player: Player): { [string]: boolean }
	local data = Data.get(player)
	return if data then data.Builds else {}
end

function Builds.owns(player: Player, id: string): boolean
	return owned(player)[id] == true
end

-- Chama `listener(player, id)` toda vez que uma parte é comprada ou ganha (para métricas, missões...).
function Builds.onBuilt(listener: (Player, string) -> ())
	table.insert(listeners, listener)
end

-- Posição do botão no terreno (coordenadas locais). Celas: na frente da vaga da cela.
local function padPosition(piece: BuildCatalog.Piece): Vector3?
	if piece.cellIndex then
		local offset = Layout.cellOffset(piece.cellIndex)
		local middle = (Layout.PARTITION_Z + Layout.STORE_BACK_Z) / 2
		return Vector3.new(offset.X, 0, offset.Z + (if offset.Z > middle then -3.5 else 3.5))
	end
	local pad = piece.pad
	return if pad then Vector3.new(pad.X, 0, pad.Y) else nil
end

-- A peça sobe do chão e aparece aos poucos, uma parte depois da outra.
local function animate(created: { BasePart })
	local info =
		TweenInfo.new(Settings.BUILD_ANIMATION_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local delayEach = math.min(0.02, 1 / math.max(#created, 1))
	for index, part in created do
		local target = part.CFrame
		local transparency = part.Transparency
		part.CFrame = target + Vector3.new(0, 4, 0)
		part.Transparency = 1
		task.delay(index * delayEach, function()
			if part.Parent then
				TweenService:Create(part, info, { CFrame = target, Transparency = transparency }):Play()
			end
		end)
	end
end

-- Liga o que a peça nova faz (prateleira com estoque, cela, porta de aço, renda...).
local function afterBuild(player: Player, id: string)
	Shelves.setupAll(player)
	local piece = BuildCatalog.get(id)
	local effects = piece and piece.effects
	if effects and effects.cells then
		Cells.render(player)
	end
	if id == "SteelDoor" then
		Door.setup(player)
	end
	Cells.refreshIncome(player)
end

local function buildPiece(player: Player, id: string, withAnimation: boolean)
	local store = Plots.getStore(player)
	local origin = Plots.getOrigin(player)
	if store == nil or origin == nil then
		return
	end
	player:SetAttribute(`Build_{id}`, true) -- o cliente usa para mostrar o que falta (ex.: UpgradesUi)
	local ctx: Pieces.Ctx = { origin = origin, store = store, owner = player, created = {} }
	Pieces.build(ctx, id)
	if withAnimation then
		animate(ctx.created)
	end
end

local refreshPads: (Player) -> ()

local function tryBuy(player: Player, id: string)
	local now = os.clock()
	if now - (lastTouch[player] or 0) < Settings.TOUCH_COOLDOWN then
		return
	end
	lastTouch[player] = now

	local data = Data.get(player)
	local piece = BuildCatalog.get(id)
	if data == nil or piece == nil or not BuildCatalog.isAvailable(data.Builds, data.Franchise, piece) then
		return
	end
	if not Economy.trySpend(player, piece.cost) then
		-- Mensagem mais espaçada, para não encher a tela enquanto ele está em cima do botão.
		lastTouch[player] = now + 1.5
		tell(
			player,
			`You need {NumberFormat.cash(piece.cost)} for {piece.displayName}. Collect your safe!`,
			BAD
		)
		return
	end

	data.Builds[id] = true
	buildPiece(player, id, true)
	afterBuild(player, id)
	refreshPads(player)
	tell(player, `Built: {piece.displayName}!`, GOOD)
	for _, listener in listeners do
		task.spawn(listener, player, id)
	end
end

local function makePad(player: Player, pads: Folder, origin: CFrame, piece: BuildCatalog.Piece)
	local position = padPosition(piece)
	if position == nil then
		return
	end
	local pad = Instance.new("Part")
	pad.Name = piece.id
	pad.Anchored = true
	pad.CanCollide = false
	pad.Size = Vector3.new(5, 0.3, 5)
	pad.CFrame = origin * CFrame.new(position + Vector3.new(0, 0.45, 0))
	pad.Material = Enum.Material.Neon
	pad.Color = PAD_COLOR
	pad.Transparency = 0.25
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("Cost", piece.cost)
	pad:SetAttribute("OwnerUserId", player.UserId)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PadBillboard"
	billboard.Size = UDim2.fromOffset(170, 56)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.MaxDistance = 60
	billboard.Parent = pad

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.Text = piece.displayName
	title.Parent = billboard

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Size = UDim2.fromScale(1, 0.45)
	price.Position = UDim2.fromScale(0, 0.55)
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.FredokaOne
	price.TextScaled = true
	price.TextColor3 = GOOD
	price.TextStrokeTransparency = 0.3
	price.Text = NumberFormat.cash(piece.cost)
	price.Parent = billboard

	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character and Players:GetPlayerFromCharacter(character) == player then
			tryBuy(player, piece.id)
		end
	end)
	pad.Parent = pads
end

-- Mostra um botão para cada parte que já pode ser comprada e apaga os que não valem mais.
function refreshPads(player: Player)
	local store = Plots.getStore(player)
	local origin = Plots.getOrigin(player)
	local data = Data.get(player)
	if store == nil or origin == nil or data == nil then
		return
	end
	local pads = store:FindFirstChild("Pads") :: Folder?
	if pads == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Pads"
		folder.Parent = store
		pads = folder
	end
	assert(pads)

	local wanted: { [string]: BuildCatalog.Piece } = {}
	for _, piece in BuildCatalog.LIST do
		if BuildCatalog.isAvailable(data.Builds, data.Franchise, piece) then
			wanted[piece.id] = piece
		end
	end
	for _, pad in pads:GetChildren() do
		if wanted[pad.Name] == nil then
			pad:Destroy()
		end
	end
	for id, piece in wanted do
		if pads:FindFirstChild(id) == nil then
			makePad(player, pads, origin, piece)
		end
	end
end

Builds.refreshPads = refreshPads

-- Dá uma parte de graça (ex.: a sala dos fundos na primeira captura do tutorial).
function Builds.grant(player: Player, id: string)
	local data = Data.get(player)
	if data == nil or data.Builds[id] or BuildCatalog.get(id) == nil then
		return
	end
	data.Builds[id] = true
	buildPiece(player, id, true)
	afterBuild(player, id)
	refreshPads(player)
	for _, listener in listeners do
		task.spawn(listener, player, id)
	end
end

-- Reconstrói tudo que o jogador já comprou, na ordem do catálogo (as partes de base vêm antes).
local function onStoreReady(player: Player)
	local data = Data.waitFor(player)
	if data == nil then
		return
	end
	for _, piece in BuildCatalog.LIST do
		if data.Builds[piece.id] then
			buildPiece(player, piece.id, false)
		end
	end
	Shelves.setupAll(player)
	Cells.render(player)
	if data.Builds.SteelDoor then
		Door.setup(player)
	end
	refreshPads(player)
end

-- Portas automáticas: abrem quando alguém (jogador ou cliente) chega perto.
local function autoDoorLoop()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local store = Plots.getStore(player)
			local origin = Plots.getOrigin(player)
			local doors = store and store:FindFirstChild("AutoDoor")
			if doors == nil or origin == nil then
				continue
			end
			local center = (origin * CFrame.new(0, 3, Layout.STORE_FRONT_Z)).Position
			local open = false
			for _, part in workspace:GetPartBoundsInRadius(center, 9, params) do
				if part.Name == "HumanoidRootPart" then
					open = true
					break
				end
			end
			if doors:GetAttribute("Open") == open then
				continue
			end
			doors:SetAttribute("Open", open)
			for _, panel in doors:GetChildren() do
				local closedX = panel:GetAttribute("ClosedX")
				local side = panel:GetAttribute("Side")
				if panel:IsA("BasePart") and typeof(closedX) == "number" and typeof(side) == "number" then
					local x = if open then closedX + side * 3.6 else closedX
					local target = origin * CFrame.new(x, panel.Size.Y / 2, Layout.STORE_FRONT_Z + 0.5)
					TweenService:Create(panel, TweenInfo.new(0.35), { CFrame = target }):Play()
				end
			end
		end
	end
end

-- O boneco inflável balança de um lado para o outro.
local function mascotLoop()
	local random = Random.new()
	while true do
		task.wait(0.7)
		for _, player in Players:GetPlayers() do
			local store = Plots.getStore(player)
			local mascot = store and store:FindFirstChild("Mascot")
			local origin = Plots.getOrigin(player)
			if mascot == nil or origin == nil then
				continue
			end
			for _, tube in mascot:GetChildren() do
				local baseY = tube:GetAttribute("BaseY")
				if tube:IsA("BasePart") and typeof(baseY) == "number" then
					local sway = (baseY - 2) * 0.12 * random:NextNumber(-1, 1)
					local target = origin
						* CFrame.new(32 + sway * 3, baseY, -30)
						* CFrame.Angles(0, 0, sway * 0.5)
					TweenService:Create(tube, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { CFrame = target })
						:Play()
				end
			end
		end
	end
end

-- Precisa rodar depois de Plots, Economy, Shelves, Cells e Door.
function Builds.start()
	notify = Remotes.get("Notify")
	Plots.onStoreReady(onStoreReady)
	Players.PlayerRemoving:Connect(function(player)
		lastTouch[player] = nil
	end)
	task.spawn(autoDoorLoop)
	task.spawn(mascotLoop)
end

return Builds
