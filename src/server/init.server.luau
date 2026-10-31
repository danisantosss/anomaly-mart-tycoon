--!strict
-- Ponto de entrada do servidor (vira o Script "Server" dentro de ServerScriptService).
-- Os sistemas do jogo moram em ModuleScripts dentro desta pasta e são iniciados daqui, em ordem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Customers = require(script.Customers)
local DayNight = require(script.DayNight)
local Economy = require(script.Economy)
local Plots = require(script.Plots)
local Shelves = require(script.Shelves)

Plots.start() -- primeiro: os outros sistemas usam a loja do jogador
Economy.start()
DayNight.start()
Shelves.start()
Customers.start()

print(`[Anomaly Mart] servidor iniciado (v{Config.VERSION})`)
