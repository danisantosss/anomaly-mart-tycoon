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
	requiresBuild: string?, -- parte da loja que precisa ter (shared/Builds.luau)
}

-- Prateleiras, celas e letreiro viraram partes da loja (botões do chão, shared/Builds.luau). Aqui ficam os
-- upgrades "de número" do terminal.
local LIST: { Definition } = {
	{
		id = "PremiumProducts",
		displayName = "Premium Products",
		description = "+15% price on everything you sell.",
		maxLevel = 10,
		baseCost = 200,
	},
	{
		id = "BigShelves",
		displayName = "Bigger Shelves",
		description = "+4 stock on every shelf and fridge.",
		maxLevel = 5,
		baseCost = 300,
	},
	{
		id = "Advertising",
		displayName = "Advertising",
		description = "+10% customers.",
		maxLevel = 5,
		baseCost = 400,
	},
	{
		id = "FastRegister",
		displayName = "Fast Register",
		description = "Charge +1 customer per press.",
		maxLevel = 3,
		baseCost = 500,
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
		baseCost = 600,
		requiresBuild = "Backroom",
	},
	{
		id = "DoorLock",
		displayName = "Reinforced Lock",
		description = "Steel door stays locked +20s.",
		maxLevel = 3,
		baseCost = 2500,
		requiresBuild = "SteelDoor",
	},
}

Upgrades.LIST = LIST
Upgrades.COST_GROWTH = 1.7 -- cada nível custa 1,7× o anterior

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
