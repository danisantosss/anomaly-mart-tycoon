--!strict
-- Bastão de choque (docs/V3.md, seção 9): a arma com que todo jogador começa.
--
-- O servidor cria a ferramenta "Shock Baton" no StarterPack, e o Roblox entrega uma cópia a cada jogador sempre
-- que ele nasce. O clique (Tool.Activated) chega no servidor, que confere tudo:
--   * acerta o monstro ofensivo mais perto à frente (StreetMonsters.hit) e tira vida até nocautear;
--   * perto do Colosso da Fenda, tira vida dele (vale o dobro);
--   * acerta um ladrão carregando anomalia roubada: ele deixa cair, e ela volta para a cela do dono.
-- Não machuca outros jogadores.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local RiftInvasion = require(script.Parent.RiftInvasion)
local Steal = require(script.Parent.Steal)
local StoreUpgrades = require(script.Parent.StoreUpgrades)
local StreetMonsters = require(script.Parent.StreetMonsters)

local Combat = Config.Combat

local TOOL_NAME = "Shock Baton"
local SPARK = Color3.fromRGB(120, 230, 255)
local GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, 0)
local SWING_GRIP = CFrame.new(0, -1, 0.4) * CFrame.Angles(math.rad(-80), 0, 0)

local Weapons = {}

local lastSwing: { [Player]: number } = {}
local template: Tool

local function makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Click to zap monsters and thieves"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = GRIP

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 3, 0.35)
	handle.Color = Color3.fromRGB(35, 35, 40)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Ponta azul brilhando e uma faixa amarela de "perigo".
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		part.CFrame = handle.CFrame * offset
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	local tip = piece("Tip", Vector3.new(0.5, 0.7, 0.5), CFrame.new(0, 1.7, 0), SPARK, Enum.Material.Neon)
	piece(
		"Stripe",
		Vector3.new(0.4, 0.25, 0.4),
		CFrame.new(0, -0.6, 0),
		Color3.fromRGB(255, 200, 40),
		Enum.Material.SmoothPlastic
	)
	local light = Instance.new("PointLight")
	light.Color = SPARK
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = tip
	return tool
end

-- Faísca rápida onde o golpe pegou.
local function spark(position: Vector3)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Material = Enum.Material.Neon
	ball.Color = SPARK
	ball.Size = Vector3.one * 1.2
	ball.Position = position
	ball.Parent = workspace
	TweenService:Create(ball, TweenInfo.new(0.25), { Size = Vector3.one * 4, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.3)
end

local function damageFor(player: Player): number
	return Combat.BATON_DAMAGE + StoreUpgrades.level(player, "ShockBaton") * Combat.BATON_DAMAGE_PER_LEVEL
end

-- Ladrão (carregando anomalia roubada) mais perto à frente.
local function zapThief(player: Player, origin: CFrame): Vector3?
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if other ~= player and root and root:IsA("BasePart") and Steal.isCarrying(other) then
			if (root.Position - origin.Position).Magnitude <= Combat.BATON_RANGE then
				if Steal.zap(other, player) then
					return root.Position
				end
			end
		end
	end
	return nil
end

local function swing(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Combat.BATON_COOLDOWN then
		return
	end
	lastSwing[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end

	-- Movimento do golpe: o Grip da ferramenta é replicado, então todo mundo vê o bastão descer.
	tool.Grip = SWING_GRIP
	task.delay(0.18, function()
		tool.Grip = GRIP
	end)

	local origin = root.CFrame
	local amount = damageFor(player)
	local front = origin.Position + origin.LookVector * 3
	local thief = zapThief(player, origin)
	if thief then
		spark(thief)
	elseif StreetMonsters.hit(player, origin, Combat.BATON_RANGE, amount) then
		spark(front)
	elseif RiftInvasion.hit(player, amount * Combat.BATON_BOSS_MULTIPLIER) then
		spark(front)
	end
end

local function watch(tool: Instance, player: Player)
	if tool:IsA("Tool") and tool.Name == TOOL_NAME and tool:GetAttribute("Wired") == nil then
		tool:SetAttribute("Wired", true)
		tool.Activated:Connect(function()
			swing(player, tool)
		end)
	end
end

local function onCharacter(player: Player, character: Model)
	-- A cópia do StarterPack vai para a mochila; quando o jogador equipa, ela passa para o personagem.
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		-- Quem nasceu antes de o bastão ir para o StarterPack (primeiro jogador no Studio) recebe na mão.
		task.wait(0.5)
		if backpack:FindFirstChild(TOOL_NAME) == nil and character:FindFirstChild(TOOL_NAME) == nil then
			template:Clone().Parent = backpack
		end
		for _, child in backpack:GetChildren() do
			watch(child, player)
		end
		backpack.ChildAdded:Connect(function(child)
			watch(child, player)
		end)
	end
	character.ChildAdded:Connect(function(child)
		watch(child, player)
	end)
end

function Weapons.start()
	template = makeTool()
	template.Parent = StarterPack
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return Weapons
