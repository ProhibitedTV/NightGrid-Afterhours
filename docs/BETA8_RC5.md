# Beta.8 RC5 — Destruction Update

Windows development prerelease; RC4 is retained unchanged.

## New gameplay
- Collision-driven front/rear mesh deformation on Cinder R9 and Kestrel S6, with broken lights, side steering pull and subtle wheel camber.
- Severe side impacts can detach actual Cinder doors; severe frontal damage can detach the Kestrel front splitter. Temporary physical fragments, smoke and directional impact sparks are globally capped.
- Cinder laminated glazing displays procedural crack lines on severe damage; no full glass shattering.
- Disabled player vehicles lose drive power; repairs restore geometry, lights and damage state.
- Civilian cars and buses receive collision damage, briefly stop and limp at reduced speed; fixed traffic damage persists, ambient lease reuse clears damage.
- Retains RC4 radar, city lighting, streaming, wet surfaces and cockpit.

## Known limitations
Arcade damage, not soft-body simulation. Conservative original collision hulls remain; NPCs resume driving rather than permanently gridlock streets. Only selected panels detach. Native rendering appearance, collision-time frame pacing, controller/audio and full save compatibility acceptance still require playtesting. Police damage received from collisions is supported; police self-impact behavior retains existing policy. No claim of 60 FPS or AAA quality. See [vehicle destruction details](VEHICLE_DESTRUCTION.md).

Publication requires the exact current main revision to pass full preflight (including real collision and destruction regression), exported Windows EXE/PCK startup and SHA256 artifact verification. No overwrites of RC4 or RC5. Native acceptance remains a player task.
