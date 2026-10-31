--!strict
-- Relógio do servidor: alterna entre dia e madrugada (docs/V1.md, seção 2).
--
-- A fase atual fica em atributos do ReplicatedStorage, que o cliente lê para a HUD:
--   Phase        "Day" ou "Night"
--   PhaseEndsAt  workspace:GetServerTimeNow() em que a fase acaba

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

export type Phase = "Day" | "Night"

local DayNight = {}

local phase: Phase = "Day"
local listeners: { (Phase) -> () } = {}

local LOOKS: { [Phase]: { [string]: any } } = {
	Day = {
		ClockTime = 14,
		Brightness = 2,
		Ambient = Color3.fromRGB(110, 110, 110),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		FogEnd = 1000,
		FogColor = Color3.fromRGB(190, 210, 230),
	},
	Night = {
		ClockTime = 0,
		Brightness = 0.3,
		Ambient = Color3.fromRGB(25, 28, 40),
		OutdoorAmbient = Color3.fromRGB(20, 22, 35),
		FogEnd = 220,
		FogColor = Color3.fromRGB(10, 12, 20),
	},
}

local function duration(of: Phase): number
	local studio = RunService:IsStudio()
	if of == "Day" then
		local custom = Config.Debug.STUDIO_DAY_SECONDS
		return if studio and custom > 0 then custom else Config.Cycle.DAY_SECONDS
	end
	local custom = Config.Debug.STUDIO_NIGHT_SECONDS
	return if studio and custom > 0 then custom else Config.Cycle.NIGHT_SECONDS
end

local function applyLook(of: Phase)
	local info = TweenInfo.new(Config.Cycle.TRANSITION_SECONDS, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, LOOKS[of]):Play()
end

function DayNight.getPhase(): Phase
	return phase
end

function DayNight.isNight(): boolean
	return phase == "Night"
end

-- Chama `listener(novaFase)` toda vez que a fase muda.
function DayNight.onPhaseChanged(listener: (Phase) -> ())
	table.insert(listeners, listener)
end

local function enter(newPhase: Phase)
	phase = newPhase
	ReplicatedStorage:SetAttribute("Phase", newPhase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration(newPhase))
	applyLook(newPhase)
	for _, listener in listeners do
		task.spawn(listener, newPhase)
	end
end

function DayNight.start()
	enter("Day")
	task.spawn(function()
		while true do
			task.wait(duration(phase))
			enter(if phase == "Day" then "Night" else "Day")
		end
	end)
end

return DayNight
