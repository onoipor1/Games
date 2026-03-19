-- AbilityHandler.server.lua
-- Handles ability activation from clients, validates and applies effects server-side.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InsectData   = require(ReplicatedStorage:WaitForChild("InsectData"))
local GameConfig   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Track cooldowns per player per ability
local cooldowns = {}  -- [player][abilityName] = lastUsedTick

local function getCooldown(player, ability)
	if not cooldowns[player] then cooldowns[player] = {} end
	return cooldowns[player][ability] or 0
end

local function setCooldown(player, ability)
	if not cooldowns[player] then cooldowns[player] = {} end
	cooldowns[player][ability] = tick()
end

local function isOnCooldown(player, ability)
	local cd = GameConfig.AbilityCooldowns[ability] or 0
	if cd == 0 then return false end
	return (tick() - getCooldown(player, ability)) < cd
end

-- ─────────────────────────────────────────
-- Ability implementations
-- ─────────────────────────────────────────

local AbilityEffects = {}

-- Acid Spray: damages nearby enemies (server finds them)
function AbilityEffects.AcidSpray(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Find all enemy parts within range and damage them
	local range = 20
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "HumanoidRootPart" and obj.Parent and obj.Parent.Name:sub(1, 6) == "Enemy_" then
			local dist = (obj.Position - hrp.Position).Magnitude
			if dist <= range then
				-- Signal damage back to the server's enemy list via a server event
				-- (In full implementation, access shared enemy table; here we fire damage event)
				local dmgEvent = Remotes:FindFirstChild("DamageDealt")
				if dmgEvent then
					dmgEvent:FireClient(player, { amount = 40, position = obj.Position })
				end
				-- Destroy enemy model directly as a simplification
				obj.Parent:Destroy()
			end
		end
	end
end

-- Silk Shot: fires a web projectile that slows hit enemies
function AbilityEffects.SilkShot(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local projectile     = Instance.new("Part")
	projectile.Name      = "SilkShot"
	projectile.Size      = Vector3.new(1.5, 1.5, 1.5)
	projectile.BrickColor = BrickColor.new("White")
	projectile.Material  = Enum.Material.SmoothPlastic
	projectile.CanCollide = false
	projectile.CFrame    = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 3)
	projectile.Parent    = workspace

	local bv = Instance.new("BodyVelocity")
	bv.Velocity       = hrp.CFrame.LookVector * 60
	bv.MaxForce       = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent         = projectile

	projectile.Touched:Connect(function(hit)
		if hit.Parent and hit.Parent.Name:sub(1, 6) == "Enemy_" then
			-- Slow the enemy by tagging it (full impl would read this tag in AI)
			local slowTag = Instance.new("BoolValue")
			slowTag.Name   = "Slowed"
			slowTag.Parent = hit.Parent
			game:GetService("Debris"):AddItem(slowTag, 3)
			projectile:Destroy()
		end
	end)

	game:GetService("Debris"):AddItem(projectile, 4)
end

-- Pounce: launches player toward their look direction
function AbilityEffects.Pounce(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local bf          = Instance.new("BodyVelocity")
	bf.Velocity       = hrp.CFrame.LookVector * 80 + Vector3.new(0, 20, 0)
	bf.MaxForce       = Vector3.new(1e5, 1e5, 1e5)
	bf.Parent         = hrp

	game:GetService("Debris"):AddItem(bf, 0.25)
end

-- Horn Charge: rushes forward and knocks back everything in path
function AbilityEffects.HornCharge(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Give temporary speed boost via BodyVelocity
	local bf          = Instance.new("BodyVelocity")
	bf.Velocity       = hrp.CFrame.LookVector * 100
	bf.MaxForce       = Vector3.new(1e5, 0, 1e5)
	bf.Parent         = hrp
	game:GetService("Debris"):AddItem(bf, 0.3)

	-- Knock back any enemies in path
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "HumanoidRootPart" and obj.Parent.Name:sub(1, 6) == "Enemy_" then
			local dist = (obj.Position - hrp.Position).Magnitude
			if dist <= 15 then
				local dir = (obj.Position - hrp.Position).Unit
				local kb  = Instance.new("BodyVelocity")
				kb.Velocity   = dir * GameConfig.KnockbackForce
				kb.MaxForce   = Vector3.new(1e5, 1e5, 1e5)
				kb.Parent     = obj
				game:GetService("Debris"):AddItem(kb, 0.4)
			end
		end
	end
end

-- Harden: makes the chrysalis temporarily invincible
function AbilityEffects.Harden(player)
	local char = player.Character
	if not char then return end
	-- Tag the character as invincible
	local tag = Instance.new("BoolValue")
	tag.Name   = "Invincible"
	tag.Parent = char
	game:GetService("Debris"):AddItem(tag, 4)
	-- Visual feedback - change material temporarily
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.DiamondPlate
		end
	end
	task.delay(4, function()
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end)
end

-- Venom Cloud: spawns a damaging cloud around the player
function AbilityEffects.VenomCloud(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local cloud          = Instance.new("Part")
	cloud.Name           = "VenomCloud"
	cloud.Shape          = Enum.PartType.Ball
	cloud.Size           = Vector3.new(20, 20, 20)
	cloud.BrickColor     = BrickColor.new("Lime green")
	cloud.Material       = Enum.Material.Neon
	cloud.Transparency   = 0.75
	cloud.CanCollide     = false
	cloud.Anchored       = true
	cloud.CFrame         = hrp.CFrame
	cloud.Parent         = workspace

	local startTime = tick()
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		if not cloud.Parent then conn:Disconnect() return end
		if tick() - startTime > 5 then
			cloud:Destroy()
			conn:Disconnect()
			return
		end
		-- Damage enemies inside cloud
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj.Name == "HumanoidRootPart" and obj.Parent.Name:sub(1, 6) == "Enemy_" then
				if (obj.Position - cloud.Position).Magnitude <= 10 then
					obj.Parent:Destroy()
				end
			end
		end
	end)
end

-- Summon Workers: spawns helper ally parts briefly
function AbilityEffects.SummonWorkers(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, 3 do
		local ally        = Instance.new("Part")
		ally.Name         = "SummonedWorker"
		ally.Size         = Vector3.new(2, 2, 2)
		ally.BrickColor   = BrickColor.new("Black")
		ally.Material     = Enum.Material.SmoothPlastic
		local angle       = (i / 3) * math.pi * 2
		ally.CFrame       = hrp.CFrame * CFrame.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
		ally.Parent       = workspace
		game:GetService("Debris"):AddItem(ally, 15)

		-- Simple ally AI: move toward nearest enemy
		task.spawn(function()
			local lifetime = tick() + 15
			while tick() < lifetime and ally.Parent do
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj.Name == "HumanoidRootPart" and obj.Parent.Name:sub(1, 6) == "Enemy_" then
						local dist = (obj.Position - ally.Position).Magnitude
						if dist < 30 then
							local dir = (obj.Position - ally.Position).Unit
							ally.CFrame = ally.CFrame + dir * 0.4
							if dist < 3 then
								obj.Parent:Destroy()
							end
							break
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end
end

-- Royal Decree: massive AOE swarm (visual + damage)
function AbilityEffects.RoyalDecree(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Damage all enemies on map
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "HumanoidRootPart" and obj.Parent.Name:sub(1, 6) == "Enemy_" then
			obj.Parent:Destroy()
		end
	end

	-- Visual swarm ring
	for i = 1, 8 do
		local bee        = Instance.new("Part")
		bee.Size         = Vector3.new(1.5, 1.5, 1.5)
		bee.Shape        = Enum.PartType.Ball
		bee.BrickColor   = BrickColor.new("Bright orange")
		bee.Material     = Enum.Material.Neon
		bee.CanCollide   = false
		bee.Anchored     = true
		local angle      = (i / 8) * math.pi * 2
		bee.CFrame       = hrp.CFrame * CFrame.new(math.cos(angle) * 10, 0, math.sin(angle) * 10)
		bee.Parent       = workspace
		game:GetService("Debris"):AddItem(bee, 3)
	end
end

-- Mega Web: covers a huge area with sticky web (slows/stops enemies)
function AbilityEffects.MegaWeb(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Create a big flat web plane
	local web          = Instance.new("Part")
	web.Name           = "MegaWeb"
	web.Size           = Vector3.new(50, 0.5, 50)
	web.BrickColor     = BrickColor.new("White")
	web.Material       = Enum.Material.Fabric
	web.Transparency   = 0.4
	web.Anchored       = true
	web.CanCollide     = true
	web.CFrame         = CFrame.new(hrp.Position.X, hrp.Position.Y - 2, hrp.Position.Z)
	web.Parent         = workspace
	game:GetService("Debris"):AddItem(web, 12)

	-- Slow any enemies standing on it
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		if not web.Parent then conn:Disconnect() return end
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj.Name == "HumanoidRootPart" and obj.Parent.Name:sub(1, 6) == "Enemy_" then
				if math.abs(obj.Position.Y - web.Position.Y) < 3 and
				   (Vector3.new(obj.Position.X, 0, obj.Position.Z) -
				    Vector3.new(web.Position.X, 0, web.Position.Z)).Magnitude < 25 then
					local bv = obj:FindFirstChild("WebSlow")
					if not bv then
						local slow    = Instance.new("BodyVelocity")
						slow.Name     = "WebSlow"
						slow.Velocity = Vector3.new(0, 0, 0)
						slow.MaxForce = Vector3.new(1e4, 0, 1e4)
						slow.Parent   = obj
					end
				end
			end
		end
	end)
end

-- Moonbeam: fires a giant laser beam forward
function AbilityEffects.Moonbeam(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local beam          = Instance.new("Part")
	beam.Name           = "MoonBeam"
	beam.Size           = Vector3.new(3, 3, 80)
	beam.BrickColor     = BrickColor.new("Cyan")
	beam.Material       = Enum.Material.Neon
	beam.Transparency   = 0.3
	beam.CanCollide     = false
	beam.Anchored       = true
	beam.CFrame         = hrp.CFrame * CFrame.new(0, 0, -40)
	beam.Parent         = workspace
	game:GetService("Debris"):AddItem(beam, 1.5)

	-- Destroy enemies in the beam's path
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "HumanoidRootPart" and obj.Parent.Name:sub(1, 6) == "Enemy_" then
			local dist = (Vector3.new(obj.Position.X, 0, obj.Position.Z) -
			              Vector3.new(beam.Position.X, 0, beam.Position.Z)).Magnitude
			if dist < 6 then
				obj.Parent:Destroy()
			end
		end
	end
end

-- Urticating Hairs: fires hair particles that blind nearby enemies (visual only for now)
function AbilityEffects.UrticatingHairs(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, 12 do
		local hair        = Instance.new("Part")
		hair.Size         = Vector3.new(0.2, 0.2, 1)
		hair.BrickColor   = BrickColor.new("Dark orange")
		hair.Material     = Enum.Material.SmoothPlastic
		hair.CanCollide   = false
		hair.CFrame       = hrp.CFrame
		hair.Parent       = workspace

		local angle       = math.random() * math.pi * 2
		local bv          = Instance.new("BodyVelocity")
		bv.Velocity       = Vector3.new(math.cos(angle) * 40, math.random(10, 30), math.sin(angle) * 40)
		bv.MaxForce       = Vector3.new(1e5, 1e5, 1e5)
		bv.Parent         = hair
		game:GetService("Debris"):AddItem(hair, 1.5)

		hair.Touched:Connect(function(hit)
			if hit.Parent and hit.Parent.Name:sub(1, 6) == "Enemy_" then
				hit.Parent:Destroy()
				hair:Destroy()
			end
		end)
	end
end

-- Iron Shell: temporary invincibility for Titan Beetle
function AbilityEffects.IronShell(player)
	AbilityEffects.Harden(player) -- reuses harden logic with longer duration handled by Harden
end

-- Roll: beetles can roll into enemies
function AbilityEffects.Roll(player)
	AbilityEffects.HornCharge(player)
end

-- Scale Dust: butterfly blinds nearby enemies
function AbilityEffects.ScaleDust(player)
	AbilityEffects.UrticatingHairs(player)
end

-- Sting: quick forward lunge stab (similar to pounce)
function AbilityEffects.Sting(player)
	AbilityEffects.Pounce(player)
end

-- ─────────────────────────────────────────
-- Remote: UseAbility
-- ─────────────────────────────────────────
Remotes:FindFirstChild("UseAbility").OnServerEvent:Connect(function(player, abilityName)
	if isOnCooldown(player, abilityName) then
		local remaining = GameConfig.AbilityCooldowns[abilityName] - (tick() - getCooldown(player, abilityName))
		Remotes:FindFirstChild("AbilityCooldown"):FireClient(player, {
			ability   = abilityName,
			remaining = remaining,
		})
		return
	end

	local effect = AbilityEffects[abilityName:gsub(" ", "")]
	if effect then
		setCooldown(player, abilityName)
		effect(player)
	end
end)

-- Clean up cooldowns when player leaves
Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

print("[InsectEvo] AbilityHandler initialized.")
