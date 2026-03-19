-- RemoteEvents.lua
-- Lists all RemoteEvents and RemoteFunctions used in the game.
-- Run this on the server at startup to create them under ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local EVENT_NAMES = {
	"EvolutionUnlocked",   -- Server → Client: player evolved to new form
	"XPChanged",           -- Server → Client: XP value updated
	"StatsChanged",        -- Server → Client: stats updated (health, speed, etc.)
	"UseAbility",          -- Client → Server: player activates an ability
	"AbilityCooldown",     -- Server → Client: ability is on cooldown
	"PlayerDied",          -- Server → Client: player was defeated
	"Respawn",             -- Client → Server: request respawn
	"EnemySpawned",        -- Server → Client: new enemy appeared
	"FoodSpawned",         -- Server → Client: new food appeared
	"CollectFood",         -- Client → Server: player tries to collect food
	"AttackEnemy",         -- Client → Server: player attacks enemy
	"DamageDealt",         -- Server → Client: show damage number
	"ChooseInsect",        -- Client → Server: select starting insect type
	"GameStarted",         -- Server → Client: game is ready
}

local FUNCTION_NAMES = {
	"GetPlayerData",       -- Client → Server: fetch own player data
}

-- Create a folder to hold remotes
local function getOrCreate(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

function RemoteEvents.Init()
	local folder = getOrCreate(ReplicatedStorage, "Folder", "Remotes")

	for _, name in ipairs(EVENT_NAMES) do
		getOrCreate(folder, "RemoteEvent", name)
	end

	for _, name in ipairs(FUNCTION_NAMES) do
		getOrCreate(folder, "RemoteFunction", name)
	end

	return folder
end

-- Convenience accessor
function RemoteEvents.Get(name)
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

return RemoteEvents
