--!strict
-- HUD: o saldo grande no topo da tela, a fase do dia com o tempo restante e o "+$" que sobe ao coletar o
-- cofre.
-- O valor vem do atributo "Cash" que o servidor coloca no jogador; o cliente só mostra.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}

local CASH_GREEN = Color3.fromRGB(120, 255, 140)
local DAY_COLOR = Color3.fromRGB(255, 220, 120)
local NIGHT_COLOR = Color3.fromRGB(150, 170, 255)

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

	-- Fase do dia e tempo restante, logo abaixo do dinheiro.
	local phaseLabel = makeLabel("Phase", gui)
	phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseLabel.Size = UDim2.fromScale(0.25, 0.045)
	phaseLabel.Position = UDim2.fromScale(0.5, 0.1)

	RunService.Heartbeat:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		if typeof(phase) ~= "string" or typeof(endsAt) ~= "number" then
			phaseLabel.Text = ""
			return
		end
		local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		local clock = string.format("%d:%02d", remaining // 60, remaining % 60)
		local isNight = phase == "Night"
		phaseLabel.Text = `{if isNight then "NIGHT SHIFT" else "DAY"} · {clock}`
		phaseLabel.TextColor3 = if isNight then NIGHT_COLOR else DAY_COLOR
	end)

	-- Avisos do servidor (anomalia capturada, cofre roubado...), um embaixo do outro.
	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.BackgroundTransparency = 1
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Size = UDim2.fromScale(0.6, 0.3)
	toasts.Position = UDim2.fromScale(0.5, 0.18)
	toasts.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = toasts

	Remotes.get("Notify").OnClientEvent:Connect(function(text: string, color: Color3?)
		local label = makeLabel("Toast", toasts)
		label.Size = UDim2.fromScale(1, 0.2)
		label.TextColor3 = color or Color3.new(1, 1, 1)
		label.Text = text
		task.delay(3.5, function()
			local fade = TweenService:Create(
				label,
				TweenInfo.new(0.5),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			fade.Completed:Connect(function()
				label:Destroy()
			end)
			fade:Play()
		end)
	end)

	Remotes.get("CashCollected").OnClientEvent:Connect(function(amount: number)
		popCollected(gui, amount)
	end)
end

return Hud
