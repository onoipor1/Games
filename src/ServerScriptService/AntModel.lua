-- AntModel.lua
-- Builds procedural ant companion models for each of the 5 Ant evolution stages.
--
-- All parts are Anchored=true with a local-space CFrame offset from the body (PrimaryPart).
-- InsectCompanion updates them every heartbeat:  part.CFrame = body.CFrame * offset
--
-- Stage 1 (Ant Larva)  – grub body: 5 oval segments in a gentle arc, tiny eyes, no legs
-- Stages 2-5           – proper ant: thorax (primary) + head + petiole + gaster,
--                        6 legs, elbowed antennae, mandibles
-- Stage 5 (Queen Ant)  – adds 4 membranous wings and a small crown decoration
--
-- Body layout (front = +Z, rear = -Z, right = +X):
--
--   [head] ──── [thorax/PRIMARY] ──── [petiole] ──── [gaster]
--      antennae ↗                 6 legs
--      mandibles ↙

local InsectData = require(game:GetService("ReplicatedStorage"):WaitForChild("InsectData"))

local AntModel = {}

-- ─────────────────────────────────────────
-- Per-stage visual config
-- ─────────────────────────────────────────
local STAGE_CFG = {
	[1] = {  -- Ant Larva: pale cream-yellow grub
		bodyColor    = Color3.fromRGB(238, 225, 168),
		headColor    = Color3.fromRGB(228, 212, 152),
		eyeColor     = Color3.fromRGB(85, 65, 45),    -- dull dark brown
		glowColor    = Color3.fromRGB(242, 232, 185),
	},
	[2] = {  -- Worker Ant: matte black
		bodyColor    = Color3.fromRGB(30, 28, 24),
		headColor    = Color3.fromRGB(38, 35, 30),
		legColor     = Color3.fromRGB(24, 22, 18),
		mandColor    = Color3.fromRGB(55, 42, 28),
		antennaColor = Color3.fromRGB(26, 24, 20),
		eyeColor     = Color3.fromRGB(55, 210, 55),   -- neon green
		glowColor    = Color3.fromRGB(55, 55, 55),
	},
	[3] = {  -- Soldier Ant: very deep black, red eyes
		bodyColor    = Color3.fromRGB(16, 14, 12),
		headColor    = Color3.fromRGB(20, 18, 15),
		legColor     = Color3.fromRGB(12, 10, 9),
		mandColor    = Color3.fromRGB(38, 28, 16),
		antennaColor = Color3.fromRGB(18, 16, 13),
		eyeColor     = Color3.fromRGB(255, 45, 45),   -- bright red
		glowColor    = Color3.fromRGB(38, 32, 28),
	},
	[4] = {  -- Fire Ant: vivid red, gold eyes
		bodyColor    = Color3.fromRGB(215, 38, 18),
		headColor    = Color3.fromRGB(228, 48, 22),
		legColor     = Color3.fromRGB(192, 32, 15),
		mandColor    = Color3.fromRGB(185, 62, 18),
		antennaColor = Color3.fromRGB(200, 35, 16),
		eyeColor     = Color3.fromRGB(255, 205, 0),   -- gold
		glowColor    = Color3.fromRGB(255, 85, 38),
		accentColor  = Color3.fromRGB(255, 110, 22),  -- orange gaster stripe
	},
	[5] = {  -- Queen Ant: dark amber-orange, gold crown, translucent wings
		bodyColor    = Color3.fromRGB(188, 92, 20),
		headColor    = Color3.fromRGB(205, 105, 25),
		legColor     = Color3.fromRGB(168, 82, 17),
		mandColor    = Color3.fromRGB(158, 72, 14),
		antennaColor = Color3.fromRGB(178, 87, 18),
		eyeColor     = Color3.fromRGB(255, 222, 0),   -- bright gold
		glowColor    = Color3.fromRGB(245, 145, 42),
		wingColor    = Color3.fromRGB(185, 210, 235), -- pale sky-blue, translucent
		crownColor   = Color3.fromRGB(255, 215, 0),   -- gold
	},
}

-- ─────────────────────────────────────────
-- Build
-- ─────────────────────────────────────────
function AntModel.Build(stageIndex)
	local stageDef = InsectData.GetStage("Ant", stageIndex)
	if not stageDef then return nil end

	local cfg      = STAGE_CFG[stageIndex] or STAGE_CFG[2]
	local baseSize = math.clamp(stageDef.size * 2.5, 1.2, 6.0)
	local bs       = baseSize

	local model = Instance.new("Model")
	model.Name  = "Companion"

	local parts = {}   -- { part, offset }

	-- ── Part factories ───────────────────────────────────────────
	local function makePart(name, size, color, mat, transp)
		local p         = Instance.new("Part")
		p.Name          = name
		p.Size          = size
		p.Color         = color
		p.Material      = mat or Enum.Material.SmoothPlastic
		p.Anchored      = true
		p.CanCollide    = false
		p.CastShadow    = false
		p.Transparency  = transp or 0
		p.Parent        = model
		return p
	end

	local function addPart(p, offsetCF)
		table.insert(parts, { part = p, offset = offsetCF })
	end

	-- Ball helper: placed at a local-space position
	local function ball(name, radius, color, pos, mat, transp)
		local d = radius * 2
		local p = makePart(name, Vector3.new(d, d, d), color, mat, transp)
		p.Shape = Enum.PartType.Ball
		addPart(p, CFrame.new(pos))
	end

	-- Rod segment between two local-space points (uses CFrame.new(mid, from))
	local function rod(name, from, to, radius, color, mat, transp)
		local len = (to - from).Magnitude
		if len < 0.01 then return end
		local mid = from:Lerp(to, 0.5)
		local p   = makePart(name, Vector3.new(radius, radius, len), color, mat, transp)
		addPart(p, CFrame.new(mid, from))
	end

	-- ── HUD (shared by all stages) ───────────────────────────────
	local function attachHUD(body)
		local bb         = Instance.new("BillboardGui")
		bb.Name          = "CompanionHUD"
		bb.Size          = UDim2.new(0, 120, 0, 38)
		bb.StudsOffset   = Vector3.new(0, bs * 0.95 + 1.5, 0)
		bb.AlwaysOnTop   = false
		bb.MaxDistance   = 60
		bb.Parent        = body

		local nameLbl    = Instance.new("TextLabel")
		nameLbl.Name     = "NameLabel"
		nameLbl.Size     = UDim2.new(1, 0, 0, 18)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = Color3.new(1, 1, 1)
		nameLbl.Font     = Enum.Font.GothamBold
		nameLbl.TextScaled = true
		nameLbl.Parent   = bb

		local hpBg       = Instance.new("Frame")
		hpBg.Name        = "HPBg"
		hpBg.Size        = UDim2.new(1, 0, 0, 10)
		hpBg.Position    = UDim2.new(0, 0, 0, 20)
		hpBg.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
		hpBg.BorderSizePixel  = 0
		hpBg.Parent      = bb
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

		local hpFill     = Instance.new("Frame")
		hpFill.Name      = "HPFill"
		hpFill.Size      = UDim2.new(1, 0, 1, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
		hpFill.BorderSizePixel  = 0
		hpFill.Parent    = hpBg
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

		return hpFill, nameLbl
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGE 1 – ANT LARVA (grub body, no legs)
	-- ════════════════════════════════════════════════════════════
	if stageIndex == 1 then
		-- Five oval segments arranged along a gentle upward arc.
		-- The middle segment (s3) is the PrimaryPart / body anchor.
		--
		--  s5-head           ← +Z (front)
		--   s4
		--   s3 ← BODY
		--   s2
		--  s1-tail           ← -Z (rear)
		--
		-- Radii taper from largest at centre toward each end.
		local radii = { 0.28, 0.34, 0.40, 0.34, 0.27 }  -- * bs
		local posY  = { -0.04, -0.01, 0.0, 0.04, 0.10 } -- slight upward arc
		local posZ  = { -1.10, -0.58, 0.0, 0.52, 0.98 } -- along body axis

		-- s3 = body/PRIMARY (no offset entry)
		local bodyR = radii[3] * bs
		local body  = makePart("HumanoidRootPart",
			Vector3.new(bodyR * 2, bodyR * 2, bodyR * 2), cfg.bodyColor)
		body.Shape      = Enum.PartType.Ball
		model.PrimaryPart = body

		-- Other segments stored as offsets
		for i = 1, 5 do
			if i ~= 3 then
				local r   = radii[i] * bs
				local pos = Vector3.new(0, posY[i] * bs, posZ[i] * bs)
				local col = (i == 5) and cfg.headColor or cfg.bodyColor
				ball("Segment" .. i, r, col, pos)
			end
		end

		-- Tiny eyes on head segment (s5)
		local headPos = Vector3.new(0, posY[5] * bs, posZ[5] * bs)
		local eyeR    = bs * 0.06
		for _, sx in ipairs({ -1, 1 }) do
			local ePos = headPos + Vector3.new(sx * bs * 0.09, bs * 0.07, bs * 0.22)
			ball("Eye" .. (sx > 0 and "R" or "L"), eyeR, cfg.eyeColor, ePos,
				Enum.Material.Neon)
		end

		-- Glow core
		ball("GlowCore", bs * 0.22, cfg.glowColor, Vector3.new(0, 0, 0),
			Enum.Material.Neon, 0.35)

		local hpFill, nameLbl = attachHUD(body)
		return model, body, hpFill, nameLbl, parts
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGES 2-5 – PROPER ANT
	-- ════════════════════════════════════════════════════════════

	-- ── Body proportions ─────────────────────────────────────────
	local thoraxR  = bs * 0.44   -- thorax radius (PRIMARY)
	local headR    = bs * 0.40   -- head radius
	local petioleR = bs * 0.16   -- narrow waist "node"
	local gasterR  = bs * 0.54   -- large abdomen

	-- Soldier ant: enlarge head (big mandibles), Queen: huge gaster
	if stageIndex == 3 then
		headR   = bs * 0.44   -- proportionally bigger head for mandibles
		gasterR = bs * 0.52
	elseif stageIndex == 5 then
		gasterR = bs * 0.64   -- queen has enormous abdomen
	end

	-- Local-space positions (thorax = 0,0,0)
	local headPos    = Vector3.new(0,  bs * 0.06,  thoraxR + headR   * 0.72)
	local petiolePos = Vector3.new(0, -bs * 0.13, -(thoraxR + petioleR * 0.95))
	local gasterPos  = Vector3.new(petiolePos.X,
		petiolePos.Y - bs * 0.04,
		petiolePos.Z - petioleR - gasterR * 0.82)

	-- ── Thorax (PRIMARY – no offset entry) ───────────────────────
	local thoraxD = thoraxR * 2
	local body    = makePart("HumanoidRootPart",
		Vector3.new(thoraxD, thoraxD, thoraxD), cfg.bodyColor)
	body.Shape      = Enum.PartType.Ball
	model.PrimaryPart = body

	-- ── Head ─────────────────────────────────────────────────────
	ball("Head", headR, cfg.headColor, headPos)

	-- ── Petiole (waist node) ─────────────────────────────────────
	ball("Petiole", petioleR, cfg.bodyColor, petiolePos)

	-- ── Gaster (abdomen) ─────────────────────────────────────────
	local gasterD = gasterR * 2
	local gaster  = makePart("Gaster",
		Vector3.new(gasterD * 0.88, gasterD, gasterD * 0.95), cfg.bodyColor)
	gaster.Shape = Enum.PartType.Ball
	addPart(gaster, CFrame.new(gasterPos))

	-- Fire ant: accent stripe on gaster
	if stageIndex == 4 and cfg.accentColor then
		local sw = gasterR * 0.55
		local st = gasterR * 0.18
		ball("GasterStripe", st, cfg.accentColor,
			gasterPos + Vector3.new(0, gasterR * 0.70, 0))
	end

	-- ── Eyes (compound eyes on front-sides of head) ───────────────
	local eyeR = math.max(bs * 0.068, 0.09)
	for _, sx in ipairs({ -1, 1 }) do
		local epos = headPos + Vector3.new(sx * headR * 0.58, headR * 0.08, headR * 0.62)
		ball("Eye" .. (sx > 0 and "R" or "L"), eyeR, Color3.new(1, 1, 1), epos)
		local ppos = epos + Vector3.new(0, 0, eyeR * 0.55)
		ball("Pupil" .. (sx > 0 and "R" or "L"), eyeR * 0.62, cfg.eyeColor, ppos,
			Enum.Material.Neon)
	end

	-- ── Mandibles ────────────────────────────────────────────────
	-- Soldier ant gets extra-long mandibles; other stages get smaller ones.
	local mandLen  = (stageIndex == 3) and bs * 0.52 or bs * 0.32
	local mandSprd = (stageIndex == 3) and bs * 0.38 or bs * 0.24
	local mandW    = math.max(bs * 0.08, 0.10)

	for _, sx in ipairs({ -1, 1 }) do
		local mBase = headPos + Vector3.new(sx * headR * 0.30, -headR * 0.28, headR * 0.68)
		local mTip  = mBase + Vector3.new(sx * mandSprd, -bs * 0.14, mandLen)
		rod("Mand" .. (sx > 0 and "R" or "L"), mBase, mTip, mandW, cfg.mandColor)
	end

	-- ── Antennae (elbowed: scape → pedicel → funiculus) ──────────
	local antW = math.max(bs * 0.055, 0.08)
	for _, sx in ipairs({ -1, 1 }) do
		-- Scape base: top-front of head, angled out
		local antBase  = headPos + Vector3.new(sx * headR * 0.32, headR * 0.38, headR * 0.30)
		-- Elbow (scape tip): up and outward
		local antElbow = antBase + Vector3.new(sx * bs * 0.14, bs * 0.40, bs * 0.12)
		-- Funiculus tip: bends forward and slightly down from elbow
		local antTip   = antElbow + Vector3.new(sx * bs * 0.06, -bs * 0.10, bs * 0.34)

		local sfx = sx > 0 and "R" or "L"
		rod("Scape" .. sfx,    antBase,  antElbow, antW, cfg.antennaColor)
		rod("Funiculus" .. sfx, antElbow, antTip,   antW, cfg.antennaColor)

		-- Small club at tip (ball)
		ball("AntClub" .. sfx, antW * 1.5, cfg.antennaColor, antTip)
	end

	-- ── 6 Legs (3 pairs from thorax) ─────────────────────────────
	--  Each leg: upper (femur) + lower (tibia+tarsus), forming a slight knee-up shape.
	local legR       = math.max(bs * 0.095, 0.10)
	if stageIndex == 5 then legR = bs * 0.11 end   -- queen: slightly thicker

	local attachX    = bs * 0.36
	local attachY    = -bs * 0.18
	-- Three Z positions for front/middle/rear leg pairs
	local legPairZ   = { bs * 0.22, 0, -bs * 0.22 }

	local upperOutX  = bs * 0.44   -- knee goes this far outward from attach
	local upperUpY   = bs * 0.12   -- knee rises this much above attach
	local lowerOutX  = bs * 0.42   -- tip goes this far out from knee
	local lowerDownY = bs * 0.38   -- tip drops this much below knee

	for _, side in ipairs({ -1, 1 }) do
		for pi, pz in ipairs(legPairZ) do
			local attach = Vector3.new(side * attachX, attachY, pz)
			local knee   = Vector3.new(side * (attachX + upperOutX), attachY + upperUpY, pz)
			local tip    = Vector3.new(side * (attachX + upperOutX + lowerOutX),
				attachY + upperUpY - lowerDownY, pz)

			local sfx = tostring(pi) .. (side > 0 and "R" or "L")
			rod("UpperLeg" .. sfx, attach, knee, legR, cfg.legColor)
			rod("LowerLeg" .. sfx, knee,   tip,  legR, cfg.legColor)
		end
	end

	-- ── Queen: 4 Membranous Wings + Crown ────────────────────────
	if stageIndex == 5 then
		-- Wings originate above the thorax.
		-- Each wing is a thin flat block, tilted outward ~36° from vertical.
		-- Front wings (larger) are at a slight forward angle; hind wings lean back.
		local wingMat  = Enum.Material.SmoothPlastic
		local wingTransp = 0.40

		-- { width/thin, height/span, length/chord, posX, posY, posZ, rollDeg, yawDeg }
		local wingDefs = {
			{ bs*0.04, bs*0.55, bs*0.85,  bs*0.18, bs*0.40,  bs*0.18, -38,  -12 },  -- front-right
			{ bs*0.04, bs*0.55, bs*0.85, -bs*0.18, bs*0.40,  bs*0.18,  38,  -12 },  -- front-left
			{ bs*0.03, bs*0.40, bs*0.62,  bs*0.14, bs*0.36, -bs*0.14, -33,   10 },  -- hind-right
			{ bs*0.03, bs*0.40, bs*0.62, -bs*0.14, bs*0.36, -bs*0.14,  33,   10 },  -- hind-left
		}
		for wi, wd in ipairs(wingDefs) do
			local wp = makePart("Wing" .. wi,
				Vector3.new(wd[1], wd[2], wd[3]), cfg.wingColor, wingMat, wingTransp)
			local offsetCF = CFrame.new(wd[4], wd[5], wd[6])
				* CFrame.Angles(0, math.rad(wd[8]), math.rad(wd[7]))
			addPart(wp, offsetCF)
		end

		-- Crown: small gold spheres stacked above the head
		local crownBase = headPos + Vector3.new(0, headR * 0.88, 0)
		ball("CrownBase",  bs * 0.12, cfg.crownColor, crownBase)
		-- Three spikes
		ball("CrownMid",   bs * 0.08, cfg.crownColor, crownBase + Vector3.new(0,        bs * 0.14, 0))
		ball("CrownLeft",  bs * 0.065, cfg.crownColor, crownBase + Vector3.new(-bs*0.09, bs * 0.10, 0))
		ball("CrownRight", bs * 0.065, cfg.crownColor, crownBase + Vector3.new( bs*0.09, bs * 0.10, 0))
	end

	-- ── Glow core ────────────────────────────────────────────────
	ball("GlowCore", bs * 0.32, cfg.glowColor, Vector3.new(0, 0, 0),
		Enum.Material.Neon, 0.35)

	-- ── Billboard HUD ────────────────────────────────────────────
	local hpFill, nameLbl = attachHUD(body)

	return model, body, hpFill, nameLbl, parts
end

return AntModel
