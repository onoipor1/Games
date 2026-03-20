-- LeaderboardServer.server.lua
-- Maintains a top-10 leaderboard sorted by (rebirths × 60 + level).
-- Saves scores to a DataStore (persistent across sessions) and broadcasts
-- updated data to all clients every 30 seconds or on a kill/level-up.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")

local LevelData = require(ReplicatedStorage:WaitForChild("LevelData"))

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local LeaderStore  = DataStoreService:GetOrderedDataStore("InsectEvoLeaderboard")

local BROADCAST_INTERVAL = 30   -- seconds between full broadcasts
local TOP_COUNT          = 10

-- ─────────────────────────────────────────
-- Save a player's score to the ordered DataStore
-- ─────────────────────────────────────────
local function saveScore(player)
	local data = _G.PlayerData and _G.PlayerData[player]
	if not data then return end

	local score = LevelData.LeaderboardScore(data.level, data.rebirths)
	pcall(function()
		LeaderStore:SetAsync(tostring(player.UserId), score)
	end)
end

-- ─────────────────────────────────────────
-- Fetch top N entries from DataStore
-- ─────────────────────────────────────────
local function fetchTop()
	local ok, pages = pcall(function()
		return LeaderStore:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok or not pages then return {} end

	local results = {}
	local ok2, items = pcall(function() return pages:GetCurrentPage() end)
	if not ok2 then return {} end

	for _, entry in ipairs(items) do
		local userId = tonumber(entry.key)
		local score  = entry.value
		-- Decode level/rebirths from score (rebirths = floor(score/60), level = score % 60)
		local rebirths = math.floor(score / 60)
		local level    = score - rebirths * 60
		-- Try to get display name
		local name = "Unknown"
		pcall(function()
			name = game:GetService("Players"):GetNameFromUserIdAsync(userId) or "Unknown"
		end)
		table.insert(results, {
			name     = name,
			userId   = userId,
			level    = level,
			rebirths = rebirths,
			score    = score,
		})
	end
	return results
end

-- ─────────────────────────────────────────
-- Build in-memory leaderboard from currently online players
-- (merged with DataStore results for speed when players are online)
-- ─────────────────────────────────────────
local function buildLiveBoard()
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = _G.PlayerData and _G.PlayerData[player]
		if data then
			table.insert(entries, {
				name     = player.Name,
				userId   = player.UserId,
				level    = data.level    or 1,
				rebirths = data.rebirths or 0,
				score    = LevelData.LeaderboardScore(data.level, data.rebirths),
			})
		end
	end
	table.sort(entries, function(a, b) return a.score > b.score end)
	-- Trim to TOP_COUNT
	while #entries > TOP_COUNT do table.remove(entries) end
	return entries
end

-- ─────────────────────────────────────────
-- Broadcast leaderboard to all clients
-- ─────────────────────────────────────────
local function broadcastLeaderboard()
	local live     = buildLiveBoard()
	local persisted = {}
	task.spawn(function()
		persisted = fetchTop()
	end)
	task.wait(0.1)  -- give DataStore a moment

	-- Merge live + persisted (deduplicate by userId)
	local seen   = {}
	local merged = {}
	for _, e in ipairs(live) do
		if not seen[e.userId] then
			seen[e.userId] = true
			table.insert(merged, e)
		end
	end
	for _, e in ipairs(persisted) do
		if not seen[e.userId] then
			seen[e.userId] = true
			table.insert(merged, e)
		end
	end
	table.sort(merged, function(a, b) return a.score > b.score end)
	while #merged > TOP_COUNT do table.remove(merged) end

	Remotes:FindFirstChild("LeaderboardData"):FireAllClients(merged)
end

-- ─────────────────────────────────────────
-- Expose update trigger (called by GameServer on level-up / rebirth)
-- ─────────────────────────────────────────
_G.UpdateLeaderboard = function(player)
	saveScore(player)
	broadcastLeaderboard()
end

-- ─────────────────────────────────────────
-- Periodic broadcast loop
-- ─────────────────────────────────────────
local timer = 0
RunService.Heartbeat:Connect(function(dt)
	timer = timer + dt
	if timer >= BROADCAST_INTERVAL then
		timer = 0
		broadcastLeaderboard()
	end
end)

-- Save score when players leave
Players.PlayerRemoving:Connect(saveScore)

-- Initial broadcast after server warms up
task.wait(8)
broadcastLeaderboard()

print("[InsectEvo] LeaderboardServer ready. Broadcasting every "
	.. BROADCAST_INTERVAL .. "s.")
