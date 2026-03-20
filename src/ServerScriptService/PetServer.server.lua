-- PetServer.server.lua
-- Manages pet egg opening, pet inventory, equipping, and applying pet buffs
-- to player stats. Reads crystal balance via _G.PlayerCrystals (set by GameServer).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetData   = require(ReplicatedStorage:WaitForChild("PetData"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- Per-player pet state
-- Stored structure:
--   { pets = [{name,rarity,emoji},...], equipped = index|nil }
-- Shared via _G so GameServer can read pet buffs when applying stats.
-- ─────────────────────────────────────────
_G.PetState    = _G.PetState    or {}   -- [player] = { pets, equipped }
_G.GetPetBuffs = function(player)        -- called by GameServer
	local state = _G.PetState[player]
	if not state or not state.equipped then
		return { speed = 0, health = 0, damagePercent = 0 }
	end
	local pet = state.pets[state.equipped]
	return PetData.CalcBuffs(pet)
end

-- ─────────────────────────────────────────
-- Initialise player pet state (called by GameServer via _G after data load)
-- ─────────────────────────────────────────
_G.InitPetState = function(player, savedPets, savedEquipped)
	_G.PetState[player] = {
		pets     = savedPets     or {},
		equipped = savedEquipped or nil,
	}
end

local function notifyClient(player)
	local state = _G.PetState[player]
	if not state then return end
	Remotes:FindFirstChild("PetsChanged"):FireClient(player, {
		pets     = state.pets,
		equipped = state.equipped,
	})
end

-- ─────────────────────────────────────────
-- Open an egg: deduct crystals, roll rarity + pet, add to inventory
-- ─────────────────────────────────────────
local function openEgg(player, eggKey)
	local eggDef = PetData.Eggs[eggKey]
	if not eggDef then return end

	-- Check crystals
	local crystals = (_G.PlayerCrystals and _G.PlayerCrystals[player]) or 0
	if crystals < eggDef.crystalCost then
		Remotes:FindFirstChild("EggResult"):FireClient(player, {
			success = false,
			reason  = "Not enough crystals! Need " .. eggDef.crystalCost,
		})
		return
	end

	-- Deduct crystals
	if _G.SpendCrystals then
		_G.SpendCrystals(player, eggDef.crystalCost)
	end

	-- Roll
	local rarity  = PetData.RollRarity(eggKey)
	local petInfo = PetData.RollPet(rarity)
	local rarDef  = PetData.Rarities[rarity]

	local newPet = {
		name    = petInfo.name,
		rarity  = rarity,
		emoji   = petInfo.emoji,
		flavour = petInfo.flavour,
		buffDesc = rarDef.buffDesc,
	}

	-- Add to inventory (cap at 50 pets)
	local state = _G.PetState[player]
	if not state then return end
	if #state.pets >= 50 then
		Remotes:FindFirstChild("EggResult"):FireClient(player, {
			success = false,
			reason  = "Pet inventory full! (Max 50)",
		})
		return
	end

	table.insert(state.pets, newPet)
	notifyClient(player)

	Remotes:FindFirstChild("EggResult"):FireClient(player, {
		success = true,
		pet     = newPet,
		eggName = eggDef.displayName,
	})

	print(string.format("[PetServer] %s opened %s → %s %s (%s)",
		player.Name, eggKey, rarity, newPet.name, newPet.emoji))
end

-- ─────────────────────────────────────────
-- Remote: PurchaseEgg
-- ─────────────────────────────────────────
Remotes:FindFirstChild("PurchaseEgg").OnServerEvent:Connect(function(player, eggKey)
	openEgg(player, eggKey)
end)

-- ─────────────────────────────────────────
-- Remote: EquipPet (petIndex or nil to unequip)
-- ─────────────────────────────────────────
Remotes:FindFirstChild("EquipPet").OnServerEvent:Connect(function(player, petIndex)
	local state = _G.PetState[player]
	if not state then return end

	if petIndex == nil then
		state.equipped = nil
	elseif type(petIndex) == "number" and state.pets[petIndex] then
		state.equipped = petIndex
	end

	notifyClient(player)

	-- Re-apply character stats so pet buffs take effect immediately
	if _G.ApplyPlayerStats then
		_G.ApplyPlayerStats(player)
	end
end)

-- ─────────────────────────────────────────
-- Cleanup
-- ─────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	-- GameServer handles saving; we just clear memory
	_G.PetState[player] = nil
end)

print("[InsectEvo] PetServer initialized.")
