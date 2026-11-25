# NightGrid audio production studio

Part of [#308](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/308) and [#33](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/33). This implementation supports auditions, locked synthetic references, reference-conditioned production candidates, and explicit publishing. No actual game audio has yet been generated. No neural synthesis or GPU benchmark has been performed by the PR author. The existing soundtrack, spatial audio, dispatch and SFX work are not replaced.

## Repeatable authoring

Use a dedicated Python 3.11 environment on the RTX 3060 workstation (Linux/WSL2 is a starting point, not a verified Windows setup). Install CUDA-compatible PyTorch per upstream guidance, qwen-tts, soundfile and FFmpeg. Record exact package versions (the tool does this for each take); retain a fully resolved environment lock after a successful benchmark. Start with one model in memory, no FlashAttention requirement. See [Qwen upstream](https://github.com/QwenLM/Qwen3-TTS).

```sh
python -m venv .venv-voice
# Linux/WSL: source .venv-voice/bin/activate
# Windows PowerShell: .venv-voice\Scripts\Activate.ps1
# Install the supported CUDA PyTorch build first; then:
python -m pip install qwen-tts soundfile
python -m unittest discover -s tools/voice -v
python tools/voice/studio.py list
# Replace REVISION with the exact 40-character commit from the model repository:
hf download Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign --revision REVISION
python tools/voice/studio.py generate --revision REVISION --id synaxis.jetson.blinds --seed 308
python tools/voice/studio.py generate --revision REVISION --id synaxis.jetson.blinds --seed 309
# Listen to take.wav, compare takes, check model/checkpoint/output rights and text.
python tools/voice/studio.py approve --id synaxis.jetson.blinds --take FINGERPRINT --reviewer "Creative director" --notes "Listening and pronunciation notes" --rights-checked
python tools/voice/studio.py verify --id synaxis.jetson.blinds --take FINGERPRINT
```

Model acquisition may also require the exact compatible tokenizer assets in the local Hugging Face cache; if offline inference fails, resolve that explicitly, never silently switch to online inference. The implementation uses VoiceDesign for *auditions only*. Re-running the same seed and package settings does not guarantee bit-identical synthesis across different GPUs. For an existing verified candidate the cache avoids rerendering. A new seed generates a distinct take. Each directory is keyed by text, character direction and generation settings, and holds normalized mono 48 kHz PCM, a provenance record and optional explicit review bound to both hashes. Review is not cryptographic identity authentication and is not a substitute for a license check. The production workflow below adds character reference locking and explicit asset intake.

After audition selection: freeze original synthetic voice reference WAV + transcript + hash and model revision using the production tool; use Qwen Base voice clone for consistent casting across lines. VoiceDesign calls with matching descriptions alone do not ensure the same voice. Compare Chatterbox in a separate environment; optionally use RVC only with reviewed checkpoint/reference permissions. No real-person impersonation. Use offline ASR and language review as additional acceptance checks, not substitutes for listening.

## Whole-city coverage and delivery order

| Family | Existing foundation | Next production target | Runtime acceptance |
| --- | --- | --- | --- |
| Corporate chapter | #307 text/captions and SFX authoring | Jetson, Lin, protagonist, HR, security; full scene VO | Caption parity, localized phone call, gestures, skip/pause, no double advance |
| City pedestrians | Pedestrian director and spatial footsteps | Context barks, nearby paired conversation, reactions | Distance and occlusion, cooldown, no speech from despawned actors |
| Businesses | Venue ambience and walk-in shops | Greetings, service, vending prompts, café and bar conversations | Actual occupancy and opening hours; voice budget and music ducking |
| Police and EMS | MBPD synthesized radio and civic ledger | Consistent dispatcher/unit voices; contextual emergency sounds | Preserve priority, captions, pause, jurisdiction, closure and mute |
| Traffic and transit | Bounded traffic and rail audio | Horns, tire/surface variation, station announcements, driver barks | Speed and real stop state, no per-vehicle unbounded voice |
| Weather and city beds | Eight district profiles, recorded field ambience | Layered weather, alley vents, waterfront, construction and nighttime texture | Seamless loop transitions, zone falloff, sheltered exterior mix |
| Player and actions | Footsteps, doors, vending, delivery and vehicle sounds | Clothing, exertion, handoff, surface variations, damage feedback | Movement/event-synchronized, bounded one-shots |
| Missions and cinematics | Story/courier/progression scripts | Recurring cast, conversation trees, music transitions | Stable line IDs, save/load, interruption, missing-asset text fallback |
| Music | Twenty original NightGrid FM tracks | Curated venue/car programming and scene cues | Keep station state and existing user controls |

## Common production contract

One stable asset ID per logical cue; metadata includes text or SFX prompt, intended trigger and spatial context, provenance (source/model exact revision, rights, seed/settings, dependency versions), duration and hashes, review notes and approved variant. Dry voice masters separate from environmental effects; apply phone/radio/room treatment by context. Asset approval is separate from scene integration, and both are separate from release approval. Never ship candidate directories, GPU environments, checkpoints, or credentials. Avoid duplication of source-owned music and existing licensed recordings.

For production intake, keep dialogue and SFX master formats appropriate to the cue (short dry mono PCM, compressed long dialogue after quality review, seamless ambience with separately validated loop points). Verify approved inventory against actual packaged Godot paths, fail CI for missing required assets or stale line text, and retain subtitle fallback for optional clips. Use existing independent mix stems, bounded 3D emitters and asynchronous/prewarmed resources. No AI at runtime; no per-frame disk reads; do not change 60 Hz physics or city streaming to accommodate audio.

Acceptance per scene: native Windows capture at actual play volume, listening and accessibility pass, pause/skip/transition tests, memory and frame pacing on RTX 3060, exact revision. Measure render time, peak VRAM and failed takes separately on the authoring workstation. Coverage is a roadmap, not evidence that all listed cues exist.

## Remaining implementation

1. Native GPU smoke and blind auditions (six fixture lines, several seeds).
2. Benchmark the implemented locked voice references and Qwen Base adapter; Chatterbox comparison.
3. Automated transcript QC, required asset coverage gate, game-side voice director and lip sync. Publish/verify contract and basic PCM duration checks implemented.
4. Integrate into corporate branch after coordination; expand coverage in location-specific batches.
5. Unify the SFX authoring contract from #307 without replacing its existing working paths; audit model-specific commercial eligibility before publication. Existing AudioCraft weights and Stable Audio checkpoints have different terms. No automatic license inference from source code.


## Lock a cast member and bake production lines

After approving a VoiceDesign audition with studio.py, run:

```sh
python tools/voice/production.py lock --id synaxis.jetson.blinds --take AUDITION_FINGERPRINT
hf download Qwen/Qwen3-TTS-12Hz-1.7B-Base --revision BASE_REVISION
python tools/voice/production.py generate --id synaxis.jetson.blinds --revision BASE_REVISION --seed 310
python tools/voice/qc.py --id synaxis.jetson.blinds --take PRODUCTION_FINGERPRINT --model-dir /path/to/local-whisper-model
python tools/voice/production.py approve --id synaxis.jetson.blinds --take PRODUCTION_FINGERPRINT --reviewer "Creative director" --notes "Reviewed performance, transcript and identity" --rights-checked
python tools/voice/production.py publish --id synaxis.jetson.blinds --take PRODUCTION_FINGERPRINT
python tools/voice/production.py verify-library
```

Replace placeholders with actual exact model revisions and printed candidate fingerprints. A cast lock contains the reviewed original synthetic WAV, transcript, original metadata and rights attestation. Back up `dist/voice-cast` to a private authoring archive; the public game repository receives only approved production clips and their provenance, not the reference WAV. The production adapter refuses to replace a locked character or existing published line silently. To revise a published line, deliberately archive/remove its old directory, publish a replacement, review the diff and rerun checks. Recasting requires replacing **all** published lines for the character together, not mixing voices.

The Qwen Base reference-conditioned API does not take free-form acting direction in this implementation; the original direction remains in the take metadata and must be checked by listening. Vary seed and evaluate alternate backends for emotional performance. Identical model/reference hashes are a consistency aid, not proof of perceived voice identity. Do not claim production quality before real auditions.

Published path: `assets/audio/voiced/<line-id>/take.wav`, with `take.json`, `qc.json` and `review.json`. Library verification runs offline without models, checks existing audio against the current manifest and rejects mixed cast identities. An empty library is allowed while authoring; the chapter release coverage gate below must be run explicitly. The six current lines are audition fixtures, not the complete canonical dialogue catalog; the integration pass must bind them to the actual story source before shipping. Only one writer should use the pipeline at a time. No automatic publication.

## Godot speech channel (first integration)

The World now owns `DialogueDirector` alongside the existing MBPD radio. Its two fixed player nodes share the existing dialogue volume; actual speaking joins radio activity for existing NightGrid FM ducking. Captions are displayed by the World speech card independently of audio volume. It is ticked once from World with the current actor position; snapshot restoration clears transient speech. No new story triggers are wired in this slice.

For a later mission or venue, prewarm its approved line IDs at scene setup using `prewarm(id)` (or supply a preloaded stream with `cache_clip`); use `enqueue(id, canonical_caption, priority, speaker, scope)` from the actual mission event. Pass the physical speaker node for 3D sound or null for UI speech. Connect `line_ended` to animation/scene timing, with reason checks; do not use a skipped, cancelled or unavailable line to grant rewards. `skip()`, `cancel_scope(scope)`, `cancel_all()` and `clear_bank()` are explicit lifecycle controls. Never add hardcoded audition text to live missions. The queue holds eight entries, one active line, and up to 64 prewarmed clips; higher priority can interrupt ambient speech. Physical speakers must remain in the scene and within 18m. This initial channel does not yet implement occlusion raycasts, room reverberation, concurrent crowds, visemes or the canonical script catalog. Audio clips are absent until a real bake. The headless smoke validates lifecycle and fallback, not native acoustic quality.

## Offline speech QC gate

Install `faster-whisper` in the isolated voice environment. Acquire a complete **multilingual** CTranslate2 Whisper checkpoint separately, pin its exact source revision and review its license; the QC tool expects a local model directory containing model.bin, config.json and tokenizer.json. It fingerprints local files and records installed ASR package versions. CPU int8 is the default to avoid contending for VRAM with the voice generator; CUDA is explicit. The ASR invocation follows the upstream faster-whisper local-model API (https://github.com/SYSTRAN/faster-whisper). No reference transcript is passed to recognition; English is compared by normalized words and Mandarin by normalized written characters against the spoken script, never its English caption.

Run qc.py for the exact candidate as shown above. Its qc.json records the recognized transcript, edit count/rate, PCM duration, peak, RMS and leading/trailing/overall quiet measurements. Any normalized transcript difference or excessive quiet flags the take for review. These thresholds are provisional triage, not perceptual quality or speaker-identity certification. Chinese script variations, proper names, numbers and intentional pauses may cause legitimate flags. Listen to the complete take; regenerate bad speech. If a flagged take is genuinely correct, production.py approve requires a specific listening-based --qc-override in addition to the existing reviewer, notes and rights checks.

Production publication now requires qc.json and a review tied to its exact bytes. The four published files are take.wav, take.json, qc.json and review.json. Validation recomputes metrics and rejects stale or inconsistent records without loading ASR models. Re-running QC invalidates an earlier review if the report changes. Earlier production approvals without QC must be redone; no published production assets existed when this change was authored. Audition review/cast locking remains separate. Test transcripts and WAVs are synthetic fixtures, never game assets. Real Whisper inference and bilingual accuracy on the target workstation remain unverified.

## Canonical Chapter One production batch

`tools/voice/synaxis_chapter.json` is a production manifest for 27 spoken rows, six original characters, seven scene blocks and both Mandarin utterances with English captions. Its source is the pinned corporate branch revision 6225d774650b116aa92a4945f4b484f1902726cf. Written ticket text, automated notices and nonspoken HR labels are intentionally excluded; the catalog is not yet the full office, guard or city dialogue inventory. The audio branch still has the older prologue script, so the pinned snapshot can be validated here but **live source parity cannot be claimed until integration**.

```sh
python tools/voice/chapter.py validate
python tools/voice/chapter.py status --json
python tools/voice/studio.py list --manifest tools/voice/synaxis_chapter.json
# Use --manifest tools/voice/synaxis_chapter.json with EVERY audition, lock,
# generation, QC, approval and publish command in this production batch.
# Example cast audition and reference lock:
python tools/voice/studio.py generate --manifest tools/voice/synaxis_chapter.json --id synaxis.conference.01 --revision VOICEDESIGN_REV
python tools/voice/studio.py approve --manifest tools/voice/synaxis_chapter.json --id synaxis.conference.01 --take AUDITION_HASH --reviewer "Creative director" --notes "Reviewed performance and rights" --rights-checked
python tools/voice/production.py lock --manifest tools/voice/synaxis_chapter.json --id synaxis.conference.01 --take AUDITION_HASH
# Render multiple lines in one process once the corresponding cast is locked:
python tools/voice/production.py generate --manifest tools/voice/synaxis_chapter.json --id synaxis.conference.01 --id synaxis.conference_end.04 --revision BASE_REV
# QC accepts paired repeated --id/--take in the same order; model reused:
python tools/voice/qc.py --manifest tools/voice/synaxis_chapter.json --id synaxis.conference.01 --take TAKE_HASH_1 --id synaxis.conference_end.04 --take TAKE_HASH_2 --model-dir /path/to/whisper
# Approve and publish each exact take separately, never automatically.
python tools/voice/chapter.py status
# On the integrated branch only:
python tools/voice/chapter.py require-complete --source scripts/opening_story.gd
```

The status inventory distinguishes needs_cast, needs_render, needs_qc, flagged, needs_review, approved and published. It verifies each published asset, reports invalid candidate fingerprints, and never approves or publishes automatically. Cache reuse requires unchanged source, settings, audio and QC provenance. The explicit release command fails on changed mission text, missing clips or failed published verification. The ordinary authoring CI tolerates missing clips while production is underway. The current fixture audition manifest is not the publishable chapter inventory; use the chapter manifest consistently and do not publish fixture-only IDs into the production library. A future integrated release workflow must invoke the strict gate before declaring the chapter voiced. No actual neural clips, gameplay triggering, lip sync, or native proof is supplied by this catalog.


## Anubis quick start (WSL2 Ubuntu)

Use a clean worktree/clone of this branch and a dedicated Python environment. GPU driver must support the chosen CUDA PyTorch wheels; verify CUDA before starting. No native Windows or WSL hardware validation has been performed yet.

```bash
sudo apt-get update
sudo apt-get install -y python3-venv ffmpeg sox
python3 -m venv .venv-voice
source .venv-voice/bin/activate
python -m pip install --upgrade pip
# Example CUDA 12.8 wheels; adjust to supported driver/Python per pytorch.org.
python -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu128
python -m pip install qwen-tts soundfile faster-whisper
python -c "import torch; print(torch.cuda.is_available()); assert torch.cuda.is_available()"
python tools/voice/anubis.py setup
python tools/voice/anubis.py bake --all
```

Setup resolves and records the exact VoiceDesign, Base and multilingual Whisper model revisions in dist/voice-models.json before downloading them, so rerunning setup resumes those revisions. Back up that file and dist/voice-cast. Reserve space for both Qwen models, Whisper, the environment and candidate WAVs. Bake is offline, first generates two auditions per missing character, prompts to choose and explicitly confirm rights/listening review, then renders selected lines with locked voices and runs CPU QC. Enter to defer a cast; use --non-interactive to create auditions without prompting. Rerun the same command after interruption. Generated audio is in dist/voice-production, not the shipped library. Final take review and publication remain separate commands above. A different --seed makes another take for selected unpublished lines; existing published assets are not overwritten.

```bash
python tools/voice/anubis.py list
python tools/voice/anubis.py bake --id synaxis.conference.01
python tools/voice/anubis.py bake --character lin
python tools/voice/anubis.py bake --id synaxis.conference.01 --seed 311
python tools/voice/anubis.py status
```

Current scope is the 27-line chapter voice catalog. The environmental SFX authoring files from corporate revision 64dde941 are now also present on this branch; their dependency environment and model-specific license review remain separate. No claim that this generates the entire future city audio library or runs on Anubis without a first hardware smoke.


## Unified Anubis SFX + dialogue command

The existing 37-cue SFX catalog (office, city, four footstep surfaces) is included alongside the 27 spoken dialogue lines. Install Stable Audio 3 in its own upstream uv environment rather than modifying the Qwen environment. From the Afterhours-Audio checkout, with the voice venv active:

```bash
python -m pip install uv
git clone https://github.com/Stability-AI/stable-audio-3.git ../stable-audio-3
(cd ../stable-audio-3 && uv sync && git rev-parse HEAD)
# Review and accept applicable model terms, authenticate if necessary:
# https://huggingface.co/stabilityai/stable-audio-3-small-sfx
SFX_CLI="$(realpath ../stable-audio-3/.venv/bin/stable-audio)"
python tools/voice/anubis.py bake-all --sfx-cli "$SFX_CLI"
```

This runs all 37 effect candidates first, then the dialogue cast/production/QC workflow. The first SFX invocation may download upstream weights. After cache initialization use HF_HUB_OFFLINE=1 and TRANSFORMERS_OFFLINE=1 for offline reruns; the existing SFX CLI adapter does not yet lock the exact model-weight revision, and a stronger pinning contract is still needed. Retain the upstream commit and model cache provenance; review actual checkpoint license and output terms before publication. The effect adapter checks candidate spec and audio hash on resume, and refuses accidental replacement.

```bash
python tools/voice/anubis.py sfx-list
python tools/voice/anubis.py sfx-bake --sfx-id lift_chime --sfx-cli "$SFX_CLI"
python tools/voice/anubis.py sfx-bake --sfx-group steps --sfx-cli "$SFX_CLI"
python tools/voice/anubis.py bake --character lin
python tools/voice/anubis.py bake --id synaxis.conference.01
```

Default SFX device is CPU; opt into CUDA with --sfx-device cuda. SFX candidates live at dist/sfx-candidates; speech at dist/voice-production. Neither is published by bake-all. The separate SFX script supports explicit reviewed publication and verification; do not use --reviewed until listening and rights review. No runtime model dependencies. The dialogue catalog includes the seven initial scene blocks and breakroom choices, not every later optional NPC interview or guard branch; future authored cues need stable IDs and actual runtime triggers. This is an initial combined 64-cue library, not proof of complete city coverage. Both engines still require the first native Anubis smoke.

## Integration checkpoint

At main revision 73216c8, the seven pinned spoken script constants match the catalog. CI now checks the actual local opening script for drift; adding more dialogue still requires extending the catalog. No recordings have been baked or approved in the repository by this integration. Do not claim fully voiced gameplay until runtime triggers and strict published coverage pass.
