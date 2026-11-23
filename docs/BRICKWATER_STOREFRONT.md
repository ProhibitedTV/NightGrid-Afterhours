# Night Shift Repairs

The existing west service-alley door in Brickwater block `(-2, 1)` now leads into Night Shift Repairs. The threshold is at approximately `(-89.45, 0.14, 87.90)`. **H / LB** opens or closes it, **G / X** at the counter opens the repair menu, and **1 / A** pays $24 to repair a damaged nearby car. Park on the street and walk to the counter. The door swings inward, pauses if a body occupies its sweep, and can be opened from either side. The DOCK 9 frontage mentioned in issue #135 is a separate business.

## World integration

The parcel dimensions, window, blade sign, rain shelter and alley geometry stay in place. The west parcel's first streaming stage preserves collision around a single 5.78 × 9.60 m ground-floor workshop. It creates the floor, walls, ceiling, glazing and fixture blockers alongside the moving leaf. The next stage attaches the workshop and door artwork. Walking inside uses the same player controller, world-space camera and city chunk as the alley. The occupied block stays inside the actor's required streaming ring.

The old display cavity gives way to a real display table and stock within the workshop. The room has a counter, fitted vice, pegboard, tool drawers, stock shelves and three suspended practical lights. One local audio voice plays the existing vent sound. The interior uses concrete footsteps and outside audio is filtered with distance from the open door. Public sidewalk routes stay outside.

The v1 save uses the normal world position. An optional boolean restores the door when the player saved nearby. A save overlapping the threshold reopens the leaf so the player has a clear route. Ordinary entry and exit use continuous player movement.

## Extending the pattern

Use `storefront_door.gd` on an `AnimatableBody3D` with the local hinge at the origin and the leaf extending along −Z. Supply fitted collision bounds in the parcel's collision stage. Attach the door art in the next stage and expose the interaction once its art is present. Leave standing room beyond the sweep and keep the opened door inside the parcel. Model a different envelope and furnishings against each business's actual windows, preserve the rest of the structural collision, and connect its counter to the appropriate service with a local reach check.

The workshop and leaf are original offline-authored glTF assets with 8,744 and 500 source triangles. Both reference the existing Poly Haven CC0 brick, steel, floor and apartment plaster textures in place. Godot generates workshop LODs and retains the full hinged leaf. [Asset source and hashes](../assets/models/nightgrid/night_shift_repairs/SOURCE.json) · [Rebuild script](../tools/author_brickwater_repair.py).

## Windows gameplay evidence

Godot 4.7.2 used Windows WASAPI and Forward+/Vulkan on the RTX 3060 at 1920×1080, with SSR, AO, fog and glow on, VSync off and seed 834726. The walkthrough exercised keyboard at 22:06 and mapped controller events at noon. Both paid exactly $24, restored vehicle condition to 100%, wrote and read an isolated v1 save, restored the courier at the same counter and walked back outside. The largest traversal physics step was 0.126 m. The outside cutoff settled near 1.64 kHz at the counter with the door open. Hands-on controller review remains open.

| Matched scene | Before | After |
| --- | --- | --- |
| Daylight entrance | [Frame](playtest/brickwater-storefront-135/before-01-day-front.jpg) | [Frame](playtest/brickwater-storefront-135/after-01-day-front.jpg) |
| 22:06 entrance | [Frame](playtest/brickwater-storefront-135/before-02-night-front.jpg) | [Frame](playtest/brickwater-storefront-135/after-02-night-front.jpg) |
| Stock behind original window | [Frame](playtest/brickwater-storefront-135/before-03-display.jpg) | [Frame](playtest/brickwater-storefront-135/after-03-display.jpg) |
| Dusk alley approach | [Frame](playtest/brickwater-storefront-135/before-04-alley-approach.jpg) | [Frame](playtest/brickwater-storefront-135/after-04-alley-approach.jpg) |

The interior has its own [workbench view](playtest/brickwater-storefront-135/after-07-workbench.jpg), [open doorway view](playtest/brickwater-storefront-135/after-08-interior-to-door.jpg) and [live repair panel](playtest/brickwater-storefront-135/after-keyboard-counter.jpg).

| F8 scenario | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms | >33.3 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Closed approach before | 18.52 | 21.26 | 23.89 | 23.89 | 83 | 0 |
| Closed approach after | 18.49 | 23.38 | 26.94 | 26.94 | 67 | 0 |
| Night keyboard approach, open and enter | 18.06 | 18.33 | 18.33 | 21.83 | 72 | 0 |
| Day mapped-controller approach, open and enter | 9.72 | 18.06 | 25.33 | 44.15 | 13 | 1 |

The closed approach uses the same input duration and camera. The fitted leaf changes the stopping point by 0.24 m. The full visits use different input, hour and warm state. Viewport GPU time sampled at the counter was 3.38–3.43 ms. The controller entry interval includes one unclassified frame above 33.3 ms. [F8 CSVs](playtest/brickwater-storefront-135/f8-traces.zip) · [Capture metadata](playtest/brickwater-storefront-135/after-capture.json) · [Windows export](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45096253459) · [Full preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45096253420).

To reproduce from an imported checkout, set `NIGHTGRID_STOREFRONT_CAPTURE_DIR` to a fresh absolute path and `NIGHTGRID_SOURCE_REVISION` to the game revision. The harness uses isolated evidence saves.

```powershell
godot --path . --rendering-method forward_plus --rendering-driver vulkan --fullscreen --resolution 1920x1080 --script res://tools/capture_brickwater_storefront.gd -- --living-streets --storefront-playtest
```
