# Private music selection ledger

The soundtrack director listens to original candidates, chooses at most one
take per cue, and records alternatives and rejected takes. Rights review
is separate and must refer to the exact checkpoint and master bytes.
No script automatically chooses a take, clears rights, or publishes audio.

From the existing checkout, after generation stops, use the QC report from
music_technical_qc.py and the matching private candidate manifest:

    batch=/mnt/z/NightGrid-Afterhours/Music/music-001
    python tools/audio/music_technical_qc.py --manifest "$batch/manifest.json" --source "$batch" > "$batch/qc.json"
    python tools/audio/music_review_ledger.py template --manifest "$batch/manifest.json" --source "$batch" --qc "$batch/qc.json" > "$batch/review-new.json"

Use a new filename every time. Never redirect over an existing human review.
The template contains only pending decisions. Edit a private copy after
listening to the entire cue. Compare musical identity, arrangement, scene
fit, unwanted vocals, truncation, dynamics, and ending/loop quality. Record
listening notes and reviewer; for a selected take explicitly acknowledge
all QC flags (acknowledgment does not mean they were fixed). Decisions:
pending, alternate, rejected, selected. Selection does not imply clearance.

Rights status: pending, blocked, cleared. Only a human reviewer records this
decision, their identity and notes. A cleared record also references a
private JSON rights evidence file by SHA-256, named <hash>.json in a separate
evidence directory. It must contain candidate_sha256, checkpoint,
license_reference, output_rights_basis and review_date. Preserve actual
license text/revisions and permission records privately; the validator checks
binding and existence, not the legal adequacy or authenticity of assertions.
The MusicGen noncommercial lane cannot be marked cleared here.

    python tools/audio/music_review_ledger.py verify --manifest "$batch/manifest.json" --source "$batch" --qc "$batch/qc.json" --ledger "$batch/review-new.json" --evidence-root "$batch/rights"

A completed report lists selected cues and records with both selection and
documented clearance. It is not an export authorization or signature.
Any changed manifest or QC bytes require a new ledger/review reconciliation;
no stale decisions are carried forward automatically. Keep all review files,
evidence and unapproved audio off Git. Native listening, independent release
rights enforcement and actual approved derivative export are still required.
