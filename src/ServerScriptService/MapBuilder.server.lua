-- MapBuilder.server.lua
-- Builds the game world: five themed zones (each 600×600 studs), ground, decorations, boundary walls.
-- Zones are 800 studs apart center-to-center.
--
-- Zone layout (top-down):
--   [Grassland  0,0]   [Wetland  800,0]   [Mushroom 1600,0]
--        |
--   [Volcanic   0,800]  [Crystal  800,800]

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
		{ pos = Vector3.new(cx,         height, cz - halfH), size = Vector3.new(halfW * 2, height * 2, 4) },
		{ pos = Vector3.new(cx,         height, cz + halfH), size = Vector3.new(halfW * 2, height * 2, 4) },
		{ pos = Vector3.new(cx - halfW, height, cz),         size = Vector3.new(4, height * 2, halfH * 2) },
		{ pos = Vector3.new(cx + halfW, height, cz),         size = Vector3.new(4, height * 2, halfH * 2) },
	}
	for _, w in ipairs(wallDefs) do
		local wall        = Instance.new("Part")
		wall.Name         = "Boundary"
		wall.Size         = w.size
		wall.Anchored     = true
		wall.CanCollide   = true
		wall.Transparency = 1
		wall.CFrame       = CFrame.new(w.pos)
		wall.Parent       = parent or workspace
	end
end

-- ─────────────────────────────────────────
-- Realistic tree builder (Grassland)
-- ─────────────────────────────────────────
local function makeRealisticTree(x, z, folder)
	local trunkH = math.random(18, 32)
	local trunkW = math.random(3, 5)

	-- Main trunk (tapers slightly — simulated with a slightly narrower top section)
	local trunk = makePart("TreeTrunk",
		Vector3.new(trunkW, trunkH, trunkW), "Reddish brown",
		Enum.Material.Wood, Vector3.new(x, trunkH / 2, z), folder)

	-- Upper trunk (narrower top third)
	makePart("TreeTrunkUpper",
		Vector3.new(trunkW - 1, trunkH * 0.35, trunkW - 1), "Reddish brown",
		Enum.Material.Wood, Vector3.new(x, trunkH * 0.82, z), folder)

	-- Root flares (4 at ground level)
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local rOff  = trunkW * 0.8
		local rx    = x + math.cos(angle) * (trunkW / 2 + rOff * 0.6)
		local rz    = z + math.sin(angle) * (trunkW / 2 + rOff * 0.6)
		local root  = makePart("RootFlare",
			Vector3.new(rOff, trunkH * 0.12, rOff * 0.6), "Reddish brown",
			Enum.Material.Wood, Vector3.new(rx, trunkH * 0.06, rz), folder)
		root.CFrame = root.CFrame * CFrame.Angles(
			math.random(-20, -10) * math.pi / 180,
			angle + math.pi / 2,
			0
		)
	end

	-- Side branches (2–4 branches at varying heights)
	local branchCount = math.random(2, 4)
	for i = 1, branchCount do
		local angle  = math.random() * math.pi * 2
		local bH     = trunkH * (0.45 + i / branchCount * 0.30)
		local bLen   = math.random(5, 11)
		local bX     = x + math.cos(angle) * bLen * 0.5
		local bZ     = z + math.sin(angle) * bLen * 0.5
		local branch = makePart("Branch",
			Vector3.new(bLen, 1.6, 1.6), "Reddish brown",
			Enum.Material.Wood, Vector3.new(bX, bH, bZ), folder)
		branch.CFrame = CFrame.new(Vector3.new(bX, bH, bZ))
			* CFrame.Angles(0, -angle, math.random(-35, -15) * math.pi / 180)

		-- Small twig clusters on branch tip
		local twigX = x + math.cos(angle) * bLen * 0.85
		local twigZ = z + math.sin(angle) * bLen * 0.85
		makePart("Twig",
			Vector3.new(bLen * 0.3, 1, 1), "Reddish brown",
			Enum.Material.Wood,
			Vector3.new(twigX, bH + math.random(1, 3), twigZ), folder)
	end

	-- Canopy — 4–6 overlapping leaf balls at slightly different positions and heights
	local canopyColors = {
		"Bright green", "Medium green", "Bright lime green", "Forest green", "Dark green",
	}
	local canopyCount = math.random(4, 6)
	for layer = 1, canopyCount do
		local offX    = math.random(-4, 4)
		local offZ    = math.random(-4, 4)
		local cH      = trunkH + (layer - 1) * 3 + math.random(-2, 2)
		local cRadius = math.random(8, 14) - math.floor(layer * 0.5)
		local col     = canopyColors[math.random(1, #canopyColors)]
		local canopy  = makePart("Canopy",
			Vector3.new(cRadius * 2, cRadius * 1.3, cRadius * 2),
			col, Enum.Material.LeafyGrass,
			Vector3.new(x + offX, cH, z + offZ), folder)
		canopy.Shape = Enum.PartType.Ball
	end

	-- Fallen leaf patch under tree
	local leafPatch = makePart("LeafPatch",
		Vector3.new(math.random(8, 14), 0.3, math.random(8, 14)),
		"Bright green", Enum.Material.LeafyGrass,
		Vector3.new(x + math.random(-3, 3), 0.15, z + math.random(-3, 3)), folder,
		{ CanCollide = false, Transparency = 0.2 })
	leafPatch.CFrame = leafPatch.CFrame * CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

-- ─────────────────────────────────────────
-- Zone 1: Grassland  (center 0, 0)
-- ─────────────────────────────────────────
local function buildGrassland()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Grassland"
	folder.Parent = workspace

	-- Ground (600×600)
	makePart("Ground", Vector3.new(600, 4, 600), "Bright green",
		Enum.Material.Grass, Vector3.new(0, -2, 0), folder)

	-- Gentle hills (raised mounds for visual depth)
	for _ = 1, 8 do
		local x = math.random(-240, 240)
		local z = math.random(-240, 240)
		if math.sqrt(x*x + z*z) > 80 then
			local w = math.random(30, 60)
			local h = math.random(3, 8)
			local mound = makePart("Hill", Vector3.new(w, h, w), "Bright green",
				Enum.Material.Grass, Vector3.new(x, -2 + h/2, z), folder,
				{ CanCollide = true })
			mound.Shape = Enum.PartType.Ball
		end
	end

	-- Boundary walls (±300)
	makeWalls(0, 0, 300, 300, 40, folder)

	-- Realistic trees (30 trees, avoid safe zone radius 80)
	for _ = 1, 30 do
		local x = math.random(-280, 280)
		local z = math.random(-280, 280)
		if math.sqrt(x * x + z * z) > 80 then
			makeRealisticTree(x, z, folder)
		end
	end

	-- Rocks
	for _ = 1, 18 do
		local x = math.random(-280, 280)
		local z = math.random(-280, 280)
		local h = math.random(4, 10)
		local r = makePart("Rock", Vector3.new(math.random(6, 14), h, math.random(6, 14)),
			"Medium stone grey", Enum.Material.Rock, Vector3.new(x, h / 2, z), folder)
		r.CFrame = r.CFrame * CFrame.Angles(
			math.random(-15, 15) * math.pi / 180,
			math.random(0, 360)  * math.pi / 180,
			math.random(-15, 15) * math.pi / 180
		)
	end

	-- Tall grass patches
	for _ = 1, 25 do
		local x = math.random(-270, 270)
		local z = math.random(-270, 270)
		if math.sqrt(x*x + z*z) > 70 then
			local h = math.random(3, 7)
			makePart("TallGrass", Vector3.new(math.random(4, 8), h, math.random(4, 8)),
				"Bright green", Enum.Material.Grass, Vector3.new(x, h/2, z), folder,
				{ CanCollide = false })
		end
	end

	-- Flowers (small colourful spheres near ground)
	local flowerColors = { "Bright yellow", "Hot pink", "White", "Bright violet", "Bright red" }
	for _ = 1, 35 do
		local x = math.random(-270, 270)
		local z = math.random(-270, 270)
		local col = flowerColors[math.random(1, #flowerColors)]
		local fl = makePart("Flower", Vector3.new(1.5, 1.5, 1.5), col,
			Enum.Material.SmoothPlastic, Vector3.new(x, 0.75, z), folder,
			{ CanCollide = false })
		fl.Shape = Enum.PartType.Ball
	end

	-- Spawn pads (one per insect type) — inside safe zone
	local spawnColors = {
		Ant = "Really black", Beetle = "Reddish brown",
		Butterfly = "Bright yellow", Bee = "Bright orange", Spider = "Dark orange",
	}
	local spawnOffsets = {
		Ant       = Vector3.new(-26, 0,   0),
		Beetle    = Vector3.new( 26, 0,   0),
		Butterfly = Vector3.new(  0, 0, -26),
		Bee       = Vector3.new(  0, 0,  26),
		Spider    = Vector3.new(-18, 0,  18),
	}
	for insectType, offset in pairs(spawnOffsets) do
		local pad = makePart("SpawnPad_" .. insectType, Vector3.new(16, 1, 16),
			spawnColors[insectType], Enum.Material.Neon,
			Vector3.new(0, 1, 0) + offset, folder, { Transparency = 0.35 })
		local sg  = Instance.new("SurfaceGui")
		sg.Face   = Enum.NormalId.Top
		sg.Parent = pad
		local lbl = Instance.new("TextLabel")
		lbl.Size  = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text  = insectType
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextScaled = true
		lbl.Font  = Enum.Font.GothamBold
		lbl.Parent = sg
	end
end

-- ─────────────────────────────────────────
-- Zone 2: Wetland  (center 800, 0)
-- ─────────────────────────────────────────
local function buildWetland()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Wetland"
	folder.Parent = workspace

	local cx, cz = 800, 0

	makePart("Ground", Vector3.new(600, 4, 600), "Dark green",
		Enum.Material.Mud, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 300, 300, 40, folder)

	-- Central pond (larger)
	makePart("Pond", Vector3.new(160, 1, 160), "Bright blue",
		Enum.Material.Water, Vector3.new(cx, -0.5, cz), folder, { Transparency = 0.25 })

	-- Smaller side pools
	for _, off in ipairs({ {-130, -100}, {120, 80}, {-80, 130} }) do
		makePart("Pool", Vector3.new(50, 0.8, 50), "Bright blue",
			Enum.Material.Water, Vector3.new(cx + off[1], -0.5, cz + off[2]), folder,
			{ Transparency = 0.3, Shape = Enum.PartType.Ball })
	end

	-- Reeds / tall grass clusters
	for _ = 1, 40 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 80 then
			local h = math.random(6, 16)
			makePart("Reed", Vector3.new(math.random(2, 4), h, math.random(2, 4)),
				"Bright green", Enum.Material.Grass, Vector3.new(x, h / 2, z), folder)
		end
	end

	-- Lily pads on pond surface
	for _ = 1, 20 do
		local px = cx + math.random(-60, 60)
		local pz = cz + math.random(-60, 60)
		local lp = makePart("LilyPad",
			Vector3.new(math.random(5, 12), 0.4, math.random(5, 12)),
			"Bright green", Enum.Material.SmoothPlastic, Vector3.new(px, 0.25, pz), folder)
		lp.Shape  = Enum.PartType.Cylinder
		lp.CFrame = lp.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end

	-- Mossy rocks
	for _ = 1, 14 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		local h = math.random(3, 8)
		makePart("Rock", Vector3.new(math.random(4, 12), h, math.random(4, 12)),
			"Sand blue", Enum.Material.Rock, Vector3.new(x, h / 2, z), folder)
	end

	-- Mangrove-style roots (vertical sticks around pond edge)
	for _ = 1, 18 do
		local angle = math.random() * math.pi * 2
		local dist  = math.random(75, 95)
		local rx    = cx + math.cos(angle) * dist
		local rz    = cz + math.sin(angle) * dist
		local h     = math.random(4, 10)
		makePart("MangroveRoot", Vector3.new(1.5, h, 1.5), "Reddish brown",
			Enum.Material.Wood, Vector3.new(rx, h / 2, rz), folder)
	end
end

-- ─────────────────────────────────────────
-- Zone 3: Mushroom Hollow  (center 1600, 0)
-- ─────────────────────────────────────────
local function buildMushroom()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Mushroom"
	folder.Parent = workspace

	local cx, cz = 1600, 0

	makePart("Ground", Vector3.new(600, 4, 600), "Dark grey",
		Enum.Material.Rock, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 300, 300, 40, folder)

	-- Glowing mushrooms (large variety)
	local mushroomColors = { "Bright violet", "Hot pink", "Bright blue", "Bright orange", "Cyan" }
	for _ = 1, 40 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 75 then
			local h    = math.random(6, 20)
			local col  = mushroomColors[math.random(1, #mushroomColors)]
			local stemW = math.random(2, 5)
			makePart("Stem", Vector3.new(stemW, h, stemW), "White",
				Enum.Material.SmoothPlastic, Vector3.new(x, h / 2, z), folder)
			local capW = math.random(10, 24)
			local cap  = makePart("Cap", Vector3.new(capW, 4, capW),
				col, Enum.Material.Neon, Vector3.new(x, h + 1.8, z), folder,
				{ Transparency = 0.15 })
			cap.Shape  = Enum.PartType.Cylinder
			cap.CFrame = cap.CFrame * CFrame.Angles(0, 0, math.pi / 2)

			-- Glow underneath cap
			local glow = makePart("CapGlow", Vector3.new(capW - 2, 0.5, capW - 2),
				col, Enum.Material.Neon, Vector3.new(x, h - 0.2, z), folder,
				{ Transparency = 0.5, CanCollide = false })
			glow.Shape  = Enum.PartType.Cylinder
			glow.CFrame = glow.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	-- Spore patches
	for _ = 1, 30 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		local col = mushroomColors[math.random(1, #mushroomColors)]
		local sp = makePart("Spore", Vector3.new(math.random(2, 5), math.random(2, 5), math.random(2, 5)),
			col, Enum.Material.Neon, Vector3.new(x, 2, z), folder,
			{ Transparency = 0.55, CanCollide = false })
		sp.Shape = Enum.PartType.Ball
	end

	-- Rocky outcrops
	for _ = 1, 10 do
		local x = cx + math.random(-260, 260)
		local z = cz + math.random(-260, 260)
		local h = math.random(4, 12)
		makePart("Outcrop", Vector3.new(math.random(6, 16), h, math.random(6, 16)),
			"Dark grey", Enum.Material.Rock, Vector3.new(x, h/2, z), folder)
	end
end

-- ─────────────────────────────────────────
-- Zone 4: Volcanic Cavern  (center 0, 800)
-- ─────────────────────────────────────────
local function buildVolcanic()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Volcanic"
	folder.Parent = workspace

	local cx, cz = 0, 800

	makePart("Ground", Vector3.new(600, 4, 600), "Dark orange",
		Enum.Material.Rock, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 300, 300, 40, folder)

	-- Lava rivers (longer, wider in a larger zone)
	for _, riverDef in ipairs({
		{ pos = Vector3.new(cx - 120, 0, cz), size = Vector3.new(30, 0.5, 550) },
		{ pos = Vector3.new(cx + 120, 0, cz), size = Vector3.new(30, 0.5, 550) },
		{ pos = Vector3.new(cx, 0, cz - 120), size = Vector3.new(550, 0.5, 30) },
		{ pos = Vector3.new(cx, 0, cz + 120), size = Vector3.new(550, 0.5, 30) },
	}) do
		makePart("LavaRiver", riverDef.size, "Bright orange",
			Enum.Material.Neon, riverDef.pos, folder, { Transparency = 0.25, CanCollide = false })
	end

	-- Lava pools
	for _, off in ipairs({ {-80,-80}, {80,80}, {-80,80}, {80,-80} }) do
		local lp = makePart("LavaPool", Vector3.new(50, 0.5, 50), "Bright orange",
			Enum.Material.Neon, Vector3.new(cx + off[1], 0, cz + off[2]), folder,
			{ Transparency = 0.2, CanCollide = false })
		lp.Shape = Enum.PartType.Ball
	end

	-- Volcanic rock pillars
	for _ = 1, 35 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 80 then
			local h = math.random(6, 24)
			local r = makePart("VolcRock",
				Vector3.new(math.random(5, 14), h, math.random(5, 14)),
				"Black", Enum.Material.Rock, Vector3.new(x, h / 2, z), folder)
			r.CFrame = r.CFrame * CFrame.Angles(
				math.random(-12, 12) * math.pi / 180, 0,
				math.random(-12, 12) * math.pi / 180
			)
		end
	end

	-- Ember glow orbs
	for _ = 1, 25 do
		local x = cx + math.random(-260, 260)
		local z = cz + math.random(-260, 260)
		local col = math.random() > 0.5 and "Bright red" or "Bright orange"
		local fp = makePart("EmberGlow", Vector3.new(math.random(2, 4), math.random(2, 4), math.random(2, 4)),
			col, Enum.Material.Neon, Vector3.new(x, math.random(4, 14), z), folder,
			{ Transparency = 0.45, CanCollide = false })
		fp.Shape = Enum.PartType.Ball
	end

	-- Dark obsidian spires
	for _ = 1, 12 do
		local x = cx + math.random(-270, 270)
		local z = cz + math.random(-270, 270)
		local h = math.random(12, 30)
		local sp = makePart("Spire", Vector3.new(math.random(3, 7), h, math.random(3, 7)),
			"Black", Enum.Material.SmoothPlastic, Vector3.new(x, h/2, z), folder)
		sp.CFrame = sp.CFrame * CFrame.Angles(
			math.random(-8, 8) * math.pi / 180, 0,
			math.random(-8, 8) * math.pi / 180
		)
	end
end

-- ─────────────────────────────────────────
-- Zone 5: Crystal Abyss  (center 800, 800)
-- ─────────────────────────────────────────
local function buildCrystal()
	local folder = Instance.new("Folder")
	folder.Name  = "Zone_Crystal"
	folder.Parent = workspace

	local cx, cz = 800, 800

	makePart("Ground", Vector3.new(600, 4, 600), "Black",
		Enum.Material.SmoothPlastic, Vector3.new(cx, -2, cz), folder)

	makeWalls(cx, cz, 300, 300, 40, folder)

	-- Crystal pillars (many, tall)
	for _ = 1, 45 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		if math.sqrt((x - cx)^2 + (z - cz)^2) > 80 then
			local h   = math.random(10, 30)
			local w   = math.random(3, 8)
			local col = math.random() > 0.5 and "Bright blue" or "Bright violet"
			local crys = makePart("Crystal", Vector3.new(w, h, w),
				col, Enum.Material.Neon, Vector3.new(x, h / 2, z), folder,
				{ Transparency = 0.25 })
			crys.CFrame = crys.CFrame * CFrame.Angles(
				math.random(-25, 25) * math.pi / 180,
				math.random(0, 360)  * math.pi / 180,
				math.random(-25, 25) * math.pi / 180
			)
		end
	end

	-- Void rifts (large dark pulsing spheres)
	for _ = 1, 16 do
		local x = cx + math.random(-260, 260)
		local z = cz + math.random(-260, 260)
		local sz = math.random(4, 9)
		local vr = makePart("VoidRift", Vector3.new(sz, sz, sz), "Dark indigo",
			Enum.Material.Neon, Vector3.new(x, sz / 2 + 1, z), folder,
			{ Transparency = 0.65, CanCollide = false })
		vr.Shape = Enum.PartType.Ball
	end

	-- Crystal floor shards
	for _ = 1, 50 do
		local x = cx + math.random(-280, 280)
		local z = cz + math.random(-280, 280)
		local col = math.random() > 0.5 and "Cyan" or "Bright violet"
		local sh  = makePart("Shard",
			Vector3.new(math.random(2, 6), 0.5, math.random(2, 6)),
			col, Enum.Material.Neon, Vector3.new(x, 0.25, z), folder,
			{ Transparency = 0.35 })
		sh.CFrame = sh.CFrame * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	end

	-- Floating crystal clusters (mid-air)
	for _ = 1, 10 do
		local x = cx + math.random(-200, 200)
		local z = cz + math.random(-200, 200)
		local y = math.random(15, 35)
		local sz = math.random(3, 8)
		local col = math.random() > 0.5 and "Bright blue" or "Cyan"
		local fc = makePart("FloatingCrystal", Vector3.new(sz, sz * 2, sz),
			col, Enum.Material.Neon, Vector3.new(x, y, z), folder,
			{ Transparency = 0.2, CanCollide = false })
		fc.CFrame = fc.CFrame * CFrame.Angles(
			math.random(-45, 45) * math.pi / 180,
			math.random(0, 360)  * math.pi / 180,
			0
		)
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
Lighting.FogEnd         = 2000
Lighting.FogStart       = 1000

print("[InsectEvo] MapBuilder: all 5 zones built (600×600 studs each).")
