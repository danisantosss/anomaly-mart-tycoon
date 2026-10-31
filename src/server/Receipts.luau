--!strict
-- Compras de Robux de produtos (Developer Products). O Roblox só aceita UM ProcessReceipt no jogo inteiro,
-- então todo produto se registra aqui com Receipts.register(id, entregar).
--
-- Regras do Roblox que seguimos:
--   * só devolve PurchaseGranted depois de entregar de verdade; se der errado, NotProcessedYet e o Roblox
--     tenta de novo mais tarde (por exemplo, quando o jogador voltar);
--   * guarda o PurchaseId nos dados do jogador para nunca entregar a mesma compra duas vezes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)

local MAX_SAVED = 50 -- quantas compras recentes ficam guardadas

type Handler = (Player) -> boolean

local Receipts = {}

local handlers: { [number]: { handler: Handler, sku: string } } = {}

-- `handler` entrega o produto e devolve true se deu certo. Produtos com id 0 (ainda não criados) são ignorados.
function Receipts.register(productId: number, sku: string, handler: Handler)
	if productId ~= 0 then
		handlers[productId] = { handler = handler, sku = sku }
	end
end

local function process(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and Data.get(player)
	if player == nil or data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if table.find(data.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- já entregue antes
	end
	local entry = handlers[info.ProductId]
	if entry == nil then
		warn(`[Receipts] produto sem dono: {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(entry.handler, player)
	if not ok then
		warn(`[Receipts] {granted}`)
	end
	if not ok or granted ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_SAVED do
		table.remove(data.Receipts, 1)
	end
	Analytics.event(player, `Robux_{entry.sku}`, info.CurrencySpent)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Receipts.start()
	MarketplaceService.ProcessReceipt = process
end

return Receipts
