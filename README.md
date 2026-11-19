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
| T | Advance one in-game hour (debug) |
| Y | Pause/resume time (debug) |
| F3 | Toggle local FPS/frame-time overlay for RTX 3060 tuning |
| F4 | Toggle screen-space reflections for performance comparisons |
| F | Board/alight a stopped bus or M-Line train at marked stops |
| F5 | Save current world to slot 1 |
| F6 | New Game (new world seed; does not overwrite saved slot) |
| F9 | Reload saved world seed and player/traffic state |
| G | Interact with nearby social or civic business; G closes menu |
| 1 / 2 | Purchase services or accept/deliver local side jobs and freight contracts |
| R | Use purchased food provisions on foot to restore health |

### Outer districts, civil services and preserved world layouts

- **Four new districts**: North Quay (markets and harbor services), West Docks (freight and workshops), Horizon Gardens (housing, clinics and parks), Southworks (civic offices, utilities and industrial deliveries).
- **Eight protected landmarks total**; **64 total blocks** and **112 authored or seed-selected building profiles**—the 6×6 downtown is kept intact while a new ring is added.
- **16 functional public-service sites**: grocers, clinics, emergency/fire services, libraries, warehouses, garages, civic service desks and a power annex. Press **G** near a service counter; use **1** to buy provisions, recover, repair vehicles or check records; use **2** for four one-time freight contracts.
- **R** consumes a purchased take-away ration pack on foot (+25 health). Park damaged cars by garages to repair them.
- **81 road signals**, **25 civilian cars**, **4 boardable buses** with **16 stops**, **5 elevated rail stations** and coverage in all eight districts.
- **Real world persistence**: a world seed *and an exact 112-building manifest* are saved in slot 1; save/load never rerolls existing chosen parcels. New Game F6 chooses a new layout, while fixed roads/landmarks/shops remain fixed.
- [Expansion and public services guide](docs/EXPANSION.md). These are highly dressed streetfront destinations and accessible public plazas, **not full indoor interiors yet**.

### Social life after dark

- **12 fixed, named destinations** across Vesper Market, Glassline, Brickwater and Afterhours: three cafes, three late-night food stalls, three bars and three nightclubs.
- Each has authored streetfront decor, hosts, its own schedule, lighting, and proximity-triggered original ambient audio. Counter details, tables, shelves, bowls, signage, marquees and silhouettes use the graphic-noir palette, not generic storefront repetition.
- Approach on foot and press **G** for the local menu. Use **1** to purchase useful health or police-heat services, **2** to take/complete one of four authored cross-district side jobs. Hours and contacts matter.
- Venue pins and active side-job targets appear on the minimap. Side-job progress survives the existing **F5/F9** save/load and preserves old save compatibility.
- See the [Morrow Bay venue and side-story guide](docs/VENUES.md). These are streetfront social spaces, **not enterable interiors yet**.

### City transport and persistent worlds

- **Morrow Bay City Loop:** two low-poly buses, eight far-side curb stops, player boarding and alighting with **F**.
- **M-Line:** moving two-car elevated train, three fixed stations and marked street-level entrances.
- **Traffic:** 17 NPC cars follow right-hand lanes, traffic signals with yellow/all-red clearance, speed limits and basic safe following distance.
- **New Game seeds:** roads, landmarks and transit remain authored; eight curated alternative building parcels, decorative details and flora use the saved seed. **F5** saves seed + player/world state, **F9** restores, and **F6** creates a fresh seeded world without overwriting the previous save.
- Full infrastructure design and limitations: [Transport network](docs/TRANSPORT.md).

### Included in the first vertical slice

- Authored Morrow Bay geography expanded to **8 districts / 64 blocks**, with eight stable landmarks and 112 seeded-and-saved building profiles; roads and public destinations stay fixed in **four neighborhoods**: Vesper Market, Glassline, Brickwater, and Afterhours. Each has distinct skylines, facade shapes, storefronts and street dressing.
- Third-person character with walking, sprinting, jumping and a follow camera.
- Eight parked arcade-drivable cars with collisions.
- Repeatable courier pickups and deliveries, cash payouts.
- Heat / wanted level, pursuing police, health damage, hospital respawn.
- HUD with objective, cash, health, speed, and a city minimap.
- Procedural details: crossings, painted roads, lit windows, rooftop HVAC/water towers, fire escapes, storefront names, market stalls, signal units, benches, vending machines, hydrants, trees, crates, service alleys and distant skyline.
- Real 24-hour lighting cycle (24 real minutes), two sky palettes blended through dawn/dusk, and nighttime neon response. Press **T** to skip one hour and **Y** to pause the clock.
- Purpose-planted low-poly flora: ginkgo, pine, flowering plum, ficus, shrubs, flowers and district planters, using batched GPU instancing.
- Four fixed locations: Lantern Court, Helix Terminal, Foundry Commons and Sable Square, ready to anchor future story missions. See the [Morrow Bay World Bible](docs/WORLD_BIBLE.md).
- Cached 128px tiled PBR surface maps (brick, concrete, pavers, metal, glass, wet asphalt), handcrafted wet-street reflective patches and 8 pooled nighttime lights; see [Rendering guide](docs/RENDERING.md).
- Original procedural placeholder graphics — no external art/audio dependencies. For neighborhood layout and technical notes, see [City Atlas](docs/CITY.md).

### Known limits

**Prototype, not a finished release:** this has not been manually tested in a Godot editor on a gaming PC. CI runs file checks, a Godot 4.3 import, and city composition assertions and a short headless smoke test, but gameplay feel needs hands-on review. There are now basic lane-following NPC traffic, a single save slot and public transit, but no pedestrians, complex missions, interiors, multiplayer or audio yet. Driving uses an arcade `CharacterBody3D` instead of suspension/tire physics.

Godot now uses the **Forward+ Vulkan renderer** for SSR and glow (with F4 reflection toggle), **not DirectX**. This was chosen for rapid iteration on Windows/Linux. A native DirectX engine is possible later if justified by a clear requirement.

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
godot --headless --path . --script res://tests/world_systems_smoke.gd
godot --headless --path . --script res://tests/render_smoke.gd
godot --headless --path . --script res://tests/transport_smoke.gd
godot --headless --path . --script res://tests/expansion_smoke.gd
godot --headless --path . --quit-after 90
```

Source is deliberately unlicensed until the owner chooses an explicit license. All code/assets are original starter work.
