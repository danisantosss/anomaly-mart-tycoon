--!strict
-- Catálogo das anomalias e variantes (docs/V1.md, seção 5). Compartilhado: o servidor sorteia e calcula a
-- renda, o cliente usa para mostrar nomes.

local Anomalies = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type Definition = {
	id: string,
	displayName: string,
	rarity: Rarity,
	incomePerSecond: number, -- renda na cela, antes da variante
	weight: number, -- chance relativa de aparecer de madrugada
	clue: string, -- a pista que o jogador deve aprender a notar (aparece na mensagem depois da decisão)
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
		incomePerSecond = 2,
		weight = 30,
		clue = "Look at the neck.",
	},
	{
		id = "Backwards",
		displayName = "Backwards",
		rarity = "Common",
		incomePerSecond = 2,
		weight = 30,
		clue = "It walks facing the wrong way.",
	},
	{
		id = "NoFace",
		displayName = "No Face",
		rarity = "Uncommon",
		incomePerSecond = 6,
		weight = 15,
		clue = "It has no face.",
	},
	{
		id = "Twin",
		displayName = "The Twin",
		rarity = "Uncommon",
		incomePerSecond = 6,
		weight = 12,
		clue = "It looks exactly like another customer.",
	},
	{
		id = "SaltBuyer",
		displayName = "Salt Buyer",
		rarity = "Rare",
		incomePerSecond = 20,
		weight = 9,
		clue = "It carries salt and empties the whole shelf.",
	},
	{
		id = "Smiler",
		displayName = "The Smiler",
		rarity = "Epic",
		incomePerSecond = 75,
		weight = 4,
		clue = "That smile is too wide.",
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

local definitionWeights = {}
for _, definition in LIST do
	table.insert(definitionWeights, definition.weight)
end

local variantWeights = {}
for _, variant in VARIANTS do
	table.insert(variantWeights, variant.weight)
end

function Anomalies.pickDefinition(random: Random): Definition
	return LIST[weightedIndex(definitionWeights, random)]
end

function Anomalies.pickVariant(random: Random): Variant
	return VARIANTS[weightedIndex(variantWeights, random)]
end

function Anomalies.income(id: string, variantId: string): number
	local definition = byId[id]
	if definition == nil then
		return 0
	end
	return definition.incomePerSecond * Anomalies.getVariant(variantId).multiplier
end

-- "Shiny Long Neck", ou só "Long Neck" na variante normal.
function Anomalies.fullName(id: string, variantId: string): string
	local definition = byId[id]
	local name = if definition then definition.displayName else id
	local variant = Anomalies.getVariant(variantId)
	return if variant.displayName ~= "" then `{variant.displayName} {name}` else name
end

return Anomalies
