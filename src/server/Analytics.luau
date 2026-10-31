--!strict
-- Telemetria com o AnalyticsService do Roblox (aparece em Creator Hub → Analytics). Serve para descobrir
-- em que ponto os jogadores novos desistem e para onde vai o dinheiro do jogo (docs/V2.md, seção 9).
--
--   Onboarding  funil de primeira vez, cada passo registrado uma vez na vida do jogador (salvo nos dados)
--   Economy     entradas (cofre coletado, presentes, códigos) e gastos (partes, upgrades, Franquia)
--   Custom      eventos soltos (Franquia aberta, Lua Vermelha vista)
--
-- Tudo dentro de pcall: telemetria nunca pode quebrar o jogo. No Studio o Roblox ignora os eventos.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Data = require(script.Parent.Data)
local DayNight = require(script.Parent.DayNight)
local Plots = require(script.Parent.Plots)

local Analytics = {}

-- Ordem do funil. O número do passo é a posição na lista; não reordenar depois do lançamento (estraga os
-- gráficos), só acrescentar no fim.
Analytics.STEPS = {
	"Joined",
	"FirstSale",
	"FirstRestock",
	"FirstCollect",
	"FirstBuild",
	"SawAnomaly",
	"FirstCapture",
	"FirstUpgrade",
	"FirstNight",
}

local stepNumber: { [string]: number } = {}
for index, name in Analytics.STEPS do
	stepNumber[name] = index
end

local function try(callback: () -> ())
	local ok, problem = pcall(callback)
	if not ok then
		warn(`[Analytics] {problem}`)
	end
end

-- Registra um passo do funil se o jogador ainda não passou por ele.
function Analytics.step(player: Player, name: string)
	local number = stepNumber[name]
	local data = Data.get(player)
	if number == nil or data == nil or data.Onboarding[name] then
		return
	end
	data.Onboarding[name] = true
	try(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, number, name)
	end)
end

local function balance(player: Player): number
	local cash = player:GetAttribute("Cash")
	return if typeof(cash) == "number" then cash else 0
end

-- Dinheiro que entrou no saldo. `kind`: "Gameplay", "TimedReward", "Code"... (tipo da transação)
function Analytics.earn(player: Player, amount: number, kind: string, sku: string?)
	if amount <= 0 then
		return
	end
	try(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Cash",
			math.floor(amount),
			math.floor(balance(player)),
			kind,
			sku
		)
	end)
end

-- Dinheiro gasto. Chamar depois de descontar, para o saldo final sair certo.
function Analytics.spend(player: Player, amount: number, kind: string, sku: string?)
	if amount <= 0 then
		return
	end
	try(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Cash",
			math.floor(amount),
			math.floor(balance(player)),
			kind,
			sku
		)
	end)
end

function Analytics.event(player: Player, name: string, value: number?)
	try(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

-- Passos que não pertencem a nenhum sistema: entrar com a loja pronta e ver a primeira madrugada.
function Analytics.start()
	Plots.onStoreReady(function(player)
		if Data.waitFor(player) then
			Analytics.step(player, "Joined")
		end
	end)
	DayNight.onPhaseChanged(function(phase)
		if phase ~= "Night" then
			return
		end
		for _, player in Players:GetPlayers() do
			Analytics.step(player, "FirstNight")
			if DayNight.isRedMoon() then
				Analytics.event(player, "RedMoonSeen")
			end
		end
	end)
end

return Analytics
