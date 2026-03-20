-- TalentData.lua
-- Defines the persistent talent tree bought with crystals.
-- All talents survive rebirth. Effects are additive bonuses layered on top of base stats.
--
-- Categories:
--   "Universal" – available to any insect
--   "Ant","Beetle","Butterfly","Bee","Spider" – insect-specific (apply when that companion is active)

local TalentData = {}

-- ─────────────────────────────────────────
-- Node definitions
-- effect keys:
--   xpBonus            – fraction added to xpMult  (0.10 = +10%)
--   crystalBonus       – fraction added to crystalMult
--   companionHpBonus   – fraction added to companion maxHealth
--   companionDmgBonus  – fraction added to companion damage
--   companionSpdBonus  – fraction added to companion attack speed
--   companionRegenRate – HP per second companion regenerates
--   abilityCooldownMult– multiplied to specific ability cooldown (< 1 = shorter)
--   abilityDmgBonus    – extra fraction on a specific ability's damage
-- ─────────────────────────────────────────
TalentData.Nodes = {

	-- ══════════════════════════════════════
	-- UNIVERSAL  ─  Column 1: XP
	-- ══════════════════════════════════════
	xp1 = {
		id          = "xp1",
		name        = "XP Surge I",
		description = "+10% XP from all sources",
		icon        = "✦",
		cost        = 100,
		tier        = 1,
		requires    = nil,
		category    = "Universal",
		col         = 1,
		effect      = { xpBonus = 0.10 },
	},
	xp2 = {
		id          = "xp2",
		name        = "XP Surge II",
		description = "+20% XP from all sources",
		icon        = "✦",
		cost        = 350,
		tier        = 2,
		requires    = "xp1",
		category    = "Universal",
		col         = 1,
		effect      = { xpBonus = 0.20 },
	},
	xp3 = {
		id          = "xp3",
		name        = "XP Mastery",
		description = "+35% XP from all sources",
		icon        = "✦",
		cost        = 900,
		tier        = 3,
		requires    = "xp2",
		category    = "Universal",
		col         = 1,
		effect      = { xpBonus = 0.35 },
	},

	-- ══════════════════════════════════════
	-- UNIVERSAL  ─  Column 2: Crystals
	-- ══════════════════════════════════════
	cry1 = {
		id          = "cry1",
		name        = "Crystal Eye I",
		description = "+10% crystal drops",
		icon        = "💎",
		cost        = 120,
		tier        = 1,
		requires    = nil,
		category    = "Universal",
		col         = 2,
		effect      = { crystalBonus = 0.10 },
	},
	cry2 = {
		id          = "cry2",
		name        = "Crystal Eye II",
		description = "+20% crystal drops",
		icon        = "💎",
		cost        = 400,
		tier        = 2,
		requires    = "cry1",
		category    = "Universal",
		col         = 2,
		effect      = { crystalBonus = 0.20 },
	},
	cry3 = {
		id          = "cry3",
		name        = "Crystal Mastery",
		description = "+35% crystal drops",
		icon        = "💎",
		cost        = 1000,
		tier        = 3,
		requires    = "cry2",
		category    = "Universal",
		col         = 2,
		effect      = { crystalBonus = 0.35 },
	},

	-- ══════════════════════════════════════
	-- UNIVERSAL  ─  Column 3: Companion HP
	-- ══════════════════════════════════════
	chp1 = {
		id          = "chp1",
		name        = "Tough Shell I",
		description = "+15% companion max health",
		icon        = "🛡",
		cost        = 150,
		tier        = 1,
		requires    = nil,
		category    = "Universal",
		col         = 3,
		effect      = { companionHpBonus = 0.15 },
	},
	chp2 = {
		id          = "chp2",
		name        = "Tough Shell II",
		description = "+25% companion max health",
		icon        = "🛡",
		cost        = 500,
		tier        = 2,
		requires    = "chp1",
		category    = "Universal",
		col         = 3,
		effect      = { companionHpBonus = 0.25 },
	},
	chp3 = {
		id          = "chp3",
		name        = "Fortress",
		description = "+40% companion max health",
		icon        = "🛡",
		cost        = 1200,
		tier        = 3,
		requires    = "chp2",
		category    = "Universal",
		col         = 3,
		effect      = { companionHpBonus = 0.40 },
	},

	-- ══════════════════════════════════════
	-- UNIVERSAL  ─  Column 4: Companion Damage
	-- ══════════════════════════════════════
	cdmg1 = {
		id          = "cdmg1",
		name        = "Sharp Fangs I",
		description = "+10% companion damage",
		icon        = "⚔",
		cost        = 150,
		tier        = 1,
		requires    = nil,
		category    = "Universal",
		col         = 4,
		effect      = { companionDmgBonus = 0.10 },
	},
	cdmg2 = {
		id          = "cdmg2",
		name        = "Sharp Fangs II",
		description = "+20% companion damage",
		icon        = "⚔",
		cost        = 500,
		tier        = 2,
		requires    = "cdmg1",
		category    = "Universal",
		col         = 4,
		effect      = { companionDmgBonus = 0.20 },
	},
	cdmg3 = {
		id          = "cdmg3",
		name        = "Predator Strike",
		description = "+35% companion damage",
		icon        = "⚔",
		cost        = 1200,
		tier        = 3,
		requires    = "cdmg2",
		category    = "Universal",
		col         = 4,
		effect      = { companionDmgBonus = 0.35 },
	},

	-- ══════════════════════════════════════
	-- UNIVERSAL  ─  Column 5: Attack Speed
	-- ══════════════════════════════════════
	cspd1 = {
		id          = "cspd1",
		name        = "Swift Strike I",
		description = "+15% companion attack speed",
		icon        = "⚡",
		cost        = 130,
		tier        = 1,
		requires    = nil,
		category    = "Universal",
		col         = 5,
		effect      = { companionSpdBonus = 0.15 },
	},
	cspd2 = {
		id          = "cspd2",
		name        = "Swift Strike II",
		description = "+25% companion attack speed",
		icon        = "⚡",
		cost        = 450,
		tier        = 2,
		requires    = "cspd1",
		category    = "Universal",
		col         = 5,
		effect      = { companionSpdBonus = 0.25 },
	},
	cspd3 = {
		id          = "cspd3",
		name        = "Blur",
		description = "+40% companion attack speed",
		icon        = "⚡",
		cost        = 1100,
		tier        = 3,
		requires    = "cspd2",
		category    = "Universal",
		col         = 5,
		effect      = { companionSpdBonus = 0.40 },
	},

	-- ══════════════════════════════════════
	-- ANT-SPECIFIC
	-- ══════════════════════════════════════
	ant_passive = {
		id          = "ant_passive",
		name        = "Colony Bond",
		description = "Companion deals +20% damage to enemies below 50% HP",
		icon        = "🐜",
		cost        = 500,
		tier        = 1,
		requires    = nil,
		category    = "Ant",
		col         = 1,
		effect      = { companionDmgBonus = 0.20 },
	},
	ant_acid = {
		id          = "ant_acid",
		name        = "Corrosive Acid",
		description = "Acid Spray deals +50% damage",
		icon        = "☣",
		cost        = 650,
		tier        = 2,
		requires    = "ant_passive",
		category    = "Ant",
		col         = 1,
		effect      = { abilityDmgBonus = { ["Acid Spray"] = 0.50 } },
	},
	ant_workers = {
		id          = "ant_workers",
		name        = "Worker Rush",
		description = "Summon Workers cooldown reduced by 40%",
		icon        = "👑",
		cost        = 900,
		tier        = 3,
		requires    = "ant_acid",
		category    = "Ant",
		col         = 1,
		effect      = { abilityCooldownMult = { ["Summon Workers"] = 0.60 } },
	},

	-- ══════════════════════════════════════
	-- BEETLE-SPECIFIC
	-- ══════════════════════════════════════
	beetle_iron = {
		id          = "beetle_iron",
		name        = "Iron Core",
		description = "Companion takes 20% less damage",
		icon        = "🪲",
		cost        = 500,
		tier        = 1,
		requires    = nil,
		category    = "Beetle",
		col         = 1,
		effect      = { companionHpBonus = 0.20 },
	},
	beetle_charge = {
		id          = "beetle_charge",
		name        = "Devastating Charge",
		description = "Horn Charge deals +60% damage",
		icon        = "🏹",
		cost        = 650,
		tier        = 2,
		requires    = "beetle_iron",
		category    = "Beetle",
		col         = 1,
		effect      = { abilityDmgBonus = { ["Horn Charge"] = 0.60 } },
	},
	beetle_regen = {
		id          = "beetle_regen",
		name        = "Shell Regen",
		description = "Companion regenerates 2 HP per second",
		icon        = "💚",
		cost        = 900,
		tier        = 3,
		requires    = "beetle_charge",
		category    = "Beetle",
		col         = 1,
		effect      = { companionRegenRate = 2 },
	},

	-- ══════════════════════════════════════
	-- BUTTERFLY-SPECIFIC
	-- ══════════════════════════════════════
	butterfly_scales = {
		id          = "butterfly_scales",
		name        = "Prismatic Scales",
		description = "Scale Dust lasts 50% longer",
		icon        = "🦋",
		cost        = 500,
		tier        = 1,
		requires    = nil,
		category    = "Butterfly",
		col         = 1,
		effect      = { abilityDmgBonus = { ["Scale Dust"] = 0.30 } },
	},
	butterfly_silk = {
		id          = "butterfly_silk",
		name        = "Sticky Silk",
		description = "Silk Shot cooldown reduced by 30%",
		icon        = "🕸",
		cost        = 650,
		tier        = 2,
		requires    = "butterfly_scales",
		category    = "Butterfly",
		col         = 1,
		effect      = { abilityCooldownMult = { ["Silk Shot"] = 0.70 } },
	},
	butterfly_moon = {
		id          = "butterfly_moon",
		name        = "Full Moon",
		description = "Moonbeam cooldown reduced by 30%",
		icon        = "🌙",
		cost        = 900,
		tier        = 3,
		requires    = "butterfly_silk",
		category    = "Butterfly",
		col         = 1,
		effect      = { abilityCooldownMult = { ["Moonbeam"] = 0.70 } },
	},

	-- ══════════════════════════════════════
	-- BEE-SPECIFIC
	-- ══════════════════════════════════════
	bee_swarm = {
		id          = "bee_swarm",
		name        = "Swarm Sting",
		description = "Sting deals +30% damage",
		icon        = "🐝",
		cost        = 500,
		tier        = 1,
		requires    = nil,
		category    = "Bee",
		col         = 1,
		effect      = { abilityDmgBonus = { ["Sting"] = 0.30 } },
	},
	bee_venom = {
		id          = "bee_venom",
		name        = "Mega Venom",
		description = "Venom Cloud cooldown reduced by 35%",
		icon        = "☠",
		cost        = 650,
		tier        = 2,
		requires    = "bee_swarm",
		category    = "Bee",
		col         = 1,
		effect      = { abilityCooldownMult = { ["Venom Cloud"] = 0.65 } },
	},
	bee_royal = {
		id          = "bee_royal",
		name        = "Royal Might",
		description = "Royal Decree deals +50% damage",
		icon        = "👑",
		cost        = 900,
		tier        = 3,
		requires    = "bee_venom",
		category    = "Bee",
		col         = 1,
		effect      = { abilityDmgBonus = { ["Royal Decree"] = 0.50 } },
	},

	-- ══════════════════════════════════════
	-- SPIDER-SPECIFIC
	-- ══════════════════════════════════════
	spider_web = {
		id          = "spider_web",
		name        = "Sticky Web",
		description = "Web Trap cooldown reduced by 35%",
		icon        = "🕷",
		cost        = 500,
		tier        = 1,
		requires    = nil,
		category    = "Spider",
		col         = 1,
		effect      = { abilityCooldownMult = { ["Web Trap"] = 0.65 } },
	},
	spider_pounce = {
		id          = "spider_pounce",
		name        = "Critical Pounce",
		description = "Pounce deals +50% damage",
		icon        = "💥",
		cost        = 650,
		tier        = 2,
		requires    = "spider_web",
		category    = "Spider",
		col         = 1,
		effect      = { abilityDmgBonus = { ["Pounce"] = 0.50 } },
	},
	spider_silk = {
		id          = "spider_silk",
		name        = "Silk Armor",
		description = "+20% companion health from woven silk",
		icon        = "🛡",
		cost        = 900,
		tier        = 3,
		requires    = "spider_pounce",
		category    = "Spider",
		col         = 1,
		effect      = { companionHpBonus = 0.20 },
	},
}

-- ─────────────────────────────────────────
-- Layout order for each tab in the UI
-- ─────────────────────────────────────────
TalentData.UniversalOrder = { "xp1","xp2","xp3", "cry1","cry2","cry3",
	"chp1","chp2","chp3", "cdmg1","cdmg2","cdmg3", "cspd1","cspd2","cspd3" }

TalentData.InsectOrder = {
	Ant       = { "ant_passive",       "ant_acid",       "ant_workers"   },
	Beetle    = { "beetle_iron",       "beetle_charge",  "beetle_regen"  },
	Butterfly = { "butterfly_scales",  "butterfly_silk", "butterfly_moon" },
	Bee       = { "bee_swarm",         "bee_venom",      "bee_royal"     },
	Spider    = { "spider_web",        "spider_pounce",  "spider_silk"   },
}

-- ─────────────────────────────────────────
-- Compute combined effects for a set of purchased talent IDs
-- Returns a flat effect table with summed bonuses.
-- ─────────────────────────────────────────
function TalentData.ComputeEffects(purchasedTalents, activeInsectType)
	local out = {
		xpBonus           = 0,
		crystalBonus      = 0,
		companionHpBonus  = 0,
		companionDmgBonus = 0,
		companionSpdBonus = 0,
		companionRegenRate = 0,
		abilityDmgBonus     = {},
		abilityCooldownMult = {},
	}

	for talentId, _ in pairs(purchasedTalents or {}) do
		local node = TalentData.Nodes[talentId]
		if not node then continue end
		-- Skip insect-specific talents that don't match active insect
		if node.category ~= "Universal" and node.category ~= activeInsectType then
			continue
		end
		local e = node.effect
		out.xpBonus            = out.xpBonus            + (e.xpBonus           or 0)
		out.crystalBonus       = out.crystalBonus       + (e.crystalBonus      or 0)
		out.companionHpBonus   = out.companionHpBonus   + (e.companionHpBonus  or 0)
		out.companionDmgBonus  = out.companionDmgBonus  + (e.companionDmgBonus or 0)
		out.companionSpdBonus  = out.companionSpdBonus  + (e.companionSpdBonus or 0)
		out.companionRegenRate = out.companionRegenRate + (e.companionRegenRate or 0)
		if e.abilityDmgBonus then
			for ability, bonus in pairs(e.abilityDmgBonus) do
				out.abilityDmgBonus[ability] = (out.abilityDmgBonus[ability] or 0) + bonus
			end
		end
		if e.abilityCooldownMult then
			for ability, mult in pairs(e.abilityCooldownMult) do
				out.abilityCooldownMult[ability] = (out.abilityCooldownMult[ability] or 1) * mult
			end
		end
	end
	return out
end

-- ─────────────────────────────────────────
-- Validate a purchase: is the requirement met?
-- ─────────────────────────────────────────
function TalentData.CanPurchase(talentId, purchasedTalents)
	local node = TalentData.Nodes[talentId]
	if not node then return false, "Unknown talent" end
	if purchasedTalents[talentId] then return false, "Already purchased" end
	if node.requires and not purchasedTalents[node.requires] then
		local req = TalentData.Nodes[node.requires]
		return false, "Requires: " .. (req and req.name or node.requires)
	end
	return true, nil
end

return TalentData
