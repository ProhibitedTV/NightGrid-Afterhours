# Beta.8 RC2 — Cinder R9 driving and cockpit candidate

Status: Windows playtest prerelease candidate, **not final Beta.8**. Beta.7 remains the public comparison build. The RC1 native measurements in [BETA8_RC1.md](BETA8_RC1.md) do not apply to this changed runtime.

## Candidate changes

- Original Cinder R9 road car, independently steering/spinning wheels, stationary brake hardware and articulated doors.
- Measured longitudinal wheel travel, damped coachwork pitch/roll and bounded cosmetic road-contact suspension.
- Wet-road spray from supported tires, soft underbody contact occlusion, original day/night weather sky artwork.
- Live speed/gear/RPM/brake dashboard, articulated steering rim, upholstery micro-grain and courtesy light.
- Optional center-cabin driving view: V / D-pad Left; mouse/right stick look; normal chase view on exit and restore.

## Release candidate gate

The RC2 publishing workflow is eligible only after the exact current main revision passes both full Project preflight and Windows playtest build (including the actual exported EXE/PCK startup smoke). It packages that tested artifact rather than exporting a different build. A completion event from either workflow can publish once both are green; stale or already-published commits are skipped. Existing Beta.7 automation and its gallery gate remain unchanged.

This is an unsigned development-channel **playtest prerelease**, not visual approval or a production-quality claim. In-engine cockpit screenshot review is outstanding. Final Beta.8 promotion requires the three real hash-verified Forward+ cockpit frames from a matching runtime, the separate `tools/check_rc2_cockpit_gallery.py` verification, native visual acceptance, and [the Windows acceptance route](PLAYTEST_MAIN_ACCEPTANCE.md). No final Beta.8 tag is published by the RC2 workflow. The capture is a parked software-Vulkan review, not native GPU certification. Keep performance, controller, audio listening and save compatibility unchecked until observed. The game has not yet met the verified 1080p/60 FPS target.
