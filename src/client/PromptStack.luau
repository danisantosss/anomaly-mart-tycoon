--!strict
-- Empilha os botões de ação (ProximityPrompt) que ficariam um em cima do outro.
--
-- O Roblox desenha cada botão no ponto do objeto dele e não afasta botões vizinhos: no caixa, Charge e
-- Refuse ficam na mesma peça e o Capture fica no cliente logo atrás, então os três se sobrepunham e só um
-- dava para ler. Aqui, os botões visíveis que estão perto um do outro no mundo viram uma coluna, um embaixo
-- do outro, usando UIOffset (só no cliente; o servidor não usa UIOffset).

local ProximityPromptService = game:GetService("ProximityPromptService")

local PromptStack = {}

-- Botões a menos de GROUP_DISTANCE studs um do outro entram na mesma coluna.
local GROUP_DISTANCE = 6
-- Distância em pixels entre um botão e o próximo da coluna (o botão padrão tem uns 72 px de altura).
local ROW_PIXELS = 78
-- Os clientes andam, então a coluna é refeita algumas vezes por segundo enquanto houver 2+ botões.
local REFRESH_SECONDS = 0.25

type Entry = { prompt: ProximityPrompt, position: Vector3 }

local shown: { ProximityPrompt } = {}

local function worldPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

local function layout()
	-- Ordem fixa (mais alto primeiro, depois pela tecla) para os botões não trocarem de lugar.
	local entries: { Entry } = {}
	for _, prompt in shown do
		local position = worldPosition(prompt)
		if position then
			table.insert(entries, { prompt = prompt, position = position })
		else
			prompt.UIOffset = Vector2.zero
		end
	end
	table.sort(entries, function(a, b)
		if math.abs(a.position.Y - b.position.Y) > 0.5 then
			return a.position.Y > b.position.Y
		end
		return a.prompt.KeyboardKeyCode.Value < b.prompt.KeyboardKeyCode.Value
	end)

	-- Junta em grupos: cada botão entra no primeiro grupo que tiver alguém perto dele.
	local groups: { { Entry } } = {}
	for _, entry in entries do
		local home: { Entry }? = nil
		for _, group in groups do
			for _, other in group do
				if (other.position - entry.position).Magnitude < GROUP_DISTANCE then
					home = group
					break
				end
			end
			if home then
				break
			end
		end
		if home then
			table.insert(home, entry)
		else
			table.insert(groups, { entry })
		end
	end

	-- Cada grupo vira uma coluna centrada no ponto do grupo.
	for _, group in groups do
		local count = #group
		for index, entry in group do
			entry.prompt.UIOffset = Vector2.new(0, (index - (count + 1) / 2) * ROW_PIXELS)
		end
	end
end

function PromptStack.start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if not table.find(shown, prompt) then
			table.insert(shown, prompt)
		end
		layout()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local index = table.find(shown, prompt)
		if index then
			table.remove(shown, index)
		end
		prompt.UIOffset = Vector2.zero
		layout()
	end)
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			-- Botões destruídos (cliente saiu, anomalia capturada) não avisam que sumiram.
			for index = #shown, 1, -1 do
				if shown[index].Parent == nil then
					table.remove(shown, index)
				end
			end
			if #shown >= 2 then
				layout()
			end
		end
	end)
end

return PromptStack
