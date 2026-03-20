-- LeaderboardGui.client.lua
-- Displays a live top-10 leaderboard in the top-right corner.
-- Shows player name, level, rebirths, and score.
-- Toggles open/closed with a button. Refreshes on LeaderboardData events.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- GUI setup
-- ─────────────────────────────────────────
local screenGui          = Instance.new("ScreenGui")
screenGui.Name           = "LeaderboardGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = Players.LocalPlayer.PlayerGui

-- Toggle button — top right, rightmost button
local toggleBtn          = Instance.new("TextButton")
toggleBtn.Name           = "LBToggle"
toggleBtn.Size           = UDim2.new(0, 118, 0, 38)
toggleBtn.Position       = UDim2.new(1, -128, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 70)
toggleBtn.Text           = "🏆 Leaderboard"
toggleBtn.TextColor3     = Color3.new(1, 1, 1)
toggleBtn.Font           = Enum.Font.GothamBold
toggleBtn.TextSize       = 14
toggleBtn.Parent         = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", toggleBtn).Color        = Color3.fromRGB(255, 210, 60)

-- Main panel (drops below the button)
local panel              = Instance.new("Frame")
panel.Name               = "LBPanel"
panel.Size               = UDim2.new(0, 320, 0, 400)
panel.Position           = UDim2.new(1, -338, 0, 54)
panel.BackgroundColor3   = Color3.fromRGB(10, 10, 24)
panel.BackgroundTransparency = 0.08
panel.Visible            = false
panel.Parent             = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

-- Panel stroke
local stroke             = Instance.new("UIStroke")
stroke.Color             = Color3.fromRGB(100, 100, 200)
stroke.Thickness         = 2
stroke.Parent            = panel

-- Title
local titleBar           = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 80)
titleBar.BorderSizePixel = 0
titleBar.Parent          = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleLbl           = Instance.new("TextLabel")
titleLbl.Size            = UDim2.new(1, 0, 1, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text            = "🏆  Top Players"
titleLbl.TextColor3      = Color3.fromRGB(255, 210, 60)
titleLbl.Font            = Enum.Font.GothamBold
titleLbl.TextSize        = 20
titleLbl.Parent          = titleBar

-- Column headers
local headers            = Instance.new("Frame")
headers.Size             = UDim2.new(1, -10, 0, 26)
headers.Position         = UDim2.new(0, 5, 0, 46)
headers.BackgroundTransparency = 1
headers.Parent           = panel

local function makeHeaderLabel(text, xAnchor, width)
	local lbl = Instance.new("TextLabel")
	lbl.Size  = UDim2.new(width, 0, 1, 0)
	lbl.Position = UDim2.new(xAnchor, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text  = text
	lbl.TextColor3 = Color3.fromRGB(160, 160, 200)
	lbl.Font  = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = headers
	return lbl
end

makeHeaderLabel("#",        0.00, 0.08)
makeHeaderLabel("Player",   0.08, 0.40)
makeHeaderLabel("Level",    0.50, 0.22)
makeHeaderLabel("Rebirths", 0.73, 0.27)

-- Divider
local divider            = Instance.new("Frame")
divider.Size             = UDim2.new(1, -10, 0, 2)
divider.Position         = UDim2.new(0, 5, 0, 73)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
divider.BorderSizePixel  = 0
divider.Parent           = panel

-- Scrolling list
local scroll             = Instance.new("ScrollingFrame")
scroll.Size              = UDim2.new(1, -10, 1, -82)
scroll.Position          = UDim2.new(0, 5, 0, 78)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 3
scroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
scroll.Parent            = panel

local listLayout         = Instance.new("UIListLayout")
listLayout.Padding       = UDim.new(0, 3)
listLayout.SortOrder     = Enum.SortOrder.LayoutOrder
listLayout.Parent        = scroll

-- ─────────────────────────────────────────
-- Row builder
-- ─────────────────────────────────────────
local localPlayer = Players.LocalPlayer

local rowPool     = {}   -- reuse row frames

local function getOrCreateRow(index)
	local row = rowPool[index]
	if not row then
		row                   = Instance.new("Frame")
		row.Size              = UDim2.new(1, -4, 0, 34)
		row.BackgroundColor3  = Color3.fromRGB(20, 20, 45)
		row.LayoutOrder       = index
		row.Parent            = scroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		-- Rank
		local rank            = Instance.new("TextLabel")
		rank.Name             = "Rank"
		rank.Size             = UDim2.new(0.08, 0, 1, 0)
		rank.BackgroundTransparency = 1
		rank.TextColor3       = Color3.fromRGB(200, 200, 255)
		rank.Font             = Enum.Font.GothamBold
		rank.TextSize         = 14
		rank.Parent           = row

		-- Name
		local name            = Instance.new("TextLabel")
		name.Name             = "PlayerName"
		name.Size             = UDim2.new(0.40, 0, 1, 0)
		name.Position         = UDim2.new(0.08, 0, 0, 0)
		name.BackgroundTransparency = 1
		name.TextColor3       = Color3.new(1, 1, 1)
		name.Font             = Enum.Font.Gotham
		name.TextSize         = 13
		name.TextXAlignment   = Enum.TextXAlignment.Left
		name.Parent           = row

		-- Level
		local lvl             = Instance.new("TextLabel")
		lvl.Name              = "Level"
		lvl.Size              = UDim2.new(0.22, 0, 1, 0)
		lvl.Position          = UDim2.new(0.50, 0, 0, 0)
		lvl.BackgroundTransparency = 1
		lvl.TextColor3        = Color3.fromRGB(100, 220, 100)
		lvl.Font              = Enum.Font.GothamBold
		lvl.TextSize          = 13
		lvl.Parent            = row

		-- Rebirths
		local reb             = Instance.new("TextLabel")
		reb.Name              = "Rebirths"
		reb.Size              = UDim2.new(0.27, 0, 1, 0)
		reb.Position          = UDim2.new(0.73, 0, 0, 0)
		reb.BackgroundTransparency = 1
		reb.TextColor3        = Color3.fromRGB(255, 160, 40)
		reb.Font              = Enum.Font.GothamBold
		reb.TextSize          = 13
		reb.Parent            = row

		rowPool[index] = row
	end
	return row
end

local rankColors = {
	Color3.fromRGB(255, 210, 40),   -- 1st gold
	Color3.fromRGB(200, 200, 200),  -- 2nd silver
	Color3.fromRGB(210, 130, 60),   -- 3rd bronze
}

-- ─────────────────────────────────────────
-- Update leaderboard display
-- ─────────────────────────────────────────
local function populateBoard(entries)
	-- Show rows
	for i, entry in ipairs(entries) do
		local row = getOrCreateRow(i)
		row.Visible = true

		local isMe = (entry.name == localPlayer.Name)
		row.BackgroundColor3 = isMe
			and Color3.fromRGB(30, 50, 80)
			or  Color3.fromRGB(20, 20, 45)

		row:FindFirstChild("Rank").Text       = "#" .. i
		row:FindFirstChild("Rank").TextColor3 = rankColors[i] or Color3.fromRGB(180, 180, 180)
		row:FindFirstChild("PlayerName").Text = (isMe and "★ " or "") .. entry.name
		row:FindFirstChild("PlayerName").TextColor3 = isMe
			and Color3.fromRGB(255, 255, 100) or Color3.new(1, 1, 1)
		row:FindFirstChild("Level").Text    = "Lv." .. (entry.level or 1)
		row:FindFirstChild("Rebirths").Text = "♻" .. (entry.rebirths or 0)
	end

	-- Hide unused rows
	for i = #entries + 1, #rowPool do
		if rowPool[i] then rowPool[i].Visible = false end
	end

	-- Update canvas size
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
	end)
	scroll.CanvasSize = UDim2.new(0, 0, 0, #entries * 37 + 6)
end

-- ─────────────────────────────────────────
-- Panel toggle + remote listener
-- ─────────────────────────────────────────
local isOpen = false
toggleBtn.MouseButton1Click:Connect(function()
	isOpen  = not isOpen
	panel.Visible = isOpen
end)

Remotes:FindFirstChild("LeaderboardData").OnClientEvent:Connect(function(entries)
	if entries then
		populateBoard(entries)
	end
end)
