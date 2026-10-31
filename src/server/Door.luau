--!strict
-- Porta de aço da sala dos fundos (docs/V1.md, seção 6).
--
-- O dono aperta "Lock Door" na porta dos fundos: ela fecha por 60 s e ninguém passa, menos ele (o cliente
-- dele deixa a porta sem colisão só para ele, ver client/OwnerDoor.luau). Depois precisa esperar a recarga,
-- contada a partir do momento em que trancou.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Plots = require(script.Parent.Plots)
local StoreUpgrades = require(script.Parent.StoreUpgrades)

local Settings = Config.Door

local LOCKED_COLOR = Color3.fromRGB(110, 115, 125)

local Door = {}

local notify: RemoteEvent

local function format(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function setLocked(door: BasePart, locked: boolean)
	door.Transparency = if locked then 0 else 1
	door.CanCollide = locked
	door.Material = Enum.Material.DiamondPlate
	door.Color = LOCKED_COLOR
end

-- Liga o botão "Lock Door" na porta de aço do jogador. Só existe depois de comprar a Steel Door
-- (Builds.luau chama isto). Não faz nada se já estiver ligado.
function Door.setup(player: Player)
	local store = Plots.getStore(player)
	local door = store and store:FindFirstChild("BackDoor")
	if door == nil or not door:IsA("BasePart") or door:FindFirstChild("LockPrompt") then
		return
	end

	door:SetAttribute("OwnerUserId", player.UserId)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock Door"
	prompt.ObjectText = "Steel Door"
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Parent = door

	local lockedAt = -math.huge

	prompt.Triggered:Connect(function(who)
		if who ~= player then
			return
		end
		local now = os.clock()
		local readyIn = lockedAt
			+ math.max(Settings.COOLDOWN_SECONDS, StoreUpgrades.doorLockSeconds(player) + 30)
			- now
		if readyIn > 0 then
			notify:FireClient(player, `Steel door ready in {format(readyIn)}.`, Color3.fromRGB(255, 230, 140))
			return
		end

		lockedAt = now
		local lockSeconds = StoreUpgrades.doorLockSeconds(player)
		local cooldown = math.max(Settings.COOLDOWN_SECONDS, lockSeconds + 30)
		setLocked(door, true)
		task.spawn(function()
			while door.Parent ~= nil do
				local elapsed = os.clock() - lockedAt
				if elapsed >= cooldown then
					prompt.ActionText = "Lock Door"
					return
				elseif elapsed >= lockSeconds then
					setLocked(door, false)
					prompt.ActionText = `Ready in {format(cooldown - elapsed)}`
				else
					prompt.ActionText = `Locked {format(lockSeconds - elapsed)}`
				end
				task.wait(0.5)
			end
		end)
	end)
end

-- Precisa rodar depois de Plots.start().
function Door.start()
	notify = Remotes.get("Notify")
	Plots.onStoreReady(Door.setup)
end

return Door
