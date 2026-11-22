# Living Streets

Run the Windows playtest with `NightGrid-Afterhours.exe -- --living-streets`. The same switch works with the Godot project. The pilot is opt-in under #160, so an ordinary launch keeps the current public beta behavior.

## Simulation

- The city seed generates up to 128 stable identities across eight districts. A district's hourly profile determines which identities can appear. A nearby actor keeps its route when the clock advances.
- The director reuses up to 12 collidable actors, three of each of four authored costumes. It prefers nearby paths, admits at most two pool changes every 0.20 seconds, and spreads whole-path collision checks over multiple physics ticks. An expanded, settled camera frustum and a live clearance query govern activation. The body is disabled before its parcel lease is released.
- Physical routes stay on existing sidewalk strips. Selected endpoints pause at signal-controlled approaches. The two Central Exchange storefront links continue through the existing doors into their walk-in vestibules. Calm actors can rest, look into a storefront or face and wave to another calm actor within four meters and in clear sight.
- Active actors use the same blocking physics as the street and vehicles. A blocked actor yields and can reverse along its certified route. Approaching vehicles and nearby, unobstructed incidents trigger a look-and-stop reaction. The camera still sweeps against structures.
- Only active, rigged, nearby actors in the live camera frustum can provide a civilian eye position, facing and body RID. The existing bounded wanted ray checks line of sight to the event, including walls and other solid objects. Abstract population and occluded actors provide no new heat.
- Saves retain the existing v1 schema. A new optional phase snapshot restores the seeded population before activation. Old slots use their existing seed and default starting phases. Indoor and transit modes suppress exterior activation and recycling.

The dedicated branch integrates the selected #120 director and pool changes with the already-merged #116, #117 and #119 dependencies, and includes the #123 adapter. #124's intake tooling is already merged in main. The exact verified source binaries from its CI artifact were converted for playback and checked into this branch. The branch is stacked on #166 so the Windows checks include the updated courier, Brickwater and physical world. [Asset provenance and rebuild](../assets/models/nightgrid/pedestrians/SOURCE.md).

## Scope

The pilot certifies local straight paths. It waits on the sidewalk at crossings and uses the two actual walk-in retail vestibules. Continuous cross-street journeys, long-distance destination routing and full business-interior schedules need additional authored links. A severely displaced actor stays protected instead of teleporting back onto its route. Reactions are local pauses, looks and route reversals. Congested pavement can produce backtracking while the path clears.

The four meshes have distinct silhouettes and texture atlases. Godot supplies mesh LODs, and the animator updates distant and offscreen actors at lower rates while maintaining elapsed time. The player uses its existing independent courier rig. [Adapter contract](PEDESTRIAN_RIG_VISUAL.md).
