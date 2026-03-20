-- ZoneGui.client.lua
-- Zone map / teleport panel.
-- Shows all 5 zones, lock/unlock status by level, current zone highlight,
-- and a Teleport button for any visited zone.
-- Also shows a Rebirth button when the player is at max level.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- Zone display order and colours (mirrors ZoneData without requiring a server require)
local ZONE_ORDER = { "Grassland", "Wetland", "Mushroom", "Volcanic", "Crystal" }
local ZONE_INFO  = {
	Grassland = { displayName = "Grassland",       emoji = "🌿", color = Color3.fromRGB(80, 180, 60),   minLevel =  1 },
	Wetland   = { displayName = "Wetland",          emoji = "💧", color = Color3.fromRGB(40, 120, 180),  minLevel = 10 },
	Mushroom  = { displayName = "Mushroom Hollow",  emoji = "🍄", color = Color3.fromRGB(140, 60, 180),  minLevel = 20 },
	Volcanic  = { displayName = "Volcanic Cavern",  emoji = "🌋", color = Color3.fromRGB(220, 80, 20),   minLevel = 30 },
	Crystal   = { displayName = "Crystal Abyss",    emoji = "🔮", color = Color3.fromRGB(80, 200, 255),  minLevel = 40 },
}

local MAX_LEVEL   = 50
local playerLevel = 1
local playerRebirths = 0
local currentZone = "Grassland"
local visitedZones = { Grassland = true }

-- ─────────────────────────────────────────
-- GUI construction
-- ─────────────────────────────────────────
local screenGui        = Instance.new("ScreenGui")
screenGui.Name         = "ZoneGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent       = player.PlayerGui

-- Toggle button (bottom-left)
local toggleBtn        = Instance.new("TextButton")
toggleBtn.Name         = "ZoneToggle"
toggleBtn.Size         = UDim2.new(0, 110, 0, 38)
toggleBtn.Position     = UDim2.new(0, 14, 1, -54)
toggleBtn.AnchorPoint  = Vector2.new(0, 1)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
toggleBtn.Text         = "🗺 Zones"
toggleBtn.TextColor3   = Color3.new(1, 1, 1)
toggleBtn.Font         = Enum.Font.GothamBold
toggleBtn.TextSize     = 16
toggleBtn.Parent       = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

-- Main panel
local panel            = Instance.new("Frame")
panel.Name             = "ZonePanel"
panel.Size             = UDim2.new(0, 340, 0, 480)
panel.Position         = UDim2.new(0, 14, 1, -100)
panel.AnchorPoint      = Vector2.new(0, 1)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
panel.BackgroundTransparency = 0.1
panel.Visible          = false
panel.Parent           = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

-- Panel title
local title            = Instance.new("TextLabel")
title.Size             = UDim2.new(1, -10, 0, 36)
title.Position         = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Text             = "🗺  Zone Map & Teleport"
title.TextColor3       = Color3.new(1, 1, 1)
title.Font             = Enum.Font.GothamBold
title.TextSize         = 18
title.Parent           = panel

-- Scroll frame for zone rows
local scroll           = Instance.new("ScrollingFrame")
scroll.Size            = UDim2.new(1, -10, 1, -120)
scroll.Position        = UDim2.new(0, 5, 0, 46)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.CanvasSize      = UDim2.new(0, 0, 0, 0)
scroll.Parent          = panel

local list             = Instance.new("UIListLayout")
list.Padding           = UDim.new(0, 6)
list.SortOrder         = Enum.SortOrder.LayoutOrder
list.Parent            = scroll

-- Rebirth section (bottom of panel)
local rebirthFrame     = Instance.new("Frame")
rebirthFrame.Name      = "RebirthFrame"
rebirthFrame.Size      = UDim2.new(1, -10, 0, 64)
rebirthFrame.Position  = UDim2.new(0, 5, 1, -70)
rebirthFrame.BackgroundColor3 = Color3.fromRGB(80, 20, 10)
rebirthFrame.Parent    = panel
Instance.new("UICorner", rebirthFrame).CornerRadius = UDim.new(0, 8)

local rebirthInfo      = Instance.new("TextLabel")
rebirthInfo.Size       = UDim2.new(0.6, 0, 1, 0)
rebirthInfo.Position   = UDim2.new(0, 8, 0, 0)
rebirthInfo.BackgroundTransparency = 1
rebirthInfo.Text       = "♻ Rebirths: 0\n🔥 Lvl MAX reached!"
rebirthInfo.TextColor3 = Color3.fromRGB(255, 180, 60)
rebirthInfo.Font       = Enum.Font.GothamBold
rebirthInfo.TextSize   = 13
rebirthInfo.TextXAlignment = Enum.TextXAlignment.Left
rebirthInfo.Visible    = false
rebirthInfo.Parent     = rebirthFrame

local rebirthBtn       = Instance.new("TextButton")
rebirthBtn.Size        = UDim2.new(0.35, 0, 0.7, 0)
rebirthBtn.Position    = UDim2.new(0.63, 0, 0.15, 0)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 20)
rebirthBtn.Text        = "♻ REBIRTH"
rebirthBtn.TextColor3  = Color3.new(1, 1, 1)
rebirthBtn.Font        = Enum.Font.GothamBold
rebirthBtn.TextSize    = 14
rebirthBtn.Visible     = false
rebirthBtn.Parent      = rebirthFrame
Instance.new("UICorner", rebirthBtn).CornerRadius = UDim.new(0, 6)

-- ─────────────────────────────────────────
-- Zone row builder
-- ─────────────────────────────────────────
local zoneRows = {}

local function buildZoneRow(zoneKey, info, layoutOrder)
	local row          = Instance.new("Frame")
	row.Name           = "Row_" .. zoneKey
	row.Size           = UDim2.new(1, -8, 0, 72)
	row.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
	row.LayoutOrder    = layoutOrder
	row.Parent         = scroll
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	-- Left colour stripe
	local stripe       = Instance.new("Frame")
	stripe.Name        = "Stripe"
	stripe.Size        = UDim2.new(0, 6, 1, 0)
	stripe.BackgroundColor3 = info.color
	stripe.BorderSizePixel = 0
	stripe.Parent      = row
	Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 4)

	-- Zone name + level range
	local nameLabel    = Instance.new("TextLabel")
	nameLabel.Name     = "ZoneName"
	nameLabel.Size     = UDim2.new(0.55, 0, 0.55, 0)
	nameLabel.Position = UDim2.new(0, 14, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text     = info.emoji .. " " .. info.displayName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font     = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent   = row

	local levelLabel   = Instance.new("TextLabel")
	levelLabel.Name    = "LevelRange"
	levelLabel.Size    = UDim2.new(0.55, 0, 0.38, 0)
	levelLabel.Position= UDim2.new(0, 14, 0.55, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text    = "Lvs " .. info.minLevel .. " – " .. (info.minLevel + 9)
	levelLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	levelLabel.Font    = Enum.Font.Gotham
	levelLabel.TextSize = 12
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent  = row

	-- Teleport button
	local tpBtn        = Instance.new("TextButton")
	tpBtn.Name         = "TeleportBtn"
	tpBtn.Size         = UDim2.new(0, 96, 0, 32)
	tpBtn.Position     = UDim2.new(1, -106, 0.5, -16)
	tpBtn.BackgroundColor3 = info.color
	tpBtn.Text         = "Teleport"
	tpBtn.TextColor3   = Color3.new(1, 1, 1)
	tpBtn.Font         = Enum.Font.GothamBold
	tpBtn.TextSize     = 13
	tpBtn.AutoButtonColor = true
	tpBtn.Parent       = row
	Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

	tpBtn.MouseButton1Click:Connect(function()
		Remotes:FindFirstChild("ZoneTeleport"):FireServer(zoneKey)
	end)

	zoneRows[zoneKey] = { row = row, tpBtn = tpBtn, nameLabel = nameLabel, levelLabel = levelLabel, stripe = stripe }
end

for i, key in ipairs(ZONE_ORDER) do
	buildZoneRow(key, ZONE_INFO[key], i)
end

-- Auto-size canvas
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 10)
end)

-- ─────────────────────────────────────────
-- Update row states based on player data
-- ─────────────────────────────────────────
local function refreshRows()
	for _, key in ipairs(ZONE_ORDER) do
		local info    = ZONE_INFO[key]
		local rowData = zoneRows[key]
		if not rowData then continue end

		local isCurrentZone = (key == currentZone)
		local isVisited     = visitedZones[key] == true
		local isLocked      = playerLevel < info.minLevel and not isVisited

		-- Highlight current zone
		rowData.row.BackgroundColor3 = isCurrentZone
			and Color3.fromRGB(40, 60, 100) or Color3.fromRGB(25, 25, 45)

		-- Stripe locked = grey
		rowData.stripe.BackgroundColor3 = isLocked and Color3.fromRGB(80, 80, 80) or info.color

		-- Button state
		if isCurrentZone then
			rowData.tpBtn.Text = "Here ✓"
			rowData.tpBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 40)
			rowData.tpBtn.Active = false
		elseif isLocked then
			rowData.tpBtn.Text = "🔒 Lv." .. info.minLevel
			rowData.tpBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			rowData.tpBtn.Active = false
		else
			rowData.tpBtn.Text = "Teleport"
			rowData.tpBtn.BackgroundColor3 = info.color
			rowData.tpBtn.Active = true
		end

		-- Dim text for locked zones
		rowData.nameLabel.TextColor3 = isLocked
			and Color3.fromRGB(120, 120, 120) or Color3.new(1, 1, 1)
		rowData.levelLabel.TextColor3 = isLocked
			and Color3.fromRGB(90, 90, 90) or Color3.fromRGB(180, 180, 200)
	end

	-- Rebirth section
	local atMax = (playerLevel >= MAX_LEVEL)
	rebirthFrame.Visible     = atMax
	rebirthInfo.Visible      = atMax
	rebirthBtn.Visible       = atMax
	if atMax then
		rebirthInfo.Text = "♻ Rebirths: " .. playerRebirths .. "\n🔥 Max Level Reached!"
	end
end

-- ─────────────────────────────────────────
-- Panel toggle
-- ─────────────────────────────────────────
local panelOpen = false
toggleBtn.MouseButton1Click:Connect(function()
	panelOpen = not panelOpen
	panel.Visible = panelOpen
	if panelOpen then refreshRows() end
end)

-- ─────────────────────────────────────────
-- Remotes
-- ─────────────────────────────────────────
Remotes:FindFirstChild("StatsChanged").OnClientEvent:Connect(function(data)
	playerLevel    = data.level    or playerLevel
	playerRebirths = data.rebirths or playerRebirths
	currentZone    = data.currentZone or currentZone
	visitedZones   = data.visitedZones or visitedZones
	if panelOpen then refreshRows() end
end)

Remotes:FindFirstChild("VisitedZonesUpdate").OnClientEvent:Connect(function(zones)
	visitedZones = zones
	if panelOpen then refreshRows() end
end)

Remotes:FindFirstChild("ZoneChanged").OnClientEvent:Connect(function(data)
	if data.locked then return end
	currentZone = data.zone or currentZone
	if panelOpen then refreshRows() end
end)

Remotes:FindFirstChild("LevelUp").OnClientEvent:Connect(function(data)
	playerLevel = data.level or playerLevel
	if panelOpen then refreshRows() end
end)

Remotes:FindFirstChild("RebirthComplete").OnClientEvent:Connect(function(data)
	playerRebirths = data.rebirths or playerRebirths
	playerLevel    = 1
	currentZone    = "Grassland"
	visitedZones   = { Grassland = true }
	if panelOpen then refreshRows() end
end)

rebirthBtn.MouseButton1Click:Connect(function()
	rebirthBtn.Active = false
	rebirthBtn.Text   = "Processing..."
	Remotes:FindFirstChild("RebirthRequest"):FireServer()
	task.delay(3, function() rebirthBtn.Active = true rebirthBtn.Text = "♻ REBIRTH" end)
end)
