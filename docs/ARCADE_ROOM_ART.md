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

## Sound pass
Four original short PCM WAV cues were rendered offline (start, score, damage, record), stored in assets/arcade/audio and routed through one cabinet speaker on the existing effects bus. No runtime synthesis, external model, network, or background audio. The record cue takes priority over the final score cue. These are first-pass authored electronic effects; future sound design can replace the WAV assets without changing gameplay code.

## Game culture archive
Eight inspectable exhibits use original illustrations, no copied game art or logos. Respectful historical tributes name Toru Iwatani, Shigeru Miyamoto, Alexey Pajitnov, Roberta Williams, John Carmack, John Romero and Sid Meier; these do not imply endorsements or fictional statements by those people. Other exhibits honor physical media and lampoon fictional publisher roadmaps and apology trophies. Front-wall and side-wall inspection points preserve cabinet and regular priority. Shallow collidable shelves display original cartridge, manual, disc case and save disk props. Eight cabinet service stickers, eight new regular lines and three Rook lines add environmental character. No currency/reward changes; all archive interactions are repeatable. Tests cover art presence, unique inspect IDs, clear entry and dialogue rotation. Native typography, prop fit and accessibility still need review.

Physical satire trophies (best apology, roadmap and editions) and a separate community appreciation plaque now sit on two shallow wall shelves. The repair bench has a circuit board, chips and service manual. These are static, original models; the awards are fictional environmental props, not real industry awards or player rewards.

## Rook's neighborhood circuit
A playable eight-cabinet score challenge. The physical counter poster opens a read-only scorecard with eight rival-named targets, current bests, stamps, and Local Legend completion. Scores already stored in arcade_best determine progress, so no new save schema or duplicated settlement. All completed runs count, no sign-up, cash, repeatable reward, time limit, or real-world Friday restriction. Tests exercise threshold boundaries, save roundtrip and board reachability. The board shares the cabinet modal's pause ownership. Friday night tournament rules remain future work.

Two freestanding zine archive displays honor LAN parties, split-screen, shareware, demo discs, and community-made maps. Original computer and disk illustrations accompany the inspectable text. Their collidable stands are outside the central counter route and cabinet approach zones. The shared modal now anchors to the full viewport after parenting to the CanvasLayer.

## Restoration series
Two original, fully offline classic-game prototypes complement the eight satire machines: Starline Patrol (three moving alien formations, projectiles, cooldown, three lives) and Neon Rebound (two brick walls, paddle-angle bounce, explicit serve, three lives). Held movement and shooter fire use a 30 Hz fixed simulation with four-step catch-up cap. Only one modal is active. Each has original SVG art, restored-cabinet sticker, three local rival scores and normal save persistence; the eight-stamp circuit stays unchanged. Two cabinets flank the entrance, facing inward; native clearance and game feel remain unverified. Smoke tests cover projectile scoring, wave advance, paddle boundaries, brick scoring, life loss and maximum session length.

## Shared cabinet and poster artwork
The optional WebP resolver from #334 is integrated with existing original SVG fallbacks, including the deluxe Grand Delay CRT and nine standard cabinets. Ten wall prints use the same resolved texture, with aspect-preserving CRT, side panels and standard title art. No extra collisions, lights or gameplay logic. The separate illustrated binary pack is not included; do not claim it shipped. The deluxe driving interface remains unchanged. Native room composition and import/export validation remain pending.
