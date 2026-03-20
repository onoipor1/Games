-- LevelData.lua
-- Defines the player level system (1–50), XP requirements per level,
-- evolution thresholds every 10 levels, rebirth bonuses, and mob stat scaling.

local LevelData = {}

-- ─────────────────────────────────────────
-- Level cap
-- ─────────────────────────────────────────
LevelData.MaxLevel = 50

-- XP required to advance from level N → N+1
-- Formula: floor(100 * N^1.3)  (grows roughly from 100 at L1 to ~1930 at L50)
LevelData.XPTable = {}
for i = 1, LevelData.MaxLevel do
	LevelData.XPTable[i] = math.floor(100 * (i ^ 1.3))
end

-- ─────────────────────────────────────────
-- Evolution thresholds
-- Stage 1 : levels  1 –  9   (no stage requirement)
-- Stage 2 : levels 10 – 19
-- Stage 3 : levels 20 – 29
-- Stage 4 : levels 30 – 39
-- Stage 5 : levels 40 – 50
-- ─────────────────────────────────────────
LevelData.EvolutionLevels = { 10, 20, 30, 40 }  -- levels at which stage increases

function LevelData.GetStageForLevel(level)
	if     level >= 40 then return 5
	elseif level >= 30 then return 4
	elseif level >= 20 then return 3
	elseif level >= 10 then return 2
	else                    return 1
	end
end

-- ─────────────────────────────────────────
-- Rebirth system
-- ─────────────────────────────────────────
LevelData.MaxRebirths        = 20
LevelData.XPBonusPerRebirth  = 0.10   -- +10% XP gain per rebirth level
LevelData.DmgBonusPerRebirth = 0.05   -- +5%  damage    per rebirth level

-- Returns { xpMult, dmgMult } total multipliers for a given rebirth count
function LevelData.GetRebirthMults(rebirths)
	local r = math.min(rebirths or 0, LevelData.MaxRebirths)
	return {
		xpMult  = 1 + r * LevelData.XPBonusPerRebirth,
		dmgMult = 1 + r * LevelData.DmgBonusPerRebirth,
	}
end

-- ─────────────────────────────────────────
-- Mob stat scaling
-- Base stats in EnemyData are defined at zone minLevel.
-- For each level above that baseline, apply these percentage boosts.
-- ─────────────────────────────────────────
LevelData.MobHPPerLevel      = 0.15   -- +15% HP   per mob level above base
LevelData.MobDmgPerLevel     = 0.12   -- +12% DMG  per mob level above base
LevelData.MobXPPerLevel      = 0.50   -- +50% XP   per mob level (rewards risk)
LevelData.MobCrystalPerLevel = 0.30   -- +30% crystal drop per mob level

function LevelData.ScaleMobHP(baseHP, mobLevel)
	return math.max(1, math.floor(baseHP * (1 + (mobLevel - 1) * LevelData.MobHPPerLevel)))
end

function LevelData.ScaleMobDmg(baseDmg, mobLevel)
	return math.max(1, math.floor(baseDmg * (1 + (mobLevel - 1) * LevelData.MobDmgPerLevel)))
end

function LevelData.ScaleMobXP(baseXP, mobLevel)
	return math.max(1, math.floor(baseXP * (1 + (mobLevel - 1) * LevelData.MobXPPerLevel)))
end

function LevelData.ScaleMobCrystals(base, mobLevel)
	return math.max(0, math.floor(base * (1 + (mobLevel - 1) * LevelData.MobCrystalPerLevel)))
end

-- ─────────────────────────────────────────
-- Leaderboard score formula
-- ─────────────────────────────────────────
-- Score prioritises rebirths over level (each rebirth worth 60 level-equivalents)
function LevelData.LeaderboardScore(level, rebirths)
	return (rebirths or 0) * 60 + (level or 1)
end

return LevelData
