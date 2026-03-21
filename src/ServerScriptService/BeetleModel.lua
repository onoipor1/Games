-- BeetleModel.lua
-- Builds procedural beetle companion models for each of the 5 Beetle evolution stages.
--
-- All parts are Anchored=true with a local-space CFrame offset from the body (PrimaryPart).
-- InsectCompanion updates them every heartbeat:  part.CFrame = body.CFrame * offset
--
-- Stage 1  Beetle Egg   – smooth oval egg, tiny micropyle spot, no legs
-- Stage 2  Grub         – fat C-shaped larva: 5 segments, brown head, tiny leg nubs
-- Stages 3-5            – proper beetle:
--                          Elytra (PRIMARY, domed shell) + Pronotum + Head
--                          6 sprawling legs, elbowed antennae, center-seam line
-- Stage 3  Dung Beetle  – compact round shell, single curved horn on pronotum
-- Stage 4  Stag Beetle  – elongated, enormous forked stag-antler mandibles
-- Stage 5  Titan Beetle – massive wide shell, thick pincer mandibles, imposing bulk
--
-- Body axis: front = +Z (head), rear = -Z (elytra tip)
-- Elytra is the PrimaryPart for stages 3-5 (largest, most central visual element)

local InsectData = require(game:GetService("ReplicatedStorage"):WaitForChild("InsectData"))

local BeetleModel = {}

-- ─────────────────────────────────────────
-- Per-stage visual config
-- ─────────────────────────────────────────
local STAGE_CFG = {
	[1] = {  -- Beetle Egg: off-white with a hint of cream
		shellColor = Color3.fromRGB(242, 238, 224),
		spotColor  = Color3.fromRGB(192, 184, 163),
		glowColor  = Color3.fromRGB(248, 245, 232),
	},
	[2] = {  -- Grub: cream body, warm-brown head
		bodyColor   = Color3.fromRGB(232, 218, 156),
		headColor   = Color3.fromRGB(160, 100, 36),
		legNubColor = Color3.fromRGB(198, 182, 136),
		eyeColor    = Color3.fromRGB(52, 32, 16),
		glowColor   = Color3.fromRGB(238, 226, 172),
	},
	[3] = {  -- Dung Beetle: warm amber-brown
		shellColor   = Color3.fromRGB(150, 86, 30),
		headColor    = Color3.fromRGB(130, 70, 24),
		legColor     = Color3.fromRGB(115, 60, 18),
		antennaColor = Color3.fromRGB(125, 65, 22),
		eyeColor     = Color3.fromRGB(22, 14, 6),
		seamColor    = Color3.fromRGB(95, 50, 14),
		hornColor    = Color3.fromRGB(136, 75, 26),
		glowColor    = Color3.fromRGB(195, 115, 40),
	},
	[4] = {  -- Stag Beetle: dark reddish-brown, shiny shell
		shellColor   = Color3.fromRGB(112, 50, 16),
		headColor    = Color3.fromRGB(26, 16, 8),
		legColor     = Color3.fromRGB(20, 12, 5),
		antennaColor = Color3.fromRGB(24, 15, 7),
		eyeColor     = Color3.fromRGB(215, 45, 15),  -- bright red
		seamColor    = Color3.fromRGB(65, 25, 7),
		mandColor    = Color3.fromRGB(108, 46, 14),  -- matches shell
		glowColor    = Color3.fromRGB(172, 72, 20),
	},
	[5] = {  -- Titan Beetle: near-black, colossal
		shellColor   = Color3.fromRGB(15, 13, 11),
		headColor    = Color3.fromRGB(9, 7, 5),
		legColor     = Color3.fromRGB(7, 5, 3),
		antennaColor = Color3.fromRGB(11, 9, 7),
		eyeColor     = Color3.fromRGB(255, 55, 0),   -- vivid orange-red
		seamColor    = Color3.fromRGB(5, 3, 1),
		mandColor    = Color3.fromRGB(16, 12, 7),
		glowColor    = Color3.fromRGB(52, 35, 16),
	},
}

-- ─────────────────────────────────────────
-- Build
-- ─────────────────────────────────────────
function BeetleModel.Build(stageIndex)
	local stageDef = InsectData.GetStage("Beetle", stageIndex)
	if not stageDef then return nil end

	local cfg      = STAGE_CFG[stageIndex] or STAGE_CFG[3]
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
	-- STAGE 1 – BEETLE EGG
	-- ════════════════════════════════════════════════════════════
	if stageIndex == 1 then
		-- Smooth oval egg, slightly taller than wide, pointed toward top.
		local r    = bs * 0.44
		local body = makePart("HumanoidRootPart",
			Vector3.new(r * 1.88, r * 2.20, r * 1.92), cfg.shellColor)
		body.Shape      = Enum.PartType.Ball
		model.PrimaryPart = body

		-- Tiny micropyle dot at the top of the egg
		ball("Micropyle", bs * 0.055, cfg.spotColor, Vector3.new(0, r * 1.06, 0))

		ball("GlowCore", bs * 0.22, cfg.glowColor, Vector3.new(0, 0, 0),
			Enum.Material.Neon, 0.35)

		local hpFill, nameLbl = attachHUD(body)
		return model, body, hpFill, nameLbl, parts
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGE 2 – GRUB (larva)
	-- ════════════════════════════════════════════════════════════
	if stageIndex == 2 then
		-- Five plump cream segments in a deeper C-curve than the bee/ant larva.
		-- Brown head at the +Z (front) end with tiny mandible nubs.
		local radii = { 0.28, 0.36, 0.43, 0.37, 0.29 }
		local posY  = { -0.30, -0.15, 0.0, 0.15, 0.28 }  -- deeper C than bee/ant
		local posZ  = { -1.00, -0.52, 0.0, 0.50, 0.95 }

		local bodyR = radii[3] * bs
		local body  = makePart("HumanoidRootPart",
			Vector3.new(bodyR * 2, bodyR * 2, bodyR * 2), cfg.bodyColor)
		body.Shape      = Enum.PartType.Ball
		model.PrimaryPart = body

		for i = 1, 5 do
			if i ~= 3 then
				local r   = radii[i] * bs
				local pos = Vector3.new(0, posY[i] * bs, posZ[i] * bs)
				ball("Seg" .. i, r, (i == 5) and cfg.headColor or cfg.bodyColor, pos)
			end
		end

		-- Eyes on head segment
		local headPos = Vector3.new(0, posY[5] * bs, posZ[5] * bs)
		for _, sx in ipairs({ -1, 1 }) do
			ball("Eye" .. (sx > 0 and "R" or "L"), bs * 0.062, cfg.eyeColor,
				headPos + Vector3.new(sx * bs * 0.10, bs * 0.06, bs * 0.22),
				Enum.Material.Neon)
		end

		-- Mandible nubs (two short stubs from head front)
		local nubW = bs * 0.068
		for _, sx in ipairs({ -1, 1 }) do
			local nBase = headPos + Vector3.new(sx * bs * 0.09, -bs * 0.10, bs * 0.24)
			local nTip  = nBase + Vector3.new(sx * bs * 0.07, -bs * 0.06, bs * 0.11)
			rod("MandNub" .. (sx > 0 and "R" or "L"), nBase, nTip, nubW, cfg.headColor)
		end

		-- Vestigial thoracic leg nubs on the three segments closest to head
		-- (segments 2, 3, 4 — the front half of the body)
		local nubR = bs * 0.062
		for si, segI in ipairs({ 2, 3, 4 }) do
			local segPos = Vector3.new(0, posY[segI] * bs, posZ[segI] * bs)
			for _, sx in ipairs({ -1, 1 }) do
				local npos = segPos + Vector3.new(
					sx * radii[segI] * bs * 0.80,
					-radii[segI] * bs * 0.58, 0)
				ball("LegNub" .. si .. (sx > 0 and "R" or "L"), nubR, cfg.legNubColor, npos)
			end
		end

		ball("GlowCore", bs * 0.24, cfg.glowColor, Vector3.new(0, 0, 0),
			Enum.Material.Neon, 0.35)

		local hpFill, nameLbl = attachHUD(body)
		return model, body, hpFill, nameLbl, parts
	end

	-- ════════════════════════════════════════════════════════════
	-- STAGES 3-5 – PROPER BEETLE
	-- Elytra (domed shell) is the PrimaryPart at (0,0,0).
	-- Pronotum shield and head extend forward (+Z).
	-- Legs sprawl outward and down from the elytra sides.
	-- ════════════════════════════════════════════════════════════

	-- ── Body proportions per stage ────────────────────────────────
	local elW, elH, elL   -- elytra width, dome height, fore-aft length
	local pronR, headR

	if stageIndex == 3 then        -- Dung Beetle: compact and round
		elW, elH, elL = bs * 1.10, bs * 0.90, bs * 1.10
		pronR, headR  = bs * 0.36, bs * 0.28
	elseif stageIndex == 4 then    -- Stag Beetle: elongated
		elW, elH, elL = bs * 1.04, bs * 0.76, bs * 1.36
		pronR, headR  = bs * 0.32, bs * 0.30
	else                           -- Titan Beetle: wide and massive
		elW, elH, elL = bs * 1.24, bs * 0.84, bs * 1.40
		pronR, headR  = bs * 0.38, bs * 0.32
	end

	local elRx, elRy, elRz = elW * 0.5, elH * 0.5, elL * 0.5

	-- ── Elytra (PRIMARY) ─────────────────────────────────────────
	local body = makePart("HumanoidRootPart",
		Vector3.new(elW, elH, elL), cfg.shellColor, Enum.Material.SmoothPlastic)
	body.Shape      = Enum.PartType.Ball
	model.PrimaryPart = body

	-- Center seam line running fore-aft along the top of the elytra
	local seamW   = math.max(bs * 0.040, 0.055)
	local seamTopY = elRy * 0.88
	rod("ElySeam",
		Vector3.new(0, seamTopY,  elRz * 0.80),
		Vector3.new(0, seamTopY, -elRz * 0.80),
		seamW, cfg.seamColor)

	-- ── Pronotum (thorax shield in front of elytra) ───────────────
	local pronD   = pronR * 2
	local pronPos = Vector3.new(0, -bs * 0.04, elRz * 0.80 + pronR * 0.82)
	local pron    = makePart("Pronotum",
		Vector3.new(pronD * 1.06, pronD * 0.70, pronD * 0.88), cfg.shellColor)
	pron.Shape = Enum.PartType.Ball
	addPart(pron, CFrame.new(pronPos))

	-- Seam continues onto pronotum
	rod("PronSeam",
		Vector3.new(0, pronPos.Y + pronR * 0.60, pronPos.Z + pronR * 0.52),
		Vector3.new(0, pronPos.Y + pronR * 0.60, pronPos.Z - pronR * 0.28),
		seamW * 0.80, cfg.seamColor)

	-- ── Head ─────────────────────────────────────────────────────
	local headD   = headR * 2
	local headPos = Vector3.new(0, pronPos.Y + bs * 0.02,
		pronPos.Z + pronR * 0.72 + headR * 0.80)
	local head    = makePart("Head",
		Vector3.new(headD * 0.96, headD * 0.88, headD), cfg.headColor)
	head.Shape = Enum.PartType.Ball
	addPart(head, CFrame.new(headPos))

	-- ── Eyes ─────────────────────────────────────────────────────
	local eyeR = math.max(bs * 0.085, 0.10)
	for _, sx in ipairs({ -1, 1 }) do
		local sfx  = sx > 0 and "R" or "L"
		local epos = headPos + Vector3.new(sx * headR * 0.70, headR * 0.08, headR * 0.32)
		ball("Eye"   .. sfx, eyeR,         Color3.new(1, 1, 1), epos)
		ball("Pupil" .. sfx, eyeR * 0.70,  cfg.eyeColor,
			epos + Vector3.new(0, 0, eyeR * 0.46), Enum.Material.Neon)
	end

	-- ── Antennae (elbowed with rounded club tip) ──────────────────
	local antW = math.max(bs * 0.050, 0.07)
	for _, sx in ipairs({ -1, 1 }) do
		local sfx      = sx > 0 and "R" or "L"
		local antBase  = headPos + Vector3.new(sx * headR * 0.34, headR * 0.30, headR * 0.28)
		local antElbow = antBase  + Vector3.new(sx * bs * 0.12, bs * 0.26, bs * 0.06)
		local antTip   = antElbow + Vector3.new(sx * bs * 0.04, -bs * 0.04, bs * 0.18)
		rod("Scape"     .. sfx, antBase,  antElbow, antW,         cfg.antennaColor)
		rod("Funiculus" .. sfx, antElbow, antTip,   antW,         cfg.antennaColor)
		ball("Club"     .. sfx, antW * 2.0, cfg.antennaColor, antTip)  -- large rounded club
	end

	-- ── 6 Legs – sprawling beetle stance ─────────────────────────
	-- Beetles have a wide, low crawl: legs barely rise before dropping down.
	local legR       = math.max(bs * 0.092, 0.10)
	if stageIndex == 5 then legR = bs * 0.112 end

	local attachX    = bs * 0.46
	local attachY    = -elRy * 0.72   -- far under the shell
	local legPairZ   = { elRz * 0.50, 0, -elRz * 0.50 }
	local upperOutX  = bs * 0.40
	local upperUpY   = bs * 0.02     -- nearly horizontal — beetle sprawl
	local lowerOutX  = bs * 0.38
	local lowerDownY = bs * 0.45

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

	-- ════════════════════════════════════════════════════════════
	-- Stage-specific head / pronotum decorations
	-- ════════════════════════════════════════════════════════════

	-- ── DUNG BEETLE: curved scarab horn on pronotum ───────────────
	if stageIndex == 3 then
		local hornW    = math.max(bs * 0.092, 0.11)
		local hornBase = pronPos + Vector3.new(0, pronR * 0.82, pronR * 0.28)
		local hornElb  = hornBase + Vector3.new(0, bs * 0.25, bs * 0.05)
		local hornTip  = hornElb  + Vector3.new(0, bs * 0.10, bs * 0.20)  -- curves forward
		rod("HornShaft", hornBase, hornElb, hornW,         cfg.hornColor)
		rod("HornCurve", hornElb,  hornTip, hornW * 0.72,  cfg.hornColor)
		ball("HornTip",  hornW * 0.60, cfg.hornColor, hornTip)
	end

	-- ── STAG BEETLE: enormous forked antler mandibles ────────────
	-- Each mandible has a main stalk that curves upward and outward,
	-- then forks into an inner tooth (pointing inward) and outer tooth.
	if stageIndex == 4 then
		local mandW = math.max(bs * 0.092, 0.11)
		for _, sx in ipairs({ -1, 1 }) do
			local sfx   = sx > 0 and "R" or "L"

			-- Stalk base at head front
			local mBase = headPos + Vector3.new(sx * headR * 0.34, -headR * 0.18, headR * 0.74)
			-- Mid-point: curves up and out as it extends forward
			local mMid  = mBase + Vector3.new(sx * bs * 0.26, bs * 0.22, bs * 0.44)
			-- Stalk tip (fork origin)
			local mTip  = mMid  + Vector3.new(sx * bs * 0.10, bs * 0.08, bs * 0.18)

			rod("MandStalk" .. sfx, mBase, mMid, mandW,         cfg.mandColor)
			rod("MandMid"   .. sfx, mMid,  mTip, mandW * 0.82,  cfg.mandColor)

			-- Inner tooth: hooks inward and slightly forward from the fork
			local innerTip = mMid + Vector3.new(-sx * bs * 0.16, -bs * 0.04, bs * 0.26)
			rod("MandInner" .. sfx, mMid, innerTip, mandW * 0.62, cfg.mandColor)

			-- Outer tooth: continues the main stalk direction slightly
			local outerTip = mTip + Vector3.new(sx * bs * 0.07, -bs * 0.06, bs * 0.22)
			rod("MandOuter" .. sfx, mTip, outerTip, mandW * 0.58, cfg.mandColor)
		end
	end

	-- ── TITAN BEETLE: massive pincer mandibles ────────────────────
	-- Shorter than stag but far thicker — built for crushing, not display.
	if stageIndex == 5 then
		local mandW = math.max(bs * 0.128, 0.16)   -- thick
		for _, sx in ipairs({ -1, 1 }) do
			local sfx   = sx > 0 and "R" or "L"

			local mBase = headPos + Vector3.new(sx * headR * 0.36, -headR * 0.10, headR * 0.80)
			local mMid  = mBase + Vector3.new(sx * bs * 0.28, bs * 0.05, bs * 0.38)
			local mTip  = mMid  + Vector3.new(sx * bs * 0.08, -bs * 0.08, bs * 0.26)

			rod("MandMain"   .. sfx, mBase, mMid, mandW,         cfg.mandColor)
			rod("MandTip"    .. sfx, mMid,  mTip, mandW * 0.76,  cfg.mandColor)

			-- Large inward pincer tooth — Titan's signature crushing bite
			local pincerTip = mMid + Vector3.new(-sx * bs * 0.26, -bs * 0.10, bs * 0.24)
			rod("MandPincer" .. sfx, mMid, pincerTip, mandW * 0.68, cfg.mandColor)
		end
	end

	-- ── Glow core ────────────────────────────────────────────────
	ball("GlowCore", bs * 0.28, cfg.glowColor, Vector3.new(0, 0, 0),
		Enum.Material.Neon, 0.35)

	-- ── Billboard HUD ────────────────────────────────────────────
	local hpFill, nameLbl = attachHUD(body)

	return model, body, hpFill, nameLbl, parts
end

return BeetleModel
