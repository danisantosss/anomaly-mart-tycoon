--!strict
-- Bônus de amigo (docs/V2.md, seção 5): +10% de renda para cada amigo do Roblox no mesmo servidor, até +30%.
-- Fica no atributo "FriendBoost" do jogador, que o Economy.incomeMultiplier lê.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Social = {}

-- Cache de "a é amigo de b" (a consulta ao Roblox demora e pode falhar).
local friendship: { [string]: boolean } = {}

local function areFriends(a: Player, b: Player): boolean
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = `{low}_{high}`
	local cached = friendship[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	local value = ok and result == true
	friendship[key] = value
	return value
end

local function recompute()
	local players = Players:GetPlayers()
	for _, player in players do
		local friends = 0
		for _, other in players do
			if other ~= player and areFriends(player, other) then
				friends += 1
			end
		end
		local boost = math.min(friends * Config.Bonuses.FRIEND_PER_FRIEND, Config.Bonuses.FRIEND_MAX)
		player:SetAttribute("FriendBoost", boost)
	end
end

function Social.start()
	Players.PlayerAdded:Connect(function()
		task.defer(recompute)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(recompute)
	end)
	task.defer(recompute)
end

return Social
