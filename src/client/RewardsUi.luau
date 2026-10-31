--!strict
-- Janela de presentes: recompensa diária, presentes por tempo jogado e códigos (docs/V2.md, seção 5).
-- O servidor confere tudo (server/Rewards.luau); aqui só mostra e pede.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local RewardsUi = {}

local window: Ui.Window

function RewardsUi.toggle()
	window.toggle()
end

-- Tem alguma coisa para pegar agora? (o menu mostra um "!" no botão)
function RewardsUi.hasSomething(): boolean
	if player:GetAttribute("DailyAvailable") == true then
		return true
	end
	local claimed = Ui.number("GiftsClaimed")
	local minutes = Config.Gifts.MINUTES[claimed + 1]
	local started = Ui.number("SessionStart")
	return minutes ~= nil and started > 0 and workspace:GetServerTimeNow() - started >= minutes * 60
end

local function format(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function RewardsUi.start()
	window = Ui.window("Rewards", "REWARDS")

	-- Recompensa diária.
	local daily = Ui.row(window, 1, 70)
	local dailyTitle = Ui.text(daily, "Daily Reward", UDim2.fromScale(0.6, 0.5), UDim2.fromScale(0.03, 0.05))
	local dailyInfo = Ui.text(daily, "", UDim2.fromScale(0.6, 0.36), UDim2.fromScale(0.03, 0.58))
	dailyInfo.TextColor3 = Ui.MUTED
	local dailyButton = Ui.button(daily, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15))
	dailyButton.Activated:Connect(function()
		Remotes.get("ClaimDaily"):FireServer()
	end)
	local function refreshDaily()
		local streak = Ui.number("DailyStreak")
		local available = player:GetAttribute("DailyAvailable") == true
		dailyTitle.Text = `Daily Reward · Day {math.max(streak, 1)}/7`
		dailyInfo.Text = "Come back every day! Day 7 also gives 2x income."
		dailyButton.Text = if available then "CLAIM" else "Tomorrow"
		dailyButton.BackgroundColor3 = if available then Ui.GREEN else Ui.DISABLED
	end
	player:GetAttributeChangedSignal("DailyAvailable"):Connect(refreshDaily)
	player:GetAttributeChangedSignal("DailyStreak"):Connect(refreshDaily)
	refreshDaily()

	-- Presentes por tempo jogado.
	local gifts: { { button: TextButton, minutes: number, index: number } } = {}
	for index, minutes in Config.Gifts.MINUTES do
		local row = Ui.row(window, 1 + index, 56)
		local kind = if index % 2 == 1 then "Cash gift" else `2x income for {Config.Gifts.BOOST_MINUTES} min`
		Ui.text(row, `Gift #{index}: {kind}`, UDim2.fromScale(0.6, 0.5), UDim2.fromScale(0.03, 0.08))
		Ui.text(row, `After {minutes} min of play`, UDim2.fromScale(0.6, 0.34), UDim2.fromScale(0.03, 0.6)).TextColor3 =
			Ui.MUTED
		local button = Ui.button(row, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15))
		button.Activated:Connect(function()
			Remotes.get("ClaimGift"):FireServer()
		end)
		table.insert(gifts, { button = button, minutes = minutes, index = index })
	end

	-- Códigos.
	local codeRow = Ui.row(window, 20, 56)
	local box = Instance.new("TextBox")
	box.PlaceholderText = "Enter a code"
	box.Text = ""
	box.Font = Enum.Font.FredokaOne
	box.TextScaled = true
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderColor3 = Ui.MUTED
	box.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	box.ClearTextOnFocus = false
	box.Size = UDim2.fromScale(0.6, 0.7)
	box.Position = UDim2.fromScale(0.03, 0.15)
	box.Parent = codeRow
	Ui.round(box, 0.2)
	local redeem = Ui.button(codeRow, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.67, 0.15), Ui.BLUE)
	redeem.Text = "REDEEM"
	redeem.Activated:Connect(function()
		if box.Text ~= "" then
			Remotes.get("RedeemCode"):FireServer(box.Text)
			box.Text = ""
		end
	end)

	-- Atualiza os botões dos presentes com o tempo que falta.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 or not window.isOpen() then
			return
		end
		elapsed = 0
		local claimed = Ui.number("GiftsClaimed")
		local started = Ui.number("SessionStart")
		local played = workspace:GetServerTimeNow() - started
		for _, gift in gifts do
			if gift.index <= claimed then
				gift.button.Text = "CLAIMED"
				gift.button.BackgroundColor3 = Ui.DISABLED
			elseif gift.index == claimed + 1 and played >= gift.minutes * 60 then
				gift.button.Text = "CLAIM"
				gift.button.BackgroundColor3 = Ui.GREEN
			else
				gift.button.Text = format(gift.minutes * 60 - played)
				gift.button.BackgroundColor3 = Ui.DISABLED
			end
		end
	end)
end

return RewardsUi
