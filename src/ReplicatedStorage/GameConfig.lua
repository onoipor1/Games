-- GameConfig.lua
-- Global game configuration constants

local GameConfig = {}

-- Data store key prefix
GameConfig.DataStoreKey = "InsectEvoV1_"

-- Map settings
GameConfig.MapSize         = 300  -- studs, half-width of the square map
GameConfig.FoodSpawnCount  = 60   -- max food items on map at once
GameConfig.FoodRespawnRate = 5    -- seconds between food spawns
GameConfig.EnemySpawnCount = 15   -- max enemies on map at once
GameConfig.EnemyRespawnRate = 12  -- seconds between enemy spawns

-- Combat settings
GameConfig.AttackCooldown  = 0.8  -- seconds between player attacks
GameConfig.AttackRange     = 8    -- studs reach for melee attack
GameConfig.KnockbackForce  = 30   -- velocity applied on hit
GameConfig.InvincibleTime  = 0.5  -- brief invincibility after taking damage

-- Ability cooldowns (seconds)
GameConfig.AbilityCooldowns = {
	["Carry"]           = 0,
	["Bite"]            = 2,
	["Acid Spray"]      = 8,
	["Summon Workers"]  = 20,
	["Roll"]            = 5,
	["Horn Charge"]     = 6,
	["Iron Shell"]      = 15,
	["Silk Shot"]       = 4,
	["Harden"]          = 12,
	["Fly"]             = 0,   -- passive
	["Scale Dust"]      = 10,
	["Moonbeam"]        = 18,
	["Sting"]           = 3,
	["Venom Cloud"]     = 10,
	["Royal Decree"]    = 25,
	["Web Trap"]        = 6,
	["Pounce"]          = 5,
	["Urticating Hairs"]= 9,
	["Mega Web"]        = 22,
}

-- XP multiplier per path (balance tuning)
GameConfig.PathXPMultiplier = {
	Ant       = 1.0,
	Beetle    = 0.95,
	Butterfly = 1.1,  -- slightly easier to evolve
	Bee       = 1.0,
	Spider    = 0.9,  -- slightly harder (spider is powerful)
}

-- UI colors
GameConfig.UIColors = {
	Background    = Color3.fromRGB(20, 20, 30),
	Panel         = Color3.fromRGB(35, 35, 50),
	Accent        = Color3.fromRGB(80, 200, 120),
	XPBar         = Color3.fromRGB(60, 180, 255),
	HPBar         = Color3.fromRGB(220, 60, 60),
	TextPrimary   = Color3.fromRGB(240, 240, 240),
	TextSecondary = Color3.fromRGB(160, 160, 180),
}

return GameConfig
