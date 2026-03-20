-- ZoneData.lua
-- Five progression zones spread across a large shared world.
-- Each zone is 600×600 studs (4× the original area).
--
-- World layout (top-down view):
--
--   [Grassland  1–10 ] .......800 gap....... [Wetland   10–20] .......800 gap....... [Mushroom 20–30]
--         |                                                                                  |
--      (portal)                                                                           (portal)
--         |                                                                                  |
--   [Volcanic  30–40] .......800 gap....... [Crystal  40–50 ]
--
-- Portals teleport players instantly; no physical corridors needed.
-- A portal only works if the player meets the minLevel requirement.

local ZoneData = {}

ZoneData.SafeZoneRadius = 60   -- default safe-spawn radius (studs) — scaled up for larger zones

-- ─────────────────────────────────────────
-- Zone definitions
-- ─────────────────────────────────────────
ZoneData.Zones = {

	-- ══════════════════════════════════════════════════
	-- ZONE 1: GRASSLAND  (Level 1–10)
	-- Center (0,0). 600×600 studs. Bounds ±300.
	-- ══════════════════════════════════════════════════
	Grassland = {
		key          = "Grassland",
		displayName  = "Grassland",
		description  = "Sun-dappled fields and towering grass blades. Perfect for new insects.",
		color        = Color3.fromRGB(80, 180, 60),
		emoji        = "🌿",
		minLevel     = 1,
		maxLevel     = 10,
		bossLevel    = 12,
		bounds       = { minX = -300, maxX = 300, minZ = -300, maxZ = 300 },
		spawn        = Vector3.new(0, 3, 0),
		safeZoneRadius = 60,
		portals = {
			{ destination = "Wetland",  minLevel = 10, position = Vector3.new(270, 3,   0) },
			{ destination = "Volcanic", minLevel = 30, position = Vector3.new(  0, 3, 270) },
		},
		enemyZone  = "Grassland",
		bossKey    = "MantisOverlord",
		maxNormals = 20,
		maxElites  = 5,
		food = {
			{
				key = "CloverLeaf", displayName = "Clover Leaf",
				xp = 8, size = 0.6,
				bodyColor = Color3.fromRGB(80, 200, 80), accentColor = Color3.fromRGB(50, 150, 50),
				shape = "Cylinder", emoji = "🍀", spawnWeight = 50,
			},
			{
				key = "GrassSeed", displayName = "Grass Seed",
				xp = 18, size = 0.45,
				bodyColor = Color3.fromRGB(220, 200, 80), accentColor = Color3.fromRGB(180, 160, 40),
				shape = "Sphere", emoji = "🌾", spawnWeight = 35,
			},
			{
				key = "CricketHusk", displayName = "Cricket Husk",
				xp = 42, size = 0.9,
				bodyColor = Color3.fromRGB(160, 110, 60), accentColor = Color3.fromRGB(100, 70, 30),
				shape = "Block", emoji = "🦗", spawnWeight = 15,
			},
		},
	},

	-- ══════════════════════════════════════════════════
	-- ZONE 2: WETLAND  (Level 10–20)
	-- Center (800,0). 600×600 studs. Bounds X:500–1100, Z:±300.
	-- ══════════════════════════════════════════════════
	Wetland = {
		key          = "Wetland",
		displayName  = "Wetland",
		description  = "Damp shores and murky shallows teeming with life.",
		color        = Color3.fromRGB(40, 120, 180),
		emoji        = "💧",
		minLevel     = 10,
		maxLevel     = 20,
		bossLevel    = 22,
		bounds       = { minX = 500, maxX = 1100, minZ = -300, maxZ = 300 },
		spawn        = Vector3.new(800, 3, 0),
		safeZoneRadius = 60,
		portals = {
			{ destination = "Grassland", minLevel =  1, position = Vector3.new(530, 3,   0) },
			{ destination = "Mushroom",  minLevel = 20, position = Vector3.new(1070, 3,   0) },
		},
		enemyZone  = "Wetland",
		bossKey    = "DragonFlyWarlord",
		maxNormals = 20,
		maxElites  = 5,
		food = {
			{
				key = "AlgaeClump", displayName = "Algae Clump",
				xp = 24, size = 0.7,
				bodyColor = Color3.fromRGB(40, 160, 100), accentColor = Color3.fromRGB(20, 120, 70),
				shape = "Sphere", emoji = "💚", spawnWeight = 50,
			},
			{
				key = "LilyPad", displayName = "Lily Pad",
				xp = 38, size = 0.9,
				bodyColor = Color3.fromRGB(60, 180, 80), accentColor = Color3.fromRGB(200, 60, 100),
				shape = "Cylinder", emoji = "🌸", spawnWeight = 35,
			},
			{
				key = "DrownedFly", displayName = "Drowned Fly",
				xp = 80, size = 0.75,
				bodyColor = Color3.fromRGB(80, 80, 90), accentColor = Color3.fromRGB(50, 50, 60),
				shape = "Block", emoji = "🪰", spawnWeight = 15,
			},
		},
	},

	-- ══════════════════════════════════════════════════
	-- ZONE 3: MUSHROOM HOLLOW  (Level 20–30)
	-- Center (1600,0). 600×600 studs. Bounds X:1300–1900, Z:±300.
	-- ══════════════════════════════════════════════════
	Mushroom = {
		key          = "Mushroom",
		displayName  = "Mushroom Hollow",
		description  = "Bioluminescent spores drift through perpetual dusk.",
		color        = Color3.fromRGB(140, 60, 180),
		emoji        = "🍄",
		minLevel     = 20,
		maxLevel     = 30,
		bossLevel    = 32,
		bounds       = { minX = 1300, maxX = 1900, minZ = -300, maxZ = 300 },
		spawn        = Vector3.new(1600, 3, 0),
		safeZoneRadius = 60,
		portals = {
			{ destination = "Wetland",  minLevel = 10, position = Vector3.new(1330, 3,   0) },
			{ destination = "Crystal",  minLevel = 40, position = Vector3.new(1600, 3, 270) },
		},
		enemyZone  = "Mushroom",
		bossKey    = "SporeTitan",
		maxNormals = 20,
		maxElites  = 6,
		food = {
			{
				key = "SporeCap", displayName = "Spore Cap",
				xp = 42, size = 0.8,
				bodyColor = Color3.fromRGB(180, 60, 200), accentColor = Color3.fromRGB(220, 120, 255),
				shape = "Cylinder", emoji = "🍄", spawnWeight = 45,
			},
			{
				key = "FungalRoot", displayName = "Fungal Root",
				xp = 60, size = 0.65,
				bodyColor = Color3.fromRGB(120, 80, 40), accentColor = Color3.fromRGB(180, 120, 60),
				shape = "Block", emoji = "🌰", spawnWeight = 35,
			},
			{
				key = "DecomposedBug", displayName = "Decomposed Bug",
				xp = 120, size = 1.0,
				bodyColor = Color3.fromRGB(60, 40, 20), accentColor = Color3.fromRGB(80, 160, 40),
				shape = "Block", emoji = "💀", spawnWeight = 20,
			},
		},
	},

	-- ══════════════════════════════════════════════════
	-- ZONE 4: VOLCANIC CAVERN  (Level 30–40)
	-- Center (0,800). 600×600 studs. Bounds X:±300, Z:500–1100.
	-- ══════════════════════════════════════════════════
	Volcanic = {
		key          = "Volcanic",
		displayName  = "Volcanic Cavern",
		description  = "Scorching lava flows and ember-breathing beasts lurk in the deep.",
		color        = Color3.fromRGB(220, 80, 20),
		emoji        = "🌋",
		minLevel     = 30,
		maxLevel     = 40,
		bossLevel    = 42,
		bounds       = { minX = -300, maxX = 300, minZ = 500, maxZ = 1100 },
		spawn        = Vector3.new(0, 3, 800),
		safeZoneRadius = 60,
		portals = {
			{ destination = "Grassland", minLevel =  1, position = Vector3.new(  0, 3, 530) },
			{ destination = "Crystal",   minLevel = 40, position = Vector3.new(270, 3, 800) },
		},
		enemyZone  = "Volcanic",
		bossKey    = "PyroclastQueen",
		maxNormals = 20,
		maxElites  = 6,
		food = {
			{
				key = "EmberGrub", displayName = "Ember Grub",
				xp = 70, size = 0.7,
				bodyColor = Color3.fromRGB(220, 100, 30), accentColor = Color3.fromRGB(255, 200, 50),
				shape = "Sphere", emoji = "🔥", spawnWeight = 45,
			},
			{
				key = "ScorchedBark", displayName = "Scorched Bark",
				xp = 100, size = 0.85,
				bodyColor = Color3.fromRGB(60, 30, 10), accentColor = Color3.fromRGB(180, 60, 10),
				shape = "Block", emoji = "🪵", spawnWeight = 35,
			},
			{
				key = "LavaCrystal", displayName = "Lava Crystal",
				xp = 180, size = 1.1,
				bodyColor = Color3.fromRGB(200, 40, 10), accentColor = Color3.fromRGB(255, 140, 0),
				shape = "Block", emoji = "💎", spawnWeight = 20,
			},
		},
	},

	-- ══════════════════════════════════════════════════
	-- ZONE 5: CRYSTAL ABYSS  (Level 40–50)
	-- Center (800,800). 600×600 studs. Bounds X:500–1100, Z:500–1100.
	-- ══════════════════════════════════════════════════
	Crystal = {
		key          = "Crystal",
		displayName  = "Crystal Abyss",
		description  = "Endless void crystallised into lethal geometry. Only the mightiest survive.",
		color        = Color3.fromRGB(80, 200, 255),
		emoji        = "🔮",
		minLevel     = 40,
		maxLevel     = 50,
		bossLevel    = 52,
		bounds       = { minX = 500, maxX = 1100, minZ = 500, maxZ = 1100 },
		spawn        = Vector3.new(800, 3, 800),
		safeZoneRadius = 60,
		portals = {
			{ destination = "Volcanic", minLevel = 30, position = Vector3.new(530, 3, 800) },
			{ destination = "Mushroom", minLevel = 20, position = Vector3.new(800, 3, 530) },
		},
		enemyZone  = "Crystal",
		bossKey    = "VoidEmperor",
		maxNormals = 20,
		maxElites  = 6,
		food = {
			{
				key = "VoidShard", displayName = "Void Shard",
				xp = 110, size = 0.7,
				bodyColor = Color3.fromRGB(80, 20, 120), accentColor = Color3.fromRGB(160, 80, 255),
				shape = "Sphere", emoji = "🔮", spawnWeight = 45,
			},
			{
				key = "CrystalMoss", displayName = "Crystal Moss",
				xp = 160, size = 0.85,
				bodyColor = Color3.fromRGB(100, 220, 240), accentColor = Color3.fromRGB(200, 255, 255),
				shape = "Block", emoji = "🫧", spawnWeight = 35,
			},
			{
				key = "AbyssEgg", displayName = "Abyss Egg",
				xp = 280, size = 1.2,
				bodyColor = Color3.fromRGB(20, 10, 40), accentColor = Color3.fromRGB(140, 60, 220),
				shape = "Sphere", emoji = "🥚", spawnWeight = 20,
			},
		},
	},
}

ZoneData.ZoneOrder = { "Grassland", "Wetland", "Mushroom", "Volcanic", "Crystal" }

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────

-- Random position anywhere inside a zone
function ZoneData.RandomPos(zoneKey, yLevel)
	local z = ZoneData.Zones[zoneKey]
	if not z then return Vector3.new(0, 3, 0) end
	yLevel = yLevel or 3
	return Vector3.new(
		math.random(z.bounds.minX, z.bounds.maxX),
		yLevel,
		math.random(z.bounds.minZ, z.bounds.maxZ)
	)
end

-- Random position at least safe-zone radius + buffer away from zone spawn
function ZoneData.RandomPosOutsideSafe(zoneKey, yLevel)
	local z  = ZoneData.Zones[zoneKey]
	if not z then return Vector3.new(0, 3, 0) end
	yLevel   = yLevel or 3
	local r  = (z.safeZoneRadius or ZoneData.SafeZoneRadius) + 10
	local sx = z.spawn.X
	local sz = z.spawn.Z
	for _ = 1, 30 do
		local px = math.random(z.bounds.minX, z.bounds.maxX)
		local pz = math.random(z.bounds.minZ, z.bounds.maxZ)
		if math.sqrt((px - sx)^2 + (pz - sz)^2) >= r then
			return Vector3.new(px, yLevel, pz)
		end
	end
	-- Fallback: radial offset from spawn
	local angle = math.random() * math.pi * 2
	return Vector3.new(
		sx + math.cos(angle) * (r + 30),
		yLevel,
		sz + math.sin(angle) * (r + 30)
	)
end

-- Fraction 0 (at spawn) → 1 (far edge of zone), used for level scaling by distance
function ZoneData.GetDistanceFraction(zoneKey, position)
	local z = ZoneData.Zones[zoneKey]
	if not z then return 0.5 end
	local dx   = position.X - z.spawn.X
	local dz   = position.Z - z.spawn.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	local maxDist = math.max(
		z.bounds.maxX - z.spawn.X,
		z.spawn.X - z.bounds.minX,
		z.bounds.maxZ - z.spawn.Z,
		z.spawn.Z - z.bounds.minZ
	)
	return math.clamp(dist / maxDist, 0, 1)
end

-- Detect which zone a world-position belongs to (or nil)
function ZoneData.GetZone(position)
	local x, pz = position.X, position.Z
	for _, key in ipairs(ZoneData.ZoneOrder) do
		local b = ZoneData.Zones[key].bounds
		if x >= b.minX and x <= b.maxX and pz >= b.minZ and pz <= b.maxZ then
			return key
		end
	end
	return nil
end

-- Is position inside any zone's safe-zone radius?
function ZoneData.IsInSafeZone(position)
	for _, key in ipairs(ZoneData.ZoneOrder) do
		local z = ZoneData.Zones[key]
		local r = z.safeZoneRadius or ZoneData.SafeZoneRadius
		local dx = position.X - z.spawn.X
		local dz = position.Z - z.spawn.Z
		if math.sqrt(dx * dx + dz * dz) <= r then
			return true, key
		end
	end
	return false, nil
end

-- Weighted random food pick for a zone
function ZoneData.RollFood(zoneKey)
	local zone = ZoneData.Zones[zoneKey]
	if not zone then return nil end
	local pool = {}
	for _, f in ipairs(zone.food) do
		for _ = 1, f.spawnWeight do
			table.insert(pool, f)
		end
	end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

return ZoneData
