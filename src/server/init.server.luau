--!strict
-- Ponto de entrada do servidor (vira o Script "Server" dentro de ServerScriptService).
-- Os sistemas do jogo moram em ModuleScripts dentro desta pasta e são iniciados daqui, em ordem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = require(script.Analytics)
local Builds = require(script.Builds)
local Cells = require(script.Cells)
local Config = require(ReplicatedStorage.Shared.Config)
local Customers = require(script.Customers)
local DayNight = require(script.DayNight)
local Door = require(script.Door)
local Economy = require(script.Economy)
local Franchise = require(script.Franchise)
local Leaderboards = require(script.Leaderboards)
local MonsterPowers = require(script.MonsterPowers)
local Passes = require(script.Passes)
local Plots = require(script.Plots)
local RandomEvents = require(script.RandomEvents)
local Receipts = require(script.Receipts)
local Rewards = require(script.Rewards)
local RiftInvasion = require(script.RiftInvasion)
local RiftLure = require(script.RiftLure)
local Shelves = require(script.Shelves)
local Social = require(script.Social)
local Steal = require(script.Steal)
local StreetMonsters = require(script.StreetMonsters)
local StoreUpgrades = require(script.StoreUpgrades)
local Weapons = require(script.Weapons)

Plots.start() -- primeiro: os outros sistemas usam a loja do jogador
Passes.start()
Economy.start()
DayNight.start()
Shelves.start()
Cells.start()
MonsterPowers.start()
StoreUpgrades.start()
Door.start()
Builds.start() -- reconstrói o que o jogador comprou: depois de Shelves, Cells, StoreUpgrades e Door
Customers.start()
Steal.start()
StreetMonsters.start()
RiftInvasion.start() -- depois de StreetMonsters (chuva de monstros no fim)
RiftLure.start() -- registra os produtos no Receipts
Receipts.start()
Weapons.start() -- depois de StreetMonsters, RiftInvasion e Steal
RandomEvents.start()
Franchise.start()
Rewards.start()
Social.start()
Leaderboards.start()
Analytics.start()

print(`[Anomaly Mart] servidor iniciado (v{Config.VERSION})`)
