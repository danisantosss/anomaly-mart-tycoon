--!strict
-- Ponto de entrada do cliente (vira o LocalScript "Client" dentro de StarterPlayerScripts).
-- Roda uma vez para cada jogador, no computador/celular dele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local FranchiseUi = require(script.FranchiseUi)
local Hud = require(script.Hud)
local IndexUi = require(script.IndexUi)
local LureUi = require(script.LureUi)
local Menu = require(script.Menu)
local MonsterAnimator = require(script.MonsterAnimator)
local OwnerDoor = require(script.OwnerDoor)
local PadColors = require(script.PadColors)
local PromptFilter = require(script.PromptFilter)
local PromptStack = require(script.PromptStack)
local RewardsUi = require(script.RewardsUi)
local UpgradesUi = require(script.UpgradesUi)

PromptFilter.start()
PromptStack.start()
OwnerDoor.start()
PadColors.start()
Hud.start()
UpgradesUi.start()
IndexUi.start()
LureUi.start()
RewardsUi.start()
FranchiseUi.start()
Menu.start()
MonsterAnimator.start()

print(`[Anomaly Mart] cliente iniciado para {Players.LocalPlayer.Name} (v{Config.VERSION})`)
