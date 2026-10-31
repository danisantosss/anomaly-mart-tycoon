--!strict
-- Posição de cada terreno na rua. Módulo "puro": só faz contas, não cria nada no jogo.
--
-- A rua corre ao longo do eixo X, centrada em Z = 0. Os terrenos 1 a 4 ficam do lado +Z e os 5 a 8 do
-- lado -Z. O CFrame de cada terreno fica no centro dele, no chão, olhando para a rua (LookVector aponta
-- para a rua). Assim, no espaço local do terreno, "-Z" é a frente da loja.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Street = Config.Street

local Layout = {}

local PLOTS_PER_SIDE = Street.PLOT_COUNT // 2

-- Comprimento total da rua, usado para o asfalto e as calçadas.
Layout.STREET_LENGTH = PLOTS_PER_SIDE * (Street.PLOT_SIZE + Street.PLOT_GAP) + Street.PLOT_GAP

-- Faixa da Fenda: o caminho no meio da rua por onde os monstros andam, da Fenda (ponta -X) até o Ralo de
-- Contenção (ponta +X). Docs/V3.md, seção 2.
Layout.LANE_HALF_WIDTH = 5
Layout.RIFT_X = -(Layout.STREET_LENGTH / 2 + 34)
Layout.DRAIN_X = Layout.STREET_LENGTH / 2 + 34

-- Túneis do metrô: 4 bocas, nas duas pontas de cada calçada. Os clientes saem deles, andam até uma loja e
-- voltam para o túnel mais perto quando vão embora. O CFrame fica na boca do túnel, no chão, olhando para o
-- meio da rua (LookVector = para fora do túnel).
Layout.TUNNEL_X = Layout.STREET_LENGTH / 2 + 22
Layout.TUNNEL_Z = Street.ROAD_WIDTH / 2 + 6

function Layout.tunnels(): { CFrame }
	local list = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local mouth = Vector3.new(sx * Layout.TUNNEL_X, 0, sz * Layout.TUNNEL_Z)
			table.insert(list, CFrame.lookAt(mouth, Vector3.new(0, 0, mouth.Z)))
		end
	end
	return list
end

-- Bueiros na Faixa da Fenda (X de cada um): alguns monstros saem por eles em vez de sair da Fenda.
Layout.MANHOLES = { -110, -20, 64, 130 }

-- Meio da sala dos fundos, no espaço local do terreno (para onde vai o monstro capturado na rua).
function Layout.backroomCenter(): Vector3
	return Vector3.new(0, 0, (Layout.PARTITION_Z + Layout.STORE_BACK_Z) / 2)
end

function Layout.plotCFrame(index: number): CFrame
	assert(index >= 1 and index <= Street.PLOT_COUNT, `plot inválido: {index}`)

	local side = if index <= PLOTS_PER_SIDE then 1 else -1
	local column = (index - 1) % PLOTS_PER_SIDE -- 0..3

	local step = Street.PLOT_SIZE + Street.PLOT_GAP
	local x = (column - (PLOTS_PER_SIDE - 1) / 2) * step
	local z = side * (Street.ROAD_WIDTH / 2 + Street.PLOT_SIZE / 2)

	local center = Vector3.new(x, 0, z)
	local towardRoad = Vector3.new(x, 0, 0)
	return CFrame.lookAt(center, towardRoad)
end

-- Medidas da loja no espaço local do terreno (Z negativo = em direção à rua).
Layout.STORE_FRONT_Z = -Street.PLOT_SIZE / 2 + Street.SIDEWALK_DEPTH
Layout.STORE_BACK_Z = Layout.STORE_FRONT_Z + Street.STORE_DEPTH
Layout.PARTITION_Z = Layout.STORE_BACK_Z - Street.BACKROOM_DEPTH

-- Onde fica cada móvel que vende (centro, no chão, no espaço local do terreno). A loja vai de X = -24 a 24 e
-- de Z = -32 (frente) a 2 (divisória da sala dos fundos). Corredores de 4 studs entre as prateleiras, para
-- os clientes passarem. O cliente pega os itens pelo lado -X das prateleiras e pela frente das geladeiras.
local SLOTS: { [string]: Vector2 } = {
	Shelf1 = Vector2.new(6, -22),
	Shelf2 = Vector2.new(13, -22),
	Shelf3 = Vector2.new(20, -22),
	Shelf4 = Vector2.new(6, -10),
	Shelf5 = Vector2.new(13, -10),
	Shelf6 = Vector2.new(20, -10),
	Shelf7 = Vector2.new(-14, -12),
	Shelf8 = Vector2.new(-6, -12),
	Fridge1 = Vector2.new(6, 0.75),
	Fridge2 = Vector2.new(13, 0.75),
	Fridge3 = Vector2.new(20, 0.75),
	HotFood = Vector2.new(-14, 0.75),
}

function Layout.slot(name: string): Vector3
	local slot = SLOTS[name]
	assert(slot, `móvel sem lugar: {name}`)
	return Vector3.new(slot.X, 0, slot.Y)
end

-- `position` (no mundo) está dentro da sala dos fundos da loja do terreno `origin`?
function Layout.isInBackroom(origin: CFrame, position: Vector3): boolean
	local localPos = origin:PointToObjectSpace(position)
	return math.abs(localPos.X) < Street.STORE_WIDTH / 2
		and localPos.Z > Layout.PARTITION_Z
		and localPos.Z < Layout.STORE_BACK_Z
		and localPos.Y < Street.STORE_HEIGHT + 5
end

-- Centro (no chão) da cela número `index`, no espaço local do terreno.
-- Celas 1 a 6: fileira encostada na parede do fundo.
-- Celas 7 a 12: fileira ao lado da divisória, pulando o vão da porta dos fundos.
function Layout.cellOffset(index: number): Vector3
	assert(index >= 1 and index <= Street.MAX_CELLS, `cela inválida: {index}`)

	local depth = Street.CELL_SIZE.Z
	local spacing = Street.CELL_SIZE.X + 1.5

	if index <= 6 then
		local x = (index - 3.5) * spacing
		local z = Layout.STORE_BACK_Z - Street.WALL_THICKNESS - depth / 2
		return Vector3.new(x, 0, z)
	end

	-- 7, 8, 9 à esquerda da porta; 10, 11, 12 à direita.
	local k = index - 7 -- 0..5
	local sideSign = if k < 3 then -1 else 1
	local distance = Street.BACK_DOOR_WIDTH / 2 + spacing / 2 + (k % 3) * spacing
	local z = Layout.PARTITION_Z + Street.WALL_THICKNESS / 2 + depth / 2 + 0.5
	return Vector3.new(sideSign * distance, 0, z)
end

return Layout
