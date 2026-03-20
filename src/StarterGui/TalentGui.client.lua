-- TalentGui.client.lua
-- Talent tree UI: persistent nodes bought with crystals.
-- Toggle button sits next to Crystals display (top-right area).
-- Two tabs: Universal and the current insect type.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TalentData = require(ReplicatedStorage:WaitForChild("TalentData"))
local player     = Players.LocalPlayer
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- State
-- ─────────────────────────────────────────
local purchasedTalents = {}   -- talentId → true
local currentInsect    = nil  -- insect type string (from StatsChanged)
local crystalBalance   = 0

-- ─────────────────────────────────────────
-- ScreenGui
-- ─────────────────────────────────────────
local screenGui            = Instance.new("ScreenGui")
screenGui.Name             = "TalentGui"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.Parent           = player:WaitForChild("PlayerGui")

-- Toggle button (top-left, below info panel)
local toggleBtn            = Instance.new("TextButton")
toggleBtn.Name             = "TalentToggle"
toggleBtn.Size             = UDim2.new(0, 120, 0, 30)
toggleBtn.Position         = UDim2.new(0, 14, 0, 64)
toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 90)
toggleBtn.Text             = "🌟 Talents"
toggleBtn.TextColor3       = Color3.new(1, 1, 1)
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 13
toggleBtn.Parent           = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", toggleBtn).Color        = Color3.fromRGB(180, 80, 255)

-- ─────────────────────────────────────────
-- Main panel
-- ─────────────────────────────────────────
local panel              = Instance.new("Frame")
panel.Name               = "TalentPanel"
panel.Size               = UDim2.new(0, 480, 0, 520)
panel.Position           = UDim2.new(0, 14, 0, 100)
panel.BackgroundColor3   = Color3.fromRGB(12, 8, 22)
panel.BackgroundTransparency = 0.06
panel.Visible            = false
panel.Parent             = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(140, 60, 220)
panelStroke.Thickness = 2

-- Title bar
local titleBar           = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 10, 70)
titleBar.BorderSizePixel = 0
titleBar.Parent          = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleLbl           = Instance.new("TextLabel")
titleLbl.Size            = UDim2.new(1, -60, 1, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text            = "🌟  Talent Tree"
titleLbl.TextColor3      = Color3.fromRGB(200, 120, 255)
titleLbl.Font            = Enum.Font.GothamBold
titleLbl.TextSize        = 18
titleLbl.Parent          = titleBar

local crystalLbl         = Instance.new("TextLabel")
crystalLbl.Name          = "CrystalBalance"
crystalLbl.Size          = UDim2.new(0, 55, 1, 0)
crystalLbl.Position      = UDim2.new(1, -58, 0, 0)
crystalLbl.BackgroundTransparency = 1
crystalLbl.Text          = "💎0"
crystalLbl.TextColor3    = Color3.fromRGB(100, 220, 255)
crystalLbl.Font          = Enum.Font.GothamBold
crystalLbl.TextSize      = 13
crystalLbl.Parent        = titleBar

-- Tab row
local tabRow             = Instance.new("Frame")
tabRow.Size              = UDim2.new(1, -16, 0, 34)
tabRow.Position          = UDim2.new(0, 8, 0, 48)
tabRow.BackgroundTransparency = 1
tabRow.Parent            = panel

local tabLayout          = Instance.new("UIListLayout")
tabLayout.FillDirection  = Enum.FillDirection.Horizontal
tabLayout.Padding        = UDim.new(0, 6)
tabLayout.SortOrder      = Enum.SortOrder.LayoutOrder
tabLayout.Parent         = tabRow

-- Scrolling content area
local scroll             = Instance.new("ScrollingFrame")
scroll.Size              = UDim2.new(1, -12, 1, -96)
scroll.Position          = UDim2.new(0, 6, 0, 88)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
scroll.Parent            = panel

local contentLayout      = Instance.new("UIListLayout")
contentLayout.Padding    = UDim.new(0, 6)
contentLayout.SortOrder  = Enum.SortOrder.LayoutOrder
contentLayout.Parent     = scroll

-- ─────────────────────────────────────────
-- Helper: make tab button
-- ─────────────────────────────────────────
local function makeTab(label, order)
	local btn            = Instance.new("TextButton")
	btn.Size             = UDim2.new(0, 120, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(30, 10, 55)
	btn.Text             = label
	btn.TextColor3       = Color3.fromRGB(180, 180, 200)
	btn.Font             = Enum.Font.GothamBold
	btn.TextSize         = 13
	btn.LayoutOrder      = order
	btn.Parent           = tabRow
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local tabUniversal = makeTab("Universal", 1)
local tabInsect    = makeTab("Companion", 2)

-- ─────────────────────────────────────────
-- Helper: build a talent node card
-- ─────────────────────────────────────────
local function clearContent()
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
end

local function buildNodeCard(node, layoutOrder)
	local isPurchased = purchasedTalents[node.id] == true
	local canBuy      = not isPurchased and TalentData.CanPurchase(node.id, purchasedTalents)
	local affordable  = canBuy and (crystalBalance >= node.cost)

	local card             = Instance.new("Frame")
	card.Size              = UDim2.new(1, -8, 0, 72)
	card.BackgroundColor3  = isPurchased
		and Color3.fromRGB(20, 50, 20)
		or  Color3.fromRGB(22, 12, 38)
	card.LayoutOrder       = layoutOrder
	card.Parent            = scroll
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = isPurchased
		and Color3.fromRGB(60, 180, 60)
		or  Color3.fromRGB(100, 60, 160)
	stroke.Thickness = 1

	-- Icon
	local icon             = Instance.new("TextLabel")
	icon.Size              = UDim2.new(0, 50, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text              = node.icon or "✦"
	icon.TextColor3        = isPurchased and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(200, 120, 255)
	icon.Font              = Enum.Font.GothamBold
	icon.TextSize          = 28
	icon.Parent            = card

	-- Name
	local nameL            = Instance.new("TextLabel")
	nameL.Size             = UDim2.new(1, -130, 0, 26)
	nameL.Position         = UDim2.new(0, 52, 0, 6)
	nameL.BackgroundTransparency = 1
	nameL.Text             = node.name
	nameL.TextColor3       = isPurchased and Color3.fromRGB(120, 255, 120) or Color3.new(1, 1, 1)
	nameL.Font             = Enum.Font.GothamBold
	nameL.TextSize         = 14
	nameL.TextXAlignment   = Enum.TextXAlignment.Left
	nameL.Parent           = card

	-- Description
	local desc             = Instance.new("TextLabel")
	desc.Size              = UDim2.new(1, -130, 0, 20)
	desc.Position          = UDim2.new(0, 52, 0, 30)
	desc.BackgroundTransparency = 1
	desc.Text              = node.description
	desc.TextColor3        = Color3.fromRGB(170, 170, 200)
	desc.Font              = Enum.Font.Gotham
	desc.TextSize          = 12
	desc.TextXAlignment    = Enum.TextXAlignment.Left
	desc.Parent            = card

	-- Requirement note
	if node.requires and not purchasedTalents[node.requires] then
		local req      = TalentData.Nodes[node.requires]
		local reqName  = req and req.name or node.requires
		local reqL     = Instance.new("TextLabel")
		reqL.Size      = UDim2.new(1, -130, 0, 16)
		reqL.Position  = UDim2.new(0, 52, 0, 50)
		reqL.BackgroundTransparency = 1
		reqL.Text      = "Requires: " .. reqName
		reqL.TextColor3 = Color3.fromRGB(220, 120, 60)
		reqL.Font      = Enum.Font.Gotham
		reqL.TextSize  = 11
		reqL.TextXAlignment = Enum.TextXAlignment.Left
		reqL.Parent    = card
	end

	-- Buy / Owned button
	local btnW = 70
	local btn           = Instance.new("TextButton")
	btn.Size            = UDim2.new(0, btnW, 0, 36)
	btn.Position        = UDim2.new(1, -(btnW + 6), 0.5, -18)
	btn.BackgroundColor3 = isPurchased
		and Color3.fromRGB(30, 80, 30)
		or (affordable and Color3.fromRGB(80, 30, 130) or Color3.fromRGB(50, 50, 60))
	btn.Text            = isPurchased
		and "✓ Owned"
		or ("💎 " .. node.cost)
	btn.TextColor3      = isPurchased and Color3.fromRGB(100, 255, 100)
		or (affordable and Color3.new(1,1,1) or Color3.fromRGB(130,130,130))
	btn.Font            = Enum.Font.GothamBold
	btn.TextSize        = 13
	btn.AutoButtonColor = affordable and not isPurchased
	btn.Parent          = card
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	if not isPurchased and canBuy and affordable then
		btn.MouseButton1Click:Connect(function()
			Remotes:FindFirstChild("TalentPurchase"):FireServer(node.id)
		end)
	end

	return card
end

-- ─────────────────────────────────────────
-- Populate the scroll with a list of node IDs
-- ─────────────────────────────────────────
local currentTab = "Universal"

local function refreshContent()
	clearContent()

	local ids
	if currentTab == "Universal" then
		ids = TalentData.UniversalOrder
	else
		local insect = currentInsect or "Ant"
		ids = TalentData.InsectOrder[insect] or {}
	end

	for i, id in ipairs(ids) do
		local node = TalentData.Nodes[id]
		if node then
			buildNodeCard(node, i)
		end
	end

	-- Resize canvas
	local count = 0
	for _, c in ipairs(scroll:GetChildren()) do
		if not c:IsA("UIListLayout") then count = count + 1 end
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, count * 78 + 6)
end

-- ─────────────────────────────────────────
-- Tab switching
-- ─────────────────────────────────────────
local function setTab(tab)
	currentTab = tab
	tabUniversal.BackgroundColor3 = (tab == "Universal")
		and Color3.fromRGB(70, 20, 120)
		or  Color3.fromRGB(30, 10, 55)
	tabInsect.BackgroundColor3 = (tab == "Insect")
		and Color3.fromRGB(70, 20, 120)
		or  Color3.fromRGB(30, 10, 55)
	tabUniversal.TextColor3 = (tab == "Universal")
		and Color3.fromRGB(220, 140, 255)
		or  Color3.fromRGB(180, 180, 200)
	tabInsect.TextColor3 = (tab == "Insect")
		and Color3.fromRGB(220, 140, 255)
		or  Color3.fromRGB(180, 180, 200)
	if panel.Visible then
		refreshContent()
	end
end

tabUniversal.MouseButton1Click:Connect(function() setTab("Universal") end)
tabInsect.MouseButton1Click:Connect(function() setTab("Insect") end)

setTab("Universal")

-- ─────────────────────────────────────────
-- Panel toggle
-- ─────────────────────────────────────────
local isOpen = false
toggleBtn.MouseButton1Click:Connect(function()
	isOpen = not isOpen
	panel.Visible = isOpen
	if isOpen then refreshContent() end
end)

-- ─────────────────────────────────────────
-- Remote listeners
-- ─────────────────────────────────────────

-- Talent state from server (on load + after purchase)
Remotes:WaitForChild("TalentSync").OnClientEvent:Connect(function(talents)
	purchasedTalents = talents or {}
	crystalLbl.Text  = "💎" .. (crystalBalance or 0)
	if isOpen then refreshContent() end
end)

-- Crystal balance updates
Remotes:WaitForChild("CrystalsChanged").OnClientEvent:Connect(function(amount)
	crystalBalance = amount or 0
	crystalLbl.Text = "💎" .. crystalBalance
	if isOpen then refreshContent() end
end)

-- Current insect type from stats sync
Remotes:WaitForChild("StatsChanged").OnClientEvent:Connect(function(data)
	if data and data.insectType then
		local changed = currentInsect ~= data.insectType
		currentInsect = data.insectType
		-- Update companion tab label
		tabInsect.Text = (data.insectType or "Companion")
		if isOpen and changed then refreshContent() end
	end
end)
