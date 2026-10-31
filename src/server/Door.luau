--!strict
-- Porta de aço da sala dos fundos (docs/V1.md, seção 6).
--
-- O dono aperta "Lock Door" na porta dos fundos: ela fecha por 60 s e ninguém passa (nem ele). Depois
-- precisa esperar a recarga, contada a partir do momento em que trancou.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Plots = require(script.Parent.Plots)

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

local function setup(player: Player)
	local store = Plots.getStore(player)
	local door = store and store:FindFirstChild("BackDoor")
	if door == nil or not door:IsA("BasePart") then
		return
	end

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
		local readyIn = lockedAt + Settings.COOLDOWN_SECONDS - now
		if readyIn > 0 then
			notify:FireClient(player, `Steel door ready in {format(readyIn)}.`, Color3.fromRGB(255, 230, 140))
			return
		end

		lockedAt = now
		setLocked(door, true)
		task.spawn(function()
			while door.Parent ~= nil do
				local elapsed = os.clock() - lockedAt
				if elapsed >= Settings.COOLDOWN_SECONDS then
					prompt.ActionText = "Lock Door"
					return
				elseif elapsed >= Settings.LOCK_SECONDS then
					setLocked(door, false)
					prompt.ActionText = `Ready in {format(Settings.COOLDOWN_SECONDS - elapsed)}`
				else
					prompt.ActionText = `Locked {format(Settings.LOCK_SECONDS - elapsed)}`
				end
				task.wait(0.5)
			end
		end)
	end)
end

-- Precisa rodar depois de Plots.start().
function Door.start()
	notify = Remotes.get("Notify")
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
end

return Door
