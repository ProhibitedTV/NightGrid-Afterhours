# INSERT COIN — Morrow Bay's independent arcade

## Premise
An independent coin-op repair shop in the Afterhours district keeps games alive after fictional publishers acquired the studios, replaced creative leads with committees, introduced subscriptions and shipped roadmaps instead of features. This is original fictional satire, not a claim about the reception or conduct of any named real studio. Use no borrowed character designs, trademarks, logos, recordings or textures. Make the jokes work even for players unfamiliar with the inspirations. The actual arcade games should be fun rather than deliberately broken.

## Cabinet lineup
| Cabinet | Fictional publisher | Actual gameplay | Joke |
|---|---|---|---|
| Grand Delay Auto VI | Milestone Mirage | Three-lane driving, collect feature drops and avoid paywalls | Overhype, long waits, editions and nickel-and-diming |
| Claw & Compliance | Committee Interactive | Lane-based brawler, intercept audit drones | Corporate focus-group design and endless approvals |
| Patch Day 2077 | Quarterly Vision | Real-time grid repair | Fix bugs faster than the roadmap adds them |
| Annual Warfare 19 | Recurrence Media | Future light-gun target gallery | Identical sequels and premium reloads |
| Indie Dev Simulator | Two Friends & A Laptop | Eight-week studio management strategy | Tiny teams competing with big marketing budgets |

Four cabinets now have playable isolated screens and deterministic bounded simulation. Annual Warfare remains a concept. Patch Day uses a 4×3 grid with expiring bug deadlines and three server lives; Indie Dev uses eight player-driven weeks, balancing features, bug debt, energy and community support. The cult-classic finish requires quality ≥9, bug debt ≤2 and fans ≥3. Pilot uses a deliberately simple original graphic style; not the final cabinet visual quality.

## Run the pilot
From repo root: `godot --path . res://scenes/arcade_pilot.tscn`.
Use left/right arrows or D-pad (all four directions for Patch Day); Enter/A to start, strike, repair or commit a studio week, Escape/B to abandon or return. Default Godot UI mappings provide keyboard/controller support; native controller testing remains required. Escape/B from selection emits exit_requested for a future owner; when running standalone close the window to quit. Best scores last only for the screen instance.

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
This branch does not add a world location, modify the main game scene, charge cash, save high scores, or grant rewards. The pilot is a reusable isolated scene; integration and production art are separate follow-up slices.

## Player-first writing rule
The games are free practice during this isolated pilot. Celebrate bug reporters, fan artists, friends, speedrunners and players who waited patiently. No real studio allegations or copied assets. Rest is a positive strategic action in Indie Dev, not a punishment.
