# Morrow Bay musical north star — neon futurism / underground grunge

Creator direction, 2026-11-27. The city should have a recognizable fictional
musical era: futuristic analog electronics colliding with the vulnerability,
alienation and rebellious energy of 1990s alternative rock. This is an original
musical movement, not a recreation of any existing song, performer or band.

## Musical grammar

- Clean detuned guitars, short angular original motifs, suspended/minor harmony,
  vulnerable quiet passages against fuzz-heavy choruses.
- Warm analog bass, arpeggiators and precise machines against loose acoustic
  drums, imperfect live phrasing, worn amplifier and tape textures.
- Corporate score suppresses the human element; street freedom brings guitar
  and acoustic percussion forward. Never make every cue a dense rock song.
- Leave headroom and space for dialogue, traffic and dispatch. Pursuit gains
  rhythmic density; cooldown exposes the vulnerable melodic texture again.

## In-world culture

The fictional underground scene should have its own bands, independent record
shops, flyers, rehearsal spaces, basement shows and local radio interviews.
The player may discover that culture through the existing musician career.
These are creative targets, not newly implemented venues or gameplay.

| Context | Production direction |
| --- | --- |
| Synaxis | Clean sterile electronic pulse; barely audible guitar humanity |
| Offboarding | Fragile exposed guitar and empty space |
| Departure | Analog bass, guitar and loose drums as agency returns |
| Brickwater | Rain, worn tape, dub delays, tremolo and fuzz swells |
| Southworks | Machinery rhythm, distorted bass and garage drums |
| Afterhours clubs | Raw live-room alternative bands and electronic crossover |
| Vesper club | Dance-floor electronics, not mandatory rock |
| Home | Quiet intimate guitar and warm analog pads |
| Title / credits | Original recognizable melodic cell, quiet-loud contrast |

Anubis has a versioned 24-cue palette in `tools/audio/neon_grunge_palette.json`.
The palette retains the existing cue IDs, durations, keys, tempo targets and
seed schedule, but changes creative prompts. These prompts are not evidence
of measured tempo/key, continuity or a shared recorded motif.

## Candidate-only production

Never change the existing music-001 job specifications mid-batch. The original
default remains untouched. Preview the new prompts from the existing checkout:

    bash tools/audio/run_anubis_music.sh --plan --palette neon-grunge-v1 --batch music-neon-grunge-001

After the current GPU work stops, and only after the new branch is merged
and exact checkpoint/output rights have been reviewed, the operator may choose
a one-take comparison before authorizing a full batch:

    sudo bash tools/audio/run_anubis_music.sh --palette neon-grunge-v1 --batch music-neon-grunge-001 --limit 1

The new batch is separate on NAS. Do not launch another GPU job concurrently,
delete previous takes, or treat a good-sounding output as commercial clearance.
Compare with the initial candidate, perform technical QC and human listening,
and approve exact hashes before runtime staging. No changes to NightGrid FM,
Godot rendering, game saves or currently running scripts are required.

References to eras and broad genres guide original production; do not prompt
for a real artist, cloned vocals, borrowed melodies or soundalike recordings.
A recognizable original main motif and controlled alternate arrangements need
separate composition and listening work; prompt similarity alone is insufficient.
