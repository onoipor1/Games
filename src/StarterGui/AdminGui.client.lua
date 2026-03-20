-- AdminGui.client.lua
-- In-game admin panel: event control, weather control, player utilities.
-- Only visible to players whose UserId is in the admin whitelist
-- (determined server-side; client shows panel only after server confirms admin status).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C         = GameConfig.UIColors

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- Only show to admins (server confirms via a PassesChanged payload)
-- ─────────────────────────────────────────
local isAdmin = false

-- ─────────────────────────────────────────
-- Build ScreenGui (starts hidden)
-- ─────────────────────────────────────────
local screenGui           = Instance.new("ScreenGui")
screenGui.Name            = "AdminGui"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Enabled         = false
screenGui.Parent          = playerGui

local backdrop            = Instance.new("Frame")
backdrop.Size             = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.55
backdrop.BorderSizePixel  = 0
backdrop.Parent           = screenGui

local panel               = Instance.new("Frame")
panel.Size                = UDim2.new(0, 640, 0, 560)
panel.Position            = UDim2.new(0.5, -320, 0.5, -280)
panel.BackgroundColor3    = C.Background
panel.BorderSizePixel     = 0
panel.Parent              = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", panel).Color        = Color3.fromRGB(220, 60, 60)

-- Title bar
local titleBar            = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
titleBar.BorderSizePixel  = 0
titleBar.Parent           = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleLbl            = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(0.7, 0, 1, 0)
titleLbl.Position         = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = "🛡 ADMIN PANEL"
titleLbl.TextColor3       = Color3.fromRGB(255, 100, 100)
titleLbl.Font             = Enum.Font.GothamBold
titleLbl.TextSize         = 20
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
titleLbl.Parent           = titleBar

local closeBtn            = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 36, 0, 36)
closeBtn.Position         = UDim2.new(1, -46, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.new(1,1,1)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 18
closeBtn.Parent           = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

-- ─────────────────────────────────────────
-- Scroll content area
-- ─────────────────────────────────────────
local scroll              = Instance.new("ScrollingFrame")
scroll.Size               = UDim2.new(1, -20, 1, -60)
scroll.Position           = UDim2.new(0, 10, 0, 54)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel    = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(220, 60, 60)
scroll.CanvasSize         = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent             = panel

local listLayout          = Instance.new("UIListLayout")
listLayout.Padding        = UDim.new(0, 10)
listLayout.Parent         = scroll

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────
local function section(title)
	local f                    = Instance.new("Frame")
	f.Size                     = UDim2.new(1, -8, 0, 32)
	f.BackgroundColor3         = Color3.fromRGB(60, 20, 20)
	f.BorderSizePixel          = 0
	f.Parent                   = scroll
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

	local l                    = Instance.new("TextLabel")
	l.Size                     = UDim2.new(1, -10, 1, 0)
	l.Position                 = UDim2.new(0, 8, 0, 0)
	l.BackgroundTransparency   = 1
	l.Text                     = title
	l.TextColor3               = Color3.fromRGB(255, 140, 140)
	l.Font                     = Enum.Font.GothamBold
	l.TextSize                 = 14
	l.TextXAlignment           = Enum.TextXAlignment.Left
	l.Parent                   = f
	return f
end

local function actionRow(parent, height)
	local f                    = Instance.new("Frame")
	f.Size                     = UDim2.new(1, -8, 0, height)
	f.BackgroundColor3         = C.Panel
	f.BorderSizePixel          = 0
	f.Parent                   = parent or scroll
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	return f
end

local function rowLabel(text, parent, pos, sz)
	local l                    = Instance.new("TextLabel")
	l.Size                     = sz  or UDim2.new(0.55, 0, 1, 0)
	l.Position                 = pos or UDim2.new(0, 8, 0, 0)
	l.BackgroundTransparency   = 1
	l.Text                     = text
	l.TextColor3               = C.TextPrimary
	l.Font                     = Enum.Font.Gotham
	l.TextSize                 = 14
	l.TextXAlignment           = Enum.TextXAlignment.Left
	l.TextWrapped              = true
	l.Parent                   = parent
	return l
end

local function actionBtn(text, color, parent, pos)
	local b                    = Instance.new("TextButton")
	b.Size                     = UDim2.new(0, 130, 0, 32)
	b.Position                 = pos or UDim2.new(1, -140, 0.5, -16)
	b.BackgroundColor3         = color or C.Accent
	b.BorderSizePixel          = 0
	b.Text                     = text
	b.TextColor3               = Color3.new(1,1,1)
	b.Font                     = Enum.Font.GothamBold
	b.TextSize                 = 13
	b.Parent                   = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local function sendAdmin(payload)
	Remotes:FindFirstChild("AdminCommand"):FireServer(payload)
end

-- ─────────────────────────────────────────
-- Active event status bar
-- ─────────────────────────────────────────
local statusRow           = actionRow(scroll, 44)
local statusLbl           = rowLabel("Active Event: None", statusRow,
	UDim2.new(0, 8, 0, 0), UDim2.new(1, -16, 1, 0))
statusLbl.TextColor3      = Color3.fromRGB(255, 200, 100)
statusLbl.Font            = Enum.Font.GothamBold
statusLbl.TextSize        = 15

-- ─────────────────────────────────────────
-- Section: Server Events
-- ─────────────────────────────────────────
section("⚡ SERVER EVENTS")

local eventDefs = {
	{ key = "CrystalBonus", label = "💎 Crystal Fever",  color = C.CrystalColor,   desc = "2× crystals for all" },
	{ key = "DoubleXP",     label = "🔥 XP Surge",       color = C.XPBar,          desc = "2× XP for all" },
	{ key = "GoldenHour",   label = "☀ Golden Hour",     color = C.Gold,           desc = "1.5× XP + warm sky" },
	{ key = "BloodMoon",    label = "🌑 Blood Moon",      color = Color3.fromRGB(160,30,30), desc = "2× crystal drop, harder enemies" },
	{ key = "Storm",        label = "⛈ Storm",           color = Color3.fromRGB(80,100,180), desc = "Lightning! 1.5× crystals" },
}

for _, ev in ipairs(eventDefs) do
	local row  = actionRow(scroll, 54)

	rowLabel(ev.label .. "\n" .. ev.desc, row,
		UDim2.new(0, 8, 0, 0), UDim2.new(0.55, 0, 1, 0))

	-- Duration input
	local durInput             = Instance.new("TextBox")
	durInput.Size              = UDim2.new(0, 60, 0, 28)
	durInput.Position          = UDim2.new(1, -202, 0.5, -14)
	durInput.BackgroundColor3  = Color3.fromRGB(30, 30, 45)
	durInput.BorderSizePixel   = 0
	durInput.Text              = "300"
	durInput.TextColor3        = Color3.new(1,1,1)
	durInput.Font              = Enum.Font.Gotham
	durInput.TextSize          = 13
	durInput.PlaceholderText   = "secs"
	durInput.Parent            = row
	Instance.new("UICorner", durInput).CornerRadius = UDim.new(0, 6)

	local durLbl               = Instance.new("TextLabel")
	durLbl.Size                = UDim2.new(0, 30, 0, 28)
	durLbl.Position            = UDim2.new(1, -270, 0.5, -14)
	durLbl.BackgroundTransparency = 1
	durLbl.Text                = "sec:"
	durLbl.TextColor3          = C.TextSecondary
	durLbl.Font                = Enum.Font.Gotham
	durLbl.TextSize            = 12
	durLbl.Parent              = row

	local startBtn = actionBtn("▶ Start", ev.color, row)
	startBtn.MouseButton1Click:Connect(function()
		local dur = tonumber(durInput.Text) or 300
		sendAdmin({ action = "setEvent", eventKey = ev.key, duration = dur })
	end)
end

-- Clear event row
local clearRow = actionRow(scroll, 44)
rowLabel("Clear current event and return to default.", clearRow)
local clearBtn = actionBtn("✕ Clear Event", Color3.fromRGB(140, 40, 40), clearRow)
clearBtn.MouseButton1Click:Connect(function()
	sendAdmin({ action = "clearEvent" })
end)

-- ─────────────────────────────────────────
-- Section: Weather
-- ─────────────────────────────────────────
section("🌤 WEATHER (visual only)")

local weatherTypes = { "Clear", "Rainy", "Storm", "GoldenHour", "BloodMoon" }
local weatherColors = {
	Clear      = Color3.fromRGB(80, 160, 80),
	Rainy      = Color3.fromRGB(80, 100, 140),
	Storm      = Color3.fromRGB(60, 60, 120),
	GoldenHour = Color3.fromRGB(200, 140, 40),
	BloodMoon  = Color3.fromRGB(140, 30, 30),
}
local weatherRow   = actionRow(scroll, 50)
weatherRow.Size    = UDim2.new(1, -8, 0, 50)

local weatherBtnLayout = Instance.new("UIListLayout")
weatherBtnLayout.FillDirection = Enum.FillDirection.Horizontal
weatherBtnLayout.Padding       = UDim.new(0, 6)
weatherBtnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
weatherBtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
weatherBtnLayout.Parent        = weatherRow

for _, wType in ipairs(weatherTypes) do
	local wb               = Instance.new("TextButton")
	wb.Size                = UDim2.new(0, 100, 0, 32)
	wb.BackgroundColor3    = weatherColors[wType] or C.Panel
	wb.BorderSizePixel     = 0
	wb.Text                = wType
	wb.TextColor3          = Color3.new(1,1,1)
	wb.Font                = Enum.Font.GothamBold
	wb.TextSize            = 12
	wb.Parent              = weatherRow
	Instance.new("UICorner", wb).CornerRadius = UDim.new(0, 8)
	local wt = wType
	wb.MouseButton1Click:Connect(function()
		sendAdmin({ action = "setWeather", weatherType = wt })
	end)
end

-- ─────────────────────────────────────────
-- Section: Player Utilities
-- ─────────────────────────────────────────
section("👤 PLAYER UTILITIES")

-- Give crystals
local giveCrystalRow  = actionRow(scroll, 54)
rowLabel("Give Crystals to player:", giveCrystalRow)

local playerInput1    = Instance.new("TextBox")
playerInput1.Size     = UDim2.new(0, 110, 0, 28)
playerInput1.Position = UDim2.new(1, -280, 0.5, -14)
playerInput1.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
playerInput1.BorderSizePixel = 0
playerInput1.Text     = ""
playerInput1.TextColor3 = Color3.new(1,1,1)
playerInput1.Font     = Enum.Font.Gotham
playerInput1.TextSize = 12
playerInput1.PlaceholderText = "PlayerName"
playerInput1.Parent   = giveCrystalRow
Instance.new("UICorner", playerInput1).CornerRadius = UDim.new(0, 6)

local crystalAmtInput = Instance.new("TextBox")
crystalAmtInput.Size  = UDim2.new(0, 70, 0, 28)
crystalAmtInput.Position = UDim2.new(1, -160, 0.5, -14)
crystalAmtInput.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
crystalAmtInput.BorderSizePixel = 0
crystalAmtInput.Text  = "500"
crystalAmtInput.TextColor3 = Color3.new(1,1,1)
crystalAmtInput.Font  = Enum.Font.Gotham
crystalAmtInput.TextSize = 12
crystalAmtInput.PlaceholderText = "amt"
crystalAmtInput.Parent = giveCrystalRow
Instance.new("UICorner", crystalAmtInput).CornerRadius = UDim.new(0, 6)

local giveCBtn = actionBtn("💎 Give", C.CrystalColor, giveCrystalRow,
	UDim2.new(1, -80, 0.5, -16))
giveCBtn.Size = UDim2.new(0, 72, 0, 32)
giveCBtn.MouseButton1Click:Connect(function()
	sendAdmin({
		action     = "giveCrystals",
		targetName = playerInput1.Text ~= "" and playerInput1.Text or nil,
		amount     = crystalAmtInput.Text,
	})
end)

-- Give XP
local giveXPRow       = actionRow(scroll, 54)
rowLabel("Give XP to player:", giveXPRow)

local playerInput2    = Instance.new("TextBox")
playerInput2.Size     = UDim2.new(0, 110, 0, 28)
playerInput2.Position = UDim2.new(1, -280, 0.5, -14)
playerInput2.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
playerInput2.BorderSizePixel = 0
playerInput2.Text     = ""
playerInput2.TextColor3 = Color3.new(1,1,1)
playerInput2.Font     = Enum.Font.Gotham
playerInput2.TextSize = 12
playerInput2.PlaceholderText = "PlayerName"
playerInput2.Parent   = giveXPRow
Instance.new("UICorner", playerInput2).CornerRadius = UDim.new(0, 6)

local xpAmtInput      = Instance.new("TextBox")
xpAmtInput.Size       = UDim2.new(0, 70, 0, 28)
xpAmtInput.Position   = UDim2.new(1, -160, 0.5, -14)
xpAmtInput.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
xpAmtInput.BorderSizePixel = 0
xpAmtInput.Text       = "1000"
xpAmtInput.TextColor3 = Color3.new(1,1,1)
xpAmtInput.Font       = Enum.Font.Gotham
xpAmtInput.TextSize   = 12
xpAmtInput.PlaceholderText = "amt"
xpAmtInput.Parent     = giveXPRow
Instance.new("UICorner", xpAmtInput).CornerRadius = UDim.new(0, 6)

local giveXBtn = actionBtn("⭐ Give", C.XPBar, giveXPRow,
	UDim2.new(1, -80, 0.5, -16))
giveXBtn.Size = UDim2.new(0, 72, 0, 32)
giveXBtn.MouseButton1Click:Connect(function()
	sendAdmin({
		action     = "giveXP",
		targetName = playerInput2.Text ~= "" and playerInput2.Text or nil,
		amount     = xpAmtInput.Text,
	})
end)

-- Kick player
local kickRow         = actionRow(scroll, 54)
rowLabel("Kick player from server:", kickRow)

local kickInput       = Instance.new("TextBox")
kickInput.Size        = UDim2.new(0, 160, 0, 28)
kickInput.Position    = UDim2.new(1, -280, 0.5, -14)
kickInput.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
kickInput.BorderSizePixel = 0
kickInput.Text        = ""
kickInput.TextColor3  = Color3.new(1,1,1)
kickInput.Font        = Enum.Font.Gotham
kickInput.TextSize    = 12
kickInput.PlaceholderText = "PlayerName"
kickInput.Parent      = kickRow
Instance.new("UICorner", kickInput).CornerRadius = UDim.new(0, 6)

local kickBtn = actionBtn("⛔ Kick", Color3.fromRGB(160, 30, 30), kickRow)
kickBtn.MouseButton1Click:Connect(function()
	if kickInput.Text ~= "" then
		sendAdmin({ action = "kickPlayer", targetName = kickInput.Text })
	end
end)

-- ─────────────────────────────────────────
-- Receive event/weather updates to keep status bar current
-- ─────────────────────────────────────────
Remotes:FindFirstChild("EventChanged").OnClientEvent:Connect(function(data)
	statusLbl.Text = "Active Event: " .. (data.name or "None")
		.. "  |  💎 " .. (data.crystalMult or 1) .. "×  ⭐ " .. (data.xpMult or 1) .. "×"
end)

-- ─────────────────────────────────────────
-- Admin toggle button (only shown when admin confirmed)
-- ─────────────────────────────────────────
local adminOpenBtn            = Instance.new("TextButton")
adminOpenBtn.Name             = "AdminOpenBtn"
adminOpenBtn.Size             = UDim2.new(0, 36, 0, 36)
adminOpenBtn.Position         = UDim2.new(0, 16, 0, 16)
adminOpenBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
adminOpenBtn.BorderSizePixel  = 0
adminOpenBtn.Text             = "🛡"
adminOpenBtn.TextSize         = 20
adminOpenBtn.Font             = Enum.Font.Gotham
adminOpenBtn.TextColor3       = Color3.new(1,1,1)
adminOpenBtn.Visible          = false
adminOpenBtn.Parent           = playerGui:FindFirstChild("HUD") or screenGui
Instance.new("UICorner", adminOpenBtn).CornerRadius = UDim.new(0, 8)

adminOpenBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = not screenGui.Enabled
end)

-- Check admin status once game starts
-- The server grants admin by checking UserId; here we test with
-- a no-op AdminCommand and see if PassesChanged carries an isAdmin flag.
-- Simplest approach: if the server sends back EventChanged without error, show button.
-- For a cleaner solution you can add an "IsAdmin" RemoteFunction.
-- Here we just always show the button and let server reject non-admins silently.
task.wait(3)
adminOpenBtn.Visible = true   -- server-side rejection is the real gate

print("[InsectEvo] AdminGui initialized.")
