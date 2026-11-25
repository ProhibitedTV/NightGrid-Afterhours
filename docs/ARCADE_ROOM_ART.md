# INSERT COIN — first cabinet art and room kit

Four individually illustrated original SVG cabinet skins; reusable human-scale cabinet shell with coin door, speaker slots, control deck, joystick, buttons, screen bezel and side panels. Static CRT shader has subtle scanlines/vignette, no time-based flickering and no active SubViewport. Two collision shapes per cabinet. Original geometry and graphics are authored specifically for Afterhours, not imported publisher IP.

Room dressing puts two opposing pairs against the side walls of the existing 16×18m interior envelope, leaving a central aisle and door clear. Front-only reachability reports stable cabinet game IDs. Rook dialogue rotates through four player-positive lines. The room kit expects the host interior to supply architecture, a counter and lighting; the preview supplies a floor and camera only.

Preview: `godot --path . res://scenes/arcade_room_preview.tscn`

Smoke: `godot --headless --path . --script res://tests/arcade_room_smoke.gd`

This branch supplies art and reusable reachability only, not playable city placement or modal binding. Patch Day and Indie Dev software are in PR #326. The next integration PR must select a verified physical address, connect cabinet IDs to the active game screen, isolate input and preserve save/load behavior. The preview is not a verified native screenshot or final art acceptance; profile on the target GPU before scaling.

## World integration
INSERT COIN is now authored at block (1,2), west lot, using the existing legacy interior doorway transition, 14:00–03:00. Cabinet play pauses the world and locks the selected title; Escape/B returns to selection, then closes the overlay. Free practice only; session best survives cabinet changes, not saves or scene reload. Map and HUD identify the arcade. Seamless physical building migration and native collision/visual testing remain pending.

## Atmosphere pass
Four local animated regulars use the shared HumanoidVisual rig and static cylinder collision, with proximity-based rotating dialogue. Cabinet reachability takes priority. Three original print/carpet SVGs, a rear repair bench, spare CRT, toolbox, and parts bins provide lived-in dressing. No cabinet slots or aisle positions changed. The Friday night poster is environmental fiction only; tournament gameplay remains future work. Native art/collision review remains required.
