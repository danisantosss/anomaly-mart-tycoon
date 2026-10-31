--!strict
-- Transforma um boneco de cliente normal numa anomalia (docs/V1.md, seção 5).
-- Tudo por código, mexendo no boneco R15 do próprio Roblox: nada de modelo 3D externo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnomalyLooks = {}

local function find(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Mexe numa junta do boneco: `offset` é aplicado do lado da peça "de cima" (ex.: o tronco, no pescoço).
-- Funciona nos dois tipos de boneco R15: o antigo (juntas Motor6D) e o novo que o Roblox cria hoje
-- (juntas AnimationConstraint presas em Attachments).
local function shiftJoint(model: Model, name: string, offset: CFrame): boolean
	for _, joint in model:GetDescendants() do
		if joint.Name ~= name then
			continue
		end
		if joint:IsA("Motor6D") then
			joint.C0 = joint.C0 * offset
			return true
		elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
			local attachment = joint.Attachment0
			attachment.CFrame = attachment.CFrame * offset
			return true
		end
	end
	return false
end

local function weldTo(base: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = base.CFrame * offset
	part.Massless = true
	part.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = base
end

-- Apaga o rosto. No boneco antigo o rosto é um Decal; no novo, a cabeça é uma MeshPart com o rosto na
-- textura (SurfaceAppearance/TextureID) e FaceControls. Sem textura, fica só a cor da pele.
local function removeFace(model: Model)
	local head = find(model, "Head")
	if head == nil then
		return
	end
	for _, child in head:GetChildren() do
		if child:IsA("Decal") or child:IsA("SurfaceAppearance") or child:IsA("FaceControls") then
			child:Destroy()
		end
	end
	if head:IsA("MeshPart") then
		head.TextureID = ""
	end
end

local function blackPart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = Color3.new(0, 0, 0)
	part.Material = Enum.Material.SmoothPlastic
	return part
end

local SHAPES: { [string]: (Model) -> () } = {
	-- Pescoço esticado: a cabeça sobe e um "pescoço" da cor da pele preenche o espaço.
	LongNeck = function(model)
		local head = find(model, "Head")
		local torso = find(model, "UpperTorso")
		local stretch = 1.8
		if head == nil or torso == nil or not shiftJoint(model, "Neck", CFrame.new(0, stretch, 0)) then
			return
		end
		local segment = Instance.new("Part")
		segment.Name = "LongNeckSegment"
		segment.Size = Vector3.new(0.5, stretch + 0.4, 0.5)
		segment.Color = head.Color
		weldTo(torso, segment, CFrame.new(0, torso.Size.Y / 2 + (stretch + 0.4) / 2, 0))
	end,

	-- O corpo fica virado para trás enquanto anda para frente: parece que anda de costas.
	Backwards = function(model)
		shiftJoint(model, "Root", CFrame.Angles(0, math.pi, 0))
	end,

	NoFace = function(model)
		removeFace(model)
	end,

	-- A aparência já vem copiada de outro cliente (ver Customers.luau); aqui não muda nada.
	Twin = function(_model) end,

	-- Segura uma caixa branca de sal.
	SaltBuyer = function(model)
		local hand = find(model, "RightHand")
		if hand == nil then
			return
		end
		local box = Instance.new("Part")
		box.Name = "SaltBox"
		box.Size = Vector3.new(1, 1.4, 1)
		box.Color = Color3.new(1, 1, 1)
		weldTo(hand, box, CFrame.new(0, -0.7, -0.3))
	end,

	-- Sem rosto normal: olhos pretos pequenos e um sorriso largo demais. Sempre olha para o jogador mais
	-- perto quando está parado.
	Smiler = function(model)
		removeFace(model)
		local head = find(model, "Head")
		if head == nil then
			return
		end
		local front = -head.Size.Z / 2 - 0.02
		weldTo(
			head,
			blackPart("Smile", Vector3.new(head.Size.X * 0.95, 0.12, 0.05)),
			CFrame.new(0, -0.2, front)
		)
		for _, x in { -0.22, 0.22 } do
			weldTo(head, blackPart("Eye", Vector3.new(0.12, 0.12, 0.05)), CFrame.new(x, 0.15, front))
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local rootPart = model.PrimaryPart
		if humanoid == nil or rootPart == nil then
			return
		end
		local connection = RunService.Heartbeat:Connect(function()
			if humanoid.MoveDirection.Magnitude > 0.1 then
				return
			end
			local nearest: Vector3? = nil
			local best = 40
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local other = character and character.PrimaryPart
				if other then
					local distance = (other.Position - rootPart.Position).Magnitude
					if distance < best then
						best = distance
						nearest = other.Position
					end
				end
			end
			if nearest then
				local target = Vector3.new(nearest.X, rootPart.Position.Y, nearest.Z)
				rootPart.CFrame = CFrame.lookAt(rootPart.Position, target)
			end
		end)
		model.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end,
}

local function bodyParts(model: Model): { BasePart }
	local result = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			table.insert(result, child)
		end
	end
	return result
end

local VARIANTS: { [string]: (Model) -> () } = {
	Normal = function(_model) end,

	Shiny = function(model)
		local torso = find(model, "UpperTorso")
		if torso then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 220, 90)
			sparkles.Parent = torso
		end
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.8
		highlight.FillColor = Color3.fromRGB(255, 220, 90)
		highlight.OutlineColor = Color3.fromRGB(255, 220, 90)
		highlight.Parent = model
	end,

	Inverted = function(model)
		for _, part in bodyParts(model) do
			local color = part.Color
			part.Color = Color3.new(1 - color.R, 1 - color.G, 1 - color.B)
		end
	end,

	Giant = function(model)
		model:ScaleTo(1.5)
	end,

	-- Partes piscando em cores aleatórias.
	Glitch = function(model)
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 0, 200)
		highlight.Parent = model
		local parts = bodyParts(model)
		local alive = true
		model.Destroying:Connect(function()
			alive = false
		end)
		task.spawn(function()
			local random = Random.new()
			while alive do
				for _, part in parts do
					part.Color = Color3.fromHSV(random:NextNumber(), 1, 1)
					part.Material = if random:NextNumber() < 0.5
						then Enum.Material.Neon
						else Enum.Material.SmoothPlastic
				end
				task.wait(random:NextNumber(0.1, 0.4))
			end
		end)
	end,
}

-- Aplica a forma da anomalia `kind` e a variante `variant` no boneco. Pode ser chamado antes de colocar o
-- boneco no workspace.
function AnomalyLooks.apply(model: Model, kind: string, variant: string)
	local shape = SHAPES[kind]
	if shape then
		shape(model)
	end
	local look = VARIANTS[variant]
	if look then
		look(model)
	end
end

return AnomalyLooks
