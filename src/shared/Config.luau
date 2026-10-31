--!strict
-- Constantes compartilhadas entre servidor e cliente.
-- Tudo que for "número de ajuste" do jogo deve morar aqui, não espalhado pelo código.
-- Os valores seguem docs/V1.md.

local Config = {}

Config.VERSION = "0.0.1"

-- Rua e lojas (docs/V1.md, seção 1). Medidas em studs.
Config.Street = {
	PLOT_COUNT = 8, -- 4 de cada lado da rua
	PLOT_SIZE = 80, -- terreno quadrado
	PLOT_GAP = 4, -- espaço entre um terreno e outro
	ROAD_WIDTH = 40,
	SIDEWALK_DEPTH = 8, -- calçada entre a rua e a frente da loja

	STORE_WIDTH = 32,
	STORE_DEPTH = 32,
	STORE_HEIGHT = 14,
	WALL_THICKNESS = 1,
	FRONT_DOOR_WIDTH = 8,
	BACKROOM_DEPTH = 12, -- sala dos fundos, onde ficam as celas
	BACK_DOOR_WIDTH = 4,

	START_SHELVES = 2,
	START_CELLS = 3,
	MAX_CELLS = 12, -- 6 encostadas na parede do fundo + 6 ao lado da divisória
	CELL_SIZE = Vector3.new(3, 7, 3),
}

-- Dinheiro (docs/V1.md, seção 3).
Config.Economy = {
	SAFE_COLLECT_COOLDOWN = 1, -- segundos entre duas coletas seguidas no cofre
}

-- Ciclo dia e madrugada (docs/V1.md, seção 2). Em segundos.
Config.Cycle = {
	DAY_SECONDS = 8 * 60,
	NIGHT_SECONDS = 4 * 60,
	TRANSITION_SECONDS = 4, -- tempo da luz mudando
}

-- Clientes normais (docs/V1.md, seção 4).
Config.Customers = {
	DAY_INTERVAL = 6, -- segundos entre um cliente e outro, de dia
	NIGHT_INTERVAL = 15,
	MAX_IN_STORE = 6,
	ITEM_PRICE = 5,
	NIGHT_PRICE_MULTIPLIER = 3,
	MIN_ITEMS = 1,
	MAX_ITEMS = 3,
	WALK_SPEED = 10,
	CHECKOUT_PATIENCE = 30, -- segundos esperando no caixa antes de desistir e ir embora
	SHELF_CAPACITY = 10,
	RESTOCK_HOLD_SECONDS = 1,
}

-- Ajudas para testar no Studio. Não têm efeito no jogo publicado.
Config.Debug = {
	-- Renda extra por segundo no cofre, só no Studio. Útil para testar compras sem jogar muito.
	STUDIO_SAFE_INCOME_PER_SECOND = 0,
	-- Dia e madrugada mais curtos no Studio, para não precisar esperar 8 minutos. 0 = usar o normal.
	STUDIO_DAY_SECONDS = 60,
	STUDIO_NIGHT_SECONDS = 60,
}

return Config
