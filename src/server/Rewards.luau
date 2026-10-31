--!strict
-- Recompensas que fazem o jogador voltar (docs/V2.md, seção 5): diária com sequência, presentes por tempo
-- jogado, códigos e boosts temporários de 2x.
--
-- O cliente só pede ("ClaimDaily", "ClaimGift", "RedeemCode"); o servidor confere e entrega. O estado que a
-- tela precisa vai em atributos do jogador:
--   DailyAvailable, DailyStreak     recompensa diária
--   SessionStart, GiftsClaimed      presentes (SessionStart = workspace:GetServerTimeNow() da entrada)
--   BoostEndsAt                     fim do boost de 2x (lido pelo Economy.incomeMultiplier)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Cells = require(script.Parent.Cells)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)

local GOOD = Color3.fromRGB(120, 255, 140)
local INFO = Color3.fromRGB(255, 230, 140)
local BAD = Color3.fromRGB(255, 100, 100)

local Rewards = {}

local notify: RemoteEvent
local giftsClaimed: { [Player]: number } = {}
local sessionStart: { [Player]: number } = {}

local function today(): number
	return os.time() // 86400
end

-- Dá um boost de 2x por `minutes` minutos (soma com o que ainda falta do boost atual).
function Rewards.boost(player: Player, minutes: number)
	local now = workspace:GetServerTimeNow()
	local current = player:GetAttribute("BoostEndsAt")
	local from = if typeof(current) == "number" and current > now then current else now
	player:SetAttribute("BoostEndsAt", from + minutes * 60)
	Economy.publishMultiplier(player)
end

local function publishDaily(player: Player)
	local data = Data.get(player)
	if data == nil then
		return
	end
	local available = data.DailyLastDay ~= today()
	player:SetAttribute("DailyAvailable", available)
	-- Mostra o dia que ele vai receber agora (ou o que já recebeu hoje).
	local streak = data.DailyStreak
	if available then
		streak = if data.DailyLastDay == today() - 1 then streak % #Config.Daily.REWARDS + 1 else 1
	end
	player:SetAttribute("DailyStreak", streak)
end

local function claimDaily(player: Player)
	local data = Data.get(player)
	if data == nil or data.DailyLastDay == today() then
		return
	end
	local continued = data.DailyLastDay == today() - 1
	data.DailyStreak = if continued then data.DailyStreak % #Config.Daily.REWARDS + 1 else 1
	data.DailyLastDay = today()

	local amount = Config.Daily.REWARDS[data.DailyStreak] * (1 + data.Franchise)
	Economy.addCash(player, amount)
	Analytics.earn(player, amount, "TimedReward", `Daily_{data.DailyStreak}`)
	local text = `Day {data.DailyStreak} reward: {NumberFormat.cash(amount)}!`
	if data.DailyStreak == #Config.Daily.REWARDS then
		Rewards.boost(player, Config.Daily.DAY7_BOOST_MINUTES)
		text ..= ` Plus 2x income for {Config.Daily.DAY7_BOOST_MINUTES} min!`
	end
	notify:FireClient(player, text, GOOD)
	publishDaily(player)
end

local function claimGift(player: Player)
	local claimed = giftsClaimed[player] or 0
	local minutes = Config.Gifts.MINUTES[claimed + 1]
	local started = sessionStart[player]
	if minutes == nil or started == nil then
		return
	end
	if workspace:GetServerTimeNow() - started < minutes * 60 then
		notify:FireClient(player, "That gift isn't ready yet!", INFO)
		return
	end
	giftsClaimed[player] = claimed + 1
	player:SetAttribute("GiftsClaimed", claimed + 1)

	-- Presentes ímpares (1º, 3º...) dão dinheiro; pares dão boost.
	if claimed % 2 == 0 then
		local perSecond = Cells.totalIncome(player) + Cells.passiveIncome(player)
		local amount =
			math.max(Config.Gifts.CASH_MIN, math.floor(perSecond * Config.Gifts.CASH_SECONDS_OF_INCOME))
		Economy.addCash(player, amount)
		Analytics.earn(player, amount, "TimedReward", `Gift_{claimed + 1}`)
		notify:FireClient(player, `Gift: {NumberFormat.cash(amount)}!`, GOOD)
	else
		Rewards.boost(player, Config.Gifts.BOOST_MINUTES)
		notify:FireClient(player, `Gift: 2x income for {Config.Gifts.BOOST_MINUTES} minutes!`, GOOD)
	end
end

local function redeemCode(player: Player, raw: unknown)
	local data = Data.get(player)
	if data == nil or typeof(raw) ~= "string" or #raw > 30 then
		return
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	local reward = (Config.Codes :: any)[code]
	if reward == nil then
		notify:FireClient(player, "That code doesn't exist.", BAD)
		return
	end
	if data.Codes[code] then
		notify:FireClient(player, "You already used that code.", INFO)
		return
	end
	data.Codes[code] = true
	if reward.cash then
		local amount = reward.cash * (1 + data.Franchise)
		Economy.addCash(player, amount)
		Analytics.earn(player, amount, "Code", code)
		notify:FireClient(player, `Code redeemed: {NumberFormat.cash(amount)}!`, GOOD)
	end
	if reward.boostMinutes then
		Rewards.boost(player, reward.boostMinutes)
		notify:FireClient(player, `Code redeemed: 2x income for {reward.boostMinutes} minutes!`, GOOD)
	end
end

local function onPlayerAdded(player: Player)
	local now = workspace:GetServerTimeNow()
	sessionStart[player] = now
	giftsClaimed[player] = 0
	player:SetAttribute("SessionStart", now)
	player:SetAttribute("GiftsClaimed", 0)
	if Data.waitFor(player) then
		publishDaily(player)
	end
end

function Rewards.start()
	notify = Remotes.get("Notify")
	Remotes.get("ClaimDaily").OnServerEvent:Connect(claimDaily)
	Remotes.get("ClaimGift").OnServerEvent:Connect(claimGift)
	Remotes.get("RedeemCode").OnServerEvent:Connect(redeemCode)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		giftsClaimed[player] = nil
		sessionStart[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- Virou o dia com o jogador online: a diária volta a ficar disponível.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				publishDaily(player)
			end
		end
	end)
end

return Rewards
