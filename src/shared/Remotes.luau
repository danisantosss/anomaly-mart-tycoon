--!strict
-- Lista única dos eventos de rede entre servidor e cliente. O servidor cria, o cliente espera existir.
-- Para adicionar um evento novo: coloque o nome em NAMES e use Remotes.get("Nome").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"CashCollected", -- servidor → cliente (amount: number): mostra o "+$" na tela
	"Notify", -- servidor → cliente (text: string, color: Color3?): aviso rápido no meio da tela
	"BuyUpgrade", -- cliente → servidor (id: string): pedido de compra; o servidor confere tudo
	"ClaimDaily", -- cliente → servidor: pegar a recompensa diária
	"ClaimGift", -- cliente → servidor: pegar o próximo presente de tempo jogado
	"RedeemCode", -- cliente → servidor (code: string)
	"OpenFranchise", -- cliente → servidor: abrir uma Franquia (rebirth)
}

local FOLDER_NAME = "Remotes"

local Remotes = {}

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = created
		end
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.get(name: string): RemoteEvent
	assert(table.find(NAMES, name), `remote desconhecido: {name}`)
	return folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
