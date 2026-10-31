--!strict
-- HUD do dinheiro: o saldo grande no topo da tela e o "+$" que sobe ao coletar o cofre.
-- O valor vem do atributo "Cash" que o servidor coloca no jogador; o cliente só mostra.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}

local CASH_GREEN = Color3.fromRGB(120, 255, 140)

local function makeLabel(name: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = CASH_GREEN
	label.TextStrokeTransparency = 0.2
	label.Parent = parent
	return label
end

local function popCollected(gui: ScreenGui, amount: number)
	local label = makeLabel("CollectedPopup", gui)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromScale(0.3, 0.08)
	label.Position = UDim2.fromScale(0.5, 0.55)
	label.Text = "+" .. NumberFormat.cash(amount)

	local tween =
		TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.35),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
	tween.Completed:Connect(function()
		label:Destroy()
	end)
	tween:Play()
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local cashLabel = makeLabel("Cash", gui)
	cashLabel.AnchorPoint = Vector2.new(0.5, 0)
	cashLabel.Size = UDim2.fromScale(0.35, 0.08)
	cashLabel.Position = UDim2.fromScale(0.5, 0.02)

	local function updateCash()
		local cash = player:GetAttribute("Cash")
		cashLabel.Text = NumberFormat.cash(if typeof(cash) == "number" then cash else 0)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	updateCash()

	Remotes.get("CashCollected").OnClientEvent:Connect(function(amount: number)
		popCollected(gui, amount)
	end)
end

return Hud
