--!strict
-- Constrói cada parte da loja que o jogador compra (catálogo em shared/Builds.luau, mesmos ids).
-- Também monta os móveis que vendem (prateleiras, geladeiras, balcão de comida) e a barraquinha inicial.
--
-- Tudo em peças simples do Roblox (Part), sem modelo 3D externo. As coordenadas são locais do terreno
-- (ver Layout.luau): X de -24 a 24 é a largura da loja, Z = -32 é a frente (rua) e Z = 2 a divisória da sala
-- dos fundos. Cada peça criada entra em `ctx.created`, para o Builds animar a construção.
--
-- Nomes que outros sistemas procuram (o "contrato" da loja):
--   Counter, Shelves/<móvel>, Cells/, Safe, UpgradeTerminal, SpawnPoint, BackDoor, Sign,
--   Structure/CeilingLight (piscam quando uma anomalia é atendida), AutoDoor/ (portas automáticas)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)

local Street = Config.Street

local Pieces = {}

export type Ctx = {
	origin: CFrame,
	store: Model,
	owner: Player,
	created: { BasePart },
}

-- Paleta: loja de conveniência 24h, limpa de dia e meio estranha de madrugada.
local WHITE = Color3.fromRGB(246, 244, 238)
local TILE_A = Color3.fromRGB(236, 240, 236)
local TILE_B = Color3.fromRGB(196, 222, 210)
local GREEN = Color3.fromRGB(38, 166, 120)
local DARK = Color3.fromRGB(40, 44, 52)
local STEEL = Color3.fromRGB(150, 156, 166)
local WOOD = Color3.fromRGB(150, 104, 70)
local GLASS = Color3.fromRGB(170, 215, 235)
local PINK = Color3.fromRGB(255, 70, 160)
local GOLD = Color3.fromRGB(255, 200, 60)
local CONCRETE = Color3.fromRGB(150, 150, 152)

local PRODUCT_COLORS = {
	Color3.fromRGB(230, 70, 70),
	Color3.fromRGB(250, 190, 60),
	Color3.fromRGB(70, 150, 230),
	Color3.fromRGB(120, 200, 90),
	Color3.fromRGB(240, 120, 200),
	Color3.fromRGB(250, 140, 50),
	Color3.fromRGB(150, 110, 220),
}

local HEIGHT = Street.STORE_HEIGHT
local HALF = Street.STORE_WIDTH / 2
local FRONT = Layout.STORE_FRONT_Z
local BACK = Layout.STORE_BACK_Z
local PARTITION = Layout.PARTITION_Z
local WALL = Street.WALL_THICKNESS
local DOOR_HEIGHT = 9

local random = Random.new()

type BoxProps = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	parent: Instance?,
}

-- Cria uma peça em coordenadas locais do terreno e registra para a animação.
local function box(ctx: Ctx, parent: Instance, name: string, size: Vector3, at: CFrame, props: BoxProps): Part
	local part = Parts.make({
		name = name,
		size = size,
		cframe = ctx.origin * at,
		color = props.color,
		material = props.material,
		transparency = props.transparency,
		canCollide = props.canCollide,
		parent = props.parent or parent,
	})
	table.insert(ctx.created, part)
	return part
end

-- Peça "enfeite": não atrapalha ninguém andar nem os botões de interação.
local function decor(
	ctx: Ctx,
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	props: BoxProps
): Part
	local part = box(ctx, parent, name, size, at, props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function folder(ctx: Ctx, name: string): Folder
	local existing = ctx.store:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local new = Instance.new("Folder")
	new.Name = name
	new.Parent = ctx.store
	return new
end

-- Pasta própria de uma parte comprada (ex.: Built/Plants), para dar para achar e apagar depois.
local function pieceFolder(ctx: Ctx, id: string): Folder
	local built = folder(ctx, "Built")
	local existing = built:FindFirstChild(id)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local new = Instance.new("Folder")
	new.Name = id
	new.Parent = built
	return new
end

local function light(part: BasePart, color: Color3, range: number, brightness: number): PointLight
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Parent = part
	return pointLight
end

local function billboardText(part: BasePart, text: string, color: Color3, offset: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InfoBillboard"
	billboard.Size = UDim2.fromOffset(110, 30)
	billboard.StudsOffset = Vector3.new(0, offset, 0)
	billboard.MaxDistance = 45
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard
end

---------------------------------------------------------------------------------------------------------
-- Móveis que vendem: a peça principal (invisível) leva o nome e os atributos que o Shelves.luau lê; os
-- produtos ("Product") somem conforme o estoque cai.
---------------------------------------------------------------------------------------------------------

export type SellerKind = "Shelf" | "Fridge" | "HotFood"

local SELLERS = {
	Shelf = { capacity = 10, price = 1 },
	Fridge = { capacity = 12, price = 2 },
	HotFood = { capacity = 8, price = 4 },
}

local function product(
	ctx: Ctx,
	parent: BasePart,
	size: Vector3,
	at: CFrame,
	color: Color3,
	shape: Enum.PartType?
)
	local part = decor(ctx, parent, "Product", size, at, { color = color })
	if shape then
		part.Shape = shape
	end
	return part
end

local function buildShelfUnit(ctx: Ctx, unit: BasePart, x: number, z: number)
	local size = Street.SHELF_SIZE
	local function at(dx: number, y: number, dz: number): CFrame
		return CFrame.new(x + dx, y, z + dz)
	end
	decor(ctx, unit, "Base", Vector3.new(size.X, 0.4, size.Z), at(0, 0.4, 0), { color = DARK })
	decor(
		ctx,
		unit,
		"Back",
		Vector3.new(0.3, size.Y, size.Z),
		at(0, size.Y / 2 + 0.2, 0),
		{ color = STEEL, material = Enum.Material.Metal }
	)
	decor(
		ctx,
		unit,
		"Header",
		Vector3.new(size.X + 0.2, 0.7, size.Z + 0.2),
		at(0, size.Y + 0.4, 0),
		{ color = GREEN }
	)
	for _, y in { 1.4, 3.0, 4.6 } do
		decor(ctx, unit, "Board", Vector3.new(size.X, 0.15, size.Z), at(0, y, 0), { color = WHITE })
		for _, side in { -1, 1 } do
			for k = 0, 3 do
				local dz = -size.Z / 2 + 1 + k * 2
				product(
					ctx,
					unit,
					Vector3.new(0.9, 1.1, 1.5),
					at(side * 0.85, y + 0.65, dz),
					PRODUCT_COLORS[random:NextInteger(1, #PRODUCT_COLORS)]
				)
			end
		end
	end
end

local function buildFridgeUnit(ctx: Ctx, unit: BasePart, x: number, z: number)
	local size = Street.FRIDGE_SIZE
	local function at(dx: number, y: number, dz: number): CFrame
		return CFrame.new(x + dx, y, z + dz)
	end
	-- Fundo e laterais brancos; vidro na frente (-Z, virado para a loja).
	decor(
		ctx,
		unit,
		"Body",
		Vector3.new(size.X, size.Y, 0.3),
		at(0, size.Y / 2, size.Z / 2 - 0.15),
		{ color = WHITE, material = Enum.Material.Metal }
	)
	for _, side in { -1, 1 } do
		decor(
			ctx,
			unit,
			"Side",
			Vector3.new(0.3, size.Y, size.Z),
			at(side * (size.X / 2 - 0.15), size.Y / 2, 0),
			{ color = WHITE, material = Enum.Material.Metal }
		)
	end
	decor(
		ctx,
		unit,
		"Top",
		Vector3.new(size.X, 0.8, size.Z),
		at(0, size.Y - 0.4, 0),
		{ color = Color3.fromRGB(30, 120, 220) }
	)
	local strip = decor(
		ctx,
		unit,
		"Light",
		Vector3.new(size.X - 0.8, 0.15, 0.3),
		at(0, size.Y - 0.95, 0),
		{ color = Color3.fromRGB(200, 240, 255), material = Enum.Material.Neon }
	)
	light(strip, Color3.fromRGB(200, 235, 255), 8, 0.8)
	decor(
		ctx,
		unit,
		"Glass",
		Vector3.new(size.X - 0.6, size.Y - 1.2, 0.1),
		at(0, size.Y / 2 - 0.2, -size.Z / 2 + 0.05),
		{ color = GLASS, material = Enum.Material.Glass, transparency = 0.7 }
	)
	for _, y in { 1.0, 2.8, 4.6 } do
		decor(
			ctx,
			unit,
			"Board",
			Vector3.new(size.X - 0.6, 0.12, size.Z - 0.4),
			at(0, y, 0),
			{ color = STEEL }
		)
		for k = 0, 3 do
			product(
				ctx,
				unit,
				Vector3.new(1.3, 0.55, 0.55),
				at(-1.5 + k, y + 0.7, -0.2) * CFrame.Angles(0, 0, math.pi / 2),
				PRODUCT_COLORS[random:NextInteger(1, #PRODUCT_COLORS)],
				Enum.PartType.Cylinder
			)
		end
	end
end

local function buildHotFoodUnit(ctx: Ctx, unit: BasePart, x: number, z: number)
	local size = Street.FRIDGE_SIZE
	local function at(dx: number, y: number, dz: number): CFrame
		return CFrame.new(x + dx, y, z + dz)
	end
	decor(
		ctx,
		unit,
		"Counter",
		Vector3.new(size.X, 3.4, size.Z),
		at(0, 1.7, 0),
		{ color = STEEL, material = Enum.Material.Metal }
	)
	decor(
		ctx,
		unit,
		"Dome",
		Vector3.new(size.X - 0.4, 1.6, size.Z - 0.4),
		at(0, 4.2, 0),
		{ color = GLASS, material = Enum.Material.Glass, transparency = 0.6 }
	)
	local lamp = decor(
		ctx,
		unit,
		"HeatLamp",
		Vector3.new(size.X - 0.6, 0.2, 0.6),
		at(0, 5.2, 0),
		{ color = Color3.fromRGB(255, 90, 40), material = Enum.Material.Neon }
	)
	light(lamp, Color3.fromRGB(255, 120, 60), 8, 1)
	decor(
		ctx,
		unit,
		"Menu",
		Vector3.new(size.X, 1.6, 0.2),
		at(0, 6.8, size.Z / 2 - 0.1),
		{ color = Color3.fromRGB(220, 50, 40) }
	)
	for k = 0, 7 do
		product(
			ctx,
			unit,
			Vector3.new(1.4, 0.45, 0.45),
			at(-1.8 + (k % 4) * 1.2, 3.65, if k < 4 then -0.4 else 0.4),
			Color3.fromRGB(205, 110, 60),
			Enum.PartType.Cylinder
		)
	end
end

-- Cria um móvel que vende na vaga `name` (ver Layout.slot). Devolve a peça principal.
function Pieces.seller(ctx: Ctx, name: string, kind: SellerKind): Part
	local shelves = folder(ctx, "Shelves")
	local spot = Layout.slot(name)
	local size = if kind == "Shelf" then Street.SHELF_SIZE else Street.FRIDGE_SIZE
	local unit = box(
		ctx,
		shelves,
		name,
		size,
		CFrame.new(spot.X, size.Y / 2, spot.Z),
		{ color = WHITE, transparency = 1 }
	)
	unit:SetAttribute("Capacity", SELLERS[kind].capacity)
	unit:SetAttribute("PriceMultiplier", SELLERS[kind].price)
	unit:SetAttribute("SellerKind", kind)
	if kind ~= "Shelf" then
		unit:SetAttribute("Front", true) -- o cliente pega pela frente, não pelo lado
	end
	if kind == "Shelf" then
		buildShelfUnit(ctx, unit, spot.X, spot.Z)
	elseif kind == "Fridge" then
		buildFridgeUnit(ctx, unit, spot.X, spot.Z)
	else
		buildHotFoodUnit(ctx, unit, spot.X, spot.Z)
	end
	return unit
end

---------------------------------------------------------------------------------------------------------
-- Barraquinha inicial: o que todo jogador novo tem (balcão com toldo, uma prateleira, cofre, terminal).
---------------------------------------------------------------------------------------------------------

local function buildCounter(ctx: Ctx)
	local counter = box(
		ctx,
		ctx.store,
		"Counter",
		Vector3.new(10, 4, 3),
		CFrame.new(-14, 2, -24),
		{ color = WOOD, material = Enum.Material.WoodPlanks }
	)
	decor(ctx, counter, "Top", Vector3.new(10.4, 0.25, 3.4), CFrame.new(-14, 4.1, -24), { color = DARK })
	decor(ctx, counter, "Register", Vector3.new(1.8, 1.1, 1.4), CFrame.new(-10.5, 4.8, -24), { color = DARK })
	decor(
		ctx,
		counter,
		"Screen",
		Vector3.new(1.4, 0.8, 0.1),
		CFrame.new(-10.5, 5.6, -24.6),
		{ color = Color3.fromRGB(90, 255, 160), material = Enum.Material.Neon }
	)
	decor(
		ctx,
		counter,
		"Belt",
		Vector3.new(5, 0.1, 1.6),
		CFrame.new(-15.5, 4.25, -24),
		{ color = Color3.fromRGB(25, 25, 28) }
	)
end

local function buildKiosk(ctx: Ctx, structure: Folder)
	local awning = Instance.new("Folder")
	awning.Name = "KioskAwning"
	awning.Parent = structure
	for _, x in { -20, -8 } do
		for _, z in { -27.5, -20.5 } do
			decor(
				ctx,
				awning,
				"Pole",
				Vector3.new(0.4, 9, 0.4),
				CFrame.new(x, 4.5, z),
				{ color = STEEL, material = Enum.Material.Metal }
			)
		end
	end
	for k = 0, 5 do
		decor(ctx, awning, "Stripe", Vector3.new(2, 0.3, 8.5), CFrame.new(-19 + k * 2, 9.15, -24), {
			color = if k % 2 == 0 then GREEN else WHITE,
		})
	end
	local banner = decor(
		ctx,
		awning,
		"KioskSign",
		Vector3.new(12, 1.8, 0.3),
		CFrame.new(-14, 10.2, -28.3),
		{ color = GREEN }
	)
	Parts.label(banner, `{ctx.owner.DisplayName}'s Mart`, Color3.new(1, 1, 1))
	local lamp = decor(
		ctx,
		structure,
		"CeilingLight",
		Vector3.new(2, 0.3, 2),
		CFrame.new(-14, 8.8, -24),
		{ color = Color3.new(1, 1, 1), material = Enum.Material.Neon }
	)
	lamp:SetAttribute("Kiosk", true)
	light(lamp, Color3.fromRGB(255, 240, 210), 18, 1.4)
end

local function buildSafe(ctx: Ctx)
	local safe = box(
		ctx,
		ctx.store,
		"Safe",
		Vector3.new(3, 4, 3),
		CFrame.new(-21, 2, -1),
		{ color = Color3.fromRGB(62, 66, 74), material = Enum.Material.DiamondPlate }
	)
	decor(
		ctx,
		safe,
		"Dial",
		Vector3.new(0.2, 1, 1),
		CFrame.new(-19.4, 2.4, -1),
		{ color = GOLD, material = Enum.Material.Metal }
	).Shape =
		Enum.PartType.Cylinder
	decor(ctx, safe, "Handle", Vector3.new(0.2, 0.2, 1.2), CFrame.new(-19.4, 1.4, -1), { color = STEEL })
end

local function buildTerminal(ctx: Ctx)
	local terminal = box(
		ctx,
		ctx.store,
		"UpgradeTerminal",
		Vector3.new(2, 4.4, 1.2),
		CFrame.new(-5, 2.2, -29.5),
		{ color = DARK }
	)
	decor(
		ctx,
		terminal,
		"Screen",
		Vector3.new(1.6, 1.4, 0.1),
		CFrame.new(-5, 3.4, -30.15),
		{ color = Color3.fromRGB(80, 200, 255), material = Enum.Material.Neon }
	)
	decor(ctx, terminal, "Top", Vector3.new(2.2, 0.3, 1.4), CFrame.new(-5, 4.55, -29.5), { color = GREEN })
end

-- Monta a barraquinha inicial. Os outros móveis vêm das compras (Pieces.build).
function Pieces.buildStarter(ctx: Ctx)
	local structure = folder(ctx, "Structure")
	folder(ctx, "Shelves")
	folder(ctx, "Cells")
	buildKiosk(ctx, structure)
	buildCounter(ctx)
	buildSafe(ctx)
	buildTerminal(ctx)
	Pieces.seller(ctx, "Shelf1", "Shelf")

	local spawnPoint = box(
		ctx,
		ctx.store,
		"SpawnPoint",
		Vector3.new(4, 1, 4),
		CFrame.new(0, 0.5, FRONT - 5) * CFrame.Angles(0, math.pi, 0),
		{
			color = GREEN,
			transparency = 1,
			canCollide = false,
		}
	)
	spawnPoint.CanQuery = false
	spawnPoint.CanTouch = false
end

---------------------------------------------------------------------------------------------------------
-- Partes compradas (mesmos ids do shared/Builds.luau)
---------------------------------------------------------------------------------------------------------

-- Parede reta com um vão de porta no meio (ou sem vão, se doorWidth for 0), ocupando toda a largura.
local function wallAcross(
	ctx: Ctx,
	parent: Instance,
	name: string,
	z: number,
	doorWidth: number,
	color: Color3
)
	if doorWidth <= 0 then
		box(
			ctx,
			parent,
			name,
			Vector3.new(HALF * 2, HEIGHT, WALL),
			CFrame.new(0, HEIGHT / 2, z),
			{ color = color }
		)
		return
	end
	local segment = HALF - doorWidth / 2
	for _, side in { -1, 1 } do
		box(
			ctx,
			parent,
			name,
			Vector3.new(segment, HEIGHT, WALL),
			CFrame.new(side * (doorWidth / 2 + segment / 2), HEIGHT / 2, z),
			{ color = color }
		)
	end
	box(
		ctx,
		parent,
		name,
		Vector3.new(doorWidth, HEIGHT - DOOR_HEIGHT, WALL),
		CFrame.new(0, DOOR_HEIGHT + (HEIGHT - DOOR_HEIGHT) / 2, z),
		{ color = color }
	)
end

local BUILDERS: { [string]: (Ctx, Folder) -> () } = {}

BUILDERS.Floor = function(ctx, parent)
	local depth = PARTITION - FRONT
	local columns, rows = 8, 6
	local tileX, tileZ = HALF * 2 / columns, depth / rows
	for i = 0, columns - 1 do
		for j = 0, rows - 1 do
			local x = -HALF + tileX * (i + 0.5)
			local z = FRONT + tileZ * (j + 0.5)
			box(ctx, parent, "Tile", Vector3.new(tileX, 0.3, tileZ), CFrame.new(x, 0.15, z), {
				color = if (i + j) % 2 == 0 then TILE_A else TILE_B,
				material = Enum.Material.Marble,
			})
		end
	end
	decor(
		ctx,
		parent,
		"Doormat",
		Vector3.new(6, 0.05, 3),
		CFrame.new(0, 0.32, FRONT + 2),
		{ color = DARK, material = Enum.Material.Fabric }
	)
end

BUILDERS.Walls = function(ctx, parent)
	local depth = PARTITION - FRONT
	for _, side in { -1, 1 } do
		box(
			ctx,
			parent,
			"SideWall",
			Vector3.new(WALL, HEIGHT, depth),
			CFrame.new(side * (HALF - WALL / 2), HEIGHT / 2, FRONT + depth / 2),
			{ color = WHITE }
		)
		decor(
			ctx,
			parent,
			"Trim",
			Vector3.new(WALL + 0.1, 0.8, depth),
			CFrame.new(side * (HALF - WALL / 2), 3, FRONT + depth / 2),
			{ color = GREEN }
		)
	end
	-- Frente: mureta embaixo, viga em cima e colunas. As janelas ficam abertas até comprar a vitrine.
	local frontZ = FRONT + WALL / 2
	for _, side in { -1, 1 } do
		local width = HALF - Street.FRONT_DOOR_WIDTH / 2
		local centerX = side * (Street.FRONT_DOOR_WIDTH / 2 + width / 2)
		box(
			ctx,
			parent,
			"FrontBase",
			Vector3.new(width, 3, WALL),
			CFrame.new(centerX, 1.5, frontZ),
			{ color = WHITE }
		)
		box(
			ctx,
			parent,
			"FrontColumn",
			Vector3.new(1.5, HEIGHT, WALL + 0.4),
			CFrame.new(side * (HALF - 0.75), HEIGHT / 2, frontZ),
			{ color = GREEN }
		)
		box(
			ctx,
			parent,
			"FrontColumn",
			Vector3.new(1, HEIGHT, WALL + 0.4),
			CFrame.new(side * (Street.FRONT_DOOR_WIDTH / 2 + 0.5), HEIGHT / 2, frontZ),
			{ color = GREEN }
		)
	end
	box(
		ctx,
		parent,
		"FrontBeam",
		Vector3.new(HALF * 2, HEIGHT - 10, WALL),
		CFrame.new(0, 10 + (HEIGHT - 10) / 2, frontZ),
		{ color = WHITE }
	)
	-- Divisória da sala dos fundos (com o vão da porta).
	wallAcross(ctx, parent, "Partition", PARTITION, Street.BACK_DOOR_WIDTH, WHITE)
end

BUILDERS.Roof = function(ctx, parent)
	local structure = folder(ctx, "Structure")
	local awning = structure:FindFirstChild("KioskAwning")
	if awning then
		awning:Destroy()
	end
	for _, child in structure:GetChildren() do
		if child:GetAttribute("Kiosk") then
			child:Destroy()
		end
	end
	local depth = PARTITION - FRONT
	local centerZ = FRONT + depth / 2
	box(
		ctx,
		parent,
		"Roof",
		Vector3.new(HALF * 2 + 2, 1, depth + 2),
		CFrame.new(0, HEIGHT + 0.5, centerZ),
		{ color = GREEN }
	)
	decor(
		ctx,
		parent,
		"Ceiling",
		Vector3.new(HALF * 2 - 2, 0.2, depth - 1),
		CFrame.new(0, HEIGHT - 0.1, centerZ),
		{ color = WHITE }
	)
	local first = true
	for _, x in { -12, 0, 12 } do
		for _, z in { FRONT + 9, FRONT + 24 } do
			local panel = decor(
				ctx,
				if first then structure else parent,
				if first then "CeilingLight" else "LightPanel",
				Vector3.new(6, 0.2, 1.6),
				CFrame.new(x, HEIGHT - 0.3, z),
				{
					color = Color3.new(1, 1, 1),
					material = Enum.Material.Neon,
				}
			)
			local surface = Instance.new("SurfaceLight")
			surface.Face = Enum.NormalId.Bottom
			surface.Range = 18
			surface.Brightness = 1.2
			surface.Angle = 120
			surface.Color = Color3.fromRGB(240, 250, 255)
			surface.Parent = panel
			if first then
				light(panel, Color3.fromRGB(240, 250, 255), 30, 0.8)
				first = false
			end
		end
	end
end

BUILDERS.Storefront = function(ctx, parent)
	local frontZ = FRONT + WALL / 2
	for _, side in { -1, 1 } do
		local width = HALF - Street.FRONT_DOOR_WIDTH / 2 - 2.5
		local centerX = side * (Street.FRONT_DOOR_WIDTH / 2 + 1 + width / 2)
		box(ctx, parent, "Window", Vector3.new(width, 7, 0.3), CFrame.new(centerX, 6.5, frontZ), {
			color = GLASS,
			material = Enum.Material.Glass,
			transparency = 0.65,
		})
		for k = 1, 2 do
			decor(
				ctx,
				parent,
				"Mullion",
				Vector3.new(0.3, 7, 0.5),
				CFrame.new(centerX - width / 2 + k * width / 3, 6.5, frontZ),
				{ color = DARK }
			)
		end
	end
	-- Toldo listrado em cima da porta.
	for k = 0, 4 do
		decor(
			ctx,
			parent,
			"Awning",
			Vector3.new(2.4, 0.3, 3),
			CFrame.new(-4.8 + k * 2.4, 10.4, FRONT - 1.4) * CFrame.Angles(math.rad(-15), 0, 0),
			{
				color = if k % 2 == 0 then GREEN else WHITE,
			}
		)
	end
	local open = decor(
		ctx,
		parent,
		"OpenSign",
		Vector3.new(4, 1.4, 0.1),
		CFrame.new(12, 8.5, frontZ - 0.25),
		{ color = DARK }
	)
	Parts.label(open, "OPEN 24/7", PINK)
end

BUILDERS.AutoDoor = function(ctx, parent)
	local doors = folder(ctx, "AutoDoor")
	local frontZ = FRONT + WALL / 2
	local half = Street.FRONT_DOOR_WIDTH / 4
	for _, side in { -1, 1 } do
		local panel = decor(
			ctx,
			doors,
			if side < 0 then "Left" else "Right",
			Vector3.new(half * 2, DOOR_HEIGHT, 0.3),
			CFrame.new(side * half, DOOR_HEIGHT / 2, frontZ),
			{
				color = GLASS,
				material = Enum.Material.Glass,
				transparency = 0.55,
			}
		)
		panel:SetAttribute("ClosedX", side * half)
		panel:SetAttribute("Side", side)
	end
	decor(
		ctx,
		parent,
		"Sensor",
		Vector3.new(1, 0.4, 0.4),
		CFrame.new(0, DOOR_HEIGHT + 0.4, frontZ - 0.4),
		{ color = DARK }
	)
end

BUILDERS.NeonSign = function(ctx, parent)
	local sign = box(
		ctx,
		ctx.store,
		"Sign",
		Vector3.new(26, 4.5, 0.6),
		CFrame.new(0, HEIGHT + 3.2, FRONT + 0.5),
		{ color = Color3.fromRGB(20, 20, 26) }
	)
	local label = Parts.label(sign, `{ctx.owner.DisplayName}'s Mart`, PINK)
	label.TextStrokeColor3 = Color3.fromRGB(255, 180, 230)
	label.TextStrokeTransparency = 0.4
	local glow = decor(
		ctx,
		parent,
		"Glow",
		Vector3.new(26, 0.3, 0.3),
		CFrame.new(0, HEIGHT + 0.9, FRONT + 0.1),
		{ color = PINK, material = Enum.Material.Neon }
	)
	light(glow, PINK, 22, 1.6)
	for _, x in { -13.2, 13.2 } do
		decor(
			ctx,
			parent,
			"Edge",
			Vector3.new(0.3, 4.5, 0.3),
			CFrame.new(x, HEIGHT + 3.2, FRONT + 0.1),
			{ color = Color3.fromRGB(80, 255, 220), material = Enum.Material.Neon }
		)
	end
end

BUILDERS.Plants = function(ctx, parent)
	for _, spot in
		{
			Vector2.new(-22, FRONT + 2),
			Vector2.new(22, FRONT + 2),
			Vector2.new(22, PARTITION - 7),
			Vector2.new(-22, -12),
		}
	do
		local pot = box(
			ctx,
			parent,
			"Pot",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(spot.X, 0.8, spot.Y),
			{ color = Color3.fromRGB(190, 110, 70), material = Enum.Material.Slate }
		)
		pot.Shape = Enum.PartType.Cylinder
		pot.CFrame = ctx.origin * CFrame.new(spot.X, 0.8, spot.Y) * CFrame.Angles(0, 0, math.pi / 2)
		for k = 0, 2 do
			local leaf = decor(
				ctx,
				parent,
				"Leaves",
				Vector3.new(2.2, 2.2, 2.2),
				CFrame.new(spot.X + (k - 1) * 0.5, 2.6 + k * 0.8, spot.Y),
				{
					color = Color3.fromRGB(60, 150 + k * 20, 70),
					material = Enum.Material.Grass,
				}
			)
			leaf.Shape = Enum.PartType.Ball
		end
	end
end

local function sellerBuilder(name: string, kind: SellerKind): (Ctx, Folder) -> ()
	return function(ctx, _parent)
		Pieces.seller(ctx, name, kind)
	end
end
for index = 2, 8 do
	BUILDERS[`Shelf{index}`] = sellerBuilder(`Shelf{index}`, "Shelf")
end
for index = 1, 3 do
	BUILDERS[`Fridge{index}`] = sellerBuilder(`Fridge{index}`, "Fridge")
end
BUILDERS.HotFood = sellerBuilder("HotFood", "HotFood")

local function checkoutMachine(ctx: Ctx, parent: Folder, z: number, accent: Color3)
	local body = box(
		ctx,
		parent,
		"SelfCheckout",
		Vector3.new(2.6, 4, 2.6),
		CFrame.new(-21.5, 2, z),
		{ color = WHITE, material = Enum.Material.Metal }
	)
	decor(
		ctx,
		body,
		"Screen",
		Vector3.new(0.1, 1.4, 1.8),
		CFrame.new(-20.15, 4.2, z),
		{ color = accent, material = Enum.Material.Neon }
	)
	local beacon = decor(
		ctx,
		body,
		"Beacon",
		Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(-21.5, 4.6, z + 0.8),
		{ color = accent, material = Enum.Material.Neon }
	)
	light(beacon, accent, 8, 1)
end

BUILDERS.SelfCheckout = function(ctx, parent)
	checkoutMachine(ctx, parent, -16, Color3.fromRGB(80, 200, 255))
end

BUILDERS.SelfCheckout2 = function(ctx, parent)
	checkoutMachine(ctx, parent, -6, Color3.fromRGB(255, 120, 60))
end

BUILDERS.GoldenRegister = function(ctx, parent)
	decor(
		ctx,
		parent,
		"GoldTrim",
		Vector3.new(10.6, 0.4, 3.6),
		CFrame.new(-14, 3.7, -24),
		{ color = GOLD, material = Enum.Material.Foil }
	)
	local register = decor(
		ctx,
		parent,
		"GoldRegister",
		Vector3.new(2, 1.3, 1.6),
		CFrame.new(-17.5, 4.9, -24),
		{ color = GOLD, material = Enum.Material.Foil }
	)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Parent = register
end

BUILDERS.Backroom = function(ctx, parent)
	local depth = BACK - PARTITION
	local centerZ = PARTITION + depth / 2
	box(
		ctx,
		parent,
		"BackroomFloor",
		Vector3.new(HALF * 2, 0.3, depth),
		CFrame.new(0, 0.15, centerZ),
		{ color = CONCRETE, material = Enum.Material.Concrete }
	)
	for _, side in { -1, 1 } do
		box(
			ctx,
			parent,
			"BackroomWall",
			Vector3.new(WALL, HEIGHT, depth),
			CFrame.new(side * (HALF - WALL / 2), HEIGHT / 2, centerZ),
			{ color = Color3.fromRGB(205, 205, 200) }
		)
	end
	wallAcross(ctx, parent, "BackWall", BACK - WALL / 2, 0, Color3.fromRGB(205, 205, 200))
	box(
		ctx,
		parent,
		"BackroomRoof",
		Vector3.new(HALF * 2 + 2, 1, depth + 1),
		CFrame.new(0, HEIGHT + 0.5, centerZ + 0.5),
		{ color = DARK }
	)
	local lamp = decor(
		ctx,
		parent,
		"Lamp",
		Vector3.new(1.2, 0.4, 1.2),
		CFrame.new(0, HEIGHT - 0.4, centerZ),
		{ color = Color3.fromRGB(170, 220, 255), material = Enum.Material.Neon }
	)
	light(lamp, Color3.fromRGB(150, 200, 255), 26, 1.2)
	-- Placa "STAFF ONLY" em cima da porta, do lado da loja.
	local plate = decor(
		ctx,
		parent,
		"StaffSign",
		Vector3.new(5, 1.2, 0.2),
		CFrame.new(0, DOOR_HEIGHT + 1, PARTITION - WALL / 2 - 0.15),
		{ color = Color3.fromRGB(200, 40, 40) }
	)
	Parts.label(plate, "STAFF ONLY", Color3.new(1, 1, 1))
end

BUILDERS.SteelDoor = function(ctx, parent)
	local width = Street.BACK_DOOR_WIDTH
	for _, side in { -1, 1 } do
		decor(
			ctx,
			parent,
			"Frame",
			Vector3.new(0.5, DOOR_HEIGHT, WALL + 0.4),
			CFrame.new(side * (width / 2 + 0.25), DOOR_HEIGHT / 2, PARTITION),
			{
				color = Color3.fromRGB(240, 200, 40),
				material = Enum.Material.Metal,
			}
		)
	end
	-- A porta em si: invisível e sem colisão até o dono trancar (ver Door.luau).
	local door = box(
		ctx,
		ctx.store,
		"BackDoor",
		Vector3.new(width, DOOR_HEIGHT, WALL),
		CFrame.new(0, DOOR_HEIGHT / 2, PARTITION),
		{
			color = Color3.fromRGB(110, 115, 125),
			transparency = 1,
			canCollide = false,
		}
	)
	door.Material = Enum.Material.DiamondPlate
end

BUILDERS.Cameras = function(ctx, parent)
	for _, spot in
		{
			Vector3.new(-22, HEIGHT - 1.2, BACK - 2),
			Vector3.new(22, HEIGHT - 1.2, BACK - 2),
			Vector3.new(-22, HEIGHT - 1.2, FRONT + 2),
		}
	do
		local camera = decor(
			ctx,
			parent,
			"Camera",
			Vector3.new(1, 0.8, 1.6),
			CFrame.new(spot),
			{ color = Color3.fromRGB(230, 230, 230) }
		)
		local led = decor(
			ctx,
			camera,
			"Led",
			Vector3.new(0.25, 0.25, 0.25),
			CFrame.new(spot + Vector3.new(0, 0.2, 0.85)),
			{
				color = Color3.fromRGB(255, 40, 40),
				material = Enum.Material.Neon,
			}
		)
		led.Shape = Enum.PartType.Ball
	end
end

-- Máquinas do lado de fora (renda passiva). Ficam na coluna X = -29, com a frente virada para fora (-X).
local function machine(
	ctx: Ctx,
	parent: Folder,
	z: number,
	size: Vector3,
	color: Color3,
	screen: Color3,
	label: string
)
	local body = box(
		ctx,
		parent,
		"Machine",
		size,
		CFrame.new(-29, size.Y / 2, z),
		{ color = color, material = Enum.Material.Metal }
	)
	local panel = decor(
		ctx,
		body,
		"Screen",
		Vector3.new(0.1, size.Y * 0.45, size.Z * 0.7),
		CFrame.new(-29 - size.X / 2 - 0.05, size.Y * 0.62, z),
		{
			color = screen,
			material = Enum.Material.Neon,
		}
	)
	light(panel, screen, 10, 0.8)
	billboardText(body, label, Color3.fromRGB(120, 255, 140), size.Y / 2 + 1.2)
	return body
end

BUILDERS.Vending = function(ctx, parent)
	machine(
		ctx,
		parent,
		-26,
		Vector3.new(2.5, 7, 3.5),
		Color3.fromRGB(210, 40, 50),
		Color3.fromRGB(255, 240, 200),
		"+$1/s"
	)
end

BUILDERS.Coffee = function(ctx, parent)
	local body = machine(
		ctx,
		parent,
		-18,
		Vector3.new(2.5, 5, 3),
		Color3.fromRGB(90, 60, 40),
		Color3.fromRGB(255, 200, 120),
		"+$4/s"
	)
	local cup =
		decor(ctx, body, "Cup", Vector3.new(0.8, 0.8, 0.8), CFrame.new(-30.6, 1.5, -18), { color = WHITE })
	cup.Shape = Enum.PartType.Cylinder
end

BUILDERS.Arcade = function(ctx, parent)
	local body = machine(
		ctx,
		parent,
		-10,
		Vector3.new(3, 7.5, 3.5),
		Color3.fromRGB(60, 40, 140),
		Color3.fromRGB(80, 255, 255),
		"+$12/s"
	)
	decor(
		ctx,
		body,
		"Marquee",
		Vector3.new(0.2, 1, 3.4),
		CFrame.new(-30.6, 7, -10),
		{ color = PINK, material = Enum.Material.Neon }
	)
	decor(
		ctx,
		body,
		"Stick",
		Vector3.new(0.3, 0.8, 0.3),
		CFrame.new(-30.8, 3.8, -10.5),
		{ color = Color3.fromRGB(220, 30, 30) }
	)
end

BUILDERS.ATM = function(ctx, parent)
	machine(
		ctx,
		parent,
		-2,
		Vector3.new(2.5, 6, 3),
		Color3.fromRGB(30, 110, 70),
		Color3.fromRGB(120, 255, 170),
		"+$30/s"
	)
end

BUILDERS.Claw = function(ctx, parent)
	local body = machine(
		ctx,
		parent,
		6,
		Vector3.new(4, 3, 4),
		Color3.fromRGB(240, 80, 150),
		Color3.fromRGB(255, 220, 255),
		"+$75/s"
	)
	decor(
		ctx,
		body,
		"Glass",
		Vector3.new(4, 4, 4),
		CFrame.new(-29, 5, 6),
		{ color = GLASS, material = Enum.Material.Glass, transparency = 0.7 }
	)
	for k = 0, 8 do
		local ball = decor(
			ctx,
			body,
			"Prize",
			Vector3.new(1, 1, 1),
			CFrame.new(-30.2 + (k % 3) * 1.1, 3.6 + (k // 3) * 0.6, 4.8 + (k % 3) * 0.9),
			{
				color = PRODUCT_COLORS[(k % #PRODUCT_COLORS) + 1],
			}
		)
		ball.Shape = Enum.PartType.Ball
	end
end

BUILDERS.PhotoBooth = function(ctx, parent)
	local body = machine(
		ctx,
		parent,
		14,
		Vector3.new(4, 8, 4),
		Color3.fromRGB(30, 30, 36),
		Color3.fromRGB(255, 255, 255),
		"+$180/s"
	)
	decor(
		ctx,
		body,
		"Curtain",
		Vector3.new(0.2, 6, 2),
		CFrame.new(-31.1, 3.5, 15),
		{ color = Color3.fromRGB(200, 20, 40), material = Enum.Material.Fabric }
	)
end

BUILDERS.Statue = function(ctx, parent)
	local base = box(
		ctx,
		parent,
		"Pedestal",
		Vector3.new(5, 2, 5),
		CFrame.new(-29, 1, 24),
		{ color = WHITE, material = Enum.Material.Marble }
	)
	billboardText(base, "+$450/s", Color3.fromRGB(255, 220, 80), 12)
	local function gold(name: string, size: Vector3, at: Vector3)
		local part =
			decor(ctx, parent, name, size, CFrame.new(at), { color = GOLD, material = Enum.Material.Foil })
		return part
	end
	gold("Legs", Vector3.new(2, 3, 1), Vector3.new(-29, 3.5, 24))
	gold("Body", Vector3.new(2.6, 3, 1.4), Vector3.new(-29, 6.5, 24))
	local head = gold("Head", Vector3.new(2.6, 2.6, 2.6), Vector3.new(-29, 9.4, 24))
	head.Shape = Enum.PartType.Ball
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Parent = head
end

BUILDERS.Benches = function(ctx, parent)
	for _, x in { -12, 12 } do
		box(
			ctx,
			parent,
			"Bench",
			Vector3.new(6, 0.5, 2),
			CFrame.new(x, 1.5, FRONT - 6),
			{ color = WOOD, material = Enum.Material.WoodPlanks }
		)
		decor(
			ctx,
			parent,
			"Backrest",
			Vector3.new(6, 1.6, 0.3),
			CFrame.new(x, 2.5, FRONT - 6.9),
			{ color = WOOD, material = Enum.Material.WoodPlanks }
		)
		for _, dx in { -2.6, 2.6 } do
			decor(
				ctx,
				parent,
				"Leg",
				Vector3.new(0.3, 1.3, 1.8),
				CFrame.new(x + dx, 0.65, FRONT - 6),
				{ color = DARK }
			)
		end
	end
end

BUILDERS.StreetLamps = function(ctx, parent)
	for _, x in { -22, 22 } do
		box(
			ctx,
			parent,
			"Pole",
			Vector3.new(0.6, 12, 0.6),
			CFrame.new(x, 6, FRONT - 6),
			{ color = DARK, material = Enum.Material.Metal }
		)
		local bulb = decor(ctx, parent, "Bulb", Vector3.new(1.6, 0.6, 1.6), CFrame.new(x, 12.2, FRONT - 6), {
			color = Color3.fromRGB(255, 235, 180),
			material = Enum.Material.Neon,
		})
		light(bulb, Color3.fromRGB(255, 220, 160), 28, 1.5)
	end
end

BUILDERS.Parking = function(ctx, parent)
	box(
		ctx,
		parent,
		"Asphalt",
		Vector3.new(14, 0.2, 40),
		CFrame.new(32, 0.1, -12),
		{ color = Color3.fromRGB(60, 62, 66), material = Enum.Material.Asphalt }
	)
	for k = 0, 5 do
		decor(
			ctx,
			parent,
			"Line",
			Vector3.new(10, 0.05, 0.3),
			CFrame.new(32, 0.23, -30 + k * 7),
			{ color = WHITE }
		)
	end
	-- Um carrinho estacionado.
	local car = box(
		ctx,
		parent,
		"Car",
		Vector3.new(4.5, 2, 6.5),
		CFrame.new(32, 1.4, -5.5),
		{ color = Color3.fromRGB(70, 140, 230) }
	)
	decor(
		ctx,
		car,
		"Cabin",
		Vector3.new(3.8, 1.6, 3.5),
		CFrame.new(32, 3.2, -5),
		{ color = GLASS, material = Enum.Material.Glass, transparency = 0.3 }
	)
	for _, dx in { -2.1, 2.1 } do
		for _, dz in { -7.8, -3.2 } do
			local wheel = decor(
				ctx,
				car,
				"Wheel",
				Vector3.new(0.6, 1.4, 1.4),
				CFrame.new(32 + dx, 0.7, dz),
				{ color = DARK }
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end

BUILDERS.Mascot = function(ctx, parent)
	local mascot = folder(ctx, "Mascot")
	box(ctx, parent, "Blower", Vector3.new(2.4, 1.2, 2.4), CFrame.new(32, 0.6, -30), { color = DARK })
	for k = 0, 5 do
		local tube =
			decor(ctx, mascot, `Tube{k}`, Vector3.new(1.4, 1.6, 1.4), CFrame.new(32, 2 + k * 1.5, -30), {
				color = if k == 5 then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(240, 60, 60),
			})
		tube:SetAttribute("BaseY", 2 + k * 1.5)
	end
end

-- Constrói a parte comprada `id`. Devolve false se não existe construtor (ex.: celas, que o Cells cria).
function Pieces.build(ctx: Ctx, id: string): boolean
	local builder = BUILDERS[id]
	if builder == nil then
		return false
	end
	builder(ctx, pieceFolder(ctx, id))
	return true
end

return Pieces
