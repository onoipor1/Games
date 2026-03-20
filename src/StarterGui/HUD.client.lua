-- HUD.client.lua (LocalScript inside StarterGui)
-- Builds and manages the in-game heads-up display:
--   • Health bar
--   • XP bar & progress
--   • Crystal balance
--   • Active event banner chip
--   • Stage name & insect type
--   • Ability slots (1-4)
--   • Evolution notification popup
--   • Floating damage numbers
--   • Shop / Pet / Admin hotkeys (B = shop, N = pets)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local InsectData = require(ReplicatedStorage:WaitForChild("InsectData"))

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────
-- UIEvents BindableEvents (created here)
-- ─────────────────────────────────────────
local function getOrCreate(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = name
		obj.Parent = parent
	end
	return obj
end

local uiFolder = getOrCreate(ReplicatedStorage, "Folder", "UIEvents")
local evUpdateHUD    = getOrCreate(uiFolder, "BindableEvent", "UpdateHUD")
local evShowEvolution = getOrCreate(uiFolder, "BindableEvent", "ShowEvolution")
local evShowDamage   = getOrCreate(uiFolder, "BindableEvent", "ShowDamage")
local evShowDeath    = getOrCreate(uiFolder, "BindableEvent", "ShowDeath")

-- ─────────────────────────────────────────
-- Colour helpers
-- ─────────────────────────────────────────
local C = GameConfig.UIColors

-- ─────────────────────────────────────────
-- Build ScreenGui
-- ─────────────────────────────────────────
local screenGui            = Instance.new("ScreenGui")
screenGui.Name             = "HUD"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.Parent           = playerGui

-- ─────────────────────────────────────────
-- Panel helper
-- ─────────────────────────────────────────
local function panel(name, size, pos, color, transparency)
	local f                    = Instance.new("Frame")
	f.Name                     = name
	f.Size                     = size
	f.Position                 = pos
	f.BackgroundColor3         = color or C.Panel
	f.BackgroundTransparency   = transparency or 0
	f.BorderSizePixel          = 0
	f.Parent                   = screenGui
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	return f
end

local function label(name, text, size, pos, parent, font, color)
	local l                    = Instance.new("TextLabel")
	l.Name                     = name
	l.Text                     = text
	l.Size                     = size
	l.Position                 = pos
	l.BackgroundTransparency   = 1
	l.TextColor3               = color or C.TextPrimary
	l.Font                     = font or Enum.Font.Gotham
	l.TextScaled               = true
	l.Parent                   = parent
	return l
end

local function bar(name, parent, fillColor, bgColor)
	local bg           = Instance.new("Frame")
	bg.Name            = name .. "BG"
	bg.Size            = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = bgColor or Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Parent          = parent
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

	local fill         = Instance.new("Frame")
	fill.Name          = name .. "Fill"
	fill.Size          = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent        = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

	return bg, fill
end

-- ─────────────────────────────────────────
-- Top-left: Insect info panel
-- ─────────────────────────────────────────
local infoPanel = panel("InfoPanel",
	UDim2.new(0, 280, 0, 130),
	UDim2.new(0, 16, 0, 16),
	C.Panel
)
infoPanel.BackgroundTransparency = 0.25

local stageLabel = label("StageLabel", "Ant Larva",
	UDim2.new(1, -10, 0, 28),
	UDim2.new(0, 8, 0, 6),
	infoPanel,
	Enum.Font.GothamBold,
	C.Accent
)

local insectTypeLabel = label("InsectTypeLabel", "Ant | Stage 1",
	UDim2.new(1, -10, 0, 20),
	UDim2.new(0, 8, 0, 36),
	infoPanel,
	Enum.Font.Gotham,
	C.TextSecondary
)

local descLabel = label("DescLabel", "A tiny wriggling larva.",
	UDim2.new(1, -10, 0, 30),
	UDim2.new(0, 8, 0, 58),
	infoPanel,
	Enum.Font.Gotham,
	C.TextSecondary
)
descLabel.TextScaled = false
descLabel.TextSize   = 12
descLabel.TextWrapped = true

-- ─────────────────────────────────────────
-- HP bar (below info panel)
-- ─────────────────────────────────────────
local hpPanel = panel("HPPanel",
	UDim2.new(0, 280, 0, 26),
	UDim2.new(0, 16, 0, 154),
	C.Panel
)
hpPanel.BackgroundTransparency = 0.3

label("HPIcon", "♥ HP", UDim2.new(0, 50, 1, 0), UDim2.new(0, 4, 0, 0), hpPanel, Enum.Font.GothamBold, Color3.fromRGB(220, 60, 60))

local hpBarHolder = Instance.new("Frame")
hpBarHolder.Size             = UDim2.new(1, -60, 0, 14)
hpBarHolder.Position         = UDim2.new(0, 56, 0.5, -7)
hpBarHolder.BackgroundTransparency = 1
hpBarHolder.Parent           = hpPanel

local _, hpFill = bar("HP", hpBarHolder, C.HPBar, Color3.fromRGB(40, 20, 20))

local hpText = label("HPText", "30 / 30",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	hpBarHolder,
	Enum.Font.GothamBold,
	Color3.new(1, 1, 1)
)
hpText.ZIndex = 3

-- ─────────────────────────────────────────
-- XP bar
-- ─────────────────────────────────────────
local xpPanel = panel("XPPanel",
	UDim2.new(0, 280, 0, 26),
	UDim2.new(0, 16, 0, 186),
	C.Panel
)
xpPanel.BackgroundTransparency = 0.3

label("XPIcon", "✦ XP", UDim2.new(0, 50, 1, 0), UDim2.new(0, 4, 0, 0), xpPanel, Enum.Font.GothamBold, C.XPBar)

local xpBarHolder = Instance.new("Frame")
xpBarHolder.Size             = UDim2.new(1, -60, 0, 14)
xpBarHolder.Position         = UDim2.new(0, 56, 0.5, -7)
xpBarHolder.BackgroundTransparency = 1
xpBarHolder.Parent           = xpPanel

local _, xpFill = bar("XP", xpBarHolder, C.XPBar, Color3.fromRGB(20, 30, 50))

local xpText = label("XPText", "0 / 50",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	xpBarHolder,
	Enum.Font.GothamBold,
	Color3.new(1, 1, 1)
)
xpText.ZIndex = 3

-- ─────────────────────────────────────────
-- Crystal balance display (top right)
-- ─────────────────────────────────────────
local crystalPanel = panel("CrystalPanel",
	UDim2.new(0, 160, 0, 36),
	UDim2.new(1, -176, 0, 16),
	C.Panel
)
crystalPanel.BackgroundTransparency = 0.2
local crystalLabel = label("CrystalCount", "💎 0",
	UDim2.new(1, -8, 1, 0),
	UDim2.new(0, 6, 0, 0),
	crystalPanel,
	Enum.Font.GothamBold,
	C.CrystalColor
)
crystalLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ─────────────────────────────────────────
-- Active event chip (top centre)
-- ─────────────────────────────────────────
local eventChip = panel("EventChip",
	UDim2.new(0, 240, 0, 28),
	UDim2.new(0.5, -120, 0, 16),
	Color3.fromRGB(40, 20, 10)
)
eventChip.BackgroundTransparency = 0.3
eventChip.Visible = false
local eventChipLabel = label("EventLabel", "",
	UDim2.new(1, -8, 1, 0),
	UDim2.new(0, 4, 0, 0),
	eventChip,
	Enum.Font.GothamBold,
	C.Gold
)

-- ─────────────────────────────────────────
-- Bottom: Ability slots (1–4)
-- ─────────────────────────────────────────
local abilityPanel = panel("AbilityPanel",
	UDim2.new(0, 300, 0, 80),
	UDim2.new(0.5, -150, 1, -100),
	C.Panel
)
abilityPanel.BackgroundTransparency = 0.2

local abilitySlots = {}
for i = 1, 4 do
	local slot = Instance.new("Frame")
	slot.Name              = "Slot" .. i
	slot.Size              = UDim2.new(0, 62, 0, 62)
	slot.Position          = UDim2.new(0, (i - 1) * 70 + 8, 0, 9)
	slot.BackgroundColor3  = Color3.fromRGB(40, 40, 55)
	slot.BorderSizePixel   = 0
	slot.Parent            = abilityPanel
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

	local nameLabel = label("AbilityName", "--",
		UDim2.new(1, -2, 0, 26),
		UDim2.new(0, 1, 0, 4),
		slot,
		Enum.Font.GothamBold,
		C.TextPrimary
	)
	nameLabel.TextScaled = false
	nameLabel.TextSize   = 10
	nameLabel.TextWrapped = true

	local keyLabel = label("KeyLabel", tostring(i),
		UDim2.new(0, 18, 0, 18),
		UDim2.new(0, 2, 1, -20),
		slot,
		Enum.Font.GothamBold,
		C.Accent
	)
	keyLabel.TextScaled = false
	keyLabel.TextSize   = 11

	-- Cooldown overlay
	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name               = "CooldownOverlay"
	cdOverlay.Size               = UDim2.new(1, 0, 0, 0) -- grows from bottom
	cdOverlay.Position           = UDim2.new(0, 0, 1, 0)
	cdOverlay.AnchorPoint        = Vector2.new(0, 1)
	cdOverlay.BackgroundColor3   = Color3.fromRGB(10, 10, 20)
	cdOverlay.BackgroundTransparency = 0.4
	cdOverlay.BorderSizePixel    = 0
	cdOverlay.ZIndex             = 4
	cdOverlay.Visible            = false
	cdOverlay.Parent             = slot
	Instance.new("UICorner", cdOverlay).CornerRadius = UDim.new(0, 8)

	local cdText = label("CDText", "",
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		cdOverlay,
		Enum.Font.GothamBold,
		Color3.new(1, 1, 1)
	)
	cdText.ZIndex = 5

	abilitySlots[i] = {
		frame    = slot,
		nameLabel = nameLabel,
		cdOverlay = cdOverlay,
		cdText   = cdText,
	}
end

-- ─────────────────────────────────────────
-- Evolution popup
-- ─────────────────────────────────────────
local evoPopup = panel("EvoPopup",
	UDim2.new(0, 400, 0, 140),
	UDim2.new(0.5, -200, 0.3, 0),
	Color3.fromRGB(20, 40, 30)
)
evoPopup.BackgroundTransparency = 0.1
evoPopup.Visible = false
evoPopup.ZIndex  = 10
Instance.new("UIStroke", evoPopup).Color = C.Accent

label("EvoTitle", "✦ EVOLVED!", UDim2.new(1, -10, 0, 36), UDim2.new(0, 5, 0, 8), evoPopup, Enum.Font.GothamBold, C.Accent)

local evoNameLabel = label("EvoName", "",
	UDim2.new(1, -10, 0, 30),
	UDim2.new(0, 5, 0, 48),
	evoPopup,
	Enum.Font.GothamBold,
	Color3.new(1, 1, 1)
)

local evoDescLabel = label("EvoDesc", "",
	UDim2.new(1, -10, 0, 36),
	UDim2.new(0, 5, 0, 82),
	evoPopup,
	Enum.Font.Gotham,
	C.TextSecondary
)
evoDescLabel.TextScaled = false
evoDescLabel.TextSize   = 13
evoDescLabel.TextWrapped = true

-- Death screen
local deathScreen = panel("DeathScreen",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(40, 0, 0)
)
deathScreen.BackgroundTransparency = 0.5
deathScreen.Visible = false
deathScreen.ZIndex  = 20

label("DeathTitle", "YOU DIED", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.35, 0), deathScreen, Enum.Font.GothamBold, Color3.fromRGB(220, 60, 60))
label("DeathSub", "Respawning...", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0.5, 0), deathScreen, Enum.Font.Gotham, Color3.new(1, 1, 1))

-- ─────────────────────────────────────────
-- Update functions
-- ─────────────────────────────────────────
local function tweenBar(fillFrame, fraction)
	TweenService:Create(fillFrame, TweenInfo.new(0.2), {
		Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
	}):Play()
end

local function updateAbilitySlots(abilities)
	for i = 1, 4 do
		local slot    = abilitySlots[i]
		local ability = abilities[i]
		slot.nameLabel.Text = ability or "--"
		slot.frame.BackgroundColor3 = ability
			and Color3.fromRGB(55, 70, 90)
			or  Color3.fromRGB(35, 35, 50)
	end
end

local currentData = {}

evUpdateHUD.Event:Connect(function(data)
	currentData = data

	stageLabel.Text      = data.stageName or "Unknown"
	insectTypeLabel.Text = (data.insectType or "?") .. " | Stage " .. (data.stageIndex or 1)
	descLabel.Text       = data.description or ""

	-- HP
	local hpFrac = (data.maxHealth and data.maxHealth > 0)
		and (data.currentHealth / data.maxHealth) or 0
	tweenBar(hpFill, hpFrac)
	hpText.Text = math.floor(data.currentHealth or 0) .. " / " .. (data.maxHealth or 0)

	-- XP
	if data.xpRequired then
		local xpFrac = data.xpRequired > 0 and (data.xp / data.xpRequired) or 1
		tweenBar(xpFill, xpFrac)
		xpText.Text = (data.xp or 0) .. " / " .. data.xpRequired
	else
		tweenBar(xpFill, 1)
		xpText.Text = "MAX"
	end

	-- Abilities
	updateAbilitySlots(data.abilities or {})
end)

evShowEvolution.Event:Connect(function(data)
	evoNameLabel.Text = data.stageName or data.name or ""
	evoDescLabel.Text = data.description or ""
	evoPopup.Visible  = true

	-- Animate in
	evoPopup.BackgroundTransparency = 0.8
	TweenService:Create(evoPopup, TweenInfo.new(0.3), { BackgroundTransparency = 0.1 }):Play()

	task.delay(4, function()
		TweenService:Create(evoPopup, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		evoPopup.Visible = false
	end)
end)

evShowDeath.Event:Connect(function()
	deathScreen.Visible = true
	task.wait(3)
	deathScreen.Visible = false
end)

-- ─────────────────────────────────────────
-- Floating damage numbers
-- ─────────────────────────────────────────
local camera = workspace.CurrentCamera

evShowDamage.Event:Connect(function(data)
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size          = UDim2.new(0, 80, 0, 40)
	billboardGui.StudsOffset   = Vector3.new(0, 4, 0)
	billboardGui.AlwaysOnTop   = true
	billboardGui.LightInfluence = 0

	local part         = Instance.new("Part")
	part.Anchored      = true
	part.CanCollide    = false
	part.Transparency  = 1
	part.Size          = Vector3.new(1, 1, 1)
	part.Position      = data.position or Vector3.new(0, 5, 0)
	part.Parent        = workspace
	billboardGui.Parent = part

	local dmgLabel            = Instance.new("TextLabel")
	dmgLabel.Size             = UDim2.new(1, 0, 1, 0)
	dmgLabel.BackgroundTransparency = 1
	dmgLabel.Text             = "-" .. math.floor(data.amount or 0)
	dmgLabel.TextColor3       = Color3.fromRGB(255, 80, 80)
	dmgLabel.Font             = Enum.Font.GothamBold
	dmgLabel.TextScaled       = true
	dmgLabel.Parent           = billboardGui

	-- Float upward and fade
	TweenService:Create(part, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = part.Position + Vector3.new(0, 8, 0)
	}):Play()
	TweenService:Create(dmgLabel, TweenInfo.new(1.5), {
		TextTransparency = 1
	}):Play()

	game:GetService("Debris"):AddItem(part, 1.6)
end)

-- ─────────────────────────────────────────
-- Update ability cooldown overlays each frame
-- ─────────────────────────────────────────
local GameClient = player:WaitForChild("PlayerScripts"):WaitForChild("GameClient")
-- Access cooldown data through the module's shared bindable event pattern
-- (Cooldown overlay is driven by tick-based state in this script)
local clientCooldowns = {}  -- populated via AbilityCooldown remote below

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AbilityCooldown").OnClientEvent:Connect(function(data)
	clientCooldowns[data.ability] = { expires = tick() + data.remaining, total = data.remaining }
end)

RunService.RenderStepped:Connect(function()
	local abilities = currentData.abilities or {}
	for i = 1, 4 do
		local slot    = abilitySlots[i]
		local ability = abilities[i]
		if ability and clientCooldowns[ability] then
			local cd       = clientCooldowns[ability]
			local remaining = cd.expires - tick()
			if remaining > 0 then
				local frac = remaining / cd.total
				slot.cdOverlay.Visible  = true
				slot.cdOverlay.Size     = UDim2.new(1, 0, frac, 0)
				slot.cdText.Text        = string.format("%.1f", remaining)
			else
				slot.cdOverlay.Visible = false
				clientCooldowns[ability] = nil
			end
		else
			slot.cdOverlay.Visible = false
		end
	end
end)

-- ─────────────────────────────────────────
-- Crystal & event remote handlers
-- ─────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

Remotes:FindFirstChild("CrystalsChanged").OnClientEvent:Connect(function(amount)
	crystalLabel.Text = "💎 " .. tostring(amount)
end)

Remotes:FindFirstChild("EventChanged").OnClientEvent:Connect(function(data)
	if data and data.name and data.name ~= "None" then
		eventChipLabel.Text = "⚡ " .. data.name
		eventChip.Visible   = true
	else
		eventChip.Visible = false
	end
end)

-- ─────────────────────────────────────────
-- Hotkeys: B = Shop, N = Pets
-- ─────────────────────────────────────────
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		if _G.ToggleShop then _G.ToggleShop() end
	elseif input.KeyCode == Enum.KeyCode.N then
		if _G.TogglePets then _G.TogglePets() end
	end
end)

-- Update crystal display from StatsChanged (initial load)
evUpdateHUD.Event:Connect(function(data)
	if data.crystals then
		crystalLabel.Text = "💎 " .. tostring(data.crystals)
	end
end)

print("[InsectEvo] HUD initialized.")
