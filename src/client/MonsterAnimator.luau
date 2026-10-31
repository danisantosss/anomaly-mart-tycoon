--!strict
-- Anima os monstros da rua e das celas no computador de cada jogador (docs/V3.md, seção 3).
--
-- O servidor só move a raiz do monstro. Aqui mexemos nas juntas (Motor6D.Transform) a cada quadro: pernas
-- andando, asas batendo, tentáculos balançando, a tela do TV Head chiando. Como é só visual, não precisa
-- passar pela rede. Monstros longe da câmera não são animados, para não pesar no celular.
--
-- Também gira as peças com a tag "Spin" (o portal da Fenda, por exemplo).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MonsterAnimator = {}

local MONSTER_TAG = "Monster"
local SPIN_TAG = "Spin"
local MAX_DISTANCE = 160

type Joints = { [string]: Motor6D }
type Entry = {
	model: Model,
	root: BasePart,
	joints: Joints,
	kind: string,
	seed: number,
	static: { BasePart },
	glitch: { BasePart },
	top: { Motor6D }, -- juntas presas direto na raiz: recebem o bote e o tranco do golpe
}

local entries: { [Model]: Entry } = {}
local reactions: (Entry, number) -> ()

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

local function set(joints: Joints, name: string, transform: CFrame)
	local motor = joints[name]
	if motor then
		motor.Transform = transform
	end
end

-- Cada tipo recebe as juntas, o tempo (já com a fase própria do monstro), quanto está andando (0 a 1) e o
-- modelo (para ler atributos, como o "SlamAt" do Colosso).
local ANIMATIONS: { [string]: (Joints, number, number, Model) -> () } = {
	Gloop = function(joints, t, moving)
		local wobble = math.sin(t * (3 + moving * 4))
		set(
			joints,
			"Body",
			CFrame.new(0, math.abs(wobble) * (0.3 + moving * 0.5), 0) * rot(0, 0, wobble * 0.08)
		)
		set(joints, "Core", rot(t, t * 0.7, 0))
	end,

	MimicCrate = function(joints, t, moving)
		local hop = math.abs(math.sin(t * 6)) * moving
		set(joints, "Box", CFrame.new(0, hop * 1.2, 0) * rot(0, 0, math.sin(t * 6) * 0.08 * moving))
		local bite = math.max(0, math.sin(t * (2 + moving * 5)))
		set(joints, "Lid", rot(bite * 0.7, 0, 0))
		for index = 1, 2 do
			for jndex = 1, 2 do
				local phase = if (index + jndex) % 2 == 0 then 0 else math.pi
				set(joints, `Leg{index}{jndex}`, rot(0, 0, math.sin(t * 12 + phase) * 0.5 * moving))
			end
		end
	end,

	SkullHound = function(joints, t, moving)
		local stride = t * 9
		local swing = 0.6 * moving
		set(joints, "LegFL", rot(math.sin(stride) * swing, 0, 0))
		set(joints, "LegBR", rot(math.sin(stride) * swing, 0, 0))
		set(joints, "LegFR", rot(-math.sin(stride) * swing, 0, 0))
		set(joints, "LegBL", rot(-math.sin(stride) * swing, 0, 0))
		for _, name in { "LegFLLow", "LegFRLow", "LegBLLow", "LegBRLow" } do
			set(joints, name, rot(math.max(0, math.sin(stride)) * swing * 0.6, 0, 0))
		end
		set(joints, "Spine", CFrame.new(0, math.abs(math.sin(stride)) * 0.25 * moving, 0))
		set(joints, "Tail1", rot(0, math.sin(t * 10) * 0.6, 0))
		set(joints, "Tail2", rot(0, math.sin(t * 10 - 0.6) * 0.5, 0))
		set(joints, "Head", rot(math.sin(t * 1.3) * 0.1, math.sin(t * 0.7) * 0.25, 0))
		set(joints, "Jaw", rot(-math.max(0, math.sin(t * 4)) * 0.4, 0, 0))
	end,

	EyeSpider = function(joints, t, moving)
		for index = 1, 8 do
			local phase = if index % 2 == 0 then 0 else math.pi
			local lift = math.max(0, math.sin(t * 10 + phase)) * 0.5 * moving
			local sweep = math.sin(t * 10 + phase) * 0.25 * moving
			set(joints, `Leg{index}`, rot(lift, sweep, 0))
		end
		set(joints, "Eye", CFrame.new(0, math.sin(t * 5) * 0.15 * (0.3 + moving), 0))
		set(joints, "Iris", rot(0, 0, 0) * CFrame.new(0, math.sin(t * 0.9) * 0.4, math.sin(t * 1.3) * 0.5))
	end,

	TVHead = function(joints, t, moving)
		local stride = t * 7
		local swing = 0.7 * moving
		set(joints, "ArmL", rot(math.sin(stride) * swing, 0, 0))
		set(joints, "ArmR", rot(-math.sin(stride) * swing, 0, 0))
		set(joints, "LegL", rot(-math.sin(stride) * swing, 0, 0))
		set(joints, "LegR", rot(math.sin(stride) * swing, 0, 0))
		set(joints, "Torso", CFrame.new(0, math.abs(math.sin(stride)) * 0.2 * moving, 0))
		-- A cabeça entorta de vez em quando, como quem ouve um barulho.
		local tilt = if math.sin(t * 0.5) > 0.7 then math.sin(t * 8) * 0.2 else 0
		set(joints, "TV", rot(0, 0, tilt))
	end,

	StaticJelly = function(joints, t, _moving)
		set(joints, "Bell", CFrame.new(0, math.sin(t * 1.5) * 0.6, 0))
		for index = 1, 8 do
			for segment = 1, 3 do
				local wave = math.sin(t * 2.5 - segment * 0.8 + index) * 0.35
				set(joints, `Tendril{index}_{segment}`, rot(wave, 0, wave * 0.5))
			end
		end
		set(joints, "Core", rot(0, t * 2, 0))
	end,

	MothMonarch = function(joints, t, _moving)
		local flap = math.sin(t * 9)
		set(joints, "WingL", rot(0, 0, -flap * 0.7))
		set(joints, "WingR", rot(0, 0, flap * 0.7))
		set(
			joints,
			"Body",
			CFrame.new(0, math.sin(t * 9 + 1) * 0.35, 0) * rot(math.sin(t * 0.8) * 0.08, 0, 0)
		)
		set(joints, "FeelerL", rot(math.sin(t * 3) * 0.2, 0, 0))
		set(joints, "FeelerR", rot(math.sin(t * 3 + 1) * 0.2, 0, 0))
	end,

	TheTallOne = function(joints, t, moving)
		local stride = t * 2.6
		local swing = 0.45 * moving
		set(joints, "LegL", rot(math.sin(stride) * swing, 0, 0))
		set(joints, "LegR", rot(-math.sin(stride) * swing, 0, 0))
		set(joints, "LegLLow", rot(-math.max(0, math.sin(stride)) * swing, 0, 0))
		set(joints, "LegRLow", rot(-math.max(0, -math.sin(stride)) * swing, 0, 0))
		set(joints, "ArmL", rot(-math.sin(stride) * swing * 0.6, 0, 0.05))
		set(joints, "ArmR", rot(math.sin(stride) * swing * 0.6, 0, -0.05))
		set(joints, "Neck", rot(0, 0, math.sin(t * 0.6) * 0.35))
		set(joints, "Halo", rot(t, 0, 0))
	end,

	-- Colosso da Fenda (chefe da Invasão): anda nos punhos e, no "SlamAt" (hora do servidor), ergue os
	-- dois braços por 1 s e bate no chão.
	RiftColossus = function(joints, t, moving, model)
		local stride = t * 1.8
		local swing = 0.35 * math.max(moving, 0.3)
		local slamAt = model:GetAttribute("SlamAt")
		local slam = 0 -- 0 = normal, sobe até 1 com os braços erguidos, volta a 0 na batida
		if typeof(slamAt) == "number" then
			local since = workspace:GetServerTimeNow() - (slamAt - 1)
			if since >= 0 and since < 1 then
				slam = since -- erguendo
			elseif since >= 1 and since < 1.25 then
				slam = 1 - (since - 1) * 4 -- batendo
			end
		end
		local raise = 2.4 * slam -- ângulo positivo leva a mão para a frente e para cima
		set(joints, "ArmL", rot(math.sin(stride) * swing * (1 - slam) + raise, 0, 0))
		set(joints, "ArmR", rot(-math.sin(stride) * swing * (1 - slam) + raise, 0, 0))
		set(joints, "LegL", rot(-math.sin(stride) * swing, 0, 0))
		set(joints, "LegR", rot(math.sin(stride) * swing, 0, 0))
		set(
			joints,
			"Body",
			CFrame.new(0, math.abs(math.sin(stride)) * 0.3, 0) * rot(0.3 * slam, 0, math.sin(stride) * 0.05)
		)
		set(joints, "Head", rot(0.3 * slam, math.sin(t * 0.7) * 0.4, 0))
		set(joints, "Jaw", rot(-math.max(0, math.sin(t * 1.3)) * 0.4 - slam * 0.5, 0, 0))
	end,

	RiftKing = function(joints, t, _moving)
		set(joints, "Core", CFrame.new(0, math.sin(t * 1.2) * 0.5, 0) * rot(0, t * 0.8, 0))
		set(joints, "Orbit", rot(0, t * 1.5, math.sin(t * 0.5) * 0.2))
		set(joints, "Face", CFrame.new(0, math.sin(t * 1.2) * 0.5, 0))
		set(joints, "Robe", CFrame.new(0, math.sin(t * 1.2) * 0.5, 0))
		set(joints, "HandL", CFrame.new(math.sin(t * 2) * 0.4, math.sin(t * 1.6) * 0.8, 0))
		set(joints, "HandR", CFrame.new(-math.sin(t * 2) * 0.4, math.sin(t * 1.6 + 1) * 0.8, 0))
	end,
}

-- Por cima da animação de cada tipo: bote para a frente quando ataca ("AttackAt") e tranco para trás
-- quando leva um golpe do bastão ("HitAt"). Os dois atributos são a hora do servidor.
local ATTACK_SECONDS = 0.35
local HIT_SECONDS = 0.2

function reactions(entry: Entry, serverNow: number)
	local extra = CFrame.identity
	local attackAt = entry.model:GetAttribute("AttackAt")
	if typeof(attackAt) == "number" and serverNow - attackAt < ATTACK_SECONDS then
		local k = math.sin(math.pi * math.max(serverNow - attackAt, 0) / ATTACK_SECONDS)
		extra *= CFrame.new(0, 0, -1.5 * k) * CFrame.Angles(-0.3 * k, 0, 0)
	end
	local hitAt = entry.model:GetAttribute("HitAt")
	if typeof(hitAt) == "number" and serverNow - hitAt < HIT_SECONDS then
		local k = math.sin(math.pi * math.max(serverNow - hitAt, 0) / HIT_SECONDS)
		extra *= CFrame.new(0, 0, 0.6 * k) * CFrame.Angles(0.35 * k, 0, 0)
	end
	if extra ~= CFrame.identity then
		for _, motor in entry.top do
			motor.Transform = extra * motor.Transform
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local entry: Entry = {
		model = model,
		root = root,
		joints = {},
		kind = tostring(model:GetAttribute("Kind")),
		seed = math.random() * 100,
		static = {},
		glitch = {},
		top = {},
	}
	local glitching = model:GetAttribute("Glitch") == true
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			entry.joints[descendant.Name] = descendant
			if descendant.Part0 == root then
				table.insert(entry.top, descendant)
			end
		elseif descendant:IsA("BasePart") then
			if descendant:GetAttribute("Static") then
				table.insert(entry.static, descendant)
			end
			if glitching and descendant ~= root then
				table.insert(entry.glitch, descendant)
			end
		end
	end
	entries[model] = entry
end

local function untrack(model: Instance)
	if model:IsA("Model") then
		entries[model] = nil
	end
end

local spinners: { [BasePart]: CFrame } = {}

local function trackSpin(part: Instance)
	if part:IsA("BasePart") then
		spinners[part] = part.CFrame
	end
end

local random = Random.new()
local lastFlicker = 0

local function step()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	local flicker = now - lastFlicker > 0.08
	if flicker then
		lastFlicker = now
	end

	for model, entry in entries do
		if model.Parent == nil then
			entries[model] = nil
			continue
		end
		if (entry.root.Position - eye).Magnitude > MAX_DISTANCE then
			continue
		end
		local speed = entry.root.AssemblyLinearVelocity.Magnitude
		local moving = math.clamp(speed / 6, 0, 1)
		local animate = ANIMATIONS[entry.kind]
		-- Zera as juntas da raiz antes de animar: o bote/tranco de antes não pode se acumular nas que a
		-- animação do tipo não mexe.
		for _, motor in entry.top do
			motor.Transform = CFrame.identity
		end
		if animate then
			animate(entry.joints, now + entry.seed, moving, model)
		end
		reactions(entry, workspace:GetServerTimeNow())
		if flicker then
			for _, screen in entry.static do
				local gray = random:NextNumber(0.35, 1)
				screen.Color = Color3.new(gray, gray, gray * 1.05)
			end
			for _, part in entry.glitch do
				if random:NextNumber() < 0.3 then
					part.Color = Color3.fromHSV(random:NextNumber(), 1, 1)
				end
			end
		end
	end

	for part, base in spinners do
		if part.Parent == nil then
			spinners[part] = nil
			continue
		end
		local speed = part:GetAttribute("SpinSpeed")
		local angle = (if typeof(speed) == "number" then speed else 1) * now
		part.CFrame = base * CFrame.Angles(angle, 0, 0)
	end
end

function MonsterAnimator.start()
	for _, model in CollectionService:GetTagged(MONSTER_TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(MONSTER_TAG):Connect(function(model)
		-- Espera as peças chegarem do servidor antes de procurar as juntas.
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal(MONSTER_TAG):Connect(untrack)

	for _, part in CollectionService:GetTagged(SPIN_TAG) do
		trackSpin(part)
	end
	CollectionService:GetInstanceAddedSignal(SPIN_TAG):Connect(trackSpin)

	RunService.PreSimulation:Connect(step)
end

return MonsterAnimator
