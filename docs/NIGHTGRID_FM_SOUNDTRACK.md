# NightGrid FM

The game contains twenty authorized tracks from the creator's *Afterimage* and *Free Play Until Dawn* Chipwave albums. The earlier game-ready archive and manifest were unavailable in this checkout. The current Oggs were rebuilt from the matching 48 kHz stereo WAV masters, with no track substitutions. The encoded library is 74,513,436 bytes and runs for 64 minutes and 43.22 seconds. The source WAVs are kept outside the repository. [Manifest with master and encode hashes](../assets/audio/nightgrid_fm/NIGHTGRID_FM_AUDIO_MANIFEST.json).

Credit **NightGrid FM — original chipwave by the game's creator**. The creator granted use in NightGrid Afterhours, including its exported build and game playback. Permission for reuse outside the game remains with the creator.

## Where it plays

| Context | Programming |
| --- | --- |
| Title | Boot Sequence, Neon Checksum, Phosphor Ghosts and Carrier Signal |
| Vehicle | All twenty tracks in the NightGrid FM rotation |
| Clubs | Overclock, Rasterburn, Packet Loss, Blackout Bonus Round, Tournament in the Back Room and Neon Checksum |
| Bars | Null District, Memory Address, Phosphor Ghosts, The Coin Slot Is Taped and Last Packet Home |
| Cafés | Save Point, High Score With No Name, Second Controller, Sweep the Carpet at Sunrise and Fix It With a Paper Clip |
| Food stalls | Door on the Spin Cycle, Midnight Bus, Carrier Signal, Second Controller and The Coin Slot Is Taped |

In a car, **B** or **D-pad Right** toggles NightGrid FM. **N** or **D-pad Up** skips. The music and power preferences persist in the usual settings file. An optional track ID and playhead in v1 saves resume the station after loading. Older saves start the seeded car playlist normally.

Two stereo decks overlap during a 1.15-second equal-power fade. Godot requests compressed tracks on background resource loaders, keeping the audible deck alive while an incoming stream prepares. The title, car and indoor playlists share the decks. A single filtered street emitter follows one nearby open venue, and the song and its playhead carry through that venue's doorway. Pause ducks the current song. Audible MBPD speech briefly lowers music further.

## Rebuild and test

Give `tools/prepare_nightgrid_fm.py --source` a local Chipwave folder containing the two source album directories. The tool verifies every WAV matches the game catalog by title, encodes at Vorbis quality 5 and checks the resulting durations. Supply FFmpeg and FFprobe paths if necessary. The stock game and export require no network access.

```powershell
python tools/prepare_nightgrid_fm.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/nightgrid_fm_smoke.gd
```

The manifest verifier checks all twenty Ogg files. The Godot regression checks loading, skip, the two-deck overlap, radio power and saved tuning. The Windows audio report contains the actual game recordings. [Audio checklist and native evidence](AUDIO_MIX_QA.md).
