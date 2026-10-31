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
