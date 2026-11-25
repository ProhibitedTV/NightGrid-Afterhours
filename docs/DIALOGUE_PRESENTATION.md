# Cinematic dialogue presentation

The original Morrow Bay interface distinguishes NPC speech from system notifications. Existing café patrons surface a timed, named subtitle above the contextual action stack. Mara's existing reactive greeting and response occupy a separate, persistent speaker caption within the interaction panel. Actual prices, available contracts and talk options are exposed on the existing action buttons; long choices can wrap, and the conversation panel grows upward.

`scripts/dialogue_caption.gd` is presentation-only. Call `present(speaker, line, hold, voice_seconds)` for authored dialogue. Reading duration is bounded to 3–18 seconds for unvoiced lines, with an optional minimum duration supplied by a future voice player. Persistent content remains visible until replaced or cleared; it does not restart on the 10 Hz venue refresh. Captions do not intercept input, change quest state, charge money or play audio. They do not imply recorded or generated voices exist.

No mission logic, save schema or input mappings change. Existing system notifications continue to report actual purchases, mission awards and errors. Corporate prologue and offline voice pipeline have their own active development branches; integrate the common caption contract there after reconciling overlapping changes, rather than replacing their dialogue implementation.

## Acceptance

The independent caption smoke checks speaker prefix handling, passive input, timing, voice-duration floor and persistent refresh. Existing Mara and patron world tests now assert real caption content instead of generic toast content. Before merge, run exact-head preflight and Windows export, inspect real gameplay at 720p/1080p with long dialogue and multiple choices, test controller navigation, and reconcile PR #310 and chapter-one work. Native visual/audio verification is pending.
