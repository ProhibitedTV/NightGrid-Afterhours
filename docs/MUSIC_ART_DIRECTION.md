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

## Quality-first studio profiles (candidate pilots)

For new final-score auditions, prefer the studio profile instead of the
original fast sketch setup. Preserve the legacy profile/default for existing
batch resumption; never overwrite a legacy or alternate-palette batch.

| Profile | DiT | LM | Inference | Offload |
| --- | --- | --- | --- | --- |
| legacy | turbo | 0.6B | 8 steps, CFG 1 | Original configuration |
| studio | SFT | 1.7B | 50 steps, CFG 7 | PyTorch LM, CUDA with CPU offload; DiT CPU offload |
| studio-4b-cpu | SFT | 4B | 50 steps, CFG 7 | PyTorch LM on CPU; DiT CUDA with CPU offload |

Both studio profiles keep INT8 weight-only DiT quantization and one take
in flight to limit VRAM. The 16/24 GiB available WSL RAM minimums respectively
are conservative pilot guardrails, not measured peak RAM requirements.
A missing checkpoint, insufficient RAM, incompatible installed API or
unexpected LM device/offload state stops the run rather than substituting a
smaller model. Model downloads are deliberately not part of this runner.

Preview from the existing checkout, no GPU or checkpoint load:

    bash tools/audio/run_anubis_music.sh --plan --palette neon-grunge-v1 --profile studio --batch music-neon-grunge-studio-001

After reviewing exact checkpoint licenses, obtaining the local SFT and 1.7B
weights if missing, and stopping other GPU jobs, audition one new take:

    sudo bash tools/audio/run_anubis_music.sh --palette neon-grunge-v1 --profile studio --batch music-neon-grunge-studio-001 --limit 1

For the experimental 4B comparison only, use the same seed and cue in a
separate batch with the 4B weights installed and sufficient RAM:

    sudo bash tools/audio/run_anubis_music.sh --palette neon-grunge-v1 --profile studio-4b-cpu --batch music-neon-grunge-studio-4b-cpu-001 --limit 1

Do not run the whole batch until the comparison confirms musical quality,
actual duration, no truncation, technical QC, wall-clock, peak host RAM and
VRAM, and successful resume. CPU offload is a memory strategy, not a quality
guarantee. These settings are proposed, not native-validated; do not assume
the 4B LM improves every cue. Reference upstream ACE-Step documentation:
https://github.com/ace-step/ACE-Step-1.5/blob/main/README.md and
https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/GPU_COMPATIBILITY.md.

## Long-run safety

The music launcher now runs the existing Factory process-group supervisor in
strict single-GPU mode for the entire job, not just at take boundaries. It
checks NAS/SSD reserves and GPU temperature every 15 seconds, stops the
child process group if a reserve is breached, temperature reaches 85 C or
required telemetry disappears, and logs measurements locally under the Anubis
user's `~/.local/state/nightgrid-music/`. The runner also checks valid GPU
memory telemetry and the initial free-VRAM reserve. WSL temperature recovery
uses the existing UUID-matched Windows nvidia-smi fallback; if Windows interop
is unavailable the job refuses to launch rather than disabling the guard.
Other Factory lanes retain their previous policy. These software checks are
not hardware thermal protection. Native WSL interop, process interruption,
resume and long-run thermal behavior require an actual one-take audition.

## Modern studio export compatibility

Studio profiles request ACE-Step's public `wav32` format (direct SoundFile float export in upstream `acestep/audio_utils.py`). TorchAudio 2.9+ uses TorchCodec and ignores the old backend selector: https://docs.pytorch.org/audio/stable/generated/torchaudio.save.html . FFprobe checks stereo 48 kHz float PCM before FFmpeg writes the existing PCM24 master. A silent fallback to ordinary WAV fails closed. The original legacy profile's fingerprints and format remain unchanged; start a fresh studio batch if an earlier studio take already exists. Model initialization and generation call signatures are checked against the installed library before invoking model initialization. No modification of the installed ACE-Step checkout, package upgrade or clone is performed. Upstream internal warnings may still occur; retain native logs and report exact messages rather than suppress them. Native validation is still required.
