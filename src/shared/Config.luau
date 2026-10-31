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
	CELL_SIZE = Vector3.new(5, 8, 4), -- cabe um monstro da rua encolhido
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
	MAX_IN_STORE = 8, -- conta também quem ainda está andando do metrô até a loja
	MAX_IN_SERVER = 40, -- teto de NPCs somando todas as lojas (R15 pesa no celular)
	ITEM_PRICE = 5,
	NIGHT_PRICE_MULTIPLIER = 3,
	MIN_ITEMS = 1,
	MAX_ITEMS = 3,
	WALK_SPEED = 10,
	STREET_WALK_SPEED = 16, -- na rua, entre o túnel do metrô e a loja, andam mais rápido
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

-- Franquia (rebirth, docs/V2.md seção 4): recomeça a loja com um bônus permanente de renda.
Config.Franchise = {
	BASE_COST = 50000, -- saldo necessário para a 1ª Franquia...
	COST_GROWTH = 4, -- ...e cada próxima custa 4x a anterior
	INCOME_BONUS = 0.5, -- +50% de renda por Franquia
	MAX = 10,
}

-- Bônus que se multiplicam com a renda (docs/V2.md, seção 5).
Config.Bonuses = {
	INDEX_PER_ENTRY = 0.02, -- +2% de renda por anomalia + variante diferente no Index
	FRIEND_PER_FRIEND = 0.10, -- +10% por amigo no mesmo servidor...
	FRIEND_MAX = 0.30, -- ...até +30%
	BOOST_MULTIPLIER = 2, -- boost temporário (presentes, códigos, recompensa diária)
}

-- Recompensa diária: valor do dia 1 ao 7 da sequência (multiplicado por 1 + Franquias). O dia 7 também dá
-- um boost de 2x. Perder um dia volta para o dia 1.
Config.Daily = {
	REWARDS = { 100, 250, 500, 1000, 2000, 3500, 6000 },
	DAY7_BOOST_MINUTES = 15,
}

-- Presentes por tempo jogado na sessão (minutos). O 1º, 3º e 5º dão dinheiro (2 minutos da renda atual, no mínimo
-- $200); o 2º, 4º e 6º dão um boost de 2x por alguns minutos.
Config.Gifts = {
	MINUTES = { 3, 8, 15, 25, 40, 60 },
	CASH_SECONDS_OF_INCOME = 120,
	CASH_MIN = 200,
	BOOST_MINUTES = 5,
}

-- Códigos (divulgar no Discord/redes). Cada jogador usa cada código uma vez. Maiúsculas não importam.
Config.Codes = {
	RELEASE = { cash = 500 },
	ANOMALY = { cash = 1500 },
	NIGHTSHIFT = { boostMinutes = 10 },
}

-- Lua Vermelha (docs/V2.md, seção 6): algumas madrugadas viram evento para o servidor inteiro.
Config.RedMoon = {
	CHANCE = 0.25, -- chance de cada madrugada ser de Lua Vermelha
	ANOMALY_CHANCE_MULTIPLIER = 1.8,
	ANOMALY_CHANCE_MAX = 0.75,
	RARE_VARIANT_LUCK = 3, -- variantes raras ficam 3x mais prováveis (só sorte do jogo, nunca vendida)
}

-- Placar global (OrderedDataStore). Atualiza devagar para não estourar o limite do DataStore.
Config.Leaderboard = {
	UPDATE_SECONDS = 120,
	SIZE = 10,
}

-- Itens do catálogo do Roblox para os clientes (todos feitos pelo Roblox; testados no Studio em 2026-10-31 com
-- CreateHumanoidModelFromDescription). Lista vazia = só os acessórios feitos de Parts (server/CustomerModel.luau).
Config.CustomerLooks = {
	-- Cabeça clássica: sem ela o Roblox usa a cabeça nova (MeshPart) e ignora o rosto (Face).
	Heads = { 2432102561, 6340213, 6340101, 6340227 },
	Faces = {
		144075659,
		209995366,
		7074764,
		7699174,
		20418658,
		12145366,
		86487700,
		86487766,
		7074786,
		7317793,
		20722130,
	},
	Hair = {
		376548738,
		376524487,
		376526888,
		376527350,
		451221329,
		451220849,
		63690008,
		2956239660,
		1103003368,
		3814474927,
		3814476174,
		9243992729,
		9244021842,
		9174355709,
		9174354743,
		9244038785,
		7193442167,
		9244095135,
		7193448258,
		7193450455,
	},
	Hats = {
		607702162,
		417457461,
		48474313,
		2646473721,
		607700713,
		3403874988,
		4047554959,
		125886373,
		69937521,
	},
	Glasses = { 376526673, 376527500, 11884330, 62690529, 125369932, 25931812, 158066137 },
	Shirts = {
		607785314,
		3670737444,
		398633584,
		144076358,
		382538059,
		398635081,
		398634295,
		4047886060,
		4047884939,
		144076436,
		382537702,
		382537085,
	},
	Pants = {
		398633812,
		398635338,
		398634487,
		144076760,
		382538503,
		382537569,
		382537950,
		382537806,
		129459077,
		129458426,
	},
}

-- Monstros da rua (docs/V3.md, seção 3): saem da Fenda e atravessam a Avenida. Qualquer jogador captura pagando.
Config.StreetMonsters = {
	SPAWN_SECONDS_DAY = 6, -- um monstro novo a cada X segundos
	SPAWN_SECONDS_NIGHT = 4,
	SPAWN_SECONDS_RED_MOON = 2.5,
	MAX_ON_STREET = 14,
	WALK_SPEED = 5,
	DELIVERY_SPEED = 16, -- depois de capturado, corre para a sala dos fundos de quem pagou
	MANHOLE_CHANCE = 0.35, -- chance de sair de um bueiro no meio da rua em vez da Fenda
	LUCK_NIGHT = 1.6, -- de madrugada os raros ficam mais prováveis...
	LUCK_RED_MOON = 3, -- ...e na Lua Vermelha muito mais
	VARIANT_LUCK_NIGHT = 1.5,
	CAPTURE_HOLD_SECONDS = 0.6,
	ANNOUNCE = { Epic = true, Legendary = true, Mythic = true }, -- avisa o servidor inteiro quando um desses sai
}

-- Poderes dos monstros da rua quando estão numa cela (server/MonsterPowers.luau, docs/V3.md seção 6).
-- Cada monstro igual soma o poder de novo, até MAX_STACK (o Mimic Crate vai até MIMIC_MAX_STACK).
Config.MonsterPowers = {
	MAX_STACK = 3,
	MIMIC_MAX_STACK = 5,
	GLOOP_RESTOCK_SECONDS = 30, -- cada Gloop enche a prateleira mais vazia neste intervalo
	MIMIC_SHELF_BONUS = 2, -- itens a mais em cada prateleira, por Mimic Crate
	HOUND_HOLD_SECONDS = 1.5, -- segundos a mais para o ladrão abrir a cela, por Skull Hound
	SPIDER_CAPTURE_FASTER = 0.15, -- captura de anomalia disfarçada mais rápida, por Eye Spider
	TV_PRICE_BONUS = 0.1, -- preço dos itens, por TV Head
	JELLY_PASSIVE_BONUS = 0.2, -- renda das máquinas, por Static Jelly
	MOTH_NIGHT_CUSTOMERS = 0.25, -- clientes de madrugada, por Moth Monarch
	TALL_ONE_THIEF_SLOW = 0.7, -- velocidade do ladrão vezes isto (não soma, basta ter um)
	RIFT_KING_SERVER_BONUS = 0.1, -- renda de todo mundo no servidor, por Rift King no servidor inteiro
}

-- Invasão da Fenda (server/RiftInvasion.luau, docs/V3.md seção 7): um chefe gigante que o servidor inteiro
-- derruba junto.
Config.RiftInvasion = {
	NIGHT_CHANCE = 0.5, -- chance de ter invasão em cada madrugada (Lua Vermelha: sempre)
	STUDIO_NIGHT_CHANCE = 1, -- no Studio, para testar sem esperar
	DELAY_SECONDS = 20, -- depois que a madrugada começa
	WARNING_SECONDS = 12, -- aviso antes de ele sair da Fenda
	SCALE = 2.5, -- tamanho do Colosso (o modelo base tem uns 12 studs)
	WALK_SPEED = 3,
	HEALTH_BASE = 220,
	HEALTH_PER_EXTRA_PLAYER = 180, -- por jogador a mais no servidor
	ZAP_DAMAGE = 1,
	ZAP_COOLDOWN = 0.25, -- segundos entre dois Zaps do mesmo jogador
	ZAP_DISTANCE = 45,
	SLAM_EVERY_SECONDS = 9,
	SLAM_RADIUS = 30,
	SLAM_STUN_SECONDS = 2.5, -- quem é pego pela pancada fica sem dar Zap
	INCOME_DRAIN = 0.8, -- enquanto ele está vivo, a renda de todo mundo vezes isto
	REWARD_SECONDS = 120, -- prêmio = X segundos da renda do jogador...
	REWARD_MIN = 500, -- ...nunca menos que isto
	MVP_MULTIPLIER = 2, -- quem mais bateu ganha o dobro
	MIN_HITS = 3, -- precisa ter ajudado pelo menos isto para ganhar prêmio
	LOOT_COUNT = 5, -- monstros que caem quando ele morre
	LOOT_LUCK = 4, -- sorte de raridade desses monstros
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
	-- No Studio, chance de Lua Vermelha em cada madrugada (0 = usar a normal).
	STUDIO_RED_MOON_CHANCE = 0.5,
}

return Config
