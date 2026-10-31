--!strict
-- Constrói a rua fixa: chão, asfalto, calçadas, os 8 terrenos vazios e um ponto de spawn neutro.
-- As lojas em si são criadas pelo StoreBuilder quando um jogador recebe um terreno.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)

local Street = Config.Street

local StreetBuilder = {}

local GRASS = Color3.fromRGB(106, 158, 82)
local ASPHALT = Color3.fromRGB(52, 54, 58)
local LANE = Color3.fromRGB(240, 210, 90)
local LOT = Color3.fromRGB(196, 190, 178)
local SIGN = Color3.fromRGB(245, 245, 240)

local function buildPlot(index: number, parent: Instance): Model
	local plot = Instance.new("Model")
	plot.Name = `Plot{index}`
	plot:SetAttribute("PlotIndex", index)

	local origin = Layout.plotCFrame(index)

	local lot = Parts.make({
		name = "Lot",
		size = Vector3.new(Street.PLOT_SIZE, 0.1, Street.PLOT_SIZE),
		cframe = origin * CFrame.new(0, 0.05, 0),
		color = LOT,
		material = Enum.Material.Concrete,
		parent = plot,
	})
	plot.PrimaryPart = lot

	-- Placa de "terreno livre", escondida quando alguém é dono do terreno.
	local sign = Parts.make({
		name = "AvailableSign",
		size = Vector3.new(12, 4, 0.5),
		cframe = origin * CFrame.new(0, 5, Layout.STORE_FRONT_Z),
		color = SIGN,
		parent = plot,
	})
	Parts.label(sign, "AVAILABLE", ASPHALT)

	plot.Parent = parent
	return plot
end

function StreetBuilder.build(): Folder
	local street = Instance.new("Folder")
	street.Name = "Street"

	local length = Layout.STREET_LENGTH + 80
	local width = Street.ROAD_WIDTH + Street.PLOT_SIZE * 2 + 80

	Parts.make({
		name = "Ground",
		size = Vector3.new(length, 1, width),
		cframe = CFrame.new(0, -0.5, 0),
		color = GRASS,
		material = Enum.Material.Grass,
		parent = street,
	})

	Parts.make({
		name = "Road",
		size = Vector3.new(length, 0.1, Street.ROAD_WIDTH),
		cframe = CFrame.new(0, 0.05, 0),
		color = ASPHALT,
		material = Enum.Material.Asphalt,
		parent = street,
	})

	Parts.make({
		name = "LaneMarking",
		size = Vector3.new(length, 0.02, 0.6),
		cframe = CFrame.new(0, 0.11, 0),
		color = LANE,
		canCollide = false,
		parent = street,
	})

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = street
	for index = 1, Street.PLOT_COUNT do
		buildPlot(index, plots)
	end

	-- Spawn neutro no meio da rua, usado só por quem ainda não tem loja.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StreetSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.2, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = street

	street.Parent = workspace
	return street
end

return StreetBuilder
