# BitRiver Gaming — startup ident

Creator-approved studio credit: **BitRiver Gaming** / **by RhythmicCarnage**. The direction is a brief, original industrial/cyberpunk ident with the energy of classic studio intros, not a recreation of Neversoft or any other existing studio mark.

- 0.00–0.85 s: dark signal scan and eight displaced emblem strips assemble.
- 0.52 s: original short mechanical impact and low tonal sting.
- 0.70–1.48 s: studio name and creator credit reveal, with restrained cyan and magenta accents.
- 1.48–2.64 s: clean readable hold.
- 2.64–3.20 s: fade and handoff to the existing game/title. If threaded resource loading is not complete, a simple loading message remains until the world is ready.

The original editable monogram is `assets/branding/bitriver_emblem.svg`. The Godot script draws the timed strips and typography without a video codec or third-party artwork, and generates an original deterministic 1.2-second mono PCM sting once on startup. It respects the player's saved master and SFX volume, including mute. No repeated full-screen flashes.

Skip with Enter, Escape, Space, controller A/B/Start, or left mouse click. Developers can run `godot --path . -- --skip-studio-intro`; headless launches bypass the timing automatically. Directly running `scenes/main.tscn` still bypasses the ident. Loading a save or starting another world uses the original scene reload, not the launch scene. No new game/save state, world geometry, or HUD/menu edits are introduced.

## Acceptance

- Headless smoke validates duration, once-only completion, skip input, deterministic bounded audio and actual world handoff.
- The isolated software OpenGL workflow captures actual Godot frames at 720p and 1080p. It does not establish native Vulkan acceptance.
- Before landing: check preflight, Windows export, captured emblem/text alignment and native Windows cold launch/skip/mute/title handoff. Listen to the actual sting and verify no unexpected volume spike. No performance or visual acceptance is claimed until measured.
