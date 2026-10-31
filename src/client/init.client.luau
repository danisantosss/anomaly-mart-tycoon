--!strict
-- Ponto de entrada do cliente (vira o LocalScript "Client" dentro de StarterPlayerScripts).
-- Roda uma vez para cada jogador, no computador/celular dele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[Anomaly Mart] cliente iniciado para {Players.LocalPlayer.Name} (v{Config.VERSION})`)
