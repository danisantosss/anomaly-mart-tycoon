--!strict
-- Index: a coleção de anomalias (docs/V2.md, seção 5). Uma linha por tipo, uma casinha por variante. As já
-- capturadas aparecem com o nome e a cor da raridade; as que faltam aparecem como "???".
-- Cada casinha encontrada dá +2% de renda para sempre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anomalies = require(ReplicatedStorage.Shared.Anomalies)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local IndexUi = {}

local window: Ui.Window

function IndexUi.toggle()
	window.toggle()
end

function IndexUi.start()
	window = Ui.window("Index", "ANOMALY INDEX")

	local header = Ui.row(window, 0, 44)
	header.BackgroundTransparency = 1
	local summary =
		Ui.text(header, "", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), Enum.TextXAlignment.Center)
	summary.TextColor3 = Color3.fromRGB(255, 220, 120)

	local cells: { () -> () } = {}

	for order, definition in Anomalies.LIST do
		local row = Ui.row(window, order, 78)
		local name =
			Ui.text(row, definition.displayName, UDim2.fromScale(0.24, 0.4), UDim2.fromScale(0.02, 0.1))
		name.TextColor3 = Anomalies.RARITY_COLORS[definition.rarity]
		local rarity =
			Ui.text(row, definition.rarity, UDim2.fromScale(0.24, 0.3), UDim2.fromScale(0.02, 0.55))
		rarity.TextColor3 = Ui.MUTED

		for column, variant in Anomalies.VARIANTS do
			local slot = Instance.new("Frame")
			slot.Size = UDim2.fromScale(0.14, 0.8)
			slot.Position = UDim2.fromScale(0.27 + (column - 1) * 0.146, 0.1)
			slot.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
			slot.Parent = row
			Ui.round(slot, 0.15)
			local label = Ui.text(
				slot,
				"",
				UDim2.fromScale(0.92, 0.9),
				UDim2.fromScale(0.04, 0.05),
				Enum.TextXAlignment.Center
			)

			local attribute = Anomalies.indexAttribute(definition.id, variant.id)
			local function refresh()
				local found = player:GetAttribute(attribute) == true
				local variantName = if variant.displayName == "" then "Normal" else variant.displayName
				if found then
					label.Text = `{variantName}\n×{variant.multiplier}`
					label.TextColor3 = Color3.new(1, 1, 1)
					slot.BackgroundColor3 =
						Anomalies.RARITY_COLORS[definition.rarity]:Lerp(Color3.new(0, 0, 0), 0.45)
				else
					label.Text = `???\n{variantName}`
					label.TextColor3 = Color3.fromRGB(110, 115, 125)
					slot.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
				end
			end
			player:GetAttributeChangedSignal(attribute):Connect(function()
				refresh()
				for _, update in cells do
					update()
				end
			end)
			refresh()
		end
	end

	local function updateSummary()
		local found = 0
		for _, definition in Anomalies.LIST do
			for _, variant in Anomalies.VARIANTS do
				if player:GetAttribute(Anomalies.indexAttribute(definition.id, variant.id)) == true then
					found += 1
				end
			end
		end
		local bonus = math.floor(found * Config.Bonuses.INDEX_PER_ENTRY * 100 + 0.5)
		summary.Text = `Found {found}/{Anomalies.INDEX_SIZE} · +{bonus}% income forever`
	end
	table.insert(cells, updateSummary)
	updateSummary()
end

return IndexUi
