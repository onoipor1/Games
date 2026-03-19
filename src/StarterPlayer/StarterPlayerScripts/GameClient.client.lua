-- GameClient.client.lua
-- Handles local input, camera, and communication with the server.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")

local InsectData   = require(ReplicatedStorage:WaitForChild("InsectData"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera    = workspace.CurrentCamera

-- ─────────────────────────────────────────
-- Remote shortcuts
-- ─────────────────────────────────────────
local function remote(name)
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

-- ─────────────────────────────────────────
-- Local state
-- ─────────────────────────────────────────
local localData = {
	insectType    = "Ant",
	stageIndex    = 1,
	stageName     = "Ant Larva",
	xp            = 0,
	xpRequired    = 50,
	maxHealth     = 30,
	currentHealth = 30,
	abilities     = {},
	description   = "",
}

local abilityCooldowns   = {}  -- [abilityName] = expireTime
local lastAttackTime     = 0

-- ─────────────────────────────────────────
-- Attack: click on enemy to attack it
-- ─────────────────────────────────────────
local function tryAttack()
	if tick() - lastAttackTime < GameConfig.AttackCooldown then return end

	local unitRay = camera:ScreenPointToRay(
		UserInputService:GetMouseLocation().X,
		UserInputService:GetMouseLocation().Y
	)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)
	if result and result.Instance then
		local hit = result.Instance
		if hit.Parent and hit.Parent.Name:sub(1, 6) == "Enemy_" then
			lastAttackTime = tick()
			remote("AttackEnemy"):FireServer(hit.Parent.Name)
		elseif hit.Name:sub(1, 5) == "Food_" then
			remote("CollectFood"):FireServer(hit.Name)
		end
	end
end

-- ─────────────────────────────────────────
-- Ability activation (keyboard 1-4 / Q/E/R/F)
-- ─────────────────────────────────────────
local abilityKeys = {
	[Enum.KeyCode.One]   = 1,
	[Enum.KeyCode.Two]   = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four]  = 4,
	[Enum.KeyCode.Q]     = 1,
	[Enum.KeyCode.E]     = 2,
	[Enum.KeyCode.R]     = 3,
	[Enum.KeyCode.F]     = 4,
}

local function useAbility(index)
	local ability = localData.abilities[index]
	if not ability then return end

	if abilityCooldowns[ability] and tick() < abilityCooldowns[ability] then
		-- Still on cooldown; UI will show this
		return
	end

	remote("UseAbility"):FireServer(ability)
	-- Optimistic local cooldown
	local cd = GameConfig.AbilityCooldowns[ability] or 0
	if cd > 0 then
		abilityCooldowns[ability] = tick() + cd
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Attack
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryAttack()
	end

	-- Abilities
	local idx = abilityKeys[input.KeyCode]
	if idx then
		useAbility(idx)
	end
end)

-- ─────────────────────────────────────────
-- Receive server events
-- ─────────────────────────────────────────
remote("StatsChanged").OnClientEvent:Connect(function(data)
	for k, v in pairs(data) do
		localData[k] = v
	end
	-- Update UI (fired via BindableEvent to HUD script)
	local ue = ReplicatedStorage:FindFirstChild("UIEvents")
	if ue and ue:FindFirstChild("UpdateHUD") then
		ue.UpdateHUD:Fire(localData)
	end
end)

remote("XPChanged").OnClientEvent:Connect(function(data)
	localData.xp         = data.xp
	localData.xpRequired = data.xpRequired
	local ue = ReplicatedStorage:FindFirstChild("UIEvents")
	if ue and ue:FindFirstChild("UpdateHUD") then
		ue.UpdateHUD:Fire(localData)
	end
end)

remote("EvolutionUnlocked").OnClientEvent:Connect(function(data)
	localData.stageIndex = data.stageIndex
	localData.stageName  = data.stageName
	localData.abilities  = data.abilities
	local ue = ReplicatedStorage:FindFirstChild("UIEvents")
	if ue and ue:FindFirstChild("ShowEvolution") then
		ue.ShowEvolution:Fire(data)
	end
end)

remote("DamageDealt").OnClientEvent:Connect(function(data)
	local ue = ReplicatedStorage:FindFirstChild("UIEvents")
	if ue and ue:FindFirstChild("ShowDamage") then
		ue.ShowDamage:Fire(data)
	end
end)

remote("AbilityCooldown").OnClientEvent:Connect(function(data)
	abilityCooldowns[data.ability] = tick() + data.remaining
end)

remote("PlayerDied").OnClientEvent:Connect(function()
	local ue = ReplicatedStorage:FindFirstChild("UIEvents")
	if ue and ue:FindFirstChild("ShowDeath") then
		ue.ShowDeath:Fire()
	end
	-- Auto-respawn after 3 seconds
	task.wait(3)
	remote("Respawn"):FireServer()
end)

remote("GameStarted").OnClientEvent:Connect(function()
	-- Request initial data
	local data = remote("GetPlayerData"):InvokeServer()
	if data then
		for k, v in pairs(data) do
			localData[k] = v
		end
		local ue = ReplicatedStorage:FindFirstChild("UIEvents")
		if ue and ue:FindFirstChild("UpdateHUD") then
			ue.UpdateHUD:Fire(localData)
		end
	end
end)

-- ─────────────────────────────────────────
-- Camera: follow character in third-person
-- ─────────────────────────────────────────
camera.CameraType = Enum.CameraType.Custom

-- ─────────────────────────────────────────
-- Highlight nearby food/enemies on hover
-- ─────────────────────────────────────────
local highlight = Instance.new("SelectionBox")
highlight.Color3         = Color3.fromRGB(255, 220, 0)
highlight.LineThickness  = 0.08
highlight.SurfaceColor3  = Color3.fromRGB(255, 220, 0)
highlight.SurfaceTransparency = 0.8
highlight.Parent         = workspace

RunService.RenderStepped:Connect(function()
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay  = camera:ScreenPointToRay(mousePos.X, mousePos.Y)

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { character }
	rp.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 80, rp)
	if result and result.Instance then
		local hit = result.Instance
		if (hit.Parent and hit.Parent.Name:sub(1, 6) == "Enemy_") or hit.Name:sub(1, 5) == "Food_" then
			highlight.Adornee = hit
			return
		end
	end
	highlight.Adornee = nil
end)

print("[InsectEvo] GameClient initialized.")
