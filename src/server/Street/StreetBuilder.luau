--!strict
-- Constrói a Avenida fixa (docs/V3.md, seção 2). As lojas em si são criadas pelo StoreBuilder quando um
-- jogador recebe um terreno.
--
--   * rua com faixas, faixa de pedestre e, no meio, a Faixa da Fenda (roxa) por onde andam os monstros;
--   * a Fenda (portal na ponta oeste) e o Ralo de Contenção (ponta leste);
--   * pórtico "ANOMALY AVENUE" no meio, postes, hidrantes, lixeiras;
--   * becos atrás das lojas com carros e caçambas, árvores e prédios formando a cidade em volta;
--   * efeitos de luz (Atmosphere, Bloom, ColorCorrection).
--
-- Tudo sai de um Random com semente fixa: a cidade é igual em todos os servidores.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Decor = require(script.Parent.Decor)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)

local Street = Config.Street

local StreetBuilder = {}

local GRASS = Color3.fromRGB(86, 150, 70)
local ASPHALT = Color3.fromRGB(46, 48, 54)
local LINE = Color3.fromRGB(235, 235, 225)
local LOT = Color3.fromRGB(196, 190, 178)
local SIGN = Color3.fromRGB(245, 245, 240)
local LANE_BASE = Color3.fromRGB(38, 20, 58)
local RIFT = Color3.fromRGB(170, 70, 255)
local CONTAIN = Color3.fromRGB(80, 255, 140)
local HAZARD = Color3.fromRGB(240, 190, 30)

local SEED = 2026

local function buildPlot(index: number, parent: Instance): Model
	local plot = Instance.new("Model")
	plot.Name = `Plot{index}`
	plot:SetAttribute("PlotIndex", index)

	local origin = Layout.plotCFrame(index)

	local lot = Parts.make({
		name = "Lot",
		size = Vector3.new(Street.PLOT_SIZE, 0.1, Street.PLOT_SIZE),
		cframe = origin * CFrame.new(0, 0.05, 0),
		color = LOT,
		material = Enum.Material.Concrete,
		parent = plot,
	})
	plot.PrimaryPart = lot

	-- Calçada de ladrilho na frente do terreno, com meio-fio.
	Parts.make({
		name = "Sidewalk",
		size = Vector3.new(Street.PLOT_SIZE, 0.1, Street.SIDEWALK_DEPTH),
		cframe = origin * CFrame.new(0, 0.07, -Street.PLOT_SIZE / 2 + Street.SIDEWALK_DEPTH / 2),
		color = Color3.fromRGB(170, 168, 160),
		material = Enum.Material.Pavement,
		parent = plot,
	})
	Parts.make({
		name = "Curb",
		size = Vector3.new(Street.PLOT_SIZE, 0.35, 0.8),
		cframe = origin * CFrame.new(0, 0.17, -Street.PLOT_SIZE / 2 + 0.4),
		color = Color3.fromRGB(150, 150, 150),
		material = Enum.Material.Concrete,
		parent = plot,
	})

	-- Placa de "terreno livre", escondida quando alguém é dono do terreno.
	local sign = Parts.make({
		name = "AvailableSign",
		size = Vector3.new(12, 4, 0.5),
		cframe = origin * CFrame.new(0, 5, Layout.STORE_FRONT_Z),
		color = SIGN,
		parent = plot,
	})
	Parts.label(sign, "AVAILABLE", ASPHALT)

	plot.Parent = parent
	return plot
end

-- Rua, faixas e a Faixa da Fenda no meio.
local function buildRoad(street: Folder, length: number)
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = street

	Decor.part(
		road,
		"Asphalt",
		Vector3.new(length, 0.1, Street.ROAD_WIDTH),
		CFrame.new(0, 0.05, 0),
		ASPHALT,
		Enum.Material.Asphalt
	)

	-- Faixas tracejadas entre a Faixa da Fenda e as calçadas.
	local laneOffset = (Layout.LANE_HALF_WIDTH + Street.ROAD_WIDTH / 2) / 2
	for x = -length / 2 + 4, length / 2 - 4, 12 do
		for _, z in { -laneOffset, laneOffset } do
			Decor.part(road, "Dash", Vector3.new(6, 0.02, 0.5), CFrame.new(x, 0.11, z), LINE, nil, false)
		end
	end

	-- Faixas de pedestre nos dois cruzamentos.
	for _, x in { -84, 84 } do
		for z = -Street.ROAD_WIDTH / 2 + 2, Street.ROAD_WIDTH / 2 - 2, 3 do
			if math.abs(z) > Layout.LANE_HALF_WIDTH + 1 then
				Decor.part(
					road,
					"Crosswalk",
					Vector3.new(7, 0.02, 1.6),
					CFrame.new(x, 0.11, z),
					LINE,
					nil,
					false
				)
			end
		end
	end

	-- Faixa da Fenda: chão roxo escuro, bordas de neon e setas apontando para o Ralo.
	local lane = Instance.new("Folder")
	lane.Name = "RiftLane"
	lane.Parent = street
	local laneLength = Layout.DRAIN_X - Layout.RIFT_X
	local laneCenter = (Layout.DRAIN_X + Layout.RIFT_X) / 2
	Decor.part(
		lane,
		"LaneFloor",
		Vector3.new(laneLength, 0.12, Layout.LANE_HALF_WIDTH * 2),
		CFrame.new(laneCenter, 0.08, 0),
		LANE_BASE,
		Enum.Material.Slate
	)
	for _, z in { -Layout.LANE_HALF_WIDTH, Layout.LANE_HALF_WIDTH } do
		Decor.part(
			lane,
			"LaneEdge",
			Vector3.new(laneLength, 0.16, 0.5),
			CFrame.new(laneCenter, 0.1, z),
			RIFT,
			Enum.Material.Neon,
			false
		)
	end
	for x = Layout.RIFT_X + 20, Layout.DRAIN_X - 20, 22 do
		for _, side in { -1, 1 } do
			Decor.part(
				lane,
				"Chevron",
				Vector3.new(4, 0.05, 0.6),
				CFrame.new(x, 0.16, side * 1.3) * CFrame.Angles(0, side * math.rad(35), 0),
				Color3.fromRGB(120, 60, 200),
				Enum.Material.Neon,
				false
			)
		end
	end
end

-- A Fenda: portal de pedra com um redemoinho roxo girando, rachaduras no chão e barreiras.
local function buildRift(street: Folder)
	local rift = Instance.new("Model")
	rift.Name = "Rift"
	local base = CFrame.new(Layout.RIFT_X - 6, 0, 0)
	local stone = Color3.fromRGB(58, 52, 66)

	for _, side in { -1, 1 } do
		for level = 0, 4 do
			Decor.part(
				rift,
				"Pillar",
				Vector3.new(6 - level * 0.5, 7, 6 - level * 0.4),
				base
					* CFrame.new(0, 3.5 + level * 6.5, side * 15)
					* CFrame.Angles(0, math.rad(level * 17), math.rad(side * level * 3)),
				stone,
				Enum.Material.Slate
			)
		end
	end
	Decor.part(rift, "Lintel", Vector3.new(7, 5, 38), base * CFrame.new(0, 33, 0), stone, Enum.Material.Slate)
	for index = 1, 5 do
		Decor.part(
			rift,
			"Spike",
			Vector3.new(2, 6, 2),
			base * CFrame.new(0, 37, -12 + index * 4) * CFrame.Angles(0, 0, math.rad(index * 11 - 30)),
			stone,
			Enum.Material.Slate
		)
	end

	-- O redemoinho: um disco e três "pás" que giram em velocidades diferentes.
	local center = base * CFrame.new(1, 16, 0)
	local disc = Decor.part(
		rift,
		"Portal",
		Vector3.new(0.6, 26, 26),
		center,
		Color3.fromRGB(60, 10, 110),
		Enum.Material.Neon,
		false
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.15
	for index, speed in { 0.8, -1.3, 2.1 } do
		local blade = Decor.part(
			rift,
			"Swirl",
			Vector3.new(0.4, 24, 1.6 + index * 0.6),
			center * CFrame.new(0.4 + index * 0.1, 0, 0) * CFrame.Angles(math.rad(index * 60), 0, 0),
			RIFT,
			Enum.Material.Neon,
			false
		)
		blade.Transparency = 0.25 + index * 0.1
		Decor.spin(blade, speed)
	end
	local light = Instance.new("PointLight")
	light.Color = RIFT
	light.Range = 60
	light.Brightness = 3
	light.Parent = disc

	local ambient = Instance.new("ParticleEmitter")
	ambient.Name = "RiftMist"
	ambient.Color = ColorSequence.new(Color3.fromRGB(200, 140, 255), Color3.fromRGB(70, 0, 140))
	ambient.LightEmission = 0.8
	ambient.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	ambient.Transparency = NumberSequence.new(0.4, 1)
	ambient.Lifetime = NumberRange.new(2, 4)
	ambient.Rate = 12
	ambient.Speed = NumberRange.new(4, 8)
	ambient.EmissionDirection = Enum.NormalId.Right -- sai para +X, em direção à rua
	ambient.SpreadAngle = Vector2.new(35, 35)
	ambient.Parent = disc
	local burst = ambient:Clone()
	burst.Name = "RiftBurst" -- disparado pelo StreetMonsters quando sai um monstro
	burst.Rate = 0
	burst.Speed = NumberRange.new(12, 20)
	burst.Parent = disc

	-- Rachaduras de neon no chão saindo do portal.
	local random = Random.new(SEED + 1)
	for index = 1, 9 do
		local angle = math.rad(-70 + index * 14)
		local length = random:NextNumber(8, 18)
		Decor.part(
			rift,
			"Crack",
			Vector3.new(length, 0.06, 0.5),
			base * CFrame.Angles(0, angle, 0) * CFrame.new(length / 2 + 4, 0.2, 0),
			RIFT,
			Enum.Material.Neon,
			false
		)
	end

	-- Barreiras listradas e placa.
	for _, side in { -1, 1 } do
		for index = 0, 2 do
			local barrier = Decor.part(
				rift,
				"Barrier",
				Vector3.new(1, 3, 6),
				base * CFrame.new(16 + index * 7, 1.5, side * 12) * CFrame.Angles(0, math.rad(side * 15), 0),
				HAZARD,
				Enum.Material.SmoothPlastic
			)
			Decor.part(
				rift,
				"Stripe",
				Vector3.new(1.05, 0.8, 6.05),
				barrier.CFrame,
				Color3.fromRGB(25, 25, 25),
				Enum.Material.SmoothPlastic,
				false
			)
		end
	end
	local sign = Decor.part(
		rift,
		"RiftSign",
		Vector3.new(16, 4, 0.5),
		base * CFrame.new(22, 7, -52) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(25, 10, 40),
		Enum.Material.SmoothPlastic
	)
	Decor.sign(sign, "THE RIFT · monsters come out here", Color3.fromRGB(220, 170, 255))
	Decor.part(
		rift,
		"RiftSignPost",
		Vector3.new(0.6, 5, 0.6),
		base * CFrame.new(22, 2.5, -52),
		Color3.fromRGB(40, 40, 46),
		Enum.Material.Metal
	)

	rift.Parent = street
end

-- O Ralo de Contenção: tampa redonda com anel verde, tanques de vidro e aviso de perigo.
local function buildDrain(street: Folder)
	local drain = Instance.new("Model")
	drain.Name = "Drain"
	local base = CFrame.new(Layout.DRAIN_X, 0, 0)
	local metal = Color3.fromRGB(70, 74, 82)

	local plate = Decor.cylinder(
		drain,
		"Hatch",
		0.4,
		22,
		base * CFrame.new(0, 0.2, 0),
		metal,
		Enum.Material.DiamondPlate
	)
	plate.CanCollide = false
	local ring =
		Decor.cylinder(drain, "Ring", 0.5, 18, base * CFrame.new(0, 0.25, 0), CONTAIN, Enum.Material.Neon)
	ring.CanCollide = false
	local hole = Decor.cylinder(
		drain,
		"Hole",
		0.6,
		16,
		base * CFrame.new(0, 0.3, 0),
		Color3.fromRGB(8, 12, 10),
		Enum.Material.SmoothPlastic
	)
	hole.CanCollide = false
	for index = -3, 3 do
		Decor.part(
			drain,
			"Grate",
			Vector3.new(15, 0.3, 0.6),
			base * CFrame.new(0, 0.62, index * 2),
			metal,
			Enum.Material.Metal,
			false
		)
	end
	local glow = Instance.new("PointLight")
	glow.Color = CONTAIN
	glow.Range = 30
	glow.Brightness = 2
	glow.Parent = ring

	for _, side in { -1, 1 } do
		local tankBase = base * CFrame.new(10, 0, side * 16)
		Decor.cylinder(drain, "TankBase", 1, 7, tankBase * CFrame.new(0, 0.5, 0), metal, Enum.Material.Metal)
		local glass = Decor.cylinder(
			drain,
			"TankGlass",
			10,
			6,
			tankBase * CFrame.new(0, 6, 0),
			Color3.fromRGB(180, 230, 210),
			Enum.Material.Glass
		)
		glass.Transparency = 0.6
		Decor.cylinder(
			drain,
			"TankLiquid",
			7,
			5.4,
			tankBase * CFrame.new(0, 4.6, 0),
			CONTAIN,
			Enum.Material.Neon
		).Transparency =
			0.35
		Decor.cylinder(drain, "TankCap", 1, 7, tankBase * CFrame.new(0, 11.5, 0), metal, Enum.Material.Metal)
		Decor.part(
			drain,
			"Pipe",
			Vector3.new(10, 1, 1),
			tankBase * CFrame.new(-5, 1, -side * 4),
			metal,
			Enum.Material.Metal
		)
	end

	local sign = Decor.part(
		drain,
		"DrainSign",
		Vector3.new(18, 4, 0.5),
		base * CFrame.new(16, 9, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(20, 40, 28),
		Enum.Material.SmoothPlastic
	)
	Decor.sign(sign, "CONTAINMENT DRAIN", CONTAIN)
	for _, z in { -8, 8 } do
		Decor.part(
			drain,
			"DrainSignPost",
			Vector3.new(0.8, 7, 0.8),
			base * CFrame.new(16, 3.5, z),
			metal,
			Enum.Material.Metal
		)
	end
	drain.Parent = street
end

-- Bocas do metrô (de onde saem os clientes), calçada até elas e os bueiros dos monstros.
local function buildTunnels(street: Folder)
	local tunnels = Instance.new("Folder")
	tunnels.Name = "Tunnels"
	tunnels.Parent = street
	for _, mouth in Layout.tunnels() do
		Decor.subway(mouth, tunnels)
		-- Calçada ligando a boca do túnel às calçadas das lojas.
		local fromX, toX = mouth.Position.X, math.sign(mouth.Position.X) * (Layout.STREET_LENGTH / 2 - 2)
		local length = math.abs(fromX - toX) + 6
		Decor.part(
			tunnels,
			"Walkway",
			Vector3.new(length, 0.12, Street.SIDEWALK_DEPTH),
			CFrame.new(
				(fromX + toX) / 2,
				0.07,
				math.sign(mouth.Position.Z) * (Street.ROAD_WIDTH / 2 + Street.SIDEWALK_DEPTH / 2)
			),
			Color3.fromRGB(170, 168, 160),
			Enum.Material.Pavement,
			false
		)
	end
	for index, x in Layout.MANHOLES do
		Decor.manhole(CFrame.new(x, 0, 0), tunnels, `Manhole{index}`)
	end
end

-- Pórtico no meio da Avenida com o nome da rua.
local function buildGantry(street: Folder)
	local gantry = Instance.new("Model")
	gantry.Name = "Gantry"
	local steel = Color3.fromRGB(45, 48, 56)
	local half = Street.ROAD_WIDTH / 2 + 2
	for _, z in { -half, half } do
		Decor.part(gantry, "Pillar", Vector3.new(2, 26, 2), CFrame.new(0, 13, z), steel, Enum.Material.Metal)
	end
	local banner = Decor.part(
		gantry,
		"Banner",
		Vector3.new(1.2, 6, half * 2 - 2),
		CFrame.new(0, 23, 0),
		Color3.fromRGB(20, 18, 30),
		Enum.Material.SmoothPlastic
	)
	Decor.sign(banner, "ANOMALY AVENUE", Color3.fromRGB(255, 120, 220), nil, Enum.NormalId.Left)
	Decor.sign(banner, "ANOMALY AVENUE", Color3.fromRGB(120, 230, 255), nil, Enum.NormalId.Right)
	for _, x in { -0.7, 0.7 } do
		Decor.part(
			gantry,
			"NeonTrim",
			Vector3.new(0.2, 0.4, half * 2 - 2),
			CFrame.new(x, 26.2, 0),
			Color3.fromRGB(255, 80, 200),
			Enum.Material.Neon,
			false
		)
		Decor.part(
			gantry,
			"NeonTrimLow",
			Vector3.new(0.2, 0.4, half * 2 - 2),
			CFrame.new(x, 19.8, 0),
			Color3.fromRGB(80, 220, 255),
			Enum.Material.Neon,
			false
		)
	end
	gantry.Parent = street
end

local AD_TEXTS = {
	{ "ANOMALY MART · OPEN 24H", Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 40, 60) },
	{ "DO NOT FEED THE GLOOP", Color3.fromRGB(30, 30, 30), Color3.fromRGB(140, 230, 110) },
	{ "RIFT TOURS · ONE WAY ONLY", Color3.fromRGB(255, 230, 255), Color3.fromRGB(90, 40, 150) },
	{ "HAVE YOU SEEN THIS SHELF?", Color3.fromRGB(20, 20, 20), Color3.fromRGB(250, 220, 90) },
	{ "NIGHT SHIFT? STAY CALM. SMILE.", Color3.fromRGB(255, 255, 255), Color3.fromRGB(30, 40, 70) },
	{ "TV HEAD REPAIR · NO QUESTIONS", Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 110, 160) },
}

-- Postes, hidrantes, lixeiras e bancos ao longo da rua (na beira do asfalto, para não atrapalhar as lojas).
local function buildStreetProps(street: Folder)
	local props = Instance.new("Folder")
	props.Name = "StreetProps"
	props.Parent = street
	local edge = Street.ROAD_WIDTH / 2 - 1.2
	local half = Layout.STREET_LENGTH / 2
	for x = -half + 2, half - 2, 42 do
		if math.abs(x) > 3 then
			Decor.lamp(CFrame.new(x, 0, edge) * CFrame.Angles(0, 0, 0), props)
			Decor.lamp(CFrame.new(x + 21, 0, -edge) * CFrame.Angles(0, math.pi, 0), props)
		end
	end
	for _, x in { -150, -66, 66, 150 } do
		Decor.hydrant(CFrame.new(x, 0, edge + 0.2), props)
		Decor.trashCan(CFrame.new(x + 8, 0, -edge - 0.2), props)
	end

	-- Pracinhas nas duas pontas, perto da Fenda e do Ralo.
	local random = Random.new(SEED + 2)
	for _, x in { -half - 14, half + 14 } do
		for _, z in { -42, 42 } do
			Decor.bench(CFrame.new(x, 0, z) * CFrame.Angles(0, if z > 0 then 0 else math.pi, 0), props)
			Decor.tree(CFrame.new(x - 8, 0, z * 1.4), props, random)
			Decor.tree(CFrame.new(x + 8, 0, z * 1.5), props, random)
			Decor.bush(CFrame.new(x, 0, z * 1.25), props, random)
		end
	end
	Decor.billboard(
		CFrame.new(-half - 18, 0, 66) * CFrame.Angles(0, math.rad(200), 0),
		props,
		AD_TEXTS[2][1],
		AD_TEXTS[2][2],
		AD_TEXTS[2][3]
	)
	Decor.billboard(
		CFrame.new(half + 18, 0, -66) * CFrame.Angles(0, math.rad(20), 0),
		props,
		AD_TEXTS[1][1],
		AD_TEXTS[1][2],
		AD_TEXTS[1][3]
	)
end

-- Becos atrás das lojas (carros e caçambas), árvores e os prédios que fecham a cidade.
local function buildCity(street: Folder, length: number)
	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = street
	local random = Random.new(SEED)
	local plotBack = Street.ROAD_WIDTH / 2 + Street.PLOT_SIZE -- |z| onde os terrenos acabam
	local alleyZ = plotBack + 9
	local half = length / 2

	for _, side in { -1, 1 } do
		local facing = if side > 0 then 0 else math.pi -- frente (-Z) virada para a rua
		Decor.part(
			city,
			"Alley",
			Vector3.new(length, 0.1, 14),
			CFrame.new(0, 0.05, side * alleyZ),
			ASPHALT,
			Enum.Material.Asphalt
		)
		Decor.part(
			city,
			"AlleyWalk",
			Vector3.new(length, 0.3, 4),
			CFrame.new(0, 0.15, side * (alleyZ + 9)),
			Color3.fromRGB(160, 158, 150),
			Enum.Material.Pavement
		)

		local x = -half + 10
		while x < half - 10 do
			local roll = random:NextNumber()
			if roll < 0.45 then
				Decor.car(
					CFrame.new(x, 0, side * (alleyZ + 3.5)) * CFrame.Angles(0, math.rad(90), 0),
					city,
					random
				)
			elseif roll < 0.6 then
				Decor.dumpster(CFrame.new(x, 0, side * (alleyZ + 4.5)) * CFrame.Angles(0, facing, 0), city)
			end
			x += random:NextNumber(12, 20)
		end

		-- Fileira de árvores entre o beco e os prédios.
		x = -half + 6
		while x < half - 6 do
			Decor.tree(
				CFrame.new(x + random:NextNumber(-2, 2), 0, side * (alleyZ + 14 + random:NextNumber(-1, 1))),
				city,
				random
			)
			x += random:NextNumber(14, 22)
		end

		-- Prédios.
		x = -half
		local adIndex = if side > 0 then 3 else 5
		while x < half do
			local width = random:NextNumber(24, 44)
			local depth = random:NextNumber(24, 36)
			local height = random:NextNumber(26, 84)
			local center = CFrame.new(x + width / 2, 0, side * (alleyZ + 24 + depth / 2))
				* CFrame.Angles(0, facing, 0)
			Decor.building(center, city, random, width, depth, height)
			if random:NextNumber() < 0.25 then
				local ad = AD_TEXTS[adIndex]
				adIndex = adIndex % #AD_TEXTS + 1
				Decor.billboard(center * CFrame.new(0, height - 2, -depth / 2 + 2), city, ad[1], ad[2], ad[3])
			end
			x += width + random:NextNumber(1, 4)
		end
	end

	-- Morros escuros atrás da Fenda e prédios atrás do Ralo, fechando as pontas.
	for index = -4, 4 do
		local size = random:NextNumber(30, 60)
		local hill = Decor.ball(
			city,
			"Hill",
			size,
			CFrame.new(-half - 40 - random:NextNumber(0, 30), -size * 0.25, index * 34),
			Color3.fromRGB(60, 70, 60),
			Enum.Material.Grass
		)
		hill.CanCollide = true
	end
	for index = -3, 3 do
		local width = random:NextNumber(28, 40)
		Decor.building(
			CFrame.new(half + 60, 0, index * 42) * CFrame.Angles(0, math.rad(-90), 0),
			city,
			random,
			width,
			30,
			random:NextNumber(30, 90)
		)
	end
end

-- Luz e atmosfera. O DayNight muda as cores com o dia e a madrugada.
local function buildLighting()
	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local made = Instance.new(className)
		made.Name = name
		made.Parent = Lighting
		return made
	end
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.2
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.4
	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.05
	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
end

function StreetBuilder.build(): Folder
	local street = Instance.new("Folder")
	street.Name = "Street"

	local length = Layout.STREET_LENGTH + 140
	local plotBack = Street.ROAD_WIDTH / 2 + Street.PLOT_SIZE
	local width = (plotBack + 110) * 2

	Decor.part(
		street,
		"Ground",
		Vector3.new(length + 160, 1, width),
		CFrame.new(0, -0.5, 0),
		GRASS,
		Enum.Material.Grass
	)

	-- Paredes invisíveis na borda do chão.
	for _, data in
		{
			{ Vector3.new(length + 160, 60, 2), Vector3.new(0, 30, width / 2) },
			{ Vector3.new(length + 160, 60, 2), Vector3.new(0, 30, -width / 2) },
			{ Vector3.new(2, 60, width), Vector3.new((length + 160) / 2, 30, 0) },
			{ Vector3.new(2, 60, width), Vector3.new(-(length + 160) / 2, 30, 0) },
		}
	do
		local wall = Decor.part(street, "Boundary", data[1], CFrame.new(data[2]), Color3.new(), nil)
		wall.Transparency = 1
	end

	buildRoad(street, length)
	buildRift(street)
	buildDrain(street)
	buildGantry(street)
	buildTunnels(street)
	buildStreetProps(street)
	buildCity(street, length)
	buildLighting()

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = street
	for index = 1, Street.PLOT_COUNT do
		buildPlot(index, plots)
	end

	-- Spawn neutro no meio da rua, usado só por quem ainda não tem loja.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StreetSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.2, 12)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = street

	street.Parent = workspace
	return street
end

return StreetBuilder
