-- MapBuilder.server.lua
-- Builds the game world: five themed zones, ground, decorations, boundary walls.
-- Zones are spaced 200 studs apart so players can distinguish them clearly.
-- Safe-zone circles and portals are created by ZoneManager.server.lua.
--
-- Zone layout (top-down):
--   [Grassland  0, 0]      [Wetland  500, 0]      [Mushroom 1000, 0]
--        |
--   [Volcanic   0,500]     [Crystal  500, 500]

local workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneData   = require(ReplicatedStorage:WaitForChild("ZoneData"))

math.randomseed(os.time())

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────
local function makePart(name, size, color, material, position, parent, extraProps)
	local p          = Instance.new("Part")
	p.Name           = name
	p.Size           = size
	p.BrickColor     = BrickColor.new(color)
	p.Material       = material
	p.Anchored       = true
	p.CanCollide     = true
	p.CFrame         = CFrame.new(position)
	p.Parent         = parent or workspace
	if extraProps then
		for k, v in pairs(extraProps) do p[k] = v end
	end
	return p
end

local function makeWalls(cx, cz, halfW, halfH, height, parent)
	-- 4 invisible boundary walls around a zone
	local wallDefs = {
		{ pos = Vector3.new(cx,          height, cz - halfH), size = Vector3.new(halfW * 2, height * 2, 4) },
		{ pos = Vector3.new(cx,          height, cz + halfH), size = Vector3.new(halfW * 2, height * 2, 4) },
		{ pos = Vector3.new(cx - halfW,  height, cz),         size = Vector3.new(4, height * 2, halfH * 2) },
		{ pos = Vector3.new(cx + halfW,  height, cz),         size = Vector3.new(4, height * 2, halfH * 2) },
	}
	for _, w in ipairs(wallDefs) do
		local wall           = Instance.new("Part")
		wall.Name            = "Boundary"
		wall.Size            = w.size
		wall.Anchored        = true
		wall.CanCollide      = true
		wall.Transparency    = 1
		wall.CFrame          = CFrame.new(w.pos)
		wall.Parent          = parent or workspace
	end
end

-- ─────────────────────────────────────────
-- Zone 1: Grassland  (center 0, 0)
-- ─────────────────────────────────────────
local function buildGrassland()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Grassland"
	folder.Parent = workspace

	-- Ground
	makePart("Ground", Vector3.new(300, 4, 300), "Bright green",
		Enum.Material.Grass, Vector3.new(0, -2, 0), folder)

	-- Boundary walls
	makeWalls(0, 0, 150, 150, 40, folder)

	-- Trees
	for _ = 1, 18 do
		local x = math.random(-130, 130)
		local z = math.random(-130, 130)
		if math.sqrt(x * x + z * z) > 40 then  -- avoid spawn area
			local h     = math.random(12, 20)
			local trunk = makePart("TreeTrunk", Vector3.new(4, h, 4), "Reddish brown",
				Enum.Material.Wood, Vector3.new(x, h / 2, z), folder)
			local canopy = makePart("TreeCanopy",
				Vector3.new(math.random(14, 22), math.random(10, 16), math.random(14, 22)),
				"Bright green", Enum.Material.LeafyGrass,
				Vector3.new(x, trunk.Position.Y + h / 2 + 6, z), folder)
			canopy.Shape = Enum.PartType.Ball
		end
	end

	-- Rocks
	for _ = 1, 10 do
		local x = math.random(-140, 140)
		local z = math.random(-140, 140)
		local h = math.random(4, 10)
		local r = makePart("Rock", Vector3.new(math.random(6, 12), h, math.random(6, 12)),
			"Medium stone grey", Enum.Material.Rock, Vector3.new(x, h / 2, z), folder)
		r.CFrame = r.CFrame * CFrame.Angles(
			math.random(-15, 15) * math.pi / 180,
			math.random(0, 360)  * math.pi / 180,
			math.random(-15, 15) * math.pi / 180
		)
	end

	-- Spawn pads (one per insect type) — in the safe zone
	local spawnColors = {
		Ant = "Really black", Beetle = "Reddish brown",
		Butterfly = "Bright yellow", Bee = "Bright orange", Spider = "Dark orange",
	}
	local spawnOffsets = {
		Ant = Vector3.new(-20, 0, 0), Beetle = Vector3.new(20, 0, 0),
		Butterfly = Vector3.new(0, 0, -20), Bee = Vector3.new(0, 0, 20),
		Spider = Vector3.new(-14, 0, 14),
	}
	for insectType, offset in pairs(spawnOffsets) do
		local pad = makePart("SpawnPad_" .. insectType, Vector3.new(14, 1, 14),
			spawnColors[insectType], Enum.Material.Neon,
			Vector3.new(0, 1, 0) + offset, folder, { Transparency = 0.4 })
		local sg  = Instance.new("SurfaceGui")
		sg.Face   = Enum.NormalId.Top
		sg.Parent = pad
		local lbl = Instance.new("TextLabel")
		lbl.Size  = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text  = insectType
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.Parent = sg
	end
end

-- ─────────────────────────────────────────
-- Zone 2: Wetland  (center 500, 0)
-- ─────────────────────────────────────────
local function buildWetland()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Wetland"
	folder.Parent = workspace

	local cx, cz = 500, 0

	makePart("Ground", Vector3.new(300, 4, 300), "Dark green",
		Enum.Material.Mud, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 150, 150, 40, folder)

	-- Central pond
	local pond = makePart("Pond", Vector3.new(80, 1, 80), "Bright blue",
		Enum.Material.Water, Vector3.new(cx, -0.5, cz), folder, { Transparency = 0.3 })

	-- Reeds / tall grass clusters
	for _ = 1, 20 do
		local x = cx + math.random(-130, 130)
		local z = cz + math.random(-130, 130)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 45 then
			local h = math.random(6, 14)
			makePart("Reed", Vector3.new(2, h, 2), "Bright green",
				Enum.Material.Grass, Vector3.new(x, h / 2, z), folder)
		end
	end

	-- Lily pads on pond surface
	for _ = 1, 8 do
		local px = cx + math.random(-30, 30)
		local pz = cz + math.random(-30, 30)
		local lp = makePart("LilyPad", Vector3.new(math.random(5, 10), 0.4, math.random(5, 10)),
			"Bright green", Enum.Material.SmoothPlastic, Vector3.new(px, 0.3, pz), folder)
		lp.Shape = Enum.PartType.Cylinder
		lp.CFrame = lp.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end

	-- Rocks
	for _ = 1, 8 do
		local x = cx + math.random(-140, 140)
		local z = cz + math.random(-140, 140)
		local h = math.random(3, 8)
		makePart("Rock", Vector3.new(math.random(4, 10), h, math.random(4, 10)),
			"Sand blue", Enum.Material.Rock, Vector3.new(x, h / 2, z), folder)
	end
end

-- ─────────────────────────────────────────
-- Zone 3: Mushroom Hollow  (center 1000, 0)
-- ─────────────────────────────────────────
local function buildMushroom()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Mushroom"
	folder.Parent = workspace

	local cx, cz = 1000, 0

	makePart("Ground", Vector3.new(300, 4, 300), "Dark grey",
		Enum.Material.Rock, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 150, 150, 40, folder)

	-- Glowing mushrooms
	local mushroomColors = { "Bright violet", "Hot pink", "Bright blue", "Bright orange" }
	for _ = 1, 22 do
		local x = cx + math.random(-130, 130)
		local z = cz + math.random(-130, 130)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 42 then
			local h    = math.random(5, 14)
			local col  = mushroomColors[math.random(1, #mushroomColors)]
			makePart("Stem", Vector3.new(2.5, h, 2.5), "White",
				Enum.Material.SmoothPlastic, Vector3.new(x, h / 2, z), folder)
			local cap = makePart("Cap", Vector3.new(math.random(9, 18), 3.5, math.random(9, 18)),
				col, Enum.Material.Neon, Vector3.new(x, h + 1.5, z), folder,
				{ Transparency = 0.2 })
			cap.Shape  = Enum.PartType.Cylinder
			cap.CFrame = cap.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	-- Spore patches (glowing spheres on ground)
	for _ = 1, 15 do
		local x = cx + math.random(-140, 140)
		local z = cz + math.random(-140, 140)
		local sp = makePart("Spore", Vector3.new(3, 3, 3), "Bright violet",
			Enum.Material.Neon, Vector3.new(x, 1.5, z), folder,
			{ Transparency = 0.6, CanCollide = false })
		sp.Shape = Enum.PartType.Ball
	end
end

-- ─────────────────────────────────────────
-- Zone 4: Volcanic Cavern  (center 0, 500)
-- ─────────────────────────────────────────
local function buildVolcanic()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Volcanic"
	folder.Parent = workspace

	local cx, cz = 0, 500

	makePart("Ground", Vector3.new(300, 4, 300), "Dark orange",
		Enum.Material.Rock, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 150, 150, 40, folder)

	-- Lava rivers (flat neon parts)
	for _, riverDef in ipairs({
		{ pos = Vector3.new(cx - 60, 0, cz), size = Vector3.new(15, 0.5, 260) },
		{ pos = Vector3.new(cx + 60, 0, cz), size = Vector3.new(15, 0.5, 260) },
		{ pos = Vector3.new(cx, 0, cz - 60), size = Vector3.new(260, 0.5, 15) },
	}) do
		local lp = makePart("LavaRiver", riverDef.size, "Bright orange",
			Enum.Material.Neon, riverDef.pos, folder, { Transparency = 0.3, CanCollide = false })
	end

	-- Volcanic rocks / pillars
	for _ = 1, 20 do
		local x = cx + math.random(-130, 130)
		local z = cz + math.random(-130, 130)
		local onLava = (math.abs(x - cx) < 65 or math.abs(z - cz) < 65) and
		               (math.abs(x - cx) > 55 or math.abs(z - cz) > 55)
		if not onLava and math.sqrt((x - cx)^2 + (z - cz)^2) > 40 then
			local h = math.random(5, 18)
			local r = makePart("VolcRock", Vector3.new(math.random(5, 12), h, math.random(5, 12)),
				"Black", Enum.Material.Rock, Vector3.new(x, h / 2, z), folder)
			r.CFrame = r.CFrame * CFrame.Angles(
				math.random(-10, 10) * math.pi / 180, 0,
				math.random(-10, 10) * math.pi / 180
			)
		end
	end

	-- Fire particles simulation (glowing orbs)
	for _ = 1, 12 do
		local x = cx + math.random(-120, 120)
		local z = cz + math.random(-120, 120)
		local fp = makePart("EmberGlow", Vector3.new(2, 2, 2), "Bright red",
			Enum.Material.Neon, Vector3.new(x, math.random(3, 10), z), folder,
			{ Transparency = 0.5, CanCollide = false })
		fp.Shape = Enum.PartType.Ball
	end
end

-- ─────────────────────────────────────────
-- Zone 5: Crystal Abyss  (center 500, 500)
-- ─────────────────────────────────────────
local function buildCrystal()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Crystal"
	folder.Parent = workspace

	local cx, cz = 500, 500

	makePart("Ground", Vector3.new(300, 4, 300), "Black",
		Enum.Material.SmoothPlastic, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 150, 150, 40, folder)

	-- Crystal pillars
	for _ = 1, 25 do
		local x = cx + math.random(-130, 130)
		local z = cz + math.random(-130, 130)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 40 then
			local h   = math.random(8, 24)
			local w   = math.random(3, 7)
			local col = math.random() > 0.5 and "Bright blue" or "Bright violet"
			local crys = makePart("Crystal", Vector3.new(w, h, w),
				col, Enum.Material.Neon, Vector3.new(x, h / 2, z), folder,
				{ Transparency = 0.3 })
			crys.CFrame = crys.CFrame * CFrame.Angles(
				math.random(-20, 20) * math.pi / 180,
				math.random(0, 360)  * math.pi / 180,
				math.random(-20, 20) * math.pi / 180
			)
		end
	end

	-- Void rifts (dark pulsing spheres)
	for _ = 1, 8 do
		local x = cx + math.random(-120, 120)
		local z = cz + math.random(-120, 120)
		local vr = makePart("VoidRift", Vector3.new(5, 5, 5), "Dark indigo",
			Enum.Material.Neon, Vector3.new(x, 2, z), folder,
			{ Transparency = 0.7, CanCollide = false })
		vr.Shape = Enum.PartType.Ball
	end

	-- Crystal floor shards
	for _ = 1, 20 do
		local x = cx + math.random(-140, 140)
		local z = cz + math.random(-140, 140)
		local sh = makePart("Shard", Vector3.new(math.random(2, 5), 0.5, math.random(2, 5)),
			"Cyan", Enum.Material.Neon, Vector3.new(x, 0.25, z), folder,
			{ Transparency = 0.4 })
	end
end

-- ─────────────────────────────────────────
-- Build everything
-- ─────────────────────────────────────────
buildGrassland()
buildWetland()
buildMushroom()
buildVolcanic()
buildCrystal()

-- ─────────────────────────────────────────
-- Global lighting (Grassland default; ZoneManager adjusts per zone)
-- ─────────────────────────────────────────
Lighting.Ambient        = Color3.fromRGB(100, 120, 80)
Lighting.Brightness     = 2
Lighting.OutdoorAmbient = Color3.fromRGB(130, 150, 100)
Lighting.TimeOfDay      = "14:00:00"
Lighting.FogColor       = Color3.fromRGB(180, 210, 160)
Lighting.FogEnd         = 1200
Lighting.FogStart       = 600

print("[InsectEvo] MapBuilder: all 5 zones built.")
