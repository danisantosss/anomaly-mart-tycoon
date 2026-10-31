--!strict
-- Esconde os botões (ProximityPrompt) que não são para este jogador:
--   atributo "OwnerUserId"    o botão só aparece para esse jogador (ex.: Charge na própria loja)
--   atributo "ExcludeUserId"  o botão aparece para todos menos esse jogador (ex.: Steal na cela de outro)
-- Quem decide de verdade se a ação vale é sempre o servidor; isto aqui só evita mostrar botões que não
-- fariam nada.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptFilter = {}

local function apply(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	local excluded = instance:GetAttribute("ExcludeUserId")
	if (owner ~= nil and owner ~= player.UserId) or excluded == player.UserId then
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
