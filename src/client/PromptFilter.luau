--!strict
-- Esconde os botões (ProximityPrompt) que não são para este jogador.
-- Um botão marcado com o atributo "OwnerUserId" só aparece para o dono da loja. Quem decide de verdade se a
-- ação vale é sempre o servidor; isto aqui só evita mostrar botões que não fariam nada.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptFilter = {}

local function apply(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	if owner ~= nil and owner ~= player.UserId then
		instance.Enabled = false
	end
end

function PromptFilter.start()
	workspace.DescendantAdded:Connect(apply)
	for _, descendant in workspace:GetDescendants() do
		apply(descendant)
	end
end

return PromptFilter
