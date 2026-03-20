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
local ZoneData     = require(ReplicatedStorage:WaitForChild("ZoneData"))
local LevelData    = require(ReplicatedStorage:WaitForChild("LevelData"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local Remotes   = RemoteEvents.Init()
local DataStore = DataStoreService:GetDataStore("InsectEvoV3")  -- V3: level+zone system

-- ─────────────────────────────────────────
-- Player data table (shared via _G)
-- ─────────────────────────────────────────
local PlayerData = {}
_G.PlayerData    = PlayerData

local function defaultData(insectType)
	insectType  = insectType or nil  -- nil = not chosen yet
	local stage = insectType and InsectData.GetStage(insectType, 1) or nil
	return {
		insectType              = insectType,
		level                   = 1,
		xp                      = 0,
		stageIndex              = 1,
		rebirths                = 0,
		currentZone             = "Grassland",
		visitedZones            = { Grassland = true },
		maxHealth               = stage and stage.maxHealth or 100,
		currentHealth           = stage and stage.maxHealth or 100,
		crystals                = 0,
		pendingRebirthSelection = false,  -- waiting to pick new insect after rebirth
		retainedSkill           = nil,    -- skill kept from previous rebirth path
		bossKills               = {},     -- { [zoneKey] = count } boss kills per zone
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
			insectType              = data.insectType,
			level                   = data.level,
			xp                      = data.xp,
			rebirths                = data.rebirths,
			currentZone             = data.currentZone,
			visitedZones            = data.visitedZones,
			crystals                = data.crystals,
			retainedSkill           = data.retainedSkill,
			pendingRebirthSelection = data.pendingRebirthSelection,
			pets                    = petState and petState.pets    or {},
			equippedPet             = petState and petState.equipped or nil,
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
	if not data.insectType then return end  -- no insect chosen yet

	-- Player keeps their normal Roblox avatar — no appearance changes.
	-- Stage info is still read so we can notify the client and handle HP.
	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	-- Keep humanoid MaxHealth / WalkSpeed at sane defaults; don't morph avatar.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = stageInfo.maxHealth
		humanoid.Health    = math.min(data.currentHealth, stageInfo.maxHealth)
		-- Normal walk/jump speed; not insect-scaled
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end

	-- Notify client
	local xpReq = LevelData.XPTable[data.level]
	Remotes:FindFirstChild("StatsChanged"):FireClient(player, {
		insectType    = data.insectType,
		stageIndex    = data.stageIndex,
		stageName     = stageInfo.name,
		maxHealth     = stageInfo.maxHealth,
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
		retainedSkill = data.retainedSkill,
	})
end

_G.ApplyPlayerStats = function(player)
	local data = PlayerData[player]
	if data then applyStats(player, data) end
end

-- ─────────────────────────────────────────
-- Boss-gated companion evolution
-- Called by EnemyManager after a boss dies
-- ─────────────────────────────────────────
_G.OnBossDefeated = function(zoneKey)
	-- Advance stageIndex for all players currently in that zone
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData[player]
		if not data then continue end
		if not data.insectType then continue end
		if data.currentZone ~= zoneKey then continue end

		-- Track boss kills per zone
		data.bossKills = data.bossKills or {}
		data.bossKills[zoneKey] = (data.bossKills[zoneKey] or 0) + 1

		-- Advance companion stage (cap at 5 stages, one per zone boss)
		local maxStages = #InsectData.GetInsectTypes()  -- use stage count as limit
		-- Get number of stages for this insect
		local stageCount = 0
		for i = 1, 10 do
			if InsectData.GetStage(data.insectType, i) then
				stageCount = i
			else
				break
			end
		end

		if data.stageIndex < stageCount then
			data.stageIndex = data.stageIndex + 1
			local newStage = InsectData.GetStage(data.insectType, data.stageIndex)
			if newStage then
				data.maxHealth     = newStage.maxHealth
				data.currentHealth = newStage.maxHealth

				-- Tell companion system to rebuild the model
				if _G.EvolveCompanion then
					_G.EvolveCompanion(player, data.stageIndex)
				end

				-- Notify client of evolution
				Remotes:FindFirstChild("EvolutionUnlocked"):FireClient(player, {
					stageName   = newStage.name,
					stageIndex  = data.stageIndex,
					description = newStage.description,
					abilities   = newStage.abilities,
				})
				applyStats(player, data)
			end
		end
	end
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
	if not data.insectType then return end  -- no insect chosen
	if data.level >= LevelData.MaxLevel then return end

	local passMults  = (_G.GetMultipliers and _G.GetMultipliers(player)) or { xpMult = 1, crystalMult = 1 }
	local pathMult   = GameConfig.PathXPMultiplier and GameConfig.PathXPMultiplier[data.insectType] or 1.0
	local rebMults   = LevelData.GetRebirthMults(data.rebirths)

	local xpGain      = math.floor(baseAmount * passMults.xpMult * pathMult * rebMults.xpMult)
	local crystalGain = math.floor(baseAmount * (GameConfig.CrystalsPerFoodXP or 0.1) * (passMults.crystalMult or 1))

	data.xp = data.xp + xpGain
	if crystalGain > 0 then _G.AddCrystals(player, crystalGain) end

	-- Level-up loop
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
-- Rebirth
-- ─────────────────────────────────────────
local function doRebirth(player)
	local data = PlayerData[player]
	if not data then return false end
	if data.level < LevelData.MaxLevel then return false end
	if data.rebirths >= LevelData.MaxRebirths then return false end
	if not data.insectType then return false end

	-- Determine one skill to retain from the highest unlocked stage
	local highestStage = InsectData.GetStage(data.insectType, data.stageIndex)
	local retainedSkill = nil
	if highestStage and highestStage.abilities and #highestStage.abilities > 0 then
		-- Keep the last (most powerful) ability of the final stage
		retainedSkill = highestStage.abilities[#highestStage.abilities]
	end

	data.rebirths               = data.rebirths + 1
	data.level                  = 1
	data.xp                     = 0
	data.stageIndex             = 1
	data.currentZone            = "Grassland"
	data.visitedZones           = { Grassland = true }
	data.retainedSkill          = retainedSkill
	data.pendingRebirthSelection = true
	-- Keep crystals and old insectType temporarily (will be replaced when player picks new type)

	local mults = LevelData.GetRebirthMults(data.rebirths)
	Remotes:FindFirstChild("RebirthComplete"):FireClient(player, {
		rebirths      = data.rebirths,
		xpMult        = mults.xpMult,
		dmgMult       = mults.dmgMult,
		retainedSkill = retainedSkill,
	})
	Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)

	if _G.TeleportToZone then
		_G.TeleportToZone(player, "Grassland")
	end

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

local function buildFoodPart(pick, pos)
	local s = (pick.size or 0.8) * 3

	local part          = Instance.new("Part")
	part.Name           = "Food_" .. (pick.key or pick.name or "Item")
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
	glow.Color          = pick.accentColor or pick.bodyColor or Color3.fromRGB(200, 255, 200)
	glow.Anchored       = true
	glow.CanCollide     = false
	glow.CastShadow     = false
	glow.Position       = pos + Vector3.new(0, s * 0.8, 0)
	glow.Parent         = workspace

	-- Name tag
	local bb        = Instance.new("BillboardGui")
	bb.Size         = UDim2.new(0, 80, 0, 16)
	bb.StudsOffset  = Vector3.new(0, s + 1, 0)
	bb.AlwaysOnTop  = false
	bb.MaxDistance  = 30
	bb.Parent       = part

	local lbl                      = Instance.new("TextLabel")
	lbl.Size                       = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency     = 1
	lbl.Text                       = (pick.emoji or "🍃") .. " " .. (pick.displayName or pick.name or "Food")
	lbl.TextColor3                 = Color3.new(1, 1, 1)
	lbl.Font                       = Enum.Font.GothamBold
	lbl.TextScaled                 = true
	lbl.Parent                     = bb

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
		part      = part,
		glow      = glowPart,
		xp        = pick.xp,
		zone      = zoneKey,
		collected = false,
	}
	table.insert(foodItems, item)

	part.Touched:Connect(function(hit)
		if item.collected then return end
		local char = hit.Parent
		local p    = Players:GetPlayerFromCharacter(char)
		if p and PlayerData[p] then
			item.collected = true
			foodPerZone[zoneKey] = math.max(0, (foodPerZone[zoneKey] or 1) - 1)
			part:Destroy()
			if glowPart and glowPart.Parent then glowPart:Destroy() end
			for i, f in ipairs(foodItems) do
				if f == item then table.remove(foodItems, i) break end
			end
			addXP(p, pick.xp)
		end
	end)
end

-- ─────────────────────────────────────────
-- Remotes: insect selection
-- ─────────────────────────────────────────

-- Helper: finalize insect choice and spawn the player
local function finalizeInsectChoice(player, insectType)
	local data = PlayerData[player]
	if not data then return end

	data.insectType = insectType
	local stage     = InsectData.GetStage(insectType, 1)
	if not stage then return end

	data.maxHealth              = stage.maxHealth
	data.currentHealth          = stage.maxHealth
	data.stageIndex             = 1
	data.pendingRebirthSelection = false

	-- Spawn/respawn the character (this triggers CharacterAdded which teleports & applies stats)
	player:LoadCharacter()
end

Remotes:FindFirstChild("ChooseInsect").OnServerEvent:Connect(function(player, insectType)
	local valid = false
	for _, t in ipairs(InsectData.GetInsectTypes()) do
		if t == insectType then valid = true break end
	end
	if not valid then return end

	local data = PlayerData[player]
	if not data then return end
	-- Only allowed at level 1 (new player, not mid-rebirth)
	if data.level > 1 then return end
	-- If a rebirth is pending, use the RebirthChooseInsect path instead
	if data.pendingRebirthSelection then return end

	finalizeInsectChoice(player, insectType)
end)

Remotes:FindFirstChild("RebirthChooseInsect").OnServerEvent:Connect(function(player, insectType)
	local valid = false
	for _, t in ipairs(InsectData.GetInsectTypes()) do
		if t == insectType then valid = true break end
	end
	if not valid then return end

	local data = PlayerData[player]
	if not data then return end
	if not data.pendingRebirthSelection then return end  -- must have rebirthed first

	-- Apply the new insect choice (retainedSkill stays in data)
	finalizeInsectChoice(player, insectType)
end)

-- ─────────────────────────────────────────
-- Remotes: combat
-- ─────────────────────────────────────────
Remotes:FindFirstChild("AttackEnemy").OnServerEvent:Connect(function(player, enemyModelName)
	local data = PlayerData[player]
	if not data then return end
	if not data.insectType then return end

	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local enemyModel = workspace:FindFirstChild(enemyModelName)
	if not enemyModel then return end
	local enemyBody  = enemyModel:FindFirstChild("HumanoidRootPart")
	if not enemyBody then return end
	if (hrp.Position - enemyBody.Position).Magnitude
		> GameConfig.AttackRange + stageInfo.size * 6 then return end

	local passMults = (_G.GetMultipliers and _G.GetMultipliers(player)) or { dmgMult = 1 }
	local petBuffs  = (_G.GetPetBuffs and _G.GetPetBuffs(player)) or { damagePercent = 0 }
	local rebMults  = LevelData.GetRebirthMults(data.rebirths)

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

	if xpReward then
		local eventMult   = (_G.ActiveEvent and _G.ActiveEvent.crystalMult) or 1.0
		local crystalMult = (passMults.crystalMult or 1.0) * eventMult
		local cGain = math.floor((crystalBase or 0) * crystalMult)
		if cGain > 0 then _G.AddCrystals(player, cGain) end
		addXP(player, xpReward)
	end
end)

-- ─────────────────────────────────────────
-- Remotes: misc
-- ─────────────────────────────────────────
Remotes:FindFirstChild("CollectFood").OnServerEvent:Connect(function(player, foodPartName)
	for _, item in ipairs(foodItems) do
		if not item.collected and item.part and item.part.Name == foodPartName then
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - item.part.Position).Magnitude <= 10 then
				item.collected = true
				if item.zone then
					foodPerZone[item.zone] = math.max(0, (foodPerZone[item.zone] or 1) - 1)
				end
				item.part:Destroy()
				if item.glow and item.glow.Parent then item.glow:Destroy() end
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
	if data.level < zone.minLevel and not data.visitedZones[zoneKey] then return end

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
	local stageInfo = data.insectType and InsectData.GetStage(data.insectType, data.stageIndex)
	return {
		insectType              = data.insectType,
		stageIndex              = data.stageIndex,
		stageName               = stageInfo and stageInfo.name or "",
		level                   = data.level,
		maxLevel                = LevelData.MaxLevel,
		xp                      = data.xp,
		xpRequired              = LevelData.XPTable[data.level],
		rebirths                = data.rebirths,
		maxHealth               = data.maxHealth,
		currentHealth           = data.currentHealth,
		abilities               = stageInfo and stageInfo.abilities or {},
		description             = stageInfo and stageInfo.description or "",
		crystals                = data.crystals,
		currentZone             = data.currentZone,
		visitedZones            = data.visitedZones,
		retainedSkill           = data.retainedSkill,
		pendingRebirthSelection = data.pendingRebirthSelection,
		passes                  = (_G.PlayerPasses and _G.PlayerPasses[player]) or {},
	}
end

-- ─────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────
local function onPlayerAdded(player)
	local saved = loadData(player)
	if saved then
		-- Migrate old saves
		local lvl = saved.level or math.max(1, ((saved.stageIndex or 1) - 1) * 10 + 1)
		local insType = saved.insectType or "Ant"
		local stageInfo = InsectData.GetStage(insType, LevelData.GetStageForLevel(lvl))
		PlayerData[player] = {
			insectType              = insType,
			level                   = lvl,
			xp                      = saved.xp           or 0,
			stageIndex              = LevelData.GetStageForLevel(lvl),
			rebirths                = saved.rebirths     or 0,
			currentZone             = saved.currentZone  or "Grassland",
			visitedZones            = saved.visitedZones or { Grassland = true },
			crystals                = saved.crystals     or 0,
			maxHealth               = stageInfo and stageInfo.maxHealth or 100,
			currentHealth           = stageInfo and stageInfo.maxHealth or 100,
			retainedSkill           = saved.retainedSkill or nil,
			pendingRebirthSelection = saved.pendingRebirthSelection or false,
		}
		if _G.InitPetState then
			_G.InitPetState(player, saved.pets or {}, saved.equippedPet)
		end
	else
		-- Brand new player — no insect type yet, will choose via GUI
		PlayerData[player] = defaultData(nil)
		if _G.InitPetState then _G.InitPetState(player, {}, nil) end
	end

	_G.PlayerCrystals[player] = PlayerData[player].crystals

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		local data = PlayerData[player]
		if not data then return end

		-- Teleport character to their current zone spawn
		local zoneInfo = ZoneData.Zones[data.currentZone or "Grassland"]
		if zoneInfo and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local offset = Vector3.new(math.random(-5, 5), 2, math.random(-5, 5))
				hrp.CFrame = CFrame.new(zoneInfo.spawn + offset)
			end
		end

		if data.insectType then
			applyStats(player, data)
			-- Spawn companion pet model (InsectCompanion.server.lua)
			if _G.SpawnCompanion then
				_G.SpawnCompanion(player)
			end
		end
		notifyCrystals(player)
		Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)
		Remotes:FindFirstChild("GameStarted"):FireClient(player, {
			needsInsectSelection    = (data.insectType == nil),
			pendingRebirthSelection = data.pendingRebirthSelection,
			retainedSkill           = data.retainedSkill,
			rebirths                = data.rebirths,
		})
	end)

	-- Handle the case where Character already exists (e.g. CharacterAutoLoads=true)
	if player.Character then
		task.wait(0.5)
		local data = PlayerData[player]
		if not data then return end

		local zoneInfo = ZoneData.Zones[data.currentZone or "Grassland"]
		if zoneInfo and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local offset = Vector3.new(math.random(-5, 5), 2, math.random(-5, 5))
				hrp.CFrame = CFrame.new(zoneInfo.spawn + offset)
			end
		end

		if data.insectType then
			applyStats(player, data)
			if _G.SpawnCompanion then
				_G.SpawnCompanion(player)
			end
		end
		notifyCrystals(player)
		Remotes:FindFirstChild("VisitedZonesUpdate"):FireClient(player, data.visitedZones)
		Remotes:FindFirstChild("GameStarted"):FireClient(player, {
			needsInsectSelection    = (data.insectType == nil),
			pendingRebirthSelection = data.pendingRebirthSelection,
			retainedSkill           = data.retainedSkill,
			rebirths                = data.rebirths,
		})
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
-- Main loop: food refill across all zones
-- ─────────────────────────────────────────
local foodTimer = 0

RunService.Heartbeat:Connect(function(dt)
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

print("[InsectEvo] GameServer initialized. Level cap:", LevelData.MaxLevel,
	"| Zones:", table.concat(ZoneData.ZoneOrder, ", "))
