-- GamePasses.lua
-- All game pass / developer product IDs and their benefit definitions.
-- IMPORTANT: Replace the placeholder IDs (000000001 etc.) with your real IDs
-- from the Roblox Creator Hub after publishing.

local GamePasses = {}

-- ─────────────────────────────────────────
-- Game Pass IDs  (create in Creator Hub → Monetization → Passes)
-- ─────────────────────────────────────────
GamePasses.IDs = {
	VIP        = 000000001,   -- "VIP" pass
	DoubleXP   = 000000002,   -- "Double XP" pass
	DoubleDmg  = 000000003,   -- "Double Damage" pass
}

-- ─────────────────────────────────────────
-- Game Pass benefits applied on top of base stats
-- ─────────────────────────────────────────
GamePasses.Benefits = {
	VIP = {
		crystalMultiplier = 1.5,   -- earn 50 % more crystals
		xpMultiplier      = 1.2,   -- earn 20 % more XP
		speedBonus        = 3,     -- flat +3 WalkSpeed
		badgeColor        = Color3.fromRGB(255, 215, 0),  -- gold tint on name tag
	},
	DoubleXP = {
		xpMultiplier = 2.0,
	},
	DoubleDmg = {
		damageMultiplier = 2.0,
	},
}

-- ─────────────────────────────────────────
-- Developer Product IDs  (create in Creator Hub → Monetization → Developer Products)
-- Each product grants the listed crystalAmount when purchased.
-- ─────────────────────────────────────────
GamePasses.CrystalProducts = {
	{ productId = 100000001, crystalAmount = 100,  label = "100 Crystals",   robux = 25  },
	{ productId = 100000002, crystalAmount = 500,  label = "500 Crystals",   robux = 99  },
	{ productId = 100000003, crystalAmount = 1200, label = "1,200 Crystals", robux = 199 },
	{ productId = 100000004, crystalAmount = 2500, label = "2,500 Crystals", robux = 399 },
	{ productId = 100000005, crystalAmount = 6000, label = "6,000 Crystals", robux = 799 },
}

-- Reverse lookup: productId → crystalAmount
GamePasses.ProductIdToCrystals = {}
for _, p in ipairs(GamePasses.CrystalProducts) do
	GamePasses.ProductIdToCrystals[p.productId] = p.crystalAmount
end

-- Reverse lookup: passId → pass name key
GamePasses.IdToKey = {}
for key, id in pairs(GamePasses.IDs) do
	GamePasses.IdToKey[id] = key
end

return GamePasses
