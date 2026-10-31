--!strict
-- Isca da Fenda (docs/V3.md, seção 8): produto de Robux que chama um monstro da rua escolhido pelo jogador.
--
-- Não é caixinha de sorte: o jogador escolhe o monstro antes de pagar e recebe exatamente ele (variante
-- normal). O monstro sai do bueiro mais perto da loja e fica reservado para quem chamou por alguns segundos.
-- Para ficar com ele, o jogador ainda captura pagando o preço normal em dinheiro do jogo.
--
-- Fluxo:
--   1. o cliente manda "ChooseLure"(tipo);
--   2. o servidor confere o tipo e se o jogador tem cela livre, guarda a escolha e responde "LureApproved"(id
--      do produto); no Studio com Config.Debug.STUDIO_FREE_LURES chama o monstro na hora, sem compra;
--   3. o cliente abre a compra; quando o Roblox confirma, Receipts chama `grant`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cells = require(script.Parent.Cells)
local Receipts = require(script.Parent.Receipts)
local StreetMonsters = require(script.Parent.StreetMonsters)

type Product = { id: number, price: number, rarities: { string } }

local PRODUCTS = Config.RiftLure.PRODUCTS :: { [string]: Product }
local INFO = Color3.fromRGB(255, 230, 140)

local RiftLure = {}

local chosen: { [Player]: string } = {}
local notify: RemoteEvent

-- Produto que vende monstros desta raridade (nil = raridade que não se chama com Robux).
local function productFor(kind: string): (string?, Product?)
	local definition = Anomalies.get(kind)
	if definition == nil or definition.source ~= "Street" then
		return nil, nil
	end
	for key, product in PRODUCTS do
		if table.find(product.rarities, definition.rarity) then
			return key, product
		end
	end
	return nil, nil
end

local function grant(player: Player, key: string): boolean
	-- Usa a escolha feita antes da compra. Se ela se perdeu (o Roblox repetiu a entrega depois de o jogador
	-- voltar), entrega o primeiro monstro da lista desse produto: continua sendo algo certo, nunca sorteado.
	local kind = chosen[player]
	local chosenKey = if kind then productFor(kind) else nil
	if kind == nil or chosenKey ~= key then
		kind = nil
		for _, definition in Anomalies.STREET do
			if productFor(definition.id) == key then
				kind = definition.id
				break
			end
		end
	end
	if kind == nil then
		return false
	end
	chosen[player] = nil
	return StreetMonsters.summon(player, kind)
end

local function onChoose(player: Player, kind: unknown)
	if typeof(kind) ~= "string" then
		return
	end
	local key, product = productFor(kind)
	if key == nil or product == nil then
		return
	end
	if Cells.capacity(player) - Cells.count(player) <= 0 then
		notify:FireClient(player, "Free a cell first: you'll need room to capture it!", INFO)
		return
	end
	if RunService:IsStudio() and Config.Debug.STUDIO_FREE_LURES then
		StreetMonsters.summon(player, kind)
		return
	end
	if product.id == 0 then
		notify:FireClient(player, "Rift Lures are coming soon!", INFO)
		return
	end
	chosen[player] = kind
	Remotes.get("LureApproved"):FireClient(player, product.id)
end

function RiftLure.start()
	notify = Remotes.get("Notify")
	for key, product in PRODUCTS do
		Receipts.register(product.id, `RiftLure_{key}`, function(player)
			return grant(player, key)
		end)
	end
	Remotes.get("ChooseLure").OnServerEvent:Connect(onChoose)
	Players.PlayerRemoving:Connect(function(player)
		chosen[player] = nil
	end)
end

return RiftLure
