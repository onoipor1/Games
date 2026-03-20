-- RemoteEvents.lua
-- Registry for all RemoteEvents and RemoteFunctions.
-- Run on the server at startup to create them under ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local EVENT_NAMES = {
	-- ── Core game ──────────────────────────────────────
	"EvolutionUnlocked",    -- Server → Client : player evolved  { stageName, stageIndex, ... }
	"XPChanged",            -- Server → Client : XP/level updated { xp, xpRequired, level, maxLevel }
	"LevelUp",              -- Server → Client : player levelled up { level, stageEvolved }
	"StatsChanged",         -- Server → Client : full stat snapshot
	"UseAbility",           -- Client → Server : activate ability
	"AbilityCooldown",      -- Server → Client : ability cooldown info
	"PlayerDied",           -- Server → Client : player defeated
	"Respawn",              -- Client → Server : request respawn
	"EnemySpawned",         -- Server → Client : enemy appeared
	"FoodSpawned",          -- Server → Client : food appeared
	"CollectFood",          -- Client → Server : collect food item
	"AttackEnemy",          -- Client → Server : attack enemy
	"DamageDealt",          -- Server → Client : show damage number
	"ChooseInsect",         -- Client → Server : pick starting insect
	"GameStarted",          -- Server → Client : game ready

	-- ── Crystals & monetization ────────────────────────
	"CrystalsChanged",      -- Server → Client : crystal balance updated
	"PassesChanged",        -- Server → Client : owned passes updated
	"PurchaseEgg",          -- Client → Server : buy egg with crystals
	"PromptGamePass",       -- Client → Server : open game-pass purchase prompt

	-- ── Pets ───────────────────────────────────────────
	"EggResult",            -- Server → Client : result of opening an egg
	"PetsChanged",          -- Server → Client : pet inventory updated
	"EquipPet",             -- Client → Server : equip / unequip pet (index or nil)

	-- ── Admin / Events ─────────────────────────────────
	"AdminCommand",         -- Client → Server : admin action payload
	"EventChanged",         -- Server → Client : active server event changed
	"WeatherChanged",       -- Server → Client : weather type changed

	-- ── Boss system ─────────────────────────────────────────
	"BossSpawned",          -- Server → All : boss appeared  { name, zone, maxHealth, themeColor }
	"BossHealthChanged",    -- Server → All : boss HP update  { zone, health, maxHealth, name }
	"BossDied",             -- Server → All : boss defeated   { name, zone, respawn }

	-- ── Zone / world system ────────────────────────────
	"ZoneTeleport",         -- Client → Server : request teleport to zone key
	"ZoneChanged",          -- Server → Client : player moved to new zone { zone, displayName }
	"VisitedZonesUpdate",   -- Server → Client : { ["Grassland"]=true, ... }

	-- ── Rebirth system ─────────────────────────────────
	"RebirthRequest",       -- Client → Server : player requests rebirth
	"RebirthComplete",      -- Server → Client : rebirth granted { rebirths, xpMult, dmgMult }

	-- ── Leaderboard ────────────────────────────────────
	"LeaderboardData",      -- Server → All   : top-10 list [{ name, level, rebirths, score }]
}

local FUNCTION_NAMES = {
	"GetPlayerData",        -- Client → Server : fetch own full data snapshot
}

local function getOrCreate(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj        = Instance.new(className)
		obj.Name   = name
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

function RemoteEvents.Get(name)
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

return RemoteEvents
