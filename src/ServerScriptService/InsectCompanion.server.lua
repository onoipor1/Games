-- InsectCompanion.server.lua
-- Manages per-player insect companion models that orbit the player.
-- By default companions do NOT auto-attack — the player clicks an enemy to target it.
-- Auto-attack (finding the nearest enemy automatically) requires the AutoAttack game pass.
--
-- Attack range: 10 + (stageIndex - 1) * 2 + rebirths  (studs)
--
-- Exposes:
--   _G.SpawnCompanion(player)              – create/refresh companion
--   _G.RemoveCompanion(player)             – despawn companion
--   _G.GetCompanionDamage(player)          – returns companion damage for this tick
--   _G.EvolveCompanion(player, stage)      – rebuild companion at new stage
--   _G.SetCompanionTarget(player, name)    – set target enemy model name (from AttackEnemy)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local InsectData  = require(ReplicatedStorage:WaitForChild("InsectData"))
local TalentData  = require(ReplicatedStorage:WaitForChild("TalentData"))
local SpiderModel    = require(script.Parent:WaitForChild("SpiderModel"))
local AntModel       = require(script.Parent:WaitForChild("AntModel"))
local BeeModel       = require(script.Parent:WaitForChild("BeeModel"))
local BeetleModel    = require(script.Parent:WaitForChild("BeetleModel"))

-- ─────────────────────────────────────────
-- Per-player state
-- ─────────────────────────────────────────
local Companions       = {}   -- [player] = record
local CompanionTargets = {}   -- [player] = { rec = enemyRecord } or nil

-- ─────────────────────────────────────────
-- Attack range formula
-- ─────────────────────────────────────────
local BASE_RANGE = 10  -- studs

local function getAttackRange(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data then return BASE_RANGE end
	local stageBonus   = ((data.stageIndex or 1) - 1) * 2
	local rebirthBonus = (data.rebirths or 0) * 1
	return BASE_RANGE + stageBonus + rebirthBonus
end

-- ─────────────────────────────────────────
-- Colours per insect / stage
-- ─────────────────────────────────────────
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
	if not stageDef then return nil end

	local baseSize  = math.clamp(stageDef.size * 2.5, 1.2, 6)
	local bodyColor = INSECT_COLORS[insectType] and INSECT_COLORS[insectType][stageIndex]
		or Color3.fromRGB(100, 200, 100)

	local model     = Instance.new("Model")
	model.Name      = "Companion"

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

	-- Eyes
	for _, side in ipairs({ -0.35, 0.35 }) do
		local eye       = Instance.new("Part")
		eye.Shape       = Enum.PartType.Ball
		eye.Size        = Vector3.new(baseSize * 0.28, baseSize * 0.28, baseSize * 0.28)
		eye.Color       = Color3.new(1, 1, 1)
		eye.Material    = Enum.Material.SmoothPlastic
		eye.Anchored    = true
		eye.CanCollide  = false
		eye.CastShadow  = false
		eye.CFrame      = CFrame.new(
			body.CFrame.Position + Vector3.new(side * baseSize * 0.45, baseSize * 0.2, baseSize * 0.42)
		)
		eye.Parent      = model

		local pupil     = Instance.new("Part")
		pupil.Shape     = Enum.PartType.Ball
		pupil.Size      = Vector3.new(baseSize * 0.13, baseSize * 0.13, baseSize * 0.13)
		pupil.Color     = Color3.new(0, 0, 0)
		pupil.Material  = Enum.Material.SmoothPlastic
		pupil.Anchored  = true
		pupil.CanCollide = false
		pupil.CastShadow = false
		pupil.CFrame    = eye.CFrame + Vector3.new(0, 0, baseSize * 0.08)
		pupil.Parent    = model
	end

	-- Neon glow core
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

	-- Billboard (name + HP)
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
-- Talent helpers
-- ─────────────────────────────────────────
local function getTalentEffects(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data then return TalentData.ComputeEffects({}, nil) end
	return TalentData.ComputeEffects(data.talents or {}, data.insectType)
end

local function calcCompanionHP(player, stageDef)
	local te      = getTalentEffects(player)
	local rebirths = (_G.PlayerData and _G.PlayerData[player] and _G.PlayerData[player].rebirths) or 0
	local rebBonus = 1 + rebirths * 0.05
	return math.floor(stageDef.maxHealth * (1 + te.companionHpBonus) * rebBonus)
end

-- ─────────────────────────────────────────
-- Spawn / refresh companion
-- ─────────────────────────────────────────
local Remotes  -- resolved lazily

local function getRemotes()
	if not Remotes then
		Remotes = ReplicatedStorage:WaitForChild("Remotes")
	end
	return Remotes
end

local function spawnCompanion(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data or not data.insectType then return end

	local old = Companions[player]
	if old and old.model and old.model.Parent then
		old.model:Destroy()
	end
	CompanionTargets[player] = nil

	local stageDef = InsectData.GetStage(data.insectType, data.stageIndex or 1)
	if not stageDef then return end

	local stageIndex = data.stageIndex or 1
	local model, body, hpFill, nameLbl, spiderParts

	if data.insectType == "Spider" then
		model, body, hpFill, nameLbl, spiderParts = SpiderModel.Build(stageIndex)
	elseif data.insectType == "Ant" then
		model, body, hpFill, nameLbl, spiderParts = AntModel.Build(stageIndex)
	elseif data.insectType == "Bee" then
		model, body, hpFill, nameLbl, spiderParts = BeeModel.Build(stageIndex)
	elseif data.insectType == "Beetle" then
		model, body, hpFill, nameLbl, spiderParts = BeetleModel.Build(stageIndex)
	else
		model, body, hpFill, nameLbl = buildCompanionModel(data.insectType, stageIndex)
	end
	if not model then return end

	local maxHp    = calcCompanionHP(player, stageDef)
	local char     = player.Character
	local hrp      = char and char:FindFirstChild("HumanoidRootPart")
	local startPos = hrp and (hrp.Position + Vector3.new(4, 3, 0)) or Vector3.new(0, 5, 0)
	local startCF  = CFrame.new(startPos)

	body.CFrame = startCF
	-- Position all spider parts at their correct world locations on spawn
	if spiderParts then
		for _, pd in ipairs(spiderParts) do
			pd.part.CFrame = startCF * pd.offset
		end
	end
	model.Parent = workspace

	Companions[player] = {
		model        = model,
		body         = body,
		hpFill       = hpFill,
		nameLbl      = nameLbl,
		hp           = maxHp,
		maxHp        = maxHp,
		attackTimer  = 0,
		orbitAngle   = 0,
		dead         = false,
		respawnTimer = 0,
		insectType   = data.insectType,
		stageIndex   = stageIndex,
		parts        = spiderParts,   -- nil for non-spider; used in heartbeat
	}

	getRemotes():FindFirstChild("CompanionUpdate"):FireClient(player, {
		hp         = maxHp,
		maxHp      = maxHp,
		stageName  = stageDef.name,
		stageIndex = data.stageIndex or 1,
	})
end

-- ─────────────────────────────────────────
-- _G interface
-- ─────────────────────────────────────────
_G.SpawnCompanion = spawnCompanion

_G.RemoveCompanion = function(player)
	local rec = Companions[player]
	if rec and rec.model and rec.model.Parent then
		rec.model:Destroy()
	end
	Companions[player]       = nil
	CompanionTargets[player] = nil
end

_G.GetCompanionDamage = function(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data or not data.insectType then return 0 end
	local stageDef = InsectData.GetStage(data.insectType, data.stageIndex or 1)
	if not stageDef then return 0 end
	local te      = getTalentEffects(player)
	local rebMult = 1 + ((data.rebirths or 0) * 0.05)
	return math.floor(stageDef.damage * (1 + te.companionDmgBonus) * rebMult)
end

_G.EvolveCompanion = function(player, newStageIndex)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data then return end
	data.stageIndex = newStageIndex
	spawnCompanion(player)
end

-- Called by GameServer's AttackEnemy handler when a player clicks an enemy
_G.SetCompanionTarget = function(player, enemyModelName)
	if not _G.Enemies then return end
	-- Find the enemy record in _G.Enemies by model name
	for _, erec in ipairs(_G.Enemies) do
		if not erec.dead and erec.model and erec.model.Name == enemyModelName then
			CompanionTargets[player] = erec
			return
		end
	end
	-- Enemy not found or already dead — clear target
	CompanionTargets[player] = nil
end

-- ─────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────
local BASE_ATK_COOLDOWN = 1.4   -- seconds between attacks
local ORBIT_RADIUS      = 7     -- studs from player when idle
local LEASH_RANGE       = 40    -- companion stops chasing if player is this far from the enemy
local FLOAT_Y           = 3.5   -- height above ground

-- ─────────────────────────────────────────
-- Main AI loop
-- ─────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
	for player, rec in pairs(Companions) do
		if not player.Parent then
			if rec.model and rec.model.Parent then rec.model:Destroy() end
			Companions[player]       = nil
			CompanionTargets[player] = nil
			continue
		end

		local char = player.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")

		-- ── Dead / respawning ─────────────────────────────
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

		local myPos      = rec.body.Position
		local attackRange = getAttackRange(player)

		-- ── Talent regen ──────────────────────────────────
		local data = _G.PlayerData and _G.PlayerData[player]
		if data then
			local te = getTalentEffects(player)
			if te.companionRegenRate > 0 and rec.hp < rec.maxHp then
				rec.hp = math.min(rec.maxHp, rec.hp + te.companionRegenRate * dt)
				if rec.hpFill then
					rec.hpFill.Size = UDim2.new(math.clamp(rec.hp / rec.maxHp, 0, 1), 0, 1, 0)
				end
			end
		end

		-- ── Determine current target ──────────────────────
		local hasAutoAttack = _G.PlayerPasses and _G.PlayerPasses[player]
			and _G.PlayerPasses[player].AutoAttack

		local target = CompanionTargets[player]

		-- Validate existing target
		if target then
			if target.dead or not target.body or not target.body.Parent then
				-- Target died — clear it
				CompanionTargets[player] = nil
				target = nil
			else
				-- Leash: don't chase if enemy is too far from the player
				local playerToEnemy = (target.body.Position - hrp.Position).Magnitude
				if playerToEnemy > LEASH_RANGE then
					CompanionTargets[player] = nil
					target = nil
				end
			end
		end

		-- Auto-attack: find nearest enemy within range when no manual target
		if not target and hasAutoAttack and _G.Enemies then
			local nearestDist = attackRange
			for _, erec in ipairs(_G.Enemies) do
				if not erec.dead and erec.body and erec.body.Parent then
					local d = (erec.body.Position - myPos).Magnitude
					if d < nearestDist then
						nearestDist = d
						target      = erec
					end
				end
			end
			-- Don't store in CompanionTargets (re-evaluated each frame for auto)
		end

		-- ── Movement ─────────────────────────────────────
		local targetPos
		if target and target.body and target.body.Parent then
			-- Chase the target
			targetPos = target.body.Position + Vector3.new(0, FLOAT_Y, 0)
		else
			-- Orbit player
			rec.orbitAngle = rec.orbitAngle + dt * 1.2
			targetPos = hrp.Position + Vector3.new(
				math.cos(rec.orbitAngle) * ORBIT_RADIUS,
				FLOAT_Y,
				math.sin(rec.orbitAngle) * ORBIT_RADIUS
			)
		end

		local newPos  = myPos:Lerp(targetPos, math.min(1, dt * 6))
		local bodyCF  = CFrame.new(newPos)
		rec.body.CFrame = bodyCF

		-- Move all attached parts (spider model uses a parts table; others fall back to GlowCore)
		if rec.parts then
			for _, pd in ipairs(rec.parts) do
				if pd.part and pd.part.Parent then
					pd.part.CFrame = bodyCF * pd.offset
				end
			end
		else
			local glowPart = rec.model:FindFirstChild("GlowCore")
			if glowPart then glowPart.CFrame = bodyCF end
		end

		-- ── Attack ────────────────────────────────────────
		-- Only attack if companion is within attackRange of the target
		if target and target.body and target.body.Parent then
			local distToTarget = (target.body.Position - myPos).Magnitude
			local te           = data and getTalentEffects(player) or TalentData.ComputeEffects({}, nil)
			local atkCooldown  = BASE_ATK_COOLDOWN / (1 + (te.companionSpdBonus or 0))

			rec.attackTimer = rec.attackTimer + dt

			if distToTarget <= attackRange and rec.attackTimer >= atkCooldown then
				rec.attackTimer = 0

				local dmg = _G.GetCompanionDamage(player)

				-- Attack flash
				local flash        = Instance.new("Part")
				flash.Shape        = Enum.PartType.Ball
				flash.Size         = Vector3.new(2, 2, 2)
				flash.Color        = Color3.fromRGB(255, 255, 100)
				flash.Material     = Enum.Material.Neon
				flash.Anchored     = true
				flash.CanCollide   = false
				flash.CastShadow   = false
				flash.Transparency = 0.3
				flash.CFrame       = target.body.CFrame
				flash.Parent       = workspace
				game:GetService("Debris"):AddItem(flash, 0.15)

				if _G.DamageEnemy then
					local xpReward, crystalBase = _G.DamageEnemy(target.model.Name, dmg)
					if xpReward and xpReward > 0 and _G.AddXP then
						_G.AddXP(player, xpReward)
					end
					if crystalBase and crystalBase > 0 and _G.AddCrystals then
						local passMult   = (_G.GetMultipliers and _G.GetMultipliers(player)) or { crystalMult = 1 }
						local talentMult = 1 + (te.crystalBonus or 0)
						local cGain      = math.floor(crystalBase * (passMult.crystalMult or 1) * talentMult)
						if cGain > 0 then _G.AddCrystals(player, cGain) end
					end
				end
			end
		else
			-- No target — reset attack timer so next attack is instant when one appears
			rec.attackTimer = BASE_ATK_COOLDOWN
		end

		-- ── Enemy melee damage to companion ──────────────
		for _, erec in ipairs(_G.Enemies or {}) do
			if not erec.dead and erec.body and erec.body.Parent then
				local d = (erec.body.Position - myPos).Magnitude
				if d <= (erec.def and erec.def.size or 2) * 5 + 2 then
					local rawDmg = math.floor((erec.scaledDmg or erec.def and erec.def.damage or 10) * 0.30)
					rec.hp = math.max(0, rec.hp - rawDmg * dt)

					if rec.hpFill then
						rec.hpFill.Size = UDim2.new(math.clamp(rec.hp / rec.maxHp, 0, 1), 0, 1, 0)
					end

					getRemotes():FindFirstChild("CompanionUpdate"):FireClient(player, {
						hp    = math.floor(rec.hp),
						maxHp = rec.maxHp,
					})

					if rec.hp <= 0 then
						rec.dead        = true
						rec.respawnTimer = 8
						CompanionTargets[player] = nil
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
	Companions[player]       = nil
	CompanionTargets[player] = nil
end)

print("[InsectEvo] InsectCompanion initialized.")
