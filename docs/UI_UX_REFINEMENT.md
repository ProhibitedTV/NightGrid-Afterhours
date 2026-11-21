# NightGrid interface refinement — November 21, 2026

## Goals
Reduce the monolithic text overlay, preserve visibility of the world, make priorities obvious, and ensure every menu is usable with keyboard, mouse and standard Xbox controls.

- Shared restrained graphite / teal / amber theme; contrast and a visible two-pixel focus stroke; larger buttons, left-aligned navigation and readable section headers. No external fonts or UI image assets.
- Title prioritizes Continue when a valid save exists. New-world confirmation defaults to keeping the existing session. Back restores the previous choice when available.
- Settings groups Audio, Controls, Display & Performance, with numeric slider readouts and focus-following scrolling. Existing settings.cfg keys, save/load semantics and controller input bindings remain unchanged.
- HUD: anchored player status and health meter, separate live courier objective and active contracts, map at upper right, transient notices at top center, context-only action prompts at bottom. Driving and transit have distinct prompts; gamepad glyph names replace keyboard labels. Business dialogue has the same theme. Debug/performance data remains separate and F10 clean capture still hides HUD.
- City map keeps all real pins; a contrasted white player marker and north label improve orientation. Map updates at 10 Hz instead of every render frame.

## Verification
Run `godot --headless --path . --script res://tests/menus_gamepad_smoke.gd` plus the complete project preflight and Windows export. Manually verify native Windows 1920x1080, 1280x720 and ultrawide, title with/without save, scroll to last setting via D-pad, safe confirm/cancel, focus restore, paused map/journal, foot/driving/transit/interior prompts, long dialogue and F10 HUD-free screenshots. Headless tests check actual controls/state; they do not establish visual acceptance or GPU performance. Capture native UI-inclusive screenshots separately from F10 clean world frames.
