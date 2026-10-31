--!strict
-- Cria o boneco de um cliente: R15 do próprio Roblox com pele e roupa sorteadas (HumanoidDescription).
-- Usado pelos clientes andando na loja e pelas anomalias expostas nas celas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CustomerModel = {}

CustomerModel.COLLISION_GROUP = "Customers"

local SKIN_TONES = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(92, 56, 32),
}

local CLOTHES = {
	Color3.fromRGB(52, 101, 164),
	Color3.fromRGB(204, 0, 0),
	Color3.fromRGB(78, 154, 6),
	Color3.fromRGB(237, 212, 0),
	Color3.fromRGB(117, 80, 123),
	Color3.fromRGB(46, 52, 54),
	Color3.fromRGB(245, 121, 0),
	Color3.fromRGB(238, 238, 236),
}

local random = Random.new()

local function pick(list: { Color3 }): Color3
	return list[random:NextInteger(1, #list)]
end

function CustomerModel.randomDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKIN_TONES)
	local shirt = pick(CLOTHES)
	local pants = pick(CLOTHES)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	return description
end

-- Cria o boneco a partir de uma aparência (ou uma aleatória). Pode demorar um instante.
function CustomerModel.build(description: HumanoidDescription?): Model
	local model = Players:CreateHumanoidModelFromDescription(
		description or CustomerModel.randomDescription(),
		Enum.HumanoidRigType.R15
	)
	model.Name = "Customer"

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.Customers.WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CustomerModel.COLLISION_GROUP
		end
	end

	return model
end

return CustomerModel
