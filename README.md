# 🐛 Insect Evolution — Roblox Game

A Roblox evolution game where players choose an insect, collect food, defeat enemies, and evolve through **5 stages** into a powerful final form.

---

## 🦋 Evolution Paths

| Path | Stages | Final Form | Specialty |
|------|--------|-----------|-----------|
| **Ant** | 5 | Queen Ant | Summons worker allies |
| **Beetle** | 5 | Titan Beetle | Iron shell, charge attacks |
| **Butterfly** | 5 | Moth Emperor | Flight, moonbeam laser |
| **Bee** | 5 | Queen Hornet | Venom cloud, royal swarm |
| **Spider** | 5 | Goliath Spider | Web traps, giant mega-web |

---

## 🎮 How to Play

1. **Choose** your insect path at the selection screen.
2. **Collect food** (walk over glowing items) to gain XP.
3. **Attack enemies** by clicking/tapping on them.
4. **Evolve** automatically when your XP bar fills — you grow stronger!
5. **Use abilities** with keys `1 2 3 4` (or `Q E R F`).

---

## 🗺️ World Zones

- **Forest** — Dense trees providing cover
- **Mushroom Clearing** — High XP food spawns
- **Rocky Area** — Ambush spots for spiders/beetles
- **Pond** — Slows movement, butterfly advantage
- **Spawn Pads** — Coloured by insect type

---

## ⚔️ Abilities (examples)

| Ability | Insect | Effect |
|---------|--------|--------|
| Acid Spray | Ant (Stage 3+) | AOE acid blast on nearby enemies |
| Summon Workers | Queen Ant | Spawns 3 ally ants for 15s |
| Horn Charge | Stag Beetle | Rush forward, knock back all enemies |
| Iron Shell | Titan Beetle | Temporary invincibility |
| Silk Shot | Caterpillar+ | Projectile that slows enemies |
| Fly | Butterfly / Bee | Passive: increased jump power |
| Moonbeam | Moth Emperor | Giant forward laser beam |
| Venom Cloud | Hornet+ | Toxic AOE cloud for 5s |
| Royal Decree | Queen Hornet | Destroys ALL enemies on map |
| Web Trap | Spider+ | Places sticky web trap |
| Pounce | Wolf Spider+ | Leap at enemies |
| Mega Web | Goliath Spider | 50-stud web blanket, freezes enemies |

---

## 🛠️ Installation

### Using Rojo (recommended)

```bash
# Install Rojo (https://rojo.space)
rojo serve default.project.json
```

Then connect from **Roblox Studio → Rojo plugin**.

### Manual Installation

Copy each file into the matching Roblox service:

| File | Roblox Location |
|------|----------------|
| `src/ReplicatedStorage/*.lua` | `ReplicatedStorage` (as `ModuleScript`) |
| `src/ServerScriptService/GameServer.server.lua` | `ServerScriptService` (as `Script`) |
| `src/ServerScriptService/AbilityHandler.server.lua` | `ServerScriptService` (as `Script`) |
| `src/ServerScriptService/MapBuilder.server.lua` | `ServerScriptService` (as `Script`) |
| `src/StarterPlayer/StarterPlayerScripts/GameClient.client.lua` | `StarterPlayer > StarterPlayerScripts` (as `LocalScript`) |
| `src/StarterGui/HUD.client.lua` | `StarterGui` (as `LocalScript`) |
| `src/StarterGui/InsectSelect.client.lua` | `StarterGui` (as `LocalScript`) |

> **Script type rules:**
> - `*.server.lua` → Insert as **Script** (server)
> - `*.client.lua` → Insert as **LocalScript** (client)
> - All others in `ReplicatedStorage` → Insert as **ModuleScript**

---

## 📁 Project Structure

```
Games/
├── default.project.json          ← Rojo project file
├── README.md
└── src/
    ├── ReplicatedStorage/
    │   ├── InsectData.lua        ← All insect stats, 5 paths × 5 stages
    │   ├── GameConfig.lua        ← Tuning constants
    │   └── RemoteEvents.lua      ← Remote event registry
    ├── ServerScriptService/
    │   ├── GameServer.server.lua ← Core: XP, evolution, food, data save
    │   ├── AbilityHandler.server.lua ← Ability activation & effects
    │   └── MapBuilder.server.lua ← World generation
    ├── StarterPlayer/
    │   └── StarterPlayerScripts/
    │       └── GameClient.client.lua ← Input, attack, highlight
    └── StarterGui/
        ├── HUD.client.lua        ← Health/XP bars, ability slots, popups
        └── InsectSelect.client.lua ← Insect selection screen
```

---

## ⚙️ Configuration

Edit `src/ReplicatedStorage/GameConfig.lua` to tune:

- `FoodSpawnCount` / `FoodRespawnRate` — food frequency
- `EnemySpawnCount` / `EnemyRespawnRate` — enemy difficulty
- `AttackCooldown` / `AttackRange` — combat feel
- `AbilityCooldowns` — per-ability cooldown seconds
- `PathXPMultiplier` — per-path difficulty balance

Edit `src/ReplicatedStorage/InsectData.lua` to:

- Add new insect paths (add a new key to `Evolutions`)
- Add more evolution stages (append to the path array)
- Adjust stats per stage (`walkSpeed`, `damage`, `maxHealth`, etc.)
- Add new abilities (add name to stage's `abilities` table, then implement in `AbilityHandler`)
