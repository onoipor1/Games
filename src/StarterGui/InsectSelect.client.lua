-- InsectSelect.client.lua (LocalScript inside StarterGui)
-- Shows the insect selection screen at the start of the game.
-- Players pick their starting insect path before spawning.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local InsectData = require(ReplicatedStorage:WaitForChild("InsectData"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = GameConfig.UIColors

-- ─────────────────────────────────────────
-- Build selection ScreenGui
-- ─────────────────────────────────────────
local screenGui            = Instance.new("ScreenGui")
screenGui.Name             = "InsectSelect"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.Parent           = playerGui

-- Dark background overlay
local bg                   = Instance.new("Frame")
bg.Size                    = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3        = Color3.fromRGB(10, 12, 18)
bg.BackgroundTransparency  = 0
bg.BorderSizePixel         = 0
bg.Parent                  = screenGui

-- Title
local title                = Instance.new("TextLabel")
title.Size                 = UDim2.new(1, 0, 0, 70)
title.Position             = UDim2.new(0, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text                 = "CHOOSE YOUR COMPANION"
title.TextColor3           = C.Accent
title.Font                 = Enum.Font.GothamBold
title.TextScaled           = true
title.Parent               = bg

local subtitle             = Instance.new("TextLabel")
subtitle.Size              = UDim2.new(1, 0, 0, 30)
subtitle.Position          = UDim2.new(0, 0, 0, 100)
subtitle.BackgroundTransparency = 1
subtitle.Text              = "Your companion fights alongside your avatar — evolves by defeating bosses"
subtitle.TextColor3        = C.TextSecondary
subtitle.Font              = Enum.Font.Gotham
subtitle.TextScaled        = true
subtitle.Parent            = bg

-- ─────────────────────────────────────────
-- Insect card grid
-- ─────────────────────────────────────────
local insectTypes = InsectData.GetInsectTypes()

local cardColors = {
	Ant       = Color3.fromRGB(40, 30, 20),
	Beetle    = Color3.fromRGB(30, 20, 10),
	Butterfly = Color3.fromRGB(30, 35, 10),
	Bee       = Color3.fromRGB(40, 35, 10),
	Spider    = Color3.fromRGB(20, 10, 25),
}

local cardAccents = {
	Ant       = Color3.fromRGB(180, 80, 40),
	Beetle    = Color3.fromRGB(140, 90, 50),
	Butterfly = Color3.fromRGB(200, 200, 60),
	Bee       = Color3.fromRGB(240, 180, 30),
	Spider    = Color3.fromRGB(160, 60, 200),
}

local insectEmoji = {
	Ant       = "🐜",
	Beetle    = "🪲",
	Butterfly = "🦋",
	Bee       = "🐝",
	Spider    = "🕷",
}

local cardWidth    = 200
local cardHeight   = 240
local cardSpacing  = 20
local totalWidth   = (#insectTypes * cardWidth) + ((#insectTypes - 1) * cardSpacing)

local cardContainer        = Instance.new("Frame")
cardContainer.Size         = UDim2.new(0, totalWidth, 0, cardHeight)
cardContainer.Position     = UDim2.new(0.5, -totalWidth / 2, 0.5, -cardHeight / 2 + 20)
cardContainer.BackgroundTransparency = 1
cardContainer.Parent       = bg

for i, insectType in ipairs(insectTypes) do
	local stages   = InsectData.Evolutions[insectType]
	local firstStage = stages[1]
	local lastStage  = stages[#stages]

	local card                     = Instance.new("Frame")
	card.Name                      = "Card_" .. insectType
	card.Size                      = UDim2.new(0, cardWidth, 0, cardHeight)
	card.Position                  = UDim2.new(0, (i - 1) * (cardWidth + cardSpacing), 0, 0)
	card.BackgroundColor3          = cardColors[insectType] or C.Panel
	card.BorderSizePixel           = 0
	card.Parent                    = cardContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	-- Top accent bar
	local accentBar                = Instance.new("Frame")
	accentBar.Size                 = UDim2.new(1, 0, 0, 5)
	accentBar.BackgroundColor3     = cardAccents[insectType] or C.Accent
	accentBar.BorderSizePixel      = 0
	accentBar.Parent               = card
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 12)

	-- Emoji/icon
	local icon                     = Instance.new("TextLabel")
	icon.Size                      = UDim2.new(1, 0, 0, 60)
	icon.Position                  = UDim2.new(0, 0, 0, 12)
	icon.BackgroundTransparency    = 1
	icon.Text                      = insectEmoji[insectType] or "🐛"
	icon.TextScaled                = true
	icon.Font                      = Enum.Font.Gotham
	icon.Parent                    = card

	-- Insect name
	local nameLabel                = Instance.new("TextLabel")
	nameLabel.Size                 = UDim2.new(1, -10, 0, 26)
	nameLabel.Position             = UDim2.new(0, 5, 0, 76)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                 = insectType
	nameLabel.TextColor3           = cardAccents[insectType] or C.Accent
	nameLabel.Font                 = Enum.Font.GothamBold
	nameLabel.TextScaled           = true
	nameLabel.Parent               = card

	-- Stage info
	local stagesLabel              = Instance.new("TextLabel")
	stagesLabel.Size               = UDim2.new(1, -10, 0, 18)
	stagesLabel.Position           = UDim2.new(0, 5, 0, 104)
	stagesLabel.BackgroundTransparency = 1
	stagesLabel.Text               = firstStage.name .. "  →  " .. lastStage.name
	stagesLabel.TextColor3         = C.TextSecondary
	stagesLabel.Font               = Enum.Font.Gotham
	stagesLabel.TextScaled         = false
	stagesLabel.TextSize           = 11
	stagesLabel.TextWrapped        = true
	stagesLabel.Parent             = card

	-- Stats summary
	local statsLabel               = Instance.new("TextLabel")
	statsLabel.Size                = UDim2.new(1, -10, 0, 52)
	statsLabel.Position            = UDim2.new(0, 5, 0, 126)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text                = string.format(
		"❤ %d HP   ⚡ %d Spd\n⚔ %d Dmg   %d Stages",
		firstStage.maxHealth, firstStage.walkSpeed,
		firstStage.damage,    #stages
	)
	statsLabel.TextColor3          = C.TextSecondary
	statsLabel.Font                = Enum.Font.Gotham
	statsLabel.TextScaled          = false
	statsLabel.TextSize            = 12
	statsLabel.TextWrapped         = true
	statsLabel.Parent              = card

	-- Select button
	local btn                      = Instance.new("TextButton")
	btn.Size                       = UDim2.new(1, -16, 0, 36)
	btn.Position                   = UDim2.new(0, 8, 1, -44)
	btn.BackgroundColor3           = cardAccents[insectType] or C.Accent
	btn.BorderSizePixel            = 0
	btn.Text                       = "CHOOSE"
	btn.TextColor3                 = Color3.new(1, 1, 1)
	btn.Font                       = Enum.Font.GothamBold
	btn.TextSize                   = 15
	btn.Parent                     = card
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	-- Hover animation
	btn.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), {
			Size     = UDim2.new(0, cardWidth + 8, 0, cardHeight + 8),
			Position = UDim2.new(0, (i - 1) * (cardWidth + cardSpacing) - 4, 0, -4),
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), {
			Size     = UDim2.new(0, cardWidth, 0, cardHeight),
			Position = UDim2.new(0, (i - 1) * (cardWidth + cardSpacing), 0, 0),
		}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		-- Fire server to set insect type
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChooseInsect"):FireServer(insectType)

		-- Fade out and destroy selection screen
		TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		for _, child in ipairs(bg:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				if child:IsA("TextLabel") or child:IsA("TextButton") then
					TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				end
			end
		end

		task.wait(0.7)
		screenGui:Destroy()
	end)
end

-- Fade in on start
bg.BackgroundTransparency = 1
TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()

print("[InsectEvo] InsectSelect initialized.")
