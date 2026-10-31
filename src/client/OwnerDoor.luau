--!strict
-- Deixa o dono atravessar a própria porta de aço trancada (docs/V1.md, seção 6).
--
-- O servidor liga a colisão da porta para todo mundo. Aqui, só no computador do dono, a colisão fica sempre
-- desligada. Funciona porque o Roblox calcula a física do personagem no computador de quem joga.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local OwnerDoor = {}

local function apply(instance: Instance)
	if not instance:IsA("BasePart") or instance.Name ~= "BackDoor" then
		return
	end
	local door = instance
	local function keepOpen()
		if door:GetAttribute("OwnerUserId") == player.UserId and door.CanCollide then
			door.CanCollide = false
		end
	end
	door:GetPropertyChangedSignal("CanCollide"):Connect(keepOpen)
	door:GetAttributeChangedSignal("OwnerUserId"):Connect(keepOpen)
	keepOpen()
end

function OwnerDoor.start()
	workspace.DescendantAdded:Connect(apply)
	for _, descendant in workspace:GetDescendants() do
		apply(descendant)
	end
end

return OwnerDoor
