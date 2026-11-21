# MBPD communications and station refinement
MBPD uses familiar public radio vocabulary adapted for the fictional city: 10-4 (acknowledgment), 10-8 (in service), Code 4 (no additional assistance needed), and brief plain-English incident dialogue. Reference: [City of Tucson public Radio Signal Codes](https://www.tucsonaz.gov/Departments/Police/Radio-Codes). Definitions vary by agency; this is a game-specific selection of routine terms. Dispatch and unit acknowledgments derive from live event sequences, not fabricated reports or real transmissions. Single non-overlapping receiver on WorldSFX, maximum six queued messages, repeat deduplication, caption generated from the same dialogue source as speech, plus bracketed event metadata (not synthesized), and short closure tail. The player hears the channel while wanted or visiting a precinct; no network requests, microphones or real radio access. Local builds without optional generated speech assets fall back to a UI chirp and caption. CI and Windows beta/export generate nine actual spoken WAV clips using offline eSpeak NG and original radio filtering; no redistribution of recorded voices. For a local full-voice build install espeak-ng and run python3 tools/generate_mbpd_radio.py before Godot import. Original frontage canopy, metal/concrete/PBR details, duty staff with existing idle animation, and live dispatch board in both station rooms. Existing addresses, collisions, room streaming and fleet budget retained. Native audio intelligibility and art review pending. Future: professional voice pack, authored glTF architecture, garage/depot models.

## MBPD service-status vocabulary

| Code | MBPD meaning | Event |
|---|---|---|
| 10-4 | Acknowledged | Unit assignment acknowledgment |
| 10-17 | En route | Same acknowledgment, following assignment |
| 10-19 | Returning to station | Healthy cruiser released to its registered station |
| 10-7 | Out of service | Cruiser retired because of damage or missing station |
| 10-8 | Back in service | Return completed, fleet slot available |
| Code 4 | No more assistance required | Incident closed |

Routine vocabulary references: [Phoenix PD numerical/alphabetical radio codes, March 17 2026](https://www.phoenix.gov/content/dam/phoenix/policesite/mediaassets/Radio%20Codes%20Numerical%20Alphabetical.pdf) (10-17 and 10-7), and [Fountain Valley PD RSVP policies, 2026, p. 15](https://www.fountainvalley.gov/DocumentCenter/View/23968/RSVP-POLICIES-AND-PROCEDURES-2026pdf) (10-19). MBPD is a fictional local codebook; definitions differ across agencies. The damaged unit event never creates a return or arrival announcement. No dispatch routing or wanted-level behavior is changed.
