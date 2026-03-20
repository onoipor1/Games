-- WeatherClient.client.lua
-- Applies weather Lighting changes and a rain/storm particle effect
-- when the server broadcasts a WeatherChanged event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")

-- ─────────────────────────────────────────
-- Tween all Lighting properties smoothly
-- ─────────────────────────────────────────
local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function applyWeather(weatherType)
	local settings = GameConfig.WeatherSettings[weatherType]
		          or GameConfig.WeatherSettings.Clear

	TweenService:Create(Lighting, tweenInfo, {
		Ambient        = settings.ambient,
		OutdoorAmbient = settings.outdoorAmbient,
		FogColor       = settings.fogColor,
		FogEnd         = settings.fogEnd,
		FogStart       = settings.fogStart,
		Brightness     = settings.brightness,
	}):Play()

	Lighting.TimeOfDay = settings.timeOfDay
end

-- ─────────────────────────────────────────
-- Rain / storm overlay (simple screen tint)
-- ─────────────────────────────────────────
local Players   = game:GetService("Players")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local weatherOverlay              = Instance.new("ScreenGui")
weatherOverlay.Name               = "WeatherOverlay"
weatherOverlay.ResetOnSpawn       = false
weatherOverlay.IgnoreGuiInset     = true
weatherOverlay.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling
weatherOverlay.Parent             = playerGui

local tintFrame                   = Instance.new("Frame")
tintFrame.Size                    = UDim2.new(1, 0, 1, 0)
tintFrame.BorderSizePixel         = 0
tintFrame.BackgroundTransparency  = 1
tintFrame.BackgroundColor3        = Color3.fromRGB(0, 0, 0)
tintFrame.Parent                  = weatherOverlay

-- Event banner
local eventBanner                 = Instance.new("Frame")
eventBanner.Name                  = "EventBanner"
eventBanner.Size                  = UDim2.new(1, 0, 0, 40)
eventBanner.Position              = UDim2.new(0, 0, 0, -44)
eventBanner.BackgroundColor3      = Color3.fromRGB(40, 10, 10)
eventBanner.BackgroundTransparency = 0.15
eventBanner.BorderSizePixel       = 0
eventBanner.Parent                = weatherOverlay

local eventLabel                  = Instance.new("TextLabel")
eventLabel.Size                   = UDim2.new(1, 0, 1, 0)
eventLabel.BackgroundTransparency = 1
eventLabel.TextColor3             = Color3.fromRGB(255, 200, 80)
eventLabel.Font                   = Enum.Font.GothamBold
eventLabel.TextSize               = 18
eventLabel.Parent                 = eventBanner

local eventSubLabel               = Instance.new("TextLabel")
eventSubLabel.Size                = UDim2.new(1, 0, 0, 16)
eventSubLabel.Position            = UDim2.new(0, 0, 1, 2)
eventSubLabel.BackgroundTransparency = 1
eventSubLabel.TextColor3          = Color3.fromRGB(200, 200, 200)
eventSubLabel.Font                = Enum.Font.Gotham
eventSubLabel.TextSize            = 13
eventSubLabel.Parent              = eventBanner

local function showEventBanner(name, description)
	eventLabel.Text    = name
	eventSubLabel.Text = description

	-- Slide down
	TweenService:Create(eventBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back),
		{ Position = UDim2.new(0, 0, 0, 0) }):Play()

	-- Slide back up after 6 seconds
	task.delay(6, function()
		TweenService:Create(eventBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
			{ Position = UDim2.new(0, 0, 0, -44) }):Play()
	end)
end

-- ─────────────────────────────────────────
-- Weather type → overlay tint
-- ─────────────────────────────────────────
local tintByWeather = {
	Clear      = { color = Color3.fromRGB(0,0,0),        alpha = 1.0 },
	Rainy      = { color = Color3.fromRGB(20, 30, 50),   alpha = 0.82 },
	Storm      = { color = Color3.fromRGB(10, 10, 30),   alpha = 0.72 },
	GoldenHour = { color = Color3.fromRGB(255, 180, 60), alpha = 0.90 },
	BloodMoon  = { color = Color3.fromRGB(80, 0, 0),     alpha = 0.80 },
}

local function setTint(weatherType)
	local t = tintByWeather[weatherType] or tintByWeather.Clear
	TweenService:Create(tintFrame, TweenInfo.new(2), {
		BackgroundColor3       = t.color,
		BackgroundTransparency = t.alpha,
	}):Play()
end

-- ─────────────────────────────────────────
-- Lightning flash effect (Storm weather)
-- ─────────────────────────────────────────
local flashGui                    = Instance.new("Frame")
flashGui.Size                     = UDim2.new(1, 0, 1, 0)
flashGui.BackgroundColor3         = Color3.new(1, 1, 1)
flashGui.BackgroundTransparency   = 1
flashGui.BorderSizePixel          = 0
flashGui.ZIndex                   = 15
flashGui.Parent                   = weatherOverlay

local function doLightningFlash()
	TweenService:Create(flashGui, TweenInfo.new(0.05), { BackgroundTransparency = 0.3 }):Play()
	task.wait(0.05)
	TweenService:Create(flashGui, TweenInfo.new(0.15), { BackgroundTransparency = 1.0 }):Play()
end

-- Listen for DamageDealt from lightning (large damage at 0,0,0 = lightning signal)
Remotes:FindFirstChild("DamageDealt").OnClientEvent:Connect(function(data)
	if data and data.isLightning then
		doLightningFlash()
	end
end)

-- ─────────────────────────────────────────
-- Remote handlers
-- ─────────────────────────────────────────
Remotes:FindFirstChild("WeatherChanged").OnClientEvent:Connect(function(weatherType)
	applyWeather(weatherType)
	setTint(weatherType)
end)

Remotes:FindFirstChild("EventChanged").OnClientEvent:Connect(function(data)
	if data and data.name and data.name ~= "None" then
		showEventBanner(data.name, data.description or "")
	end
end)

-- Apply default clear weather on join
applyWeather("Clear")

print("[InsectEvo] WeatherClient initialized.")
