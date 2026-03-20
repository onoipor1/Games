-- MonetizationServer.server.lua
-- Handles game pass ownership, crystal developer-product purchases,
-- and exposes per-player pass/multiplier data to other server scripts.

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage:WaitForChild("GamePasses"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Shared table accessed by GameServer / PetServer via _G
_G.PlayerPasses   = _G.PlayerPasses   or {}   -- [player] = { VIP=bool, DoubleXP=bool, DoubleDmg=bool }
_G.AddCrystals    = _G.AddCrystals    or nil   -- set by GameServer once ready; (player, amount) → nil

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- Check all passes for a player
-- ─────────────────────────────────────────
local function checkPasses(player)
	local owned = {}
	for key, id in pairs(GamePasses.IDs) do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		owned[key] = (ok and result == true)
	end
	_G.PlayerPasses[player] = owned
	Remotes:FindFirstChild("PassesChanged"):FireClient(player, owned)
	return owned
end

-- ─────────────────────────────────────────
-- Effective multipliers for a player (stacks passes + events)
-- ─────────────────────────────────────────
function _G.GetMultipliers(player)
	local passes    = _G.PlayerPasses[player] or {}
	local event     = _G.ActiveEvent or GameConfig.ServerEvents.None

	local xpMult      = event.xpMult       or 1.0
	local crystalMult = event.crystalMult  or 1.0
	local dmgMult     = 1.0
	local speedBonus  = 0

	if passes.VIP then
		xpMult      = xpMult      * GamePasses.Benefits.VIP.xpMultiplier
		crystalMult = crystalMult * GamePasses.Benefits.VIP.crystalMultiplier
		speedBonus  = speedBonus  + GamePasses.Benefits.VIP.speedBonus
	end
	if passes.DoubleXP then
		xpMult = xpMult * GamePasses.Benefits.DoubleXP.xpMultiplier
	end
	if passes.DoubleDmg then
		dmgMult = dmgMult * GamePasses.Benefits.DoubleDmg.damageMultiplier
	end

	return {
		xpMult      = xpMult,
		crystalMult = crystalMult,
		dmgMult     = dmgMult,
		speedBonus  = speedBonus,
	}
end

-- ─────────────────────────────────────────
-- Handle Developer Product receipts (crystal purchases)
-- ─────────────────────────────────────────
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left; retry later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local crystals = GamePasses.ProductIdToCrystals[receiptInfo.ProductId]
	if crystals then
		-- _G.AddCrystals is set by GameServer after it initialises
		if _G.AddCrystals then
			_G.AddCrystals(player, crystals)
		else
			-- Fallback: queue until GameServer ready
			task.delay(3, function()
				if _G.AddCrystals then _G.AddCrystals(player, crystals) end
			end)
		end
		print(string.format("[Monetization] %s purchased %d crystals (product %d)",
			player.Name, crystals, receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ─────────────────────────────────────────
-- Client → Server: prompt game pass purchase
-- ─────────────────────────────────────────
Remotes:FindFirstChild("PromptGamePass").OnServerEvent:Connect(function(player, passKey)
	local id = GamePasses.IDs[passKey]
	if not id then return end
	MarketplaceService:PromptGamePassPurchase(player, id)
end)

-- On purchase completed, re-check passes
MarketplaceService.PromptGamePassSaleCompleted:Connect(function(player, passId, wasPurchased)
	if wasPurchased then
		checkPasses(player)
	end
end)

-- ─────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	task.defer(checkPasses, player)   -- defer so DataStore in GameServer runs first
end)

Players.PlayerRemoving:Connect(function(player)
	_G.PlayerPasses[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(checkPasses, player)
end

print("[InsectEvo] MonetizationServer initialized.")
