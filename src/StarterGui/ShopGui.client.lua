-- ShopGui.client.lua
-- Shop with two tabs: Crystal Packages (Robux) and Egg Store (Crystals).
-- Also shows Game Pass purchase options.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local GameConfig  = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GamePasses  = require(ReplicatedStorage:WaitForChild("GamePasses"))
local PetData     = require(ReplicatedStorage:WaitForChild("PetData"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C         = GameConfig.UIColors

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local localCrystals = 0

-- ─────────────────────────────────────────
-- Build ScreenGui
-- ─────────────────────────────────────────
local screenGui               = Instance.new("ScreenGui")
screenGui.Name                = "ShopGui"
screenGui.ResetOnSpawn        = false
screenGui.ZIndexBehavior      = Enum.ZIndexBehavior.Sibling
screenGui.Enabled             = false
screenGui.Parent              = playerGui

-- Backdrop
local backdrop                = Instance.new("Frame")
backdrop.Size                 = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3     = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel      = 0
backdrop.Parent               = screenGui

-- Main panel
local panel                   = Instance.new("Frame")
panel.Size                    = UDim2.new(0, 720, 0, 520)
panel.Position                = UDim2.new(0.5, -360, 0.5, -260)
panel.BackgroundColor3        = C.Background
panel.BorderSizePixel         = 0
panel.Parent                  = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", panel).Color        = C.Accent

-- Title bar
local titleBar                = Instance.new("Frame")
titleBar.Size                 = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3     = C.Panel
titleBar.BorderSizePixel      = 0
titleBar.Parent               = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleLbl                = Instance.new("TextLabel")
titleLbl.Size                 = UDim2.new(1, -60, 1, 0)
titleLbl.Position             = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                 = "💎 SHOP"
titleLbl.TextColor3           = C.Gold
titleLbl.Font                 = Enum.Font.GothamBold
titleLbl.TextSize             = 22
titleLbl.TextXAlignment       = Enum.TextXAlignment.Left
titleLbl.Parent               = titleBar

-- Crystal balance display
local crystalLbl              = Instance.new("TextLabel")
crystalLbl.Name               = "CrystalBalance"
crystalLbl.Size               = UDim2.new(0, 160, 1, 0)
crystalLbl.Position           = UDim2.new(1, -218, 0, 0)
crystalLbl.BackgroundTransparency = 1
crystalLbl.Text               = "💎 0"
crystalLbl.TextColor3         = C.CrystalColor
crystalLbl.Font               = Enum.Font.GothamBold
crystalLbl.TextSize           = 18
crystalLbl.Parent             = titleBar

-- Close button
local closeBtn                = Instance.new("TextButton")
closeBtn.Size                 = UDim2.new(0, 36, 0, 36)
closeBtn.Position             = UDim2.new(1, -46, 0, 6)
closeBtn.BackgroundColor3     = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel      = 0
closeBtn.Text                 = "✕"
closeBtn.TextColor3           = Color3.new(1, 1, 1)
closeBtn.Font                 = Enum.Font.GothamBold
closeBtn.TextSize             = 18
closeBtn.Parent               = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- ─────────────────────────────────────────
-- Tabs
-- ─────────────────────────────────────────
local tabNames  = { "💎 Crystals", "🥚 Eggs", "⭐ Game Passes" }
local tabFrames = {}
local tabBtns   = {}

local tabBar    = Instance.new("Frame")
tabBar.Size     = UDim2.new(1, -20, 0, 36)
tabBar.Position = UDim2.new(0, 10, 0, 52)
tabBar.BackgroundTransparency = 1
tabBar.Parent   = panel

local content   = Instance.new("Frame")
content.Size    = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 96)
content.BackgroundTransparency = 1
content.Parent  = panel

local tabWidth = (1 / #tabNames)
for i, name in ipairs(tabNames) do
	local btn              = Instance.new("TextButton")
	btn.Size               = UDim2.new(tabWidth, -4, 1, 0)
	btn.Position           = UDim2.new(tabWidth * (i - 1), 2, 0, 0)
	btn.BackgroundColor3   = C.Panel
	btn.BorderSizePixel    = 0
	btn.Text               = name
	btn.TextColor3         = C.TextSecondary
	btn.Font               = Enum.Font.GothamBold
	btn.TextSize           = 14
	btn.Parent             = tabBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	tabBtns[i] = btn

	local frame            = Instance.new("ScrollingFrame")
	frame.Size             = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel  = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = C.Accent
	frame.Visible          = false
	frame.Parent           = content
	Instance.new("UIListLayout", frame).Padding = UDim.new(0, 8)
	tabFrames[i] = frame
end

local activeTab = 1
local function switchTab(idx)
	activeTab = idx
	for i, btn in ipairs(tabBtns) do
		btn.BackgroundColor3 = (i == idx) and C.Accent or C.Panel
		btn.TextColor3       = (i == idx) and Color3.new(1,1,1) or C.TextSecondary
		tabFrames[i].Visible = (i == idx)
	end
end

for i, btn in ipairs(tabBtns) do
	btn.MouseButton1Click:Connect(function() switchTab(i) end)
end

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────
local function card(parent, height)
	local f                    = Instance.new("Frame")
	f.Size                     = UDim2.new(1, -8, 0, height)
	f.BackgroundColor3         = C.Panel
	f.BorderSizePixel          = 0
	f.Parent                   = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	return f
end

local function lbl(text, size, color, font, parent, pos, sz)
	local l                    = Instance.new("TextLabel")
	l.Text                     = text
	l.TextSize                 = size
	l.TextColor3               = color
	l.Font                     = font or Enum.Font.Gotham
	l.BackgroundTransparency   = 1
	l.Parent                   = parent
	l.Position                 = pos  or UDim2.new(0, 8, 0, 4)
	l.Size                     = sz   or UDim2.new(1, -16, 0, 22)
	l.TextXAlignment           = Enum.TextXAlignment.Left
	return l
end

local function buyBtn(text, color, parent, pos, sz)
	local b                    = Instance.new("TextButton")
	b.Size                     = sz  or UDim2.new(0, 120, 0, 32)
	b.Position                 = pos or UDim2.new(1, -130, 0.5, -16)
	b.BackgroundColor3         = color
	b.BorderSizePixel          = 0
	b.Text                     = text
	b.TextColor3               = Color3.new(1, 1, 1)
	b.Font                     = Enum.Font.GothamBold
	b.TextSize                 = 14
	b.Parent                   = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

-- ─────────────────────────────────────────
-- Tab 1: Crystal Packages
-- ─────────────────────────────────────────
for _, pkg in ipairs(GamePasses.CrystalProducts) do
	local c = card(tabFrames[1], 64)

	lbl("💎 " .. pkg.label,   18, C.CrystalColor, Enum.Font.GothamBold, c,
		UDim2.new(0, 12, 0, 8), UDim2.new(0.6, 0, 0, 24))
	lbl("Best value!",         12, C.TextSecondary, Enum.Font.Gotham, c,
		UDim2.new(0, 12, 0, 34), UDim2.new(0.6, 0, 0, 18))

	local btn = buyBtn("R$ " .. pkg.robux, Color3.fromRGB(0, 180, 100), c)
	btn.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, pkg.productId)
	end)
end

-- ─────────────────────────────────────────
-- Tab 2: Egg Store
-- ─────────────────────────────────────────
for _, eggKey in ipairs(PetData.EggOrder) do
	local egg = PetData.Eggs[eggKey]
	local c   = card(tabFrames[2], 80)

	lbl(egg.emoji .. "  " .. egg.displayName, 18, Color3.new(1,1,1), Enum.Font.GothamBold, c,
		UDim2.new(0, 12, 0, 6), UDim2.new(0.65, 0, 0, 26))
	lbl(egg.description, 12, C.TextSecondary, Enum.Font.Gotham, c,
		UDim2.new(0, 12, 0, 32), UDim2.new(0.65, 0, 0, 18))

	-- Rarity chances mini-display
	local chanceStr = ""
	for _, rarity in ipairs(PetData.RarityOrder) do
		local w = egg.chances[rarity]
		if w and w > 0 then
			chanceStr = chanceStr .. rarity .. " " .. w .. "%  "
		end
	end
	lbl(chanceStr, 11, C.TextSecondary, Enum.Font.Gotham, c,
		UDim2.new(0, 12, 0, 54), UDim2.new(0.65, 0, 0, 18))

	local costBtn = buyBtn("💎 " .. egg.crystalCost, C.Accent, c,
		UDim2.new(1, -140, 0.5, -18), UDim2.new(0, 130, 0, 36))
	costBtn.MouseButton1Click:Connect(function()
		Remotes:FindFirstChild("PurchaseEgg"):FireServer(eggKey)
	end)
end

-- ─────────────────────────────────────────
-- Tab 3: Game Passes
-- ─────────────────────────────────────────
local passInfo = {
	{
		key   = "VIP",
		name  = "⭐ VIP Pass",
		desc  = "+50% Crystals  •  +20% XP  •  +3 Speed",
		color = C.Gold,
	},
	{
		key   = "DoubleXP",
		name  = "🔥 Double XP",
		desc  = "All XP gains permanently doubled.",
		color = Color3.fromRGB(80, 180, 255),
	},
	{
		key   = "DoubleDmg",
		name  = "⚔ Double Damage",
		desc  = "All damage permanently doubled.",
		color = Color3.fromRGB(220, 80, 80),
	},
}

local ownedPasses = {}

for _, info in ipairs(passInfo) do
	local c = card(tabFrames[3], 74)

	lbl(info.name, 18, info.color, Enum.Font.GothamBold, c,
		UDim2.new(0, 12, 0, 8), UDim2.new(0.65, 0, 0, 26))
	lbl(info.desc, 13, C.TextSecondary, Enum.Font.Gotham, c,
		UDim2.new(0, 12, 0, 36), UDim2.new(0.65, 0, 0, 30))

	local passBtn = buyBtn("Buy Pass", info.color, c,
		UDim2.new(1, -140, 0.5, -18), UDim2.new(0, 130, 0, 36))

	local passKey = info.key   -- capture
	passBtn.MouseButton1Click:Connect(function()
		if ownedPasses[passKey] then
			passBtn.Text = "✓ Owned"
		else
			Remotes:FindFirstChild("PromptGamePass"):FireServer(passKey)
		end
	end)

	-- Store reference for owned-state update
	info.btn = passBtn
end

-- ─────────────────────────────────────────
-- React to server events
-- ─────────────────────────────────────────
Remotes:FindFirstChild("CrystalsChanged").OnClientEvent:Connect(function(amount)
	localCrystals = amount
	crystalLbl.Text = "💎 " .. amount
end)

Remotes:FindFirstChild("PassesChanged").OnClientEvent:Connect(function(passes)
	ownedPasses = passes
	for _, info in ipairs(passInfo) do
		if passes[info.key] and info.btn then
			info.btn.Text             = "✓ Owned"
			info.btn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
		end
	end
end)

-- ─────────────────────────────────────────
-- Open shop button (bottom of screen, E key or via HUD button)
-- ─────────────────────────────────────────
local openBtn                 = Instance.new("TextButton")
openBtn.Name                  = "ShopOpenBtn"
openBtn.Size                  = UDim2.new(0, 110, 0, 38)
openBtn.Position              = UDim2.new(1, -126, 1, -52)
openBtn.BackgroundColor3      = C.Accent
openBtn.BorderSizePixel       = 0
openBtn.Text                  = "🛒 SHOP"
openBtn.TextColor3            = Color3.new(1, 1, 1)
openBtn.Font                  = Enum.Font.GothamBold
openBtn.TextSize              = 16
openBtn.Parent                = playerGui:WaitForChild("HUD") or screenGui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)

openBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = not screenGui.Enabled
	if screenGui.Enabled then switchTab(1) end
end)

-- Expose toggle function for HUD hotkey
_G.ToggleShop = function()
	screenGui.Enabled = not screenGui.Enabled
	if screenGui.Enabled then switchTab(1) end
end

switchTab(1)
print("[InsectEvo] ShopGui initialized.")
