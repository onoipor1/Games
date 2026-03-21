-- BeeModel.lua
-- Builds procedural bee / hornet companion models for each of the 5 Bee evolution stages.
--
-- All parts are Anchored=true with a local-space CFrame offset from the body (PrimaryPart).
-- InsectCompanion updates them every heartbeat:  part.CFrame = body.CFrame * offset
--
-- Stage 1 (Bee Larva)   – cream-yellow grub: 5 oval segments, no wings/legs
-- Stages 2-5            – proper bee/hornet:
--                          Head + Thorax (PRIMARY) + Petiole + Abdomen
--                          4 wings, 6 legs, elbowed antennae, abdomen stripes
-- Stage 3 (Worker Bee)  – adds stinger + yellow pollen baskets on rear legs
-- Stages 3-5            – stinger at abdomen tip
-- Stage 5 (Queen Hornet)– bright red, massive abdomen, larger wings, gold crown
--
-- Body axis: front = +Z (head), rear = -Z (abdomen tip / stinger)

local InsectData = require(game:GetService("ReplicatedStorage"):WaitForChild("InsectData"))

local BeeModel = {}

-- ─────────────────────────────────────────
-- Per-stage visual config
-- ─────────────────────────────────────────
local STAGE_CFG = {
	[1] = {  -- Bee Larva: honeycomb cream
		bodyColor = Color3.fromRGB(240, 226, 168),
		headColor = Color3.fromRGB(230, 214, 152),
		eyeColor  = Color3.fromRGB(88, 68, 44),
		glowColor = Color3.fromRGB(246, 235, 184),
	},
	[2] = {  -- Drone Bee: classic yellow + black
		bodyColor    = Color3.fromRGB(245, 218, 32),    -- yellow body/thorax
		headColor    = Color3.fromRGB(26, 24, 20),      -- black head
		legColor     = Color3.fromRGB(20, 18, 14),
		antennaColor = Color3.fromRGB(24, 22, 18),
		eyeColor     = Color3.fromRGB(48, 205, 48),     -- neon green compound
		stripeColor  = Color3.fromRGB(18, 16, 13),      -- near-black
		wingColor    = Color3.fromRGB(200, 218, 240),   -- pale blue-white
		glowColor    = Color3.fromRGB(255, 234, 52),
	},
	[3] = {  -- Worker Bee: warm amber-gold
		bodyColor    = Color3.fromRGB(240, 160, 16),
		headColor    = Color3.fromRGB(20, 18, 14),
		legColor     = Color3.fromRGB(16, 14, 10),
		antennaColor = Color3.fromRGB(18, 16, 12),
		eyeColor     = Color3.fromRGB(255, 152, 0),     -- amber compound
		stripeColor  = Color3.fromRGB(14, 12, 9),
		wingColor    = Color3.fromRGB(196, 215, 238),
		glowColor    = Color3.fromRGB(255, 196, 36),
		stingerColor = Color3.fromRGB(52, 36, 16),
		pollenColor  = Color3.fromRGB(255, 212, 18),    -- bright yellow pollen
	},
	[4] = {  -- Hornet: blazing orange, menacing
		bodyColor    = Color3.fromRGB(248, 126, 14),
		headColor    = Color3.fromRGB(16, 14, 10),
		legColor     = Color3.fromRGB(12, 10, 7),
		antennaColor = Color3.fromRGB(14, 12, 8),
		eyeColor     = Color3.fromRGB(255, 72, 0),      -- fiery orange-red
		stripeColor  = Color3.fromRGB(8, 6, 4),         -- near-black
		wingColor    = Color3.fromRGB(188, 208, 234),
		glowColor    = Color3.fromRGB(255, 136, 26),
		stingerColor = Color3.fromRGB(42, 26, 10),
	},
	[5] = {  -- Queen Hornet: vivid crimson, regal
		bodyColor    = Color3.fromRGB(220, 34, 16),     -- bright red
		headColor    = Color3.fromRGB(14, 12, 8),
		legColor     = Color3.fromRGB(10, 8, 5),
		antennaColor = Color3.fromRGB(192, 30, 14),     -- red antennae
		eyeColor     = Color3.fromRGB(255, 215, 0),     -- gold
		stripeColor  = Color3.fromRGB(6, 4, 2),
		wingColor    = Color3.fromRGB(184, 204, 232),
		glowColor    = Color3.fromRGB(255, 54, 26),
		stingerColor = Color3.fromRGB(32, 20, 8),
		crownColor   = Color3.fromRGB(255, 215, 0),     -- gold
	},
}

-- ─────────────────────────────────────────
-- Build
-- ─────────────────────────────────────────
function BeeModel.Build(stageIndex)
	local stageDef = InsectData.GetStage("Bee", stageIndex)
	if not stageDef then return nil end

	local cfg      = STAGE_CFG[stageIndex] or STAGE_CFG[2]
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

	-- Ball at local-space position
	local function ball(name, radius, color, pos, mat, transp)
		local d = radius * 2
		local p = makePart(name, Vector3.new(d, d, d), color, mat, transp)
		p.Shape = Enum.PartType.Ball
		addPart(p, CFrame.new(pos))
	end

	-- Rod segment between two local-space points
	local function rod(name, from, to, radius, color, mat, transp)
		local len = (to - from).Magnitude
		if len < 0.01 then return end
		local mid = from:Lerp(to, 0.5)
		local p   = makePart(name, Vector3.new(radius, radius, len), color, mat, transp)
		addPart(p, CFrame.new(mid, from))
	end

	-- ── HUD ──────────────────────────────────────────────────────
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
		hpBg.BackgroundColor3  = Color3.fromRGB(50, 20, 20)
		hpBg.BorderSizePixel   = 0
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
	-- STAGE 1 – BEE LARVA (grub, no wings or legs)
	-- ════════════════════════════════════════════════════════════
	if stageIndex == 1 then
		-- Five cream-yellow oval segments along a gentle upward arc.
		local radii = { 0.26, 0.32, 0.37, 0.31, 0.24 }
		local posY  = { -0.04, -0.01, 0.0, 0.04, 0.09 }
		local posZ  = { -1.06, -0.55, 0.0, 0.50, 0.93 }

		local bodyR = radii[3] * bs
		local body  = makePart("HumanoidRootPart",
			Vector3.new(bodyR * 2, bodyR * 2, bodyR * 2), cfg.bodyColor)
		body.Shape      = Enum.PartType.Ball
		model.PrimaryPart = body

		for i = 1, 5 do
			if i ~= 3 then
				local r   = radii[i] * bs
				local pos = Vector3.new(0, posY[i] * bs, posZ[i] * bs)
				ball("Segment" .. i, r, (i == 5) and cfg.headColor or cfg.bodyColor, pos)
			end
		end

		-- Eyes on head segment
		local headPos = Vector3.new(0, posY[5] * bs, posZ[5] * bs)
		for _, sx in ipairs({ -1, 1 }) do
			ball("Eye" .. (sx > 0 and "R" or "L"), bs * 0.055, cfg.eyeColor,
				headPos + Vector3.new(sx * bs * 0.08, bs * 0.06, bs * 0.19),
				Enum.Material.Neon)
		end

		ball("GlowCore", bs * 0.21, cfg.glowColor, Vector3.new(0, 0, 0),
			Enum.Material.Neon, 0.35)

		local hpFill, nameLbl = attachHUD(body)
		return model, body, hpFill, nameLbl, parts
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGES 2-5 – PROPER BEE / HORNET
	-- ════════════════════════════════════════════════════════════
	local isHornet = (stageIndex >= 4)

	-- ── Body proportions ─────────────────────────────────────────
	-- Hornets: narrower waist (petiole), more elongated abdomen
	local thoraxR  = bs * 0.47
	local headR    = bs * 0.34
	local petR     = bs * (isHornet and 0.11 or 0.14)
	local abdR     = bs * (stageIndex == 5 and 0.62 or isHornet and 0.56 or 0.50)
	-- Abdomen elongation factor along Z (bees = slightly oval, hornets = noticeably tapered)
	local abdZmult = isHornet and 1.38 or 1.14

	-- Local positions (thorax = 0,0,0)
	local headPos = Vector3.new(0,  bs * 0.04,  thoraxR + headR * 0.72)
	local petPos  = Vector3.new(0, -bs * 0.10, -(thoraxR + petR * 0.86))
	local abdPos  = Vector3.new(0,  petPos.Y - bs * 0.04,
		petPos.Z - petR - abdR * 0.80)

	-- ── Thorax (PRIMARY) – Fabric material simulates fuzziness ───
	local thoraxD = thoraxR * 2
	local body    = makePart("HumanoidRootPart",
		Vector3.new(thoraxD, thoraxD, thoraxD), cfg.bodyColor, Enum.Material.Fabric)
	body.Shape      = Enum.PartType.Ball
	model.PrimaryPart = body

	-- ── Head ─────────────────────────────────────────────────────
	ball("Head", headR, cfg.headColor, headPos)

	-- ── Compound eyes (large, on head sides – signature bee feature) ──
	local eyeR = math.max(bs * 0.112, 0.13)
	for _, sx in ipairs({ -1, 1 }) do
		local sfx  = sx > 0 and "R" or "L"
		local epos = headPos + Vector3.new(sx * headR * 0.66, headR * 0.04, headR * 0.44)
		ball("Eye"   .. sfx, eyeR,         Color3.new(1, 1, 1), epos)
		ball("Pupil" .. sfx, eyeR * 0.68,  cfg.eyeColor,
			epos + Vector3.new(0, 0, eyeR * 0.48), Enum.Material.Neon)
	end

	-- ── Petiole (waist node) ─────────────────────────────────────
	ball("Petiole", petR, cfg.bodyColor, petPos)

	-- ── Abdomen (slightly oval; hornets are more elongated/tapered) ──
	local abdD  = abdR * 2
	local abd   = makePart("Abdomen",
		Vector3.new(abdD * 0.87, abdD * 0.93, abdD * abdZmult), cfg.bodyColor)
	abd.Shape   = Enum.PartType.Ball
	addPart(abd, CFrame.new(abdPos))

	-- ── Abdomen stripes (dark horizontal bands around the body) ──
	-- Stripes are flat discs in the XY plane, spaced along the Z axis.
	local stripeNum = isHornet and 3 or 2
	local stripeD   = abdD * 0.95   -- slightly wider than abdomen short axis → visible ring
	local stripeH   = bs * 0.085
	local stripeZ   = isHornet
		and { abdR * 0.42, abdR * 0.04, -abdR * 0.36 }
		or  { abdR * 0.28, -abdR * 0.20 }

	for si, dz in ipairs(stripeZ) do
		local sp = makePart("Stripe" .. si,
			Vector3.new(stripeD, stripeD, stripeH), cfg.stripeColor)
		sp.Shape = Enum.PartType.Ball    -- oblate sphere = natural-looking disc
		addPart(sp, CFrame.new(abdPos + Vector3.new(0, 0, dz)))
	end

	-- ── Antennae (short elbowed, bee-typical) ────────────────────
	local antW = math.max(bs * 0.050, 0.07)
	for _, sx in ipairs({ -1, 1 }) do
		local sfx      = sx > 0 and "R" or "L"
		local antBase  = headPos + Vector3.new(sx * headR * 0.26, headR * 0.38, headR * 0.26)
		local antElbow = antBase  + Vector3.new(sx * bs * 0.10, bs * 0.30, bs * 0.07)
		local antTip   = antElbow + Vector3.new(sx * bs * 0.04, -bs * 0.05, bs * 0.22)

		rod("Scape"     .. sfx, antBase,  antElbow, antW, cfg.antennaColor)
		rod("Funiculus" .. sfx, antElbow, antTip,   antW, cfg.antennaColor)
		ball("Club"     .. sfx, antW * 1.65, cfg.antennaColor, antTip)
	end

	-- ── 6 Legs (3 pairs from thorax) ─────────────────────────────
	local legR      = math.max(bs * 0.086, 0.10)
	if stageIndex == 5 then legR = bs * 0.100 end

	local attachX    = bs * 0.38
	local attachY    = -bs * 0.18
	local legPairZ   = { bs * 0.21, 0, -bs * 0.21 }
	local upperOutX  = bs * 0.44
	local upperUpY   = bs * 0.10
	local lowerOutX  = bs * 0.43
	local lowerDownY = bs * 0.36

	for _, side in ipairs({ -1, 1 }) do
		for pi, pz in ipairs(legPairZ) do
			local attach = Vector3.new(side * attachX, attachY, pz)
			local knee   = Vector3.new(side * (attachX + upperOutX), attachY + upperUpY, pz)
			local tip    = Vector3.new(side * (attachX + upperOutX + lowerOutX),
				attachY + upperUpY - lowerDownY, pz)
			local sfx    = tostring(pi) .. (side > 0 and "R" or "L")
			rod("UpperLeg" .. sfx, attach, knee, legR, cfg.legColor)
			rod("LowerLeg" .. sfx, knee,   tip,  legR, cfg.legColor)
		end
	end

	-- ── Worker Bee pollen baskets on rear legs (stage 3) ─────────
	if stageIndex == 3 and cfg.pollenColor then
		local polR = bs * 0.082
		local rz   = legPairZ[3]
		for _, side in ipairs({ -1, 1 }) do
			local knee = Vector3.new(side * (attachX + upperOutX), attachY + upperUpY, rz)
			local tip  = Vector3.new(side * (attachX + upperOutX + lowerOutX),
				attachY + upperUpY - lowerDownY, rz)
			-- Pollen basket sits on the outer face of the tibia, mid-segment
			local basketPos = knee:Lerp(tip, 0.45) + Vector3.new(side * polR * 1.4, 0, 0)
			ball("Pollen" .. (side > 0 and "R" or "L"), polR, cfg.pollenColor, basketPos)
		end
	end

	-- ── Stinger (stages 3-5) ─────────────────────────────────────
	if stageIndex >= 3 and cfg.stingerColor then
		local stW    = math.max(bs * 0.062, 0.08)
		-- Stinger protrudes from the rear tip of the abdomen in -Z direction
		local stBase = abdPos + Vector3.new(0, 0, -abdR * abdZmult * 0.84)
		local stTip  = abdPos + Vector3.new(0, 0, -abdR * abdZmult * 0.84 - bs * 0.18)
		rod("Stinger",    stBase, stTip, stW,         cfg.stingerColor)
		ball("StingTip",  stW * 0.65, cfg.stingerColor, stTip)
	end

	-- ── 4 Wings (all stages 2-5) ─────────────────────────────────
	-- Wings are flat parts (thin in X, elongated in Y=span and Z=chord).
	-- Roll angle ~22° tilts the spread end upward; yaw angles front/hind pairs.
	-- Hornets get 15% larger wings for a more imposing silhouette.
	local wScale = isHornet and 1.15 or 1.0
	local wMat   = Enum.Material.SmoothPlastic
	local wCol   = cfg.wingColor
	local wTrp   = 0.42

	-- { spanX, thicknessY, chordZ, posX, posY, posZ, yawDeg, rollDeg }
	local wingDefs = {
		{ bs*0.80*wScale, bs*0.04, bs*0.52*wScale,  bs*0.16,  bs*0.40,  bs*0.10, -8,  22 },  -- front-R
		{ bs*0.80*wScale, bs*0.04, bs*0.52*wScale, -bs*0.16,  bs*0.40,  bs*0.10,  8, -22 },  -- front-L
		{ bs*0.60*wScale, bs*0.03, bs*0.38*wScale,  bs*0.13,  bs*0.36, -bs*0.08, -5,  20 },  -- hind-R
		{ bs*0.60*wScale, bs*0.03, bs*0.38*wScale, -bs*0.13,  bs*0.36, -bs*0.08,  5, -20 },  -- hind-L
	}
	for wi, wd in ipairs(wingDefs) do
		local wp = makePart("Wing" .. wi,
			Vector3.new(wd[1], wd[2], wd[3]), wCol, wMat, wTrp)
		addPart(wp, CFrame.new(wd[4], wd[5], wd[6])
			* CFrame.Angles(0, math.rad(wd[7]), math.rad(wd[8])))
	end

	-- ── Queen Hornet crown ────────────────────────────────────────
	if stageIndex == 5 and cfg.crownColor then
		local crBase = headPos + Vector3.new(0, headR * 0.88, 0)
		ball("CrownBase",  bs * 0.105, cfg.crownColor, crBase)
		ball("CrownMid",   bs * 0.072, cfg.crownColor, crBase + Vector3.new(0,      bs*0.13, 0))
		ball("CrownLeft",  bs * 0.058, cfg.crownColor, crBase + Vector3.new(-bs*0.08, bs*0.09, 0))
		ball("CrownRight", bs * 0.058, cfg.crownColor, crBase + Vector3.new( bs*0.08, bs*0.09, 0))
	end

	-- ── Glow core ────────────────────────────────────────────────
	ball("GlowCore", bs * 0.30, cfg.glowColor, Vector3.new(0, 0, 0),
		Enum.Material.Neon, 0.35)

	-- ── Billboard HUD ────────────────────────────────────────────
	local hpFill, nameLbl = attachHUD(body)

	return model, body, hpFill, nameLbl, parts
end

return BeeModel
