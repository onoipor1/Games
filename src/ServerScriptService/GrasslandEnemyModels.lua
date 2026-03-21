-- GrasslandEnemyModels.lua
-- Procedural Part-based enemy models for the Grassland zone.
-- GrasslandEnemyModels.Build(def, mobLevel) → model, body, hpBar, parts
--
-- 'parts' is { {part=Part, offset=CFrame}, ... } relative to body (HumanoidRootPart).
-- EnemyManager updates each part every heartbeat:  part.CFrame = body.CFrame * offset
--
-- Models:  Aphid, Earwig, Grasshopper (Normal)
--          AlphaEarwig, GiantAphid    (Elite)
--          MantisOverlord             (Boss)

local GrasslandEnemyModels = {}

-- ─────────────────────────────────────────
-- Shared helpers
-- ─────────────────────────────────────────

local SP = Enum.Material.SmoothPlastic
local NE = Enum.Material.Neon
local FA = Enum.Material.Fabric

local function addPart(model, parts, offset, size, color, mat, shape, tr)
	local p          = Instance.new("Part")
	p.Size           = size
	p.Color          = color
	p.Material       = mat or SP
	p.Transparency   = tr or 0
	p.Anchored       = true
	p.CanCollide     = false
	p.CastShadow     = false
	if shape == "Ball" then p.Shape = Enum.PartType.Ball
	elseif shape == "Cyl" then p.Shape = Enum.PartType.Cylinder end
	p.Parent = model
	table.insert(parts, { part = p, offset = offset })
	return p
end

-- Rod from localA to localB.
-- CFrame.new(mid, localA) makes the part's -Z face localA,
-- so the block's Z-length fills exactly from localA to localB.
local function addRod(model, parts, localA, localB, radius, color, mat)
	local len = (localB - localA).Magnitude
	if len < 0.05 then return end
	local mid    = (localA + localB) * 0.5
	local offset = CFrame.new(mid, localA)   -- -Z toward A, +Z toward B
	addPart(model, parts, offset,
		Vector3.new(radius * 2, radius * 2, len),
		color, mat or SP)
end

-- ─────────────────────────────────────────
-- Billboard (same layout as buildEnemyModel)
-- ─────────────────────────────────────────

local function buildBillboard(body, def, mobLevel, bbHeight)
	local isElite = def.tier == "Elite"
	local isBoss  = def.tier == "Boss"

	local bb            = Instance.new("BillboardGui")
	bb.Name             = "EnemyBB"
	bb.Size             = UDim2.new(0, isBoss and 180 or 120, 0, isBoss and 32 or 22)
	bb.StudsOffset      = Vector3.new(0, bbHeight + 0.5, 0)
	bb.AlwaysOnTop      = false
	bb.MaxDistance      = 80
	bb.Parent           = body

	local bg                     = Instance.new("Frame")
	bg.Size                      = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3          = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency    = 0.4
	bg.BorderSizePixel           = 0
	bg.Parent                    = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

	local hpBar                  = Instance.new("Frame")
	hpBar.Name                   = "HPBar"
	hpBar.Size                   = UDim2.new(1, 0, 0.4, 0)
	hpBar.Position               = UDim2.new(0, 0, 0.6, 0)
	hpBar.BackgroundColor3       = isBoss
		and Color3.fromRGB(220, 30, 30)
		or (isElite and Color3.fromRGB(220, 160, 20) or Color3.fromRGB(80, 200, 80))
	hpBar.BorderSizePixel        = 0
	hpBar.Parent                 = bg
	Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 2)

	local nameLabel              = Instance.new("TextLabel")
	nameLabel.Name               = "NameLabel"
	nameLabel.Size               = UDim2.new(1, -4, 0.6, 0)
	nameLabel.Position           = UDim2.new(0, 2, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text               = (isBoss and "💀 " or isElite and "⭐ " or "")
		.. def.displayName .. "  [Lv." .. (mobLevel or "?") .. "]"
	nameLabel.TextColor3         = isBoss and Color3.fromRGB(255, 100, 100)
		or (isElite and Color3.fromRGB(255, 210, 60) or Color3.new(1, 1, 1))
	nameLabel.Font               = Enum.Font.GothamBold
	nameLabel.TextScaled         = true
	nameLabel.Parent             = bg

	return hpBar
end

-- ─────────────────────────────────────────
-- Elite extras (crown orb + aura ring)
-- ─────────────────────────────────────────

local function addEliteExtras(model, parts, def, r)
	-- Gold crown ball on top
	addPart(model, parts,
		CFrame.new(0, r * 1.5, 0),
		Vector3.new(r * 0.38, r * 0.38, r * 0.38),
		Color3.fromRGB(255, 215, 40), NE, "Ball")
	-- Aura ring (horizontal cylinder)
	addPart(model, parts,
		CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.28, r * 2.8, r * 2.8),
		def.eliteAura or def.accentColor, NE, "Cyl", 0.55)
end

-- ─────────────────────────────────────────
-- Boss OrbCore (animated by EnemyManager)
-- ─────────────────────────────────────────

local function addBossOrb(model, def, r)
	local orb        = Instance.new("Part")
	orb.Name         = "OrbCore"
	orb.Shape        = Enum.PartType.Ball
	orb.Size         = Vector3.new(r * 0.5, r * 0.5, r * 0.5)
	orb.Material     = NE
	orb.Color        = def.accentColor
	orb.Transparency = 0.2
	orb.Anchored     = true
	orb.CanCollide   = false
	orb.CastShadow   = false
	orb.Parent       = model
	-- OrbCore is NOT in parts table; EnemyManager animates it directly by name
end

-- ─────────────────────────────────────────
-- APHID  (Normal + GiantAphid Elite)
-- Plump green sap-sucker with cornicles
-- ─────────────────────────────────────────

local function buildAphid(def, mobLevel)
	local r        = def.size * 2
	local green    = def.bodyColor    -- 120,210,80 / 60,180,40
	local darkGrn  = def.accentColor  -- 80,160,40 / 180,255,100
	local isElite  = def.tier == "Elite"

	local model    = Instance.new("Model")
	model.Name     = "Enemy_" .. def.key
	local parts    = {}

	-- ── Body (PRIMARY) ─ plump oval, front half acts as head ──
	local body     = Instance.new("Part")
	body.Name      = "HumanoidRootPart"
	body.Shape     = Enum.PartType.Ball
	body.Size      = Vector3.new(r * 1.3, r * 1.1, r * 1.5)
	body.Color     = green
	body.Material  = SP
	body.Anchored  = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent    = model
	model.PrimaryPart = body

	-- Abdomen (larger ball behind, darker)
	addPart(model, parts,
		CFrame.new(0, -r*0.08, r * 1.45),
		Vector3.new(r * 1.55, r * 1.35, r * 1.65),
		Color3.fromRGB(75, 165, 40), SP, "Ball")

	-- Abdomen highlight stripe (dark band across mid)
	addPart(model, parts,
		CFrame.new(0, r*0.62, r * 1.45),
		Vector3.new(r*1.58, r*0.12, r*1.6),
		Color3.fromRGB(50, 120, 20), SP)

	-- Compound eyes (neon, on front-sides)
	local eyeCol = isElite and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(30, 220, 30)
	addPart(model, parts,
		CFrame.new( r*0.38,  r*0.22, -r*0.58),
		Vector3.new(r*0.3, r*0.26, r*0.28), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.38,  r*0.22, -r*0.58),
		Vector3.new(r*0.3, r*0.26, r*0.28), eyeCol, NE, "Ball")

	-- 6 stubby legs (3 per side, near-horizontal)
	local legCol = Color3.fromRGB(55, 130, 25)
	for side = 1, 2 do
		local sx = (side == 1) and 1 or -1
		for i = 1, 3 do
			local zo  = (i - 2) * r * 0.5
			local frm = Vector3.new(sx * r*0.58, -r*0.12, zo)
			local too = Vector3.new(sx * r*1.35, -r*0.65, zo + sx*0.05)
			addRod(model, parts, frm, too, r*0.075, legCol)
		end
	end

	-- Antennae (2-segment, club tips)
	local antCol = Color3.fromRGB(45, 120, 20)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.18, r*0.32, -r*0.66)
		local mid = Vector3.new(sx*r*0.52, r*0.88, -r*1.08)
		local tip = Vector3.new(sx*r*0.72, r*1.28, -r*1.32)
		addRod(model, parts, bas, mid, r*0.065, antCol)
		addRod(model, parts, mid, tip, r*0.05,  antCol)
		-- Club tip ball
		addPart(model, parts,
			CFrame.new(tip),
			Vector3.new(r*0.15, r*0.15, r*0.15), antCol, SP, "Ball")
	end

	-- Cornicles (2 small exhaust tubes on abdomen tip)
	local cornCol = Color3.fromRGB(45, 110, 18)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.28, r*0.18, r*2.05)
		local tip = Vector3.new(sx*r*0.33, r*0.72, r*2.55)
		addRod(model, parts, bas, tip, r*0.09, cornCol)
		addPart(model, parts, CFrame.new(tip),
			Vector3.new(r*0.14, r*0.14, r*0.14), cornCol, SP, "Ball")
	end

	if isElite then addEliteExtras(model, parts, def, r) end

	local hpBar = buildBillboard(body, def, mobLevel, r * 1.6)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- EARWIG  (Normal + AlphaEarwig Elite)
-- Brown, elongated, iconic cerci pincers
-- ─────────────────────────────────────────

local function buildEarwig(def, mobLevel)
	local r       = def.size * 2
	local brown   = def.bodyColor    -- 100,55,20 / 80,40,10
	local isElite = def.tier == "Elite"

	local model   = Instance.new("Model")
	model.Name    = "Enemy_" .. def.key
	local parts   = {}

	-- ── Thorax (PRIMARY) ──────────────────────────────────────
	local body    = Instance.new("Part")
	body.Name     = "HumanoidRootPart"
	body.Size     = Vector3.new(r*0.95, r*0.68, r*1.35)
	body.Color    = brown
	body.Material = SP
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent   = model
	model.PrimaryPart = body

	-- Head (front)
	addPart(model, parts,
		CFrame.new(0, r*0.05, -r*1.02),
		Vector3.new(r*0.8, r*0.7, r*0.75), brown, SP, "Ball")

	-- Pronotum shield (flat saddle on thorax top)
	addPart(model, parts,
		CFrame.new(0, r*0.38, 0),
		Vector3.new(r*1.0, r*0.12, r*1.0),
		Color3.fromRGB(80, 40, 10), SP)

	-- Abdomen (elongated oval, segmented)
	addPart(model, parts,
		CFrame.new(0, -r*0.06, r*1.38),
		Vector3.new(r*0.8, r*0.65, r*1.95),
		Color3.fromRGB(65, 30, 8), SP, "Ball")

	-- Abdomen segment seam lines (2 dark rings)
	for i = 1, 2 do
		addPart(model, parts,
			CFrame.new(0, r*0.3, r*(0.9 + i*0.5)),
			Vector3.new(r*0.82, r*0.09, r*0.22),
			Color3.fromRGB(40, 18, 4), SP)
	end

	-- Eyes (neon, on head sides)
	local eyeCol = isElite and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(210, 110, 20)
	addPart(model, parts,
		CFrame.new( r*0.32, r*0.18, -r*1.0),
		Vector3.new(r*0.22, r*0.22, r*0.2), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.32, r*0.18, -r*1.0),
		Vector3.new(r*0.22, r*0.22, r*0.2), eyeCol, NE, "Ball")

	-- 6 legs (3 per side, splayed horizontally)
	local legCol = Color3.fromRGB(65, 35, 10)
	for side = 1, 2 do
		local sx = (side == 1) and 1 or -1
		for i = 1, 3 do
			local zo  = (i - 2) * r * 0.55
			local frm = Vector3.new(sx*r*0.48, 0, zo)
			local too = Vector3.new(sx*r*1.55, -r*0.58, zo)
			addRod(model, parts, frm, too, r*0.085, legCol)
		end
	end

	-- Antennae (2 segments each, long and beaded)
	local antCol = Color3.fromRGB(55, 28, 8)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.22, r*0.22, -r*1.0)
		local mid = Vector3.new(sx*r*0.48, r*0.55, -r*1.65)
		local tip = Vector3.new(sx*r*0.68, r*0.78, -r*2.35)
		addRod(model, parts, bas, mid, r*0.07, antCol)
		addRod(model, parts, mid, tip, r*0.055, antCol)
	end

	-- Cerci pincers (iconic earwig feature — curved forceps at tail)
	local cerciCol = isElite
		and Color3.fromRGB(200, 160, 20)    -- gold for elite
		or  Color3.fromRGB(55, 28, 8)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		-- Base: exits abdomen tip angled outward
		local bas = Vector3.new(sx*r*0.14, r*0.08, r*2.3)
		local mid = Vector3.new(sx*r*0.52, r*0.42, r*2.72)
		-- Tip: curves back inward (crab-claw motion)
		local tip = Vector3.new(sx*r*0.22, r*0.14, r*2.95)
		addRod(model, parts, bas, mid, r*0.11, cerciCol)
		addRod(model, parts, mid, tip, r*0.10, cerciCol)
	end

	if isElite then addEliteExtras(model, parts, def, r) end

	local hpBar = buildBillboard(body, def, mobLevel, r * 1.4)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- GRASSHOPPER  (Normal, charge attacker)
-- Green, huge hind legs, tegmina wing covers
-- ─────────────────────────────────────────

local function buildGrasshopper(def, mobLevel)
	local r       = def.size * 2
	local green   = def.bodyColor    -- 80,180,40
	local ltGreen = def.accentColor  -- 140,220,80

	local model   = Instance.new("Model")
	model.Name    = "Enemy_" .. def.key
	local parts   = {}

	-- ── Thorax (PRIMARY) ──────────────────────────────────────
	local body    = Instance.new("Part")
	body.Name     = "HumanoidRootPart"
	body.Size     = Vector3.new(r*1.05, r*0.95, r*1.5)
	body.Color    = green
	body.Material = SP
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent   = model
	model.PrimaryPart = body

	-- Pronotum saddle (distinctive grasshopper neck-shield)
	addPart(model, parts,
		CFrame.new(0, r*0.52, -r*0.35),
		Vector3.new(r*1.1, r*0.14, r*1.1),
		Color3.fromRGB(55, 150, 25), SP)

	-- Head (large, front, slightly upward tilt)
	addPart(model, parts,
		CFrame.new(0, r*0.22, -r*1.18),
		Vector3.new(r*1.05, r*1.0, r*0.9), green, SP, "Ball")

	-- Abdomen (long, tapered, behind thorax)
	addPart(model, parts,
		CFrame.new(0, -r*0.08, r*1.65),
		Vector3.new(r*0.9, r*0.78, r*2.35),
		Color3.fromRGB(55, 150, 22), SP, "Ball")

	-- Abdomen stripe (dark dorsal line)
	addPart(model, parts,
		CFrame.new(0, r*0.38, r*1.65),
		Vector3.new(r*0.92, r*0.11, r*2.2),
		Color3.fromRGB(28, 95, 10), SP)

	-- Large compound eyes (neon, side of head)
	local eyeCol = Color3.fromRGB(30, 210, 30)
	addPart(model, parts,
		CFrame.new( r*0.52, r*0.28, -r*1.08),
		Vector3.new(r*0.42, r*0.44, r*0.34), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.52, r*0.28, -r*1.08),
		Vector3.new(r*0.42, r*0.44, r*0.34), eyeCol, NE, "Ball")

	-- Tegmina (wing covers) flat on back, slightly angled
	local wingCol = Color3.fromRGB(55, 155, 22)
	addPart(model, parts,
		CFrame.new( r*0.32, r*0.52, r*0.65) * CFrame.Angles(0, 0, math.rad(-8)),
		Vector3.new(r*0.62, r*0.07, r*2.1), wingCol, SP)
	addPart(model, parts,
		CFrame.new(-r*0.32, r*0.52, r*0.65) * CFrame.Angles(0, 0, math.rad(8)),
		Vector3.new(r*0.62, r*0.07, r*2.1), wingCol, SP)

	-- 4 front walking legs (2 per side, short)
	local legCol = Color3.fromRGB(38, 125, 15)
	for side = 1, 2 do
		local sx = (side == 1) and 1 or -1
		for i = 1, 2 do
			local zo  = (i == 1) and -r*0.38 or r*0.22
			local frm = Vector3.new(sx*r*0.52, -r*0.1, zo)
			local too = Vector3.new(sx*r*1.5,  -r*0.75, zo)
			addRod(model, parts, frm, too, r*0.09, legCol)
		end
	end

	-- 2 massive hind legs (femur + tibia, classic grasshopper L-bend)
	local hindCol = Color3.fromRGB(38, 125, 15)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		-- Femur (large, goes up-back from hip)
		local hip   = Vector3.new(sx*r*0.52,  r*0.12, r*0.68)
		local knee  = Vector3.new(sx*r*1.22,  r*1.08, r*1.85)
		addRod(model, parts, hip, knee, r*0.2, hindCol)
		-- Tibia (long, drops steeply down-back from knee)
		local foot  = Vector3.new(sx*r*0.85, -r*1.0,  r*3.0)
		addRod(model, parts, knee, foot, r*0.14, hindCol)
		-- Tarsus (tiny foot pad)
		addPart(model, parts, CFrame.new(foot),
			Vector3.new(r*0.2, r*0.1, r*0.35), hindCol, SP)
	end

	-- Antennae (long filiform, 2 segments)
	local antCol = Color3.fromRGB(30, 110, 12)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.22, r*0.46, -r*1.18)
		local mid = Vector3.new(sx*r*0.52, r*1.08, -r*1.78)
		local tip = Vector3.new(sx*r*0.72, r*1.72, -r*2.55)
		addRod(model, parts, bas, mid, r*0.065, antCol)
		addRod(model, parts, mid, tip, r*0.05,  antCol)
	end

	local hpBar = buildBillboard(body, def, mobLevel, r * 1.5)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- MANTIS OVERLORD  (Boss, 3-phase)
-- Raptorial forelegs, wings, multi-segment abdomen
-- ─────────────────────────────────────────

local function buildMantisOverlord(def, mobLevel)
	local r         = def.size * 2        -- r = 6.0
	local dkGreen   = def.bodyColor       -- 40,140,30
	local redAcc    = def.accentColor     -- 200,50,50

	local model     = Instance.new("Model")
	model.Name      = "Enemy_" .. def.key
	local parts     = {}

	-- ── Prothorax (PRIMARY) — tall upright slab ──────────────
	local body      = Instance.new("Part")
	body.Name       = "HumanoidRootPart"
	body.Size       = Vector3.new(r*0.85, r*1.5, r*0.95)
	body.Color      = dkGreen
	body.Material   = NE
	body.Anchored   = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent     = model
	model.PrimaryPart = body

	-- ── Head (triangular-ish, tilted forward on top of prothorax) ──
	addPart(model, parts,
		CFrame.new(0, r*0.92, -r*0.55),
		Vector3.new(r*0.9, r*0.72, r*0.68),
		Color3.fromRGB(28, 110, 20), NE, "Ball")

	-- Giant compound eyes (boss neon red)
	local eyeCol = Color3.fromRGB(255, 40, 40)
	addPart(model, parts,
		CFrame.new( r*0.46, r*0.96, -r*0.64),
		Vector3.new(r*0.46, r*0.46, r*0.36), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.46, r*0.96, -r*0.64),
		Vector3.new(r*0.46, r*0.46, r*0.36), eyeCol, NE, "Ball")

	-- Mesothorax + Metathorax (lower body, wider)
	addPart(model, parts,
		CFrame.new(0, -r*0.55, r*0.12),
		Vector3.new(r*1.05, r*0.85, r*1.2),
		Color3.fromRGB(32, 118, 22), SP)

	-- Abdomen (4 tapering segments)
	local abdZ     = { r*1.0, r*1.95, r*2.75, r*3.45 }
	local abdScale = { 1.0,   0.86,   0.70,   0.52   }
	local abdCol   = {
		Color3.fromRGB(36, 125, 26),
		Color3.fromRGB(30, 112, 20),
		Color3.fromRGB(25,  98, 17),
		Color3.fromRGB(20,  82, 14),
	}
	for i, zo in ipairs(abdZ) do
		local s = abdScale[i]
		addPart(model, parts,
			CFrame.new(0, -r*0.42, zo),
			Vector3.new(r*s, r*s*0.78, r*0.76),
			abdCol[i], SP, "Ball")
	end

	-- Wing covers (folded, flat panels on back)
	local wingCol = Color3.fromRGB(48, 175, 38)
	addPart(model, parts,
		CFrame.new( r*0.58, r*0.12, r*1.1) * CFrame.Angles(0, 0, math.rad(-12)),
		Vector3.new(r*0.92, r*0.06, r*2.8), wingCol, SP)
	addPart(model, parts,
		CFrame.new(-r*0.58, r*0.12, r*1.1) * CFrame.Angles(0, 0, math.rad(12)),
		Vector3.new(r*0.92, r*0.06, r*2.8), wingCol, SP)

	-- 4 walking legs (2 per side on meso/metathorax)
	local legCol = Color3.fromRGB(22, 95, 15)
	for side = 1, 2 do
		local sx = (side == 1) and 1 or -1
		for li = 1, 2 do
			local zo  = (li == 1) and r*0.12 or r*0.95
			local frm = Vector3.new(sx*r*0.52, -r*0.52, zo)
			local too = Vector3.new(sx*r*1.75, -r*1.55, zo + sx*0.08)
			addRod(model, parts, frm, too, r*0.15, legCol)
		end
	end

	-- ── Raptorial forelegs (iconic mantis arms, one per side) ──
	-- Upper arm (coxa→femur): rises diagonally upward-forward
	-- Lower arm (femur→tibia): folds sharply inward-down (ready to strike)
	local foreCol  = Color3.fromRGB(42, 140, 28)
	local spikeCol = Color3.fromRGB(210, 45, 45)
	for side = 1, 2 do
		local sx      = (side == 1) and 1 or -1
		local shoulder = Vector3.new(sx*r*0.42,  r*0.52, -r*0.55)
		local elbow    = Vector3.new(sx*r*1.3,   r*1.6,  -r*1.35)
		local wrist    = Vector3.new(sx*r*0.65,  r*0.72, -r*1.95)

		-- Upper arm
		addRod(model, parts, shoulder, elbow, r*0.2,  foreCol)
		-- Lower arm (tibia)
		addRod(model, parts, elbow,    wrist,  r*0.16, foreCol)

		-- Spines on inner tibia edge (2 small spines)
		local sp1A = Vector3.new(sx*r*1.08, r*1.22, -r*1.55)
		local sp1B = Vector3.new(sx*r*0.78, r*0.95, -r*1.62)
		addRod(model, parts, sp1A, sp1B, r*0.07, spikeCol)

		local sp2A = Vector3.new(sx*r*0.88, r*0.98, -r*1.78)
		local sp2B = Vector3.new(sx*r*0.60, r*0.74, -r*1.84)
		addRod(model, parts, sp2A, sp2B, r*0.07, spikeCol)

		-- Claw tip
		addPart(model, parts, CFrame.new(wrist),
			Vector3.new(r*0.2, r*0.2, r*0.2), spikeCol, NE, "Ball")
	end

	-- Antennae (filiform, 2 segments each)
	local antCol = Color3.fromRGB(22, 95, 15)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.22, r*1.08, -r*0.72)
		local mid = Vector3.new(sx*r*0.55, r*1.85, -r*1.38)
		local tip = Vector3.new(sx*r*0.78, r*2.62, -r*2.15)
		addRod(model, parts, bas, mid, r*0.08, antCol)
		addRod(model, parts, mid, tip, r*0.06, antCol)
	end

	-- OrbCore (animated by EnemyManager heartbeat, not in parts table)
	addBossOrb(model, def, r)

	local hpBar = buildBillboard(body, def, mobLevel, r * 2.0)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- Dispatch
-- ─────────────────────────────────────────

function GrasslandEnemyModels.Build(def, mobLevel)
	local k = def.key
	if k == "Aphid" or k == "GiantAphid" then
		return buildAphid(def, mobLevel)
	elseif k == "Earwig" or k == "AlphaEarwig" then
		return buildEarwig(def, mobLevel)
	elseif k == "Grasshopper" then
		return buildGrasshopper(def, mobLevel)
	elseif k == "MantisOverlord" then
		return buildMantisOverlord(def, mobLevel)
	end
	-- Fallback: shouldn't occur for valid Grassland enemies
	return nil
end

return GrasslandEnemyModels
