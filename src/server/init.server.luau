--!strict
-- Ponto de entrada do servidor (vira o Script "Server" dentro de ServerScriptService).
-- Os sistemas do jogo moram em ModuleScripts dentro desta pasta e são iniciados daqui, em ordem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cells = require(script.Cells)
local Config = require(ReplicatedStorage.Shared.Config)
local Customers = require(script.Customers)
local DayNight = require(script.DayNight)
local Door = require(script.Door)
local Economy = require(script.Economy)
local Plots = require(script.Plots)
local Shelves = require(script.Shelves)
local Steal = require(script.Steal)

Plots.start() -- primeiro: os outros sistemas usam a loja do jogador
Economy.start()
DayNight.start()
Shelves.start()
Cells.start()
Customers.start()
Steal.start()
Door.start()

print(`[Anomaly Mart] servidor iniciado (v{Config.VERSION})`)
