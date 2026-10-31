--!strict
-- Pinta os botões de compra do chão da própria loja: verde quando dá para comprar, vermelho quando falta
-- dinheiro. Só muda a cor neste computador; quem confere o dinheiro de verdade é o servidor (Builds.luau).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local PadColors = {}

local AFFORDABLE = Color3.fromRGB(60, 230, 120)
local TOO_EXPENSIVE = Color3.fromRGB(230, 70, 70)
local PRICE_OK = Color3.fromRGB(120, 255, 140)
local PRICE_MISSING = Color3.fromRGB(255, 110, 110)

local pads: { BasePart } = {}

local function cash(): number
	local value = player:GetAttribute("Cash")
	return if typeof(value) == "number" then value else 0
end

local function paint(pad: BasePart)
	local cost = pad:GetAttribute("Cost")
	if typeof(cost) ~= "number" then
		return
	end
	local affordable = cash() >= cost
	pad.Color = if affordable then AFFORDABLE else TOO_EXPENSIVE
	local billboard = pad:FindFirstChild("PadBillboard")
	local price = billboard and billboard:FindFirstChild("Price")
	if price and price:IsA("TextLabel") then
		price.TextColor3 = if affordable then PRICE_OK else PRICE_MISSING
	end
end

local function track(instance: Instance)
	if
		instance:IsA("BasePart")
		and instance:GetAttribute("OwnerUserId") == player.UserId
		and instance:GetAttribute("Cost")
	then
		table.insert(pads, instance)
		paint(instance)
	end
end

function PadColors.start()
	workspace.DescendantAdded:Connect(track)
	for _, descendant in workspace:GetDescendants() do
		track(descendant)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		for index = #pads, 1, -1 do
			local pad = pads[index]
			if pad.Parent == nil then
				table.remove(pads, index)
			else
				paint(pad)
			end
		end
	end)
	-- Os botões que dá para comprar "respiram" para chamar atenção.
	RunService.RenderStepped:Connect(function()
		local glow = 0.15 + 0.15 * math.sin(os.clock() * 4)
		for _, pad in pads do
			if pad.Parent and pad.Color == AFFORDABLE then
				pad.Transparency = glow
			end
		end
	end)
end

return PadColors
