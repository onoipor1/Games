-- PetGui.client.lua
-- Pet inventory screen: shows owned pets, lets players equip one,
-- displays active pet buffs in a HUD corner widget.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PetData    = require(ReplicatedStorage:WaitForChild("PetData"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C         = GameConfig.UIColors

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Local state
local localPets     = {}
local localEquipped = nil   -- 1-based index or nil

-- ─────────────────────────────────────────
-- Build ScreenGui
-- ─────────────────────────────────────────
local screenGui           = Instance.new("ScreenGui")
screenGui.Name            = "PetGui"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Enabled         = false
screenGui.Parent          = playerGui

-- Backdrop
local backdrop            = Instance.new("Frame")
backdrop.Size             = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel  = 0
backdrop.Parent           = screenGui

-- Main panel
local panel               = Instance.new("Frame")
panel.Size                = UDim2.new(0, 660, 0, 500)
panel.Position            = UDim2.new(0.5, -330, 0.5, -250)
panel.BackgroundColor3    = C.Background
panel.BorderSizePixel     = 0
panel.Parent              = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", panel).Color        = C.Accent

-- Title bar
local titleBar            = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = C.Panel
titleBar.BorderSizePixel  = 0
titleBar.Parent           = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleLbl            = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(0.6, 0, 1, 0)
titleLbl.Position         = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = "🐾 MY PETS"
titleLbl.TextColor3       = C.Accent
titleLbl.Font             = Enum.Font.GothamBold
titleLbl.TextSize         = 22
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
titleLbl.Parent           = titleBar

local petCountLbl         = Instance.new("TextLabel")
petCountLbl.Size          = UDim2.new(0, 120, 1, 0)
petCountLbl.Position      = UDim2.new(0.6, 0, 0, 0)
petCountLbl.BackgroundTransparency = 1
petCountLbl.Text          = "0 / 50 pets"
petCountLbl.TextColor3    = C.TextSecondary
petCountLbl.Font          = Enum.Font.Gotham
petCountLbl.TextSize      = 14
petCountLbl.Parent        = titleBar

local closeBtn            = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 36, 0, 36)
closeBtn.Position         = UDim2.new(1, -46, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 18
closeBtn.Parent           = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

-- ─────────────────────────────────────────
-- Left: Pet grid
-- ─────────────────────────────────────────
local gridFrame           = Instance.new("ScrollingFrame")
gridFrame.Size            = UDim2.new(0, 390, 1, -56)
gridFrame.Position        = UDim2.new(0, 10, 0, 54)
gridFrame.BackgroundTransparency = 1
gridFrame.BorderSizePixel = 0
gridFrame.ScrollBarThickness = 4
gridFrame.ScrollBarImageColor3 = C.Accent
gridFrame.Parent          = panel

local gridLayout          = Instance.new("UIGridLayout")
gridLayout.CellSize       = UDim2.new(0, 88, 0, 100)
gridLayout.CellPadding    = UDim2.new(0, 8, 0, 8)
gridLayout.Parent         = gridFrame

-- ─────────────────────────────────────────
-- Right: Equipped info panel
-- ─────────────────────────────────────────
local infoPanel           = Instance.new("Frame")
infoPanel.Size            = UDim2.new(0, 240, 1, -56)
infoPanel.Position        = UDim2.new(0, 410, 0, 54)
infoPanel.BackgroundColor3 = C.Panel
infoPanel.BorderSizePixel = 0
infoPanel.Parent          = panel
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 10)

local equippedTitle       = Instance.new("TextLabel")
equippedTitle.Size        = UDim2.new(1, -10, 0, 28)
equippedTitle.Position    = UDim2.new(0, 8, 0, 8)
equippedTitle.BackgroundTransparency = 1
equippedTitle.Text        = "EQUIPPED PET"
equippedTitle.TextColor3  = C.Accent
equippedTitle.Font        = Enum.Font.GothamBold
equippedTitle.TextSize    = 14
equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
equippedTitle.Parent      = infoPanel

local equippedEmoji       = Instance.new("TextLabel")
equippedEmoji.Size        = UDim2.new(1, 0, 0, 60)
equippedEmoji.Position    = UDim2.new(0, 0, 0, 40)
equippedEmoji.BackgroundTransparency = 1
equippedEmoji.Text        = "—"
equippedEmoji.TextColor3  = Color3.new(1,1,1)
equippedEmoji.Font        = Enum.Font.Gotham
equippedEmoji.TextSize    = 44
equippedEmoji.Parent      = infoPanel

local equippedName        = Instance.new("TextLabel")
equippedName.Size         = UDim2.new(1, -10, 0, 26)
equippedName.Position     = UDim2.new(0, 8, 0, 105)
equippedName.BackgroundTransparency = 1
equippedName.Text         = "None"
equippedName.TextColor3   = Color3.new(1,1,1)
equippedName.Font         = Enum.Font.GothamBold
equippedName.TextSize     = 18
equippedName.TextXAlignment = Enum.TextXAlignment.Left
equippedName.Parent       = infoPanel

local equippedRarity      = Instance.new("TextLabel")
equippedRarity.Size       = UDim2.new(1, -10, 0, 22)
equippedRarity.Position   = UDim2.new(0, 8, 0, 132)
equippedRarity.BackgroundTransparency = 1
equippedRarity.Text       = ""
equippedRarity.Font       = Enum.Font.GothamBold
equippedRarity.TextSize   = 13
equippedRarity.TextXAlignment = Enum.TextXAlignment.Left
equippedRarity.Parent     = infoPanel

local equippedBuff        = Instance.new("TextLabel")
equippedBuff.Size         = UDim2.new(1, -10, 0, 60)
equippedBuff.Position     = UDim2.new(0, 8, 0, 158)
equippedBuff.BackgroundTransparency = 1
equippedBuff.Text         = ""
equippedBuff.TextColor3   = C.TextSecondary
equippedBuff.Font         = Enum.Font.Gotham
equippedBuff.TextSize     = 13
equippedBuff.TextXAlignment = Enum.TextXAlignment.Left
equippedBuff.TextWrapped  = true
equippedBuff.Parent       = infoPanel

local equippedFlavour     = Instance.new("TextLabel")
equippedFlavour.Size      = UDim2.new(1, -10, 0, 50)
equippedFlavour.Position  = UDim2.new(0, 8, 0, 222)
equippedFlavour.BackgroundTransparency = 1
equippedFlavour.Text      = ""
equippedFlavour.TextColor3 = C.TextSecondary
equippedFlavour.Font      = Enum.Font.Gotham
equippedFlavour.TextSize  = 12
equippedFlavour.TextWrapped = true
equippedFlavour.TextXAlignment = Enum.TextXAlignment.Left
equippedFlavour.Parent    = infoPanel

local unequipBtn          = Instance.new("TextButton")
unequipBtn.Size           = UDim2.new(1, -16, 0, 36)
unequipBtn.Position       = UDim2.new(0, 8, 1, -48)
unequipBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
unequipBtn.BorderSizePixel = 0
unequipBtn.Text           = "Unequip"
unequipBtn.TextColor3     = Color3.new(1,1,1)
unequipBtn.Font           = Enum.Font.GothamBold
unequipBtn.TextSize       = 15
unequipBtn.Parent         = infoPanel
Instance.new("UICorner", unequipBtn).CornerRadius = UDim.new(0, 8)
unequipBtn.MouseButton1Click:Connect(function()
	Remotes:FindFirstChild("EquipPet"):FireServer(nil)
end)

-- ─────────────────────────────────────────
-- Rarity color helper
-- ─────────────────────────────────────────
local rarityColors = {
	Common    = C.Common,
	Uncommon  = C.Uncommon,
	Rare      = C.Rare,
	Legendary = C.Legendary,
}

-- ─────────────────────────────────────────
-- Rebuild pet grid
-- ─────────────────────────────────────────
local function refreshGrid()
	-- Clear existing cards
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:sub(1,8) == "PetCard_" then
			child:Destroy()
		end
	end

	petCountLbl.Text = #localPets .. " / 50 pets"

	for i, pet in ipairs(localPets) do
		local rarColor = rarityColors[pet.rarity] or C.TextSecondary
		local isEquipped = (localEquipped == i)

		local card             = Instance.new("Frame")
		card.Name              = "PetCard_" .. i
		card.BackgroundColor3  = isEquipped
			and Color3.fromRGB(40, 60, 40)
			or  Color3.fromRGB(30, 30, 44)
		card.BorderSizePixel   = 0
		card.Parent            = gridFrame
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

		local stroke = Instance.new("UIStroke", card)
		stroke.Color      = rarColor
		stroke.Thickness  = isEquipped and 2 or 1
		stroke.Transparency = isEquipped and 0 or 0.5

		local emojiLbl             = Instance.new("TextLabel")
		emojiLbl.Size              = UDim2.new(1, 0, 0, 44)
		emojiLbl.Position          = UDim2.new(0, 0, 0, 4)
		emojiLbl.BackgroundTransparency = 1
		emojiLbl.Text              = pet.emoji or "❓"
		emojiLbl.TextSize          = 32
		emojiLbl.Font              = Enum.Font.Gotham
		emojiLbl.Parent            = card

		local nameLbl              = Instance.new("TextLabel")
		nameLbl.Size               = UDim2.new(1, -4, 0, 18)
		nameLbl.Position           = UDim2.new(0, 2, 0, 50)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text               = pet.name
		nameLbl.TextColor3         = Color3.new(1,1,1)
		nameLbl.Font               = Enum.Font.GothamBold
		nameLbl.TextSize           = 11
		nameLbl.TextScaled         = false
		nameLbl.TextWrapped        = true
		nameLbl.Parent             = card

		local rarLbl               = Instance.new("TextLabel")
		rarLbl.Size                = UDim2.new(1, -4, 0, 16)
		rarLbl.Position            = UDim2.new(0, 2, 0, 70)
		rarLbl.BackgroundTransparency = 1
		rarLbl.Text                = pet.rarity
		rarLbl.TextColor3          = rarColor
		rarLbl.Font                = Enum.Font.GothamBold
		rarLbl.TextSize            = 10
		rarLbl.Parent              = card

		-- Click to equip
		local petIndex = i   -- capture
		local btn = Instance.new("TextButton")
		btn.Size  = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text  = ""
		btn.Parent = card
		btn.MouseButton1Click:Connect(function()
			if localEquipped == petIndex then
				Remotes:FindFirstChild("EquipPet"):FireServer(nil)
			else
				Remotes:FindFirstChild("EquipPet"):FireServer(petIndex)
			end
		end)
	end

	-- Update right panel
	if localEquipped and localPets[localEquipped] then
		local pet     = localPets[localEquipped]
		local rarDef  = PetData.Rarities[pet.rarity]
		equippedEmoji.Text  = pet.emoji or "❓"
		equippedName.Text   = pet.name
		equippedRarity.Text = pet.rarity
		equippedRarity.TextColor3 = rarityColors[pet.rarity] or Color3.new(1,1,1)
		equippedBuff.Text   = "Buff: " .. (rarDef and rarDef.buffDesc or "?")
		equippedFlavour.Text = pet.flavour or ""
	else
		equippedEmoji.Text  = "—"
		equippedName.Text   = "None"
		equippedRarity.Text = ""
		equippedBuff.Text   = ""
		equippedFlavour.Text = "Select a pet from your collection."
	end
end

-- ─────────────────────────────────────────
-- Egg result popup
-- ─────────────────────────────────────────
local eggPopup            = Instance.new("Frame")
eggPopup.Size             = UDim2.new(0, 320, 0, 220)
eggPopup.Position         = UDim2.new(0.5, -160, 0.3, 0)
eggPopup.BackgroundColor3 = C.Background
eggPopup.BorderSizePixel  = 0
eggPopup.Visible          = false
eggPopup.ZIndex           = 30
eggPopup.Parent           = playerGui:FindFirstChild("HUD") or screenGui
Instance.new("UICorner", eggPopup).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", eggPopup).Color        = C.Gold

local eggResultEmoji = Instance.new("TextLabel")
eggResultEmoji.Size  = UDim2.new(1, 0, 0, 70)
eggResultEmoji.Position = UDim2.new(0, 0, 0, 10)
eggResultEmoji.BackgroundTransparency = 1
eggResultEmoji.TextSize = 52
eggResultEmoji.Font  = Enum.Font.Gotham
eggResultEmoji.ZIndex = 31
eggResultEmoji.Parent = eggPopup

local eggResultTitle = Instance.new("TextLabel")
eggResultTitle.Size  = UDim2.new(1, -10, 0, 30)
eggResultTitle.Position = UDim2.new(0, 5, 0, 84)
eggResultTitle.BackgroundTransparency = 1
eggResultTitle.TextColor3 = C.Accent
eggResultTitle.Font  = Enum.Font.GothamBold
eggResultTitle.TextSize = 20
eggResultTitle.ZIndex = 31
eggResultTitle.Parent = eggPopup

local eggResultRarity = Instance.new("TextLabel")
eggResultRarity.Size  = UDim2.new(1, -10, 0, 24)
eggResultRarity.Position = UDim2.new(0, 5, 0, 116)
eggResultRarity.BackgroundTransparency = 1
eggResultRarity.Font  = Enum.Font.GothamBold
eggResultRarity.TextSize = 16
eggResultRarity.ZIndex = 31
eggResultRarity.Parent = eggPopup

local eggResultBuff = Instance.new("TextLabel")
eggResultBuff.Size  = UDim2.new(1, -10, 0, 22)
eggResultBuff.Position = UDim2.new(0, 5, 0, 142)
eggResultBuff.BackgroundTransparency = 1
eggResultBuff.TextColor3 = C.TextSecondary
eggResultBuff.Font  = Enum.Font.Gotham
eggResultBuff.TextSize = 13
eggResultBuff.ZIndex = 31
eggResultBuff.Parent = eggPopup

local eggCloseBtn = Instance.new("TextButton")
eggCloseBtn.Size  = UDim2.new(0, 110, 0, 32)
eggCloseBtn.Position = UDim2.new(0.5, -55, 1, -44)
eggCloseBtn.BackgroundColor3 = C.Accent
eggCloseBtn.BorderSizePixel = 0
eggCloseBtn.Text  = "Collect!"
eggCloseBtn.TextColor3 = Color3.new(1,1,1)
eggCloseBtn.Font  = Enum.Font.GothamBold
eggCloseBtn.TextSize = 15
eggCloseBtn.ZIndex = 31
eggCloseBtn.Parent = eggPopup
Instance.new("UICorner", eggCloseBtn).CornerRadius = UDim.new(0, 8)
eggCloseBtn.MouseButton1Click:Connect(function()
	eggPopup.Visible = false
end)

-- ─────────────────────────────────────────
-- Receive server events
-- ─────────────────────────────────────────
Remotes:FindFirstChild("PetsChanged").OnClientEvent:Connect(function(data)
	localPets     = data.pets     or {}
	localEquipped = data.equipped or nil
	if screenGui.Enabled then refreshGrid() end
end)

Remotes:FindFirstChild("EggResult").OnClientEvent:Connect(function(result)
	if not result.success then
		-- Show brief error toast via existing damage-number system
		local hudUE = ReplicatedStorage:FindFirstChild("UIEvents")
		if hudUE and hudUE:FindFirstChild("ShowDamage") then
			-- reuse system — not ideal but lightweight
		end
		warn("[PetGui] Egg failed: " .. (result.reason or "unknown"))
		return
	end

	local pet     = result.pet
	local rarDef  = PetData.Rarities[pet.rarity]
	local rarColor = rarityColors[pet.rarity] or Color3.new(1,1,1)

	eggResultEmoji.Text            = pet.emoji or "❓"
	eggResultTitle.Text            = pet.name
	eggResultRarity.Text           = "⭐ " .. pet.rarity
	eggResultRarity.TextColor3     = rarColor
	eggResultBuff.Text             = rarDef and rarDef.buffDesc or ""
	eggPopup.Visible               = true

	-- Flash gold border for Legendary
	if pet.rarity == "Legendary" then
		local stroke = eggPopup:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
				{ Thickness = 4 }):Play()
		end
	end
end)

-- ─────────────────────────────────────────
-- Compact pet buff HUD widget (always visible, bottom-left)
-- ─────────────────────────────────────────
local buffWidget              = Instance.new("Frame")
buffWidget.Name               = "PetBuffWidget"
buffWidget.Size               = UDim2.new(0, 160, 0, 46)
buffWidget.Position           = UDim2.new(0, 16, 1, -260)
buffWidget.BackgroundColor3   = C.Panel
buffWidget.BackgroundTransparency = 0.3
buffWidget.BorderSizePixel    = 0
buffWidget.Parent             = playerGui:FindFirstChild("HUD") or screenGui
Instance.new("UICorner", buffWidget).CornerRadius = UDim.new(0, 8)

local buffTitle               = Instance.new("TextLabel")
buffTitle.Size                = UDim2.new(1, -8, 0, 18)
buffTitle.Position            = UDim2.new(0, 6, 0, 4)
buffTitle.BackgroundTransparency = 1
buffTitle.Text                = "🐾 No Pet"
buffTitle.TextColor3          = C.TextSecondary
buffTitle.Font                = Enum.Font.GothamBold
buffTitle.TextSize            = 12
buffTitle.TextXAlignment      = Enum.TextXAlignment.Left
buffTitle.Parent              = buffWidget

local buffDesc                = Instance.new("TextLabel")
buffDesc.Size                 = UDim2.new(1, -8, 0, 18)
buffDesc.Position             = UDim2.new(0, 6, 0, 22)
buffDesc.BackgroundTransparency = 1
buffDesc.Text                 = ""
buffDesc.TextColor3           = C.TextSecondary
buffDesc.Font                 = Enum.Font.Gotham
buffDesc.TextSize             = 11
buffDesc.TextXAlignment       = Enum.TextXAlignment.Left
buffDesc.Parent               = buffWidget

Remotes:FindFirstChild("PetsChanged").OnClientEvent:Connect(function(data)
	localPets     = data.pets     or {}
	localEquipped = data.equipped or nil

	if localEquipped and localPets[localEquipped] then
		local pet    = localPets[localEquipped]
		local rarDef = PetData.Rarities[pet.rarity]
		buffTitle.Text     = pet.emoji .. " " .. pet.name
		buffTitle.TextColor3 = rarityColors[pet.rarity] or Color3.new(1,1,1)
		buffDesc.Text      = rarDef and rarDef.buffDesc or ""
	else
		buffTitle.Text     = "🐾 No Pet"
		buffTitle.TextColor3 = C.TextSecondary
		buffDesc.Text      = ""
	end

	if screenGui.Enabled then refreshGrid() end
end)

-- ─────────────────────────────────────────
-- Open button (sits next to the shop button)
-- ─────────────────────────────────────────
local openBtn             = Instance.new("TextButton")
openBtn.Name              = "PetOpenBtn"
openBtn.Size              = UDim2.new(0, 100, 0, 38)
openBtn.Position          = UDim2.new(1, -242, 1, -52)
openBtn.BackgroundColor3  = Color3.fromRGB(100, 60, 160)
openBtn.BorderSizePixel   = 0
openBtn.Text              = "🐾 PETS"
openBtn.TextColor3        = Color3.new(1, 1, 1)
openBtn.Font              = Enum.Font.GothamBold
openBtn.TextSize          = 16
openBtn.Parent            = playerGui:FindFirstChild("HUD") or screenGui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)

openBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = not screenGui.Enabled
	if screenGui.Enabled then refreshGrid() end
end)

_G.TogglePets = function()
	screenGui.Enabled = not screenGui.Enabled
	if screenGui.Enabled then refreshGrid() end
end

print("[InsectEvo] PetGui initialized.")
