-- TalentServer.server.lua
-- Handles talent purchases (TalentPurchase remote), persists talent data in DataStore,
-- exposes _G.GetTalentEffects(player) for other systems to query active bonuses.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local TalentData   = require(ReplicatedStorage:WaitForChild("TalentData"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Wait for RemoteEvents to be fully initialised by GameServer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function getRemote(name)
	return Remotes:WaitForChild(name, 10)
end

local DataStore = DataStoreService:GetDataStore("InsectEvoTalentsV1")

-- ─────────────────────────────────────────
-- In-memory talent state per player
-- { [player] = { talentId = true, ... } }
-- ─────────────────────────────────────────
local TalentState = {}

local function loadTalents(player)
	local key = "talents_" .. player.UserId
	local ok, saved = pcall(function() return DataStore:GetAsync(key) end)
	if ok and type(saved) == "table" then
		return saved
	end
	return {}
end

local function saveTalents(player)
	local talents = TalentState[player]
	if not talents then return end
	local key = "talents_" .. player.UserId
	pcall(function()
		DataStore:SetAsync(key, talents)
	end)
end

-- ─────────────────────────────────────────
-- _G interface
-- ─────────────────────────────────────────

_G.GetTalentEffects = function(player)
	local talents     = TalentState[player] or {}
	local data        = _G.PlayerData and _G.PlayerData[player]
	local insectType  = data and data.insectType or nil
	return TalentData.ComputeEffects(talents, insectType)
end

_G.GetTalentState = function(player)
	return TalentState[player] or {}
end

-- ─────────────────────────────────────────
-- Sync to client
-- ─────────────────────────────────────────
local function syncClient(player)
	local remote = getRemote("TalentSync")
	if remote then
		remote:FireClient(player, TalentState[player] or {})
	end
end

-- ─────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────
local function onPlayerAdded(player)
	TalentState[player] = loadTalents(player)
	-- Wait briefly for GameServer to set up PlayerData before syncing
	task.delay(2, function()
		if Players:FindFirstChild(player.Name) then
			syncClient(player)
		end
	end)
end

local function onPlayerRemoving(player)
	saveTalents(player)
	TalentState[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- ─────────────────────────────────────────
-- TalentPurchase remote handler
-- ─────────────────────────────────────────
local function onTalentPurchase(player, talentId)
	if type(talentId) ~= "string" then return end

	local talents = TalentState[player]
	if not talents then return end

	-- Already purchased?
	if talents[talentId] then return end

	-- Validate the talent exists
	local node = TalentData.Nodes[talentId]
	if not node then return end

	-- Check insect-specific restriction
	local data = _G.PlayerData and _G.PlayerData[player]
	if node.insectType then
		-- Can only buy this if it matches current OR retained insect type
		local currentType = data and data.insectType
		if currentType ~= node.insectType then return end
	end

	-- Check requirements
	if not TalentData.CanPurchase(talentId, talents) then return end

	-- Spend crystals
	local cost = node.cost or 0
	if cost > 0 then
		if not (_G.SpendCrystals and _G.SpendCrystals(player, cost)) then return end
	end

	-- Grant talent
	talents[talentId] = true
	saveTalents(player)
	syncClient(player)

	print(string.format("[TalentServer] %s purchased talent '%s' (cost %d)", player.Name, talentId, cost))
end

getRemote("TalentPurchase").OnServerEvent:Connect(onTalentPurchase)

print("[InsectEvo] TalentServer initialized.")
