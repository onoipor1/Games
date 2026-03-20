-- GameConfig.lua
-- Global game configuration constants.

local GameConfig = {}

-- ─────────────────────────────────────────
-- Data store
-- ─────────────────────────────────────────
GameConfig.DataStoreKey = "InsectEvoV1_"

-- ─────────────────────────────────────────
-- Map settings
-- ─────────────────────────────────────────
GameConfig.MapSize          = 300
GameConfig.FoodSpawnCount   = 60
GameConfig.FoodRespawnRate  = 5
GameConfig.EnemySpawnCount  = 15
GameConfig.EnemyRespawnRate = 12

-- ─────────────────────────────────────────
-- Combat
-- ─────────────────────────────────────────
GameConfig.AttackCooldown  = 0.8
GameConfig.AttackRange     = 8
GameConfig.KnockbackForce  = 30
GameConfig.InvincibleTime  = 0.5

-- ─────────────────────────────────────────
-- Crystal earning rates  (before any multipliers)
-- ─────────────────────────────────────────
GameConfig.CrystalsPerFoodXP   = 0.15   -- crystals = floor(foodXP  × rate)
GameConfig.CrystalsPerEnemyXP  = 0.20   -- crystals = floor(enemyXP × rate)

-- ─────────────────────────────────────────
-- Ability cooldowns (seconds)
-- ─────────────────────────────────────────
GameConfig.AbilityCooldowns = {
	["Carry"]            = 0,
	["Bite"]             = 2,
	["Acid Spray"]       = 8,
	["Summon Workers"]   = 20,
	["Roll"]             = 5,
	["Horn Charge"]      = 6,
	["Iron Shell"]       = 15,
	["Silk Shot"]        = 4,
	["Harden"]           = 12,
	["Fly"]              = 0,
	["Scale Dust"]       = 10,
	["Moonbeam"]         = 18,
	["Sting"]            = 3,
	["Venom Cloud"]      = 10,
	["Royal Decree"]     = 25,
	["Web Trap"]         = 6,
	["Pounce"]           = 5,
	["Urticating Hairs"] = 9,
	["Mega Web"]         = 22,
}

-- ─────────────────────────────────────────
-- XP multiplier per path
-- ─────────────────────────────────────────
GameConfig.PathXPMultiplier = {
	Ant       = 1.0,
	Beetle    = 0.95,
	Butterfly = 1.1,
	Bee       = 1.0,
	Spider    = 0.9,
}

-- ─────────────────────────────────────────
-- Server events (managed by AdminServer)
-- Each entry: displayName, crystalMult, xpMult, description, weatherType
-- ─────────────────────────────────────────
GameConfig.ServerEvents = {
	None = {
		displayName  = "None",
		description  = "No active event.",
		crystalMult  = 1.0,
		xpMult       = 1.0,
		weatherType  = "Clear",
	},
	CrystalBonus = {
		displayName  = "Crystal Fever!",
		description  = "Earn 2× crystals from everything!",
		crystalMult  = 2.0,
		xpMult       = 1.0,
		weatherType  = "GoldenHour",
	},
	DoubleXP = {
		displayName  = "XP Surge!",
		description  = "All XP gains doubled for this event!",
		crystalMult  = 1.0,
		xpMult       = 2.0,
		weatherType  = "Clear",
	},
	BloodMoon = {
		displayName  = "Blood Moon!",
		description  = "Enemies are stronger but drop 2× crystals!",
		crystalMult  = 2.0,
		xpMult       = 1.0,
		weatherType  = "BloodMoon",
		enemyHealthMult = 2.0,
	},
	Storm = {
		displayName  = "Storm Warning!",
		description  = "Lightning strikes! 1.5× crystal bonus.",
		crystalMult  = 1.5,
		xpMult       = 1.0,
		weatherType  = "Storm",
		lightningDamage = 20,
		lightningInterval = 12,
	},
	GoldenHour = {
		displayName  = "Golden Hour!",
		description  = "Bask in the sun — 1.5× XP gain!",
		crystalMult  = 1.0,
		xpMult       = 1.5,
		weatherType  = "GoldenHour",
	},
}

-- ─────────────────────────────────────────
-- Weather visual settings (applied on client)
-- ─────────────────────────────────────────
GameConfig.WeatherSettings = {
	Clear = {
		ambient         = Color3.fromRGB(100, 120, 80),
		outdoorAmbient  = Color3.fromRGB(130, 150, 100),
		fogColor        = Color3.fromRGB(180, 210, 160),
		fogEnd          = 800,
		fogStart        = 400,
		brightness      = 2,
		timeOfDay       = "14:00:00",
	},
	Rainy = {
		ambient         = Color3.fromRGB(70, 80, 90),
		outdoorAmbient  = Color3.fromRGB(90, 100, 110),
		fogColor        = Color3.fromRGB(120, 130, 140),
		fogEnd          = 350,
		fogStart        = 100,
		brightness      = 1.2,
		timeOfDay       = "12:00:00",
	},
	Storm = {
		ambient         = Color3.fromRGB(40, 40, 55),
		outdoorAmbient  = Color3.fromRGB(50, 50, 70),
		fogColor        = Color3.fromRGB(60, 60, 80),
		fogEnd          = 250,
		fogStart        = 60,
		brightness      = 0.8,
		timeOfDay       = "06:00:00",
	},
	GoldenHour = {
		ambient         = Color3.fromRGB(160, 120, 60),
		outdoorAmbient  = Color3.fromRGB(200, 150, 80),
		fogColor        = Color3.fromRGB(240, 180, 100),
		fogEnd          = 700,
		fogStart        = 300,
		brightness      = 2.5,
		timeOfDay       = "17:00:00",
	},
	BloodMoon = {
		ambient         = Color3.fromRGB(80, 20, 20),
		outdoorAmbient  = Color3.fromRGB(100, 30, 30),
		fogColor        = Color3.fromRGB(120, 30, 30),
		fogEnd          = 400,
		fogStart        = 150,
		brightness      = 1.0,
		timeOfDay       = "22:00:00",
	},
}

-- ─────────────────────────────────────────
-- UI colours
-- ─────────────────────────────────────────
GameConfig.UIColors = {
	Background    = Color3.fromRGB(20, 20, 30),
	Panel         = Color3.fromRGB(35, 35, 50),
	Accent        = Color3.fromRGB(80, 200, 120),
	XPBar         = Color3.fromRGB(60, 180, 255),
	HPBar         = Color3.fromRGB(220, 60, 60),
	CrystalColor  = Color3.fromRGB(100, 210, 255),
	TextPrimary   = Color3.fromRGB(240, 240, 240),
	TextSecondary = Color3.fromRGB(160, 160, 180),
	Gold          = Color3.fromRGB(255, 210, 50),
	Legendary     = Color3.fromRGB(255, 200, 50),
	Rare          = Color3.fromRGB(180, 80, 255),
	Uncommon      = Color3.fromRGB(60, 150, 255),
	Common        = Color3.fromRGB(100, 200, 100),
}

return GameConfig
