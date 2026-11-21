# NightGrid development guide

The [player README](../README.md) is deliberately short. Detailed engineering and art history from the previous README remains available in the [archived README at commit 70a3f88](https://github.com/ProhibitedTV/NightGrid-Afterhours/blob/70a3f880bc4f0145a8cbeeeda2ff7c4e57223c71/README.md); all linked technical specifications are preserved.

## Getting started
- Godot 4.7.2 standard (no .NET), Forward+ with Vulkan on Windows, fixed 60 Hz gameplay physics, uncapped rendering subject to VSync.
- [Menus and input](INPUT_MENUS.md) · [Playtest checklist](PLAYTEST_CHECKLIST.md) · [Beta release notes](BETA_RELEASE_NOTES.md)
- Run `python3 tools/check_project.py`, `godot --headless --path . --import --quit`, then relevant smoke tests. Generate optional spoken MBPD assets with eSpeak NG and `python3 tools/generate_mbpd_radio.py` before import.
- [Preflight](../.github/workflows/preflight.yml) lists the complete regression suite; [Windows build](../.github/workflows/windows-build.yml) exports the playtest.

## City and gameplay
[World bible](WORLD_BIBLE.md) · [City atlas](CITY.md) · [Expansion](EXPANSION.md) · [Venues](VENUES.md) · [Transport](TRANSPORT.md) · [Combat](COMBAT_PILOT.md) · [Wanted](WANTED_SYSTEM.md) · [Dispatch](POLICE_DISPATCH.md) · [Radio and civic patrols](MBPD_COMMS.md) · [Road restrictions](CIVIC_ROAD_RESTRICTIONS.md)

## Streaming and performance
[Frame pacing](FRAME_PACING_AND_ASSETS.md) · [Interiors](STREAMING_INTERIORS.md) · [Predictive city streaming](PREDICTIVE_CITY_STREAMING.md) · [RenderingServer](RENDERING_SERVER_LIVE_CITY.md) · [Traffic foundation](TRAFFIC_STREAMING.md) · [Sidewalk foundation](SIDEWALK_POPULATION.md)

## Art and sound
[Approved fidelity target](APPROVED_WORLD_FIDELITY_TARGET.md) · [Art direction](ART_DIRECTION.md) · [Central Exchange](CENTRAL_EXCHANGE_PHOTOREAL_VERTICAL_SLICE.md) · [Walk-in storefronts](CENTRAL_EXCHANGE_WALK_IN_STOREFRONTS.md) · [West Docks](WEST_DOCKS_CC0_GLTF_ART.md) · [Kestrel S6](KESTREL_S6.md) · [Lantern Cup](LANTERN_CUP.md) · [Mara](MARA_HERO.md) · [NightGrid FM](NIGHTGRID_FM_SOUNDTRACK.md) · [Audio mix QA](AUDIO_MIX_QA.md)

## Acceptance
Read [AGENTS.md](../AGENTS.md) and the [first playtest triage](PLAYTEST_TRIAGE_2026_11_20.md). Real screenshots, asset provenance and target-hardware frame traces determine visual acceptance. Prototype structures and headless tests are not proof of production art quality or 60 FPS. Track live issues and PRs on GitHub rather than maintaining release claims in the landing page.
