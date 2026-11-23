# Morrow Bay field recordings

These are non-musical sound effects from the creators' public Freesound previews. All five source pages identify their recordings as CC0 1.0. The game redistributes the edited effects under that same dedication. [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/).

| In-game files | Credited source |
| --- | --- |
| `traffic.ogg` | [Seamless City Loop by qubodup](https://freesound.org/people/qubodup/sounds/223093/), based on a city recording by jmbphilmes |
| `harbor.ogg` | [Harbor Ambience 1 by clif_creates](https://freesound.org/people/clif_creates/sounds/254125/) |
| `steps/stone_*.wav`, `steps/asphalt_*.wav` | [Hiking Boot Footsteps on Stone by Fission9](https://freesound.org/people/Fission9/sounds/521590/) |
| `steps/gravel_*.wav` | [Hiking Boot Footsteps on Gravel by Fission9](https://freesound.org/people/Fission9/sounds/521588/) |
| `steps/tile_*.wav` | [Footsteps On Tile by IENBA](https://freesound.org/people/IENBA/sounds/834027/) |

The ambience uses 32 kHz Vorbis loops with filtered lows and an 800 ms circular seam. The boot bank uses four individually trimmed 32 kHz mono PCM clips per surface. Asphalt is a filtered derivative of the stone recordings. The manifest records all five downloaded preview hashes and all eighteen edited file hashes. [Manifest](MANIFEST.json).

To rebuild, save the public previews as `traffic-preview.mp3`, `harbor-preview.mp3`, `stone-preview.mp3`, `tile-preview.mp3` and `gravel-preview.mp3`. The script checks loop length and writes the WAV cuts and Ogg loops using FFmpeg with libvorbis. [Authoring script](../../../tools/prepare_morrow_bay_audio.py).

Original game-designed electrical fans, service machinery, wind details, tire roll, brake transients and door cues are synthesized deterministically by the repository's audio code. Existing Kestrel and M-Line sounds remain game-authored effects. MBPD voice recordings are generated offline from the game's fictional dispatch captions with eSpeak NG. [Dispatch source notes](../mbpd/README.md).
