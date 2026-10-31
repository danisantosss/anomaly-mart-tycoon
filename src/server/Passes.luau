--!strict
-- Gamepasses (docs/V1.md, seção 8): consulta e guarda em cache se o jogador tem cada um.
-- Os IDs ficam em Config.GamePasses. Sem ID (0), ninguém tem o gamepass, exceto no Studio com
-- Config.Debug.STUDIO_OWN_ALL_PASSES ligado.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

export type PassKey = "DoubleCash" | "RestockRobot"

local Passes = {}

local owned: { [Player]: { [string]: boolean } } = {}

local function check(player: Player, key: string): boolean
	if RunService:IsStudio() and Config.Debug.STUDIO_OWN_ALL_PASSES then
		return true
	end
	local pass = (Config.GamePasses :: any)[key]
	if pass == nil or pass.id == 0 then
		return false
	end
	local ok, result =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
	return ok and result == true
end

local function refresh(player: Player)
	local cache = {}
	for key in Config.GamePasses do
		cache[key] = check(player, key)
		player:SetAttribute(`Pass_{key}`, cache[key])
	end
	owned[player] = cache
end

function Passes.has(player: Player, key: PassKey): boolean
	local cache = owned[player]
	return cache ~= nil and cache[key] == true
end

function Passes.start()
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end

	-- Comprou dentro do jogo: vale na hora, sem precisar sair e entrar.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local cache = owned[player]
		for key, pass in Config.GamePasses do
			if pass.id == passId and cache then
				cache[key] = true
				player:SetAttribute(`Pass_{key}`, true)
			end
		end
	end)
end

return Passes
