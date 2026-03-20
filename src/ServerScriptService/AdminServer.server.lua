-- AdminServer.server.lua
-- Admin tools: server events (weather, XP bonus, crystal bonus),
-- lightning strikes during storms, and admin utility commands.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- Admin whitelist  ← Add your Roblox UserId(s) here
-- ─────────────────────────────────────────
local ADMIN_IDS = {
	-- 123456789,   -- example: replace with real UserId
}
-- Also grant admin to the game creator automatically (Studio testing)
local function isAdmin(player)
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	for _, id in ipairs(ADMIN_IDS) do
		if player.UserId == id then return true end
	end
	return false
end

-- ─────────────────────────────────────────
-- Active server event state
-- Shared globally so MonetizationServer.GetMultipliers() reads it
-- ─────────────────────────────────────────
_G.ActiveEvent = GameConfig.ServerEvents.None

local activeEventTimer    = 0   -- seconds remaining (0 = indefinite while event is set)
local lightningTimer      = 0

local function broadcastEvent()
	for _, p in ipairs(Players:GetPlayers()) do
		Remotes:FindFirstChild("EventChanged"):FireClient(p, {
			name        = _G.ActiveEvent.displayName,
			description = _G.ActiveEvent.description,
			crystalMult = _G.ActiveEvent.crystalMult,
			xpMult      = _G.ActiveEvent.xpMult,
			weatherType = _G.ActiveEvent.weatherType,
		})
		Remotes:FindFirstChild("WeatherChanged"):FireClient(p, _G.ActiveEvent.weatherType)
	end
end

local function setEvent(eventKey, durationSeconds)
	local def = GameConfig.ServerEvents[eventKey]
	if not def then return false end
	_G.ActiveEvent     = def
	activeEventTimer   = durationSeconds or 0  -- 0 = indefinite
	lightningTimer     = 0
	broadcastEvent()
	print(string.format("[AdminServer] Event set: %s  (duration: %s)",
		def.displayName,
		durationSeconds and (durationSeconds .. "s") or "indefinite"))
	return true
end

local function clearEvent()
	_G.ActiveEvent   = GameConfig.ServerEvents.None
	activeEventTimer = 0
	lightningTimer   = 0
	broadcastEvent()
	print("[AdminServer] Event cleared.")
end

-- ─────────────────────────────────────────
-- Storm lightning loop
-- ─────────────────────────────────────────
local function triggerLightning()
	local allPlayers = Players:GetPlayers()
	if #allPlayers == 0 then return end

	local target = allPlayers[math.random(1, #allPlayers)]
	local char   = target.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Visual: bright neon bolt part
	local bolt           = Instance.new("Part")
	bolt.Name            = "LightningBolt"
	bolt.Size            = Vector3.new(1, 60, 1)
	bolt.BrickColor      = BrickColor.new("Cyan")
	bolt.Material        = Enum.Material.Neon
	bolt.Transparency    = 0.2
	bolt.Anchored        = true
	bolt.CanCollide      = false
	bolt.CFrame          = CFrame.new(hrp.Position + Vector3.new(
		math.random(-10, 10), 30, math.random(-10, 10)
	))
	bolt.Parent          = workspace
	game:GetService("Debris"):AddItem(bolt, 0.3)

	-- Apply damage
	local dmg    = _G.ActiveEvent.lightningDamage or 20
	local pData  = _G.PlayerData and _G.PlayerData[target]
	if pData then
		pData.currentHealth = math.max(1, pData.currentHealth - dmg)
		if _G.ApplyPlayerStats then _G.ApplyPlayerStats(target) end
	end

	-- Notify
	Remotes:FindFirstChild("DamageDealt"):FireClient(target, {
		amount   = dmg,
		position = hrp.Position + Vector3.new(0, 4, 0),
	})
end

-- ─────────────────────────────────────────
-- Heartbeat: timed events + lightning
-- ─────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
	-- Count down active event duration
	if activeEventTimer > 0 then
		activeEventTimer = activeEventTimer - dt
		if activeEventTimer <= 0 then
			clearEvent()
		end
	end

	-- Storm lightning
	if _G.ActiveEvent.weatherType == "Storm" then
		lightningTimer = lightningTimer + dt
		local interval = _G.ActiveEvent.lightningInterval or 12
		if lightningTimer >= interval then
			lightningTimer = 0
			triggerLightning()
		end
	end
end)

-- ─────────────────────────────────────────
-- Remote: AdminCommand
-- payload.action = "setEvent" | "clearEvent" | "setWeather" |
--                  "giveCrystals" | "giveXP" | "kickPlayer"
-- ─────────────────────────────────────────
Remotes:FindFirstChild("AdminCommand").OnServerEvent:Connect(function(sender, payload)
	if not isAdmin(sender) then return end
	if type(payload) ~= "table" then return end

	local action = payload.action

	if action == "setEvent" then
		setEvent(payload.eventKey, payload.duration)

	elseif action == "clearEvent" then
		clearEvent()

	elseif action == "setWeather" then
		-- Just changes weather visual without a full event
		local weatherType = payload.weatherType or "Clear"
		for _, p in ipairs(Players:GetPlayers()) do
			Remotes:FindFirstChild("WeatherChanged"):FireClient(p, weatherType)
		end

	elseif action == "giveCrystals" then
		local target = payload.targetName
		       and Players:FindFirstChild(payload.targetName)
		       or sender
		local amount = tonumber(payload.amount) or 0
		if _G.AddCrystals and amount > 0 then
			_G.AddCrystals(target, amount)
			print(string.format("[Admin] %s → gave %d crystals to %s",
				sender.Name, amount, target.Name))
		end

	elseif action == "giveXP" then
		local target = payload.targetName
		       and Players:FindFirstChild(payload.targetName)
		       or sender
		local amount = tonumber(payload.amount) or 0
		if _G.AddXP and amount > 0 then
			_G.AddXP(target, amount)
			print(string.format("[Admin] %s → gave %d XP to %s",
				sender.Name, amount, target.Name))
		end

	elseif action == "kickPlayer" then
		local target = payload.targetName
		       and Players:FindFirstChild(payload.targetName)
		if target then
			target:Kick("[Admin] You have been removed by an admin.")
		end
	end
end)

-- ─────────────────────────────────────────
-- Send current event to a player when they join
-- ─────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	task.wait(2)  -- wait for character + HUD
	Remotes:FindFirstChild("EventChanged"):FireClient(player, {
		name        = _G.ActiveEvent.displayName,
		description = _G.ActiveEvent.description,
		crystalMult = _G.ActiveEvent.crystalMult,
		xpMult      = _G.ActiveEvent.xpMult,
		weatherType = _G.ActiveEvent.weatherType,
	})
	Remotes:FindFirstChild("WeatherChanged"):FireClient(player, _G.ActiveEvent.weatherType)
end)

print("[InsectEvo] AdminServer initialized.")
