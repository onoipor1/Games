-- PetData.lua
-- Defines all egg types, pet rarities, individual pets, and their buff values.

local PetData = {}

-- ─────────────────────────────────────────
-- Rarity definitions
-- buff:  what stat(s) the pet boosts
-- color: BrickColor for pet model
-- ─────────────────────────────────────────
PetData.Rarities = {
	Common = {
		displayName  = "Common",
		color        = Color3.fromRGB(180, 220, 180),
		glowColor    = Color3.fromRGB(120, 200, 120),
		buff         = { speed = 2 },               -- +2 WalkSpeed
		buffDesc     = "+2 Speed",
		weight       = 65,   -- relative roll weight
	},
	Uncommon = {
		displayName  = "Uncommon",
		color        = Color3.fromRGB(100, 180, 255),
		glowColor    = Color3.fromRGB(60, 140, 255),
		buff         = { health = 50 },             -- +50 MaxHealth
		buffDesc     = "+50 HP",
		weight       = 25,
	},
	Rare = {
		displayName  = "Rare",
		color        = Color3.fromRGB(200, 100, 255),
		glowColor    = Color3.fromRGB(160, 60, 220),
		buff         = { damagePercent = 0.20 },    -- +20 % damage multiplier
		buffDesc     = "+20% Damage",
		weight       = 8,
	},
	Legendary = {
		displayName  = "Legendary",
		color        = Color3.fromRGB(255, 200, 50),
		glowColor    = Color3.fromRGB(255, 165, 0),
		buff         = { speed = 2, health = 30, damagePercent = 0.10 },
		buffDesc     = "+2 Spd / +30 HP / +10% Dmg",
		weight       = 2,
	},
}

-- Ordered for display
PetData.RarityOrder = { "Common", "Uncommon", "Rare", "Legendary" }

-- ─────────────────────────────────────────
-- Individual pets per rarity
-- Each pet: name, emoji, flavourText
-- ─────────────────────────────────────────
PetData.Pets = {
	Common = {
		{ name = "Firefly",   emoji = "🪲", flavour = "Glows softly in the dark." },
		{ name = "Ladybug",   emoji = "🐞", flavour = "Lucky little bug." },
		{ name = "Cricket",   emoji = "🦗", flavour = "Always chirping away." },
		{ name = "Grub",      emoji = "🐛", flavour = "Small but scrappy." },
		{ name = "Pillbug",   emoji = "🪳", flavour = "Rolls into a perfect ball." },
	},
	Uncommon = {
		{ name = "Dragonfly", emoji = "🦟", flavour = "Dashes through the air." },
		{ name = "Mantis",    emoji = "🦗", flavour = "Strikes with precision." },
		{ name = "Cicada",    emoji = "🎶", flavour = "Its song shakes the earth." },
		{ name = "Horsefly",  emoji = "🪰", flavour = "Unnervingly fast." },
	},
	Rare = {
		{ name = "Scorpion",       emoji = "🦂", flavour = "Venomous tail, loyal heart." },
		{ name = "Centipede",      emoji = "🪱", flavour = "A hundred legs of fury." },
		{ name = "Hercules Beetle",emoji = "🪲", flavour = "Lifts 850× its own weight." },
		{ name = "Tarantula Hawk", emoji = "🕷",  flavour = "The deadliest wasp alive." },
	},
	Legendary = {
		{ name = "Titan Moth",    emoji = "🦋", flavour = "Wings blot out the moon." },
		{ name = "Golden Ant",    emoji = "🐜", flavour = "Ancient. Immortal. Golden." },
		{ name = "Crystal Spider",emoji = "🕸",  flavour = "Spins webs of pure light." },
		{ name = "Diamond Bee",   emoji = "🐝", flavour = "Its honey grants eternal power." },
	},
}

-- ─────────────────────────────────────────
-- Egg types
-- chances: rarity → weight override (nil = use rarity default weight)
-- ─────────────────────────────────────────
PetData.Eggs = {
	BasicEgg = {
		displayName  = "Basic Egg",
		description  = "A humble egg. Contains a Common–Uncommon pet.",
		crystalCost  = 100,
		emoji        = "🥚",
		color        = Color3.fromRGB(240, 230, 200),
		glowColor    = Color3.fromRGB(200, 190, 160),
		chances      = { Common = 70, Uncommon = 25, Rare = 4, Legendary = 1 },
	},
	RareEgg = {
		displayName  = "Rare Egg",
		description  = "A shimmering egg. Higher chance of Rare pets.",
		crystalCost  = 350,
		emoji        = "🔮",
		color        = Color3.fromRGB(160, 100, 255),
		glowColor    = Color3.fromRGB(120, 60, 220),
		chances      = { Common = 40, Uncommon = 35, Rare = 20, Legendary = 5 },
	},
	LegendaryEgg = {
		displayName  = "Legendary Egg",
		description  = "Forged from pure crystal. Best chance for Legendary!",
		crystalCost  = 1200,
		emoji        = "💎",
		color        = Color3.fromRGB(255, 215, 50),
		glowColor    = Color3.fromRGB(255, 180, 0),
		chances      = { Common = 20, Uncommon = 25, Rare = 35, Legendary = 20 },
	},
}

PetData.EggOrder = { "BasicEgg", "RareEgg", "LegendaryEgg" }

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────

-- Roll a rarity from an egg's chance table
function PetData.RollRarity(eggKey)
	local egg = PetData.Eggs[eggKey]
	if not egg then return "Common" end

	local pool = {}
	for rarity, weight in pairs(egg.chances) do
		for _ = 1, weight do
			table.insert(pool, rarity)
		end
	end

	return pool[math.random(1, #pool)]
end

-- Pick a random pet of the given rarity
function PetData.RollPet(rarity)
	local list = PetData.Pets[rarity]
	if not list or #list == 0 then return { name = "Unknown", emoji = "❓", flavour = "" } end
	return list[math.random(1, #list)]
end

-- Get total buff table for a list of equipped pet records
-- petRecord = { rarity = "Rare", name = "Scorpion", ... }
function PetData.CalcBuffs(equippedPet)
	if not equippedPet then
		return { speed = 0, health = 0, damagePercent = 0 }
	end
	local rarityData = PetData.Rarities[equippedPet.rarity]
	if not rarityData then
		return { speed = 0, health = 0, damagePercent = 0 }
	end
	local b = rarityData.buff
	return {
		speed         = b.speed         or 0,
		health        = b.health        or 0,
		damagePercent = b.damagePercent or 0,
	}
end

return PetData
