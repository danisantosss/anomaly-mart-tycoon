--!strict
-- Catálogo das partes da loja que o jogador compra nos botões do chão (docs/V2.md, seção 2).
--
-- O jogador começa com uma barraquinha (balcão, uma prateleira, cofre e terminal) e vai comprando o resto:
-- piso, paredes, teto, vitrine, prateleiras, geladeiras, sala dos fundos, celas, máquinas... Cada parte só
-- aparece para compra quando as partes em `requires` já foram compradas (e com a Franquia mínima).
--
-- Compartilhado: o servidor valida a compra e soma os efeitos; o cliente lê preços para colorir os botões.
-- Quem constrói as peças de verdade é o server/Street/Pieces.luau, pelo mesmo `id`.

local Builds = {}

export type Effects = {
	customers: number?, -- +fração de clientes (0.1 = +10%)
	passive: number?, -- $/s que cai no cofre
	chargeBatch: number?, -- clientes a mais por "Charge"
	selfCheckout: number?, -- cobra 1 humano sozinho a cada N segundos (vale o menor N)
	cells: number?, -- celas de contenção a mais
	cameras: boolean?, -- ladrões ficam mais lentos e o dono é avisado
}

export type Piece = {
	id: string,
	displayName: string,
	description: string,
	cost: number,
	requires: { string },
	franchise: number, -- nível mínimo de Franquia para aparecer
	pad: Vector2?, -- posição do botão no terreno (X, Z locais; ver Street/Layout.luau). Celas usam cellIndex.
	cellIndex: number?,
	effects: Effects?,
	keepOnFranchise: boolean?, -- continua comprada depois de abrir uma Franquia (sala dos fundos e celas)
}

local LIST: { Piece } = {}

local function add(piece: {
	id: string,
	displayName: string,
	description: string,
	cost: number,
	requires: { string }?,
	franchise: number?,
	pad: Vector2?,
	cellIndex: number?,
	effects: Effects?,
	keepOnFranchise: boolean?,
})
	table.insert(LIST, {
		id = piece.id,
		displayName = piece.displayName,
		description = piece.description,
		cost = piece.cost,
		requires = piece.requires or {},
		franchise = piece.franchise or 0,
		pad = piece.pad,
		cellIndex = piece.cellIndex,
		effects = piece.effects,
		keepOnFranchise = piece.keepOnFranchise,
	})
end

-- Estrutura da loja.
add({
	id = "Floor",
	displayName = "Tile Floor",
	description = "A real floor.",
	cost = 30,
	pad = Vector2.new(0, -27),
})
add({
	id = "Walls",
	displayName = "Walls",
	description = "Walls for your store.",
	cost = 150,
	requires = { "Floor" },
	pad = Vector2.new(-21, -30),
})
add({
	id = "Roof",
	displayName = "Roof & Lights",
	description = "Bright lights. Customers like it.",
	cost = 300,
	requires = { "Walls" },
	pad = Vector2.new(-21, -30),
	effects = { customers = 0.1 },
})
add({
	id = "Storefront",
	displayName = "Glass Storefront",
	description = "Big windows and a door frame.",
	cost = 450,
	requires = { "Walls" },
	pad = Vector2.new(21, -30),
	effects = { customers = 0.05 },
})
add({
	id = "AutoDoor",
	displayName = "Automatic Doors",
	description = "Whoosh! +5% customers.",
	cost = 700,
	requires = { "Storefront" },
	pad = Vector2.new(21, -30),
	effects = { customers = 0.05 },
})
add({
	id = "NeonSign",
	displayName = "Neon Sign",
	description = "Glows at night. +10% customers.",
	cost = 900,
	requires = { "Roof" },
	pad = Vector2.new(-21, -30),
	effects = { customers = 0.1 },
})
add({
	id = "Plants",
	displayName = "Plants",
	description = "A little green. +3% customers.",
	cost = 250,
	requires = { "Walls" },
	pad = Vector2.new(-10, -30),
	effects = { customers = 0.03 },
})

-- Prateleiras e geladeiras (cada uma é mais estoque para vender).
add({
	id = "Shelf2",
	displayName = "Shelf #2",
	description = "More stock.",
	cost = 60,
	requires = { "Floor" },
	pad = Vector2.new(13, -28.5),
})
add({
	id = "Shelf3",
	displayName = "Shelf #3",
	description = "More stock.",
	cost = 140,
	requires = { "Shelf2" },
	pad = Vector2.new(20, -28.5),
})
add({
	id = "Shelf4",
	displayName = "Shelf #4",
	description = "More stock.",
	cost = 350,
	requires = { "Shelf3", "Walls" },
	pad = Vector2.new(6, -16),
})
add({
	id = "Shelf5",
	displayName = "Shelf #5",
	description = "More stock.",
	cost = 800,
	requires = { "Shelf4" },
	pad = Vector2.new(13, -16),
})
add({
	id = "Shelf6",
	displayName = "Shelf #6",
	description = "More stock.",
	cost = 1800,
	requires = { "Shelf5", "Roof" },
	pad = Vector2.new(20, -16),
})
add({
	id = "Shelf7",
	displayName = "Shelf #7",
	description = "More stock.",
	cost = 4000,
	requires = { "Shelf6" },
	pad = Vector2.new(-14, -18.5),
})
add({
	id = "Shelf8",
	displayName = "Shelf #8",
	description = "More stock.",
	cost = 9000,
	requires = { "Shelf7" },
	pad = Vector2.new(-6, -18.5),
})
add({
	id = "Fridge1",
	displayName = "Drinks Fridge",
	description = "Cold drinks sell for 2x.",
	cost = 1200,
	requires = { "Roof" },
	pad = Vector2.new(6, -4),
})
add({
	id = "Fridge2",
	displayName = "Fridge #2",
	description = "Cold drinks sell for 2x.",
	cost = 5000,
	requires = { "Fridge1" },
	pad = Vector2.new(13, -4),
})
add({
	id = "Fridge3",
	displayName = "Fridge #3",
	description = "Cold drinks sell for 2x.",
	cost = 15000,
	requires = { "Fridge2" },
	pad = Vector2.new(20, -4),
})
add({
	id = "HotFood",
	displayName = "Hot Food Counter",
	description = "Hot snacks sell for 4x.",
	cost = 40000,
	requires = { "Fridge1" },
	franchise = 1,
	pad = Vector2.new(-14, -4),
})

-- Caixa e automação.
add({
	id = "SelfCheckout",
	displayName = "Self-Checkout",
	description = "Charges 1 human every 4s by itself.",
	cost = 3500,
	requires = { "Roof" },
	pad = Vector2.new(-21, -18),
	effects = { selfCheckout = 4 },
})
add({
	id = "SelfCheckout2",
	displayName = "Turbo Self-Checkout",
	description = "Self-checkout every 2s.",
	cost = 20000,
	requires = { "SelfCheckout" },
	pad = Vector2.new(-21, -18),
	effects = { selfCheckout = 2 },
})
add({
	id = "GoldenRegister",
	displayName = "Golden Register",
	description = "Charge +2 customers per press.",
	cost = 60000,
	requires = { "SelfCheckout" },
	franchise = 2,
	pad = Vector2.new(-14, -29.5),
	effects = { chargeBatch = 2 },
})

-- Sala dos fundos, celas e segurança.
add({
	id = "Backroom",
	displayName = "Back Room",
	description = "Unlocks containment cells for anomalies.",
	cost = 600,
	requires = { "Walls" },
	pad = Vector2.new(0, -2),
	effects = { cells = 1 },
	keepOnFranchise = true,
})
local CELL_BASE_COST = 500
for index = 2, 12 do
	add({
		id = `Cell{index}`,
		displayName = `Cell #{index}`,
		description = "Room for one more anomaly.",
		cost = math.floor(CELL_BASE_COST * 1.55 ^ (index - 2) / 50) * 50,
		requires = { if index == 2 then "Backroom" else `Cell{index - 1}` },
		cellIndex = index,
		effects = { cells = 1 },
		keepOnFranchise = true,
	})
end
add({
	id = "SteelDoor",
	displayName = "Steel Door",
	description = "Lock your back room against thieves.",
	cost = 1500,
	requires = { "Backroom" },
	pad = Vector2.new(-5, -2),
	keepOnFranchise = true,
})
add({
	id = "Cameras",
	displayName = "Security Cameras",
	description = "Thieves run slower and you get an alert.",
	cost = 4000,
	requires = { "SteelDoor" },
	pad = Vector2.new(-5, -2),
	effects = { cameras = true },
	keepOnFranchise = true,
})

-- Máquinas do lado de fora: renda passiva, como os "droppers" dos tycoons clássicos.
add({
	id = "Vending",
	displayName = "Vending Machine",
	description = "+$1/s, forever.",
	cost = 350,
	requires = { "Floor" },
	pad = Vector2.new(-34, -26),
	effects = { passive = 1 },
})
add({
	id = "Coffee",
	displayName = "Coffee Machine",
	description = "+$4/s.",
	cost = 1800,
	requires = { "Vending", "Storefront" },
	pad = Vector2.new(-34, -18),
	effects = { passive = 4 },
})
add({
	id = "Arcade",
	displayName = "Arcade Cabinet",
	description = "+$12/s.",
	cost = 7000,
	requires = { "Coffee" },
	pad = Vector2.new(-34, -10),
	effects = { passive = 12 },
})
add({
	id = "ATM",
	displayName = "ATM",
	description = "+$30/s.",
	cost = 20000,
	requires = { "Arcade" },
	franchise = 1,
	pad = Vector2.new(-34, -2),
	effects = { passive = 30 },
})
add({
	id = "Claw",
	displayName = "Claw Machine",
	description = "+$75/s.",
	cost = 60000,
	requires = { "ATM" },
	franchise = 2,
	pad = Vector2.new(-34, 6),
	effects = { passive = 75 },
})
add({
	id = "PhotoBooth",
	displayName = "Photo Booth",
	description = "+$180/s.",
	cost = 150000,
	requires = { "Claw" },
	franchise = 3,
	pad = Vector2.new(-34, 14),
	effects = { passive = 180 },
})
add({
	id = "Statue",
	displayName = "Golden Mascot Statue",
	description = "+$450/s. Pure flex.",
	cost = 400000,
	requires = { "PhotoBooth" },
	franchise = 4,
	pad = Vector2.new(-34, 24),
	effects = { passive = 450, customers = 0.1 },
})

-- Lado de fora: decoração que traz clientes.
add({
	id = "Benches",
	displayName = "Benches",
	description = "A place to sit. +3% customers.",
	cost = 400,
	requires = { "Floor" },
	pad = Vector2.new(10, -37),
	effects = { customers = 0.03 },
})
add({
	id = "StreetLamps",
	displayName = "Street Lamps",
	description = "Light up the night. +5% customers.",
	cost = 1100,
	requires = { "Benches" },
	pad = Vector2.new(10, -37),
	effects = { customers = 0.05 },
})
add({
	id = "Parking",
	displayName = "Parking Lot",
	description = "Room for cars. +10% customers.",
	cost = 2500,
	requires = { "Storefront" },
	pad = Vector2.new(32, -36),
	effects = { customers = 0.1 },
})
add({
	id = "Mascot",
	displayName = "Inflatable Mascot",
	description = "Waves at the street. +10% customers.",
	cost = 25000,
	requires = { "Parking" },
	franchise = 1,
	pad = Vector2.new(32, -36),
	effects = { customers = 0.1 },
})

Builds.LIST = LIST

local byId: { [string]: Piece } = {}
for _, piece in LIST do
	byId[piece.id] = piece
end

function Builds.get(id: string): Piece?
	return byId[id]
end

-- A peça pode aparecer para compra? (ainda não comprada, requisitos comprados, Franquia suficiente)
function Builds.isAvailable(owned: { [string]: boolean }, franchise: number, piece: Piece): boolean
	if owned[piece.id] or franchise < piece.franchise then
		return false
	end
	for _, required in piece.requires do
		if not owned[required] then
			return false
		end
	end
	return true
end

-- Soma um efeito numérico de todas as peças compradas.
function Builds.sum(owned: { [string]: boolean }, key: string): number
	local total = 0
	for id in owned do
		local piece = byId[id]
		local effects = piece and piece.effects
		local value = effects and (effects :: any)[key]
		if typeof(value) == "number" then
			total += value
		end
	end
	return total
end

function Builds.has(owned: { [string]: boolean }, key: string): boolean
	for id in owned do
		local piece = byId[id]
		if piece and piece.effects and (piece.effects :: any)[key] == true then
			return true
		end
	end
	return false
end

-- Intervalo do self-checkout em segundos, ou nil se não tem.
function Builds.selfCheckoutInterval(owned: { [string]: boolean }): number?
	local best: number? = nil
	for id in owned do
		local piece = byId[id]
		local interval = piece and piece.effects and piece.effects.selfCheckout
		if interval and (best == nil or interval < best) then
			best = interval
		end
	end
	return best
end

return Builds
