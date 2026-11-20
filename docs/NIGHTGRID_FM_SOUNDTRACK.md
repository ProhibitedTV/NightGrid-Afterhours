# NightGrid FM / Chipwave soundtrack integration

## Provenance and permission

The NightGrid FM creator personally supplied 20 48 kHz stereo WAV recordings
on 2026-11-20 and explicitly authorized creative use in **NightGrid Afterhours**
(in cars, menus, locations and ambient environments). These are original
creator-supplied recordings; permission for this game does not constitute a
third-party reuse, resale or sublicensing permission. Preserve attribution as
**NightGrid FM — original chipwave by the game's creator**.

## Runtime audio direction

`scripts/nightgrid_fm.gd` is a lightweight music director. It provides:
- Two lazily loaded stereo decks with fades between title music, in-car NightGrid
  FM and active room music. It chooses only from available audio resources.
- A single positionally attenuated exterior music emitter for the nearest
  **open** social venue (31 m acquisition / 39 m hysteresis).
- Automatic rotation when tracks end, with venue-specific deterministic starting
  positions. At most three compressed music streams play simultaneously during
  a stereo crossfade while the exterior emitter remains active.
- Smooth volume changes across entering/exiting a car or shop, approaching
  restaurants or clubs, and opening/closing menus.
- Existing procedural venue ambience remains in place beneath the music.
- Persisted music volume and default car radio enable/disable in
  `user://settings.cfg`. The global master volume still applies.
- No network dependency, no per-frame waveform synthesis, and no loading all
  20 full-length WAVs into memory.

**Controls:** while driving, B turns the radio on/off and N skips a track.
On an Xbox-style pad, D-pad Right toggles and D-pad Up skips. The HUD displays
the station and currently playing track. Settings include a dedicated NightGrid
FM music-volume slider and default radio toggle.

## Curated programming

| Venue/use | Initial programming |
| --- | --- |
| Title screen | BOOT SEQUENCE, NEON CHECKSUM, PHOSPHOR GHOSTS, CARRIER SIGNAL |
| Vehicle / NightGrid FM | All twenty original tracks, rotational playlist |
| PRISM CLUB / STATIC ROOM / BLUE HOUR | OVERCLOCK, RASTERBURN, PACKET LOSS, Blackout Bonus Round, Tournament in the Back Room, NEON CHECKSUM |
| Ink & Tonic / Afterimage Lounge / Dock Nine | NULL DISTRICT, MEMORY ADDRESS, PHOSPHOR GHOSTS, The Coin Slot Is Taped, LAST PACKET HOME |
| Cafés including Lantern Cup | SAVE POINT, High Score With No Name, Second Controller, Sweep the Carpet at Sunrise, Fix It With a Paper Clip |
| Food stalls | Door on the Spin Cycle, MIDNIGHT BUS, CARRIER SIGNAL, Second Controller, The Coin Slot Is Taped |

Titles are shown as credits in-game and can be retuned later after playtesting.
All 20 appear in the in-car programming.

## Required audio pack

The source recording set totals about 898 MiB of WAV. The supplied game-ready
archive contains 20 Ogg Vorbis, stereo 48 kHz files (approximately 50 MiB
combined) and a checksum/duration JSON manifest. Unzip the archive **at the
repository root**, retaining paths under
`assets/audio/nightgrid_fm/<track_id>.ogg`. Example paths:

- `assets/audio/nightgrid_fm/boot_sequence.ogg`
- `assets/audio/nightgrid_fm/blackout_bonus_round.ogg`
- `assets/audio/nightgrid_fm/the_coin_slot_is_taped.ogg`

All 20 expected IDs are defined in `scripts/nightgrid_fm.gd`. To ship audio
inside an exported Windows game, commit those .ogg files to the repository (or
otherwise provide them in the checkout before Godot import/export). The
current code branch contains the integration and metadata, **not the actual
binary tracks**. In checkouts without tracks, the director fails quietly and
original venue ambience still works. Do not mistake a code-only build for
a full audible soundtrack implementation.

## Acceptance

1. Import assets: `godot --headless --path . --import --quit`.
2. Run `godot --headless --path . --script res://tests/nightgrid_fm_smoke.gd`:
   it checks all IDs, playlists and either 0 or 20 installed tracks.
3. Launch normally: title plays BOOT SEQUENCE and fades when entering the world.
4. Enter a parked car, drive, use B/N (or D-pad Right/Up), check track titles;
   adjust music level and confirm settings survive a restart.
5. Walk to an open club around 23:00: music becomes audible nearby, is
   strongest inside, and falls off across the street. Return at noon: club
   music should be silent when closed.
6. Visit a café and a bar; verify appropriate playlists and that procedural
   room textures/sounds remain. Pause/unpause and save/load during playback.
7. Export Windows build with all Ogg assets present; confirm an actual Windows
   playtest before calling the audio system complete.

## World audio and tactile feedback (same branch)

The **NightGrid FM music director** is complemented by the original,
creator-owned **city Foley** system in `scripts/world_audio.gd` and
`scripts/city_foley.gd`. It is not dependent on the 20 Ogg files and works
in source-only builds.

- Four long (~9 second), cached original PCM beds: subdued street wind, distant
  traffic, Southworks/West Docks industrial hum and waterfront ambience.
  Each layer changes with district, time of day and whether the player is
  inside a building or car; levels fade rather than cutting hard.
- Footfalls are triggered from **actual walking distance**, not a fixed number
  of video or physics frames. Concrete and interior tile have separate cached
  four-step variations. Entering cars, walking into walls, teleporting,
  airborne movement and large position discontinuities do not spam steps.
- UI menu choices have a separate original, short confirmation tone.
- Existing original KESTREL electric motor, train, café and venue audio stay
  intact, so this adds texture instead of replacing current work.
- New independent **City Ambience** and **Footsteps / Interactions / UI**
  sliders sit next to Master and NightGrid FM Music in settings. Audio can be
  turned completely off without interfering with saved game state.

### Testing

Run `godot --headless --path . --script res://tests/world_audio_smoke.gd`
to check cache use, waveform formats, environment layers, footstep distance,
no teleport bursts and settings persistence.

**Honest limitations:** these generated beds are a starting sound design,
not real-world recorded city ambience; there are no authentic sampled footfalls,
car door foley, siren Doppler, street-level occlusion meshes, frequency-aware
reverb or independent Godot bus layout yet. A Windows headphone listening pass
is required for loudness and timing QA. The broader world-audio issue #33
remains open.
