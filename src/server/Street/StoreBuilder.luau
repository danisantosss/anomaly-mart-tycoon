--!strict
-- Constrói a loja inicial de um jogador dentro do terreno dele.
--
-- Os outros sistemas encontram as partes da loja pelo nome, então os nomes abaixo são o "contrato":
--   Store
--     Structure/        paredes, piso, teto (só visual)
--     Sign              letreiro com o nome do dono
--     Counter           caixa onde o cliente paga
--     Shelves/Shelf1..  prateleiras
--     Safe              cofre onde o dinheiro acumula
--     BackDoor          vão da porta dos fundos (a porta de aço entra aqui no PR 7)
--     Cells/Cell1..     celas de contenção na sala dos fundos
--     SpawnPoint        onde o dono aparece (na calçada, olhando para a loja)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)

local Street = Config.Street

local StoreBuilder = {}

local FLOOR = Color3.fromRGB(235, 232, 225)
local WALL = Color3.fromRGB(250, 248, 240)
local TRIM = Color3.fromRGB(46, 160, 120) -- verde "loja de conveniência"
local SHELF = Color3.fromRGB(200, 205, 212)
local COUNTER = Color3.fromRGB(150, 110, 80)
local SAFE = Color3.fromRGB(70, 74, 82)
local CELL = Color3.fromRGB(150, 210, 255)
local BACKROOM_FLOOR = Color3.fromRGB(150, 150, 150)

local DOOR_HEIGHT = 9

-- Parede reta com um vão de porta no meio (ou sem vão, se doorWidth for 0).
-- `z` é a posição da parede no eixo Z local; ela ocupa toda a largura da loja.
local function wallWithDoor(
	name: string,
	origin: CFrame,
	z: number,
	doorWidth: number,
	color: Color3,
	parent: Instance
)
	local width = Street.STORE_WIDTH
	local height = Street.STORE_HEIGHT
	local thickness = Street.WALL_THICKNESS

	if doorWidth <= 0 then
		Parts.make({
			name = name,
			size = Vector3.new(width, height, thickness),
			cframe = origin * CFrame.new(0, height / 2, z),
			color = color,
			parent = parent,
		})
		return
	end

	local segment = (width - doorWidth) / 2
	for _, sideSign in { -1, 1 } do
		Parts.make({
			name = name,
			size = Vector3.new(segment, height, thickness),
			cframe = origin * CFrame.new(sideSign * (doorWidth / 2 + segment / 2), height / 2, z),
			color = color,
			parent = parent,
		})
	end
	Parts.make({
		name = name,
		size = Vector3.new(doorWidth, height - DOOR_HEIGHT, thickness),
		cframe = origin * CFrame.new(0, DOOR_HEIGHT + (height - DOOR_HEIGHT) / 2, z),
		color = color,
		parent = parent,
	})
end

local function buildStructure(origin: CFrame, store: Model)
	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = store

	local width = Street.STORE_WIDTH
	local depth = Street.STORE_DEPTH
	local height = Street.STORE_HEIGHT
	local thickness = Street.WALL_THICKNESS
	local centerZ = (Layout.STORE_FRONT_Z + Layout.STORE_BACK_Z) / 2
	local shopDepth = Layout.PARTITION_Z - Layout.STORE_FRONT_Z

	Parts.make({
		name = "Floor",
		size = Vector3.new(width, 0.2, shopDepth),
		cframe = origin * CFrame.new(0, 0.2, Layout.STORE_FRONT_Z + shopDepth / 2),
		color = FLOOR,
		material = Enum.Material.Marble,
		parent = structure,
	})
	Parts.make({
		name = "BackroomFloor",
		size = Vector3.new(width, 0.2, Street.BACKROOM_DEPTH),
		cframe = origin * CFrame.new(0, 0.2, Layout.PARTITION_Z + Street.BACKROOM_DEPTH / 2),
		color = BACKROOM_FLOOR,
		material = Enum.Material.Concrete,
		parent = structure,
	})

	wallWithDoor(
		"FrontWall",
		origin,
		Layout.STORE_FRONT_Z + thickness / 2,
		Street.FRONT_DOOR_WIDTH,
		WALL,
		structure
	)
	wallWithDoor("BackWall", origin, Layout.STORE_BACK_Z - thickness / 2, 0, WALL, structure)
	wallWithDoor("Partition", origin, Layout.PARTITION_Z, Street.BACK_DOOR_WIDTH, WALL, structure)

	for _, sideSign in { -1, 1 } do
		Parts.make({
			name = "SideWall",
			size = Vector3.new(thickness, height, depth),
			cframe = origin * CFrame.new(sideSign * (width / 2 - thickness / 2), height / 2, centerZ),
			color = WALL,
			parent = structure,
		})
	end

	Parts.make({
		name = "Roof",
		size = Vector3.new(width + 2, 1, depth + 2),
		cframe = origin * CFrame.new(0, height + 0.5, centerZ),
		color = TRIM,
		parent = structure,
	})

	-- Faixa verde acima da porta, típica de loja de conveniência.
	Parts.make({
		name = "Awning",
		size = Vector3.new(width + 2, 1.5, 0.5),
		cframe = origin * CFrame.new(0, DOOR_HEIGHT + 0.75, Layout.STORE_FRONT_Z - 0.3),
		color = TRIM,
		parent = structure,
	})

	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Parent = Parts.make({
		name = "CeilingLight",
		size = Vector3.new(6, 0.3, 2),
		cframe = origin * CFrame.new(0, height - 0.2, (Layout.STORE_FRONT_Z + Layout.PARTITION_Z) / 2),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = structure,
	})
end

local function buildFixtures(origin: CFrame, store: Model, owner: Player)
	local sign = Parts.make({
		name = "Sign",
		size = Vector3.new(24, 4, 0.5),
		cframe = origin * CFrame.new(0, Street.STORE_HEIGHT + 3, Layout.STORE_FRONT_Z),
		color = TRIM,
		parent = store,
	})
	Parts.label(sign, `{owner.DisplayName}'s Mart`, Color3.new(1, 1, 1))

	-- Caixa: perto da entrada, do lado direito de quem entra.
	Parts.make({
		name = "Counter",
		size = Vector3.new(8, 4, 3),
		cframe = origin * CFrame.new(-9, 2, Layout.STORE_FRONT_Z + 7),
		color = COUNTER,
		material = Enum.Material.Wood,
		parent = store,
	})

	local shelves = Instance.new("Folder")
	shelves.Name = "Shelves"
	shelves.Parent = store
	for index = 1, Street.START_SHELVES do
		Parts.make({
			name = `Shelf{index}`,
			size = Vector3.new(2, 6, 10),
			cframe = origin * CFrame.new(4 + (index - 1) * 6, 3, Layout.STORE_FRONT_Z + 11),
			color = SHELF,
			material = Enum.Material.Metal,
			parent = shelves,
		})
	end

	Parts.make({
		name = "Safe",
		size = Vector3.new(3, 4, 3),
		cframe = origin * CFrame.new(-12.5, 2, Layout.PARTITION_Z - 3),
		color = SAFE,
		material = Enum.Material.DiamondPlate,
		parent = store,
	})

	Parts.make({
		name = "BackDoor",
		size = Vector3.new(Street.BACK_DOOR_WIDTH, DOOR_HEIGHT, Street.WALL_THICKNESS),
		cframe = origin * CFrame.new(0, DOOR_HEIGHT / 2, Layout.PARTITION_Z),
		color = SAFE,
		transparency = 1,
		canCollide = false,
		parent = store,
	})

	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = store
	for index = 1, Street.START_CELLS do
		StoreBuilder.addCell(origin, store, index)
	end

	local spawnPoint = Parts.make({
		name = "SpawnPoint",
		size = Vector3.new(4, 1, 4),
		cframe = origin * CFrame.new(0, 0.5, Layout.STORE_FRONT_Z - 4) * CFrame.Angles(0, math.pi, 0),
		color = TRIM,
		transparency = 1,
		canCollide = false,
		parent = store,
	})
	spawnPoint.CanQuery = false
end

-- Cria a cela número `index`. Exposto porque o upgrade de celas (PR 8) vai chamar isto.
function StoreBuilder.addCell(origin: CFrame, store: Model, index: number): Part
	local cells = store:FindFirstChild("Cells")
	assert(cells, "loja sem pasta Cells")

	local size = Street.CELL_SIZE
	local offset = Layout.cellOffset(index)
	return Parts.make({
		name = `Cell{index}`,
		size = size,
		cframe = origin * CFrame.new(offset + Vector3.new(0, 0.3 + size.Y / 2, 0)),
		color = CELL,
		material = Enum.Material.Glass,
		transparency = 0.6,
		canCollide = false,
		parent = cells,
	})
end

function StoreBuilder.build(origin: CFrame, owner: Player, parent: Instance): Model
	local store = Instance.new("Model")
	store.Name = "Store"
	store:SetAttribute("OwnerUserId", owner.UserId)

	buildStructure(origin, store)
	buildFixtures(origin, store, owner)

	store.Parent = parent
	return store
end

return StoreBuilder
