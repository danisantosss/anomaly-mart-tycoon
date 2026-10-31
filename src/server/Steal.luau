--!strict
-- Roubo de anomalias da sala dos fundos dos outros (docs/V1.md, seção 6).
--
-- Fluxo: o ladrão segura "Steal" numa cela de outra loja. A anomalia some da cela do dono (mas continua nos
-- dados dele) e o ladrão fica lento e brilhando. Se ele chegar na sala dos fundos da própria loja com cela
-- livre, a anomalia passa para ele. Se o dono encostar nele, se ele morrer ou se alguém sair do jogo, o
-- roubo é cancelado e a anomalia volta para a cela do dono. Assim nunca dá para duplicar uma anomalia.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local BuildCatalog = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cells = require(script.Parent.Cells)
local Data = require(script.Parent.Data)
local Layout = require(script.Parent.Street.Layout)
local MonsterPowers = require(script.Parent.MonsterPowers)
local Plots = require(script.Parent.Plots)
local StoreUpgrades = require(script.Parent.StoreUpgrades)

local Settings = Config.Steal

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 100, 100)
local INFO = Color3.fromRGB(255, 230, 140)

type Carry = {
	owner: Player,
	cell: Data.CellData,
	marker: Instance,
}

local Steal = {}

local carrying: { [Player]: Carry } = {}
local notify: RemoteEvent

local function tell(player: Player, text: string, color: Color3)
	if player.Parent == Players then
		notify:FireClient(player, text, color)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function setSpeed(player: Player, speed: number)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Brilho vermelho e o nome da anomalia em cima da cabeça de quem está roubando: todo mundo vê.
local function makeMarker(thief: Player, cell: Data.CellData): Instance
	local folder = Instance.new("Folder")
	folder.Name = "StolenMarker"

	local character = thief.Character
	if character then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
		highlight.Adornee = character
		highlight.Parent = folder

		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(200, 40)
			billboard.StudsOffset = Vector3.new(0, 3, 0)
			billboard.Adornee = head
			billboard.AlwaysOnTop = true
			billboard.Parent = folder

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 90, 90)
			label.TextStrokeTransparency = 0.2
			label.Text = `STOLEN: {Anomalies.fullName(cell.Kind, cell.Variant)}`
			label.Parent = billboard
		end
		folder.Parent = character
	end
	return folder
end

local function finish(thief: Player)
	local carry = carrying[thief]
	if carry == nil then
		return
	end
	carrying[thief] = nil
	carry.marker:Destroy()
	thief:SetAttribute("CarryingStolen", nil)
	setSpeed(thief, StoreUpgrades.walkSpeed(thief))
end

-- Cancela: a anomalia volta para a cela do dono.
local function giveBack(thief: Player, reason: string)
	local carry = carrying[thief]
	if carry == nil then
		return
	end
	finish(thief)
	if carry.owner.Parent == Players then
		Cells.setHidden(carry.owner, carry.cell, false)
	end
	local name = Anomalies.fullName(carry.cell.Kind, carry.cell.Variant)
	tell(thief, `{reason} The {name} went back.`, BAD)
	tell(carry.owner, `{reason} Your {name} is back in its cell.`, GOOD)
end

local function deliver(thief: Player)
	local carry = carrying[thief]
	if carry == nil then
		return
	end
	if not Cells.hasFreeCell(thief) then
		giveBack(thief, "No free cell to keep it!")
		return
	end

	finish(thief)
	local kind, variant = carry.cell.Kind, carry.cell.Variant
	if Cells.removeCell(carry.owner, carry.cell) then
		Cells.tryAdd(thief, kind, variant)
		local name = Anomalies.fullName(kind, variant)
		tell(thief, `You stole a {name}!`, GOOD)
		tell(carry.owner, `{thief.DisplayName} stole your {name}!`, BAD)
	end
end

local function onPromptTriggered(prompt: ProximityPrompt, thief: Player)
	if prompt.Name ~= "StealPrompt" or carrying[thief] then
		return
	end

	local ownerId = prompt:GetAttribute("ExcludeUserId")
	local index = prompt:GetAttribute("CellIndex")
	if typeof(ownerId) ~= "number" or typeof(index) ~= "number" then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner == nil or owner == thief or Plots.getStore(thief) == nil then
		return
	end

	local cell = Cells.get(owner, index)
	if cell == nil or Cells.isHidden(cell) then
		return
	end

	-- O botão só funciona de perto, mas confere de novo no servidor.
	local root = rootOf(thief)
	local cellPart = prompt.Parent
	if root == nil or not cellPart or not cellPart:IsA("BasePart") then
		return
	end
	if (root.Position - cellPart.Position).Magnitude > prompt.MaxActivationDistance + 4 then
		return
	end

	Cells.setHidden(owner, cell, true)
	carrying[thief] = { owner = owner, cell = cell, marker = makeMarker(thief, cell) }
	thief:SetAttribute("CarryingStolen", true)
	-- Câmeras de segurança na loja roubada: o ladrão fica ainda mais lento.
	local ownerData = Data.get(owner)
	local cameras = ownerData ~= nil and BuildCatalog.has(ownerData.Builds, "cameras")
	-- The Tall One na cela do dono: mais lento ainda.
	local speed = if cameras then Settings.CARRY_SPEED_CAMERAS else Settings.CARRY_SPEED
	setSpeed(thief, speed * MonsterPowers.thiefSpeedMultiplier(owner))

	local name = Anomalies.fullName(cell.Kind, cell.Variant)
	tell(thief, `Run back to your store's back room with the {name}!`, INFO)
	tell(
		owner,
		if cameras
			then `CAMERAS: {thief.DisplayName} is stealing your {name}! They're slowed down, catch them!`
			else `{thief.DisplayName} is stealing your {name}! Catch them!`,
		BAD
	)
end

local function watchLoop()
	while true do
		task.wait(0.2)
		for thief, carry in carrying do
			local owner = carry.owner
			if thief.Parent ~= Players then
				carrying[thief] = nil
				if owner.Parent == Players then
					Cells.setHidden(owner, carry.cell, false)
				end
			elseif owner.Parent ~= Players then
				-- O dono saiu: os dados dele já foram salvos com a anomalia, então o roubo não vale mais.
				finish(thief)
				tell(thief, "The owner left. The stolen anomaly vanished.", INFO)
			else
				local thiefRoot = rootOf(thief)
				local ownerRoot = rootOf(owner)
				local humanoid = humanoidOf(thief)
				local origin = Plots.getOrigin(thief)
				if thiefRoot == nil or humanoid == nil or humanoid.Health <= 0 then
					giveBack(thief, "The thief went down!")
				elseif
					ownerRoot
					and (ownerRoot.Position - thiefRoot.Position).Magnitude < Settings.CATCH_DISTANCE
				then
					giveBack(thief, `{owner.DisplayName} caught {thief.DisplayName}!`)
				elseif origin and Layout.isInBackroom(origin, thiefRoot.Position) then
					deliver(thief)
				end
			end
		end
	end
end

-- Alguém acertou o ladrão com o bastão de choque: ele deixa cair a anomalia, que volta para a cela.
function Steal.zap(thief: Player, by: Player): boolean
	if carrying[thief] == nil or thief == by then
		return false
	end
	giveBack(thief, `{by.DisplayName} zapped {thief.DisplayName}!`)
	return true
end

function Steal.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Precisa rodar depois de Cells.start().
function Steal.start()
	notify = Remotes.get("Notify")
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	task.spawn(watchLoop)
end

return Steal
