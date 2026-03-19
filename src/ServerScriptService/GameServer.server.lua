-- GameServer.server.lua
-- Main server-side game loop: handles player data, evolution, food, enemies.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local DataStoreService   = game:GetService("DataStoreService")

local InsectData   = require(ReplicatedStorage:WaitForChild("InsectData"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

-- Initialize remotes
local Remotes = RemoteEvents.Init()

local DataStore = DataStoreService:GetDataStore("InsectEvoV1")

-- ─────────────────────────────────────────
-- Player state table
-- ─────────────────────────────────────────
local PlayerData = {}  -- [player] = { insectType, stage, xp, maxHealth, currentHealth }

local function defaultData(insectType)
	insectType = insectType or "Ant"
	local stage = InsectData.GetStage(insectType, 1)
	return {
		insectType    = insectType,
		stageIndex    = 1,
		xp            = 0,
		maxHealth     = stage.maxHealth,
		currentHealth = stage.maxHealth,
	}
end

-- ─────────────────────────────────────────
-- DataStore persistence
-- ─────────────────────────────────────────
local function loadData(player)
	local key = GameConfig.DataStoreKey .. player.UserId
	local success, data = pcall(function()
		return DataStore:GetAsync(key)
	end)
	if success and data then
		return data
	end
	return nil
end

local function saveData(player)
	local data = PlayerData[player]
	if not data then return end
	local key = GameConfig.DataStoreKey .. player.UserId
	pcall(function()
		DataStore:SetAsync(key, {
			insectType  = data.insectType,
			stageIndex  = data.stageIndex,
			xp          = data.xp,
		})
	end)
end

-- ─────────────────────────────────────────
-- Character setup
-- ─────────────────────────────────────────
local function applyStats(player, data)
	local character = player.Character
	if not character then return end

	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	-- Apply humanoid stats
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth    = stageInfo.maxHealth
		humanoid.Health       = data.currentHealth
		humanoid.WalkSpeed    = stageInfo.walkSpeed
		humanoid.JumpPower    = stageInfo.jumpPower
	end

	-- Scale character body
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local scaleTag = character:FindFirstChild("BodyScale")
		if not scaleTag then
			scaleTag = Instance.new("NumberValue")
			scaleTag.Name   = "BodyScale"
			scaleTag.Parent = character
		end
		scaleTag.Value = stageInfo.size

		-- Apply scaling via BodyDepthScale / BodyHeightScale / BodyWidthScale / HeadScale
		local function setScale(partName, val)
			local part = character:FindFirstChild(partName)
			if part then
				local sv = part:FindFirstChildOfClass("NumberValue") or Instance.new("NumberValue", part)
				sv.Value = val
			end
		end
		-- The standard Roblox R15 scale values live inside the Humanoid
		if humanoid then
			for _, scaleName in ipairs({
				"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"
			}) do
				local sv = humanoid:FindFirstChild(scaleName)
				if sv then sv.Value = stageInfo.size end
			end
		end

		-- Color the primary parts
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.BrickColor = BrickColor.new(stageInfo.color)
			end
		end
	end

	-- Notify client
	Remotes:FindFirstChild("StatsChanged"):FireClient(player, {
		insectType    = data.insectType,
		stageIndex    = data.stageIndex,
		stageName     = stageInfo.name,
		maxHealth     = stageInfo.maxHealth,
		currentHealth = data.currentHealth,
		xp            = data.xp,
		xpRequired    = stageInfo.xpRequired,
		abilities     = stageInfo.abilities,
		description   = stageInfo.description,
	})
end

-- ─────────────────────────────────────────
-- XP & Evolution
-- ─────────────────────────────────────────
local function addXP(player, amount)
	local data = PlayerData[player]
	if not data then return end

	local multiplier = GameConfig.PathXPMultiplier[data.insectType] or 1.0
	data.xp = data.xp + math.floor(amount * multiplier)

	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	-- Check evolution
	if stageInfo.xpRequired and data.xp >= stageInfo.xpRequired then
		local maxStages = InsectData.GetMaxStages(data.insectType)
		if data.stageIndex < maxStages then
			data.stageIndex    = data.stageIndex + 1
			data.xp            = 0
			local newStage     = InsectData.GetStage(data.insectType, data.stageIndex)
			data.maxHealth     = newStage.maxHealth
			data.currentHealth = newStage.maxHealth

			-- Notify evolution
			Remotes:FindFirstChild("EvolutionUnlocked"):FireClient(player, {
				stageName   = newStage.name,
				stageIndex  = data.stageIndex,
				description = newStage.description,
				abilities   = newStage.abilities,
			})

			-- Re-apply stats to character
			applyStats(player, data)
			return
		end
	end

	-- Just fire XP update
	Remotes:FindFirstChild("XPChanged"):FireClient(player, {
		xp         = data.xp,
		xpRequired = stageInfo.xpRequired,
	})
end

-- ─────────────────────────────────────────
-- Food system
-- ─────────────────────────────────────────
local foodItems = {}  -- { part, xp, collected }

local function spawnFood()
	if #foodItems >= GameConfig.FoodSpawnCount then return end

	local foodList = InsectData.FoodItems
	local pick     = foodList[math.random(1, #foodList)]
	local mapSize  = GameConfig.MapSize

	local part       = Instance.new("Part")
	part.Name        = "Food_" .. pick.name
	part.Size        = Vector3.new(pick.size, pick.size, pick.size) * 3
	part.BrickColor  = BrickColor.new(pick.color)
	part.Material    = Enum.Material.SmoothPlastic
	part.Anchored    = true
	part.CanCollide  = false

	local x = math.random(-mapSize, mapSize)
	local z = math.random(-mapSize, mapSize)
	part.Position = Vector3.new(x, 2, z)
	part.Parent   = workspace

	local item = { part = part, xp = pick.xp, collected = false }
	table.insert(foodItems, item)

	-- Touch detection
	part.Touched:Connect(function(hit)
		if item.collected then return end
		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if player and PlayerData[player] then
			item.collected = true
			part:Destroy()
			-- Remove from list
			for i, f in ipairs(foodItems) do
				if f == item then table.remove(foodItems, i) break end
			end
			addXP(player, pick.xp)
		end
	end)
end

-- ─────────────────────────────────────────
-- Enemy NPC system
-- ─────────────────────────────────────────
local enemies = {}  -- { model, health, data }

local function spawnEnemy()
	if #enemies >= GameConfig.EnemySpawnCount then return end

	local enemyList = InsectData.Enemies
	local pick      = enemyList[math.random(1, #enemyList)]
	local mapSize   = GameConfig.MapSize

	-- Create a simple NPC model
	local model    = Instance.new("Model")
	model.Name     = "Enemy_" .. pick.name

	local body        = Instance.new("Part")
	body.Name         = "HumanoidRootPart"
	body.Size         = Vector3.new(pick.size * 4, pick.size * 4, pick.size * 4)
	body.BrickColor   = BrickColor.new(pick.color)
	body.Material     = Enum.Material.SmoothPlastic

	local x = math.random(-GameConfig.MapSize, GameConfig.MapSize)
	local z = math.random(-GameConfig.MapSize, GameConfig.MapSize)
	body.Position = Vector3.new(x, pick.size * 2, z)

	body.Parent  = model
	model.PrimaryPart = body

	-- Health bar billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Size          = UDim2.new(0, 100, 0, 14)
	billboard.StudsOffset   = Vector3.new(0, pick.size * 4 + 2, 0)
	billboard.AlwaysOnTop   = false
	billboard.Parent        = body

	local bg = Instance.new("Frame")
	bg.Size            = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	bg.BorderSizePixel = 0
	bg.Parent          = billboard

	local hpBar = Instance.new("Frame")
	hpBar.Name             = "HPBar"
	hpBar.Size             = UDim2.new(1, 0, 1, 0)
	hpBar.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	hpBar.BorderSizePixel  = 0
	hpBar.Parent           = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size             = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = pick.name
	nameLabel.TextColor3       = Color3.new(1, 1, 1)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.Parent           = billboard

	model.Parent = workspace

	local enemyRecord = {
		model      = model,
		body       = body,
		hpBar      = hpBar,
		maxHealth  = pick.health,
		health     = pick.health,
		damage     = pick.damage,
		speed      = pick.speed,
		xpReward   = pick.xpReward,
		dead       = false,
		lastMove   = 0,
		target     = nil,
	}
	table.insert(enemies, enemyRecord)
end

local function removeEnemy(enemyRecord)
	enemyRecord.dead = true
	if enemyRecord.model and enemyRecord.model.Parent then
		enemyRecord.model:Destroy()
	end
	for i, e in ipairs(enemies) do
		if e == enemyRecord then
			table.remove(enemies, i)
			break
		end
	end
end

-- Simple enemy AI: wander or chase nearest player
local function updateEnemyAI(enemy, dt)
	if enemy.dead then return end
	local body = enemy.body
	if not body or not body.Parent then
		removeEnemy(enemy)
		return
	end

	enemy.lastMove = (enemy.lastMove or 0) + dt

	-- Find nearest player character
	local nearestDist   = 40
	local nearestPlayer = nil
	local nearestChar   = nil

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - body.Position).Magnitude
				if dist < nearestDist then
					nearestDist   = dist
					nearestPlayer = player
					nearestChar   = char
				end
			end
		end
	end

	if nearestChar and enemy.lastMove >= 0.05 then
		enemy.lastMove = 0
		local hrp = nearestChar:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dir = (hrp.Position - body.Position).Unit
			local vel = dir * enemy.speed * dt * 20
			body.CFrame = body.CFrame + Vector3.new(vel.X, 0, vel.Z)

			-- Attack if close enough
			if nearestDist < 5 then
				local data = PlayerData[nearestPlayer]
				if data then
					data.currentHealth = math.max(0, data.currentHealth - enemy.damage * dt * 2)
					if data.currentHealth <= 0 then
						Remotes:FindFirstChild("PlayerDied"):FireClient(nearestPlayer)
						data.currentHealth = data.maxHealth
					end
				end
			end
		end
	elseif enemy.lastMove >= 2 then
		-- Wander randomly
		enemy.lastMove = 0
		local wanderDir = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit
		body.CFrame = body.CFrame + wanderDir * 3
	end
end

-- ─────────────────────────────────────────
-- Remote: Choose insect (lobby phase)
-- ─────────────────────────────────────────
Remotes:FindFirstChild("ChooseInsect").OnServerEvent:Connect(function(player, insectType)
	local validTypes = InsectData.GetInsectTypes()
	local valid = false
	for _, t in ipairs(validTypes) do
		if t == insectType then valid = true break end
	end
	if not valid then return end

	local data = PlayerData[player]
	if not data then return end

	-- Only allow choosing before stage 2
	if data.stageIndex > 1 then return end

	data.insectType = insectType
	local stageInfo = InsectData.GetStage(insectType, 1)
	data.maxHealth     = stageInfo.maxHealth
	data.currentHealth = stageInfo.maxHealth
	data.xp            = 0

	applyStats(player, data)
end)

-- Remote: Attack enemy
Remotes:FindFirstChild("AttackEnemy").OnServerEvent:Connect(function(player, enemyModelName)
	local data = PlayerData[player]
	if not data then return end

	local stageInfo = InsectData.GetStage(data.insectType, data.stageIndex)
	if not stageInfo then return end

	for _, enemy in ipairs(enemies) do
		if not enemy.dead and enemy.model.Name == enemyModelName then
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			local ebody = enemy.body
			if hrp and ebody then
				local dist = (hrp.Position - ebody.Position).Magnitude
				if dist <= GameConfig.AttackRange + stageInfo.size * 4 then
					enemy.health = enemy.health - stageInfo.damage
					-- Update HP bar
					local frac = math.max(0, enemy.health / enemy.maxHealth)
					enemy.hpBar.Size = UDim2.new(frac, 0, 1, 0)

					Remotes:FindFirstChild("DamageDealt"):FireClient(player, {
						amount   = stageInfo.damage,
						position = ebody.Position,
					})

					if enemy.health <= 0 then
						addXP(player, enemy.xpReward)
						removeEnemy(enemy)
					end
				end
			end
			break
		end
	end
end)

-- Remote: Collect food (manual, used alongside touch)
Remotes:FindFirstChild("CollectFood").OnServerEvent:Connect(function(player, foodPartName)
	-- Touch already handles this; secondary click-collect path
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

-- Remote: Respawn
Remotes:FindFirstChild("Respawn").OnServerEvent:Connect(function(player)
	local data = PlayerData[player]
	if not data then return end
	data.currentHealth = data.maxHealth
	player:LoadCharacter()
end)

-- Remote: GetPlayerData (RemoteFunction)
Remotes:FindFirstChild("GetPlayerData").OnServerInvoke = function(player)
	return PlayerData[player]
end

-- ─────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────
local function onPlayerAdded(player)
	-- Load or create data
	local saved = loadData(player)
	if saved then
		local stageInfo = InsectData.GetStage(saved.insectType, saved.stageIndex)
		PlayerData[player] = {
			insectType    = saved.insectType,
			stageIndex    = saved.stageIndex,
			xp            = saved.xp,
			maxHealth     = stageInfo and stageInfo.maxHealth or 100,
			currentHealth = stageInfo and stageInfo.maxHealth or 100,
		}
	else
		PlayerData[player] = defaultData()
	end

	-- Apply stats on character spawn
	player.CharacterAdded:Connect(function(character)
		-- Small wait for character to fully load
		task.wait(0.5)
		applyStats(player, PlayerData[player])
		Remotes:FindFirstChild("GameStarted"):FireClient(player)
	end)

	-- If character already exists (rejoined quickly)
	if player.Character then
		task.wait(0.5)
		applyStats(player, PlayerData[player])
		Remotes:FindFirstChild("GameStarted"):FireClient(player)
	end
end

local function onPlayerRemoving(player)
	saveData(player)
	PlayerData[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (if script runs late)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ─────────────────────────────────────────
-- Main server loop
-- ─────────────────────────────────────────
local foodTimer  = 0
local enemyTimer = 0

RunService.Heartbeat:Connect(function(dt)
	foodTimer  = foodTimer  + dt
	enemyTimer = enemyTimer + dt

	if foodTimer >= GameConfig.FoodRespawnRate then
		foodTimer = 0
		for _ = 1, 3 do spawnFood() end
	end

	if enemyTimer >= GameConfig.EnemyRespawnRate then
		enemyTimer = 0
		for _ = 1, 2 do spawnEnemy() end
	end

	-- Update enemy AI
	for _, enemy in ipairs(enemies) do
		updateEnemyAI(enemy, dt)
	end
end)

-- Seed initial food and enemies
task.wait(2)
for _ = 1, 20 do spawnFood() end
for _ = 1, 5  do spawnEnemy() end

print("[InsectEvo] Server initialized.")
