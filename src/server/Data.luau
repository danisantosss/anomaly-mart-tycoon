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
	LastLogout: number, -- os.time() da última saída, para o ganho offline (PR 8)
	Upgrades: { [string]: number }, -- nível de cada upgrade (PR 8)
	Cells: { CellData }, -- anomalias contidas (PR 6)
}

local TEMPLATE: PlayerData = {
	Cash = 0,
	SafeBalance = 0,
	LastLogout = 0,
	Upgrades = {},
	Cells = {},
}

-- Mudar o nome cria um banco novo e zera todo mundo. Só fazer isso antes do lançamento.
local store = ProfileStore.New("PlayerData_v1", TEMPLATE)

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

function Data.release(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	profile.Data.LastLogout = os.time()
	profile:EndSession()
end

return Data
