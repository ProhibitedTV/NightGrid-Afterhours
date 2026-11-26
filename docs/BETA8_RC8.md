# NightGrid: Afterhours — Beta.8 RC8 | Voices of Morrow Bay

Windows x64 public playtest prerelease, Godot 4.7.2 / Forward+ / Vulkan. Published only from exact current main after successful project preflight, Windows export and native Windows startup smoke. The release uses the already-tested Windows artifact and verifies its checksums.

## What's new
- First Anubis production batch: 78 of 88 authored dialogue cues, including 24 corporate and 54 street/venue recordings. Fourteen original synthetic character identities were created locally using Qwen3-TTS on an RTX 3060 12 GB.
- Synaxis briefing, Mandarin call with English captions, breakroom choices and offboarding now have sequential speech on the Dialogue bus. Advancing cancels the current scene's speech; missing recordings retain text.
- Morrow Bay street and venue dialogue uses imported speech resources and scoped playback. The existing city, arcade, music career, phone and driving systems are included.
- Offline generation, provenance checks, and original synthetic cast references are versioned for future production. The game requires no model downloads, GPU inference or WSL.

## Install and test
Extract the entire ZIP into a fresh folder. Keep the EXE and PCK together. Verify SHA256SUMS.txt, read BUILD-INFO.txt, back up existing saves and start a New World. Follow PLAYTEST-GUIDE.md for the chapter and city routes. The optional living-streets pilot can be enabled as described in the guide.

## Known limitations
This is an explicitly provisional public playtest, not final voice or gameplay certification. The project owner has authorized distribution of the locally generated original synthetic recordings; machine QC does not imply individual human listening approval. Ten dialogue cues remain flagged and use text fallback, and 37 new environmental effects are not yet generated. Native acoustic quality, pacing, lip synchronization, frame pacing and performance targets remain to be evaluated. Report in-context issues with the speaker, location, source revision and relevant logs. Final dialogue release-review and complete-coverage gates remain separate from this preview.
