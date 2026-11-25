# NightGrid: Afterhours — Menus, input and standard gamepads

The game now has proper pause-aware title, pause, settings, controls, city map and quest/inventory journal screens. `scripts/game_menu.gd` is a full-screen keyboard/mouse/gamepad focusable menu layer. `scripts/game_input.gd` installs shared named Godot input actions, replacing hardware-specific movement and driving reads in the player and vehicle controllers.

## In-game screens

| Screen | What it does |
|---|---|
| Title | Enter Morrow Bay, Continue saved world (disabled if no valid slot exists), New World, Settings, Controls, Quit |
| Pause (Esc / controller Start) | Resume, Save at Lantern Court (or route to the hotel), Load, New World confirmation, City Map, Journal, Settings, Controls, Title, Quit |
| City Map (M / controller View/Select) | Enlarged live 8x8 district map showing player position, pickup/delivery, venue, civic and side-job markers |
| Journal (Tab or Pause > Mission journal) | Current district, local time, active courier/contact/civic contracts, mission actions and completed work |
| Player & inventory (Pause or Journal) | Live health/stamina, cash/BTC, itemized supplies, equipment, outfit, conditioning, property and vehicle ownership |
| Settings | Master volume, mouse sensitivity, right-stick sensitivity, invert Y, SSR, glow, VSync and F3 overlay visibility |
| Controls | Context-dependent keyboard and standard gamepad mapping; all buttons are focusable |
| New World confirmation | Warns that unsaved progress will be discarded; the saved slot is not overwritten until another save |
| Business dialogue | Focusable buttons for service purchase (A/1), contracts (X/2) and close (B/G); moving controls are blocked while dialogue is open |

The first application launch opens Title. Deliberately creating a new world or loading a saved world **does not** force another title screen on reload. F5/F9 shortcuts are retained, but F5 respects the hotel save gate and the pause menu exposes the same actions. Esc/Start suspends the SceneTree so traffic, the game clock, physics and pursuit stop while paused. Menu UI runs with `PROCESS_MODE_ALWAYS`. Back returns to the preceding screen; the title screen cannot be accidentally dismissed as if it were a pause menu.

### Keyboard and mouse

| State | Binding | Action |
|---|---|---|
| On foot | WASD, mouse, Shift, Space | Move, look, sprint, jump |
| Vehicle | W/S, A/D, Space | Accelerate/reverse, steer, brake |
| Outside | E | Enter/exit parked vehicle |
| Transit | F | Board/alight at station or stop |
| Buildings | H | Enter/leave at door |
| Shops | G, 1, 2 | Interact/close, use service, contract |
| Supplies | R | Consume supply pack while on foot |
| Menus | Esc, M, Tab | Pause, full city map, journal |
| Game saves | F5, F9, F6 | Save at eligible Lantern Court checkpoint, load, confirm New World |
| Debug | F3, F4, T, Y | FPS, SSR, advance clock, pause day/night cycle |

### Standard Xbox/XInput controller layout

| Game state | Control | Action |
|---|---|---|
| On foot | Left stick | Walk (analog) |
| Vehicle | Left stick X | Steer (analog) |
| Everywhere | Right stick | Orbit camera (adjustable sensitivity/Y inversion) |
| On foot | L3 | Sprint |
| On foot | A | Jump |
| Vehicle | RT / LT / B | Accelerator, reverse, handbrake |
| World | X | Interact with business |
| World | Y | Enter/exit parked car |
| World | RB | Board/alight bus or M-Line |
| World | LB | Enter/leave business interior |
| World | D-pad Down | Use food supplies |
| System | Start | Pause menu |
| System | View/Select | Full city map |
| Menus | D-pad, A, B | Navigate focus, accept, go back |
| Business dialogue | A, X, B | Use service, take/turn in job, close |

All gamepad buttons are **contextual**. In particular, B is the handbrake in a drivable car and does **not** unexpectedly open the pause menu; Start always does. Face-button A means jump while walking, but service selection while a business dialog has focus. Gameplay movement is suppressed while a dialogue is open. Godot's built-in control focus navigation handles title/pause/settings and buttons, without implementing a second keyboard-only menu system.

**Compatibility:** The standard Xbox/XInput layout is defined using Godot 4 joypad enums. Other controllers may work when Godot and the host OS map their buttons/axes to this layout, but this pass has **not** been tested on physical Xbox, PlayStation or Switch controllers. Controller auto-detection updates HUD action hints when receiving actual joypad input. No vibration, gyroscope, remapping UI, or certified console support yet.

## Persistent player settings

Settings are saved locally to `user://settings.cfg` using `ConfigFile`; a change applies immediately to the live environment/AudioServer and is read again on the next launch. Parameters have safe bounds. Settings are **separate from** `GameSession` world saves: updating SSR or mouse sensitivity does not reroll the city or corrupt the saved world seed.

The whole controller action map is installed by `GameInput.install()` in `world.gd` on startup. Player and arcade car scripts now use `Input.get_vector()`, `Input.get_axis()`, `Input.get_action_strength()` and named actions. The menu layer listens for gamepad D-pad navigation and focus/accept rather than hardcoded UI key branches.

## Performance and tests

Pausing freezes physical simulation while the menu can still respond. The map reuses the existing live minimap renderer instead of maintaining a second map representation. Menus use built-in Godot UI widgets, minimal texture assets, and do not need special GPUs. Screen-space reflection, glow and FPS/chunk metrics can be enabled/disabled to help profile the game's RTX 3060 target. On-device frame rate is **not measured by headless CI**.

`tests/menus_gamepad_smoke.gd` validates action mappings and stick/trigger assignments, simulated forward motion, menu pause/resume, save-slot affordances, new-world confirmation and cancellation, settings persistence, graphics/live HUD settings, focusable dialogue controls, the live world map and journal, and the B-button conflict between menu Back and driving brake. Other city, transport, interiors and venue tests continue to run.

## Interface polish and reduced HUD

The circular lower-left radar retains its existing renderer, dimensions, navigation and input contract. The player status uses compact health/stamina meters and retains the objective and waypoint. Driving uses a mutually exclusive lower-right speed (km/h), vehicle name and NightGrid FM status display in the weapon panel's slot. Speed is sourced from the live car, not a simulated dashboard. The track label follows the existing audio director and is hidden if the director has no car context.

Settings > Interface provides two independent persistent preferences, both enabled by default: **Show general control reminders** and **Show inventory counts in HUD**. Turning reminders off removes generic movement, map and weapon-cycle help when holstered, but retains contextual actions, nearby vehicle/transit entry, vehicle exit, equipped weapon controls, mission objectives and navigation. Turning inventory counts off hides delivery/supply/snack counts in the status panel, without altering game state. The existing controls screen remains accessible.

Validation: expanded radar/menu smoke assertions are included in preflight. Native Windows checks and real screenshots are still required, particularly long radio track names, context stacking, interiors and 720p/ultrawide layout. The HUD still runs on its existing 10 Hz update schedule; no new render pass or measured FPS claim.

The equipment wheel (C / right-stick click) is a paused-world preview with original vector slot marks, an animated selection ring, distinct equipped/preview labels and loaded/reserve information. Selection responds immediately; only the highlight interpolates for 140 ms. Confirm or cancel retains the existing ammunition and trigger-release contracts. The wheel does not render continuously when idle. The HUD framebuffer QA now includes an actual equipment-wheel capture alongside walking, driving and the interactive atlas at three window resolutions; these software captures are not native performance or visual acceptance.

## Property-based saves

Manual save is now a physical world activity rather than a global quick-save. Visit Lantern Court: before renting, use the free checkpoint at the actual exterior entrance (G / controller X, F5 or Pause > Save Progress). No room key or fee is required for this temporary checkpoint. It does not grant tenancy, bed, storage or other residential privileges. After paying the existing deposit, enter the rented capsule and approach its existing save desk; the free entrance checkpoint is no longer available. Resting at the bed remains a separate health/stamina action. Saving requires being on foot, outside other modal interactions, and clear of police heat. If unavailable, Pause explains why and can route to the hotel entrance without changing the active mission. The existing atomic single-slot writer, legacy load compatibility and world snapshot format remain unchanged. There is no autosave, additional save slot, new property type or global pre-tenancy exemption in this pass.

`tests/walk_in_lot_smoke.gd` covers the actual property entitlement and save availability, blocked save requests leaving the slot intact, route-before-tenancy, desk-only eligibility after payment, pause menu enablement and an isolated eligible snapshot write. Real native playtesting is required before claiming acceptance.

## Mission journal and player inventory

Pause separates World (atlas, missions, player), Session (property-restricted save/load/new), and System (settings, controls, title, quit). The journal now focuses on mission objectives, active contracts, navigation and completed work. The separate Player & inventory screen uses live world data for health and stamina meters, cash and BTC, ration packs, itemized carried food/drinks with the existing original vending icons, pack capacity, equipment, outfit, conditioning, property/garage and vehicle titles. Inventory browsing is read-only; existing on-foot supply use is unchanged. Both screens cross-link, preserve controller focus and return to Pause. Route to Lantern Court works before tenancy; garage route remains entitlement-gated. Developer-facing seed and loaded-block counts are no longer shown in the main journal; snapshot data is unchanged, and streaming diagnostics remain available via F3.

Expanded menu smoke checks actual item counts, icons, vitals, cross-navigation and read-only behavior. Native visual verification remains required. No new textures, save fields or simulated inventory state were introduced.
