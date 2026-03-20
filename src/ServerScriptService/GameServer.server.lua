-- GameServer.server.lua
-- Core server: player data, level system, XP/evolution every 10 levels,
-- zone tracking, food spawning, rebirth system, and crystal/enemy kill rewards.
-- Integrates with ZoneManager (_G.TeleportToZone), EnemyManager (_G.DamageEnemy),
-- MonetizationServer (_G.GetMultipliers), PetServer (_G.GetPetBuffs).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local DataStoreService  = game:GetService("DataStoreService")

local InsectData   = require(ReplicatedStorage:WaitForChild("InsectData"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
<<<<<<< Updated upstream
=======
local ZoneData     = require(ReplicatedStorage:WaitForChild("ZoneData"))
local LevelData    = require(ReplicatedStorage:WaitForChild("LevelData"))
>>>>>>> Stashed changes
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local Remotes   = RemoteEvents.Init()
local DataStore = DataStoreService:GetDataStore("InsectEvoV3")  -- V3: level+zone system

-- ─────────────────────────────────────────
-- Player data table (shared via _G)
-- ─────────────────────────────────────────
local PlayerData = {}
_G.PlayerData    = PlayerData

local function defaultData(insectType)
	insectType  = insectType or "Ant"
	local stage = InsectData.GetStage(insectType, 1)
	return {
		insectType    = insectType,
		level         = 1,
		xp            = 0,
		stageIndex    = 1,       -- auto-derived from level; stored for convenience
		rebirths      = 0,
		currentZone   = "Grassland",
		visitedZones  = { Grassland = true },
		maxHealth     = stage.maxHealth,
		currentHealth = stage.maxHealth,
		crystals      = 0,
	}
end

-- ─────────────────────────────────────────
-- DataStore
-- ─────────────────────────────────────────
local function loadData(player)
	local key = GameConfig.DataStoreKey .. player.UserId
	local ok, saved = pcall(function() return DataStore:GetAsync(key) end)
	if ok and saved then return saved end
	return nil
end

local function saveData(player)
	local data = PlayerData[player]
	if not data then return end
	local key      = GameConfig.DataStoreKey .. player.UserId
	local petState = _G.PetState and _G.PetState[player]
	pcall(function()
		DataStore:SetAsync(key, {
			insectType   = data.insectType,
			level        = data.level,
			xp           = data.xp,
			rebirths     = data.rebirths,
			currentZone  = data.currentZone,
			visitedZones = data.visitedZones,
			crystals     = data.crystals,
			pets         = petState and petState.pets    or {},
			equippedPet  = petState and petState.equipped or nil,
		})
	end)
end

-- ─────────────────────────────────────────
-- Stage / stats helpers
-- ─────────────────────────────────────────
local function syncStageFromLevel(data)
	data.stageIndex = LevelData.GetStageForLevel(data.level)
end

local function applyStats(player, data)
	local character = player.Character
	if not character then return end

	syncStageFromLevel(data)
	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	-- Multipliers: passes + active event + rebirth
	local passMults   = (_G.GetMultipliers and _G.GetMultipliers(player))
		or { xpMult = 1, crystalMult = 1, dmgMult = 1, speedBonus = 0 }
	local petBuffs    = (_G.GetPetBuffs and _G.GetPetBuffs(player))
		or { speed = 0, health = 0, damagePercent = 0 }
	local rebMults    = LevelData.GetRebirthMults(data.rebirths)

	local finalMaxHP  = stageInfo.maxHealth + petBuffs.health
	local finalSpeed  = stageInfo.walkSpeed + (passMults.speedBonus or 0) + petBuffs.speed
	local finalJump   = stageInfo.jumpPower

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = finalMaxHP
		humanoid.Health    = math.min(data.currentHealth, finalMaxHP)
		humanoid.WalkSpeed = finalSpeed
		humanoid.JumpPower = finalJump
		for _, scaleName in ipairs({
			"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"
		}) do
			local sv = humanoid:FindFirstChild(scaleName)
			if sv then sv.Value = stageInfo.size end
		end
	end

	-- Colour body parts
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.BrickColor = BrickColor.new(stageInfo.color)
		end
	end

	-- Notify client
	local xpReq = LevelData.XPTable[data.level]
	Remotes:FindFirstChild("StatsChanged"):FireClient(player, {
		insectType    = data.insectType,
		stageIndex    = data.stageIndex,
		stageName     = stageInfo.name,
		maxHealth     = finalMaxHP,
		currentHealth = data.currentHealth,
		level         = data.level,
		maxLevel      = LevelData.MaxLevel,
		xp            = data.xp,
		xpRequired    = xpReq,
		rebirths      = data.rebirths,
		abilities     = stageInfo.abilities,
		description   = stageInfo.description,
		crystals      = data.crystals,
		currentZone   = data.currentZone,
		visitedZones  = data.visitedZones,
	})
end

_G.ApplyPlayerStats = function(player)
	local data = PlayerData[player]
	if data then applyStats(player, data) end
end

-- ─────────────────────────────────────────
-- Crystal helpers
-- ─────────────────────────────────────────
_G.PlayerCrystals = {}

local function notifyCrystals(player)
	local data = PlayerData[player]
	if not data then return end
	_G.PlayerCrystals[player] = data.crystals
	Remotes:FindFirstChild("CrystalsChanged"):FireClient(player, data.crystals)
end

_G.AddCrystals = function(player, amount)
	local data = PlayerData[player]
	if not data then return end
	data.crystals = data.crystals + math.floor(amount)
	notifyCrystals(player)
end

_G.SpendCrystals = function(player, amount)
	local data = PlayerData[player]
	if not data then return false end
	if data.crystals < amount then return false end
	data.crystals = data.crystals - amount
	notifyCrystals(player)
	return true
end

-- ─────────────────────────────────────────
-- XP & Level-up
-- ─────────────────────────────────────────
local function addXP(player, baseAmount)
	local data = PlayerData[player]
	if not data then return end
	if data.level >= LevelData.MaxLevel then return end  -- cap; must rebirth

	-- Multipliers
	local passMults  = (_G.GetMultipliers and _G.GetMultipliers(player)) or { xpMult = 1, crystalMult = 1 }
	local pathMult   = GameConfig.PathXPMultiplier and GameConfig.PathXPMultiplier[data.insectType] or 1.0
	local rebMults   = LevelData.GetRebirthMults(data.rebirths)

	local xpGain      = math.floor(baseAmount * passMults.xpMult * pathMult * rebMults.xpMult)
	local crystalGain = math.floor(baseAmount * (GameConfig.CrystalsPerFoodXP or 0.1) * (passMults.crystalMult or 1))

	data.xp = data.xp + xpGain
	if crystalGain > 0 then _G.AddCrystals(player, crystalGain) end

	-- Level-up loop (can gain multiple levels at once)
	local evolved = false
	while data.level < LevelData.MaxLevel do
		local xpNeeded = LevelData.XPTable[data.level]
		if data.xp < xpNeeded then break end
		data.xp    = data.xp - xpNeeded
		data.level = data.level + 1

		-- Check evolution (every 10 levels)
		local oldStage = data.stageIndex
		syncStageFromLevel(data)
		if data.stageIndex > oldStage then
			evolved = true
			local newStage = InsectData.GetStage(data.insectType, data.stageIndex)
			data.maxHealth     = newStage.maxHealth
			data.currentHealth = newStage.maxHealth

			Remotes:FindFirstChild("EvolutionUnlocked"):FireClient(player, {
				stageName   = newStage.name,
				stageIndex  = data.stageIndex,
				description = newStage.description,
				abilities   = newStage.abilities,
			})
		end

		-- Fire level-up event
		Remotes:FindFirstChild("LevelUp"):FireClient(player, {
			level        = data.level,
			stageEvolved = evolved,
		})
	end

	if evolved then
		applyStats(player, data)
	else
		local xpReq = LevelData.XPTable[data.level]
		Remotes:FindFirstChild("XPChanged"):FireClient(player, {
			xp         = data.xp,
			xpRequired = xpReq,
			level      = data.level,
			maxLevel   = LevelData.MaxLevel,
		})
	end
end

_G.AddXP = addXP

-- ─────────────────────────────────────────
<<<<<<< Updated upstream
-- Food system
-- ─────────────────────────────────────────
local foodItems = {}
=======
-- Rebirth
-- ─────────────────────────────────────────
local function doRebirth(player)
	local data = PlayerData[player]
	if not data then return false end
	if data.level < LevelData.MaxLevel then return false end
	if data.rebirths >= LevelData.MaxRebirths then return false end

	data.rebirths     = data.rebirths + 1
	data.level        = 1
	data.xp           = 0
	data.stageIndex   = 1
	data.currentZone  = "Grassland"
	data.visitedZones = { Grassland = true }

	local stage        = InsectData.GetStage(data.insectType, 1)
	data.maxHealth     = stage.maxHealth
	data.currentHealth = stage.maxHealth

	local mults = LevelData.GetRebirthMults(data.rebirths)
	Remotes:FindFirstChild("RebirthComplete"):FireClient(player, {
		rebirths = data.rebirths,
		xpMult   = mults.xpMult,
		dmgMult  = mults.dmgMult,
	})
	Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)

	-- Teleport back to Grassland
	if _G.TeleportToZone then
		_G.TeleportToZone(player, "Grassland")
	end

	applyStats(player, data)
	return true
end

-- ─────────────────────────────────────────
-- Zone management helpers
-- ─────────────────────────────────────────
_G.SetPlayerZone = function(player, zoneKey)
	local data = PlayerData[player]
	if not data then return end
	data.currentZone = zoneKey
	data.visitedZones[zoneKey] = true
	Remotes:FindFirstChild("ZoneChanged"):FireClient(player, {
		zone        = zoneKey,
		displayName = ZoneData.Zones[zoneKey] and ZoneData.Zones[zoneKey].displayName or zoneKey,
	})
	Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)
end

_G.GetPlayerLevel = function(player)
	local data = PlayerData[player]
	return data and data.level or 1
end

_G.GetPlayerZone = function(player)
	local data = PlayerData[player]
	return data and data.currentZone or "Grassland"
end

-- ─────────────────────────────────────────
-- Food system (zone-aware)
-- ─────────────────────────────────────────
local foodItems   = {}
local foodPerZone = {}
for _, k in ipairs(ZoneData.ZoneOrder) do foodPerZone[k] = 0 end
local FOOD_PER_ZONE = 20
>>>>>>> Stashed changes

local function spawnFood()
	if #foodItems >= GameConfig.FoodSpawnCount then return end
	local foodList = InsectData.FoodItems
	local pick     = foodList[math.random(1, #foodList)]
	local mapSize  = GameConfig.MapSize

	local part          = Instance.new("Part")
<<<<<<< Updated upstream
	part.Name           = "Food_" .. pick.name
	part.Size           = Vector3.new(pick.size, pick.size, pick.size) * 3
	part.BrickColor     = BrickColor.new(pick.color)
	part.Material       = Enum.Material.SmoothPlastic
	part.Anchored       = true
	part.CanCollide     = false
	part.Position       = Vector3.new(
		math.random(-mapSize, mapSize), 2, math.random(-mapSize, mapSize)
	)
	part.Parent         = workspace

	local item = { part = part, xp = pick.xp, collected = false }
=======
	part.Name           = "Food_" .. pick.key
	part.Material       = Enum.Material.SmoothPlastic
	part.Color          = pick.bodyColor or Color3.fromRGB(100, 200, 100)
	part.Anchored       = true
	part.CanCollide     = false
	part.CastShadow     = false

	if pick.shape == "Sphere" then
		part.Shape = Enum.PartType.Ball
		part.Size  = Vector3.new(s, s, s)
	elseif pick.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
		part.Size  = Vector3.new(s * 0.5, s * 1.6, s * 1.6)
	else
		part.Size  = Vector3.new(s * 1.2, s * 0.6, s * 1.2)
	end
	part.Position = pos

	-- Glow orb
	local glow          = Instance.new("Part")
	glow.Shape          = Enum.PartType.Ball
	glow.Size           = Vector3.new(s * 0.4, s * 0.4, s * 0.4)
	glow.Material       = Enum.Material.Neon
	glow.Color          = pick.accentColor or pick.bodyColor
	glow.Anchored       = true
	glow.CanCollide     = false
	glow.CastShadow     = false
	glow.Position       = pos + Vector3.new(0, s * 0.8, 0)
	glow.Parent         = workspace

	-- Name tag
	local bb            = Instance.new("BillboardGui")
	bb.Size             = UDim2.new(0, 80, 0, 16)
	bb.StudsOffset      = Vector3.new(0, s + 1, 0)
	bb.AlwaysOnTop      = false
	bb.MaxDistance      = 30
	bb.Parent           = part

	local lbl           = Instance.new("TextLabel")
	lbl.Size            = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text            = (pick.emoji or "🍃") .. " " .. pick.displayName
	lbl.TextColor3      = Color3.new(1, 1, 1)
	lbl.Font            = Enum.Font.GothamBold
	lbl.TextScaled      = true
	lbl.Parent          = bb

	return part, glow
end

local function spawnZoneFood(zoneKey)
	if (foodPerZone[zoneKey] or 0) >= FOOD_PER_ZONE then return end
	local pick = ZoneData.RollFood(zoneKey)
	if not pick then return end
	local pos  = ZoneData.RandomPos(zoneKey, 2)

	local part, glowPart = buildFoodPart(pick, pos)
	part.Parent = workspace

	foodPerZone[zoneKey] = (foodPerZone[zoneKey] or 0) + 1
	local item = {
		part = part, glow = glowPart,
		xp   = pick.xp, zone = zoneKey, collected = false,
	}
>>>>>>> Stashed changes
	table.insert(foodItems, item)

	part.Touched:Connect(function(hit)
		if item.collected then return end
<<<<<<< Updated upstream
		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if player and PlayerData[player] then
=======
		local char = hit.Parent
		local p    = Players:GetPlayerFromCharacter(char)
		if p and PlayerData[p] then
>>>>>>> Stashed changes
			item.collected = true
			part:Destroy()
			for i, f in ipairs(foodItems) do
				if f == item then table.remove(foodItems, i) break end
			end
			addXP(player, pick.xp)
		end
	end)
end

<<<<<<< Updated upstream
-- ─────────────────────────────────────────
-- Enemy system
-- ─────────────────────────────────────────
local enemies = {}

local function spawnEnemy()
	if #enemies >= GameConfig.EnemySpawnCount then return end
	local pick    = InsectData.Enemies[math.random(1, #InsectData.Enemies)]
	local mapSize = GameConfig.MapSize

	-- Apply Blood Moon health modifier
	local healthMult = (_G.ActiveEvent and _G.ActiveEvent.enemyHealthMult) or 1.0

	local model         = Instance.new("Model")
	model.Name          = "Enemy_" .. pick.name

	local body          = Instance.new("Part")
	body.Name           = "HumanoidRootPart"
	body.Size           = Vector3.new(pick.size * 4, pick.size * 4, pick.size * 4)
	body.BrickColor     = BrickColor.new(pick.color)
	body.Material       = Enum.Material.SmoothPlastic
	body.Position       = Vector3.new(
		math.random(-mapSize, mapSize), pick.size * 2, math.random(-mapSize, mapSize)
	)
	body.Parent         = model
	model.PrimaryPart   = body

	-- Health bar billboard
	local billboard            = Instance.new("BillboardGui")
	billboard.Size             = UDim2.new(0, 100, 0, 14)
	billboard.StudsOffset      = Vector3.new(0, pick.size * 4 + 2, 0)
	billboard.AlwaysOnTop      = false
	billboard.Parent           = body

	local bg = Instance.new("Frame")
	bg.Size             = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	bg.BorderSizePixel  = 0
	bg.Parent           = billboard

	local hpBar = Instance.new("Frame")
	hpBar.Name              = "HPBar"
	hpBar.Size              = UDim2.new(1, 0, 1, 0)
	hpBar.BackgroundColor3  = Color3.fromRGB(220, 60, 60)
	hpBar.BorderSizePixel   = 0
	hpBar.Parent            = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size              = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text              = pick.name
	nameLabel.TextColor3        = Color3.new(1, 1, 1)
	nameLabel.TextScaled        = true
	nameLabel.Font              = Enum.Font.GothamBold
	nameLabel.Parent            = billboard

	model.Parent = workspace

	local maxHP = math.floor(pick.health * healthMult)
	local enemyRecord = {
		model      = model,
		body       = body,
		hpBar      = hpBar,
		maxHealth  = maxHP,
		health     = maxHP,
		damage     = pick.damage,
		speed      = pick.speed,
		xpReward   = pick.xpReward,
		dead       = false,
		lastMove   = 0,
	}
	table.insert(enemies, enemyRecord)
end

local function removeEnemy(rec)
	rec.dead = true
	if rec.model and rec.model.Parent then rec.model:Destroy() end
	for i, e in ipairs(enemies) do
		if e == rec then table.remove(enemies, i) break end
	end
end

local function updateEnemyAI(enemy, dt)
	if enemy.dead then return end
	local body = enemy.body
	if not body or not body.Parent then removeEnemy(enemy) return end

	enemy.lastMove = (enemy.lastMove or 0) + dt

	local nearestDist   = 40
	local nearestPlayer = nil
	local nearestHRP    = nil

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dist = (hrp.Position - body.Position).Magnitude
			if dist < nearestDist then
				nearestDist   = dist
				nearestPlayer = player
				nearestHRP    = hrp
			end
		end
	end

	if nearestHRP and enemy.lastMove >= 0.05 then
		enemy.lastMove = 0
		local dir = (nearestHRP.Position - body.Position).Unit
		body.CFrame = body.CFrame + Vector3.new(dir.X, 0, dir.Z) * enemy.speed * 0.05 * 20

		if nearestDist < 5 then
			local data = PlayerData[nearestPlayer]
			if data then
				local invincible = nearestPlayer.Character
					and nearestPlayer.Character:FindFirstChild("Invincible")
				if not invincible then
					data.currentHealth = math.max(0, data.currentHealth - enemy.damage * dt * 2)
					if data.currentHealth <= 0 then
						Remotes:FindFirstChild("PlayerDied"):FireClient(nearestPlayer)
						data.currentHealth = data.maxHealth
					end
				end
			end
		end
	elseif enemy.lastMove >= 2 then
		enemy.lastMove = 0
		local wander = Vector3.new(math.random(-1,1), 0, math.random(-1,1)).Unit
		body.CFrame = body.CFrame + wander * 3
	end
end

=======
>>>>>>> Stashed changes
-- ─────────────────────────────────────────
-- Remotes
-- ─────────────────────────────────────────
Remotes:FindFirstChild("ChooseInsect").OnServerEvent:Connect(function(player, insectType)
	local valid = false
	for _, t in ipairs(InsectData.GetInsectTypes()) do
		if t == insectType then valid = true break end
	end
	if not valid then return end
	local data = PlayerData[player]
	if not data or data.level > 1 then return end  -- only allowed at level 1

	data.insectType = insectType
	local stage     = InsectData.GetStage(insectType, 1)
	data.maxHealth     = stage.maxHealth
	data.currentHealth = stage.maxHealth
	data.xp            = 0
	applyStats(player, data)
end)

Remotes:FindFirstChild("AttackEnemy").OnServerEvent:Connect(function(player, enemyModelName)
	local data = PlayerData[player]
	if not data then return end
	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

<<<<<<< Updated upstream
	local mults     = (_G.GetMultipliers and _G.GetMultipliers(player))
		            or { dmgMult = 1 }
	local petBuffs  = (_G.GetPetBuffs and _G.GetPetBuffs(player))
		            or { damagePercent = 0 }
	local finalDmg  = math.floor(
		stageInfo.damage * mults.dmgMult * (1 + petBuffs.damagePercent)
	)

	for _, enemy in ipairs(enemies) do
		if not enemy.dead and enemy.model.Name == enemyModelName then
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - enemy.body.Position).Magnitude
				<= GameConfig.AttackRange + stageInfo.size * 4 then
=======
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local enemyModel = workspace:FindFirstChild(enemyModelName)
	if not enemyModel then return end
	local enemyBody = enemyModel:FindFirstChild("HumanoidRootPart")
	if not enemyBody then return end
	if (hrp.Position - enemyBody.Position).Magnitude
		> GameConfig.AttackRange + stageInfo.size * 6 then return end

	local passMults  = (_G.GetMultipliers and _G.GetMultipliers(player)) or { dmgMult = 1 }
	local petBuffs   = (_G.GetPetBuffs and _G.GetPetBuffs(player)) or { damagePercent = 0 }
	local rebMults   = LevelData.GetRebirthMults(data.rebirths)

	local finalDmg = math.floor(
		stageInfo.damage
		* (passMults.dmgMult or 1)
		* (1 + (petBuffs.damagePercent or 0))
		* rebMults.dmgMult
	)

	local xpReward, crystalBase
	if _G.DamageEnemy then
		xpReward, crystalBase = _G.DamageEnemy(enemyModelName, finalDmg)
	end
>>>>>>> Stashed changes

				enemy.health = enemy.health - finalDmg
				enemy.hpBar.Size = UDim2.new(
					math.max(0, enemy.health / enemy.maxHealth), 0, 1, 0
				)
				Remotes:FindFirstChild("DamageDealt"):FireClient(player, {
					amount   = finalDmg,
					position = enemy.body.Position,
				})

<<<<<<< Updated upstream
				if enemy.health <= 0 then
					-- Crystal reward (Blood Moon doubles crystal drop)
					local crystalMult = (_G.ActiveEvent and _G.ActiveEvent.crystalMult) or 1.0
					local mults2      = (_G.GetMultipliers and _G.GetMultipliers(player)) or {}
					local cGain = math.floor(
						enemy.xpReward * GameConfig.CrystalsPerEnemyXP
						* crystalMult * (mults2.crystalMult or 1.0)
					)
					if cGain > 0 then _G.AddCrystals(player, cGain) end
					addXP(player, enemy.xpReward)
					removeEnemy(enemy)
				end
			end
			break
		end
=======
	if xpReward then
		local eventMult   = (_G.ActiveEvent and _G.ActiveEvent.crystalMult) or 1.0
		local crystalMult = (passMults.crystalMult or 1.0) * eventMult
		local cGain = math.floor((crystalBase or 0) * crystalMult)
		if cGain > 0 then _G.AddCrystals(player, cGain) end
		addXP(player, xpReward)
>>>>>>> Stashed changes
	end
end)

Remotes:FindFirstChild("CollectFood").OnServerEvent:Connect(function(player, foodPartName)
	for _, item in ipairs(foodItems) do
		if not item.collected and item.part and item.part.Name == foodPartName then
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - item.part.Position).Magnitude <= 10 then
				item.collected = true
				item.part:Destroy()
				addXP(player, item.xp)
			end
			break
		end
	end
end)

Remotes:FindFirstChild("ZoneTeleport").OnServerEvent:Connect(function(player, zoneKey)
	local data = PlayerData[player]
	if not data then return end
	local zone = ZoneData.Zones[zoneKey]
	if not zone then return end

	-- Must meet min level OR have already visited
	if data.level < zone.minLevel and not data.visitedZones[zoneKey] then
		return
	end

	if _G.TeleportToZone then
		_G.TeleportToZone(player, zoneKey)
	end
end)

Remotes:FindFirstChild("RebirthRequest").OnServerEvent:Connect(function(player)
	doRebirth(player)
end)

Remotes:FindFirstChild("Respawn").OnServerEvent:Connect(function(player)
	local data = PlayerData[player]
	if not data then return end
	data.currentHealth = data.maxHealth
	player:LoadCharacter()
end)

Remotes:FindFirstChild("GetPlayerData").OnServerInvoke = function(player)
	local data = PlayerData[player]
	if not data then return nil end
	syncStageFromLevel(data)
	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	return {
		insectType    = data.insectType,
		stageIndex    = data.stageIndex,
		stageName     = stageInfo and stageInfo.name or "",
		level         = data.level,
		maxLevel      = LevelData.MaxLevel,
		xp            = data.xp,
		xpRequired    = LevelData.XPTable[data.level],
		rebirths      = data.rebirths,
		maxHealth     = data.maxHealth,
		currentHealth = data.currentHealth,
		abilities     = stageInfo and stageInfo.abilities or {},
		description   = stageInfo and stageInfo.description or "",
		crystals      = data.crystals,
		currentZone   = data.currentZone,
		visitedZones  = data.visitedZones,
		passes        = (_G.PlayerPasses and _G.PlayerPasses[player]) or {},
	}
end

-- ─────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────
local function onPlayerAdded(player)
	local saved = loadData(player)
	if saved then
		-- Migrate old saves: if no level field, derive from stageIndex
		local lvl = saved.level or math.max(1, ((saved.stageIndex or 1) - 1) * 10 + 1)
		local stageInfo = InsectData.GetStage(saved.insectType or "Ant",
			LevelData.GetStageForLevel(lvl))
		PlayerData[player] = {
			insectType    = saved.insectType   or "Ant",
			level         = lvl,
			xp            = saved.xp           or 0,
			stageIndex    = LevelData.GetStageForLevel(lvl),
			rebirths      = saved.rebirths     or 0,
			currentZone   = saved.currentZone  or "Grassland",
			visitedZones  = saved.visitedZones or { Grassland = true },
			crystals      = saved.crystals     or 0,
			maxHealth     = stageInfo and stageInfo.maxHealth or 100,
			currentHealth = stageInfo and stageInfo.maxHealth or 100,
		}
		if _G.InitPetState then
			_G.InitPetState(player, saved.pets or {}, saved.equippedPet)
		end
	else
		PlayerData[player] = defaultData()
		if _G.InitPetState then _G.InitPetState(player, {}, nil) end
	end

	_G.PlayerCrystals[player] = PlayerData[player].crystals

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		local data = PlayerData[player]
		if not data then return end

		-- Teleport character to their current zone spawn
		local zoneInfo = ZoneData.Zones[data.currentZone]
		if zoneInfo and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(zoneInfo.spawn + Vector3.new(math.random(-5, 5), 2, math.random(-5, 5)))
			end
		end

		applyStats(player, data)
		notifyCrystals(player)
		Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)
		Remotes:FindFirstChild("GameStarted"):FireClient(player)
	end)

	if player.Character then
		task.wait(0.5)
		local data = PlayerData[player]
		if not data then return end
		applyStats(player, data)
		notifyCrystals(player)
		Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)
		Remotes:FindFirstChild("GameStarted"):FireClient(player)
	end
end

local function onPlayerRemoving(player)
	saveData(player)
	PlayerData[player]        = nil
	_G.PlayerCrystals[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

-- ─────────────────────────────────────────
<<<<<<< Updated upstream
-- Main loop
=======
-- Main loop: food refill across all zones
>>>>>>> Stashed changes
-- ─────────────────────────────────────────
local foodTimer  = 0
local enemyTimer = 0

RunService.Heartbeat:Connect(function(dt)
<<<<<<< Updated upstream
	foodTimer  = foodTimer  + dt
	enemyTimer = enemyTimer + dt

	if foodTimer  >= GameConfig.FoodRespawnRate  then foodTimer  = 0; for _ = 1, 3 do spawnFood()  end end
	if enemyTimer >= GameConfig.EnemyRespawnRate then enemyTimer = 0; for _ = 1, 2 do spawnEnemy() end end

	for _, enemy in ipairs(enemies) do updateEnemyAI(enemy, dt) end
end)

task.wait(2)
for _ = 1, 20 do spawnFood()  end
for _ = 1, 5  do spawnEnemy() end
=======
	foodTimer = foodTimer + dt
	if foodTimer >= (GameConfig.FoodRespawnRate or 5) then
		foodTimer = 0
		for _, zoneKey in ipairs(ZoneData.ZoneOrder) do
			for _ = 1, 3 do spawnZoneFood(zoneKey) end
		end
	end
end)

-- Initial food population
task.wait(3)
for _, zoneKey in ipairs(ZoneData.ZoneOrder) do
	for _ = 1, FOOD_PER_ZONE do spawnZoneFood(zoneKey) end
end
>>>>>>> Stashed changes

print("[InsectEvo] GameServer initialized. Level cap:", LevelData.MaxLevel,
	"| Zones:", table.concat(ZoneData.ZoneOrder, ", "))
