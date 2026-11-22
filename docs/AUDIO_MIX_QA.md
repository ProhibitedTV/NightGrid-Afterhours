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
