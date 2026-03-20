-- EnemyManager.server.lua
-- Manages all enemy spawning, AI (melee/charge/ranged/AOE), DoT/stun effects,
-- boss phase switching, and boss respawn timers across all 5 zones.
-- Mob level is distance-based within each zone (closer to spawn = lower level).
-- Mobs never enter or attack inside safe-zone radii.
-- Exposes _G.Enemies and _G.DamageEnemy for GameServer.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local EnemyData  = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ZoneData   = require(ReplicatedStorage:WaitForChild("ZoneData"))
local LevelData  = require(ReplicatedStorage:WaitForChild("LevelData"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- Live state
-- ─────────────────────────────────────────
local Enemies    = {}
_G.Enemies       = Enemies

local BossTimers = {}   -- [zoneKey] = seconds until boss respawn
local ActiveDots = {}   -- list of { player, dps, remaining }

-- ─────────────────────────────────────────
-- Helper: mob level from spawn position
-- Closer to safe zone = zone.minLevel; far edge = zone.maxLevel
-- Elites get +2 levels, bosses use zone.bossLevel
-- ─────────────────────────────────────────
local function calcMobLevel(zoneKey, position, tier)
	local zone = ZoneData.Zones[zoneKey]
	if not zone then return 1 end
	if tier == "Boss" then return zone.bossLevel end

	local frac     = ZoneData.GetDistanceFraction(zoneKey, position)
	local baseLevel = zone.minLevel + math.floor(frac * (zone.maxLevel - zone.minLevel))
	baseLevel = math.clamp(baseLevel, zone.minLevel, zone.maxLevel)

	if tier == "Elite" then
		baseLevel = math.min(baseLevel + 2, zone.bossLevel - 1)
	end
	return baseLevel
end

-- ─────────────────────────────────────────
-- Visual builder
-- ─────────────────────────────────────────
local function buildEnemyModel(def, mobLevel)
	local model    = Instance.new("Model")
	model.Name     = "Enemy_" .. def.key

	local bodySize = def.size * 4
	local isElite  = def.tier == "Elite"
	local isBoss   = def.tier == "Boss"

	-- ── Main body ──────────────────────────────────
	local body         = Instance.new("Part")
	body.Name          = "HumanoidRootPart"
	body.Material      = isBoss and Enum.Material.Neon or Enum.Material.SmoothPlastic
	body.Color         = def.bodyColor
	body.CastShadow    = true
	body.Anchored      = true
	body.CanCollide    = false

	if def.shape == "Sphere" then
		body.Shape = Enum.PartType.Ball
		body.Size  = Vector3.new(bodySize, bodySize, bodySize)
	elseif def.shape == "Cylinder" then
		body.Shape = Enum.PartType.Cylinder
		body.Size  = Vector3.new(bodySize * 1.4, bodySize * 0.6, bodySize)
	else
		body.Size  = Vector3.new(bodySize, bodySize * 0.8, bodySize * 1.2)
	end
	body.Parent       = model
	model.PrimaryPart = body

	-- ── Eyes ──────────────────────────────────────
	for i = 1, 2 do
		local eye      = Instance.new("Part")
		eye.Shape      = Enum.PartType.Ball
		eye.Size       = Vector3.new(bodySize * 0.25, bodySize * 0.25, bodySize * 0.25)
		eye.Material   = Enum.Material.Neon
		eye.Color      = isBoss and Color3.fromRGB(255, 50, 50) or def.accentColor
		eye.Anchored   = true
		eye.CanCollide = false
		eye.CastShadow = false
		local side     = (i == 1) and 1 or -1
		eye.CFrame     = body.CFrame
			* CFrame.new(side * bodySize * 0.3, bodySize * 0.25, -bodySize * 0.45)
		eye.Parent     = model
	end

	-- ── Tier extras ────────────────────────────────
	if isElite then
		local crown      = Instance.new("Part")
		crown.Shape      = Enum.PartType.Ball
		crown.Size       = Vector3.new(bodySize * 0.4, bodySize * 0.4, bodySize * 0.4)
		crown.Material   = Enum.Material.Neon
		crown.Color      = Color3.fromRGB(255, 210, 40)
		crown.Anchored   = true
		crown.CanCollide = false
		crown.CastShadow = false
		crown.CFrame     = body.CFrame * CFrame.new(0, bodySize * 0.6, 0)
		crown.Parent     = model

		local ring       = Instance.new("Part")
		ring.Shape       = Enum.PartType.Cylinder
		ring.Size        = Vector3.new(0.3, bodySize * 2.2, bodySize * 2.2)
		ring.Material    = Enum.Material.Neon
		ring.Color       = def.eliteAura or def.accentColor
		ring.Transparency = 0.55
		ring.Anchored    = true
		ring.CanCollide  = false
		ring.CastShadow  = false
		ring.CFrame      = body.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent      = model

	elseif isBoss then
		local orb        = Instance.new("Part")
		orb.Name         = "OrbCore"
		orb.Shape        = Enum.PartType.Ball
		orb.Size         = Vector3.new(bodySize * 0.6, bodySize * 0.6, bodySize * 0.6)
		orb.Material     = Enum.Material.Neon
		orb.Color        = def.accentColor
		orb.Transparency = 0.2
		orb.Anchored     = true
		orb.CanCollide   = false
		orb.CastShadow   = false
		orb.CFrame       = body.CFrame * CFrame.new(bodySize * 1.3, 0, 0)
		orb.Parent       = model

		local spike      = Instance.new("Part")
		spike.Shape      = Enum.PartType.Ball
		spike.Size       = Vector3.new(bodySize * 0.5, bodySize * 0.7, bodySize * 0.5)
		spike.Material   = Enum.Material.Neon
		spike.Color      = Color3.fromRGB(220, 30, 30)
		spike.Anchored   = true
		spike.CanCollide = false
		spike.CastShadow = false
		spike.CFrame     = body.CFrame * CFrame.new(0, bodySize * 0.8, 0)
		spike.Parent     = model
	end

	-- ── Level badge ────────────────────────────────
	local bb               = Instance.new("BillboardGui")
	bb.Name                = "EnemyBB"
	bb.Size                = UDim2.new(0, isBoss and 180 or 120, 0, isBoss and 32 or 22)
	bb.StudsOffset         = Vector3.new(0, bodySize + 2.5, 0)
	bb.AlwaysOnTop         = false
	bb.MaxDistance         = 80
	bb.Parent              = body

	local bg               = Instance.new("Frame")
	bg.Size                = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3    = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel     = 0
	bg.Parent              = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

	local hpBar            = Instance.new("Frame")
	hpBar.Name             = "HPBar"
	hpBar.Size             = UDim2.new(1, 0, 0.4, 0)
	hpBar.Position         = UDim2.new(0, 0, 0.6, 0)
	hpBar.BackgroundColor3 = isBoss
		and Color3.fromRGB(220, 30, 30)
		or (isElite and Color3.fromRGB(220, 160, 20) or Color3.fromRGB(80, 200, 80))
	hpBar.BorderSizePixel  = 0
	hpBar.Parent           = bg
	Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0, 2)

	local nameLabel        = Instance.new("TextLabel")
	nameLabel.Name         = "NameLabel"
	nameLabel.Size         = UDim2.new(1, -4, 0.6, 0)
	nameLabel.Position     = UDim2.new(0, 2, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text         = (isBoss and "💀 " or isElite and "⭐ " or "")
		.. def.displayName .. "  [Lv." .. (mobLevel or "?") .. "]"
	nameLabel.TextColor3   = isBoss and Color3.fromRGB(255, 100, 100)
		or (isElite and Color3.fromRGB(255, 210, 60) or Color3.new(1, 1, 1))
	nameLabel.Font         = Enum.Font.GothamBold
	nameLabel.TextScaled   = true
	nameLabel.Parent       = bg

	return model, body, hpBar
end

-- ─────────────────────────────────────────
-- Projectile
-- ─────────────────────────────────────────
local function fireProjectile(origin, targetPos, def)
	local proj       = Instance.new("Part")
	proj.Shape       = Enum.PartType.Ball
	proj.Size        = Vector3.new(1.5, 1.5, 1.5)
	proj.Material    = Enum.Material.Neon
	proj.Color       = def.projectileColor or def.accentColor
	proj.Anchored    = false
	proj.CanCollide  = false
	proj.CFrame      = CFrame.new(origin)
	proj.Parent      = workspace
	Debris:AddItem(proj, 5)

	local dir        = (targetPos - origin).Unit
	proj.AssemblyLinearVelocity = dir * (def.projectileSpeed or 50)

	proj.Touched:Connect(function(hit)
		if proj.Parent == nil then return end
		local char   = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			local pData = _G.PlayerData and _G.PlayerData[player]
			if pData then
				local dmg = math.floor(def.damage * 0.75)
				pData.currentHealth = math.max(1, pData.currentHealth - dmg)
				Remotes:FindFirstChild("DamageDealt"):FireClient(player, {
					amount   = dmg,
					position = proj.Position + Vector3.new(0, 3, 0),
				})
			end
			proj:Destroy()
		end
	end)
end

-- ─────────────────────────────────────────
-- DoT / Stun
-- ─────────────────────────────────────────
local function applyDoT(player, dps, duration)
	for i = #ActiveDots, 1, -1 do
		if ActiveDots[i].player == player then table.remove(ActiveDots, i) end
	end
	table.insert(ActiveDots, { player = player, dps = dps, remaining = duration })
end

local function stunPlayer(player, duration)
	local char = player.Character
	if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local saved = hum.WalkSpeed
	hum.WalkSpeed = 0
	task.delay(duration, function()
		if hum and hum.Parent then hum.WalkSpeed = saved end
	end)
end

-- ─────────────────────────────────────────
-- Damage a player (safe-zone immune)
-- ─────────────────────────────────────────
local function damagePlayer(player, amount, def)
	local pData = _G.PlayerData and _G.PlayerData[player]
	if not pData then return end

	-- Safe zone immunity
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and ZoneData.IsInSafeZone(hrp.Position) then return end

	pData.currentHealth = math.max(1, pData.currentHealth - amount)

	Remotes:FindFirstChild("DamageDealt"):FireClient(player, {
		amount   = amount,
		position = hrp and hrp.Position + Vector3.new(0, 4, 0) or Vector3.new(0, 5, 0),
	})

	if pData.currentHealth <= 1 then
		pData.currentHealth = pData.maxHealth
		Remotes:FindFirstChild("PlayerDied"):FireClient(player)
	end

	if def.dotDamage and def.dotDamage > 0 then
		applyDoT(player, def.dotDamage, def.dotDuration or 3)
	end
	if def.stunOnHit and def.stunOnHit > 0 then
		stunPlayer(player, def.stunOnHit)
	end
end

-- ─────────────────────────────────────────
-- Aggro: nearest player NOT in a safe zone
-- ─────────────────────────────────────────
local function getNearestPlayer(pos, aggroRange)
	local nearest, nearestHRP, nearestDist = nil, nil, aggroRange
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Ignore players in safe zone
			if not ZoneData.IsInSafeZone(hrp.Position) then
				local d = (hrp.Position - pos).Magnitude
				if d < nearestDist then
					nearestDist = d
					nearest     = p
					nearestHRP  = hrp
				end
			end
		end
	end
	return nearest, nearestHRP, nearestDist
end

-- ─────────────────────────────────────────
-- Boss phase
-- ─────────────────────────────────────────
local function getAttackType(rec)
	local def = rec.def
	if def.tier ~= "Boss" or not def.phases then return def.attackType end
	local frac   = rec.health / rec.maxHealth
	local chosen = def.phases[1].attackType
	for _, phase in ipairs(def.phases) do
		if frac <= phase.hpFrac then
			chosen            = phase.attackType
			rec.currentSpeed  = phase.speed
		end
	end
	return chosen
end

-- ─────────────────────────────────────────
-- AOE
-- ─────────────────────────────────────────
local function doAOE(rec)
	local def    = rec.def
	local pos    = rec.body.Position
	local radius = def.aoeRadius or 12
	local dmg    = math.floor(def.damage * (def.aoeDamageScale or 0.5))

	local ring        = Instance.new("Part")
	ring.Shape        = Enum.PartType.Cylinder
	ring.Size         = Vector3.new(0.5, radius * 2, radius * 2)
	ring.CFrame       = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material     = Enum.Material.Neon
	ring.Color        = def.accentColor
	ring.Transparency = 0.4
	ring.Anchored     = true
	ring.CanCollide   = false
	ring.Parent       = workspace
	Debris:AddItem(ring, 0.5)

	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude <= radius then
			damagePlayer(p, dmg, def)
		end
	end
end

-- ─────────────────────────────────────────
-- Charge
-- ─────────────────────────────────────────
local function doCharge(rec, targetPos)
	if rec.charging then return end
	rec.charging = true

	local def      = rec.def
	local body     = rec.body
	local windupTime = def.chargeWindup or 1.0
	local startPos = body.Position
	local shakeEnd = tick() + windupTime

	task.spawn(function()
		while tick() < shakeEnd do
			body.CFrame = CFrame.new(
				startPos + Vector3.new(math.random(-1, 1) * 0.2, 0, math.random(-1, 1) * 0.2)
			)
			task.wait(0.05)
		end
		body.CFrame = CFrame.new(startPos)

		local dir      = (targetPos - startPos).Unit
		local power    = def.chargePower or 80
		local steps    = 12
		local stepDist = power / steps * 0.1

		for _ = 1, steps do
			if not body or not body.Parent then break end
			body.CFrame = CFrame.new(body.Position + dir * stepDist)
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local hrp  = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - body.Position).Magnitude <= def.size * 5 then
					damagePlayer(p, def.damage, def)
				end
			end
			task.wait(0.03)
		end
		rec.charging = false
	end)
end

-- ─────────────────────────────────────────
-- Remove enemy
-- ─────────────────────────────────────────
local function removeEnemy(rec)
	rec.dead = true
	if rec.model and rec.model.Parent then rec.model:Destroy() end
	for i = #Enemies, 1, -1 do
		if Enemies[i] == rec then table.remove(Enemies, i) break end
	end

	if rec.def.tier == "Boss" then
		local delay = rec.def.respawnDelay or 300
		BossTimers[rec.zoneKey] = delay
		Remotes:FindFirstChild("BossDied"):FireAllClients({
			name    = rec.def.displayName,
			zone    = rec.zoneKey,
			respawn = delay,
		})
		print(string.format("[EnemyManager] Boss '%s' defeated. Respawn in %ds.",
			rec.def.displayName, delay))
	end
end

-- ─────────────────────────────────────────
-- Spawn a single enemy
-- ─────────────────────────────────────────
local function spawnEnemy(def, zoneKey, spawnPos)
	local mobLevel = calcMobLevel(zoneKey, spawnPos or Vector3.new(0, 0, 0), def.tier)

	-- Scale stats
	local scaledHP  = LevelData.ScaleMobHP(def.health, mobLevel)
	local scaledDmg = LevelData.ScaleMobDmg(def.damage, mobLevel)
	local scaledXP  = LevelData.ScaleMobXP(def.xpReward, mobLevel)
	local scaledCry = LevelData.ScaleMobCrystals(def.crystalDrop or 0, mobLevel)

	-- Event health modifier
	local hpMult = (_G.ActiveEvent and _G.ActiveEvent.enemyHealthMult) or 1.0
	local maxHP  = math.floor(scaledHP * hpMult)

	local model, body, hpBar = buildEnemyModel(def, mobLevel)

	local pos = spawnPos or ZoneData.RandomPosOutsideSafe(zoneKey, 3)
	body.CFrame = CFrame.new(pos)
	model.Parent = workspace

	local rec = {
		model        = model,
		body         = body,
		hpBar        = hpBar,
		def          = def,
		zoneKey      = zoneKey,
		mobLevel     = mobLevel,
		scaledDmg    = scaledDmg,
		scaledXP     = scaledXP,
		scaledCry    = scaledCry,
		maxHealth    = maxHP,
		health       = maxHP,
		dead         = false,
		lastAttack   = 0,
		lastMove     = 0,
		orbAngle     = 0,
		charging     = false,
		currentSpeed = def.speed,
	}
	table.insert(Enemies, rec)

	if def.tier == "Boss" then
		Remotes:FindFirstChild("BossSpawned"):FireAllClients({
			name       = def.displayName,
			zone       = zoneKey,
			maxHealth  = maxHP,
			themeColor = def.bossThemeColor or def.bodyColor,
			level      = mobLevel,
		})
	end
	return rec
end

-- ─────────────────────────────────────────
-- Zone enemy counts
-- ─────────────────────────────────────────
local function countZone(zoneKey, tier)
	local n = 0
	for _, rec in ipairs(Enemies) do
		if rec.zoneKey == zoneKey and rec.def.tier == tier and not rec.dead then
			n = n + 1
		end
	end
	return n
end

local function isBossAlive(zoneKey)
	for _, rec in ipairs(Enemies) do
		if rec.zoneKey == zoneKey and rec.def.tier == "Boss" and not rec.dead then
			return true
		end
	end
	return false
end

local function trySpawnForZone(zoneKey)
	local zone = ZoneData.Zones[zoneKey]
	if not zone then return end

	local zoneEnemies = EnemyData[zone.enemyZone]
	if not zoneEnemies then return end

	local normals, elites, bossDef = {}, {}, nil
	for _, def in ipairs(zoneEnemies) do
		if def.tier == "Normal" then
			table.insert(normals, def)
		elseif def.tier == "Elite" then
			table.insert(elites, def)
		elseif def.tier == "Boss" and def.key == zone.bossKey then
			bossDef = def
		end
	end

	-- Normal fills
	local needed = zone.maxNormals - countZone(zoneKey, "Normal")
	for _ = 1, math.max(0, needed) do
		if #normals > 0 then
			local def    = normals[math.random(1, #normals)]
			local origin = ZoneData.RandomPosOutsideSafe(zoneKey, 3)
			local groupSize = def.groupSize or 1
			for _ = 1, groupSize do
				local offset = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
				spawnEnemy(def, zoneKey, origin + offset)
			end
		end
	end

	-- Elite fills
	if countZone(zoneKey, "Elite") < zone.maxElites and #elites > 0 then
		local def = elites[math.random(1, #elites)]
		spawnEnemy(def, zoneKey, ZoneData.RandomPosOutsideSafe(zoneKey, 3))
	end

	-- Boss
	if bossDef and not isBossAlive(zoneKey) and not BossTimers[zoneKey] then
		spawnEnemy(bossDef, zoneKey, zone.spawn + Vector3.new(0, 3, 60))
		BossTimers[zoneKey] = nil
	end
end

-- ─────────────────────────────────────────
-- AI update (per heartbeat)
-- ─────────────────────────────────────────
local function updateEnemy(rec, dt)
	if rec.dead then return end
	local body = rec.body
	if not body or not body.Parent then removeEnemy(rec) return end

	local def = rec.def
	local pos = body.Position

	-- Animate boss orb
	if def.tier == "Boss" then
		local orb = rec.model:FindFirstChild("OrbCore")
		if orb then
			rec.orbAngle = (rec.orbAngle or 0) + dt * 1.5
			local r      = def.size * 5
			orb.CFrame   = CFrame.new(pos + Vector3.new(
				math.cos(rec.orbAngle) * r,
				math.sin(rec.orbAngle * 0.5) * 2,
				math.sin(rec.orbAngle) * r
			))
		end
	end

	-- Keep enemy above ground
	if pos.Y < 1 then
		body.CFrame = CFrame.new(Vector3.new(pos.X, 3, pos.Z))
	end

	-- Nearest eligible player
	local nearPlayer, nearHRP, nearDist = getNearestPlayer(pos, def.aggroRange)

	if not nearPlayer then
		-- Idle wander (stay inside zone bounds)
		rec.lastMove = (rec.lastMove or 0) + dt
		if rec.lastMove >= 3.0 then
			rec.lastMove = 0
			local wander = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1))
			if wander.Magnitude > 0 then
				local newPos = pos + wander.Unit * 3
				-- Don't wander into safe zone
				if not ZoneData.IsInSafeZone(newPos) then
					body.CFrame = CFrame.new(newPos)
				end
			end
		end
		return
	end

	-- Don't chase into safe zone
	if ZoneData.IsInSafeZone(nearHRP.Position) then return end

	local attackType = getAttackType(rec)
	local spd        = rec.currentSpeed or def.speed
	local atkRange   = def.attackRange

	-- Movement
	if not rec.charging then
		local dir = (nearHRP.Position - pos)
		dir = Vector3.new(dir.X, 0, dir.Z)

		if attackType == "ranged" then
			local prefDist = math.max(atkRange * 1.5, 15)
			if nearDist > prefDist + 3 then
				body.CFrame = CFrame.new(pos + dir.Unit * spd * dt)
					* CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
			elseif nearDist < prefDist - 3 then
				body.CFrame = CFrame.new(pos - dir.Unit * spd * dt)
					* CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
			end
		else
			if nearDist > atkRange then
				body.CFrame = CFrame.new(pos + dir.Unit * math.min(spd * dt, nearDist - atkRange))
					* CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
			end
		end

		-- Prevent walking into safe zone
		if ZoneData.IsInSafeZone(body.Position) then
			body.CFrame = CFrame.new(pos)  -- revert
		end
	end

	-- Attack
	local now = tick()
	if now - (rec.lastAttack or 0) < def.attackRate then return end

	-- Use scaled damage from spawn time
	local dmg = rec.scaledDmg or def.damage

	if attackType == "melee" then
		if nearDist <= atkRange + 1 then
			rec.lastAttack = now
			damagePlayer(nearPlayer, dmg, def)
			local origColor = body.Color
			body.Color = Color3.new(1, 0.3, 0.3)
			task.delay(0.12, function()
				if body and body.Parent then body.Color = origColor end
			end)
		end

	elseif attackType == "charge" then
		if nearDist <= atkRange * 3 then
			rec.lastAttack = now
			doCharge(rec, nearHRP.Position)
		end

	elseif attackType == "ranged" then
		if nearDist <= def.aggroRange then
			rec.lastAttack = now
			fireProjectile(pos + Vector3.new(0, def.size * 2, 0), nearHRP.Position, def)
		end

	elseif attackType == "aoe" then
		rec.lastAttack = now
		doAOE(rec)
	end
end

-- ─────────────────────────────────────────
-- Expose: damage enemy (called from GameServer)
-- ─────────────────────────────────────────
function _G.DamageEnemy(enemyModelName, damage)
	for _, rec in ipairs(Enemies) do
		if not rec.dead and rec.model.Name == enemyModelName then
			rec.health = rec.health - damage

			if rec.hpBar then
				rec.hpBar.Size = UDim2.new(
					math.max(0, rec.health / rec.maxHealth), 0, 0.4, 0
				)
			end

			if rec.def.tier == "Boss" then
				Remotes:FindFirstChild("BossHealthChanged"):FireAllClients({
					zone      = rec.zoneKey,
					health    = rec.health,
					maxHealth = rec.maxHealth,
					name      = rec.def.displayName,
					level     = rec.mobLevel,
				})
			end

			if rec.health <= 0 then
				local xp  = rec.scaledXP  or rec.def.xpReward
				local cry = rec.scaledCry or rec.def.crystalDrop
				removeEnemy(rec)
				return xp, cry
			end
			return nil, nil
		end
	end
	return nil, nil
end

-- ─────────────────────────────────────────
-- Spawn loops
-- ─────────────────────────────────────────
local spawnTimer = 0
local dotTimer   = 0
local bossTimer  = 0

RunService.Heartbeat:Connect(function(dt)

	-- Enemy AI
	for _, rec in ipairs(Enemies) do
		pcall(updateEnemy, rec, dt)
	end

	-- DoT ticks
	dotTimer = dotTimer + dt
	if dotTimer >= 1 then
		dotTimer = 0
		for i = #ActiveDots, 1, -1 do
			local dot   = ActiveDots[i]
			local pData = _G.PlayerData and _G.PlayerData[dot.player]
			if pData and dot.player.Character then
				pData.currentHealth = math.max(1, pData.currentHealth - dot.dps)
				local hrp = dot.player.Character:FindFirstChild("HumanoidRootPart")
				Remotes:FindFirstChild("DamageDealt"):FireClient(dot.player, {
					amount   = dot.dps,
					isDoT    = true,
					position = hrp and hrp.Position + Vector3.new(0, 3, 0) or Vector3.new(0, 5, 0),
				})
			end
			dot.remaining = dot.remaining - 1
			if dot.remaining <= 0 then table.remove(ActiveDots, i) end
		end
	end

	-- Boss respawn countdown
	bossTimer = bossTimer + dt
	if bossTimer >= 1 then
		bossTimer = 0
		for zoneKey, timeLeft in pairs(BossTimers) do
			BossTimers[zoneKey] = timeLeft - 1
			if BossTimers[zoneKey] <= 0 then BossTimers[zoneKey] = nil end
		end
	end

	-- Zone refill
	spawnTimer = spawnTimer + dt
	if spawnTimer >= 8 then
		spawnTimer = 0
		for _, zoneKey in ipairs(ZoneData.ZoneOrder) do
			pcall(trySpawnForZone, zoneKey)
		end
	end
end)

-- ─────────────────────────────────────────
-- Initial population
-- ─────────────────────────────────────────
task.wait(5)
for _, zoneKey in ipairs(ZoneData.ZoneOrder) do
	for _ = 1, 3 do pcall(trySpawnForZone, zoneKey) end
end

print("[InsectEvo] EnemyManager initialized. Zones: "
	.. table.concat(ZoneData.ZoneOrder, ", "))
