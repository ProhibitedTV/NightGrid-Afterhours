# Morrow Bay After Dark — venues and neighborhood stories

The social economy is **authored, not rerolled**. Twelve individual streetfronts are permanent destinations with fixed names, contacts, hours, addresses, and architectural compositions, even when a New Game seed changes selected nearby building facades. The design language is graphic noir: copper food heat, frosted cyan coffee bars, rose-toned taverns, and violet clubs. These are tangible destinations with interactions and NPC silhouettes, not a claim of finished walkable interiors or conversational AI.

## Permanent venue directory

| District | Venue | Category | Hours (game clock) | On-site contact |
|---|---|---|---|---|
| Vesper Market | Moon Noodles | Stall | 11:00–02:00 | Auntie Sol |
| Vesper Market | Lantern Cup | Cafe | 06:00–22:00 | Mara |
| Vesper Market | Ink & Tonic | Bar | 17:00–03:00 | The Archivist |
| Glassline | Helix Espresso | Cafe | 05:00–20:00 | Ev |
| Glassline | Afterimage Lounge | Bar | 18:00–04:00 | Iris |
| Glassline | Prism Club | Nightclub | 20:00–05:00 | DJ Lumen |
| Brickwater | Dock Nine Social | Bar | 15:00–02:00 | Old Ren |
| Brickwater | Furnace Skewers | Stall | 12:00–01:00 | Nell |
| Brickwater | Copper Cup | Cafe | 06:00–19:00 | Hal |
| Afterhours | Static Room | Nightclub | 21:00–05:00 | Nyx |
| Afterhours | Neon Bao | Stall | 14:00–04:00 | Jun |
| Afterhours | Blue Hour | Nightclub | 19:00–04:00 | Rae |

All twelve have stable coordinates derived from `scripts/venue_system.gd`, occupying the sidewalk frontage of reserved ordinary parcels, avoiding the four fixed landmark blocks. They are on the existing city minimap with type-colored dots; an active local side quest adds a ring around its destination.

## What the player can actually do

Approach a frontage on foot and press **G** to open a local menu. Press **1** to purchase a service, **2** to accept or turn in a local contract, and **G** or **Escape** to close. Cars and transit must be exited before interacting. Businesses close at their scheduled times; menus and signage reflect the 24-hour game clock, including schedules that span midnight.

Services are paid with existing mission currency, and **no charge is taken when the service is not needed**:

| Location kind | Price range | Gameplay effect |
|---|---|---|
| Food stall | $16–19 | Restore 28 health |
| Cafe | $15–20 | Restore 20 health |
| Bar | $22–30 | Reduce police heat by 0.65 |
| Nightclub | $35–45 | Reduce police heat by 1.0 |

Bars and clubs offer discreet contacts/places to disappear, rather than framing alcohol as a health consumable. Food and coffee support a low-stakes way to recover between courier missions. All services are deterministic and preserve existing health/heat caps.

## Four authored side jobs

| Job | Starting contact | Destination | Payout |
|---|---|---|---:|
| The Midnight Thermos | Moon Noodles | Copper Cup | $180 |
| Dead Frequency | Ink & Tonic | Static Room | $265 |
| The Glass Invoice | Afterimage Lounge | Dock Nine Social | $230 |
| Last Shift Recipe | Furnace Skewers | Neon Bao | $150 |

Each short job has a beginning and ending line of story dialogue, connects districts, rewards traveling, and can be finished only when the destination is open. One local side job is active at once; completed jobs cannot be collected repeatedly. The HUD and minimap track the current destination while the existing courier objective remains available.

**Save compatibility:** Both the current side-job ID and completed contract IDs are added as *optional* fields to existing version-one save snapshots. Existing saves with no social activity fields continue to load as before. The saved world seed remains intact. No new-game regeneration occurs on venue interaction.

## Architectural art details

Each frontage has a separate fixed design within the established façade language, including a shop header and contact signage. Individual props vary by venue type: steaming-food stylization (bowls, grills, awnings, crates, warm lanterns); coffee counters (cups, espresso kit, stools, potted greenery); bars (backlit shelves, bottles, brass counters and stools); and clubs (magenta/cyan portal frames, animated-looking equalizer sculpture, speakers, queue barriers, and patron silhouettes). The scene dresses **external streetfront spaces only**. It does not hollow out collidable building shells, supply navmeshed NPC workers, create interiors, or play licensed music.

## Performance

Twelve mostly static handcrafted small scenes; no per-frame random generation or physical crowds. Four **original, procedurally synthesized two-second spatial sound beds** distinguish cafes (pump/crockery), food stalls (grill hiss), bars (murmur/ventilation), and clubs (abstract bass). They are cached at 11.025 kHz mono, played only in the audible radius of open venues, and do not use any copyrighted music or imported samples. Each location uses one emissive material, and **only two additional nearby unshadowed OmniLights** may be enabled by night. Signage dims during the day or outside operating hours. This respects the RTX 3060 / Ryzen 7 / 32 GB intended baseline, but FPS remains **unmeasured** on that target hardware.

## Roadmap

The next major step is several proper enterable interiors with working door triggers, activity-specific NPC scripting, simple seating/relaxation interactions, richer recorded/synthesized sound and player-first dialogue, plus ambient crowd motion and faction reputation. These larger systems should be measured on the target GPU before multiplying their instances. Social hub addresses and side-job IDs are stable foundations for later quests and saves.
