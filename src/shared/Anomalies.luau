--!strict
-- Catálogo das anomalias e variantes (docs/V1.md, seção 5). Compartilhado: o servidor sorteia e calcula a
-- renda, o cliente usa para mostrar nomes.

local Anomalies = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

-- "Store": disfarçada de cliente, aparece na loja de madrugada e é capturada de graça (se você perceber).
-- "Street": monstro de verdade que sai da Fenda e anda pela Avenida; qualquer jogador pode capturar pagando
-- `captureCost` (docs/V3.md, seção 3).
export type Source = "Store" | "Street"

export type Definition = {
	id: string,
	displayName: string,
	rarity: Rarity,
	source: Source,
	incomePerSecond: number, -- renda na cela, antes da variante
	weight: number, -- chance relativa de aparecer (entre as do mesmo `source`)
	clue: string, -- loja: a pista para perceber a anomalia; rua: uma frase sobre o monstro
	captureCost: number?, -- só "Street": preço para capturar na rua, antes da variante
}

export type Variant = {
	id: string,
	displayName: string,
	multiplier: number, -- multiplica o $/s
	weight: number,
}

local LIST: { Definition } = {
	{
		id = "LongNeck",
		displayName = "Long Neck",
		rarity = "Common",
		source = "Store",
		incomePerSecond = 2,
		weight = 30,
		clue = "Look at the neck.",
	},
	{
		id = "Backwards",
		displayName = "Backwards",
		rarity = "Common",
		source = "Store",
		incomePerSecond = 2,
		weight = 30,
		clue = "It walks facing the wrong way.",
	},
	{
		id = "NoFace",
		displayName = "No Face",
		rarity = "Uncommon",
		source = "Store",
		incomePerSecond = 6,
		weight = 15,
		clue = "It has no face.",
	},
	{
		id = "Twin",
		displayName = "The Twin",
		rarity = "Uncommon",
		source = "Store",
		incomePerSecond = 6,
		weight = 12,
		clue = "It looks exactly like another customer.",
	},
	{
		id = "SaltBuyer",
		displayName = "Salt Buyer",
		rarity = "Rare",
		source = "Store",
		incomePerSecond = 20,
		weight = 9,
		clue = "It carries salt and empties the whole shelf.",
	},
	{
		id = "Smiler",
		displayName = "The Smiler",
		rarity = "Epic",
		source = "Store",
		incomePerSecond = 75,
		weight = 4,
		clue = "That smile is too wide.",
	},

	-- Monstros da rua (docs/V3.md, seção 3). Saem da Fenda, andam pela Avenida e entram no Ralo de Contenção
	-- do outro lado. Quem pagar o preço leva para a própria sala dos fundos.
	{
		id = "Gloop",
		displayName = "Gloop",
		rarity = "Common",
		source = "Street",
		incomePerSecond = 4,
		weight = 30,
		clue = "A wobbly slime that swallowed half the snack aisle.",
		captureCost = 250,
	},
	{
		id = "MimicCrate",
		displayName = "Mimic Crate",
		rarity = "Common",
		source = "Street",
		incomePerSecond = 5,
		weight = 26,
		clue = "Looks like a delivery. It bites.",
		captureCost = 350,
	},
	{
		id = "SkullHound",
		displayName = "Skull Hound",
		rarity = "Uncommon",
		source = "Street",
		incomePerSecond = 12,
		weight = 15,
		clue = "A bony dog with glowing ribs. Very good boy. Very wrong boy.",
		captureCost = 1200,
	},
	{
		id = "EyeSpider",
		displayName = "Eye Spider",
		rarity = "Uncommon",
		source = "Street",
		incomePerSecond = 15,
		weight = 12,
		clue = "One giant eye, eight long legs. It never blinks.",
		captureCost = 1800,
	},
	{
		id = "TVHead",
		displayName = "TV Head",
		rarity = "Rare",
		source = "Street",
		incomePerSecond = 40,
		weight = 7,
		clue = "A man in a suit with an old TV for a head. The channel is always static.",
		captureCost = 7500,
	},
	{
		id = "StaticJelly",
		displayName = "Static Jelly",
		rarity = "Rare",
		source = "Street",
		incomePerSecond = 55,
		weight = 5,
		clue = "A floating jellyfish that hums like a broken fridge.",
		captureCost = 12000,
	},
	{
		id = "MothMonarch",
		displayName = "Moth Monarch",
		rarity = "Epic",
		source = "Street",
		incomePerSecond = 160,
		weight = 2.5,
		clue = "Huge wings covered in eyes. It loves the neon sign.",
		captureCost = 45000,
	},
	{
		id = "TheTallOne",
		displayName = "The Tall One",
		rarity = "Legendary",
		source = "Street",
		incomePerSecond = 500,
		weight = 0.8,
		clue = "Taller than the store. Nobody saw it walk in.",
		captureCost = 200000,
	},
	{
		id = "RiftKing",
		displayName = "Rift King",
		rarity = "Mythic",
		source = "Street",
		incomePerSecond = 2000,
		weight = 0.15,
		clue = "The Rift itself, wearing a crown.",
		captureCost = 1000000,
	},
}

-- Sorteadas só com a sorte do jogo. Nunca vender por Robux (regra de itens aleatórios pagos).
local VARIANTS: { Variant } = {
	{ id = "Normal", displayName = "", multiplier = 1, weight = 600 },
	{ id = "Shiny", displayName = "Shiny", multiplier = 2, weight = 250 },
	{ id = "Inverted", displayName = "Inverted", multiplier = 3, weight = 100 },
	{ id = "Giant", displayName = "Giant", multiplier = 5, weight = 40 },
	{ id = "Glitch", displayName = "Glitch", multiplier = 10, weight = 10 },
}

local RARITY_COLORS: { [Rarity]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(110, 220, 110),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 60, 120),
}

Anomalies.LIST = LIST
Anomalies.VARIANTS = VARIANTS
Anomalies.RARITY_COLORS = RARITY_COLORS

local byId: { [string]: Definition } = {}
for _, definition in LIST do
	byId[definition.id] = definition
end

local variantById: { [string]: Variant } = {}
for _, variant in VARIANTS do
	variantById[variant.id] = variant
end

function Anomalies.get(id: string): Definition?
	return byId[id]
end

function Anomalies.getVariant(id: string): Variant
	return variantById[id] or variantById.Normal
end

-- Sorteia um índice de `weights`, com chance proporcional ao peso.
local function weightedIndex(weights: { number }, random: Random): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = random:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return index
		end
	end
	return #weights
end

-- Listas separadas por origem, para sortear só entre as da loja ou só entre as da rua.
local storeList: { Definition } = {}
local streetList: { Definition } = {}
for _, definition in LIST do
	table.insert(if definition.source == "Street" then streetList else storeList, definition)
end
Anomalies.STORE = storeList
Anomalies.STREET = streetList

local function weightsOf(list: { Definition }): { number }
	local weights = {}
	for _, definition in list do
		table.insert(weights, definition.weight)
	end
	return weights
end
local storeWeights = weightsOf(storeList)

local variantWeights = {}
for _, variant in VARIANTS do
	table.insert(variantWeights, variant.weight)
end

-- Sorteia uma anomalia disfarçada de cliente (loja).
function Anomalies.pickDefinition(random: Random): Definition
	return storeList[weightedIndex(storeWeights, random)]
end

-- Sorteia um monstro da rua. `luck` > 1 deixa os mais raros mais prováveis (madrugada, Lua Vermelha):
-- o peso de cada um é multiplicado por luck elevado ao "degrau" da raridade.
local RARITY_STEP: { [Rarity]: number } =
	{ Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

function Anomalies.pickStreet(random: Random, luck: number?): Definition
	local weights = {}
	for _, definition in streetList do
		local bonus = if luck and luck > 1 then luck ^ RARITY_STEP[definition.rarity] else 1
		table.insert(weights, definition.weight * bonus)
	end
	return streetList[weightedIndex(weights, random)]
end

-- Preço para capturar um monstro da rua nessa variante (a variante multiplica o preço como multiplica a renda).
function Anomalies.captureCost(id: string, variantId: string): number
	local definition = byId[id]
	if definition == nil or definition.captureCost == nil then
		return 0
	end
	return definition.captureCost * Anomalies.getVariant(variantId).multiplier
end

-- `luck` > 1 deixa as variantes raras mais prováveis (só a Normal fica com o peso de sempre). Usado na Lua
-- Vermelha. Sorte só do jogo: nunca vender isso por Robux.
function Anomalies.pickVariant(random: Random, luck: number?): Variant
	if luck == nil or luck <= 1 then
		return VARIANTS[weightedIndex(variantWeights, random)]
	end
	local lucky = {}
	for index, variant in VARIANTS do
		table.insert(
			lucky,
			if variant.id == "Normal" then variantWeights[index] else variantWeights[index] * luck
		)
	end
	return VARIANTS[weightedIndex(lucky, random)]
end

-- Quantas entradas o Index tem (tipos x variantes).
Anomalies.INDEX_SIZE = #LIST * #VARIANTS

function Anomalies.income(id: string, variantId: string): number
	local definition = byId[id]
	if definition == nil then
		return 0
	end
	return definition.incomePerSecond * Anomalies.getVariant(variantId).multiplier
end

-- Atributo do jogador que diz se ele já conseguiu essa anomalia nessa variante (Index).
function Anomalies.indexAttribute(id: string, variantId: string): string
	return `Index_{id}_{variantId}`
end

-- "Shiny Long Neck", ou só "Long Neck" na variante normal.
function Anomalies.fullName(id: string, variantId: string): string
	local definition = byId[id]
	local name = if definition then definition.displayName else id
	local variant = Anomalies.getVariant(variantId)
	return if variant.displayName ~= "" then `{variant.displayName} {name}` else name
end

return Anomalies
