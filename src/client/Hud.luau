--!strict
-- HUD: o saldo grande no topo da tela, o que está no cofre com a renda por segundo, a fase do dia com o tempo restante e o "+$" que sobe ao coletar o
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
local SAFE_COLOR = Color3.fromRGB(200, 230, 200)
local GOLD = Color3.fromRGB(255, 205, 80)
local BOOST_COLOR = Color3.fromRGB(120, 220, 255)
local RED_MOON_COLOR = Color3.fromRGB(255, 70, 70)

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

	-- Embaixo do saldo: quanto está no cofre (ainda não é seu, pode ser perdido) e a renda das celas.
	local safeLabel = makeLabel("Safe", gui)
	safeLabel.AnchorPoint = Vector2.new(0.5, 0)
	safeLabel.Size = UDim2.fromScale(0.3, 0.035)
	safeLabel.Position = UDim2.fromScale(0.5, 0.1)
	safeLabel.TextColor3 = SAFE_COLOR

	local function updateSafe()
		local safe = player:GetAttribute("SafeBalance")
		local income = player:GetAttribute("IncomePerSecond")
		local safeText = NumberFormat.cash(if typeof(safe) == "number" then safe else 0)
		local incomeText = NumberFormat.cash(if typeof(income) == "number" then income else 0)
		safeLabel.Text = `In safe: {safeText} · +{incomeText}/s`
	end
	player:GetAttributeChangedSignal("SafeBalance"):Connect(updateSafe)
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(updateSafe)
	updateSafe()

	-- Fase do dia e tempo restante.
	local phaseLabel = makeLabel("Phase", gui)
	phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseLabel.Size = UDim2.fromScale(0.25, 0.045)
	phaseLabel.Position = UDim2.fromScale(0.5, 0.14)

	-- Evento aleatório em andamento (server/RandomEvents.luau), logo abaixo da fase do dia.
	local eventLabel = makeLabel("Event", gui)
	eventLabel.AnchorPoint = Vector2.new(0.5, 0)
	eventLabel.Size = UDim2.fromScale(0.3, 0.035)
	eventLabel.Position = UDim2.fromScale(0.5, 0.19)
	eventLabel.TextColor3 = Color3.fromRGB(255, 210, 60)

	-- Canto superior direito: multiplicador total, estrela da Franquia e tempo do boost 2x.
	local bonusLabel = makeLabel("Bonus", gui)
	bonusLabel.AnchorPoint = Vector2.new(1, 0)
	bonusLabel.Size = UDim2.fromScale(0.22, 0.04)
	bonusLabel.Position = UDim2.fromScale(0.98, 0.02)
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Right
	bonusLabel.TextColor3 = GOLD

	local boostLabel = makeLabel("Boost", gui)
	boostLabel.AnchorPoint = Vector2.new(1, 0)
	boostLabel.Size = UDim2.fromScale(0.22, 0.032)
	boostLabel.Position = UDim2.fromScale(0.98, 0.065)
	boostLabel.TextXAlignment = Enum.TextXAlignment.Right
	boostLabel.TextColor3 = BOOST_COLOR

	local function updateBonus()
		local multiplier = player:GetAttribute("IncomeMultiplier")
		local franchise = player:GetAttribute("Franchise")
		local parts = {}
		if typeof(franchise) == "number" and franchise > 0 then
			table.insert(parts, `★{franchise}`)
		end
		if typeof(multiplier) == "number" and multiplier > 1.001 then
			table.insert(parts, string.format("x%.2f income", multiplier))
		end
		bonusLabel.Text = table.concat(parts, "  ")
	end
	player:GetAttributeChangedSignal("IncomeMultiplier"):Connect(updateBonus)
	player:GetAttributeChangedSignal("Franchise"):Connect(updateBonus)
	updateBonus()

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local boostEndsAt = player:GetAttribute("BoostEndsAt")
		if typeof(boostEndsAt) == "number" and boostEndsAt > now then
			local left = math.ceil(boostEndsAt - now)
			boostLabel.Text = string.format("2x BOOST %d:%02d", left // 60, left % 60)
		else
			boostLabel.Text = ""
		end

		local eventName = ReplicatedStorage:GetAttribute("EventName")
		local eventEndsAt = ReplicatedStorage:GetAttribute("EventEndsAt")
		if typeof(eventName) == "string" and typeof(eventEndsAt) == "number" and eventEndsAt > now then
			eventLabel.Text = `★ {eventName} · {math.ceil(eventEndsAt - now)}s`
		else
			eventLabel.Text = ""
		end

		local phase = ReplicatedStorage:GetAttribute("Phase")
		local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		if typeof(phase) ~= "string" or typeof(endsAt) ~= "number" then
			phaseLabel.Text = ""
			return
		end
		local remaining = math.max(0, math.ceil(endsAt - now))
		local clock = string.format("%d:%02d", remaining // 60, remaining % 60)
		local isNight = phase == "Night"
		local redMoon = isNight and ReplicatedStorage:GetAttribute("RedMoon") == true
		local title = if redMoon then "RED MOON" elseif isNight then "NIGHT SHIFT" else "DAY"
		phaseLabel.Text = `{title} · {clock}`
		phaseLabel.TextColor3 = if redMoon then RED_MOON_COLOR elseif isNight then NIGHT_COLOR else DAY_COLOR
	end)

	-- Avisos do servidor (anomalia capturada, cofre roubado...), um embaixo do outro.
	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.BackgroundTransparency = 1
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Size = UDim2.fromScale(0.6, 0.3)
	toasts.Position = UDim2.fromScale(0.5, 0.235)
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
