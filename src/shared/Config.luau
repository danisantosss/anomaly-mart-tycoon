--!strict
-- Constantes compartilhadas entre servidor e cliente.
-- Tudo que for "número de ajuste" do jogo deve morar aqui, não espalhado pelo código.
-- Os valores seguem docs/V1.md.

local Config = {}

Config.VERSION = "0.2.0"

-- Rua e lojas (docs/V1.md, seção 1). Medidas em studs.
Config.Street = {
	PLOT_COUNT = 8, -- 4 de cada lado da rua
	PLOT_SIZE = 80, -- terreno quadrado
	PLOT_GAP = 4, -- espaço entre um terreno e outro
	ROAD_WIDTH = 40,
	SIDEWALK_DEPTH = 8, -- calçada entre a rua e a frente da loja

	-- Tamanho da loja completa. O jogador começa só com uma barraquinha e vai comprando as partes
	-- (shared/Builds.luau).
	STORE_WIDTH = 48,
	STORE_DEPTH = 48,
	STORE_HEIGHT = 14,
	WALL_THICKNESS = 1,
	FRONT_DOOR_WIDTH = 8,
	BACKROOM_DEPTH = 14, -- sala dos fundos, onde ficam as celas
	BACK_DOOR_WIDTH = 5,

	SHELF_SIZE = Vector3.new(3, 6, 8),
	FRIDGE_SIZE = Vector3.new(5, 7, 2.5),
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
	MAX_IN_SERVER = 32, -- teto de NPCs somando todas as lojas (R15 pesa no celular)
	ITEM_PRICE = 5,
	NIGHT_PRICE_MULTIPLIER = 3,
	MIN_ITEMS = 1,
	MAX_ITEMS = 3,
	WALK_SPEED = 10,
	CHECKOUT_PATIENCE = 30, -- segundos esperando no caixa antes de desistir e ir embora
	SHELF_CAPACITY = 10, -- prateleira comum; geladeiras e balcão de comida têm a deles (shared/Builds.luau)
	RESTOCK_HOLD_SECONDS = 1,
}

-- Anomalias e celas (docs/V1.md, seções 5 e 6). Os tipos e variantes ficam em Shared/Anomalies.luau.
Config.Anomalies = {
	NIGHT_CHANCE = 1 / 3, -- chance de um cliente da madrugada ser anomalia
	BAD_SERVE_SAFE_LOSS = 0.10, -- atender uma anomalia: ela leva 10% do cofre...
	BAD_SERVE_MAX_LOSS_SECONDS = 60, -- ...mas no máximo 60 s da renda das celas (mínimo $100)
	MISTAKE_GRACE = 2, -- os 2 primeiros erros de cada sessão só dão aviso, sem punição
	REFUSED_HUMAN_PENALTY_SECONDS = 10, -- recusar/assustar humano: clientes vêm na metade do ritmo
	CAPTURE_HOLD_SECONDS = 2,
	CAPTURE_DISTANCE = 12,
	ESCAPE_AFTER_SECONDS = 30, -- anomalia ignorada esse tempo no caixa foge para o vizinho
}

-- Primeira anomalia do jogador novo (sem nenhuma cela): aparece de dia, logo depois das primeiras vendas, e
-- pode ser capturada mesmo de dia. Assim ele vê o diferencial do jogo sem esperar a madrugada.
Config.Tutorial = {
	SALES_BEFORE_ANOMALY = 2,
	ANOMALY = "LongNeck",
}

-- Roubo e porta de aço (docs/V1.md, seção 6).
Config.Steal = {
	HOLD_SECONDS = 2, -- segurar E na cela do outro
	CARRY_SPEED = 10, -- velocidade de quem carrega uma anomalia roubada
	CARRY_SPEED_CAMERAS = 7, -- ...roubando de uma loja com câmeras de segurança
	NORMAL_SPEED = 16,
	CATCH_DISTANCE = 5, -- o dono encostou no ladrão: a anomalia volta
}

Config.Door = {
	LOCK_SECONDS = 60,
	COOLDOWN_SECONDS = 120, -- contado a partir do momento em que trancou
}

-- Efeito de cada nível de upgrade (a lista e os preços ficam em Shared/Upgrades.luau).
Config.UpgradeEffects = {
	SNEAKERS_SPEED_PER_LEVEL = 2,
	FLASHLIGHT_HOLD_PER_LEVEL = 0.4, -- segundos a menos para capturar
	FLASHLIGHT_MIN_HOLD = 0.8,
	ADVERTISING_CUSTOMERS_PER_LEVEL = 0.10,
	PREMIUM_PRICE_PER_LEVEL = 0.15, -- +15% no preço de cada item
	BIG_SHELVES_CAPACITY_PER_LEVEL = 4,
	DOOR_LOCK_SECONDS_PER_LEVEL = 20,
}

-- Botões de compra no chão (shared/Builds.luau).
Config.Pads = {
	TOUCH_COOLDOWN = 0.6, -- segundos entre duas tentativas de compra do mesmo jogador
	BUILD_ANIMATION_SECONDS = 0.45,
}

-- Gamepasses (docs/V1.md, seção 8). Os IDs são criados pelo Daniel no Creator Hub (Monetization → Passes)
-- e colados aqui. Com 0, o botão de compra aparece como "Soon".
Config.GamePasses = {
	DoubleCash = { id = 0, displayName = "2x Cash", price = 199 },
	RestockRobot = { id = 0, displayName = "Restock Robot", price = 149 },
}
Config.RESTOCK_ROBOT_INTERVAL = 5 -- segundos entre as reposições automáticas

-- Ganho offline (docs/V1.md, seção 3).
Config.Offline = {
	FRACTION = 0.10, -- parte do $/s das celas que continua rendendo com o jogador fora
	MAX_HOURS = 8,
	MIN_SECONDS = 60, -- abaixo disso não mostra nada
}

-- Ajudas para testar no Studio. Não têm efeito no jogo publicado.
Config.Debug = {
	-- Renda extra por segundo no cofre, só no Studio. Útil para testar compras sem jogar muito.
	STUDIO_SAFE_INCOME_PER_SECOND = 0,
	-- Dia e madrugada mais curtos no Studio, para não precisar esperar 8 minutos. 0 = usar o normal.
	STUDIO_DAY_SECONDS = 60,
	STUDIO_NIGHT_SECONDS = 60,
	-- No Studio, a chance de anomalia de madrugada vira este valor (0 = usar a normal).
	STUDIO_NIGHT_ANOMALY_CHANCE = 0.6,
	-- No Studio, finge que o jogador tem todos os gamepasses (para testar os efeitos sem comprar).
	STUDIO_OWN_ALL_PASSES = false,
}

return Config
