--!strict
-- Monta a loja de um jogador dentro do terreno dele.
--
-- A loja começa como uma barraquinha (Pieces.buildStarter). O resto (piso, paredes, prateleiras, sala dos
-- fundos...) é construído pelo Builds.luau conforme o jogador compra nos botões do chão. Os nomes que os
-- outros sistemas procuram estão descritos no topo do Pieces.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)
local Pieces = require(script.Parent.Pieces)

local Street = Config.Street

local StoreBuilder = {}

local CELL = Color3.fromRGB(150, 210, 255)

-- Cria a cela número `index` na sala dos fundos. Usado pelo Cells.luau.
function StoreBuilder.addCell(origin: CFrame, store: Model, index: number): Part
	local cells = store:FindFirstChild("Cells")
	assert(cells, "loja sem pasta Cells")

	local size = Street.CELL_SIZE
	local offset = Layout.cellOffset(index)
	local cell = Parts.make({
		name = `Cell{index}`,
		size = size,
		cframe = origin * CFrame.new(offset + Vector3.new(0, 0.3 + size.Y / 2, 0)),
		color = CELL,
		material = Enum.Material.Glass,
		transparency = 0.6,
		canCollide = false,
		parent = cells,
	})
	-- Moldura de metal embaixo e em cima, para parecer uma cápsula de contenção.
	for _, y in { -size.Y / 2 + 0.2, size.Y / 2 - 0.2 } do
		local ring = Parts.make({
			name = "Ring",
			size = Vector3.new(size.X + 0.4, 0.4, size.Z + 0.4),
			cframe = cell.CFrame * CFrame.new(0, y, 0),
			color = Color3.fromRGB(70, 74, 82),
			material = Enum.Material.Metal,
			canCollide = false,
			parent = cell,
		})
		ring.CanQuery = false
	end
	return cell
end

-- Cria a loja inicial (barraquinha) do jogador no terreno `parent`.
function StoreBuilder.build(origin: CFrame, owner: Player, parent: Instance): Model
	local store = Instance.new("Model")
	store.Name = "Store"
	store:SetAttribute("OwnerUserId", owner.UserId)

	Pieces.buildStarter({ origin = origin, store = store, owner = owner, created = {} })

	store.Parent = parent
	return store
end

return StoreBuilder
