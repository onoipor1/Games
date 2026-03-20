-- SpiderModel.lua
-- Builds procedural spider companion models for each of the 5 Spider evolution stages.
--
-- All parts are Anchored=true and stored with a local-space CFrame offset from the
-- cephalothorax (body / PrimaryPart).  InsectCompanion updates them each heartbeat:
--   part.CFrame = body.CFrame * offset
--
-- Geometry per spider:
--   • Cephalothorax  – front round body section (the PrimaryPart / move anchor)
--   • Abdomen        – larger oval behind the cepha
--   • 8 legs         – 4 per side, each with upper (femur) + lower (tibia) segments
--   • Chelicerae     – two short downward fangs (stage 2+)
--   • Eyes           – 6 (stage 1) or 8 (stage 2+) eyes with glowing neon pupils
--   • Abdominal stripe – decorative accent part (stage 3+)
--   • Glow core      – neon inner sphere

local InsectData = require(game:GetService("ReplicatedStorage"):WaitForChild("InsectData"))

local SpiderModel = {}

-- ─────────────────────────────────────────
-- Per-stage visual config
-- ─────────────────────────────────────────
local STAGE_CFG = {
	[1] = {  -- Spiderling: small, bright red
		cephaColor = Color3.fromRGB(210, 55, 55),
		abdColor   = Color3.fromRGB(185, 35, 35),
		legColor   = Color3.fromRGB(170, 35, 35),
		eyeColor   = Color3.fromRGB(60, 255, 60),   -- neon green
		glowColor  = Color3.fromRGB(255, 90, 90),
		numEyes    = 6,
	},
	[2] = {  -- House Spider: warm reddish-brown
		cephaColor = Color3.fromRGB(145, 80, 30),
		abdColor   = Color3.fromRGB(110, 55, 20),
		legColor   = Color3.fromRGB(125, 65, 25),
		eyeColor   = Color3.fromRGB(255, 225, 40),  -- amber
		glowColor  = Color3.fromRGB(185, 105, 45),
		numEyes    = 8,
	},
	[3] = {  -- Wolf Spider: dark earth-brown, orange eye glow
		cephaColor = Color3.fromRGB(95, 65, 25),
		abdColor   = Color3.fromRGB(75, 50, 18),
		legColor   = Color3.fromRGB(85, 58, 22),
		eyeColor   = Color3.fromRGB(255, 145, 0),   -- orange
		glowColor  = Color3.fromRGB(255, 105, 20),
		numEyes    = 8,
	},
	[4] = {  -- Tarantula: jet black body, orange-tipped legs
		cephaColor  = Color3.fromRGB(18, 18, 18),
		abdColor    = Color3.fromRGB(12, 12, 12),
		legColor    = Color3.fromRGB(25, 14, 4),
		legTipColor = Color3.fromRGB(210, 80, 18),  -- orange tips
		eyeColor    = Color3.fromRGB(255, 80, 20),  -- orange-red
		glowColor   = Color3.fromRGB(90, 22, 8),
		numEyes     = 8,
	},
	[5] = {  -- Goliath Spider: colossal dark-brown, blood-red glowing eyes
		cephaColor = Color3.fromRGB(65, 38, 12),
		abdColor   = Color3.fromRGB(48, 28, 8),
		legColor   = Color3.fromRGB(55, 32, 10),
		eyeColor   = Color3.fromRGB(255, 0, 0),     -- blood red
		glowColor  = Color3.fromRGB(210, 22, 22),
		numEyes    = 8,
	},
}

-- ─────────────────────────────────────────
-- Build spider model for the given stage
-- Returns: model, body (PrimaryPart), hpFill, nameLbl, parts
--   parts = { {part=Part, offset=CFrame}, … }
-- ─────────────────────────────────────────
function SpiderModel.Build(stageIndex)
	local stageDef = InsectData.GetStage("Spider", stageIndex)
	if not stageDef then return nil end

	local cfg      = STAGE_CFG[stageIndex] or STAGE_CFG[1]
	local baseSize = math.clamp(stageDef.size * 2.5, 1.2, 6.0)

	local model = Instance.new("Model")
	model.Name  = "Companion"

	local parts = {}   -- {part, offset}

	-- ── Helpers ──────────────────────────────────────────────────
	local function makePart(name, size, color, mat, transp)
		local p          = Instance.new("Part")
		p.Name           = name
		p.Size           = size
		p.Color          = color
		p.Material       = mat or Enum.Material.SmoothPlastic
		p.Anchored       = true
		p.CanCollide     = false
		p.CastShadow     = false
		p.Transparency   = transp or 0
		p.Parent         = model
		return p
	end

	local function addPart(p, offsetCF)
		table.insert(parts, { part = p, offset = offsetCF })
	end

	-- Place a segment from localFrom → localTo (both in body-local space).
	-- Uses CFrame.new(mid, localFrom) so the part fills exactly that span.
	local function segment(name, localFrom, localTo, radius, color, mat, transp)
		local len = (localTo - localFrom).Magnitude
		if len < 0.01 then return end
		local mid = localFrom:Lerp(localTo, 0.5)
		local p   = makePart(name, Vector3.new(radius, radius, len), color, mat, transp)
		-- CFrame.new(mid, localFrom): -Z faces localFrom → +Z axis spans toward localTo
		addPart(p, CFrame.new(mid, localFrom))
	end

	-- ── Cephalothorax (primary / movement anchor) ────────────────
	local cepha = makePart("HumanoidRootPart",
		Vector3.new(baseSize, baseSize * 0.82, baseSize),
		cfg.cephaColor)
	cepha.Shape      = Enum.PartType.Ball
	model.PrimaryPart = cepha
	-- Cepha IS the body – no offset entry needed.

	-- ── Abdomen ──────────────────────────────────────────────────
	local abdW  = baseSize * 1.10
	local abdH  = baseSize * 1.20
	local abdL  = baseSize * 1.05
	local abdPos = Vector3.new(0, -baseSize * 0.08, -baseSize * 0.90)
	local abd = makePart("Abdomen", Vector3.new(abdW, abdH, abdL), cfg.abdColor)
	abd.Shape = Enum.PartType.Ball
	addPart(abd, CFrame.new(abdPos))

	-- ── Abdominal stripe decoration (Wolf Spider / Tarantula) ────
	if stageIndex >= 3 then
		local stripeColor = (stageIndex == 4)
			and Color3.fromRGB(205, 85, 20)  -- tarantula orange
			or  Color3.fromRGB(90, 62, 22)   -- wolf spider lighter
		local sw = baseSize * 0.22
		local st = baseSize * 0.10
		local sl = abdL * 0.65
		local stripePos = abdPos + Vector3.new(0, abdH * 0.52, 0)
		local stripe = makePart("AbdStripe", Vector3.new(sw, st, sl), stripeColor)
		addPart(stripe, CFrame.new(stripePos))
	end

	-- ── Chelicerae / Fangs (House Spider and above) ──────────────
	if stageIndex >= 2 then
		local fangW     = math.max(baseSize * 0.08, 0.12)
		local fangLen   = baseSize * 0.38
		local fangColor = Color3.fromRGB(75, 40, 12)
		for _, sx in ipairs({ -1, 1 }) do
			local fBase = Vector3.new(sx * baseSize * 0.14, -baseSize * 0.27, baseSize * 0.44)
			local fTip  = fBase + Vector3.new(sx * fangLen * 0.28, -fangLen * 0.82, fangLen * 0.35)
			segment("Fang" .. (sx > 0 and "R" or "L"), fBase, fTip, fangW, fangColor)
		end
	end

	-- ── 8 Legs: 4 per side, 2 segments each (femur + tibia) ─────
	--
	--  Legs attach on the cephalothorax sides and form a classic
	--  "M / W" silhouette when viewed from the front:
	--
	--       ↑ knee
	--      /         upper (femur): angled UP and OUT
	-- body●
	--      \         lower (tibia): angled DOWN and further OUT
	--       ↓ tip
	--
	local legRadius = math.max(baseSize * 0.11, 0.12)
	if stageIndex == 4 then legRadius = baseSize * 0.155 end  -- tarantula: thick
	if stageIndex == 5 then legRadius = baseSize * 0.135 end  -- goliath: very thick

	-- Normalised Z positions for 4 leg pairs along the body
	local attachZFracs = { 0.28, 0.09, -0.09, -0.28 }
	local attachX      = baseSize * 0.38   -- lateral attachment on body
	local attachY      = -baseSize * 0.18  -- slightly below body center

	-- Upper leg (femur): tip = "knee" position
	local upperOutX  = baseSize * 0.52   -- how far knee goes out in X from attach
	local upperUpY   = baseSize * 0.30   -- how far knee rises in Y

	-- Lower leg (tibia): from knee to tip
	local lowerOutX  = baseSize * 0.54   -- further X from knee to tip
	local lowerDownY = baseSize * 0.48   -- how far tip drops below knee

	for _, side in ipairs({ -1, 1 }) do       -- -1 = left, 1 = right
		for i, zFrac in ipairs(attachZFracs) do
			local bz     = zFrac * baseSize
			local attach = Vector3.new(side * attachX, attachY, bz)
			local knee   = Vector3.new(side * (attachX + upperOutX), attachY + upperUpY, bz)
			local tip    = Vector3.new(side * (attachX + upperOutX + lowerOutX), attachY + upperUpY - lowerDownY, bz)

			local suffix = tostring(i) .. (side > 0 and "R" or "L")
			segment("UpperLeg" .. suffix, attach, knee, legRadius, cfg.legColor)
			segment("LowerLeg" .. suffix, knee,   tip,  legRadius, cfg.legColor)

			-- Tarantula orange leg tips (last 40% of tibia)
			if stageIndex == 4 and cfg.legTipColor then
				local tipStart = knee:Lerp(tip, 0.60)
				segment("LegTip" .. suffix, tipStart, tip, legRadius * 1.05, cfg.legTipColor)
			end
		end
	end

	-- ── Eyes ─────────────────────────────────────────────────────
	--  8-eye arrangement: main row (4), upper pair (2), side pair (2)
	local eyeR     = math.max(baseSize * 0.072, 0.10)
	local numEyes  = cfg.numEyes

	local eyePositions = {
		-- Main row (median eyes + posterior median) — 4 total
		Vector3.new(-baseSize * 0.215, -baseSize * 0.055, baseSize * 0.405),
		Vector3.new(-baseSize * 0.068,  baseSize * 0.045, baseSize * 0.435),
		Vector3.new( baseSize * 0.068,  baseSize * 0.045, baseSize * 0.435),
		Vector3.new( baseSize * 0.215, -baseSize * 0.055, baseSize * 0.405),
	}
	-- Upper pair (anterior lateral eyes)
	if numEyes >= 6 then
		table.insert(eyePositions, Vector3.new(-baseSize * 0.125,  baseSize * 0.185, baseSize * 0.385))
		table.insert(eyePositions, Vector3.new( baseSize * 0.125,  baseSize * 0.185, baseSize * 0.385))
	end
	-- Side pair (posterior lateral eyes)
	if numEyes >= 8 then
		table.insert(eyePositions, Vector3.new(-baseSize * 0.315,  baseSize * 0.075, baseSize * 0.305))
		table.insert(eyePositions, Vector3.new( baseSize * 0.315,  baseSize * 0.075, baseSize * 0.305))
	end

	for ei = 1, math.min(numEyes, #eyePositions) do
		local epos = eyePositions[ei]

		local eye      = makePart("Eye" .. ei, Vector3.new(eyeR * 2, eyeR * 2, eyeR * 2), Color3.new(1, 1, 1))
		eye.Shape      = Enum.PartType.Ball
		addPart(eye, CFrame.new(epos))

		local pr       = eyeR * 0.62
		local pupil    = makePart("Pupil" .. ei, Vector3.new(pr * 2, pr * 2, pr * 2), cfg.eyeColor)
		pupil.Shape    = Enum.PartType.Ball
		pupil.Material = Enum.Material.Neon
		addPart(pupil, CFrame.new(epos + Vector3.new(0, 0, eyeR * 0.55)))
	end

	-- ── Glow core ────────────────────────────────────────────────
	local gs   = baseSize * 0.36
	local glow = makePart("GlowCore", Vector3.new(gs, gs, gs), cfg.glowColor,
		Enum.Material.Neon, 0.35)
	glow.Shape = Enum.PartType.Ball
	addPart(glow, CFrame.new(0, 0, 0))

	-- ── Billboard HUD ────────────────────────────────────────────
	local bb          = Instance.new("BillboardGui")
	bb.Name           = "CompanionHUD"
	bb.Size           = UDim2.new(0, 120, 0, 38)
	bb.StudsOffset    = Vector3.new(0, baseSize * 0.95 + 1.5, 0)
	bb.AlwaysOnTop    = false
	bb.MaxDistance    = 60
	bb.Parent         = cepha

	local nameLbl     = Instance.new("TextLabel")
	nameLbl.Name      = "NameLabel"
	nameLbl.Size      = UDim2.new(1, 0, 0, 18)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.Font      = Enum.Font.GothamBold
	nameLbl.TextScaled = true
	nameLbl.Parent    = bb

	local hpBg        = Instance.new("Frame")
	hpBg.Name         = "HPBg"
	hpBg.Size         = UDim2.new(1, 0, 0, 10)
	hpBg.Position     = UDim2.new(0, 0, 0, 20)
	hpBg.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
	hpBg.BorderSizePixel  = 0
	hpBg.Parent       = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

	local hpFill      = Instance.new("Frame")
	hpFill.Name       = "HPFill"
	hpFill.Size       = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	hpFill.BorderSizePixel  = 0
	hpFill.Parent     = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

	return model, cepha, hpFill, nameLbl, parts
end

return SpiderModel
