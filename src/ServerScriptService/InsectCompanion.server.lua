-- InsectCompanion.server.lua
-- Manages per-player insect companion models that orbit the player and auto-attack enemies.
-- Companions evolve their appearance when the zone boss is defeated.
-- Exposes:
--   _G.SpawnCompanion(player)          – create/refresh companion for a player
--   _G.RemoveCompanion(player)         – despawn companion
--   _G.GetCompanionDamage(player)      – returns scaled companion damage for combat
--   _G.EvolveCompanion(player, stage)  – rebuild companion at new stage

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local InsectData  = require(ReplicatedStorage:WaitForChild("InsectData"))
local TalentData  = require(ReplicatedStorage:WaitForChild("TalentData"))

-- ─────────────────────────────────────────
-- Per-player companion records
-- record = { model, body, hpBg, hpFill, nameLbl,
--            hp, maxHp, attackCooldown, angle, dead, respawnTimer }
-- ─────────────────────────────────────────
local Companions = {}

-- Colour per insect type (stage 1 default, updated on evolve)
local INSECT_COLORS = {
	Ant       = { Color3.fromRGB(40,40,40),   Color3.fromRGB(60,60,60),     Color3.fromRGB(20,20,20),
	              Color3.fromRGB(200,40,20),   Color3.fromRGB(180,90,20)     },
	Beetle    = { Color3.fromRGB(240,240,200), Color3.fromRGB(220,190,120),  Color3.fromRGB(160,110,50),
	              Color3.fromRGB(140,70,30),   Color3.fromRGB(20,20,20)      },
	Butterfly = { Color3.fromRGB(80,180,60),   Color3.fromRGB(100,210,80),   Color3.fromRGB(220,200,50),
	              Color3.fromRGB(240,220,80),   Color3.fromRGB(180,180,200)   },
	Bee       = { Color3.fromRGB(240,220,80),  Color3.fromRGB(240,200,40),   Color3.fromRGB(220,140,20),
	              Color3.fromRGB(240,120,20),   Color3.fromRGB(220,40,40)     },
	Spider    = { Color3.fromRGB(200,60,60),   Color3.fromRGB(160,60,60),    Color3.fromRGB(180,80,20),
	              Color3.fromRGB(20,20,20),     Color3.fromRGB(60,30,10)      },
}

-- ─────────────────────────────────────────
-- Build companion model
-- ─────────────────────────────────────────
local function buildCompanionModel(insectType, stageIndex)
	local stageDef  = InsectData.GetStage(insectType, stageIndex)
	if not stageDef then return nil, nil end

	local baseSize  = math.clamp(stageDef.size * 2.5, 1.2, 6)
	local bodyColor = INSECT_COLORS[insectType] and INSECT_COLORS[insectType][stageIndex]
		or Color3.fromRGB(100, 200, 100)

	local model     = Instance.new("Model")
	model.Name      = "Companion"

	-- Main body
	local body      = Instance.new("Part")
	body.Name       = "HumanoidRootPart"
	body.Shape      = Enum.PartType.Ball
	body.Size       = Vector3.new(baseSize, baseSize, baseSize)
	body.Color      = bodyColor
	body.Material   = Enum.Material.SmoothPlastic
	body.Anchored   = true
	body.CanCollide = false
	body.CastShadow = false
	body.Parent     = model
	model.PrimaryPart = body

	-- Eyes (2 small white spheres with black pupils)
	for _, side in ipairs({ -0.35, 0.35 }) do
		local eye        = Instance.new("Part")
		eye.Name         = "Eye"
		eye.Shape        = Enum.PartType.Ball
		eye.Size         = Vector3.new(baseSize * 0.28, baseSize * 0.28, baseSize * 0.28)
		eye.Color        = Color3.new(1, 1, 1)
		eye.Material     = Enum.Material.SmoothPlastic
		eye.Anchored     = true
		eye.CanCollide   = false
		eye.CastShadow   = false
		eye.CFrame       = CFrame.new(
			body.CFrame.Position + Vector3.new(side * baseSize * 0.45, baseSize * 0.2, baseSize * 0.42)
		)
		eye.Parent = model

		local pupil      = Instance.new("Part")
		pupil.Name       = "Pupil"
		pupil.Shape      = Enum.PartType.Ball
		pupil.Size       = Vector3.new(baseSize * 0.13, baseSize * 0.13, baseSize * 0.13)
		pupil.Color      = Color3.new(0, 0, 0)
		pupil.Material   = Enum.Material.SmoothPlastic
		pupil.Anchored   = true
		pupil.CanCollide = false
		pupil.CastShadow = false
		pupil.CFrame     = eye.CFrame + Vector3.new(0, 0, baseSize * 0.08)
		pupil.Parent     = model
	end

	-- Glow neon core (small inner sphere matching insect)
	local glow      = Instance.new("Part")
	glow.Name       = "GlowCore"
	glow.Shape      = Enum.PartType.Ball
	glow.Size       = Vector3.new(baseSize * 0.5, baseSize * 0.5, baseSize * 0.5)
	glow.Color      = bodyColor
	glow.Material   = Enum.Material.Neon
	glow.Anchored   = true
	glow.CanCollide = false
	glow.CastShadow = false
	glow.Transparency = 0.4
	glow.CFrame     = body.CFrame
	glow.Parent     = model

	-- Billboard GUI (name + stage + HP bar)
	local bb        = Instance.new("BillboardGui")
	bb.Name         = "CompanionHUD"
	bb.Size         = UDim2.new(0, 120, 0, 38)
	bb.StudsOffset  = Vector3.new(0, baseSize * 0.7 + 1, 0)
	bb.AlwaysOnTop  = false
	bb.MaxDistance  = 60
	bb.Parent       = body

	local nameLbl   = Instance.new("TextLabel")
	nameLbl.Name    = "NameLabel"
	nameLbl.Size    = UDim2.new(1, 0, 0, 18)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text    = stageDef.name
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.Font    = Enum.Font.GothamBold
	nameLbl.TextScaled = true
	nameLbl.Parent  = bb

	local hpBg      = Instance.new("Frame")
	hpBg.Name       = "HPBg"
	hpBg.Size       = UDim2.new(1, 0, 0, 10)
	hpBg.Position   = UDim2.new(0, 0, 0, 20)
	hpBg.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
	hpBg.BorderSizePixel  = 0
	hpBg.Parent     = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

	local hpFill    = Instance.new("Frame")
	hpFill.Name     = "HPFill"
	hpFill.Size     = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	hpFill.BorderSizePixel  = 0
	hpFill.Parent   = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

	return model, body, hpFill, nameLbl
end

-- ─────────────────────────────────────────
-- Get talent effects for a player
-- ─────────────────────────────────────────
local function getTalentEffects(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data then return TalentData.ComputeEffects({}, nil) end
	return TalentData.ComputeEffects(data.talents or {}, data.insectType)
end

-- ─────────────────────────────────────────
-- Compute companion max HP with talents
-- ─────────────────────────────────────────
local function calcCompanionHP(player, stageDef)
	local te    = getTalentEffects(player)
	local rebirth = (_G.PlayerData and _G.PlayerData[player] and _G.PlayerData[player].rebirths) or 0
	local rebBonus = 1 + rebirth * 0.05  -- +5% HP per rebirth (same as damage bonus)
	return math.floor(stageDef.maxHealth * (1 + te.companionHpBonus) * rebBonus)
end

-- ─────────────────────────────────────────
-- Spawn / refresh companion
-- ─────────────────────────────────────────
local function spawnCompanion(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data or not data.insectType then return end

	-- Remove old companion
	local old = Companions[player]
	if old and old.model and old.model.Parent then
		old.model:Destroy()
	end

	local stageDef = InsectData.GetStage(data.insectType, data.stageIndex or 1)
	if not stageDef then return end

	local model, body, hpFill, nameLbl = buildCompanionModel(data.insectType, data.stageIndex or 1)
	if not model then return end

	local maxHp = calcCompanionHP(player, stageDef)

	-- Place next to player
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local startPos = hrp and (hrp.Position + Vector3.new(4, 3, 0)) or Vector3.new(0, 5, 0)
	body.CFrame = CFrame.new(startPos)
	model.Parent = workspace

	Companions[player] = {
		model         = model,
		body          = body,
		hpFill        = hpFill,
		nameLbl       = nameLbl,
		hp            = maxHp,
		maxHp         = maxHp,
		attackTimer   = 0,
		orbitAngle    = 0,
		dead          = false,
		respawnTimer  = 0,
		insectType    = data.insectType,
		stageIndex    = data.stageIndex or 1,
	}

	-- Notify client of companion HP
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	Remotes:FindFirstChild("CompanionUpdate"):FireClient(player, {
		maxHp      = maxHp,
		hp         = maxHp,
		stageName  = stageDef.name,
		stageIndex = data.stageIndex or 1,
	})
end

_G.SpawnCompanion  = spawnCompanion

_G.RemoveCompanion = function(player)
	local rec = Companions[player]
	if rec and rec.model and rec.model.Parent then
		rec.model:Destroy()
	end
	Companions[player] = nil
end

_G.GetCompanionDamage = function(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data or not data.insectType then return 0 end
	local stageDef = InsectData.GetStage(data.insectType, data.stageIndex or 1)
	if not stageDef then return 0 end
	local te      = getTalentEffects(player)
	local rebMult = _G.PlayerData and _G.PlayerData[player] and
		(1 + (_G.PlayerData[player].rebirths or 0) * 0.05) or 1
	return math.floor(stageDef.damage * (1 + te.companionDmgBonus) * rebMult)
end

_G.EvolveCompanion = function(player, newStageIndex)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data then return end
	data.stageIndex = newStageIndex
	spawnCompanion(player)
end

-- ─────────────────────────────────────────
-- Main AI loop
-- ─────────────────────────────────────────
local BASE_ATK_COOLDOWN = 1.4   -- seconds between auto-attacks
local ORBIT_RADIUS      = 7     -- studs from player when idle
local AGGRO_RANGE       = 22    -- studs to detect enemy
local LEASH_RANGE       = 35    -- return to player if > this from enemy
local FLOAT_Y           = 3.5  -- height above ground

RunService.Heartbeat:Connect(function(dt)
	for player, rec in pairs(Companions) do
		if not player.Parent then
			-- Player left
			if rec.model and rec.model.Parent then rec.model:Destroy() end
			Companions[player] = nil
			continue
		end

		local char = player.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")

		-- ── Respawn handling ──────────────────────────────
		if rec.dead then
			rec.respawnTimer = rec.respawnTimer - dt
			if rec.respawnTimer <= 0 then
				spawnCompanion(player)
			end
			continue
		end

		if not rec.body or not rec.body.Parent then
			rec.dead        = true
			rec.respawnTimer = 6
			continue
		end

		if not hrp then continue end

		local myPos = rec.body.Position

		-- ── Regen from beetle talent ──────────────────────
		local data = _G.PlayerData and _G.PlayerData[player]
		if data then
			local te = getTalentEffects(player)
			if te.companionRegenRate > 0 and rec.hp < rec.maxHp then
				rec.hp = math.min(rec.maxHp, rec.hp + te.companionRegenRate * dt)
				local frac = rec.hp / rec.maxHp
				if rec.hpFill then
					rec.hpFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
				end
			end
		end

		-- ── Find nearest enemy ────────────────────────────
		local nearestEnemy, nearestDist = nil, AGGRO_RANGE
		if _G.Enemies then
			for _, erec in ipairs(_G.Enemies) do
				if not erec.dead and erec.body and erec.body.Parent then
					local d = (erec.body.Position - myPos).Magnitude
					if d < nearestDist then
						nearestDist  = d
						nearestEnemy = erec
					end
				end
			end
		end

		-- ── Movement ─────────────────────────────────────
		local targetPos
		if nearestEnemy and nearestDist < LEASH_RANGE then
			-- Chase enemy
			targetPos = nearestEnemy.body.Position + Vector3.new(0, FLOAT_Y, 0)
		else
			-- Orbit player
			rec.orbitAngle = rec.orbitAngle + dt * 1.2
			targetPos = hrp.Position + Vector3.new(
				math.cos(rec.orbitAngle) * ORBIT_RADIUS,
				FLOAT_Y,
				math.sin(rec.orbitAngle) * ORBIT_RADIUS
			)
		end

		-- Smooth lerp toward target
		local newPos = myPos:Lerp(targetPos, math.min(1, dt * 6))
		rec.body.CFrame = CFrame.new(newPos)

		-- Keep glow/eyes positioned on body
		local glowPart = rec.model:FindFirstChild("GlowCore")
		if glowPart then glowPart.CFrame = rec.body.CFrame end

		-- ── Auto attack ───────────────────────────────────
		rec.attackTimer = rec.attackTimer + dt

		local te = data and getTalentEffects(player) or TalentData.ComputeEffects({}, nil)
		local atkCooldown = BASE_ATK_COOLDOWN / (1 + (te.companionSpdBonus or 0))

		if nearestEnemy and nearestDist <= AGGRO_RANGE and rec.attackTimer >= atkCooldown then
			rec.attackTimer = 0
			local dmg = _G.GetCompanionDamage(player)

			-- Attack visual flash
			local flash        = Instance.new("Part")
			flash.Shape        = Enum.PartType.Ball
			flash.Size         = Vector3.new(2, 2, 2)
			flash.Color        = Color3.fromRGB(255, 255, 100)
			flash.Material     = Enum.Material.Neon
			flash.Anchored     = true
			flash.CanCollide   = false
			flash.CastShadow   = false
			flash.Transparency = 0.3
			flash.CFrame       = nearestEnemy.body.CFrame
			flash.Parent       = workspace
			game:GetService("Debris"):AddItem(flash, 0.15)

			-- Deal damage via EnemyManager
			if _G.DamageEnemy then
				local xpReward, crystalBase = _G.DamageEnemy(nearestEnemy.model.Name, dmg)
				if xpReward and xpReward > 0 and _G.AddXP then
					_G.AddXP(player, xpReward)
				end
				if crystalBase and crystalBase > 0 and _G.AddCrystals then
					local passMult = (_G.GetMultipliers and _G.GetMultipliers(player)) or { crystalMult = 1 }
					local talentMult = 1 + (te.crystalBonus or 0)
					local cGain = math.floor(crystalBase * (passMult.crystalMult or 1) * talentMult)
					if cGain > 0 then _G.AddCrystals(player, cGain) end
				end
			end
		end

		-- ── Enemy melee damage to companion ──────────────
		for _, erec in ipairs(_G.Enemies or {}) do
			if not erec.dead and erec.body and erec.body.Parent then
				local d = (erec.body.Position - myPos).Magnitude
				if d <= (erec.def and erec.def.size or 2) * 5 + 2 then
					-- Companion takes 30% of normal enemy damage
					local rawDmg = math.floor((erec.scaledDmg or erec.def and erec.def.damage or 10) * 0.30)
					rec.hp = math.max(0, rec.hp - rawDmg * dt)

					local frac = rec.hp / rec.maxHp
					if rec.hpFill then
						rec.hpFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
					end

					-- Update client companion HP
					local Remotes = ReplicatedStorage:WaitForChild("Remotes")
					Remotes:FindFirstChild("CompanionUpdate"):FireClient(player, {
						maxHp = rec.maxHp,
						hp    = math.floor(rec.hp),
					})

					if rec.hp <= 0 then
						rec.dead        = true
						rec.respawnTimer = 8
						if rec.model and rec.model.Parent then rec.model:Destroy() end
						rec.model = nil
						break
					end
				end
			end
		end
	end
end)

-- ─────────────────────────────────────────
-- Clean up on player leaving
-- ─────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	local rec = Companions[player]
	if rec and rec.model and rec.model.Parent then
		rec.model:Destroy()
	end
	Companions[player] = nil
end)

print("[InsectEvo] InsectCompanion initialized.")
