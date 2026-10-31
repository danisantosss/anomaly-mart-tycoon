--!strict
-- Objetos de decoração da Avenida (docs/V3.md, seção 2): postes, árvores, carros, prédios, bancos, placas...
-- Cada função recebe o CFrame no chão (Y = 0) e uma pasta. Tudo ancorado, feito só de Parts.

local CollectionService = game:GetService("CollectionService")

local Parts = require(script.Parent.Parts)

local Decor = {}

local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local CONCRETE = Enum.Material.Concrete

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local made = Parts.make({
		name = name,
		size = size,
		cframe = cframe,
		color = color,
		material = material,
		canCollide = if collide == nil then true else collide,
		parent = parent,
	})
	return made
end

local function cylinder(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	-- O eixo do cilindro é o X da peça; o CFrame recebido aponta o eixo para cima.
	local made = part(
		parent,
		name,
		Vector3.new(length, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	made.Shape = Enum.PartType.Cylinder
	return made
end

local function ball(
	parent: Instance,
	name: string,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local made = part(parent, name, Vector3.one * diameter, cframe, color, material, false)
	made.Shape = Enum.PartType.Ball
	return made
end

-- Texto numa face da peça (letreiro).
function Decor.sign(
	target: BasePart,
	text: string,
	textColor: Color3,
	background: Color3?,
	face: Enum.NormalId?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new()
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = label
	return label
end

-- Poste de luz com o braço virado para a frente do CFrame (-Z).
function Decor.lamp(cframe: CFrame, parent: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Lamp"
	local pole = Color3.fromRGB(40, 44, 52)
	cylinder(folder, "Base", 1, 1.6, cframe * CFrame.new(0, 0.5, 0), pole, METAL)
	cylinder(folder, "Pole", 15, 0.6, cframe * CFrame.new(0, 8, 0), pole, METAL)
	part(folder, "Arm", Vector3.new(0.4, 0.4, 4), cframe * CFrame.new(0, 15.3, -1.8), pole, METAL)
	local head = part(
		folder,
		"Head",
		Vector3.new(1.6, 0.5, 2),
		cframe * CFrame.new(0, 15, -3.6),
		Color3.fromRGB(255, 236, 190),
		NEON,
		false
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 32
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Shadows = false
	light.Parent = head
	folder.Parent = parent
end

local LEAVES = {
	Color3.fromRGB(72, 140, 62),
	Color3.fromRGB(58, 120, 56),
	Color3.fromRGB(96, 160, 70),
	Color3.fromRGB(120, 90, 160), -- de vez em quando uma árvore "estranha", roxa
}

function Decor.tree(cframe: CFrame, parent: Instance, random: Random)
	local folder = Instance.new("Model")
	folder.Name = "Tree"
	local height = random:NextNumber(9, 15)
	cylinder(
		folder,
		"Trunk",
		height,
		random:NextNumber(1.2, 1.8),
		cframe * CFrame.new(0, height / 2, 0),
		Color3.fromRGB(100, 70, 45),
		Enum.Material.Wood
	)
	local color = if random:NextNumber() < 0.08 then LEAVES[4] else LEAVES[random:NextInteger(1, 3)]
	for index = 1, random:NextInteger(3, 5) do
		local size = random:NextNumber(5, 9)
		local offset = Vector3.new(
			random:NextNumber(-2.5, 2.5),
			height + random:NextNumber(-1, 3),
			random:NextNumber(-2.5, 2.5)
		)
		ball(folder, `Leaves{index}`, size, cframe * CFrame.new(offset), color, Enum.Material.Grass)
	end
	folder.Parent = parent
end

function Decor.bush(cframe: CFrame, parent: Instance, random: Random)
	local color = LEAVES[random:NextInteger(1, 3)]
	for index = 1, 3 do
		local size = random:NextNumber(2.5, 4)
		ball(
			parent,
			"Bush",
			size,
			cframe * CFrame.new((index - 2) * 1.8, size / 2 - 0.4, random:NextNumber(-0.6, 0.6)),
			color,
			Enum.Material.Grass
		)
	end
end

function Decor.bench(cframe: CFrame, parent: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Bench"
	local wood = Color3.fromRGB(150, 100, 60)
	local iron = Color3.fromRGB(35, 38, 44)
	part(folder, "Seat", Vector3.new(6, 0.4, 1.8), cframe * CFrame.new(0, 1.8, 0), wood, Enum.Material.Wood)
	part(
		folder,
		"Back",
		Vector3.new(6, 1.6, 0.3),
		cframe * CFrame.new(0, 2.9, 0.9) * CFrame.Angles(math.rad(-10), 0, 0),
		wood,
		Enum.Material.Wood
	)
	for _, x in { -2.6, 2.6 } do
		part(folder, "Leg", Vector3.new(0.3, 1.8, 1.8), cframe * CFrame.new(x, 0.9, 0), iron, METAL)
	end
	folder.Parent = parent
end

function Decor.trashCan(cframe: CFrame, parent: Instance)
	cylinder(parent, "TrashCan", 3, 2, cframe * CFrame.new(0, 1.5, 0), Color3.fromRGB(46, 110, 70), METAL)
	cylinder(parent, "TrashLid", 0.3, 2.2, cframe * CFrame.new(0, 3.15, 0), Color3.fromRGB(36, 90, 56), METAL)
end

function Decor.hydrant(cframe: CFrame, parent: Instance)
	local red = Color3.fromRGB(200, 40, 40)
	cylinder(parent, "Hydrant", 2.2, 1, cframe * CFrame.new(0, 1.1, 0), red, METAL)
	ball(parent, "HydrantCap", 1.1, cframe * CFrame.new(0, 2.3, 0), red, METAL)
	part(
		parent,
		"HydrantSide",
		Vector3.new(1.6, 0.4, 0.4),
		cframe * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(230, 200, 60),
		METAL,
		false
	)
end

local CAR_COLORS = {
	Color3.fromRGB(200, 50, 50),
	Color3.fromRGB(40, 90, 180),
	Color3.fromRGB(240, 240, 235),
	Color3.fromRGB(30, 30, 34),
	Color3.fromRGB(240, 190, 40),
	Color3.fromRGB(70, 150, 90),
	Color3.fromRGB(140, 140, 150),
}

-- Carro estacionado, de frente para -Z.
function Decor.car(cframe: CFrame, parent: Instance, random: Random)
	local folder = Instance.new("Model")
	folder.Name = "Car"
	local color = CAR_COLORS[random:NextInteger(1, #CAR_COLORS)]
	part(
		folder,
		"Body",
		Vector3.new(5.2, 1.8, 10),
		cframe * CFrame.new(0, 1.7, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	part(
		folder,
		"Cabin",
		Vector3.new(4.6, 1.7, 5),
		cframe * CFrame.new(0, 3.4, 0.6),
		color,
		Enum.Material.SmoothPlastic
	)
	local glass = part(
		folder,
		"Glass",
		Vector3.new(4.7, 1.3, 5.1),
		cframe * CFrame.new(0, 3.4, 0.6),
		Color3.fromRGB(150, 190, 220),
		Enum.Material.Glass,
		false
	)
	glass.Transparency = 0.3
	for _, x in { -2.3, 2.3 } do
		for _, z in { -3.2, 3.2 } do
			local wheel = part(
				folder,
				"Wheel",
				Vector3.new(0.8, 2, 2),
				cframe * CFrame.new(x, 1, z),
				Color3.fromRGB(20, 20, 22),
				Enum.Material.SmoothPlastic,
				false
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	for _, x in { -1.8, 1.8 } do
		part(
			folder,
			"Headlight",
			Vector3.new(1, 0.5, 0.2),
			cframe * CFrame.new(x, 1.9, -5.05),
			Color3.fromRGB(255, 250, 220),
			NEON,
			false
		)
		part(
			folder,
			"Taillight",
			Vector3.new(1, 0.4, 0.2),
			cframe * CFrame.new(x, 1.9, 5.05),
			Color3.fromRGB(200, 20, 20),
			NEON,
			false
		)
	end
	folder.Parent = parent
end

function Decor.dumpster(cframe: CFrame, parent: Instance)
	part(
		parent,
		"Dumpster",
		Vector3.new(7, 4, 4),
		cframe * CFrame.new(0, 2, 0),
		Color3.fromRGB(40, 90, 60),
		METAL
	)
	part(
		parent,
		"DumpsterLid",
		Vector3.new(7.2, 0.3, 4.2),
		cframe * CFrame.new(0, 4.2, 0.2) * CFrame.Angles(math.rad(-8), 0, 0),
		Color3.fromRGB(30, 30, 34),
		METAL
	)
end

local BUILDING_COLORS = {
	Color3.fromRGB(150, 90, 70),
	Color3.fromRGB(110, 110, 120),
	Color3.fromRGB(200, 180, 150),
	Color3.fromRGB(80, 90, 110),
	Color3.fromRGB(170, 120, 90),
	Color3.fromRGB(60, 70, 80),
}

-- Prédio de fundo. A frente (-Z) tem faixas de janelas e algumas janelas acesas que brilham de noite.
function Decor.building(
	cframe: CFrame,
	parent: Instance,
	random: Random,
	width: number,
	depth: number,
	height: number
)
	local folder = Instance.new("Model")
	folder.Name = "Building"
	local color = BUILDING_COLORS[random:NextInteger(1, #BUILDING_COLORS)]
	part(
		folder,
		"Block",
		Vector3.new(width, height, depth),
		cframe * CFrame.new(0, height / 2, 0),
		color,
		if random:NextNumber() < 0.5 then Enum.Material.Brick else CONCRETE
	)
	part(
		folder,
		"Roof",
		Vector3.new(width + 1, 1, depth + 1),
		cframe * CFrame.new(0, height + 0.5, 0),
		Color3.fromRGB(50, 50, 55),
		CONCRETE
	)
	local floor = 8
	for level = 1, math.floor((height - 6) / floor) do
		local y = 4 + level * floor - 2
		part(
			folder,
			"Windows",
			Vector3.new(width - 3, 3.4, 0.4),
			cframe * CFrame.new(0, y, -depth / 2 - 0.1),
			Color3.fromRGB(40, 50, 70),
			Enum.Material.Glass,
			false
		)
		-- Algumas janelas acesas.
		for _ = 1, random:NextInteger(0, 2) do
			local x = random:NextNumber(-width / 2 + 3, width / 2 - 3)
			part(
				folder,
				"LitWindow",
				Vector3.new(2.6, 3, 0.2),
				cframe * CFrame.new(x, y, -depth / 2 - 0.35),
				Color3.fromRGB(255, 220, 140),
				NEON,
				false
			)
		end
	end
	if random:NextNumber() < 0.35 then
		-- Caixa d'água no telhado.
		cylinder(
			folder,
			"WaterTank",
			5,
			5,
			cframe * CFrame.new(width / 4, height + 4, 0),
			Color3.fromRGB(130, 90, 60),
			Enum.Material.Wood
		)
	else
		part(
			folder,
			"AirUnit",
			Vector3.new(4, 2.5, 4),
			cframe * CFrame.new(-width / 5, height + 2.2, depth / 6),
			Color3.fromRGB(170, 175, 180),
			METAL
		)
	end
	folder.Parent = parent
end

-- Placa grande de propaganda, com a face virada para -Z.
function Decor.billboard(
	cframe: CFrame,
	parent: Instance,
	text: string,
	textColor: Color3,
	background: Color3
)
	local folder = Instance.new("Model")
	folder.Name = "Billboard"
	local post = Color3.fromRGB(50, 52, 60)
	for _, x in { -5, 5 } do
		part(folder, "Post", Vector3.new(0.8, 14, 0.8), cframe * CFrame.new(x, 7, 0.6), post, METAL)
	end
	local board = part(
		folder,
		"Board",
		Vector3.new(18, 8, 0.6),
		cframe * CFrame.new(0, 16, 0),
		background,
		Enum.Material.SmoothPlastic
	)
	Decor.sign(board, text, textColor, background)
	part(folder, "Frame", Vector3.new(18.6, 8.6, 0.4), cframe * CFrame.new(0, 16, 0.4), post, METAL)
	folder.Parent = parent
end

-- Boca de túnel do metrô, com a frente (saída) virada para -Z. Os clientes nascem lá dentro, no escuro
-- (a peça "Darkness" não tem colisão), e saem andando.
function Decor.subway(cframe: CFrame, parent: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Subway"
	local tile = Color3.fromRGB(215, 210, 196)
	local trim = Color3.fromRGB(30, 90, 170)
	local width, height, depth = 12, 10, 12
	for _, side in { -1, 1 } do
		part(
			folder,
			"Wall",
			Vector3.new(1.5, height, depth),
			cframe * CFrame.new(side * (width / 2 + 0.75), height / 2, depth / 2),
			tile,
			Enum.Material.Pavement
		)
		part(
			folder,
			"WallTrim",
			Vector3.new(1.7, 0.8, depth + 0.2),
			cframe * CFrame.new(side * (width / 2 + 0.75), height - 1, depth / 2),
			trim,
			Enum.Material.SmoothPlastic,
			false
		)
	end
	part(
		folder,
		"Roof",
		Vector3.new(width + 3, 1.5, depth),
		cframe * CFrame.new(0, height + 0.75, depth / 2),
		tile,
		Enum.Material.Pavement
	)
	part(
		folder,
		"Back",
		Vector3.new(width, height, 1),
		cframe * CFrame.new(0, height / 2, depth + 0.5),
		Color3.fromRGB(10, 10, 12),
		Enum.Material.SmoothPlastic
	)
	-- Escuridão de dentro do túnel (sem colisão: os clientes saem de dentro dela).
	local darkness = part(
		folder,
		"Darkness",
		Vector3.new(width - 0.2, height - 0.2, depth - 3),
		cframe * CFrame.new(0, height / 2, depth / 2 + 1.5),
		Color3.fromRGB(5, 5, 8),
		Enum.Material.SmoothPlastic,
		false
	)
	darkness.Transparency = 0.05
	darkness.CanQuery = false
	part(
		folder,
		"Floor",
		Vector3.new(width, 0.2, depth + 2),
		cframe * CFrame.new(0, 0.1, depth / 2 - 1),
		Color3.fromRGB(120, 118, 112),
		Enum.Material.Concrete,
		false
	)
	-- Placa "METRO" com o M.
	local sign = part(
		folder,
		"Sign",
		Vector3.new(width + 3, 2.6, 0.6),
		cframe * CFrame.new(0, height + 2.8, 0),
		trim,
		Enum.Material.SmoothPlastic
	)
	Decor.sign(sign, "Ⓜ METRO", Color3.new(1, 1, 1))
	for _, side in { -1, 1 } do
		local lamp = part(
			folder,
			"Lamp",
			Vector3.new(0.8, 0.8, 0.8),
			cframe * CFrame.new(side * (width / 2 + 0.75), height - 2.5, -0.5),
			Color3.fromRGB(255, 240, 200),
			NEON,
			false
		)
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 235, 200)
		light.Parent = lamp
	end
	folder.Parent = parent
end

-- Bueiro na rua. Alguns monstros sobem por ele (com vapor verde).
function Decor.manhole(cframe: CFrame, parent: Instance, name: string)
	local lid = cylinder(
		parent,
		name,
		0.3,
		5,
		cframe * CFrame.new(0, 0.2, 0),
		Color3.fromRGB(60, 62, 66),
		Enum.Material.DiamondPlate
	)
	lid.CanCollide = false
	local ring = cylinder(
		parent,
		`{name}Ring`,
		0.25,
		5.8,
		cframe * CFrame.new(0, 0.18, 0),
		Color3.fromRGB(90, 255, 140),
		NEON
	)
	ring.CanCollide = false
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Color = ColorSequence.new(Color3.fromRGB(150, 255, 180), Color3.fromRGB(60, 120, 80))
	steam.LightEmission = 0.4
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	steam.Transparency = NumberSequence.new(0.5, 1)
	steam.Lifetime = NumberRange.new(1, 2)
	steam.Rate = 1.5
	steam.Speed = NumberRange.new(3, 6)
	steam.EmissionDirection = Enum.NormalId.Right -- o eixo do cilindro aponta para cima
	steam.SpreadAngle = Vector2.new(15, 15)
	steam.Parent = lid
end

-- Peça que gira sozinha no cliente (client/MonsterAnimator.luau, tag "Spin").
function Decor.spin(target: BasePart, speed: number)
	target:SetAttribute("SpinSpeed", speed)
	CollectionService:AddTag(target, "Spin")
end

Decor.part = part
Decor.cylinder = cylinder
Decor.ball = ball

return Decor
