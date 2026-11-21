# Central Exchange — physically motivated retail lighting (vertical slice phase 4)

**Target:** Two real 3D walk-in storefronts shipped in [phase 3](CENTRAL_EXCHANGE_WALK_IN_STOREFRONTS.md), Brickwater **(-1,0), lot 1**, and Afterhours **(0,0), lot 0**; continuation of [visual/block geometry issue #21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21).

## Why this pass exists

The photo-PBR retail glTFs already had two modeled warm ceiling lens fixtures per store, but their emissive texture/material rendered only as a luminous object. They did not contribute any light to the real 3D room, its photographed displays or the sidewalk. The general-purpose city storefront light pool landed below the exterior fascia and did not match the source ceiling-lens position. At 22:07 the interior did not convincingly look occupied.

This pass moves real-time illumination to the actual imported source-owned emissive fixtures **without allocating additional real-time lights or doubling the city's normal street lighting**.

## Exact live-world geometry and lighting

`scripts/night_lighting.gd` already creates eight unshadowed, reusable `OmniLight3D` nodes: four slots serve physical streetlamp heads and four serve real shop signs. The two source photo-gltf retail entrances **borrow up to two of the four storefront slots**, and only when within **23 m** of the player; the other shop slots remain available for normal street signs. Outside that radius, all four slots revert to ordinary shop signs. No new lights are created on city chunk stream load or unload.

Each new fixture maps to a real, permanently installed lens in the two static glTFs:

| Item | Brickwater | Afterhours |
| --- | --- | --- |
| World-space x | -18.5 m | +18.5 m |
| Emissive source local center | z = 1.08 m; y = 3.07 m | z = 1.08 m; y = 3.07 m |
| Real lamp world-space center | x = -18.5, y = 3.06, z = 15.20 | x = +18.5, y = 3.06, z = 15.20 |
| Color | warm amber/cream, #FFE0B8 | gentle warm neutral, #FFE5C8 |
| Range | 6.2 m (limited local spill) | 6.2 m (limited local spill) |
| Full-night energy | 1.55 (Godot-relative; not measured lux) | 1.55 |
| Shadows | disabled (existing pool performance policy) | disabled |

Each light is placed **16 cm below** the actual photographed 3D ceiling lens group, not at the road intersection center, then shares the existing day/night controller's eased lighting factor. Within the finite 6.2 m radius, it can illuminate actual photographed floor/sidewalk/steel/brick around the recessed doorway. Lenses themselves still emit warm light as modeled, but the nearby architecture now receives actual real-time illumination.

**Intentional compromises:** no new shadow maps, GI, screen-space reflection, volumetric fog, texture relighting or unbounded light loops. The unshadowed Omni pool can leak some light through surrounding walls; the short radius and under-lens position reduce the issue, but do not claim physically accurate occlusion. Further improvements (measured SpotLight cones or shadow-enabled area proxies) require a real Windows Forward+ GPU benchmark and native visual comparisons.

## Invariants and test contracts

The existing scene uses the same eight `OmniLight3D` objects, original four streetlight slots, all canonical street poles/regular shop-sign positions, full set of 81 traffic signals, persistent source-owned shop/doorway glTFs, their saved lot indices, old v1/v2 manifest, 60 Hz physics and world streaming. Loading and freeing a distant neighborhood never creates a permanent in-place lamp or increases VRAM light budget. No changes are made to `DayNight`'s color grading, F11 A/B tonemapping, weather/reflection or current interior H transitions.

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/practical_lighting_smoke.gd
godot --headless --path . --script res://tests/central_exchange_shop_lighting_smoke.gd
godot --headless --path . --script res://tests/central_exchange_walk_in_shops_smoke.gd
```

The new test **boots the real playable Godot world**, checks both imported glTFs have actual luminous fixture geometry, verifies the two exact fixed world anchors, confirms two shop portals + active street poles + active shop signs all fit the existing **eight pooled, non-shadowed** lights, verifies daytime OFF, both 19:15 dusk and midnight ON, falls away correctly with distance, then forces full city chunk unload/reload and asserts the exact same pooled light nodes are reused and save/traffic identity unchanged. Existing practical-light tests now recognize only the two new exact physical ceiling-lens anchors, with all other fixture positions required to remain unchanged.

## Native visual validation to do

At each **Central Exchange** shop, compare real in-game **F10** screenshot pairs at **12:00, 19:15 and 22:07**, from the same outside 16:9 street-eye viewpoint at x ±18.5/z 13.0 and inside the portal at z 16.2. At night inspect visible photographed display shelves, under-canopy sidewalk warmth, continuity between luminous lenses and pool, and unnatural light bleed through brick/steel side walls or the roof. Pair before/after **F8** frametime traces on the user's RTX 3060 12 GB at 1080p, including cold-stream and warm-loaded camera turns. GPU evidence is **not** obtainable from GitHub headless CI or Windows binary export alone; **photoreal/60fps signoff remains pending**.

Once native visual evidence validates this composition, the next work can include limited commerce/quest/NPC shop interactions and actual authored lighting at the venue identity level rather than adding generic decorative neon.
