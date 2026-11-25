# INSERT COIN — Morrow Bay's independent arcade

## Premise
An independent coin-op repair shop in the Afterhours district keeps games alive after fictional publishers acquired the studios, replaced creative leads with committees, introduced subscriptions and shipped roadmaps instead of features. This is original fictional satire, not a claim about the reception or conduct of any named real studio. Use no borrowed character designs, trademarks, logos, recordings or textures. Make the jokes work even for players unfamiliar with the inspirations. The actual arcade games should be fun rather than deliberately broken.

## Cabinet lineup
| Cabinet | Fictional publisher | Actual gameplay | Joke |
|---|---|---|---|
| Grand Delay Auto VI | Milestone Mirage | Three-lane driving, collect feature drops and avoid paywalls | Overhype, long waits, editions and nickel-and-diming |
| Claw & Compliance | Committee Interactive | Lane-based brawler, intercept audit drones | Corporate focus-group design and endless approvals |
| Patch Day 2077 | Quarterly Vision | Real-time grid repair | Fix bugs faster than the roadmap adds them |
| Annual Warfare 19 | Recurrence Media | Timed target gallery with free reloads | Identical sequels and premium reloads |
| Day-One DLC | Partition Publishing | Three-stage sliding puzzle | Complete game split into artificial packs |
| Open World Checklist | Icon Avalanche | Timed map-icon routing | Filler and map clutter |
| Battle Pass Hero | Retention Systems | Timed command sequences across six seasons | FOMO and engagement metrics |
| Indie Dev Simulator | Two Friends & A Laptop | Eight-week studio management strategy | Tiny teams competing with big marketing budgets |

Eight cabinets now have playable screens and deterministic bounded simulation. Annual Warfare uses a timed 3×3 gallery with four-round magazines, streak bonuses and protected fan targets; Day-One DLC is a three-stage sliding puzzle with a 36-move budget per stage. All content is free in practice. Patch Day uses a 4×3 grid with expiring bug deadlines and three server lives; Indie Dev uses eight player-driven weeks, balancing features, bug debt, energy and community support. The cult-classic finish requires quality ≥9, bug debt ≤2 and fans ≥3. Pilot uses a deliberately simple original graphic style; not the final cabinet visual quality.

## Run the pilot
From repo root: `godot --path . res://scenes/arcade_pilot.tscn`.
Use left/right arrows or D-pad (all four directions for Patch Day); Enter/A to start, strike, repair or commit a studio week, Escape/B to abandon or return. Default Godot UI mappings provide keyboard/controller support; native controller testing remains required. Escape/B from selection emits exit_requested for a future owner; when running standalone close the window to quit. Standalone preview scores last only for the screen instance; world play saves personal bests in the normal slot.

Headless: `godot --headless --path . --script res://tests/arcade_smoke.gd`.

## Physical venue — next slice
- Fixed authored parcel in Afterhours, verified against collision, sidewalk reservations, doors and minimap. Do not insert an unverified address or change seeded map geometry. Opening 14:00–03:00.
- Original neon INSERT COIN marquee, blackened steel, warm wood, terrazzo, carpet runner, tinted glass, ventilation and coin slots; two finished cabinet silhouettes with original side art, bevels, CRT glass, joystick and buttons. No loud blinking; reduced-motion option.
- Repair counter owner Rook; NPC regulars argue over high scores, complain about subscription cartridges, or praise indie games. Idle attract screens share one atlas or shader; no per-cabinet SubViewport in idle state. One active cabinet screen only.
- On foot, use existing interior entry and G/X interaction; reachability, opening hours and input ownership must match other activities. Modal owner must release camera, movement, weapon and menu inputs on close, abandonment, load, new game and scene teardown. No background simulation of a cabinet after leaving.
- Pricing proposal: $2 per run, free practice, cosmetic-only prizes, local per-title best score. No real-money purchases or gambling. Use existing progression ledger for atomic payment, not a second wallet; charge once on confirmed start. Keep arcade score separate from street cred initially. Later evaluate a one-time tournament reward with stable receipt, not repeatable cash farming.
- Persist only validated bounded best scores by stable game ID in optional legacy-compatible save field; do not persist live round or pay twice after load.
- Add headless tests for reachability, input isolation, reset, payment rollback, old saves and world re-entry. Native target: Ryzen 7/RTX 3060, genuine F10 screenshots and F8 frame trace; no measured FPS yet.

## Writing samples
Rook: "Used to be a game studio. Now it's a storefront with a cutscene attached."
Regular: "I bought the deluxe edition. It came with a picture of the thing I wanted."
Other regular: "The old cabinet still works. Nobody remembered to turn off its server."
Claw cabinet attract: "Berserker mode pending committee approval."
Driving cabinet attract: "Seamless open world. Some districts require a separate license."
Self-own poster: "AFTERHOURS: early access to your own bad decisions."

## Integration boundary
The in-city vertical slice adds INSERT COIN as a fixed legacy-transition venue in block (1,2), west lot. Free practice pauses the world and uses four cabinet-specific screens. Personal bests persist in an optional, validated per-save field. Completed results settle immediately; abandoned runs do not. No wallet debit or reward changes. Native placement and controller acceptance remain outstanding.

## Player-first writing rule
The games are free practice during this isolated pilot. Celebrate bug reporters, fan artists, friends, speedrunners and players who waited patiently. No real studio allegations or copied assets. Rest is a positive strategic action in Indie Dev, not a punishment.

The six-cabinet layout preserves the original four positions; two more are near the entrance sides, with no extra live viewports. Both extra titles have original SVG art. Controller/native validation remains required.

## Complete eight-cabinet lineup
Open World Checklist uses a 5×3 city grid, three icon types and bounded waves; route planning and full-map bonuses reward exploration efficiency. Battle Pass Hero uses six short command-sequence seasons with three lives; wrong commands reset only the combo and the full game remains free. Two original cabinet skins occupy the rear side positions, preserving entry and central aisle. All eight cabinets now share the same ID catalog and have physical marquee labels. Native readability and frame pacing still require validation.

## Neighborhood leaderboard
Three fictional authored local rivals per cabinet, plus the player's personal best if earned. Sort descending with established rivals winning ties. Save data uses optional `arcade_best` (eight stable IDs, finite whole scores 0–20000). Legacy saves omit it; invalid values reject the snapshot. No network calls, score history or currency rewards. A new game starts fresh.

## Grand Delay Auto VI — The Eventual Edition
One cabinet receives the hero pass: original 768×960 vinyl, separate backlit marquee, original rear-view car sprite, printed side panels rather than CRT-shaded vinyl, chrome rails, service seal, serial plate, coin-return hardware, light pipes and low-energy non-shadowing marquee spill. The CRT has curved UVs, static scanlines and a subtle slow sweep; other machines remain unchanged. The active screen has an authored sunset skyline, perspective road, animated lane marks, smoothly interpolated vehicle and steering-wheel presentation, nitro button response, title and results screens and labeled feature/paywall drops. Collect three features to charge nitro; Enter/A consumes the charge for a five-step window, absorbing one paywall. The score remains 100 per feature and old leaderboards are comparable. The fixed 32-step simulation, save ID, collision footprint, free practice and input ownership are preserved. No live world viewport or extra runtime AI. The physical steering wheel and nitro button are synchronized to the modal controls, reset on result, abandonment and teardown; the deck also animates on-screen. This is not a skeletal player animation; native cabinet close-up, controller feel, color/contrast, frame-time and avatar hand placement remain to be verified. 

### Full driving game (build 1.1)
The world cabinet now launches a dedicated 60 Hz deterministic racer instead of the legacy 32-step lane pilot. Three authored 1.2 km districts form a 3.6 km sprint: Promise Beach, Roadmap Downtown and Gold Master Expressway. Hold left/right to steer continuously with inertia; up accelerates to 76 m/s, down brakes toward 28 m/s, no input cruises at 53 m/s. Three feature pickups charge a 2.8 second nitro burst (98 m/s target), which bypasses paywalls but not traffic. Checkpoints grant 20 seconds, moving traffic rewards overtakes and close passes, and collisions cost a life and speed with short invulnerability. Results show time, distance, features, near misses and best combo. All scores remain bounded by the existing 20,000 save limit; the new scoring scale is different, so legacy local scores remain readable but are not directly comparable. The old lane model remains as a regression fixture and for Claw & Compliance. Native tuning and controller playtest required; no measured FPS or playtest claims.
