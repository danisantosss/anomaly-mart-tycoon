--!strict
-- Catálogo dos upgrades da loja (docs/V1.md, seção 7). Compartilhado: o servidor valida e aplica, o cliente
-- mostra a lista com nível e preço. O nível de cada um fica no atributo "Upgrade_<id>" do jogador.

local Upgrades = {}

export type Definition = {
	id: string,
	displayName: string,
	description: string,
	maxLevel: number,
	baseCost: number,
}

local LIST: { Definition } = {
	{
		id = "Shelves",
		displayName = "More Shelves",
		description = "+1 shelf. More stock, more sales.",
		maxLevel = 5,
		baseCost = 100,
	},
	{
		id = "FastRegister",
		displayName = "Fast Register",
		description = "Charge +1 customer per press.",
		maxLevel = 3,
		baseCost = 250,
	},
	{
		id = "Sneakers",
		displayName = "Sneakers",
		description = "+2 walk speed.",
		maxLevel = 5,
		baseCost = 150,
	},
	{
		id = "Flashlight",
		displayName = "Flashlight",
		description = "Capture anomalies faster.",
		maxLevel = 3,
		baseCost = 300,
	},
	{
		id = "Cells",
		displayName = "Containment Cell",
		description = "+1 cell for anomalies.",
		maxLevel = 9,
		baseCost = 500,
	},
	{
		id = "Sign",
		displayName = "Neon Sign",
		description = "+10% customers.",
		maxLevel = 3,
		baseCost = 400,
	},
}

Upgrades.LIST = LIST
Upgrades.COST_GROWTH = 1.6 -- cada nível custa 1,6× o anterior

local byId: { [string]: Definition } = {}
for _, definition in LIST do
	byId[definition.id] = definition
end

function Upgrades.get(id: string): Definition?
	return byId[id]
end

-- Preço para subir do nível `currentLevel` para o próximo.
function Upgrades.cost(id: string, currentLevel: number): number
	local definition = byId[id]
	if definition == nil then
		return math.huge
	end
	return math.floor(definition.baseCost * Upgrades.COST_GROWTH ^ currentLevel)
end

function Upgrades.attributeName(id: string): string
	return `Upgrade_{id}`
end

return Upgrades
