# Offline sound effects authoring

The game never runs a model or downloads audio. Stable Audio 3 Small-SFX is an optional development dependency. Its weights are gated: review and accept the model license yourself at https://huggingface.co/stabilityai/stable-audio-3-small-sfx. Review https://stability.ai/license before commercial distribution; Community License eligibility is not assumed.

Install upstream in a separate folder from https://github.com/Stability-AI/stable-audio-3 using its documented uv sync workflow. Authenticate to Hugging Face if required. Install FFmpeg and ensure it is on PATH. Use the upstream environment's stable-audio executable (on Windows .venv/Scripts/stable-audio.exe). Record the upstream checkout revision for reproducibility. The official CLI supports --model small-sfx, --device, --seed, --duration and -o. CPU is the conservative default; use --device cuda if the installed upstream runtime supports your GPU.

From the Afterhours repository root:

    python tools/audio/generate_sfx.py list
    python tools/audio/generate_sfx.py generate --id server_fans --cli PATH_TO_STABLE_AUDIO --device cpu
    python tools/audio/generate_sfx.py publish --id server_fans --reviewed
    python tools/audio/generate_sfx.py verify --id server_fans

Generate creates candidates under dist/sfx-candidates; listen to each WAV before publishing. A fixed seed is not a guarantee of identical bytes on different hardware. Publish requires an explicit review flag, records the prompt, seed, model, license and checksum, and refuses replacement unless --replace is set. Check for audible glitches, abrupt cuts, unintended intelligible speech, clipping and poor loop seams. The monitor impact needs editing to align its onset if necessary. Mono 48 kHz PCM16 keeps spatial emitters simple. Loops use overlap crossfade and one-shots use short fades. Sound levels are conservative and normalized. Commit reviewed WAV plus JSON together. Reimport with Godot and export all resources. No generated model weights are shipped.

Current runtime hookups: ground/workfloor room tone, B1 fan loop (existing synthesized fallback if absent), robotics bay servo ambience, Cal's keyboard strike and lift arrival bell. Printer and coffee station clips play during optional appliance interactions. Missing optional audio is silent; music and existing audio paths are untouched. Native model inference, listening review and export verification remain separate steps.

## City-wide authoring
The manifest now covers 37 slots: seven office assets, four outdoor ambience beds, one road roll loop, nine action events, and sixteen footstep variants. `--group office`, `--group city`, or `--group steps` selects a batch. `generate --skip-existing` resumes previously generated matching candidates. Existing audio is the fallback, and reviewed WAVs are loaded once when the world audio system starts. All gameplay uses the existing bounded voice pool and audio buses. For footsteps and single impacts, trim candidates to one well-timed event during review; a two-second generation window is not an acceptable two-second footstep. Do not distribute weights, caches, raw candidates or unreviewed assets. `assets/audio/generated/synaxis` remains the shared approved-asset path for compatibility.
