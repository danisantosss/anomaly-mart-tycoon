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

return Config
