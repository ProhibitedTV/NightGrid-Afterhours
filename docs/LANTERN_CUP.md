# Lantern Cup — flagship playable cyberpunk coffeehouse

**Venue:** `lantern_cup` / LANTERN CUP / Mara / Vesper Market. **Hours:** 06:00–22:00 on the in-game clock, unchanged. **Player workflow:** approach its original stable street address on foot → **H** to enter → walk to the staff counter → **G**, **1** to buy an espresso (existing $18 service, +20 health when needed) → **H** near entry to return to the same street position.

## Original authorial direction

Warm brass and walnut, aged glazed brick, graphite acoustic ceiling baffles, translucent shop glazing and utilitarian espresso engineering contrast with restrained cyan status lights. A quiet, furnished all-evening refuge for night-shift couriers rather than a generic neon box. The exterior and interior are designed as **one consistent venue**.

## Implemented asset

- **Exterior:** original matching two-sided glazed storefront, transom rails, copper portal and matching lantern supports with cyan-controlled lightbox using the venue's existing open/closed lamp material. Street signs show opening context, `H` and `G` actions. No separate exterior collider, duplicate venue address or new street mapping.
- **Interior architecture:** deep timber wainscot, brass rails, glazed backbar brick, steel service ducting, exposed brackets, 17 acoustic ceiling blades, fitted tiles, five stacked glass feature fins and copper inlaid doorway threshold. Existing collidable 16m×18m room and counter remain the canonical physical geometry.
- **Coffee-making detail:** polished stone bar, backsplash glazing, two independently constructed espresso heads, pressure indicators, portafilters, drainage trays, stocked shelving and dozens of small ceramic mugs. Three cosmetic steam wisps animate only while the room exists.
- **Human-scale fixtures:** six sculpted banquettes with physically collidable upholstery, eight wall-side and rear coffee tables, ceramic planters, 12 cable-suspended copper pendants, clear frontal glazing around an open central door, illuminated menu boards, detailed booth upholstery and limited warm bar lighting.
- **Atmosphere:** one new original cached, spatial 11.025-kHz café pump/hiss/crockery loop alongside the existing synthesized café soundscape. All audio and furniture free when the player leaves; two small-range unshadowed bar worklights supplement the existing shared room pair.
- **Gameplay integration:** staffed interactions and coffee's existing actual cash/health outcomes are preserved. At the right rear booth, pressing **G** reveals **Mara's shift notes**. The note is a one-time lore discovery recorded in the **existing saved civic_intel array**—no new save schema or currency reward, and no way to repeatedly farm it.

## Mara — staffed hero character and responsive conversation

The previous three-block contact silhouette has been replaced with a streamed original humanlike character: tapered facial sculpt, eyes/lids/brows/lips, swept hair, ear radio, sewn utility jacket, apron and readable identity details. She breathes, blinks, looks at the player, speaks with expressive mouth motion and gestures after successful coffee orders. With the counter menu open, **3** / **Y** starts or advances four no-cost authored conversations contextualized by player health, police heat, active work and the shift note. Existing 1/A coffee and 2/X job inputs remain intact. Character dialogue is ephemeral; the previous booth clue persists as before. [Mara art and animation details](MARA_HERO.md).

## Café regulars — the last pre-playtest asset

Five distinct wall-side café regulars, **Rin, Ivo, Tamsin, Len and Aya**, now occupy the original booth positions. Each has lightweight original facial/workwear geometry and an authored deterministic **sip, scroll, chat or read** idle; character material resources are shared within the process. Press **G** near a customer for optional contextual gossip. The interaction does not change cash, health, quests or persistent journal entries. Guests remain non-colliding (existing furniture is the walkable environment), use **zero extra lights**, and are only generated inside Lantern Cup. Each visit and save/load reconstructs identical identities, side anchors, palettes and activities. They are not navigating crowd AI; the limited set is intentional for stable pre-playtest performance. See [playtest walkthrough](PLAYTEST_CHECKLIST.md).

## Technical/safety contract

The live game only constructs the bespoke `LanternCupHero` when `InteriorSystem` enters `lantern_cup`. The venue's id, host, storefront position, schedule, business category, other eleven social locations, four existing side jobs, counter reach, exit radius and v1 save fields remain untouched. Other two cafés retain the original `_lounge` archetype.

The interior itself is at a common off-city scene-staging origin; it is **not a seamless cut-through doorway**, an NPC navigation simulation, or a physically traversable back-of-house kitchen. Patrons remain stylized silhouettes, not rigged living people. The clue note references a nearby service alley but is **story texture**, not a new explorable door or active quest.

## QA acceptance

The new `tests/lantern_cup_hero_smoke.gd` enters the **actual world** through the pre-existing H path, checks both exterior and interior, furnishings, glass, audio, steam, the lore discovery and anti-repeat behavior, live purchase cost/healing, save/load inside the café, preservation of seed and cash, exit to the original coordinate, proper room freeing, and another café falling back to generic interior. The test is required in GitHub Actions, alongside the previous full-city suite and Windows export.

Visual checks to perform manually in Godot Forward+: inspect the entrance from the curb at 06:00, 19:15 and 21:45; inspect door framing, face normals and alpha sorting from both sides; look down the central aisle at Mara's counter; test that all booths are navigable and cannot trap the player. Profile additional audio/rendering/lighting on an RTX 3060; **1080p/60 remains unmeasured**.

**Production art gap:** bespoke UV-unwrapped high-detail mesh topology, authored layered PBR textures and signage atlases, realistic hair/skin and human animations, coffee machine animation/audio quality, physical seat interaction, particle-based steam and measured rendering quality are still required before claiming final AAA assets. Existing README screenshots are older actual Godot captures, not proof of this upgrade.

## Recommended next asset

An **inhabited NPC/character** with consistent game-scale anatomy, believable clothing/hair/skin PBR, idle gestures and a true conversation state, applied first to Mara, then the nightlife contacts.
