# Anubis unattended production — batch 002

From Windows CMD in the checkout, run:

```bat
tools\audio\run_anubis_batch.cmd --rights-checked --sfx-rights-checked
```

The first flag confirms original synthetic dialogue rights. Before including the second flag, review the [Stable Audio license](https://stability.ai/license), accept the [gated checkpoint terms](https://huggingface.co/stabilityai/stable-audio-3-small-sfx) on your own Hugging Face account and authenticate in WSL if needed. Do not paste tokens into Git or logs. No license/login prompt is automated or bypassed. With only --rights-checked, voice runs and the summary reports SFX blocked. Use --voice-only for a voice-only batch or --sfx-only --sfx-rights-checked to resume just effects. --plan prints the queue without inference.

Batch 001's 78 verified lines and 14 cast references are reused. Missing lines receive up to three seed passes (312, 314, 316), in groups of 12; already published audio is not replaced. Failures are recorded and later groups continue. The worker uses the established voice venv, then a separate locked uv environment for Stable Audio at a pinned upstream commit; one engine runs at a time. The SFX worker pins primary model weights, loads once, processes all 37 effects with their authored seeds and PCM validation, and caches candidate files. Auxiliary text-encoder versions remain upstream-managed. SFX files are cached in dist/sfx-candidates, then copied into assets/audio/generated/synaxis as provisional playtest assets after technical QC. They retain reviewed=false, playtest_accepted=true, and rights confirmation. Existing different assets are never overwritten. The ordinary generate_sfx.py verify gate still rejects machine-only intake; verify-playtest allows the explicitly provisional assets. The runner checks gated access before installing the SFX CUDA stack, so missing access is reported early while dialogue still proceeds. On first run, installing dependencies and downloading weights can take substantial time; no authentication prompt is issued by the batch. Use --sfx-device cpu if the CUDA worker fails. The same command resumes; corrupted or mismatched candidate pairs are flagged, not overwritten. No auto-push.

Output: dist/anubis-batch/run-*.log, summary.json and sfx-results.json. A nonzero exit code can mean partial success or remaining cues; inspect the report, not just the exit code. The launcher prevents simultaneous batches under the same WSL user. Results are local; commit only validated runtime assets and cast changes from Windows Git. Native inference and SFX listening still require testing on Anubis.

The launcher does not commit or push. After the job, inspect the summary, then stage only intended assets (assets/audio/voiced, assets/audio/generated/synaxis, tools/voice/cast-library) from Windows Git. The 37 effects are provisional until native listening, and auxiliary encoder weights are not independently pinned. No final release claim is made.

On Anubis, after accepting the checkpoint terms, authenticate once from Windows CMD if required: `wsl -d Ubuntu -u anubis -- /home/anubis/afterhours-voice/bin/hf auth login`. Enter the token only into the official local CLI prompt, never into the batch command or repository. Close Docker Desktop and the game before generation; keep Windows awake and the batch terminal open.
