--!strict
-- Peças de interface reutilizadas pelas janelas (loja, Index, presentes, Franquia). Tudo em escala (Scale),
-- com tamanho mínimo, para funcionar no PC e no celular. Só uma janela fica aberta por vez.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Ui = {}

Ui.PANEL = Color3.fromRGB(28, 32, 40)
Ui.ROW = Color3.fromRGB(42, 48, 60)
Ui.GREEN = Color3.fromRGB(46, 160, 120)
Ui.DISABLED = Color3.fromRGB(80, 84, 92)
Ui.BLUE = Color3.fromRGB(0, 120, 215)
Ui.GOLD = Color3.fromRGB(230, 170, 40)
Ui.MUTED = Color3.fromRGB(190, 195, 205)

function Ui.text(
	parent: Instance,
	value: string,
	size: UDim2,
	position: UDim2,
	align: Enum.TextXAlignment?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.Size = size
	label.Position = position
	label.Text = value
	label.Parent = parent
	return label
end

function Ui.button(parent: Instance, size: UDim2, position: UDim2, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or Ui.GREEN
	button.Size = size
	button.Position = position
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = button
	button.Parent = parent
	return button
end

function Ui.round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = instance
end

export type Window = {
	gui: ScreenGui,
	panel: Frame,
	body: ScrollingFrame,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
}

local windows: { Window } = {}

-- Janela com título, botão de fechar e uma lista com rolagem (`body`) para as linhas.
function Ui.window(name: string, title: string): Window
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromScale(0.5, 0.72)
	panel.BackgroundColor3 = Ui.PANEL
	panel.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(300, 240)
	constraint.MaxSize = Vector2.new(720, 620)
	constraint.Parent = panel
	Ui.round(panel, 0.03)

	Ui.text(panel, title, UDim2.fromScale(0.75, 0.09), UDim2.fromScale(0.04, 0.02))
	local close =
		Ui.button(panel, UDim2.fromScale(0.1, 0.09), UDim2.fromScale(0.87, 0.02), Color3.fromRGB(200, 60, 60))
	close.Text = "X"

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.03, 0.13)
	body.Size = UDim2.fromScale(0.94, 0.84)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	local window: Window
	window = {
		gui = gui,
		panel = panel,
		body = body,
		open = function()
			for _, other in windows do
				if other ~= window then
					other.gui.Enabled = false
				end
			end
			gui.Enabled = true
		end,
		close = function()
			gui.Enabled = false
		end,
		toggle = function()
			if gui.Enabled then
				window.close()
			else
				window.open()
			end
		end,
		isOpen = function()
			return gui.Enabled
		end,
	}
	close.Activated:Connect(window.close)
	table.insert(windows, window)
	return window
end

-- Linha da lista de uma janela (altura fixa em pixels, largura da janela).
function Ui.row(window: Window, order: number, height: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Ui.ROW
	frame.Size = UDim2.new(1, -8, 0, height or 64)
	frame.LayoutOrder = order
	frame.Parent = window.body
	Ui.round(frame, 0.15)
	return frame
end

function Ui.number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

return Ui
