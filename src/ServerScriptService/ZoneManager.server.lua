-- ZoneManager.server.lua
-- Manages safe zones (visual + enforcement), portals between zones,
-- player zone-change tracking, and character teleportation.
-- Exposes _G.TeleportToZone(player, zoneKey) for use by GameServer/Rebirth.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local ZoneData  = require(ReplicatedStorage:WaitForChild("ZoneData"))
local LevelData = require(ReplicatedStorage:WaitForChild("LevelData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Portal cooldown per player (prevent rapid double-teleport)
local portalCooldowns = {}

-- ─────────────────────────────────────────
-- Teleport a player's character to a zone spawn
-- ─────────────────────────────────────────
local function teleportCharacter(player, zoneKey)
	local zone = ZoneData.Zones[zoneKey]
	if not zone then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Slightly random offset inside safe zone so players don't stack
	local offset = Vector3.new(math.random(-12, 12), 2, math.random(-12, 12))
	hrp.CFrame   = CFrame.new(zone.spawn + offset)
end

_G.TeleportToZone = function(player, zoneKey)
	if not ZoneData.Zones[zoneKey] then return end
	teleportCharacter(player, zoneKey)
	if _G.SetPlayerZone then
		_G.SetPlayerZone(player, zoneKey)
	end
end

-- ─────────────────────────────────────────
-- Build safe-zone visual marker (glowing circle on ground)
-- ─────────────────────────────────────────
local function buildSafeZoneMarker(zone)
	local r  = zone.safeZoneRadius or ZoneData.SafeZoneRadius
	local cx = zone.spawn.X
	local cz = zone.spawn.Z

	-- Outer glow ring (flat neon cylinder)
	local outer        = Instance.new("Part")
	outer.Name         = "SafeZone_" .. zone.key
	outer.Shape        = Enum.PartType.Cylinder
	outer.Size         = Vector3.new(0.5, r * 2, r * 2)
	outer.Material     = Enum.Material.Neon
	outer.Color        = Color3.fromRGB(100, 220, 100)
	outer.Transparency = 0.65
	outer.Anchored     = true
	outer.CanCollide   = false
	outer.CastShadow   = false
	outer.CFrame       = CFrame.new(cx, 0.3, cz) * CFrame.Angles(0, 0, math.pi / 2)
	outer.Parent       = workspace

	-- Inner solid disc (slightly smaller)
	local inner        = Instance.new("Part")
	inner.Name         = "SafeZoneFloor_" .. zone.key
	inner.Shape        = Enum.PartType.Cylinder
	inner.Size         = Vector3.new(0.3, (r - 4) * 2, (r - 4) * 2)
	inner.Material     = Enum.Material.Neon
	inner.Color        = Color3.fromRGB(80, 255, 80)
	inner.Transparency = 0.82
	inner.Anchored     = true
	inner.CanCollide   = false
	inner.CastShadow   = false
	inner.CFrame       = CFrame.new(cx, 0.2, cz) * CFrame.Angles(0, 0, math.pi / 2)
	inner.Parent       = workspace

	-- Billboard label above the safe zone
	local labelPart        = Instance.new("Part")
	labelPart.Name         = "SafeZoneLabel_" .. zone.key
	labelPart.Size         = Vector3.new(1, 1, 1)
	labelPart.Transparency = 1
	labelPart.Anchored     = true
	labelPart.CanCollide   = false
	labelPart.Position     = Vector3.new(cx, 5, cz)
	labelPart.Parent       = workspace

	local bb           = Instance.new("BillboardGui")
	bb.Size            = UDim2.new(0, 200, 0, 40)
	bb.StudsOffset     = Vector3.new(0, 8, 0)
	bb.AlwaysOnTop     = false
	bb.MaxDistance     = 80
	bb.Parent          = labelPart

	local lbl          = Instance.new("TextLabel")
	lbl.Size           = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lbl.BackgroundTransparency = 0.5
	lbl.Text           = "🛡 " .. zone.displayName .. " — Safe Zone\n⚠ Lvs " .. zone.minLevel .. "–" .. zone.maxLevel
	lbl.TextColor3     = Color3.fromRGB(100, 255, 100)
	lbl.Font           = Enum.Font.GothamBold
	lbl.TextScaled     = true
	lbl.Parent         = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
end

-- ─────────────────────────────────────────
-- Build a portal object
-- ─────────────────────────────────────────
local function buildPortal(portalDef, sourceZoneKey)
	local destZone = ZoneData.Zones[portalDef.destination]
	if not destZone then return end

	local pos  = portalDef.position

	-- Portal pillar
	local pillar        = Instance.new("Part")
	pillar.Name         = "Portal_" .. sourceZoneKey .. "_to_" .. portalDef.destination
	pillar.Size         = Vector3.new(6, 14, 1.5)
	pillar.Material     = Enum.Material.Neon
	pillar.Color        = destZone.color
	pillar.Transparency = 0.35
	pillar.Anchored     = true
	pillar.CanCollide   = false
	pillar.CastShadow   = false
	pillar.Position     = pos + Vector3.new(0, 7, 0)
	pillar.Parent       = workspace

	-- Spinning ring around pillar
	local ring          = Instance.new("Part")
	ring.Shape          = Enum.PartType.Cylinder
	ring.Size           = Vector3.new(0.4, 9, 9)
	ring.Material       = Enum.Material.Neon
	ring.Color          = destZone.color
	ring.Transparency   = 0.5
	ring.Anchored       = true
	ring.CanCollide     = false
	ring.CastShadow     = false
	ring.CFrame         = CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent         = workspace

	-- Touch detector (invisible hitbox at ground level)
	local detector      = Instance.new("Part")
	detector.Name       = "PortalTrigger_" .. sourceZoneKey .. "_to_" .. portalDef.destination
	detector.Size       = Vector3.new(8, 10, 8)
	detector.Transparency = 1
	detector.Anchored   = true
	detector.CanCollide = false
	detector.Position   = pos + Vector3.new(0, 5, 0)
	detector.Parent     = workspace

	-- Label
	local bb           = Instance.new("BillboardGui")
	bb.Size            = UDim2.new(0, 220, 0, 60)
	bb.StudsOffset     = Vector3.new(0, 12, 0)
	bb.AlwaysOnTop     = false
	bb.MaxDistance     = 60
	bb.Parent          = pillar

	local lbl          = Instance.new("TextLabel")
	lbl.Size           = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lbl.BackgroundTransparency = 0.45
	lbl.Text           = destZone.emoji .. " " .. destZone.displayName
		.. "\n⚠ Requires Level " .. portalDef.minLevel
	lbl.TextColor3     = Color3.new(1, 1, 1)
	lbl.Font           = Enum.Font.GothamBold
	lbl.TextScaled     = true
	lbl.Parent         = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)

	-- Spin animation
	task.spawn(function()
		while ring and ring.Parent do
			ring.CFrame = ring.CFrame * CFrame.Angles(0, 0.03, 0)
			task.wait(0.04)
		end
	end)

	-- Touch handler
	detector.Touched:Connect(function(hit)
		local char   = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		-- Cooldown
		local now = tick()
		if (portalCooldowns[player] or 0) + 3 > now then return end
		portalCooldowns[player] = now

		local data = _G.PlayerData and _G.PlayerData[player]
		if not data then return end

		-- Level check
		if data.level < portalDef.minLevel then
			-- Flash pillar red briefly to signal locked
			local origColor = pillar.Color
			pillar.Color = Color3.fromRGB(255, 60, 60)
			task.delay(0.8, function()
				if pillar and pillar.Parent then pillar.Color = origColor end
			end)
			-- Notify player
			Remotes:FindFirstChild("ZoneChanged"):FireClient(player, {
				zone        = data.currentZone,
				displayName = "Locked — Need Level " .. portalDef.minLevel,
				locked      = true,
			})
			return
		end

		-- Teleport
		_G.TeleportToZone(player, portalDef.destination)
	end)
end

-- ─────────────────────────────────────────
-- Zone-aware lighting adjustments
-- ─────────────────────────────────────────
local zoneLighting = {
	Grassland = { ambient = Color3.fromRGB(100, 120, 80),  fog = Color3.fromRGB(180, 210, 160), fogEnd = 1200 },
	Wetland   = { ambient = Color3.fromRGB(60,  100, 120), fog = Color3.fromRGB(120, 160, 180), fogEnd = 900  },
	Mushroom  = { ambient = Color3.fromRGB(60,  20,  80),  fog = Color3.fromRGB(80,  30,  100), fogEnd = 600  },
	Volcanic  = { ambient = Color3.fromRGB(120, 50,  20),  fog = Color3.fromRGB(200, 80,  20),  fogEnd = 700  },
	Crystal   = { ambient = Color3.fromRGB(20,  20,  60),  fog = Color3.fromRGB(40,  20,  80),  fogEnd = 800  },
}

-- Track per-player zone and update lighting (last connected player wins — could be
-- improved with per-player sky in a real game, but global lighting is fine for now)
local function updateLightingForZone(zoneKey)
	local lt = zoneLighting[zoneKey]
	if not lt then return end
	local Lighting = game:GetService("Lighting")
	Lighting.Ambient    = lt.ambient
	Lighting.FogColor   = lt.fog
	Lighting.FogEnd     = lt.fogEnd
	Lighting.FogStart   = lt.fogEnd * 0.5
end

-- Detect zone change each heartbeat
local playerZoneCache = {}

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local detectedZone = ZoneData.GetZone(hrp.Position)
			if detectedZone and detectedZone ~= playerZoneCache[player] then
				playerZoneCache[player] = detectedZone
				-- Update server data
				if _G.SetPlayerZone then
					_G.SetPlayerZone(player, detectedZone)
				end
				updateLightingForZone(detectedZone)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerZoneCache[player] = nil
	portalCooldowns[player] = nil
end)

-- ─────────────────────────────────────────
-- Build all safe zones and portals on startup
-- ─────────────────────────────────────────
task.wait(1)  -- wait for MapBuilder to finish

for _, zoneKey in ipairs(ZoneData.ZoneOrder) do
	local zone = ZoneData.Zones[zoneKey]
	if zone then
		-- Safe zone visuals
		buildSafeZoneMarker(zone)

		-- Portals
		if zone.portals then
			for _, portalDef in ipairs(zone.portals) do
				pcall(buildPortal, portalDef, zoneKey)
			end
		end
	end
end

print("[InsectEvo] ZoneManager: safe zones and portals built for "
	.. #ZoneData.ZoneOrder .. " zones.")
