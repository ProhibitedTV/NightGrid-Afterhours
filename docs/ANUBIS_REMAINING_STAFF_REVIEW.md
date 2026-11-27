# Remaining named staff — native review

After the targeted batch in #527 completes (or after recovering compatible exact candidate records from prior work), run on native Windows from an integrated source checkout:

    Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/review_synaxis_remaining_staff.gd -- "Z:/NightGrid-Afterhours/Characters/remaining-staff-001" "Z:/NightGrid-Afterhours/Visual/Evidence/remaining-staff-review-001"

Use the actual installed Godot path and a new output directory. This fixture reads the four per-actor candidate.json records, checks their identity and GLB SHA-256, loads the current actual HQ and compares the original and candidate at the same authored anchor and camera transform. Four PNG pairs and a report.json identify the candidates, floor, rig clip, adapter and resolution. No model is copied into runtime assets, no pin is replaced, and no save is written by the fixture. Camera placement is a first-pass review position; inspect occlusion and framing manually before drawing conclusions. It does not test radio/tablet/badge fit, final role-specific outfit, dialogue interactions, seated transitions or performance. Measure those separately before promoting any candidate, and preserve the existing four private cast pins. No headless or synthetic screenshot substitutes.
