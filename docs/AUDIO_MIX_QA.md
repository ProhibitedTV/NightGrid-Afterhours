# Morrow Bay audio

This is the audio workstream for [#33](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/33), with soundtrack ingestion in [#36](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/36), dispatch in [#81](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/81) and Brickwater's service alley in [#151](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/151).

## Implementation checklist

- [x] Five independent music, ambience, effects, dialogue and UI stems under Master. Existing music, ambience, SFX and Master settings are preserved. Dispatch has its own saved volume.
- [x] Eight district profiles combine wind, recorded distant traffic, industrial power and water. Local, ray-occluded emitters give Brickwater a service fan and workfront, the docks a recorded harbor and Horizon Gardens a wind texture. The city uses its existing dry-weather cycle.
- [x] Recorded footsteps on concrete, indoor tile and gravel, plus a filtered asphalt variation. Distance, speed and floor contact determine cadence. One courier player can overlap two footfalls.
- [x] Acceleration-sensitive Kestrel drivetrain, with one dedicated passenger roll layer, a braking cue, collision and vehicle latch cues. Passing cars and buses keep a five-voice pool with fade-before-reassignment. M-Line roll follows speed and the station chime follows the stop. Boarding uses distinct bus and train door cues.
- [x] Outdoor low-pass and attenuation respond to buildings and cabins. Interior effects use short café reflections or a larger club reverb. The street-to-room music handoff retains the song and playhead for the open venue.
- [x] Positional footsteps from nearby moving Living Streets civilians when the pedestrian pilot is enabled. Workfront sources follow their activity windows. Existing businesses keep their authored room ambience.
- [x] A prioritized dispatch queue sends speech through one active playback voice, using a positional receiver near the precinct and the player receiver for active incidents. Speech ducks music, and captions remain available with dialogue muted.
- [x] All twenty actual NightGrid FM tracks and a verified manifest ship in the game. The music director uses two stereo decks, one street music voice and at most three asynchronous load jobs. It retains the active song under pause and restores optional car tuning in v1 saves. [Soundtrack details](NIGHTGRID_FM_SOUNDTRACK.md).

The mix keeps four broad bed players, two local ambience voices, two resident-footfall voices, one passenger roll player, four pooled action voices, five passing-traffic voices and the three music players. The existing vehicle, station and venue emitters remain separate. Each local ambience scan considers at most two occlusion rays every 0.2 seconds. The boot bank, synthesized loops and action transients are prepared before play. Soundscape, audio fading and resource loading use elapsed time.

Original synthesized effects are labeled separately from CC0 field recordings and creator-owned music. [Field recording sources and checksums](../assets/audio/morrow_bay/SOURCE.md) · [Fictional dispatch voice source](../assets/audio/mbpd/README.md).

## Native Windows recordings

These are genuine Godot Master-bus recordings from Windows WASAPI, Forward+ / Vulkan on an RTX 3060 at 1920×1080. The scripted replay used the actual World at runtime `0d1e5ef`, seed 834726 and Living Streets enabled. It placed the courier at existing city addresses and invoked the same interaction and movement paths as regular play. The listening files are compressed copies of the native stereo PCM and retain the recorded levels.

| Gameplay | What was verified |
| --- | --- |
| [Title and scene fade](playtest/audio-33/01-title-and-fade.ogg) | Boot Sequence tuned from the packaged library and faded on entering the city |
| [Brickwater at 22:06](playtest/audio-33/02-brickwater-sidewalk-and-vents.ogg) | Concrete steps, takeoff and landing, two local emitters and one obstructed source |
| [Lantern Cup doorway](playtest/audio-33/03-cafe-doorway.ogg) | Save Point carried from street at 0.50 s to the room at 2.09 s. Indoors selected tile steps and an outside cutoff of 950 Hz |
| [Static Room doorway](playtest/audio-33/04-club-doorway.ogg) | Tournament in the Back Room carried from street at 1.66 s to the room at 3.25 s. Indoors selected tile steps |
| [Southworks drive, brake and car radio](playtest/audio-33/05-southworks-engine-brake-and-fm.ogg) | Keyboard N and mapped D-pad Up advanced the car station, braking fired and pause kept the same track at 44% of its current gain target. A v1 snapshot carried the track and playhead |
| [City Loop and M-Line](playtest/audio-33/06-city-loop-and-m-line.ogg) | Boarding a stopped bus and a train at the actual East Gardens platform used distinct doors and passenger motion sound |
| [Active MBPD precinct receiver](playtest/audio-33/07-mbpd-live-receiver.ogg) | A live civic ledger request used the positioned speaker and the independent dialogue stem |
| [West Docks harbor](playtest/audio-33/08-west-docks-harbor.ogg) | The recorded harbor played from the actual waterfront emitter before dawn |

All eight captures contained stereo signal. The highest measured sample peak was −12.29 dBFS on the driving sequence. The revised precinct scene measured −43.15 dBFS RMS, up 8.71 dB from the first pass at the same position. These are sample measurements from a scripted mix at the documented defaults. Headphone balance, dialogue intelligibility on different outputs and a physical controller pass remain open. [Scene, playhead and voice records](playtest/audio-33/native-capture.json) · [Measured WAV levels and trace results](playtest/audio-33/measurements.json).

A separate daytime replay placed the courier 3.5 m behind a moving Brickwater resident and kept the courier stationary for eight seconds. Eight residents were active nearby. The two positional voice slots played four resident footfalls and the courier produced zero. [Daytime pedestrian recording](playtest/audio-33/09-brickwater-daytime-pedestrians.ogg) · [Resident and footfall counts](playtest/audio-33/pedestrian-capture.json).

### Matched driving traces

Both revisions drove the same seeded night route from Southworks through Afterhours and Glassline, with the same camera turn, parked vehicle and traffic setup. The driver reached 130 km/h in all four passes and crossed the same endpoint. Polling at frame boundaries produced final travel distances of 227.13 m before and 227.73 m after. VSync was off and SSR, AO, glow and fog were on. The runtime before the audio changes used the same world, vehicle and character code at `22aab3e`.

| Revision and pass | Median ms | p95 ms | p99 ms | Max ms | Frames >16.67 ms | Frames >33.3 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Before, first | 21.61 | 29.17 | 30.57 | 31.28 | 273 | 0 |
| Audio update, first | 20.83 | 30.00 | 31.02 | 32.80 | 268 | 0 |
| Before, repeat | 22.22 | 31.94 | 34.35 | 38.45 | 264 | 8 |
| Audio update, repeat | 22.22 | 29.17 | 38.48 | 45.15 | 260 | 5 |

The render intervals also showed a 65.36 ms outlier in the updated repeat. Neither side lost focus or performed a runtime material bake. The traces measure the combined game and rendering workload, so the remaining outlier has no isolated audio attribution. The 16.67 ms target remains open for this night route. [Raw F8 and renderer traces](playtest/audio-33/f8-and-render-traces.zip).

The scope uses room and roadway classes for step surfaces and simplified acoustic filtering for exteriors. Vehicle and station transients include designed effects alongside the recorded field bank. Full adjacent-room propagation, a larger pedestrian voice library and human listening acceptance remain open.

## Export and regression results

Godot 4.7.2 on Windows passed all 72 scene regressions, the 90-frame boot, the material-map bake check and the Windows x64 release export at runtime `0d1e5ef`. Hosted project preflight and the hosted Windows build passed at the same revision. [Project preflight](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45076206117) · [Windows artifact](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/45076206092).

The shipped executable reached its title screen on the RTX 3060. All eight scripted WASAPI scenarios also passed with Godot loading only the packaged PCK, including the title, car and venue music. A separate packed-data smoke test verified all twenty stream entries, overlap, skip and v1 tuning restore. That short headless run reported ObjectDB and resource references at shutdown. The longer native replay and source test passed. [Packaged audio replay](playtest/audio-33/packaged-capture.json).
