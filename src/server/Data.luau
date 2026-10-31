--!strict
-- Salvamento dos dados do jogador com o ProfileStore (vendor/ProfileStore.luau).
--
-- O ProfileStore cuida de salvar sozinho a cada poucos minutos, ao sair e quando o servidor fecha, e impede
-- que dois servidores mexam no mesmo jogador ao mesmo tempo. No Studio sem "API Services" ligado ele usa
-- um banco de mentira (nada é salvo de verdade), então para testar o salvamento é preciso ligar
-- Game Settings → Security → Enable Studio Access to API Services.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)

export type CellData = {
	Kind: string, -- id da anomalia (ex.: "LongNeck")
	Variant: string, -- "Normal", "Shiny", "Inverted", "Giant" ou "Glitch"
}

export type PlayerData = {
	Cash: number,
	SafeBalance: number, -- dinheiro no cofre, ainda não coletado
	LastLogout: number, -- os.time() da última saída, para o ganho offline
	Upgrades: { [string]: number }, -- nível de cada upgrade do terminal (shared/Upgrades.luau)
	Cells: { CellData }, -- anomalias contidas
	Builds: { [string]: boolean }, -- partes da loja compradas nos botões do chão (shared/Builds.luau)
	Franchise: number, -- quantas Franquias (rebirths) já abriu
	Index: { [string]: boolean }, -- anomalias já capturadas, por "Tipo:Variante" (Index)
	Codes: { [string]: boolean }, -- códigos já usados
	DailyStreak: number, -- dias seguidos pegando a recompensa diária
	DailyLastDay: number, -- dia (os.time() // 86400) da última recompensa diária
	TotalEarned: number, -- tudo que já entrou no cofre (placar global)
	TotalCaptured: number,
	Onboarding: { [string]: boolean }, -- passos do funil de primeira vez já registrados (server/Analytics.luau)
}

local TEMPLATE: PlayerData = {
	Cash = 0,
	SafeBalance = 0,
	LastLogout = 0,
	Upgrades = {},
	Cells = {},
	Builds = {},
	Franchise = 0,
	Index = {},
	Codes = {},
	DailyStreak = 0,
	DailyLastDay = 0,
	TotalEarned = 0,
	TotalCaptured = 0,
	Onboarding = {},
}

-- Mudar o nome cria um banco novo e zera todo mundo. Só fazer isso antes do lançamento.
-- v2: a loja passou a começar como barraquinha e crescer com compras (os saves da v1 não servem mais).
local store = ProfileStore.New("PlayerData_v2", TEMPLATE)

local profiles: { [Player]: any } = {}

local Data = {}

-- Carrega os dados do jogador. Pode demorar (espera o DataStore). Devolve nil se não deu para carregar,
-- e nesse caso o jogador já foi expulso com uma mensagem.
function Data.load(player: Player): PlayerData?
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			player:Kick("We couldn't load your data. Please rejoin.")
		end
		return nil
	end

	profile:AddUserId(player.UserId) -- exigido pelas regras de privacidade (GDPR)
	profile:Reconcile() -- preenche campos novos do TEMPLATE em saves antigos

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		-- Saiu enquanto carregava.
		profile:EndSession()
		return nil
	end

	profiles[player] = profile
	return profile.Data :: PlayerData
end

-- Dados já carregados, ou nil se ainda não carregou (ou o jogador saiu).
function Data.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data :: PlayerData else nil
end

-- Espera os dados carregarem (até `timeout` segundos). Para sistemas que começam junto com o Economy mas
-- precisam dos dados salvos.
function Data.waitFor(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while profiles[player] == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.2)
	end
	return Data.get(player)
end

function Data.release(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	profile.Data.LastLogout = os.time()
	profile:EndSession()
end

return Data
