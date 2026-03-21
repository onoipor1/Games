-- WetlandEnemyModels.lua
-- Procedural Part-based enemy models for the Wetland zone.
-- WetlandEnemyModels.Build(def, mobLevel) → model, body, hpBar, parts
--
-- 'parts' is { {part=Part, offset=CFrame}, ... } relative to body (HumanoidRootPart).
-- EnemyManager updates each part every heartbeat:  part.CFrame = body.CFrame * offset
--
-- Models:  WaterStrider, PondLeech, DivingBeetle  (Normal)
--          ElderStrider, BloatedLeech             (Elite)
--          DragonFlyWarlord                       (Boss)

local WetlandEnemyModels = {}

-- ─────────────────────────────────────────
-- Shared helpers
-- ─────────────────────────────────────────

local SP = Enum.Material.SmoothPlastic
local NE = Enum.Material.Neon

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

-- Rod from localA to localB using CFrame.new(mid, localA) orientation.
local function addRod(model, parts, localA, localB, radius, color, mat)
	local len = (localB - localA).Magnitude
	if len < 0.05 then return end
	local mid    = (localA + localB) * 0.5
	local offset = CFrame.new(mid, localA)
	addPart(model, parts, offset,
		Vector3.new(radius * 2, radius * 2, len),
		color, mat or SP)
end

-- ─────────────────────────────────────────
-- Billboard
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
-- Elite extras
-- ─────────────────────────────────────────

local function addEliteExtras(model, parts, def, r)
	addPart(model, parts,
		CFrame.new(0, r * 1.5, 0),
		Vector3.new(r*0.38, r*0.38, r*0.38),
		Color3.fromRGB(255, 215, 40), NE, "Ball")
	addPart(model, parts,
		CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.28, r*2.8, r*2.8),
		def.eliteAura or def.accentColor, NE, "Cyl", 0.55)
end

-- ─────────────────────────────────────────
-- Boss OrbCore (EnemyManager animates by name)
-- ─────────────────────────────────────────

local function addBossOrb(model, def, r)
	local orb        = Instance.new("Part")
	orb.Name         = "OrbCore"
	orb.Shape        = Enum.PartType.Ball
	orb.Size         = Vector3.new(r*0.5, r*0.5, r*0.5)
	orb.Material     = NE
	orb.Color        = def.accentColor
	orb.Transparency = 0.2
	orb.Anchored     = true
	orb.CanCollide   = false
	orb.CastShadow   = false
	orb.Parent       = model
end

-- ─────────────────────────────────────────
-- WATER STRIDER  (Normal + ElderStrider Elite)
-- Slim body, six impossibly long splayed legs that skate on water
-- ─────────────────────────────────────────

local function buildWaterStrider(def, mobLevel)
	local r       = def.size * 2
	local blue    = def.bodyColor    -- 50,140,180 / 30,100,150
	local ltBlue  = def.accentColor  -- 100,200,230 / 180,220,255
	local isElite = def.tier == "Elite"

	local model   = Instance.new("Model")
	model.Name    = "Enemy_" .. def.key
	local parts   = {}

	-- ── Body (PRIMARY): long, slender, tapered ───────────────
	local body    = Instance.new("Part")
	body.Name     = "HumanoidRootPart"
	body.Shape    = Enum.PartType.Ball
	body.Size     = Vector3.new(r*0.72, r*0.52, r*2.3)
	body.Color    = blue
	body.Material = SP
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent   = model
	model.PrimaryPart = body

	-- Head (front nub)
	addPart(model, parts,
		CFrame.new(0, r*0.06, -r*1.28),
		Vector3.new(r*0.58, r*0.48, r*0.52), blue, SP, "Ball")

	-- Abdomen (rear, slightly wider teardrop)
	addPart(model, parts,
		CFrame.new(0, -r*0.06, r*1.45),
		Vector3.new(r*0.7, r*0.48, r*0.82),
		Color3.fromRGB(32, 108, 148), SP, "Ball")

	-- Thorax stripe (dark band in the middle)
	addPart(model, parts,
		CFrame.new(0, r*0.26, 0),
		Vector3.new(r*0.74, r*0.1, r*0.85),
		Color3.fromRGB(25, 90, 125), SP)

	-- Eyes (neon, on head sides)
	local eyeCol = isElite and Color3.fromRGB(200, 240, 255) or ltBlue
	addPart(model, parts,
		CFrame.new( r*0.22, r*0.15, -r*1.35),
		Vector3.new(r*0.2, r*0.2, r*0.18), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.22, r*0.15, -r*1.35),
		Vector3.new(r*0.2, r*0.2, r*0.18), eyeCol, NE, "Ball")

	-- ── 6 very long legs (signature water-strider silhouette) ──
	-- Front pair: shorter, angled forward-out, create the "V" shape
	-- Middle pair: longest, nearly straight sideways for skating
	-- Rear pair: long, angled backward for propulsion
	local legCol = Color3.fromRGB(25, 95, 140)
	local tipCol = Color3.fromRGB(18, 70, 105)

	-- Front legs
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local frm = Vector3.new(sx*r*0.3,  -r*0.02, -r*0.72)
		local too = Vector3.new(sx*r*2.65, -r*0.28, -r*1.15)
		addRod(model, parts, frm, too, r*0.055, legCol)
	end

	-- Middle legs (longest, hydrodynamic skating stance)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local frm = Vector3.new(sx*r*0.32,  -r*0.02, r*0.12)
		local too = Vector3.new(sx*r*3.55, -r*0.22, r*0.12)
		addRod(model, parts, frm, too, r*0.062, legCol)
		-- Foot tip (tiny ball resting "on water")
		addPart(model, parts,
			CFrame.new(too),
			Vector3.new(r*0.14, r*0.14, r*0.14), tipCol, SP, "Ball")
	end

	-- Rear legs
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local frm = Vector3.new(sx*r*0.3,  -r*0.02, r*0.95)
		local too = Vector3.new(sx*r*2.95, -r*0.25, r*1.78)
		addRod(model, parts, frm, too, r*0.055, legCol)
	end

	-- Antennae (short, thin, project forward)
	local antCol = Color3.fromRGB(22, 85, 128)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.15, r*0.18, -r*1.38)
		local tip = Vector3.new(sx*r*0.38, r*0.48, -r*1.9)
		addRod(model, parts, bas, tip, r*0.05, antCol)
	end

	if isElite then addEliteExtras(model, parts, def, r) end

	local hpBar = buildBillboard(body, def, mobLevel, r * 0.75)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- POND LEECH  (Normal + BloatedLeech Elite)
-- Segmented annelid body, oral and tail suckers
-- ─────────────────────────────────────────

local function buildPondLeech(def, mobLevel)
	local r         = def.size * 2
	local red       = def.bodyColor    -- 100,20,20 / 140,30,30
	local darkRed   = def.accentColor  -- 60,10,10  / 220,80,80
	local isElite   = def.tier == "Elite"
	local isBloated = def.key == "BloatedLeech"
	local fat       = isBloated and 1.35 or 1.0

	local model     = Instance.new("Model")
	model.Name      = "Enemy_" .. def.key
	local parts     = {}

	-- ── Body (PRIMARY): widest at center, tapers at ends ────
	local body      = Instance.new("Part")
	body.Name       = "HumanoidRootPart"
	body.Shape      = Enum.PartType.Ball
	body.Size       = Vector3.new(r*1.0*fat, r*0.82*fat, r*1.55)
	body.Color      = red
	body.Material   = SP
	body.Anchored   = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent     = model
	model.PrimaryPart = body

	-- 7 visible body segments (alternating colors, sizes peak at center)
	local halfLen   = r * 1.42
	local segWidths = { 0.55, 0.74, 0.90, 1.0, 0.90, 0.74, 0.55 }
	local segCols   = {
		Color3.fromRGB(85,  18, 18),
		Color3.fromRGB(105, 22, 22),
		Color3.fromRGB(88,  18, 18),
		Color3.fromRGB(108, 23, 23),
		Color3.fromRGB(88,  18, 18),
		Color3.fromRGB(105, 22, 22),
		Color3.fromRGB(85,  18, 18),
	}
	if isBloated then
		for i = 1, 7 do
			segCols[i] = Color3.fromRGB(
				math.min(255, segCols[i].R * 255 + 40),
				segCols[i].G * 255,
				segCols[i].B * 255)
		end
	end
	for i = 1, 7 do
		local zo = -halfLen + (i - 1) / 6 * (halfLen * 2)
		local sw = segWidths[i] * fat
		addPart(model, parts,
			CFrame.new(0, 0, zo),
			Vector3.new(r*sw, r*sw*0.85, r*0.44),
			segCols[i], SP, "Ball")
	end

	-- Oral sucker (head end, front flat disc + inner neon ring)
	local frontZ = -halfLen - r*0.28
	addPart(model, parts,
		CFrame.new(0, 0, frontZ) * CFrame.Angles(math.pi/2, 0, 0),
		Vector3.new(r*0.68*fat, r*0.22, r*0.68*fat),
		Color3.fromRGB(210, 70, 70), SP, "Cyl")
	addPart(model, parts,
		CFrame.new(0, 0, frontZ - r*0.12) * CFrame.Angles(math.pi/2, 0, 0),
		Vector3.new(r*0.34*fat, r*0.15, r*0.34*fat),
		Color3.fromRGB(255, 130, 130), NE, "Cyl")

	-- Posterior sucker (tail, slightly smaller)
	local backZ  = halfLen + r*0.28
	addPart(model, parts,
		CFrame.new(0, 0, backZ) * CFrame.Angles(math.pi/2, 0, 0),
		Vector3.new(r*0.52*fat, r*0.18, r*0.52*fat),
		Color3.fromRGB(155, 45, 45), SP, "Cyl")

	-- Eyes (two tiny neon dots just behind the oral sucker)
	local eyeCol = isBloated and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(230, 55, 55)
	addPart(model, parts,
		CFrame.new( r*0.2, r*0.3, frontZ + r*0.25),
		Vector3.new(r*0.17, r*0.17, r*0.17), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.2, r*0.3, frontZ + r*0.25),
		Vector3.new(r*0.17, r*0.17, r*0.17), eyeCol, NE, "Ball")

	if isElite then addEliteExtras(model, parts, def, r) end

	local hpBar = buildBillboard(body, def, mobLevel, r * 1.2 * fat)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- DIVING BEETLE  (Normal, charge attacker)
-- Wide oval elytra, oar-like hind legs, streamlined profile
-- ─────────────────────────────────────────

local function buildDivingBeetle(def, mobLevel)
	local r     = def.size * 2
	local navy  = def.bodyColor    -- 20,40,100
	local blue  = def.accentColor  -- 60,90,180

	local model = Instance.new("Model")
	model.Name  = "Enemy_" .. def.key
	local parts = {}

	-- ── Elytra (PRIMARY): wide, flat, very smooth oval ───────
	-- Diving beetles have the most hydrodynamic shape of any beetle
	local body  = Instance.new("Part")
	body.Name   = "HumanoidRootPart"
	body.Shape  = Enum.PartType.Ball
	body.Size   = Vector3.new(r*1.55, r*0.52, r*1.85)
	body.Color  = navy
	body.Material = SP
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent = model
	model.PrimaryPart = body

	-- Elytra center seam line
	addPart(model, parts,
		CFrame.new(0, r*0.27, r*0.15),
		Vector3.new(r*0.065, r*0.11, r*1.72),
		Color3.fromRGB(10, 22, 62), SP)

	-- Elytra blue sheen stripe along each side
	addPart(model, parts,
		CFrame.new( r*0.55, r*0.27, r*0.1),
		Vector3.new(r*0.55, r*0.07, r*1.55),
		blue, NE, nil, 0.55)
	addPart(model, parts,
		CFrame.new(-r*0.55, r*0.27, r*0.1),
		Vector3.new(r*0.55, r*0.07, r*1.55),
		blue, NE, nil, 0.55)

	-- Pronotum (trapezoidal shield between elytra and head)
	addPart(model, parts,
		CFrame.new(0, r*0.2, -r*1.1),
		Vector3.new(r*1.28, r*0.4, r*0.72),
		Color3.fromRGB(14, 30, 80), SP)

	-- Head (small, streamlined)
	addPart(model, parts,
		CFrame.new(0, r*0.04, -r*1.62),
		Vector3.new(r*0.78, r*0.6, r*0.68), navy, SP, "Ball")

	-- Compound eyes (neon blue, on sides of head)
	addPart(model, parts,
		CFrame.new( r*0.34, r*0.1, -r*1.6),
		Vector3.new(r*0.34, r*0.34, r*0.28), blue, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.34, r*0.1, -r*1.6),
		Vector3.new(r*0.34, r*0.34, r*0.28), blue, NE, "Ball")

	-- Underside (flat ventral keel for hydrodynamics)
	addPart(model, parts,
		CFrame.new(0, -r*0.3, r*0.1),
		Vector3.new(r*1.32, r*0.08, r*1.65),
		Color3.fromRGB(14, 30, 80), SP)

	-- 4 front/mid legs (thin walking legs, tucked under)
	local legCol = Color3.fromRGB(10, 24, 68)
	for side = 1, 2 do
		local sx = (side == 1) and 1 or -1
		for i = 1, 2 do
			local zo  = (i == 1) and -r*0.52 or r*0.18
			local frm = Vector3.new(sx*r*0.74, -r*0.22, zo)
			local too = Vector3.new(sx*r*1.65, -r*0.72, zo - sx*0.04)
			addRod(model, parts, frm, too, r*0.085, legCol)
		end
	end

	-- 2 rear oar legs (broadened for swimming, 2-segment with flat tarsus pad)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local frm = Vector3.new(sx*r*0.74, -r*0.22, r*0.88)
		local mid = Vector3.new(sx*r*1.32,  -r*0.5,  r*1.15)
		local too = Vector3.new(sx*r*1.72, -r*0.65, r*1.42)
		addRod(model, parts, frm, mid, r*0.1, legCol)
		addRod(model, parts, mid, too, r*0.09, legCol)
		-- Flat oar tarsus
		addPart(model, parts, CFrame.new(too),
			Vector3.new(r*0.42, r*0.07, r*0.3), legCol, SP)
	end

	-- Antennae (short, tucked under pronotum edge)
	local antCol = Color3.fromRGB(10, 24, 68)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.2,  r*0.22, -r*1.65)
		local tip = Vector3.new(sx*r*0.44, r*0.55, -r*2.05)
		addRod(model, parts, bas, tip, r*0.06, antCol)
	end

	local hpBar = buildBillboard(body, def, mobLevel, r * 0.8)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- DRAGONFLY WARLORD  (Boss, 3-phase)
-- Enormous compound eyes, four iridescent wings,
-- long segmented abdomen, raptorial legs
-- ─────────────────────────────────────────

local function buildDragonflyWarlord(def, mobLevel)
	local r     = def.size * 2    -- 7.0
	local navy  = def.bodyColor   -- 20,80,160
	local cyan  = def.accentColor -- 80,200,255

	local model = Instance.new("Model")
	model.Name  = "Enemy_" .. def.key
	local parts = {}

	-- ── Synthorax (PRIMARY): upright, powerful, NE for boss ──
	local body  = Instance.new("Part")
	body.Name   = "HumanoidRootPart"
	body.Size   = Vector3.new(r*0.72, r*1.25, r*0.9)
	body.Color  = navy
	body.Material = NE
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = true
	body.Parent = model
	model.PrimaryPart = body

	-- ── Head: mostly compound eyes (dragonflies have ~270° vision) ──
	addPart(model, parts,
		CFrame.new(0, r*0.8, -r*0.55),
		Vector3.new(r*1.05, r*0.88, r*0.75),
		Color3.fromRGB(14, 58, 130), NE, "Ball")

	-- Giant compound eyes (boss red, nearly wrap-around)
	local eyeCol = Color3.fromRGB(255, 40, 40)
	addPart(model, parts,
		CFrame.new( r*0.55, r*0.82, -r*0.6),
		Vector3.new(r*0.68, r*0.7, r*0.55), eyeCol, NE, "Ball")
	addPart(model, parts,
		CFrame.new(-r*0.55, r*0.82, -r*0.6),
		Vector3.new(r*0.68, r*0.7, r*0.55), eyeCol, NE, "Ball")

	-- Ocelli (3 small neon dots on top of head — dragonfly simple eyes)
	local ocelCol = Color3.fromRGB(255, 220, 40)
	for i = -1, 1 do
		addPart(model, parts,
			CFrame.new(i * r*0.22, r*1.12, -r*0.48),
			Vector3.new(r*0.15, r*0.15, r*0.15), ocelCol, NE, "Ball")
	end

	-- ── Abdomen (5 segments, long and narrow, tapering) ─────
	local abdZ     = { r*0.85, r*1.7,  r*2.48, r*3.18, r*3.82 }
	local abdScale = { 0.68,   0.58,   0.46,   0.34,   0.22   }
	local abdBase  = Color3.fromRGB(18, 72, 148)
	for i, zo in ipairs(abdZ) do
		local s = abdScale[i]
		addPart(model, parts,
			CFrame.new(0, -r*0.12, zo),
			Vector3.new(r*s, r*s*0.82, r*0.68),
			abdBase, SP, "Ball")
		-- Cyan accent stripe on each segment
		addPart(model, parts,
			CFrame.new(0, r*s*0.44, zo),
			Vector3.new(r*s*1.05, r*0.07, r*0.64),
			cyan, NE)
	end
	-- Tail cerci (two tiny points at abdomen tip)
	local tailZ = abdZ[5]
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.06, -r*0.12, tailZ + r*0.32)
		local tip = Vector3.new(sx*r*0.12, -r*0.18, tailZ + r*0.62)
		addRod(model, parts, bas, tip, r*0.05, abdBase)
	end

	-- ── 4 Wings (two pairs, large flat horizontal panels) ───
	-- Real dragonfly wings are held perpendicular to body axis
	-- and slope very slightly downward from thorax to tip.
	-- Forewings are slightly ahead of hindwings.
	local wingTr  = 0.32
	local wingCol = cyan

	-- Forewings (pair 1, behind the head)
	addPart(model, parts,
		CFrame.new( r*2.0, r*0.42, -r*0.08) * CFrame.Angles(0, 0, math.rad(6)),
		Vector3.new(r*3.45, r*0.06, r*1.12), wingCol, NE, nil, wingTr)
	addPart(model, parts,
		CFrame.new(-r*2.0, r*0.42, -r*0.08) * CFrame.Angles(0, 0, math.rad(-6)),
		Vector3.new(r*3.45, r*0.06, r*1.12), wingCol, NE, nil, wingTr)

	-- Hindwings (pair 2, slightly behind + lower, broader near base)
	addPart(model, parts,
		CFrame.new( r*1.88, r*0.25, r*0.78) * CFrame.Angles(0, 0, math.rad(4)),
		Vector3.new(r*3.1,  r*0.06, r*1.22), wingCol, NE, nil, wingTr)
	addPart(model, parts,
		CFrame.new(-r*1.88, r*0.25, r*0.78) * CFrame.Angles(0, 0, math.rad(-4)),
		Vector3.new(r*3.1,  r*0.06, r*1.22), wingCol, NE, nil, wingTr)

	-- Wing veins (thin structural rods giving the netting look)
	local veinCol = Color3.fromRGB(38, 120, 200)
	local vR = r * 0.045
	-- Right forewing: leading-edge vein + diagonal cross-vein
	addRod(model, parts, Vector3.new(r*0.36, r*0.42, -r*0.55),
		Vector3.new(r*3.72, r*0.42, -r*0.55), vR, veinCol)
	addRod(model, parts, Vector3.new(r*0.36, r*0.42,  r*0.38),
		Vector3.new(r*3.72, r*0.42,  r*0.38), vR, veinCol)
	-- Left forewing
	addRod(model, parts, Vector3.new(-r*0.36, r*0.42, -r*0.55),
		Vector3.new(-r*3.72, r*0.42, -r*0.55), vR, veinCol)
	addRod(model, parts, Vector3.new(-r*0.36, r*0.42,  r*0.38),
		Vector3.new(-r*3.72, r*0.42,  r*0.38), vR, veinCol)
	-- Right hindwing cross-vein
	addRod(model, parts, Vector3.new(r*0.36, r*0.25, r*0.22),
		Vector3.new(r*3.42, r*0.25, r*0.22), vR, veinCol)
	-- Left hindwing cross-vein
	addRod(model, parts, Vector3.new(-r*0.36, r*0.25, r*0.22),
		Vector3.new(-r*3.42, r*0.25, r*0.22), vR, veinCol)

	-- ── 6 raptorial legs (held forward, spiny, basket-like) ─
	-- Dragonflies use their legs as a capture basket in flight
	local legCol  = Color3.fromRGB(12, 52, 115)
	local spineCol = Color3.fromRGB(40, 130, 210)
	for side = 1, 2 do
		local sx = (side == 1) and 1 or -1
		for li = 1, 3 do
			local zo  = -r*0.52 + (li - 1) * r*0.38
			local frm = Vector3.new(sx*r*0.36, -r*0.05, zo)
			local mid = Vector3.new(sx*r*0.78, -r*0.62, zo - r*0.22)
			local too = Vector3.new(sx*r*1.18, -r*1.28, zo - r*0.55)
			addRod(model, parts, frm, mid, r*0.1,  legCol)
			addRod(model, parts, mid, too, r*0.08, legCol)
			-- Leg spine
			local spA = Vector3.new((mid.X + frm.X)*0.5, (mid.Y + frm.Y)*0.5, (mid.Z + frm.Z)*0.5)
			local spB = Vector3.new(spA.X + sx*r*0.15, spA.Y - r*0.18, spA.Z)
			addRod(model, parts, spA, spB, r*0.05, spineCol)
		end
	end

	-- Antennae (short, bristle-like — dragonflies have tiny antennae)
	local antCol = Color3.fromRGB(12, 52, 115)
	for side = 1, 2 do
		local sx  = (side == 1) and 1 or -1
		local bas = Vector3.new(sx*r*0.22, r*1.05, -r*0.68)
		local tip = Vector3.new(sx*r*0.42, r*1.4,  -r*1.05)
		addRod(model, parts, bas, tip, r*0.07, antCol)
	end

	-- OrbCore (boss orbit animation handled by EnemyManager)
	addBossOrb(model, def, r)

	local hpBar = buildBillboard(body, def, mobLevel, r * 2.1)
	return model, body, hpBar, parts
end

-- ─────────────────────────────────────────
-- Dispatch
-- ─────────────────────────────────────────

function WetlandEnemyModels.Build(def, mobLevel)
	local k = def.key
	if k == "WaterStrider" or k == "ElderStrider" then
		return buildWaterStrider(def, mobLevel)
	elseif k == "PondLeech" or k == "BloatedLeech" then
		return buildPondLeech(def, mobLevel)
	elseif k == "DivingBeetle" then
		return buildDivingBeetle(def, mobLevel)
	elseif k == "DragonFlyWarlord" then
		return buildDragonflyWarlord(def, mobLevel)
	end
	return nil
end

return WetlandEnemyModels
