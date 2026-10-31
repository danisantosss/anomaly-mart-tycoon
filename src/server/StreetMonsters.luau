--!strict
-- Monstros da rua (docs/V3.md, seção 3).
--
-- De tempos em tempos um monstro sai da Fenda (ponta oeste da Avenida) e anda pela faixa roxa até o Ralo de
-- Contenção (ponta leste), onde some. Cada um mostra o nome, a raridade, quanto rende e quanto custa.
-- Qualquer jogador pode segurar C perto dele para capturar: paga o preço, e o monstro corre sozinho até a
-- sala dos fundos de quem pagou e entra numa cela. É a mesma ideia de comprar unidades que passam no meio do
-- mapa dos tycoons de "Steal", com o nosso tema.
--
-- Regras:
--   * só captura quem tem cela livre (contando os monstros que ainda estão a caminho);
--   * se a cela não existir mais quando ele chegar (Franquia no meio do caminho), o dinheiro volta;
--   * se o jogador sair, o monstro some (o dinheiro já foi gasto, como numa compra normal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Cells = require(script.Parent.Cells)
local Data = require(script.Parent.Data)
local DayNight = require(script.Parent.DayNight)
local Economy = require(script.Parent.Economy)
local Layout = require(script.Parent.Street.Layout)
local Models = require(script.Parent.Monsters.Models)
local Plots = require(script.Parent.Plots)

local Settings = Config.StreetMonsters

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 100, 100)
local INFO = Color3.fromRGB(255, 230, 140)

type Wanderer = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	variant: string,
	lane: number, -- deslocamento em Z dentro da faixa
	claimedBy: Player?,
	status: TextLabel,
}

local StreetMonsters = {}

local wanderers: { Wanderer } = {}
local pending: { [Player]: number } = {} -- monstros pagos ainda a caminho, por jogador
local random = Random.new()
local folder: Folder
local notify: RemoteEvent

local function tell(player: Player, text: string, color: Color3)
	if player.Parent == Players then
		notify:FireClient(player, text, color)
	end
end

local function remove(wanderer: Wanderer)
	local index = table.find(wanderers, wanderer)
	if index then
		table.remove(wanderers, index)
	end
	if wanderer.model.Parent then
		wanderer.model:Destroy()
	end
end

-- Some afundando e encolhendo (no Ralo ou ao entrar na cela).
local function vanish(wanderer: Wanderer)
	local index = table.find(wanderers, wanderer)
	if index then
		table.remove(wanderers, index)
	end
	local model = wanderer.model
	if model.Parent == nil then
		return
	end
	wanderer.root.Anchored = true
	local start = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(alpha)
		if model.Parent then
			model:PivotTo(start * CFrame.new(0, -alpha * 6, 0) * CFrame.Angles(0, alpha * math.pi * 3, 0))
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		value:Destroy()
		model:Destroy()
	end)
	tween:Play()
end

local function makeBillboard(wanderer: Wanderer, height: number): TextLabel
	local definition = Anomalies.get(wanderer.kind)
	local rarity = if definition then definition.rarity else "Common"
	local color = Anomalies.RARITY_COLORS[rarity]

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.fromOffset(220, 86)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height + 1.5, 0)
	billboard.MaxDistance = 110
	billboard.LightInfluence = 0
	billboard.Parent = wanderer.root

	local function line(text: string, order: number, textColor: Color3, scale: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, scale)
		label.Position = UDim2.fromScale(0, order)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = textColor
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = billboard
		return label
	end

	line(string.upper(rarity), 0, color, 0.2)
	line(Anomalies.fullName(wanderer.kind, wanderer.variant), 0.2, Color3.new(1, 1, 1), 0.3)
	line(`{NumberFormat.cash(Anomalies.income(wanderer.kind, wanderer.variant))}/s`, 0.5, GOOD, 0.22)
	return line(NumberFormat.cash(Anomalies.captureCost(wanderer.kind, wanderer.variant)), 0.72, INFO, 0.26)
end

local function freeCells(player: Player): number
	return Cells.capacity(player) - Cells.count(player) - (pending[player] or 0)
end

-- Corre até a sala dos fundos de quem pagou e entra numa cela.
local function deliver(wanderer: Wanderer, player: Player, cost: number)
	local humanoid = wanderer.humanoid
	humanoid.WalkSpeed = Settings.DELIVERY_SPEED

	local arrived = false
	for _ = 1, 30 do
		local origin = Plots.getOrigin(player)
		if origin == nil or player.Parent ~= Players or wanderer.model.Parent == nil then
			break
		end
		local target = origin:PointToWorldSpace(Layout.backroomCenter())
		if (wanderer.root.Position * Vector3.new(1, 0, 1) - target * Vector3.new(1, 0, 1)).Magnitude < 4 then
			arrived = true
			break
		end
		humanoid:MoveTo(target)
		task.wait(0.5)
	end

	pending[player] = math.max(0, (pending[player] or 1) - 1)
	if not arrived or player.Parent ~= Players then
		remove(wanderer)
		return
	end
	if Cells.tryAdd(player, wanderer.kind, wanderer.variant) then
		local data = Data.get(player)
		if data then
			data.TotalCaptured += 1
		end
		tell(player, `{Anomalies.fullName(wanderer.kind, wanderer.variant)} is in your cell!`, GOOD)
		Analytics.step(player, "FirstCapture")
	else
		Economy.addCash(player, cost)
		tell(player, "No free cell when it arrived. Your money was returned.", INFO)
	end
	vanish(wanderer)
end

local function capture(wanderer: Wanderer, player: Player)
	if wanderer.claimedBy ~= nil or wanderer.model.Parent == nil then
		return
	end
	if Plots.getStore(player) == nil or Data.get(player) == nil then
		return
	end
	if Cells.capacity(player) == 0 then
		tell(player, "Build the Back Room first: monsters need a cell!", INFO)
		return
	end
	if freeCells(player) <= 0 then
		tell(player, "All your cells are full! Buy more cells.", INFO)
		return
	end
	local cost = Anomalies.captureCost(wanderer.kind, wanderer.variant)
	if not Economy.trySpend(player, cost) then
		tell(player, `You need {NumberFormat.cash(cost)} to capture it. Collect your safe!`, BAD)
		return
	end

	wanderer.claimedBy = player
	pending[player] = (pending[player] or 0) + 1
	Analytics.spend(player, cost, "Shop", `Monster_{wanderer.kind}_{wanderer.variant}`)
	local prompt = wanderer.root:FindFirstChild("CapturePrompt")
	if prompt then
		prompt:Destroy()
	end
	wanderer.status.Text = `→ {player.DisplayName}`
	wanderer.status.TextColor3 = GOOD
	tell(
		player,
		`Captured {Anomalies.fullName(wanderer.kind, wanderer.variant)}! It's running to your Back Room.`,
		GOOD
	)
	task.spawn(deliver, wanderer, player, cost)
end

-- Anda pela faixa até o Ralo. Para no meio se alguém capturar.
local function walkLane(wanderer: Wanderer)
	local step = 30
	local x = wanderer.root.Position.X
	while x < Layout.DRAIN_X and wanderer.claimedBy == nil and wanderer.model.Parent do
		x = math.min(x + step, Layout.DRAIN_X)
		local target = Vector3.new(x, 0, wanderer.lane)
		wanderer.humanoid:MoveTo(target)
		local deadline = os.clock() + step / Settings.WALK_SPEED + 3
		while
			wanderer.claimedBy == nil
			and wanderer.model.Parent
			and os.clock() < deadline
			and math.abs(wanderer.root.Position.X - x) > 2
		do
			task.wait(0.25)
		end
	end
	if wanderer.claimedBy == nil then
		vanish(wanderer)
	end
end

local function luck(): (number, number)
	if DayNight.isRedMoon() then
		return Settings.LUCK_RED_MOON, Config.RedMoon.RARE_VARIANT_LUCK
	elseif DayNight.isNight() then
		return Settings.LUCK_NIGHT, Settings.VARIANT_LUCK_NIGHT
	end
	return 1, 1
end

local function spawnOne(startX: number?)
	if #wanderers >= Settings.MAX_ON_STREET then
		return
	end
	local rarityLuck, variantLuck = luck()
	local definition = Anomalies.pickStreet(random, rarityLuck)
	local variant = Anomalies.pickVariant(random, variantLuck).id

	local model = Models.build(definition.id, variant, true)
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Settings.WALK_SPEED
	local lane = random:NextNumber(-Layout.LANE_HALF_WIDTH + 1.5, Layout.LANE_HALF_WIDTH - 1.5)

	-- Mede a altura antes de mover, para o letreiro ficar logo acima da cabeça.
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2 - root.Position.Y
	-- De onde sai: posição dada (monstros iniciais), um bueiro no meio da rua ou a Fenda.
	local manhole: number? = nil
	if startX == nil and random:NextNumber() < Settings.MANHOLE_CHANCE then
		manhole = random:NextInteger(1, #Layout.MANHOLES)
	end
	local x = startX or (if manhole then Layout.MANHOLES[manhole] else Layout.RIFT_X)
	local z = if manhole then 0 else lane
	local standing =
		CFrame.lookAt(Vector3.new(x, root.Position.Y, z), Vector3.new(x + 10, root.Position.Y, z))
	if manhole then
		-- Sobe do bueiro: começa enterrado e ancorado, e o tween levanta até a altura normal.
		root.Anchored = true
		model:PivotTo(standing * CFrame.new(0, -root.Position.Y - 4, 0))
	else
		model:PivotTo(standing)
	end
	model.Parent = folder

	local wanderer: Wanderer = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = definition.id,
		variant = variant,
		lane = lane,
		claimedBy = nil,
		status = nil :: any,
	}
	wanderer.status = makeBillboard(wanderer, top)
	table.insert(wanderers, wanderer)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CapturePrompt"
	prompt.ActionText = "Capture"
	prompt.ObjectText = NumberFormat.cash(Anomalies.captureCost(definition.id, variant))
	prompt.KeyboardKeyCode = Enum.KeyCode.C
	prompt.HoldDuration = Settings.CAPTURE_HOLD_SECONDS
	prompt.MaxActivationDistance = 12 + boxSize.X / 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		capture(wanderer, player)
	end)

	-- Faísca no portal da Fenda.
	local street = workspace:FindFirstChild("Street")
	if manhole then
		local lid = street and street:FindFirstChild(`Manhole{manhole}`, true)
		local steam = lid and lid:FindFirstChild("Steam")
		if steam and steam:IsA("ParticleEmitter") then
			steam:Emit(40)
		end
	else
		local burst = street and street:FindFirstChild("RiftBurst", true)
		if startX == nil and burst and burst:IsA("ParticleEmitter") then
			burst:Emit(30)
		end
	end

	if Settings.ANNOUNCE[definition.rarity] then
		notify:FireAllClients(
			`A {string.upper(definition.rarity)} {Anomalies.fullName(definition.id, variant)} crawled out of the Rift!`,
			Anomalies.RARITY_COLORS[definition.rarity]
		)
	end

	humanoid.Died:Connect(function()
		remove(wanderer)
	end)
	task.spawn(function()
		if manhole then
			local start = model:GetPivot()
			local rise = Instance.new("NumberValue")
			rise.Changed:Connect(function(alpha)
				if model.Parent then
					model:PivotTo(start:Lerp(standing, alpha))
				end
			end)
			local tween = TweenService:Create(
				rise,
				TweenInfo.new(1.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Value = 1 }
			)
			tween:Play()
			tween.Completed:Wait()
			rise:Destroy()
			if model.Parent == nil then
				return
			end
			root.Anchored = false
		end
		root:SetNetworkOwner(nil) -- o servidor controla, sem engasgos
		walkLane(wanderer)
	end)
end

local function spawnInterval(): number
	if DayNight.isRedMoon() then
		return Settings.SPAWN_SECONDS_RED_MOON
	elseif DayNight.isNight() then
		return Settings.SPAWN_SECONDS_NIGHT
	end
	return Settings.SPAWN_SECONDS_DAY
end

function StreetMonsters.start()
	notify = Remotes.get("Notify")
	folder = Instance.new("Folder")
	folder.Name = "StreetMonsters"
	folder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)

	task.spawn(function()
		-- Começa com alguns já andando, para a rua não estar vazia quando o primeiro jogador chega.
		local length = Layout.DRAIN_X - Layout.RIFT_X
		for index = 1, 6 do
			spawnOne(Layout.RIFT_X + length * (index - 0.5) / 7)
		end
		while true do
			task.wait(spawnInterval())
			local ok, problem = pcall(spawnOne)
			if not ok then
				warn(`[StreetMonsters] {problem}`)
			end
		end
	end)
end

return StreetMonsters
