-- GameServer.server.lua
-- Core server loop: player data, XP/evolution, crystals, food, enemies.
-- Integrates with MonetizationServer (_G.GetMultipliers),
-- PetServer (_G.GetPetBuffs / _G.InitPetState),
-- and AdminServer (_G.ActiveEvent).

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local DataStoreService   = game:GetService("DataStoreService")

local InsectData   = require(ReplicatedStorage:WaitForChild("InsectData"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local Remotes   = RemoteEvents.Init()
local DataStore = DataStoreService:GetDataStore("InsectEvoV2")   -- V2 includes crystals

-- ─────────────────────────────────────────
-- Player data table (shared via _G for AdminServer & PetServer)
-- ─────────────────────────────────────────
local PlayerData = {}
_G.PlayerData    = PlayerData   -- AdminServer reads this for health edits

local function defaultData(insectType)
	insectType      = insectType or "Ant"
	local stage     = InsectData.GetStage(insectType, 1)
	return {
		insectType    = insectType,
		stageIndex    = 1,
		xp            = 0,
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
	local key = GameConfig.DataStoreKey .. player.UserId
	local petState = _G.PetState and _G.PetState[player]
	pcall(function()
		DataStore:SetAsync(key, {
			insectType   = data.insectType,
			stageIndex   = data.stageIndex,
			xp           = data.xp,
			crystals     = data.crystals,
			pets         = petState and petState.pets     or {},
			equippedPet  = petState and petState.equipped or nil,
		})
	end)
end

-- ─────────────────────────────────────────
-- Apply stats to character (also called by PetServer on equip)
-- ─────────────────────────────────────────
local function applyStats(player, data)
	local character = player.Character
	if not character then return end

	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	-- Multipliers from passes + active event
	local mults      = (_G.GetMultipliers and _G.GetMultipliers(player))
		             or { xpMult = 1, crystalMult = 1, dmgMult = 1, speedBonus = 0 }

	-- Pet buffs
	local petBuffs   = (_G.GetPetBuffs and _G.GetPetBuffs(player))
		             or { speed = 0, health = 0, damagePercent = 0 }

	-- Event enemy health modifier (for display; actual enemy HP set at spawn)
	local finalMaxHP    = stageInfo.maxHealth + petBuffs.health
	local finalSpeed    = stageInfo.walkSpeed + mults.speedBonus + petBuffs.speed
	local finalJump     = stageInfo.jumpPower

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = finalMaxHP
		humanoid.Health    = math.min(data.currentHealth, finalMaxHP)
		humanoid.WalkSpeed = finalSpeed
		humanoid.JumpPower = finalJump
		-- Scale
		for _, scaleName in ipairs({
			"BodyDepthScale","BodyHeightScale","BodyWidthScale","HeadScale"
		}) do
			local sv = humanoid:FindFirstChild(scaleName)
			if sv then sv.Value = stageInfo.size end
		end
	end

	-- Colour
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.BrickColor = BrickColor.new(stageInfo.color)
		end
	end

	-- Notify client
	Remotes:FindFirstChild("StatsChanged"):FireClient(player, {
		insectType    = data.insectType,
		stageIndex    = data.stageIndex,
		stageName     = stageInfo.name,
		maxHealth     = finalMaxHP,
		currentHealth = data.currentHealth,
		xp            = data.xp,
		xpRequired    = stageInfo.xpRequired,
		abilities     = stageInfo.abilities,
		description   = stageInfo.description,
		crystals      = data.crystals,
	})
end

-- Expose for PetServer.EquipPet
_G.ApplyPlayerStats = function(player)
	local data = PlayerData[player]
	if data then applyStats(player, data) end
end

-- ─────────────────────────────────────────
-- Crystal helpers (exposed to MonetizationServer & AdminServer)
-- ─────────────────────────────────────────
_G.PlayerCrystals = {}   -- mirror of data.crystals for fast lookup by PetServer

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
-- XP & Evolution
-- ─────────────────────────────────────────
local function addXP(player, baseAmount)
	local data = PlayerData[player]
	if not data then return end

	local mults  = (_G.GetMultipliers and _G.GetMultipliers(player))
		         or { xpMult = 1, crystalMult = 1 }
	local pathMult = GameConfig.PathXPMultiplier[data.insectType] or 1.0

	local xpGain       = math.floor(baseAmount * mults.xpMult * pathMult)
	local crystalGain  = math.floor(baseAmount * GameConfig.CrystalsPerFoodXP * mults.crystalMult)

	data.xp = data.xp + xpGain
	if crystalGain > 0 then _G.AddCrystals(player, crystalGain) end

	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	-- Evolution check
	if stageInfo.xpRequired and data.xp >= stageInfo.xpRequired then
		local maxStages = InsectData.GetMaxStages(data.insectType)
		if data.stageIndex < maxStages then
			data.stageIndex    = data.stageIndex + 1
			data.xp            = 0
			local newStage     = InsectData.GetStage(data.insectType, data.stageIndex)
			data.maxHealth     = newStage.maxHealth
			data.currentHealth = newStage.maxHealth

			Remotes:FindFirstChild("EvolutionUnlocked"):FireClient(player, {
				stageName   = newStage.name,
				stageIndex  = data.stageIndex,
				description = newStage.description,
				abilities   = newStage.abilities,
			})
			applyStats(player, data)
			return
		end
	end

	Remotes:FindFirstChild("XPChanged"):FireClient(player, {
		xp         = data.xp,
		xpRequired = stageInfo.xpRequired,
	})
end

-- Expose for AdminServer giveXP
_G.AddXP = addXP

-- ─────────────────────────────────────────
-- Food system
-- ─────────────────────────────────────────
local foodItems = {}

local function spawnFood()
	if #foodItems >= GameConfig.FoodSpawnCount then return end
	local foodList = InsectData.FoodItems
	local pick     = foodList[math.random(1, #foodList)]
	local mapSize  = GameConfig.MapSize

	local part          = Instance.new("Part")
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
	table.insert(foodItems, item)

	part.Touched:Connect(function(hit)
		if item.collected then return end
		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if player and PlayerData[player] then
			item.collected = true
			part:Destroy()
			for i, f in ipairs(foodItems) do
				if f == item then table.remove(foodItems, i) break end
			end
			addXP(player, pick.xp)
		end
	end)
end

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
	if not data or data.stageIndex > 1 then return end

	data.insectType    = insectType
	local stage        = InsectData.GetStage(insectType, 1)
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

				enemy.health = enemy.health - finalDmg
				enemy.hpBar.Size = UDim2.new(
					math.max(0, enemy.health / enemy.maxHealth), 0, 1, 0
				)
				Remotes:FindFirstChild("DamageDealt"):FireClient(player, {
					amount   = finalDmg,
					position = enemy.body.Position,
				})

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

Remotes:FindFirstChild("Respawn").OnServerEvent:Connect(function(player)
	local data = PlayerData[player]
	if not data then return end
	data.currentHealth = data.maxHealth
	player:LoadCharacter()
end)

Remotes:FindFirstChild("GetPlayerData").OnServerInvoke = function(player)
	local data = PlayerData[player]
	if not data then return nil end
	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	return {
		insectType    = data.insectType,
		stageIndex    = data.stageIndex,
		stageName     = stageInfo and stageInfo.name or "",
		maxHealth     = data.maxHealth,
		currentHealth = data.currentHealth,
		xp            = data.xp,
		xpRequired    = stageInfo and stageInfo.xpRequired,
		abilities     = stageInfo and stageInfo.abilities or {},
		description   = stageInfo and stageInfo.description or "",
		crystals      = data.crystals,
		passes        = (_G.PlayerPasses and _G.PlayerPasses[player]) or {},
	}
end

-- ─────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────
local function onPlayerAdded(player)
	local saved = loadData(player)
	if saved then
		local stageInfo = InsectData.GetStage(saved.insectType or "Ant", saved.stageIndex or 1)
		PlayerData[player] = {
			insectType    = saved.insectType  or "Ant",
			stageIndex    = saved.stageIndex  or 1,
			xp            = saved.xp          or 0,
			crystals      = saved.crystals    or 0,
			maxHealth     = stageInfo and stageInfo.maxHealth or 100,
			currentHealth = stageInfo and stageInfo.maxHealth or 100,
		}
		-- Init pet state from save
		if _G.InitPetState then
			_G.InitPetState(player, saved.pets, saved.equippedPet)
		end
	else
		PlayerData[player] = defaultData()
		if _G.InitPetState then
			_G.InitPetState(player, {}, nil)
		end
	end

	_G.PlayerCrystals[player] = PlayerData[player].crystals

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyStats(player, PlayerData[player])
		notifyCrystals(player)
		Remotes:FindFirstChild("GameStarted"):FireClient(player)
	end)

	if player.Character then
		task.wait(0.5)
		applyStats(player, PlayerData[player])
		notifyCrystals(player)
		Remotes:FindFirstChild("GameStarted"):FireClient(player)
	end
end

local function onPlayerRemoving(player)
	saveData(player)
	PlayerData[player]          = nil
	_G.PlayerCrystals[player]   = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ─────────────────────────────────────────
-- Main loop
-- ─────────────────────────────────────────
local foodTimer  = 0
local enemyTimer = 0

RunService.Heartbeat:Connect(function(dt)
	foodTimer  = foodTimer  + dt
	enemyTimer = enemyTimer + dt

	if foodTimer  >= GameConfig.FoodRespawnRate  then foodTimer  = 0; for _ = 1, 3 do spawnFood()  end end
	if enemyTimer >= GameConfig.EnemyRespawnRate then enemyTimer = 0; for _ = 1, 2 do spawnEnemy() end end

	for _, enemy in ipairs(enemies) do updateEnemyAI(enemy, dt) end
end)

task.wait(2)
for _ = 1, 20 do spawnFood()  end
for _ = 1, 5  do spawnEnemy() end

print("[InsectEvo] GameServer initialized.")
