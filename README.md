# NIGHTGRID: AFTERHOURS

**An original 3D, open-world night-courier and crime sandbox prototype.** A neon city, parked vehicles, delivery missions and basic police pursuit — no copied Rockstar assets.

## Play the first prototype

1. Download [Godot 4.3+](https://godotengine.org/download/), standard version (no .NET).
2. Clone the repository, or select **Code → Download ZIP** on GitHub.
3. Open `project.godot` in Godot.
4. Press **F5** to play. Head for the amber pickup beacon; deliver the package to the cyan destination and earn money.

| Controls | Action |
|---|---|
| WASD | Walk / drive |
| Mouse | Orbit third-person camera |
| Shift | Sprint on foot |
| Space | Jump on foot / handbrake in a car |
| E | Enter nearby parked car / exit when stopped |
| Escape | Release or capture mouse |

### Included in the first vertical slice

- Procedurally generated street grid with **four neighborhoods**: Vesper Market, Glassline, Brickwater, and Afterhours. Each has distinct skylines, facade shapes, storefronts and street dressing.
- Third-person character with walking, sprinting, jumping and a follow camera.
- Eight parked arcade-drivable cars with collisions.
- Repeatable courier pickups and deliveries, cash payouts.
- Heat / wanted level, pursuing police, health damage, hospital respawn.
- HUD with objective, cash, health, speed, and a city minimap.
- Procedural details: crossings, painted roads, lit windows, rooftop HVAC/water towers, fire escapes, storefront names, market stalls, signal units, benches, vending machines, hydrants, trees, crates, service alleys and distant skyline.
- Original procedural placeholder graphics — no external art/audio dependencies. For neighborhood layout and technical notes, see [City Atlas](docs/CITY.md).

### Known limits

**Prototype, not a finished release:** this has not been manually tested in a Godot editor on a gaming PC. CI runs file checks, a Godot 4.3 import, and city composition assertions and a short headless smoke test, but gameplay feel needs hands-on review. There are no civilian traffic AI, pedestrians, complex missions, interiors, multiplayer, audio or saves yet. Driving uses an arcade `CharacterBody3D` instead of suspension/tire physics.

Godot uses its Compatibility renderer here, **not DirectX**. This was chosen for rapid iteration on Windows/Linux. A native DirectX engine is possible later if justified by a clear requirement.

## Roadmap

1. **0.1 — Playable:** validate the scripts and vehicle collisions on real hardware; add pause/menu, sound and a downloadable Windows build.
2. **0.2 — Living city:** streamed districts, pedestrians, moving traffic, lighting/weather, shops and persistence.
3. **0.3 — Emergent systems:** more jobs, vehicle ownership, police escalation, NPC schedules and a stronger identity.
4. **0.4+ — Expand responsibly:** performance budgets, dense district content, accessibility, controller support and modding.

## Download a Windows build

On GitHub, open **Actions → Windows playtest build → latest successful run**, then download the `nightgrid-afterhours-windows-x64` artifact. Unzip and launch `NightGrid-Afterhours.exe`. The game is an alpha and may trigger Windows SmartScreen because the executable is unsigned. The workflow builds from this source; it is not a standalone release yet.

## Local checks

```bash
python3 tools/check_project.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/city_smoke.gd
godot --headless --path . --quit-after 90
```

Source is deliberately unlicensed until the owner chooses an explicit license. All code/assets are original starter work.
