--!strict
-- Cria o boneco de um cliente: R15 do próprio Roblox com pele, roupa, corpo e acessórios sorteados
-- (docs/V3.md, seção 4). Usado pelos clientes andando na loja e pelas anomalias expostas nas celas.
--
-- O visual vem de duas fontes:
--   * itens do catálogo do Roblox (cabelo, chapéu, roupa...) listados em Config.CustomerLooks, quando houver;
--   * acessórios feitos de Parts (cabelo, boné, óculos, barba, mochila, sacola), que sempre funcionam.
-- Tudo sai de uma semente guardada na HumanoidDescription ("LookSeed"): a The Twin copia a descrição de outro
-- cliente e fica idêntica, acessórios inclusive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CustomerModel = {}

CustomerModel.COLLISION_GROUP = "Customers"

local SKIN_TONES = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(92, 56, 32),
}

local SHIRTS = {
	Color3.fromRGB(52, 101, 164),
	Color3.fromRGB(204, 60, 60),
	Color3.fromRGB(78, 154, 86),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(140, 100, 170),
	Color3.fromRGB(240, 240, 236),
	Color3.fromRGB(245, 140, 60),
	Color3.fromRGB(90, 190, 200),
	Color3.fromRGB(230, 120, 160),
	Color3.fromRGB(60, 60, 70),
}

local PANTS = {
	Color3.fromRGB(40, 60, 110), -- jeans
	Color3.fromRGB(30, 40, 80),
	Color3.fromRGB(46, 46, 52),
	Color3.fromRGB(110, 90, 70),
	Color3.fromRGB(150, 140, 110),
	Color3.fromRGB(90, 100, 90),
}

local HAIR = {
	Color3.fromRGB(30, 22, 18),
	Color3.fromRGB(70, 45, 25),
	Color3.fromRGB(120, 80, 40),
	Color3.fromRGB(220, 190, 120),
	Color3.fromRGB(160, 60, 30),
	Color3.fromRGB(200, 200, 205),
	Color3.fromRGB(230, 100, 160), -- cabelo pintado
	Color3.fromRGB(80, 140, 230),
}

local CAPS = {
	Color3.fromRGB(200, 40, 40),
	Color3.fromRGB(30, 60, 140),
	Color3.fromRGB(30, 30, 34),
	Color3.fromRGB(240, 240, 235),
	Color3.fromRGB(60, 140, 70),
}

local random = Random.new()

local function pick<T>(list: { T }, from: Random): T
	return list[from:NextInteger(1, #list)]
end

-- Um item do catálogo de Config.CustomerLooks[slot], ou nil se a lista estiver vazia ou não sorteou.
local function catalogItem(slot: string, chance: number, from: Random): number?
	local looks = (Config :: any).CustomerLooks
	local list = looks and looks[slot]
	if list == nil or #list == 0 or from:NextNumber() > chance then
		return nil
	end
	return list[from:NextInteger(1, #list)]
end

function CustomerModel.randomDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local seed = random:NextInteger(1, 2 ^ 30)
	local look = Random.new(seed)
	description:SetAttribute("LookSeed", seed)

	local skin = pick(SKIN_TONES, look)
	local shirt = pick(SHIRTS, look)
	local pants = pick(PANTS, look)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants

	-- Corpos diferentes: altos, baixos, mais largos, mais magros.
	description.HeightScale = look:NextNumber(0.88, 1.08)
	description.WidthScale = look:NextNumber(0.85, 1.05)
	description.DepthScale = look:NextNumber(0.9, 1.05)
	description.HeadScale = look:NextNumber(0.95, 1.05)
	description.BodyTypeScale = look:NextNumber(0, 0.3)
	description.ProportionScale = look:NextNumber(0, 0.6)

	-- Itens do catálogo (se a lista estiver configurada).
	local hair = catalogItem("Hair", 0.85, look)
	if hair then
		description.HairAccessory = tostring(hair)
		description:SetAttribute("CatalogHair", true)
	end
	local hat = catalogItem("Hats", 0.3, look)
	if hat then
		description.HatAccessory = tostring(hat)
	end
	local glasses = catalogItem("Glasses", 0.2, look)
	if glasses then
		description.FaceAccessory = tostring(glasses)
	end
	local shirtId = catalogItem("Shirts", 0.85, look)
	local pantsId = catalogItem("Pants", 0.85, look)
	if shirtId and pantsId then
		description.Shirt = shirtId
		description.Pants = pantsId
	end
	local face = catalogItem("Faces", 0.8, look)
	if face then
		description.Face = face
	end
	return description
end

-- Peça de acessório presa (solda) numa parte do corpo.
local function attach(
	model: Model,
	bodyPart: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function ellipsoid(part: Part): Part
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Acessórios feitos de Parts: cabelo, boné/gorro, óculos, barba, mochila ou sacola de compras.
local function decorate(model: Model, look: Random, catalogHair: boolean)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local hand = model:FindFirstChild("RightHand")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local size = head.Size
	local w, h, d = size.X, size.Y, size.Z
	local hairColor = pick(HAIR, look)

	-- Cabelo (se não veio do catálogo).
	if not catalogHair and look:NextNumber() < 0.9 then
		local style = look:NextInteger(1, 5)
		if style == 1 then -- curto
			ellipsoid(
				attach(
					model,
					head,
					"Hair",
					Vector3.new(w * 1.08, h * 0.55, d * 1.1),
					CFrame.new(0, h * 0.3, d * 0.04),
					hairColor
				)
			)
		elseif style == 2 then -- franja
			ellipsoid(
				attach(
					model,
					head,
					"Hair",
					Vector3.new(w * 1.1, h * 0.6, d * 1.12),
					CFrame.new(0, h * 0.28, d * 0.06),
					hairColor
				)
			)
			attach(
				model,
				head,
				"Bangs",
				Vector3.new(w * 0.9, h * 0.22, d * 0.2),
				CFrame.new(0, h * 0.32, -d * 0.48) * CFrame.Angles(math.rad(-20), 0, 0),
				hairColor
			)
		elseif style == 3 then -- comprido
			ellipsoid(
				attach(
					model,
					head,
					"Hair",
					Vector3.new(w * 1.12, h * 0.62, d * 1.14),
					CFrame.new(0, h * 0.27, d * 0.05),
					hairColor
				)
			)
			attach(
				model,
				head,
				"HairBack",
				Vector3.new(w * 1.05, h * 1.1, d * 0.3),
				CFrame.new(0, -h * 0.15, d * 0.48),
				hairColor
			)
		elseif style == 4 then -- rabo de cavalo
			ellipsoid(
				attach(
					model,
					head,
					"Hair",
					Vector3.new(w * 1.08, h * 0.55, d * 1.1),
					CFrame.new(0, h * 0.3, d * 0.04),
					hairColor
				)
			)
			ellipsoid(
				attach(
					model,
					head,
					"Ponytail",
					Vector3.new(w * 0.35, h * 0.8, d * 0.35),
					CFrame.new(0, h * 0.05, d * 0.62) * CFrame.Angles(math.rad(20), 0, 0),
					hairColor
				)
			)
		else -- espetado
			for index = -1, 1 do
				attach(
					model,
					head,
					"Spike",
					Vector3.new(w * 0.3, h * 0.45, d * 0.3),
					CFrame.new(index * w * 0.28, h * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-index * 20)),
					hairColor,
					nil,
					nil
				)
			end
			ellipsoid(
				attach(
					model,
					head,
					"Hair",
					Vector3.new(w * 1.05, h * 0.5, d * 1.05),
					CFrame.new(0, h * 0.32, 0),
					hairColor
				)
			)
		end
	end

	-- Boné ou gorro.
	local hatRoll = look:NextNumber()
	if hatRoll < 0.22 then
		local cap = pick(CAPS, look)
		ellipsoid(
			attach(
				model,
				head,
				"Cap",
				Vector3.new(w * 1.12, h * 0.5, d * 1.12),
				CFrame.new(0, h * 0.4, 0),
				cap
			)
		)
		attach(
			model,
			head,
			"Brim",
			Vector3.new(w * 0.9, h * 0.06, d * 0.55),
			CFrame.new(0, h * 0.32, -d * 0.62),
			cap
		)
	elseif hatRoll < 0.32 then
		local beanie = pick(SHIRTS, look)
		ellipsoid(
			attach(
				model,
				head,
				"Beanie",
				Vector3.new(w * 1.15, h * 0.62, d * 1.15),
				CFrame.new(0, h * 0.35, 0),
				beanie,
				nil,
				Enum.Material.Fabric
			)
		)
		attach(
			model,
			head,
			"Pompom",
			Vector3.one * w * 0.3,
			CFrame.new(0, h * 0.72, 0),
			Color3.new(1, 1, 1),
			Enum.PartType.Ball,
			Enum.Material.Fabric
		)
	end

	-- Óculos.
	if look:NextNumber() < 0.25 then
		local frame = if look:NextNumber() < 0.5
			then Color3.fromRGB(20, 20, 24)
			else Color3.fromRGB(150, 60, 40)
		for _, side in { -1, 1 } do
			local lens = attach(
				model,
				head,
				"Lens",
				Vector3.new(w * 0.28, h * 0.2, 0.05),
				CFrame.new(side * w * 0.2, h * 0.08, -d * 0.52),
				Color3.fromRGB(180, 210, 230),
				nil,
				Enum.Material.Glass
			)
			lens.Transparency = 0.4
			attach(
				model,
				head,
				"Rim",
				Vector3.new(w * 0.3, h * 0.04, 0.06),
				CFrame.new(side * w * 0.2, h * 0.19, -d * 0.53),
				frame
			)
		end
		attach(
			model,
			head,
			"Bridge",
			Vector3.new(w * 0.14, h * 0.03, 0.05),
			CFrame.new(0, h * 0.12, -d * 0.53),
			frame
		)
	end

	-- Barba.
	if look:NextNumber() < 0.15 then
		ellipsoid(
			attach(
				model,
				head,
				"Beard",
				Vector3.new(w * 0.8, h * 0.45, d * 0.4),
				CFrame.new(0, -h * 0.3, -d * 0.38),
				hairColor
			)
		)
	end

	-- Mochila nas costas ou sacola de compras na mão.
	local carry = look:NextNumber()
	if carry < 0.18 and torso and torso:IsA("BasePart") then
		local bag = pick(SHIRTS, look)
		local t = torso.Size
		attach(
			model,
			torso,
			"Backpack",
			Vector3.new(t.X * 0.7, t.Y * 0.85, t.Z * 0.6),
			CFrame.new(0, 0, t.Z * 0.75),
			bag,
			nil,
			Enum.Material.Fabric
		)
	elseif carry < 0.35 and hand and hand:IsA("BasePart") then
		attach(
			model,
			hand,
			"ShoppingBag",
			Vector3.new(0.9, 1.1, 0.5),
			CFrame.new(0, -0.75, 0),
			Color3.fromRGB(240, 235, 225),
			nil,
			Enum.Material.Fabric
		)
	end
end

-- Animações padrão de andar e de ficar parado do R15 (feitas pelo próprio Roblox).
local WALK_ANIMATION = "rbxassetid://507777826"
local IDLE_ANIMATION = "rbxassetid://507766388"

local function loadTrack(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	return if ok then track else nil
end

-- Faz o boneco mexer as pernas quando anda e respirar quando está parado. Chamar depois de colocar o
-- boneco no workspace. Sem isso os clientes "deslizam" pela loja.
function CustomerModel.animate(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local walk = loadTrack(animator :: Animator, WALK_ANIMATION)
	local idle = loadTrack(animator :: Animator, IDLE_ANIMATION)
	if walk == nil or idle == nil then
		return
	end
	idle.Looped = true
	walk.Looped = true
	idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				idle:Stop(0.2)
			end
		elseif walk.IsPlaying then
			walk:Stop(0.2)
			idle:Play(0.2)
		end
	end)
end

-- Cria o boneco a partir de uma aparência (ou uma aleatória). Pode demorar um instante.
function CustomerModel.build(description: HumanoidDescription?): Model
	local used = description or CustomerModel.randomDescription()
	local model = Players:CreateHumanoidModelFromDescription(used, Enum.HumanoidRigType.R15)
	model.Name = "Customer"

	local seed = used:GetAttribute("LookSeed")
	local catalogHair = used:GetAttribute("CatalogHair") == true
	if typeof(seed) == "number" then
		decorate(model, Random.new(seed + 7), catalogHair)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.Customers.WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CustomerModel.COLLISION_GROUP
		end
	end

	return model
end

return CustomerModel
