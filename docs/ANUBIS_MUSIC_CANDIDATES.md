# Anubis original music candidate intake

Tracks [#545](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/545). The music creation models are **studio tools**, not LLMs that run in Godot. This path can accept original atmospheric score, radio-ad jingle, club underscoring, arcade-loop and cinematics drafts for human evaluation. Existing NightGrid FM master tracks, programming, rights and 20 published Oggs remain unchanged.

## Existing local model candidates

The previous local workstation experiments included ACE-Step 1.5 with a 5Hz LM 1.7B checkpoint + Qwen3 embedding, and AudioCraft/MusicGen stereo-small and stereo-medium checkpoints in separate CUDA environments. Historical checkpoint discovery **does not** establish that either model currently runs, that an individual take exists, or that model weight and output rights permit commercial release. Verify local paths/versions/requirements before any synthesis. Keep model installations, prompts, WAVE masters, rejected takes and logs outside Git. Coordinate with the existing Anubis factory lock and audio lock; RTX 3060 12 GiB supports only bounded, one-model-at-a-time jobs.

## Candidate-only WAV manifest

Create a separate private input directory (prefer the NAS) with generated original PCM stereo WAVs and a JSON manifest. **Never supply the approved NightGrid FM master directory as the source.** Example manifest:

```json
{
  "schema": 1,
  "candidates": [{
    "id": "synaxis.lobby.ambient-01",
    "file": "synaxis-lobby-original.wav",
    "sha256": "REPLACE_WITH_LOWERCASE_64_CHARACTER_SHA256",
    "model": "ace-step",
    "checkpoint": "exact local checkpoint revision or hash",
    "scene": "Synaxis HQ arrival vestibule",
    "direction": "Original corporate ambient underscore; quiet pulse, avoid melody collisions with footsteps and badge cue",
    "rights_notes": "Review model weights/output-use rights before any game approval",
    "reviewed": false
  }]
}
```

Run from an updated repository checkout:

```sh
python tools/audio/music_candidate_intake.py --manifest /path/to/private/music-manifest.json --source /path/to/private/wav-masters
python tests/test_music_candidate_intake.py
```

The script is **read-only**. It rejects duplicate IDs, unsafe paths including symlink escapes, hash mismatch, missing source information, invalid PCM formats, oversized files, and duration outside 1–600 seconds. It checks stereo 44.1/48 kHz PCM16/24 but does **not** certify loudness, originality, seamless looping, absence of copyrighted likeness, hallucinated lyrics, model licenses, or true human review. It prints verified candidate metadata to standard output only; redirect that report to a **private** review location if needed. The checked `reviewed: false` field prevents accidental representation as approved.

Next work after the workstation's installed models and exact model rights are checked: optional isolated adapters for ACE-Step and AudioCraft, candidate export and music-specific QC (peak/RMS/LUFS, intro/outro, loops, duplicate similarity, scene mix listening), a private approval/rejection ledger, then independently authorized Godot cues using existing Music bus and dynamic ducking. No generated output becomes playable or releases automatically. Check native dialogue overlap and chapter transitions before promoting approved cues.
