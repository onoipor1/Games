-- MapBuilder.server.lua
-- Generates the game world: terrain, zones, decorations.

local workspace  = game:GetService("Workspace")
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

local mapSize = GameConfig.MapSize

-- ─────────────────────────────────────────
-- Helper
-- ─────────────────────────────────────────
local function makePart(name, size, color, material, position, anchored, parent)
	local p          = Instance.new("Part")
	p.Name           = name
	p.Size           = size
	p.BrickColor     = BrickColor.new(color)
	p.Material       = material
	p.Anchored       = anchored
	p.CanCollide     = true
	p.CFrame         = CFrame.new(position)
	p.Parent         = parent or workspace
	return p
end

-- ─────────────────────────────────────────
-- Ground
-- ─────────────────────────────────────────
makePart(
	"Ground",
	Vector3.new(mapSize * 2, 4, mapSize * 2),
	"Bright green",
	Enum.Material.Grass,
	Vector3.new(0, -2, 0),
	true
)

-- ─────────────────────────────────────────
-- Boundary walls (invisible)
-- ─────────────────────────────────────────
local wallData = {
	{ pos = Vector3.new(0, 20, -mapSize),    size = Vector3.new(mapSize * 2, 44, 4) },
	{ pos = Vector3.new(0, 20,  mapSize),    size = Vector3.new(mapSize * 2, 44, 4) },
	{ pos = Vector3.new(-mapSize, 20, 0),    size = Vector3.new(4, 44, mapSize * 2) },
	{ pos = Vector3.new( mapSize, 20, 0),    size = Vector3.new(4, 44, mapSize * 2) },
}
for _, w in ipairs(wallData) do
	local wall              = Instance.new("Part")
	wall.Name               = "Boundary"
	wall.Size               = w.size
	wall.Anchored           = true
	wall.CanCollide         = true
	wall.Transparency       = 1
	wall.CFrame             = CFrame.new(w.pos)
	wall.Parent             = workspace
end

-- ─────────────────────────────────────────
-- Zone: Forest area (trees/logs)
-- ─────────────────────────────────────────
local forestFolder = Instance.new("Folder")
forestFolder.Name  = "ForestZone"
forestFolder.Parent = workspace

local function spawnTree(x, z)
	-- Trunk
	local trunk = makePart(
		"TreeTrunk",
		Vector3.new(4, math.random(12, 20), 4),
		"Reddish brown",
		Enum.Material.Wood,
		Vector3.new(x, math.random(6, 10), z),
		true,
		forestFolder
	)
	-- Canopy
	local canopy = makePart(
		"TreeCanopy",
		Vector3.new(math.random(14, 22), math.random(10, 16), math.random(14, 22)),
		"Bright green",
		Enum.Material.LeafyGrass,
		Vector3.new(x, trunk.Position.Y + trunk.Size.Y / 2 + 6, z),
		true,
		forestFolder
	)
	canopy.Shape = Enum.PartType.Ball
end

-- Scatter trees across the map
math.randomseed(12345)
for _ = 1, 30 do
	local x = math.random(-mapSize + 20, mapSize - 20)
	local z = math.random(-mapSize + 20, mapSize - 20)
	spawnTree(x, z)
end

-- ─────────────────────────────────────────
-- Zone: Rock formations
-- ─────────────────────────────────────────
local rockFolder = Instance.new("Folder")
rockFolder.Name  = "Rocks"
rockFolder.Parent = workspace

for _ = 1, 20 do
	local x    = math.random(-mapSize + 10, mapSize - 10)
	local z    = math.random(-mapSize + 10, mapSize - 10)
	local h    = math.random(4, 12)
	local rock = makePart(
		"Rock",
		Vector3.new(math.random(6, 14), h, math.random(6, 14)),
		"Medium stone grey",
		Enum.Material.Rock,
		Vector3.new(x, h / 2, z),
		true,
		rockFolder
	)
	rock.CFrame = rock.CFrame * CFrame.Angles(
		math.random(-15, 15) * math.pi / 180,
		math.random(0, 360)  * math.pi / 180,
		math.random(-15, 15) * math.pi / 180
	)
end

-- ─────────────────────────────────────────
-- Zone: Pond (water area)
-- ─────────────────────────────────────────
local pond = makePart(
	"Pond",
	Vector3.new(60, 1, 60),
	"Bright blue",
	Enum.Material.Water,
	Vector3.new(80, -0.5, 80),
	true
)
pond.Transparency = 0.3

-- ─────────────────────────────────────────
-- Zone: Mushroom Clearing
-- ─────────────────────────────────────────
local mushroomFolder = Instance.new("Folder")
mushroomFolder.Name  = "Mushrooms"
mushroomFolder.Parent = workspace

local function spawnMushroom(x, z)
	local h    = math.random(5, 12)
	local stem = makePart(
		"Stem",
		Vector3.new(2, h, 2),
		"White",
		Enum.Material.SmoothPlastic,
		Vector3.new(x, h / 2, z),
		true,
		mushroomFolder
	)
	local cap = makePart(
		"Cap",
		Vector3.new(math.random(8, 16), 3, math.random(8, 16)),
		"Bright red",
		Enum.Material.SmoothPlastic,
		Vector3.new(x, h + 1.5, z),
		true,
		mushroomFolder
	)
	cap.Shape = Enum.PartType.Cylinder
	cap.CFrame = CFrame.new(cap.Position) * CFrame.Angles(0, 0, math.pi / 2)
end

for _ = 1, 12 do
	local x = math.random(-mapSize + 10, -30)
	local z = math.random(30, mapSize - 10)
	spawnMushroom(x, z)
end

-- ─────────────────────────────────────────
-- Lighting atmosphere
-- ─────────────────────────────────────────
local Lighting = game:GetService("Lighting")
Lighting.Ambient            = Color3.fromRGB(100, 120, 80)
Lighting.Brightness         = 2
Lighting.OutdoorAmbient     = Color3.fromRGB(130, 150, 100)
Lighting.TimeOfDay          = "14:00:00"
Lighting.FogColor           = Color3.fromRGB(180, 210, 160)
Lighting.FogEnd             = 800
Lighting.FogStart           = 400

-- ─────────────────────────────────────────
-- Spawn pads (one per insect type)
-- ─────────────────────────────────────────
local spawnColors = {
	Ant       = "Really black",
	Beetle    = "Reddish brown",
	Butterfly = "Bright yellow",
	Bee       = "Bright orange",
	Spider    = "Dark orange",
}

local spawnPositions = {
	Ant       = Vector3.new(-50, 1,   0),
	Beetle    = Vector3.new( 50, 1,   0),
	Butterfly = Vector3.new(  0, 1, -50),
	Bee       = Vector3.new(  0, 1,  50),
	Spider    = Vector3.new(-35, 1,  35),
}

local spawnFolder = Instance.new("Folder")
spawnFolder.Name  = "SpawnPads"
spawnFolder.Parent = workspace

for insectType, pos in pairs(spawnPositions) do
	local pad       = makePart(
		"SpawnPad_" .. insectType,
		Vector3.new(16, 1, 16),
		spawnColors[insectType],
		Enum.Material.Neon,
		pos,
		true,
		spawnFolder
	)
	pad.Transparency = 0.4

	-- Label
	local sg        = Instance.new("SurfaceGui")
	sg.Face         = Enum.NormalId.Top
	sg.Parent       = pad

	local lbl           = Instance.new("TextLabel")
	lbl.Size            = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text            = insectType
	lbl.TextColor3      = Color3.new(1, 1, 1)
	lbl.TextScaled      = true
	lbl.Font            = Enum.Font.GothamBold
	lbl.Parent          = sg
end

print("[InsectEvo] Map built.")
