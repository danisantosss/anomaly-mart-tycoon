--!strict
-- Relógio do servidor: alterna entre dia e madrugada (docs/V1.md, seção 2).
--
-- A fase atual fica em atributos do ReplicatedStorage, que o cliente lê para a HUD:
--   Phase        "Day" ou "Night"
--   PhaseEndsAt  workspace:GetServerTimeNow() em que a fase acaba
--   RedMoon      true durante uma madrugada de Lua Vermelha (evento do servidor inteiro, docs/V2.md seção 6)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Phase = "Day" | "Night"

local DayNight = {}

local phase: Phase = "Day"
local redMoon = false
local random = Random.new()

local RED_MOON_LOOK = {
	ClockTime = 0,
	Brightness = 0.6,
	Ambient = Color3.fromRGB(70, 18, 22),
	OutdoorAmbient = Color3.fromRGB(80, 20, 25),
	FogEnd = 260,
	FogColor = Color3.fromRGB(60, 8, 12),
}
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
	TweenService:Create(Lighting, info, if redMoon then RED_MOON_LOOK else LOOKS[of]):Play()
end

local function redMoonChance(): number
	local studio = Config.Debug.STUDIO_RED_MOON_CHANCE
	return if RunService:IsStudio() and studio > 0 then studio else Config.RedMoon.CHANCE
end

function DayNight.isRedMoon(): boolean
	return redMoon
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
	redMoon = newPhase == "Night" and random:NextNumber() < redMoonChance()
	ReplicatedStorage:SetAttribute("RedMoon", redMoon)
	if redMoon then
		Remotes.get("Notify"):FireAllClients(
			"RED MOON! More anomalies tonight, and rare variants are 3x more likely!",
			Color3.fromRGB(255, 70, 70)
		)
	end
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
