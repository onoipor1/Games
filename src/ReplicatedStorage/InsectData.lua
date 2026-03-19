-- InsectData.lua
-- Module containing all insect evolution data, stats, and progression

local InsectData = {}

--[[
	Evolution Paths:
	Each insect has multiple stages. Players earn XP by collecting food/killing enemies.
	At each stage threshold, they evolve to the next form.

	Stats:
	  walkSpeed    - movement speed
	  jumpPower    - jump height
	  maxHealth    - max HP
	  damage       - attack damage
	  size         - body scale multiplier
	  xpRequired   - XP needed to evolve to NEXT stage
	  color        - BrickColor name for the body
	  abilities    - special abilities unlocked at this stage
]]

InsectData.Evolutions = {

	-- ===================== ANT PATH =====================
	Ant = {
		{
			name        = "Ant Larva",
			walkSpeed   = 10,
			jumpPower   = 30,
			maxHealth   = 30,
			damage      = 5,
			size        = 0.4,
			xpRequired  = 50,
			color       = "Pastel yellow",
			abilities   = {},
			description = "A tiny wriggling larva. Weak but fast.",
		},
		{
			name        = "Worker Ant",
			walkSpeed   = 18,
			jumpPower   = 40,
			maxHealth   = 80,
			damage      = 12,
			size        = 0.7,
			xpRequired  = 200,
			color       = "Black",
			abilities   = { "Carry" },
			description = "A fully grown worker ant. Can carry items.",
		},
		{
			name        = "Soldier Ant",
			walkSpeed   = 20,
			jumpPower   = 45,
			maxHealth   = 160,
			damage      = 28,
			size        = 1.0,
			xpRequired  = 600,
			color       = "Really black",
			abilities   = { "Carry", "Bite" },
			description = "A powerful soldier ant with crushing mandibles.",
		},
		{
			name        = "Fire Ant",
			walkSpeed   = 22,
			jumpPower   = 50,
			maxHealth   = 280,
			damage      = 50,
			size        = 1.3,
			xpRequired  = 1500,
			color       = "Bright red",
			abilities   = { "Carry", "Bite", "Acid Spray" },
			description = "A fire ant capable of spraying painful acid.",
		},
		{
			name        = "Queen Ant",
			walkSpeed   = 16,
			jumpPower   = 35,
			maxHealth   = 700,
			damage      = 80,
			size        = 2.0,
			xpRequired  = nil, -- Final form
			color       = "Dark orange",
			abilities   = { "Carry", "Bite", "Acid Spray", "Summon Workers" },
			description = "The mighty Queen Ant. Summons worker allies in battle!",
		},
	},

	-- ===================== BEETLE PATH =====================
	Beetle = {
		{
			name        = "Beetle Egg",
			walkSpeed   = 8,
			jumpPower   = 25,
			maxHealth   = 50,
			damage      = 3,
			size        = 0.3,
			xpRequired  = 60,
			color       = "White",
			abilities   = {},
			description = "A fragile beetle egg. Barely mobile.",
		},
		{
			name        = "Grub",
			walkSpeed   = 10,
			jumpPower   = 28,
			maxHealth   = 100,
			damage      = 8,
			size        = 0.6,
			xpRequired  = 250,
			color       = "Pastel yellow",
			abilities   = {},
			description = "A soft grub. Still developing its exoskeleton.",
		},
		{
			name        = "Dung Beetle",
			walkSpeed   = 14,
			jumpPower   = 35,
			maxHealth   = 200,
			damage      = 20,
			size        = 0.9,
			xpRequired  = 700,
			color       = "Dark orange",
			abilities   = { "Roll" },
			description = "A dung beetle. Uses its roll to bowl over enemies.",
		},
		{
			name        = "Stag Beetle",
			walkSpeed   = 16,
			jumpPower   = 40,
			maxHealth   = 400,
			damage      = 45,
			size        = 1.4,
			xpRequired  = 1800,
			color       = "Reddish brown",
			abilities   = { "Roll", "Horn Charge" },
			description = "A stag beetle with massive horns for charging.",
		},
		{
			name        = "Titan Beetle",
			walkSpeed   = 14,
			jumpPower   = 38,
			maxHealth   = 1000,
			damage      = 100,
			size        = 2.5,
			xpRequired  = nil, -- Final form
			color       = "Really black",
			abilities   = { "Roll", "Horn Charge", "Iron Shell" },
			description = "The Titan Beetle — the largest insect alive. Near-invincible shell.",
		},
	},

	-- ===================== BUTTERFLY PATH =====================
	Butterfly = {
		{
			name        = "Caterpillar",
			walkSpeed   = 8,
			jumpPower   = 20,
			maxHealth   = 25,
			damage      = 2,
			size        = 0.4,
			xpRequired  = 40,
			color       = "Bright green",
			abilities   = {},
			description = "A tiny caterpillar. Very fragile but quick to grow.",
		},
		{
			name        = "Fat Caterpillar",
			walkSpeed   = 7,
			jumpPower   = 22,
			maxHealth   = 60,
			damage      = 6,
			size        = 0.6,
			xpRequired  = 150,
			color       = "Lime green",
			abilities   = { "Silk Shot" },
			description = "A plump caterpillar. Shoots silk to slow enemies.",
		},
		{
			name        = "Chrysalis",
			walkSpeed   = 5,
			jumpPower   = 18,
			maxHealth   = 120,
			damage      = 0,
			size        = 0.5,
			xpRequired  = 300,
			color       = "Gold",
			abilities   = { "Harden" },
			description = "Encased in a chrysalis. Invulnerable for a short time.",
		},
		{
			name        = "Butterfly",
			walkSpeed   = 24,
			jumpPower   = 80,
			maxHealth   = 180,
			damage      = 22,
			size        = 1.0,
			xpRequired  = 900,
			color       = "Bright yellow",
			abilities   = { "Silk Shot", "Fly", "Scale Dust" },
			description = "A beautiful butterfly. Flies high and blinds foes with scale dust.",
		},
		{
			name        = "Moth Emperor",
			walkSpeed   = 26,
			jumpPower   = 90,
			maxHealth   = 500,
			damage      = 65,
			size        = 2.0,
			xpRequired  = nil, -- Final form
			color       = "Medium stone grey",
			abilities   = { "Silk Shot", "Fly", "Scale Dust", "Moonbeam" },
			description = "The Moth Emperor. Commands moonlight energy to smite enemies.",
		},
	},

	-- ===================== BEE PATH =====================
	Bee = {
		{
			name        = "Bee Larva",
			walkSpeed   = 10,
			jumpPower   = 30,
			maxHealth   = 35,
			damage      = 4,
			size        = 0.35,
			xpRequired  = 55,
			color       = "Pastel yellow",
			abilities   = {},
			description = "A tiny bee larva cradled in honeycomb.",
		},
		{
			name        = "Drone Bee",
			walkSpeed   = 20,
			jumpPower   = 55,
			maxHealth   = 90,
			damage      = 15,
			size        = 0.75,
			xpRequired  = 220,
			color       = "Bright yellow",
			abilities   = { "Fly" },
			description = "A drone bee. Flies at decent speed.",
		},
		{
			name        = "Worker Bee",
			walkSpeed   = 24,
			jumpPower   = 60,
			maxHealth   = 150,
			damage      = 25,
			size        = 0.9,
			xpRequired  = 650,
			color       = "Dark orange",
			abilities   = { "Fly", "Sting" },
			description = "A worker bee armed with a venomous stinger.",
		},
		{
			name        = "Hornet",
			walkSpeed   = 28,
			jumpPower   = 70,
			maxHealth   = 300,
			damage      = 55,
			size        = 1.3,
			xpRequired  = 1600,
			color       = "Bright orange",
			abilities   = { "Fly", "Sting", "Venom Cloud" },
			description = "A giant hornet. Releases toxic venom clouds.",
		},
		{
			name        = "Queen Hornet",
			walkSpeed   = 26,
			jumpPower   = 75,
			maxHealth   = 800,
			damage      = 90,
			size        = 2.2,
			xpRequired  = nil, -- Final form
			color       = "Bright red",
			abilities   = { "Fly", "Sting", "Venom Cloud", "Royal Decree" },
			description = "The Queen Hornet. Her Royal Decree summons a swarm of hornets!",
		},
	},

	-- ===================== SPIDER PATH =====================
	Spider = {
		{
			name        = "Spider Spiderling",
			walkSpeed   = 14,
			jumpPower   = 45,
			maxHealth   = 30,
			damage      = 6,
			size        = 0.3,
			xpRequired  = 45,
			color       = "Bright red",
			abilities   = {},
			description = "A newborn spiderling. Tiny but surprisingly quick.",
		},
		{
			name        = "House Spider",
			walkSpeed   = 18,
			jumpPower   = 50,
			maxHealth   = 80,
			damage      = 15,
			size        = 0.65,
			xpRequired  = 200,
			color       = "Reddish brown",
			abilities   = { "Web Trap" },
			description = "A common house spider. Lays web traps for enemies.",
		},
		{
			name        = "Wolf Spider",
			walkSpeed   = 26,
			jumpPower   = 65,
			maxHealth   = 180,
			damage      = 35,
			size        = 1.0,
			xpRequired  = 700,
			color       = "Dark orange",
			abilities   = { "Web Trap", "Pounce" },
			description = "A wolf spider. Pounces at prey from a distance.",
		},
		{
			name        = "Tarantula",
			walkSpeed   = 22,
			jumpPower   = 55,
			maxHealth   = 400,
			damage      = 65,
			size        = 1.6,
			xpRequired  = 1800,
			color       = "Really black",
			abilities   = { "Web Trap", "Pounce", "Urticating Hairs" },
			description = "A tarantula. Launches irritating hairs that blind and slow.",
		},
		{
			name        = "Goliath Spider",
			walkSpeed   = 20,
			jumpPower   = 50,
			maxHealth   = 1200,
			damage      = 120,
			size        = 3.0,
			xpRequired  = nil, -- Final form
			color       = "Dark brown",
			abilities   = { "Web Trap", "Pounce", "Urticating Hairs", "Mega Web" },
			description = "The Goliath Spider — the largest spider on Earth. Covers entire arenas in webs!",
		},
	},
}

-- ===================== FOOD ITEMS (XP Sources) =====================
InsectData.FoodItems = {
	{ name = "Leaf",      xp = 5,   color = "Bright green",  size = 0.8 },
	{ name = "Berry",     xp = 10,  color = "Bright red",    size = 0.5 },
	{ name = "Mushroom",  xp = 20,  color = "Bright orange", size = 0.7 },
	{ name = "Dead Bug",  xp = 35,  color = "Dark orange",   size = 0.6 },
	{ name = "Honeydew",  xp = 50,  color = "Gold",          size = 0.4 },
	{ name = "Carcass",   xp = 100, color = "Reddish brown", size = 1.2 },
}

-- ===================== ENEMY NPCS =====================
InsectData.Enemies = {
	{
		name      = "Small Bug",
		health    = 30,
		damage    = 8,
		speed     = 12,
		xpReward  = 15,
		size      = 0.5,
		color     = "Bright green",
	},
	{
		name      = "Beetle Grunt",
		health    = 80,
		damage    = 18,
		speed     = 10,
		xpReward  = 40,
		size      = 0.9,
		color     = "Dark orange",
	},
	{
		name      = "Wasp Scout",
		health    = 60,
		damage    = 25,
		speed     = 18,
		xpReward  = 55,
		size      = 0.8,
		color     = "Bright yellow",
	},
	{
		name      = "Spider Raider",
		health    = 150,
		damage    = 35,
		speed     = 14,
		xpReward  = 80,
		size      = 1.2,
		color     = "Really black",
	},
	{
		name      = "Mantis Hunter",
		health    = 300,
		damage    = 60,
		speed     = 16,
		xpReward  = 150,
		size      = 1.8,
		color     = "Bright green",
	},
}

-- Helper: get stage data for an insect path at a given stage index (1-based)
function InsectData.GetStage(insectType, stageIndex)
	local path = InsectData.Evolutions[insectType]
	if not path then return nil end
	return path[stageIndex]
end

-- Helper: get total number of stages for an insect type
function InsectData.GetMaxStages(insectType)
	local path = InsectData.Evolutions[insectType]
	if not path then return 0 end
	return #path
end

-- Helper: get list of all insect type names
function InsectData.GetInsectTypes()
	local types = {}
	for k, _ in pairs(InsectData.Evolutions) do
		table.insert(types, k)
	end
	table.sort(types)
	return types
end

return InsectData
