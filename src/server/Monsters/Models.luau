--!strict
-- Monta os monstros da rua peça por peça (docs/V3.md, seção 3). Nada de modelo 3D importado: cada monstro é
-- feito de Parts ligadas por Motor6D, e o cliente (client/MonsterAnimator.luau) mexe nas juntas para andar,
-- voar, abanar o rabo...
--
-- Regras para o animador do cliente achar as juntas:
--   * cada Motor6D tem o mesmo nome da peça que ele mexe (Part1);
--   * o modelo tem a tag "Monster" e o atributo "Kind" (id em shared/Anomalies.luau);
--   * a peça raiz se chama "HumanoidRootPart" e fica invisível.
--
-- O modelo nasce com o chão em Y = 0 e a raiz na altura `height` do monstro. Quem usa o modelo só precisa
-- chamar PivotTo (a raiz é o PrimaryPart).

local CollectionService = game:GetService("CollectionService")

local Models = {}

Models.TAG = "Monster"
Models.COLLISION_GROUP = "Customers" -- mesmo grupo dos clientes: não empurra nem trava os jogadores

local ROOT_SIZE = Vector3.new(2, 2, 1)

type Shape = "Block" | "Ball" | "Cylinder" | "Ellipsoid" | "Wedge"

type Rig = {
	model: Model,
	root: Part,
	-- Cria uma peça presa em `parent` (ou na raiz) na posição `offset`, relativa ao pai.
	add: (
		name: string,
		shape: Shape,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		parent: BasePart?,
		pivot: Vector3?
	) -> BasePart,
}

local function newRig(kind: string, height: number): Rig
	local model = Instance.new("Model")
	model.Name = kind

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.CFrame = CFrame.new(0, height, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CollisionGroup = Models.COLLISION_GROUP
	root.Parent = model
	model.PrimaryPart = root

	local function add(
		name: string,
		shape: Shape,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		parent: BasePart?,
		pivot: Vector3?
	): BasePart
		local base = parent or root
		local part: BasePart
		if shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local plain = Instance.new("Part")
			if shape == "Ball" then
				plain.Shape = Enum.PartType.Ball
			elseif shape == "Cylinder" then
				plain.Shape = Enum.PartType.Cylinder -- o eixo do cilindro é o X da peça
			elseif shape == "Ellipsoid" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere -- esfera esticada no tamanho da peça
				mesh.Parent = plain
			end
			part = plain
		end
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CollisionGroup = Models.COLLISION_GROUP
		part.CFrame = base.CFrame * offset
		part.Parent = model

		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = base
		motor.Part1 = part
		-- `pivot` (no espaço da peça) é o ponto em que ela gira: o ombro de um braço, a dobradiça da tampa...
		local joint = CFrame.new(pivot or Vector3.zero)
		motor.C0 = offset * joint
		motor.C1 = joint
		motor.Parent = base
		return part
	end

	return { model = model, root = root, add = add }
end

-- Atalhos de ângulo, em graus.
local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local NEON = Enum.Material.Neon
local BLACK = Color3.fromRGB(15, 15, 18)
local WHITE = Color3.fromRGB(245, 245, 240)

-- Olho: bola branca com pupila. `glow` deixa o olho todo brilhando (cor única).
local function eye(rig: Rig, name: string, parent: BasePart, offset: CFrame, size: number, glow: Color3?)
	if glow then
		rig.add(name, "Ball", Vector3.one * size, offset, glow, NEON, parent)
		return
	end
	local white = rig.add(name, "Ball", Vector3.one * size, offset, WHITE, nil, parent)
	rig.add(`{name}Pupil`, "Ball", Vector3.one * size * 0.45, at(0, 0, -size * 0.4), BLACK, nil, white)
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number?)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness or 1.5
	point.Shadows = false
	point.Parent = parent
end

local BUILDERS: { [string]: () -> Rig } = {}

-- Gloop: geleia verde que engoliu metade do corredor de salgadinhos.
BUILDERS.Gloop = function()
	local rig = newRig("Gloop", 2.6)
	local green = Color3.fromRGB(110, 230, 90)
	local body = rig.add("Body", "Ellipsoid", Vector3.new(6, 4.6, 6), at(0, 0, 0), green, Enum.Material.Glass)
	body.Transparency = 0.25
	rig.add(
		"Core",
		"Ellipsoid",
		Vector3.new(3.6, 2.6, 3.6),
		at(0, -0.4, 0),
		Color3.fromRGB(60, 170, 60),
		NEON,
		body
	).Transparency =
		0.5
	-- Coisas engolidas, boiando dentro.
	rig.add(
		"Can",
		"Cylinder",
		Vector3.new(1.4, 0.8, 0.8),
		at(1, -0.3, 0.6) * rot(0, 30, 70),
		Color3.fromRGB(220, 40, 40),
		nil,
		body
	)
	rig.add(
		"Bone",
		"Block",
		Vector3.new(1.8, 0.3, 0.3),
		at(-1.1, 0.2, 0.4) * rot(0, 50, 20),
		WHITE,
		nil,
		body
	)
	rig.add(
		"Chips",
		"Block",
		Vector3.new(1, 1.3, 0.3),
		at(0.2, 0.5, -0.9) * rot(10, 20, -15),
		Color3.fromRGB(250, 190, 40),
		nil,
		body
	)
	eye(rig, "EyeL", body, at(-1, 1.6, -2.2), 1.1)
	eye(rig, "EyeR", body, at(1.1, 1.8, -2.1), 1.3)
	rig.add(
		"Mouth",
		"Ellipsoid",
		Vector3.new(2.4, 0.7, 0.5),
		at(0, 0.2, -2.8),
		Color3.fromRGB(30, 80, 30),
		nil,
		body
	)
	return rig
end

-- Mimic Crate: parece uma entrega. Morde.
BUILDERS.MimicCrate = function()
	local rig = newRig("MimicCrate", 3.2)
	local cardboard = Color3.fromRGB(196, 150, 96)
	local box =
		rig.add("Box", "Block", Vector3.new(4, 2.6, 4), at(0, 0, 0), cardboard, Enum.Material.Cardboard)
	rig.add(
		"Tape",
		"Block",
		Vector3.new(0.6, 2.62, 4.02),
		at(0, 0, 0),
		Color3.fromRGB(170, 120, 70),
		nil,
		box
	)
	rig.add(
		"Inside",
		"Block",
		Vector3.new(3.6, 0.2, 3.6),
		at(0, 1.2, 0),
		Color3.fromRGB(25, 10, 10),
		nil,
		box
	)
	-- A tampa é a boca: abre e fecha (junta "Lid" presa na borda de trás).
	local lid = rig.add(
		"Lid",
		"Block",
		Vector3.new(4.1, 0.25, 4.1),
		at(0, 1.4, 0),
		cardboard,
		Enum.Material.Cardboard,
		box,
		Vector3.new(0, 0, 2.05)
	)
	for index = -1, 1 do
		rig.add(
			`ToothTop{index + 2}`,
			"Wedge",
			Vector3.new(0.5, 0.6, 0.4),
			at(index * 1.2, -0.42, -1.8) * rot(180, 0, 0),
			WHITE,
			nil,
			lid
		)
		rig.add(
			`ToothBottom{index + 2}`,
			"Wedge",
			Vector3.new(0.5, 0.6, 0.4),
			at(index * 1.2 + 0.6, 1.55, -1.8),
			WHITE,
			nil,
			box
		)
	end
	rig.add(
		"Tongue",
		"Ellipsoid",
		Vector3.new(1.2, 0.4, 2.6),
		at(0, 1.35, -1.6) * rot(-15, 0, 0),
		Color3.fromRGB(220, 60, 90),
		nil,
		box
	)
	eye(rig, "EyeL", box, at(-0.9, 1.3, 0.6), 0.6, Color3.fromRGB(255, 220, 40))
	eye(rig, "EyeR", box, at(0.9, 1.3, 0.6), 0.6, Color3.fromRGB(255, 220, 40))
	for index, x in { -1.4, 1.4 } do
		for jndex, z in { -1.4, 1.4 } do
			rig.add(
				`Leg{index}{jndex}`,
				"Cylinder",
				Vector3.new(1.9, 0.35, 0.35),
				at(x, -2, z) * rot(0, 0, 90),
				Color3.fromRGB(40, 30, 30),
				nil,
				box,
				Vector3.new(0.95, 0, 0)
			)
		end
	end
	return rig
end

-- Skull Hound: cachorro de ossos com as costelas brilhando.
BUILDERS.SkullHound = function()
	local rig = newRig("SkullHound", 3.4)
	local bone = Color3.fromRGB(232, 226, 205)
	local glow = Color3.fromRGB(90, 255, 120)
	local spine = rig.add("Spine", "Block", Vector3.new(0.5, 0.5, 5), at(0, 0.6, 0), bone)
	rig.add("Soul", "Ellipsoid", Vector3.new(1.6, 1.6, 3.6), at(0, -0.4, 0), glow, NEON, spine).Transparency =
		0.2
	light(spine, glow, 10)
	for index = 1, 5 do
		local z = -2 + index * 0.75
		rig.add(
			`RibL{index}`,
			"Block",
			Vector3.new(0.25, 2, 0.25),
			at(-0.9, -0.7, z) * rot(0, 0, -20),
			bone,
			nil,
			spine
		)
		rig.add(
			`RibR{index}`,
			"Block",
			Vector3.new(0.25, 2, 0.25),
			at(0.9, -0.7, z) * rot(0, 0, 20),
			bone,
			nil,
			spine
		)
	end
	local head = rig.add(
		"Head",
		"Block",
		Vector3.new(1.8, 1.6, 2),
		at(0, 0.6, -3.1),
		bone,
		nil,
		spine,
		Vector3.new(0, -0.3, 1)
	)
	rig.add("Snout", "Block", Vector3.new(1.1, 0.7, 1.3), at(0, -0.3, -1.4), bone, nil, head)
	rig.add(
		"Jaw",
		"Block",
		Vector3.new(1.1, 0.3, 1.8),
		at(0, -0.9, -1),
		bone,
		nil,
		head,
		Vector3.new(0, 0, 0.9)
	)
	eye(rig, "EyeL", head, at(-0.45, 0.25, -1), 0.5, glow)
	eye(rig, "EyeR", head, at(0.45, 0.25, -1), 0.5, glow)
	rig.add("EarL", "Wedge", Vector3.new(0.3, 0.9, 0.6), at(-0.6, 1.1, 0.3), bone, nil, head)
	rig.add("EarR", "Wedge", Vector3.new(0.3, 0.9, 0.6), at(0.6, 1.1, 0.3), bone, nil, head)
	-- Pernas em duas partes: coxa (junta "LegXX") e canela presa nela.
	for _, leg in
		{ { "LegFL", -0.8, -1.9 }, { "LegFR", 0.8, -1.9 }, { "LegBL", -0.8, 1.9 }, { "LegBR", 0.8, 1.9 } }
	do
		local name, x, z = leg[1] :: string, leg[2] :: number, leg[3] :: number
		local upper = rig.add(
			name,
			"Block",
			Vector3.new(0.35, 1.8, 0.35),
			at(x, -0.6, z) * at(0, -0.9, 0),
			bone,
			nil,
			spine,
			Vector3.new(0, 0.9, 0)
		)
		rig.add(
			`{name}Low`,
			"Block",
			Vector3.new(0.3, 1.7, 0.3),
			at(0, -1.6, 0.15) * rot(-10, 0, 0),
			bone,
			nil,
			upper,
			Vector3.new(0, 0.85, 0)
		)
	end
	local tail = rig.add(
		"Tail1",
		"Block",
		Vector3.new(0.25, 0.25, 1.2),
		at(0, 0.3, 3) * rot(25, 0, 0),
		bone,
		nil,
		spine,
		Vector3.new(0, 0, -0.6)
	)
	local tail2 = rig.add(
		"Tail2",
		"Block",
		Vector3.new(0.22, 0.22, 1.1),
		at(0, 0, 1.1) * rot(15, 0, 0),
		bone,
		nil,
		tail,
		Vector3.new(0, 0, -0.55)
	)
	rig.add("TailTip", "Ball", Vector3.one * 0.5, at(0, 0, 0.7), glow, NEON, tail2)
	return rig
end

-- Eye Spider: um olho gigante em oito pernas.
BUILDERS.EyeSpider = function()
	local rig = newRig("EyeSpider", 3.8)
	local eyeBall = rig.add("Eye", "Ball", Vector3.one * 4.4, at(0, 0, 0), WHITE)
	local iris = rig.add(
		"Iris",
		"Cylinder",
		Vector3.new(0.3, 2.4, 2.4),
		at(0, 0, -2.1) * rot(0, 90, 0),
		Color3.fromRGB(200, 40, 60),
		NEON,
		eyeBall
	)
	rig.add("Pupil", "Cylinder", Vector3.new(0.32, 1.1, 1.1), at(-0.05, 0, 0), BLACK, nil, iris)
	for index = 1, 6 do
		local angle = index * 60
		rig.add(
			`Vein{index}`,
			"Block",
			Vector3.new(0.12, 0.12, 2.2),
			rot(0, angle, 0) * at(0, 0.6 * math.sin(index), 1.9) * rot(0, 20, 0),
			Color3.fromRGB(200, 30, 40),
			nil,
			eyeBall
		)
	end
	local legColor = Color3.fromRGB(30, 22, 30)
	for index = 1, 8 do
		local side = if index <= 4 then -1 else 1
		local slot = (index - 1) % 4 -- 0..3, da frente para trás
		local yaw = -side * (35 + slot * 30) -- ângulo positivo gira a frente (-Z) para a esquerda
		local thigh = rig.add(
			`Leg{index}`,
			"Block",
			Vector3.new(0.35, 0.35, 3.4),
			rot(0, yaw, 0) * at(0, 0.6, -2.6) * rot(35, 0, 0),
			legColor,
			nil,
			eyeBall,
			Vector3.new(0, 0, 1.7)
		)
		rig.add(
			`Leg{index}Low`,
			"Block",
			Vector3.new(0.28, 0.28, 5.2),
			at(0, 0, -1.7) * rot(-110, 0, 0) * at(0, 0, -2.6),
			legColor,
			nil,
			thigh,
			Vector3.new(0, 0, 2.6)
		)
	end
	return rig
end

-- TV Head: homem de terno com uma TV velha no lugar da cabeça. A tela fica chiando (o cliente pisca a cor).
BUILDERS.TVHead = function()
	local rig = newRig("TVHead", 3)
	local suit = Color3.fromRGB(28, 30, 38)
	local torso = rig.add("Torso", "Block", Vector3.new(2.2, 2.4, 1.1), at(0, 0.6, 0), suit)
	rig.add("Shirt", "Block", Vector3.new(0.7, 2.3, 0.1), at(0, 0.05, -0.56), WHITE, nil, torso)
	rig.add(
		"Tie",
		"Block",
		Vector3.new(0.3, 1.6, 0.1),
		at(0, -0.1, -0.62),
		Color3.fromRGB(190, 20, 30),
		nil,
		torso
	)
	local tv = rig.add(
		"TV",
		"Block",
		Vector3.new(2.6, 2.1, 2),
		at(0, 2.3, 0),
		Color3.fromRGB(110, 100, 90),
		Enum.Material.Wood,
		torso,
		Vector3.new(0, -1.05, 0)
	)
	local screen = rig.add(
		"Screen",
		"Block",
		Vector3.new(2, 1.5, 0.1),
		at(-0.15, 0, -1.01),
		Color3.fromRGB(180, 180, 190),
		NEON,
		tv
	)
	screen:SetAttribute("Static", true)
	light(screen, Color3.fromRGB(160, 200, 255), 10, 1)
	rig.add(
		"Knob",
		"Cylinder",
		Vector3.new(0.2, 0.35, 0.35),
		at(1.05, 0.4, -1.02) * rot(0, 90, 0),
		BLACK,
		nil,
		tv
	)
	rig.add("AntennaL", "Block", Vector3.new(0.12, 2, 0.12), at(-0.5, 1.8, 0) * rot(0, 0, 25), BLACK, nil, tv)
	rig.add("AntennaR", "Block", Vector3.new(0.12, 2, 0.12), at(0.5, 1.8, 0) * rot(0, 0, -25), BLACK, nil, tv)
	for _, arm in { { "ArmL", -1.45 }, { "ArmR", 1.45 } } do
		local name, x = arm[1] :: string, arm[2] :: number
		local limb = rig.add(
			name,
			"Block",
			Vector3.new(0.7, 2.4, 0.7),
			at(x, 0, 0) * at(0, -0.1, 0),
			suit,
			nil,
			torso,
			Vector3.new(0, 1.1, 0)
		)
		rig.add(
			`{name}Hand`,
			"Ball",
			Vector3.one * 0.7,
			at(0, -1.35, 0),
			Color3.fromRGB(200, 200, 205),
			nil,
			limb
		)
	end
	for _, leg in { { "LegL", -0.55 }, { "LegR", 0.55 } } do
		local name, x = leg[1] :: string, leg[2] :: number
		local limb = rig.add(
			name,
			"Block",
			Vector3.new(0.9, 2.5, 0.9),
			at(x, -1.85, 0),
			suit,
			nil,
			torso,
			Vector3.new(0, 1.25, 0)
		)
		rig.add(`{name}Shoe`, "Block", Vector3.new(0.95, 0.4, 1.3), at(0, -1.3, -0.2), BLACK, nil, limb)
	end
	return rig
end

-- Static Jelly: água-viva voadora que zumbe como geladeira quebrada.
BUILDERS.StaticJelly = function()
	local rig = newRig("StaticJelly", 6.5)
	local cyan = Color3.fromRGB(110, 220, 255)
	local bell = rig.add("Bell", "Ellipsoid", Vector3.new(5, 3.4, 5), at(0, 0, 0), cyan, Enum.Material.Glass)
	bell.Transparency = 0.35
	local core =
		rig.add("Core", "Ball", Vector3.one * 1.8, at(0, -0.2, 0), Color3.fromRGB(255, 240, 120), NEON, bell)
	light(core, cyan, 14, 2)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.15)
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Rate = 8
	sparks.Speed = NumberRange.new(4, 7)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = core
	for index = 1, 8 do
		local angle = math.rad(index * 45)
		local x, z = math.cos(angle) * 1.6, math.sin(angle) * 1.6
		local previous = bell
		local offset = at(x, -1.5, z)
		for segment = 1, 3 do
			local piece = rig.add(
				`Tendril{index}_{segment}`,
				"Block",
				Vector3.new(0.2, 1.4, 0.2),
				offset * at(0, -0.7, 0),
				cyan,
				NEON,
				previous,
				Vector3.new(0, 0.7, 0)
			)
			piece.Transparency = 0.2
			previous = piece
			offset = at(0, -0.7, 0)
		end
	end
	return rig
end

-- Moth Monarch: asas enormes cheias de olhos. Adora o letreiro de neon.
BUILDERS.MothMonarch = function()
	local rig = newRig("MothMonarch", 6)
	local fur = Color3.fromRGB(150, 120, 90)
	local body =
		rig.add("Body", "Ellipsoid", Vector3.new(1.8, 1.8, 4.2), at(0, 0, 0), fur, Enum.Material.Fabric)
	local head = rig.add(
		"Head",
		"Ball",
		Vector3.one * 1.6,
		at(0, 0.3, -2.2),
		Color3.fromRGB(220, 210, 190),
		Enum.Material.Fabric,
		body
	)
	eye(rig, "EyeL", head, at(-0.55, 0.15, -0.5), 0.75, Color3.fromRGB(255, 40, 40))
	eye(rig, "EyeR", head, at(0.55, 0.15, -0.5), 0.75, Color3.fromRGB(255, 40, 40))
	rig.add(
		"FeelerL",
		"Block",
		Vector3.new(0.15, 0.15, 2),
		at(-0.4, 0.9, -0.6) * rot(50, -20, 0),
		fur,
		nil,
		head
	)
	rig.add(
		"FeelerR",
		"Block",
		Vector3.new(0.15, 0.15, 2),
		at(0.4, 0.9, -0.6) * rot(50, 20, 0),
		fur,
		nil,
		head
	)
	rig.add(
		"Ruff",
		"Ball",
		Vector3.one * 2.2,
		at(0, 0.2, -1.2),
		Color3.fromRGB(240, 235, 225),
		Enum.Material.Fabric,
		body
	)
	local wingColor = Color3.fromRGB(120, 90, 160)
	for _, wing in { { "WingL", -1 }, { "WingR", 1 } } do
		local name, side = wing[1] :: string, wing[2] :: number
		local plate = rig.add(
			name,
			"Block",
			Vector3.new(6, 0.15, 4.4),
			at(side * 0.8, 0.4, -0.4) * at(side * 3, 0, 0),
			wingColor,
			Enum.Material.Fabric,
			body,
			Vector3.new(-side * 3, 0, 0)
		)
		rig.add(
			`{name}Spot`,
			"Cylinder",
			Vector3.new(0.18, 2.2, 2.2),
			at(side * 0.6, 0, -0.3) * rot(0, 0, 90),
			Color3.fromRGB(255, 200, 60),
			NEON,
			plate
		)
		rig.add(
			`{name}Pupil`,
			"Cylinder",
			Vector3.new(0.2, 1, 1),
			at(side * 0.6, 0, -0.3) * rot(0, 0, 90),
			BLACK,
			nil,
			plate
		)
		local back = rig.add(
			`{name}Back`,
			"Block",
			Vector3.new(4, 0.14, 3),
			at(side * -0.8, 0, 3.2) * rot(0, side * 25, 0),
			Color3.fromRGB(90, 60, 130),
			Enum.Material.Fabric,
			plate
		)
		rig.add(
			`{name}BackSpot`,
			"Cylinder",
			Vector3.new(0.16, 1.2, 1.2),
			at(0, 0, 0.3) * rot(0, 0, 90),
			Color3.fromRGB(80, 220, 255),
			NEON,
			back
		)
	end
	for index = 1, 3 do
		rig.add(
			`LegsL{index}`,
			"Block",
			Vector3.new(0.12, 1.6, 0.12),
			at(-0.6, -1.2, -1 + index * 0.6) * rot(0, 0, 20),
			BLACK,
			nil,
			body
		)
		rig.add(
			`LegsR{index}`,
			"Block",
			Vector3.new(0.12, 1.6, 0.12),
			at(0.6, -1.2, -1 + index * 0.6) * rot(0, 0, -20),
			BLACK,
			nil,
			body
		)
	end
	return rig
end

-- The Tall One: mais alto que a loja. Ninguém viu ele entrar.
BUILDERS.TheTallOne = function()
	local rig = newRig("TheTallOne", 9)
	local skin = Color3.fromRGB(205, 205, 200)
	local coat = Color3.fromRGB(20, 20, 26)
	local torso = rig.add("Torso", "Block", Vector3.new(2, 5.5, 1.1), at(0, 2.6, 0) * rot(8, 0, 0), coat)
	local neck = rig.add(
		"Neck",
		"Block",
		Vector3.new(0.5, 1.6, 0.5),
		at(0, 3.4, -0.2) * rot(15, 0, 0),
		skin,
		nil,
		torso,
		Vector3.new(0, -0.8, 0)
	)
	local head = rig.add("Head", "Ellipsoid", Vector3.new(1.6, 2.4, 1.5), at(0, 1.6, -0.2), skin, nil, neck)
	for index, x in { -0.4, 0, 0.4 } do
		rig.add(
			`Eye{index}`,
			"Ball",
			Vector3.one * (if x == 0 then 0.45 else 0.35),
			at(x, 0.4 + (if x == 0 then 0.35 else 0), -0.68),
			BLACK,
			nil,
			head
		)
	end
	rig.add("Smile", "Block", Vector3.new(1, 0.12, 0.1), at(0, -0.45, -0.72) * rot(0, 0, 0), BLACK, nil, head)
	local halo = rig.add(
		"Halo",
		"Cylinder",
		Vector3.new(0.15, 2.6, 2.6),
		at(0, 1.6, 0.3) * rot(0, 0, 90),
		Color3.fromRGB(255, 250, 200),
		NEON,
		head
	)
	halo.Transparency = 0.2
	light(halo, Color3.fromRGB(255, 250, 220), 16, 1.2)
	for _, arm in { { "ArmL", -1.25 }, { "ArmR", 1.25 } } do
		local name, x = arm[1] :: string, arm[2] :: number
		local upper = rig.add(
			name,
			"Block",
			Vector3.new(0.45, 4, 0.45),
			at(x, 2.3, 0) * at(0, -2, 0),
			coat,
			nil,
			torso,
			Vector3.new(0, 2, 0)
		)
		local lower = rig.add(
			`{name}Low`,
			"Block",
			Vector3.new(0.38, 4, 0.38),
			at(0, -3.9, 0) * rot(-15, 0, 0),
			skin,
			nil,
			upper,
			Vector3.new(0, 2, 0)
		)
		for finger = -1, 1 do
			rig.add(
				`{name}Finger{finger + 2}`,
				"Block",
				Vector3.new(0.12, 1.4, 0.12),
				at(finger * 0.13, -2.6, 0),
				skin,
				nil,
				lower
			)
		end
	end
	for _, leg in { { "LegL", -0.55 }, { "LegR", 0.55 } } do
		local name, x = leg[1] :: string, leg[2] :: number
		local upper = rig.add(
			name,
			"Block",
			Vector3.new(0.6, 4.4, 0.6),
			at(x, -2.75, 0) * at(0, -2.2, 0),
			coat,
			nil,
			torso,
			Vector3.new(0, 2.2, 0)
		)
		rig.add(
			`{name}Low`,
			"Block",
			Vector3.new(0.5, 4.4, 0.5),
			at(0, -4.3, 0),
			coat,
			nil,
			upper,
			Vector3.new(0, 2.2, 0)
		)
	end
	return rig
end

-- Rift King: a própria Fenda, de coroa.
BUILDERS.RiftKing = function()
	local rig = newRig("RiftKing", 7)
	local purple = Color3.fromRGB(150, 60, 255)
	local core = rig.add("Core", "Block", Vector3.new(2.4, 4, 2.4), at(0, 0, 0) * rot(0, 45, 0), purple, NEON)
	light(core, purple, 20, 3)
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255), Color3.fromRGB(60, 0, 120))
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new(0.3, 1)
	aura.Lifetime = NumberRange.new(1, 2)
	aura.Rate = 14
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = core
	local robe = rig.add(
		"Robe",
		"Wedge",
		Vector3.new(3.6, 4, 2.6),
		at(0, -3, 0.2) * rot(0, 180, 0),
		Color3.fromRGB(30, 10, 50),
		Enum.Material.Fabric
	)
	robe.Transparency = 0.1
	local face =
		rig.add("Face", "Ellipsoid", Vector3.new(1.8, 2, 1), at(0, 3, -0.2), Color3.fromRGB(20, 0, 40), nil)
	eye(rig, "EyeL", face, at(-0.4, 0.15, -0.45), 0.45, Color3.fromRGB(255, 255, 255))
	eye(rig, "EyeR", face, at(0.4, 0.15, -0.45), 0.45, Color3.fromRGB(255, 255, 255))
	local crown = rig.add(
		"Crown",
		"Cylinder",
		Vector3.new(0.6, 2, 2),
		at(0, 1.3, 0) * rot(0, 0, 90),
		Color3.fromRGB(255, 200, 40),
		Enum.Material.Metal,
		face
	)
	for index = 1, 5 do
		local angle = math.rad(index * 72)
		rig.add(
			`Spike{index}`,
			"Wedge",
			Vector3.new(0.3, 0.8, 0.5),
			at(0, 0.6, 0)
				* CFrame.Angles(math.rad(-90), 0, 0)
				* at(math.cos(angle) * 0.85, math.sin(angle) * 0.85, 0)
				* rot(90, 0, 0),
			Color3.fromRGB(255, 200, 40),
			Enum.Material.Metal,
			crown
		)
	end
	rig.add("Gem", "Ball", Vector3.one * 0.5, at(0.35, 0, -0.95), Color3.fromRGB(255, 40, 90), NEON, crown)
	-- Cacos que giram em volta (junta "Orbit" girada pelo cliente).
	local orbit = rig.add("Orbit", "Block", Vector3.new(0.2, 0.2, 0.2), at(0, 0, 0), purple, NEON)
	orbit.Transparency = 1
	for index = 1, 6 do
		local angle = math.rad(index * 60)
		rig.add(
			`Shard{index}`,
			"Wedge",
			Vector3.new(0.6, 1.6, 0.6),
			at(math.cos(angle) * 3.4, math.sin(index) * 0.8, math.sin(angle) * 3.4)
				* rot(index * 25, index * 40, 0),
			Color3.fromRGB(200, 150, 255),
			NEON,
			orbit
		)
	end
	for _, hand in { { "HandL", -2.6 }, { "HandR", 2.6 } } do
		local name, x = hand[1] :: string, hand[2] :: number
		rig.add(name, "Ball", Vector3.one * 1.1, at(x, 0.3, -0.6), Color3.fromRGB(60, 20, 100), NEON)
	end
	return rig
end

-- Colosso da Fenda: o chefe da Invasão da Fenda (server/RiftInvasion.luau). Corcunda, anda apoiado nos
-- punhos, com um olho só e cristais da Fenda nas costas. Nasce no tamanho de um monstro grande e o
-- RiftInvasion aumenta com ScaleTo.
BUILDERS.RiftColossus = function()
	local rig = newRig("RiftColossus", 7)
	local void = Color3.fromRGB(32, 20, 48)
	local stone = Color3.fromRGB(58, 44, 76)
	local purple = Color3.fromRGB(170, 70, 255)
	local red = Color3.fromRGB(255, 60, 90)

	local body = rig.add(
		"Body",
		"Ellipsoid",
		Vector3.new(8, 7, 6),
		at(0, 2, 0) * rot(-20, 0, 0),
		void,
		Enum.Material.Slate,
		nil,
		Vector3.new(0, -3, 0)
	)
	-- Rachaduras de neon no peito, como as do chão perto da Fenda.
	for index, crack in { { 0, 0.6, 12 }, { -0.9, -0.6, -25 }, { 0.8, -0.9, 30 } } do
		rig.add(
			`Crack{index}`,
			"Block",
			Vector3.new(0.35, 2.6, 0.35),
			at(crack[1], crack[2], -2.85) * rot(0, 0, crack[3]),
			purple,
			NEON,
			body
		)
	end
	light(body, purple, 30, 2.5)
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255), Color3.fromRGB(60, 0, 120))
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new(0.4, 1)
	aura.Lifetime = NumberRange.new(1.5, 2.5)
	aura.Rate = 18
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = body

	-- Cristais da Fenda saindo das costas.
	for index, shard in
		{
			{ 0, 3.2, 1.2, 0, 3.4 },
			{ -1.8, 2.6, 1.8, -25, 2.6 },
			{ 1.8, 2.6, 1.8, 25, 2.6 },
			{ -1, 1.2, 2.7, -15, 2 },
			{ 1.1, 1, 2.7, 20, 2.2 },
		}
	do
		rig.add(
			`Shard{index}`,
			"Block",
			Vector3.new(0.9, shard[5], 0.9),
			at(shard[1], shard[2], shard[3]) * rot(-35, 45, shard[4]),
			purple,
			NEON,
			body
		)
	end

	local head = rig.add(
		"Head",
		"Ball",
		Vector3.one * 3.6,
		at(0, 2, -3) * rot(20, 0, 0),
		stone,
		Enum.Material.Slate,
		body,
		Vector3.new(0, -1, 0.6)
	)
	eye(rig, "Eye", head, at(0, 0.45, -1.45), 1.6, red)
	light(head, red, 14, 2)
	for index, x in { -0.9, 0.9 } do
		rig.add(
			`Brow{index}`,
			"Block",
			Vector3.new(1.3, 0.35, 0.5),
			at(x, 1.3, -1.25) * rot(0, 0, x * 18),
			void,
			nil,
			head
		)
	end
	local jaw = rig.add(
		"Jaw",
		"Block",
		Vector3.new(2.8, 0.8, 1.8),
		at(0, -1.45, -0.9),
		stone,
		Enum.Material.Slate,
		head,
		Vector3.new(0, 0, 0.9)
	)
	for tooth = -2, 2 do
		rig.add(
			`Tooth{tooth + 3}`,
			"Wedge",
			Vector3.new(0.3, 0.6, 0.3),
			at(tooth * 0.5, 0.6, -0.75),
			WHITE,
			nil,
			jaw
		)
	end

	-- Braços compridos: ele anda apoiado nos punhos, como um gorila.
	for _, arm in { { "ArmL", -4.2 }, { "ArmR", 4.2 } } do
		local name, x = arm[1] :: string, arm[2] :: number
		local upper = rig.add(
			name,
			"Block",
			Vector3.new(1.6, 4.6, 1.6),
			at(x, 3.8, -1.2) * at(0, -2.3, 0),
			void,
			Enum.Material.Slate,
			nil,
			Vector3.new(0, 2.3, 0)
		)
		local lower = rig.add(
			`{name}Low`,
			"Block",
			Vector3.new(1.4, 4.2, 1.4),
			at(0, -4.4, 0),
			stone,
			Enum.Material.Slate,
			upper,
			Vector3.new(0, 2.1, 0)
		)
		local fist =
			rig.add(`{name}Fist`, "Ball", Vector3.one * 2.2, at(0, -3, 0), stone, Enum.Material.Slate, lower)
		rig.add(`{name}Glow`, "Block", Vector3.new(1.8, 0.25, 0.25), at(0, 0.3, -1), purple, NEON, fist)
	end

	for _, leg in { { "LegL", -2 }, { "LegR", 2 } } do
		local name, x = leg[1] :: string, leg[2] :: number
		local upper = rig.add(
			name,
			"Block",
			Vector3.new(1.8, 3, 1.8),
			at(x, -0.6, 0.5) * at(0, -1.5, 0),
			void,
			Enum.Material.Slate,
			nil,
			Vector3.new(0, 1.5, 0)
		)
		local lower = rig.add(
			`{name}Low`,
			"Block",
			Vector3.new(1.6, 2.6, 1.6),
			at(0, -2.8, 0),
			stone,
			Enum.Material.Slate,
			upper,
			Vector3.new(0, 1.3, 0)
		)
		rig.add(`{name}Foot`, "Block", Vector3.new(2.2, 0.8, 3), at(0, -1.7, -0.5), void, nil, lower)
	end
	return rig
end

-- Variantes (as mesmas da loja): brilho dourado, cores invertidas, gigante e glitch.
local function applyVariant(model: Model, variant: string)
	if variant == "Shiny" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 90)
		sparkles.Parent = model.PrimaryPart
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 220, 90)
		highlight.FillTransparency = 0.75
		highlight.OutlineColor = Color3.fromRGB(255, 220, 90)
		highlight.Parent = model
	elseif variant == "Inverted" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon then
				local color = part.Color
				part.Color = Color3.new(1 - color.R, 1 - color.G, 1 - color.B)
			end
		end
	elseif variant == "Giant" then
		model:ScaleTo(1.6)
	elseif variant == "Glitch" then
		-- O cliente faz as cores piscarem (atributo "Glitch"), sem custar nada para o servidor.
		model:SetAttribute("Glitch", true)
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 0, 200)
		highlight.Parent = model
	end
end

function Models.has(kind: string): boolean
	return BUILDERS[kind] ~= nil
end

-- Cria o monstro `kind` na variante `variant`. `walking` = true coloca um Humanoid para ele poder andar
-- (na rua); sem isso ele é só um modelo para mostrar (nas celas).
function Models.build(kind: string, variant: string, walking: boolean): Model
	local builder = BUILDERS[kind]
	assert(builder, `monstro desconhecido: {kind}`)
	local rig = builder()
	local model = rig.model
	local height = rig.root.Position.Y

	applyVariant(model, variant)
	local scale = model:GetScale()

	if walking then
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 usa HipHeight: distância do chão até a base da raiz
		humanoid.HipHeight = (height - ROOT_SIZE.Y / 2) * scale
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.AutoRotate = true
		humanoid.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Chega inteiro no cliente (com StreamingEnabled as peças poderiam chegar aos poucos e o animador não
	-- acharia as juntas).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Variant", variant)
	CollectionService:AddTag(model, Models.TAG)
	return model
end

return Models
