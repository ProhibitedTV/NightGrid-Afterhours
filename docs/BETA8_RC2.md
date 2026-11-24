# Beta.8 RC2 — Cinder R9 driving and cockpit candidate

Status: proposed Windows review candidate, **not yet a published release**. Beta.7 remains the public comparison build. The RC1 native measurements in [BETA8_RC1.md](BETA8_RC1.md) do not apply to this changed runtime.

## Candidate changes

- Original Cinder R9 road car, independently steering/spinning wheels, stationary brake hardware and articulated doors.
- Measured longitudinal wheel travel, damped coachwork pitch/roll and bounded cosmetic road-contact suspension.
- Wet-road spray from supported tires, soft underbody contact occlusion, original day/night weather sky artwork.
- Live speed/gear/RPM/brake dashboard, articulated steering rim, upholstery micro-grain and courtesy light.
- Optional center-cabin driving view: V / D-pad Left; mouse/right stick look; normal chase view on exit and restore.

## Release candidate gate

The manual RC2 publishing workflow must be run on main only, after the exact main revision passes full Project preflight and Windows playtest build (including the actual exported EXE/PCK startup smoke). It packages that tested artifact, rather than exporting a different build. The cockpit gallery must have three real hash-verified Forward+ frames from a source whose game runtime tree matches the candidate (excluding only the build-info version stamp). The capture is a parked software-Vulkan review, not native GPU certification.

Existing Beta.7 release automation remains unchanged. The RC2 workflow is explicitly dispatched; no automatic public release is authorized by a branch push. A release candidate remains an unsigned development-channel build, not a production-quality claim.

Before publication: inspect all three genuine cockpit frames, run [the Windows acceptance route](PLAYTEST_MAIN_ACCEPTANCE.md), and keep performance, controller, audio listening and save compatibility unchecked until observed. The game has not yet met the verified 1080p/60 FPS target.
