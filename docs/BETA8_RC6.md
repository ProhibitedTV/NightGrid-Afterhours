# Beta.8 RC6 — Seamless Interiors Preview

Windows development prerelease; RC5 Destruction Update remains available unchanged.

## What's new
- Ordinary (non-bespoke) city building parcels have real ground-floor rooms, opening physical doors, connected corridors, and a second level reachable by a physical ramp.
- Use H near an ordinary entrance to swing the door, then walk through. No loading screens or remote-room teleport for these lots.
- Furnished collision is ready at the first sector streaming stage; exterior art is finished by later stages. Decorative fixtures use local MultiMesh batches and a 45 m visibility range. Only one ordinary interior light is active, following the occupied floor.
- Save and restore ordinary physical interiors at real coordinates, including upper floors; safe threshold restore prevents a closed door trapping the character.
- Helix Espresso is the first migrated named business: enter its actual door, walk to the left lobby counter, and press G to use its original coffee service and business hours.
- All RC5 vehicle destruction, RC4 radar, and earlier world content are retained.

## Limits and playtest objectives
Not all buildings or floors are enterable yet. Bespoke façades and landmarks still require conversion, and other named businesses retain their legacy remote-room behavior. The two accessible levels use ramps, not finished staircases/elevators; interior art is an initial reusable layout, not final unique design. Ordinary door states are transient. Target native frame pacing, camera clearance, door interaction, interior lighting, service access and save/restore on actual hardware. No verified native FPS target or claim that the entire city has been converted.

Publication requires the exact current main revision to pass project preflight, actual Windows EXE/PCK startup, and SHA256 verification. See [implementation details](SEAMLESS_BUILDING_INTERIORS.md).
