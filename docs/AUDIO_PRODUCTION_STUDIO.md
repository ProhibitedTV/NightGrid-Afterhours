# NightGrid audio production studio

Part of [#308](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/308) and [#33](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/33). This is the first **audition-only** implementation. It produces local candidate WAVs, not game assets. No neural synthesis or GPU benchmark has been performed by the PR author. The existing soundtrack, spatial audio, dispatch and SFX work are not replaced.

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

Model acquisition may also require the exact compatible tokenizer assets in the local Hugging Face cache; if offline inference fails, resolve that explicitly, never silently switch to online inference. The implementation uses VoiceDesign for *auditions only*. Re-running the same seed and package settings does not guarantee bit-identical synthesis across different GPUs. For an existing verified candidate the cache avoids rerendering. A new seed generates a distinct take. Each directory is keyed by text, character direction and generation settings, and holds normalized mono 48 kHz PCM, a provenance record and optional explicit review bound to both hashes. Review is not cryptographic identity authentication and is not a substitute for a license check. No production publish action until character reference locking and asset intake are implemented.

After audition selection: freeze original synthetic voice reference WAV + transcript + hash and model revision; use Qwen Base voice clone for consistent casting across lines. VoiceDesign calls with matching descriptions alone do not ensure the same voice. Compare Chatterbox in a separate environment; optionally use RVC only with reviewed checkpoint/reference permissions. No real-person impersonation. Use offline ASR and language review as additional acceptance checks, not substitutes for listening.

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
2. Locked voice references and Qwen Base adapter; Chatterbox comparison.
3. Automated transcript/duration QC, publish/verify contract, game-side voice director and lip sync.
4. Integrate into corporate branch after coordination; expand coverage in location-specific batches.
5. Unify the SFX authoring contract from #307 without replacing its existing working paths; audit model-specific commercial eligibility before publication. Existing AudioCraft weights and Stable Audio checkpoints have different terms. No automatic license inference from source code.

