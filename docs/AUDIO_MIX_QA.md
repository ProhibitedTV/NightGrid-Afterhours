# Afterhours audio routing and interaction QA

Issue: [#33](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/33)

## Implemented in this pass

Four independent runtime audio buses route into **Master**:

| Bus | Sources | Player-facing setting |
| --- | --- | --- |
| `NightGridMusic` | NightGrid FM stereo decks and spatial venue radio | Music volume / radio toggle |
| `CityAmbience` | Wind, urban traffic bed, docks and industry; venue and interior atmosphere; Lantern Cup steam | City ambience |
| `WorldSFX` | Footsteps, pooled traffic, Kestrel motors, M-Line, and action cues | SFX |
| `NightGridUI` | Menu select tone | SFX |

Music and UI keep their existing source-level settings. The ambience and world-effects sliders now set the **actual shared stem gain and mute**, so venues, trains and Kestrel motors follow the same volume/mute controls as city beds, footsteps and passing cars. Internal effect sources retain authored relative levels without applying slider gain twice. Master remains the global volume. All buses are initialized idempotently before the playable world creates sound sources; a saved-game scene reload does not duplicate them.

**New original procedural one-shots:** vehicle latch/close on entry and exit, boarding/alighting acknowledgement, courier pickup and completed delivery, takeoff and landing. Four reusable 3D player-action emitters are preallocated; six PCM samples are cached at world startup, so user interactions do not generate WAV data in the render/physics callback. They use SFX mute/volume. These are *prototype sound design*, not claims of AAA recorded Foley.

Audio remains distinct from the 20 user-owned NightGrid FM Ogg masters; the unresolved track ingestion is tracked in [#36](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/36).

## Automated gates

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/audio_mix_actions_smoke.gd
godot --headless --path . --script res://tests/world_audio_smoke.gd
godot --headless --path . --script res://tests/traffic_spatial_audio_smoke.gd
```

The new smoke instantiates the real main scene, checks stem routing and idempotence, confirms the fixed voice pool, verifies driving/mission/takeoff/landing event connections, and checks mute behavior. The CI preflight runs it with the other Godot 4.7.2 tests.

## Windows headphone listening pass (still required)

1. Download the Windows build from the PR workflow and confirm the exact build revision. Listen with headphones and, ideally, a second speaker setup.
2. Start on the title screen. With music assets present, verify `NightGridMusic` is independent from `NightGridUI`; test Master, music, ambience, and SFX at 0%, 50%, and 100% and reopen settings to check persistence. Without #36's Ogg files, report music as *missing assets*, not a routing failure.
3. Drive the Kestrel in Southworks, at noon and at 21:30. Listen for door, motor, nearby passing vehicles, industry and footsteps after exiting. Move into West Docks and North Quay to compare waterfront against industrial beds. Try multiple fast chunk crossings; effects must not start, stall or pop as chunks load.
4. Walk, sprint, jump and land. Verify one takeoff sound and one landing sound, no footstep loop while standing, and no burst on respawn/save restore.
5. Board/alight City Loop and M-Line, and enter a café, bar and club. Confirm source direction follows vehicles and outside traffic attenuates indoors. Note excessive doubling of adjacent venue audio.
6. Pick up and deliver a courier package. Listen for distinct acknowledgement sounds once each. Test rapid interactions and SFX mute; the fixed pool should not multiply endlessly.
7. Record F8 frame times while streaming and add F7 marks when audio noticeably cuts, clips, or falls silent. Compare cold launch versus warm-cache driving. Capture hardware, volume levels, route and headphones in the issue.

**Do not close #33 on CI alone.** A full production sound library, spatial listening QA, occlusion/reverb, calibrated loudness, and the creator-owned Ogg installation remain outstanding.
