# Private soundtrack mastering and game derivative handoff

After the complete batch has stopped, perform technical QC and human creative
and rights review as described in MUSIC_REVIEW_LEDGER.md. The exporter refuses
to proceed unless every selected take has documented rights clearance and
matching source/QC/ledger hashes. It does not approve any music itself.

    batch=/mnt/z/NightGrid-Afterhours/Music/music-001
    python tools/audio/music_mastering_export.py --manifest "$batch/manifest.json" --source "$batch" --qc "$batch/qc.json" --ledger "$batch/review-new.json" --evidence-root "$batch/rights" --output "$batch/derivatives-001"

The output must be a new derivatives-* directory inside the private source
batch. No originals are altered. The first mastering profile uses constant
gain toward -18 LUFS, caps boosts at +6 dB, and reserves -2 dBTP source
headroom. No compressor or limiter is applied: the quiet/loud dynamics are
part of the musical direction. Peak-limited cues can remain below target.

Exports use 48 kHz stereo Ogg Vorbis quality 7. Each derivative is decoded
for loudness and true peak measurement (maximum -1 dBTP) and checked for
codec, channel count, sample rate and duration against the source. The report
binds original and derivative hashes, exact checkpoint, rights evidence,
manifest/QC/ledger hashes, conversion parameters and encoder version.
A failure cleans up files created by that invocation; an existing output
directory is never overwritten. An interruption can leave an incomplete
directory; do not use it without the completed report and re-verification.

This is private handoff, not an automatic game import or release. The
chapter score system uses exact cue IDs (see CHAPTER_SCORE_INTEGRATION.md).
Audition compressed recordings, transitions and loop seams in native Godot.
Do not ship without a separate release rights gate and explicit approval.
NightGrid FM remains separate. Album mastering may use different levels.
