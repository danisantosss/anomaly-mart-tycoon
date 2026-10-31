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

-- Ajudas para testar no Studio. Não têm efeito no jogo publicado.
Config.Debug = {
	-- Enquanto ainda não existem vendas nem celas, o cofre ganha este valor por segundo no Studio, para dar
	-- para testar a coleta. Vai a 0 quando as fontes de renda de verdade chegarem (PRs 5 e 6).
	STUDIO_SAFE_INCOME_PER_SECOND = 25,
}

return Config
