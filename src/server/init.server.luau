--!strict
-- Ponto de entrada do servidor (vira o Script "Server" dentro de ServerScriptService).
-- Os sistemas do jogo vão morar em ModuleScripts dentro desta pasta e serão iniciados daqui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[Anomaly Mart] servidor iniciado (v{Config.VERSION})`)
