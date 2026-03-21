-- ButterflyModel.lua
-- Builds procedural companion models for each of the 5 Butterfly evolution stages.
--
-- All parts are Anchored=true with a local-space CFrame offset from the body (PrimaryPart).
-- InsectCompanion updates them every heartbeat:  part.CFrame = body.CFrame * offset
--
-- Stage 1  Caterpillar      – 7 bright-green segments, yellow dorsal spots, tiny prolegs
-- Stage 2  Fat Caterpillar  – same structure 1.25× fatter, silk spinneret on head
-- Stage 3  Chrysalis        – smooth metallic-gold teardrop, lengthwise ridges, gold dots
-- Stage 4  Butterfly        – large oval wings (XY-plane), segmented abdomen, club antennae
-- Stage 5  Moth Emperor     – huge angular grey wings, feathery antennae, blue eye-spots
--
-- Wing display plane: wings spread in the XY plane (thin in Z).
-- This means full wing area is visible when the companion faces the camera (+Z).
-- Body axis: front = +Z (head), rear = -Z (abdomen / chrysalis bottom).

local InsectData = require(game:GetService("ReplicatedStorage"):WaitForChild("InsectData"))

local ButterflyModel = {}

-- ─────────────────────────────────────────
-- Per-stage visual config
-- ─────────────────────────────────────────
local STAGE_CFG = {
	[1] = {  -- Caterpillar: vivid grass-green
		bodyColor  = Color3.fromRGB(58, 185, 48),
		headColor  = Color3.fromRGB(48, 155, 40),
		spotColor  = Color3.fromRGB(238, 224, 55),   -- yellow dorsal spots
		legColor   = Color3.fromRGB(46, 148, 36),
		eyeColor   = Color3.fromRGB(18, 14, 8),
		glowColor  = Color3.fromRGB(78, 215, 62),
	},
	[2] = {  -- Fat Caterpillar: lime green, plump
		bodyColor  = Color3.fromRGB(96, 210, 60),
		headColor  = Color3.fromRGB(78, 182, 48),
		spotColor  = Color3.fromRGB(240, 218, 42),
		legColor   = Color3.fromRGB(72, 172, 42),
		eyeColor   = Color3.fromRGB(16, 12, 6),
		glowColor  = Color3.fromRGB(115, 232, 78),
		spinColor  = Color3.fromRGB(238, 235, 220),  -- silk spinneret
	},
	[3] = {  -- Chrysalis: metallic gold
		shellColor = Color3.fromRGB(192, 176, 38),
		ridgeColor = Color3.fromRGB(158, 142, 24),
		dotColor   = Color3.fromRGB(228, 215, 78),   -- golden neon dots
		hookColor  = Color3.fromRGB(145, 132, 22),
		glowColor  = Color3.fromRGB(230, 215, 52),
	},
	[4] = {  -- Butterfly: golden-yellow wings, dark body
		bodyColor    = Color3.fromRGB(48, 36, 26),
		wingYellow   = Color3.fromRGB(245, 192, 18),  -- main wing colour
		wingDark     = Color3.fromRGB(18, 14, 8),     -- border / veins
		wingSpot     = Color3.fromRGB(252, 248, 240),  -- white spots
		eyeColor     = Color3.fromRGB(46, 210, 46),   -- bright green compound
		antennaColor = Color3.fromRGB(30, 24, 16),
		legColor     = Color3.fromRGB(36, 28, 18),
		glowColor    = Color3.fromRGB(255, 212, 32),
	},
	[5] = {  -- Moth Emperor: warm stone-grey, blue eye-spots
		bodyColor    = Color3.fromRGB(135, 130, 122),
		wingGrey     = Color3.fromRGB(158, 152, 145),  -- main wing
		wingDark     = Color3.fromRGB(85, 80, 75),     -- dark markings
		eyeSpotBlue  = Color3.fromRGB(75, 115, 225),   -- wing eye-spot ring
		eyeSpotWhite = Color3.fromRGB(245, 242, 235),  -- eye-spot centre
		eyeColor     = Color3.fromRGB(178, 75, 218),   -- purple compound eyes
		antennaColor = Color3.fromRGB(142, 136, 128),
		legColor     = Color3.fromRGB(115, 110, 104),
		glowColor    = Color3.fromRGB(175, 172, 198),
	},
}

-- ─────────────────────────────────────────
-- Build
-- ─────────────────────────────────────────
function ButterflyModel.Build(stageIndex)
	local stageDef = InsectData.GetStage("Butterfly", stageIndex)
	if not stageDef then return nil end

	local cfg      = STAGE_CFG[stageIndex] or STAGE_CFG[4]
	local baseSize = math.clamp(stageDef.size * 2.5, 1.2, 6.0)
	local bs       = baseSize

	local model = Instance.new("Model")
	model.Name  = "Companion"

	local parts = {}

	-- ── Part factories ───────────────────────────────────────────
	local function makePart(name, size, color, mat, transp)
		local p        = Instance.new("Part")
		p.Name         = name
		p.Size         = size
		p.Color        = color
		p.Material     = mat or Enum.Material.SmoothPlastic
		p.Anchored     = true
		p.CanCollide   = false
		p.CastShadow   = false
		p.Transparency = transp or 0
		p.Parent       = model
		return p
	end

	local function addPart(p, offsetCF)
		table.insert(parts, { part = p, offset = offsetCF })
	end

	local function ball(name, radius, color, pos, mat, transp)
		local d = radius * 2
		local p = makePart(name, Vector3.new(d, d, d), color, mat, transp)
		p.Shape = Enum.PartType.Ball
		addPart(p, CFrame.new(pos))
	end

	local function rod(name, from, to, radius, color, mat, transp)
		local len = (to - from).Magnitude
		if len < 0.01 then return end
		local mid = from:Lerp(to, 0.5)
		local p   = makePart(name, Vector3.new(radius, radius, len), color, mat, transp)
		addPart(p, CFrame.new(mid, from))
	end

	-- Flat oval part (for wings): Ball shape with very thin Z
	local function wing(name, spanX, heightY, thinZ, color, pos, yawDeg, rollDeg, transp)
		local p = makePart(name, Vector3.new(spanX, heightY, thinZ), color,
			Enum.Material.SmoothPlastic, transp or 0.12)
		p.Shape = Enum.PartType.Ball
		addPart(p, CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg or 0), math.rad(rollDeg or 0)))
	end

	-- Flat rectangular wing panel (for moth's more angular wings)
	local function wingPanel(name, spanX, heightY, thinZ, color, pos, yawDeg, rollDeg, transp)
		local p = makePart(name, Vector3.new(spanX, heightY, thinZ), color,
			Enum.Material.SmoothPlastic, transp or 0.12)
		addPart(p, CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg or 0), math.rad(rollDeg or 0)))
	end

	local function attachHUD(body)
		local bb       = Instance.new("BillboardGui")
		bb.Name        = "CompanionHUD"
		bb.Size        = UDim2.new(0, 120, 0, 38)
		bb.StudsOffset = Vector3.new(0, bs * 0.95 + 1.5, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 60
		bb.Parent      = body

		local nameLbl  = Instance.new("TextLabel")
		nameLbl.Name   = "NameLabel"
		nameLbl.Size   = UDim2.new(1, 0, 0, 18)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3  = Color3.new(1, 1, 1)
		nameLbl.Font        = Enum.Font.GothamBold
		nameLbl.TextScaled  = true
		nameLbl.Parent      = bb

		local hpBg     = Instance.new("Frame")
		hpBg.Name      = "HPBg"
		hpBg.Size      = UDim2.new(1, 0, 0, 10)
		hpBg.Position  = UDim2.new(0, 0, 0, 20)
		hpBg.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
		hpBg.BorderSizePixel  = 0
		hpBg.Parent    = bb
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

		local hpFill   = Instance.new("Frame")
		hpFill.Name    = "HPFill"
		hpFill.Size    = UDim2.new(1, 0, 1, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
		hpFill.BorderSizePixel  = 0
		hpFill.Parent  = hpBg
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

		return hpFill, nameLbl
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGES 1-2 – CATERPILLAR / FAT CATERPILLAR
	-- ════════════════════════════════════════════════════════════
	if stageIndex <= 2 then
		-- 7 round segments along a gentle arc; head at +Z.
		-- Stage 2 applies a fat multiplier to all segment radii.
		local fatMult = (stageIndex == 2) and 1.25 or 1.0

		local radii = { 0.24, 0.27, 0.30, 0.32, 0.30, 0.27, 0.22 }
		local posY  = { -0.10, -0.05, -0.01, 0.0, 0.01, 0.05, 0.10 }
		local posZ  = { -1.32, -0.88, -0.50, 0.0, 0.48, 0.88, 1.28 }

		local bodyR = radii[4] * bs * fatMult
		local body  = makePart("HumanoidRootPart",
			Vector3.new(bodyR * 2, bodyR * 2, bodyR * 2), cfg.bodyColor)
		body.Shape      = Enum.PartType.Ball
		model.PrimaryPart = body

		for i = 1, 7 do
			if i ~= 4 then
				local r   = radii[i] * bs * fatMult
				local pos = Vector3.new(0, posY[i] * bs, posZ[i] * bs)
				ball("Seg" .. i, r, (i == 7) and cfg.headColor or cfg.bodyColor, pos)
			end
		end

		-- Yellow dorsal spots (top of each body segment)
		local spotR = bs * 0.062 * fatMult
		for si = 1, 6 do   -- segments 1-6 (not head)
			local segRI = radii[si] * bs * fatMult
			local spos  = Vector3.new(0, posY[si] * bs + segRI * 0.85, posZ[si] * bs)
			ball("Spot" .. si, spotR, cfg.spotColor, spos)
		end

		-- Prolegs: small stubs on underside of body segments 2-6
		local plegR = bs * 0.060 * fatMult
		for si = 2, 6 do
			local segRI = radii[si] * bs * fatMult
			for _, sx in ipairs({ -1, 1 }) do
				local npos = Vector3.new(sx * segRI * 0.72, posY[si] * bs - segRI * 0.75, posZ[si] * bs)
				ball("Proleg" .. si .. (sx > 0 and "R" or "L"), plegR, cfg.legColor, npos)
			end
		end

		-- Eyes on head segment (s7)
		local headPos = Vector3.new(0, posY[7] * bs, posZ[7] * bs)
		local eyeR    = bs * 0.060 * fatMult
		for _, sx in ipairs({ -1, 1 }) do
			ball("Eye" .. (sx > 0 and "R" or "L"), eyeR, cfg.eyeColor,
				headPos + Vector3.new(sx * bs * 0.10, bs * 0.04, bs * 0.18), Enum.Material.Neon)
		end

		-- Short head antennae (2 tiny balls per side)
		local antR = bs * 0.050 * fatMult
		for _, sx in ipairs({ -1, 1 }) do
			local aBase = headPos + Vector3.new(sx * bs * 0.08, bs * 0.14, bs * 0.12)
			local aTip  = aBase   + Vector3.new(sx * bs * 0.05, bs * 0.12, bs * 0.04)
			rod("Ant" .. (sx > 0 and "R" or "L"), aBase, aTip, antR, cfg.headColor)
			ball("AntTip" .. (sx > 0 and "R" or "L"), antR * 1.3, cfg.spotColor, aTip)
		end

		-- Stage 2: silk spinneret bump at head front-bottom
		if stageIndex == 2 then
			ball("Spinneret", bs * 0.072,
				cfg.spinColor,
				headPos + Vector3.new(0, -headPos.Y * 0.5 - bs * 0.05, bs * 0.18))
		end

		ball("GlowCore", bs * 0.22, cfg.glowColor, Vector3.new(0, 0, 0),
			Enum.Material.Neon, 0.35)

		local hpFill, nameLbl = attachHUD(body)
		return model, body, hpFill, nameLbl, parts
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGE 3 – CHRYSALIS
	-- ════════════════════════════════════════════════════════════
	if stageIndex == 3 then
		-- Smooth gold oval, slightly elongated in Z (forward/back axis).
		local r    = bs * 0.46
		local body = makePart("HumanoidRootPart",
			Vector3.new(r * 2.0, r * 1.72, r * 2.52), cfg.shellColor)
		body.Shape      = Enum.PartType.Ball
		model.PrimaryPart = body

		-- Attachment hook at the top (where a real chrysalis hangs)
		local hookY = r * 0.86
		ball("Hook",  bs * 0.072, cfg.hookColor, Vector3.new(0, hookY + bs * 0.04, 0))
		ball("HookStem", bs * 0.048, cfg.hookColor, Vector3.new(0, hookY + bs * 0.11, 0))

		-- Three longitudinal ridges running along the Z axis at the top
		local ridgeW = math.max(bs * 0.038, 0.05)
		local ridgeY = r * 0.76
		local ridgeZ = r * 1.12
		for _, rx in ipairs({ 0, bs * 0.28, -bs * 0.28 }) do
			rod("Ridge" .. tostring(rx),
				Vector3.new(rx, ridgeY, -ridgeZ),
				Vector3.new(rx, ridgeY,  ridgeZ),
				ridgeW, cfg.ridgeColor)
		end

		-- Metallic gold neon dots scattered on surface
		local dotPositions = {
			Vector3.new( bs*0.22,  r*0.62,  r*0.80),
			Vector3.new(-bs*0.22,  r*0.62,  r*0.80),
			Vector3.new( bs*0.30,  r*0.30, -r*0.60),
			Vector3.new(-bs*0.30,  r*0.30, -r*0.60),
			Vector3.new( bs*0.10,  r*0.72,  r*0.00),
			Vector3.new(-bs*0.10,  r*0.72,  r*0.00),
		}
		for di, dpos in ipairs(dotPositions) do
			ball("Dot" .. di, bs * 0.050, cfg.dotColor, dpos, Enum.Material.Neon, 0.25)
		end

		ball("GlowCore", bs * 0.28, cfg.glowColor, Vector3.new(0, 0, 0),
			Enum.Material.Neon, 0.35)

		local hpFill, nameLbl = attachHUD(body)
		return model, body, hpFill, nameLbl, parts
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGES 4-5 – BUTTERFLY / MOTH EMPEROR
	-- ════════════════════════════════════════════════════════════
	local isMoth = (stageIndex == 5)

	-- ── Body proportions ─────────────────────────────────────────
	local thoraxR = bs * 0.30
	local headR   = bs * 0.26

	local headPos = Vector3.new(0, bs * 0.04, thoraxR + headR * 0.75)

	-- ── Thorax (PRIMARY) ─────────────────────────────────────────
	local thoraxD = thoraxR * 2
	local body    = makePart("HumanoidRootPart",
		Vector3.new(thoraxD, thoraxD, thoraxD), cfg.bodyColor, Enum.Material.Fabric)
	body.Shape      = Enum.PartType.Ball
	model.PrimaryPart = body

	-- ── Head ─────────────────────────────────────────────────────
	ball("Head", headR, cfg.bodyColor, headPos)

	-- ── Compound eyes ────────────────────────────────────────────
	local eyeR = math.max(bs * 0.088, 0.10)
	for _, sx in ipairs({ -1, 1 }) do
		local sfx  = sx > 0 and "R" or "L"
		local epos = headPos + Vector3.new(sx * headR * 0.64, headR * 0.06, headR * 0.50)
		ball("Eye"   .. sfx, eyeR,        Color3.new(1, 1, 1), epos)
		ball("Pupil" .. sfx, eyeR * 0.68, cfg.eyeColor,
			epos + Vector3.new(0, 0, eyeR * 0.46), Enum.Material.Neon)
	end

	-- ── Segmented abdomen (4 tapering segments behind thorax) ────
	local abdSegR = { bs * 0.18, bs * 0.14, bs * 0.11, bs * 0.08 }
	local abdSegZ = { -bs * 0.45, -bs * 0.80, -bs * 1.10, -bs * 1.35 }
	for i, r in ipairs(abdSegR) do
		ball("AbdSeg" .. i, r, cfg.bodyColor, Vector3.new(0, 0, abdSegZ[i]))
	end

	-- ── 6 Thin legs ──────────────────────────────────────────────
	local legR     = bs * 0.052
	local attachX  = bs * 0.28
	local attachY  = -bs * 0.16
	local legPairZ = { bs * 0.18, 0, -bs * 0.18 }

	for _, side in ipairs({ -1, 1 }) do
		for pi, pz in ipairs(legPairZ) do
			local attach = Vector3.new(side * attachX, attachY, pz)
			local knee   = Vector3.new(side * (attachX + bs*0.30), attachY + bs*0.06, pz)
			local tip    = Vector3.new(side * (attachX + bs*0.58), attachY + bs*0.06 - bs*0.28, pz)
			local sfx    = tostring(pi) .. (side > 0 and "R" or "L")
			rod("UpperLeg" .. sfx, attach, knee, legR, cfg.legColor)
			rod("LowerLeg" .. sfx, knee,   tip,  legR, cfg.legColor)
		end
	end

	-- ════════════════════════════════════════════════════════════
	-- BUTTERFLY WINGS (stage 4)
	-- Wings are oval Ball-shape parts, very thin in Z (depth), large in X and Y.
	-- They sit in the XY plane so the full wing area faces the camera.
	-- Layout:  dark border layer (slightly behind) + bright yellow layer (in front)
	--          + small white spots near wing tips.
	-- ════════════════════════════════════════════════════════════
	if not isMoth then

		-- Antennae: long, thin, club-tipped
		local antW = math.max(bs * 0.042, 0.06)
		for _, sx in ipairs({ -1, 1 }) do
			local sfx      = sx > 0 and "R" or "L"
			local antBase  = headPos + Vector3.new(sx * headR * 0.24, headR * 0.38, headR * 0.22)
			local antElbow = antBase  + Vector3.new(sx * bs * 0.10, bs * 0.36, bs * 0.06)
			local antTip   = antElbow + Vector3.new(sx * bs * 0.06, bs * 0.32, bs * 0.02)
			rod("Scape"     .. sfx, antBase,  antElbow, antW,         cfg.antennaColor)
			rod("Funiculus" .. sfx, antElbow, antTip,   antW,         cfg.antennaColor)
			ball("Club"     .. sfx, antW * 2.6, cfg.antennaColor, antTip)  -- distinctive large club
		end

		-- Wing pair data:  { sign, isFore, centerX, centerY, centerZ }
		-- isFore=true → forewing (taller, positioned higher)
		-- sign +1 → right, -1 → left
		local wingPairs = {
			{  1, true,   bs*0.52,  bs*0.30,  bs*0.08 },  -- right forewing
			{ -1, true,  -bs*0.52,  bs*0.30,  bs*0.08 },  -- left forewing
			{  1, false,  bs*0.40, -bs*0.16, -bs*0.10 },  -- right hindwing
			{ -1, false, -bs*0.40, -bs*0.16, -bs*0.10 },  -- left hindwing
		}

		for wi, wd in ipairs(wingPairs) do
			local sx, isFore, cx, cy, cz = wd[1], wd[2], wd[3], wd[4], wd[5]
			local spanX  = isFore and bs * 0.92 or bs * 0.70
			local heightY = isFore and bs * 1.12 or bs * 0.82
			local suffix = (wi <= 2) and "F" or "H"  .. tostring(wi)

			-- Dark border (slightly further back in Z, a touch larger)
			wing("Wing" .. wi .. "Dark",
				spanX * 1.06, heightY * 1.06, bs * 0.042,
				cfg.wingDark,
				Vector3.new(cx, cy, cz - bs * 0.04))

			-- Bright yellow main wing (in front)
			wing("Wing" .. wi .. "Main",
				spanX * 0.90, heightY * 0.92, bs * 0.055,
				cfg.wingYellow,
				Vector3.new(cx, cy, cz + bs * 0.02))

			-- White spots near outer wing tip
			local spotX = cx + sx * spanX * 0.36
			local spotY = cy + heightY * 0.38
			ball("WSpot" .. wi, bs * 0.052, cfg.wingSpot,
				Vector3.new(spotX, spotY, cz + bs * 0.04), Enum.Material.Neon, 0.1)
			ball("WSpot2_" .. wi, bs * 0.040, cfg.wingSpot,
				Vector3.new(spotX + sx * bs*0.08, spotY - bs*0.12, cz + bs * 0.04),
				Enum.Material.Neon, 0.1)
		end
	end

	-- ════════════════════════════════════════════════════════════
	-- MOTH EMPEROR WINGS (stage 5)
	-- Flat rectangular panels (not oval) for a more angular moth silhouette.
	-- Forewings are large, slightly angled; hindwings overlap below.
	-- Each wing has a dark layered marking + two concentric eye-spots.
	-- ════════════════════════════════════════════════════════════
	if isMoth then

		-- Feathery antennae: main rod + perpendicular barbs
		local antW     = math.max(bs * 0.052, 0.07)
		local barbW    = math.max(bs * 0.028, 0.04)
		for _, sx in ipairs({ -1, 1 }) do
			local sfx      = sx > 0 and "R" or "L"
			local antBase  = headPos + Vector3.new(sx * headR * 0.26, headR * 0.34, headR * 0.20)
			local antElbow = antBase  + Vector3.new(sx * bs * 0.22, bs * 0.40, bs * 0.04)

			rod("AntMain" .. sfx, antBase, antElbow, antW, cfg.antennaColor)

			-- 5 feather barbs evenly spaced along the antenna
			for bi = 1, 5 do
				local t     = bi / 6
				local bPos  = antBase:Lerp(antElbow, t)
				local bLen  = bs * 0.20 * (1 - t * 0.4)  -- shorter toward tip
				-- Barb perpendicular to antenna direction, spread upward
				local bTip  = bPos + Vector3.new(0, bLen * 0.7, sx * bLen * 0.3)
				rod("Barb" .. sfx .. bi, bPos, bTip, barbW, cfg.antennaColor)
			end
		end

		-- Moth wings: flat rectangular panels, slightly rolled downward (~12°)
		-- { right/left sign, isFore, centerX, centerY, centerZ }
		local mWingDefs = {
			{  1, true,   bs*0.64,  bs*0.30,  bs*0.08 },   -- right forewing
			{ -1, true,  -bs*0.64,  bs*0.30,  bs*0.08 },   -- left forewing
			{  1, false,  bs*0.54, -bs*0.22, -bs*0.12 },   -- right hindwing
			{ -1, false, -bs*0.54, -bs*0.22, -bs*0.12 },   -- left hindwing
		}

		for wi, wd in ipairs(mWingDefs) do
			local sx, isFore, cx, cy, cz = wd[1], wd[2], wd[3], wd[4], wd[5]
			local spanX   = isFore and bs * 1.25 or bs * 1.00
			local heightY = isFore and bs * 1.18 or bs * 0.88
			-- Moths hold wings slightly below horizontal; roll outward edge down ~12°
			local rollDeg = sx * (-12)
			local yawDeg  = isFore and sx * (-5) or sx * 5

			-- Dark base layer (behind)
			wingPanel("MWing" .. wi .. "Dark",
				spanX * 1.06, heightY * 1.06, bs * 0.038,
				cfg.wingDark,
				Vector3.new(cx, cy, cz - bs * 0.04),
				yawDeg, rollDeg, 0.10)

			-- Grey main wing (front)
			wingPanel("MWing" .. wi .. "Main",
				spanX * 0.92, heightY * 0.92, bs * 0.050,
				cfg.wingGrey,
				Vector3.new(cx, cy, cz + bs * 0.02),
				yawDeg, rollDeg, 0.12)

			-- Eye-spot (only on forewings, characteristic moth marking)
			if isFore then
				-- Position: roughly mid-wing
				local spX = cx + sx * spanX * 0.10
				local spY = cy + bs * 0.08
				local spZ = cz + bs * 0.05
				-- Blue ring
				ball("EyeSpotBlue" .. wi, bs * 0.110, cfg.eyeSpotBlue,
					Vector3.new(spX, spY, spZ), Enum.Material.Neon, 0.10)
				-- White centre dot
				ball("EyeSpotWhite" .. wi, bs * 0.058, cfg.eyeSpotWhite,
					Vector3.new(spX, spY, spZ + bs * 0.03), Enum.Material.Neon, 0.05)
			end
		end
	end

	-- ── Glow core ────────────────────────────────────────────────
	ball("GlowCore", bs * 0.24, cfg.glowColor, Vector3.new(0, 0, 0),
		Enum.Material.Neon, 0.35)

	-- ── Billboard HUD ────────────────────────────────────────────
	local hpFill, nameLbl = attachHUD(body)

	return model, body, hpFill, nameLbl, parts
end

return ButterflyModel
