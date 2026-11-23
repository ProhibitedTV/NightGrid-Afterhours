# APPROVED VISUAL TARGET — NIGHTGRID: AFTERHOURS

**Decision date:** November 20, 2026  
**Status:** **APPROVED WORLD-FIDELITY TARGET** — replaces earlier "low-poly", procedural-cube, and stylized concept-art fidelity goals.  
**Source:** User-approved *photorealistic cyberpunk waterfront city* image supplied in the design conversation on November 20, 2026 (original upload: `image(20261120-150334).png`, showing the Azure Mirage waterfront boulevard). **The binary reference image is attached to that conversation but is not yet checked into this repository.** The actual uploaded image—not a recreated SVG, README screenshot, or temporary URL—is the creative reference of record until it can be copied into `docs/art/references/approved-world-target.png` through an authorized binary upload. Do not claim that this file is already committed.

## Nonnegotiable direction

**NightGrid is now targeting the visual language of an ultrarealistic AAA open-world cyberpunk crime sandbox.**

Original art and original fictional city. Contemporary open-world production values are a **fidelity benchmark**, not permission to reuse the identity, assets, names, UI or locations from GTA VI or any other game.

The November 22 Brickwater night reference gives the service alley its own [location-specific visual target and native comparison](BRICKWATER_REALISM_REFERENCE.md).

The user expressly rejected the earlier appearance of detached block-like buildings, rectangle characters, strangely proportioned vehicles, excessive procedural sameness and a cartoonish city. **Do not treat small decorative primitive additions or a passing Godot headless test as progress toward this art goal.** A cinematic reference image is *not* an in-engine achievement and is never to be shown as game footage.

### What makes the approved image compelling

- **Coherent urban geography:** a curving, believable coastal boulevard with real lanes, curb geometry, drainage, sidewalks, palm-lined storefronts, a waterfront railing, and traffic flowing through the same scene; architecture, road, harbor and elevated transit are physically connected.
- **Architecture with scale:** luxury ocean club with full-depth glazing and warm interiors; differentiated shopfronts, structural slabs, steps and planters; a dense skyline with real façade and window proportions; enormous integrated digital advertisements; distant architectural tiers and a dramatic waterfront skyline.
- **Transportation hierarchy:** a plausible elevated train guideway with supports, a connected multi-lane road, premium cars that sit correctly on their wheels, and navigable pedestrian/harbor paths. Elements occupy real space and respect circulation.
- **Photoreal material response:** wet asphalt with *varying* roughness, water puddles and physically consistent reflections; natural-looking vegetation; individually readable façade materials, glazing, brushed metal, pavement seams, drainage and façade wear. A neon palette is not a replacement for real surface detail.
- **Motivated lighting:** cinematic purple-blue dusk, cyan/magenta signage and transit accents, amber storefront interiors and warm street lights. Every conspicuous reflection should correspond to a plausible light source or luminous surface; controlled haze adds depth but preserves detail.
- **Lived-in environmental depth:** shops, furniture, lounge interiors, marina piers, boats, layered road infrastructure, service access and signs. The reference is about the **world**, **not** posed foreground characters. Characters may exist in gameplay, but world geography and visual realism lead the frame.

### Do not translate too literally

This source image is a **design/fidelity reference** rather than a requirement to duplicate a Miami-inspired branded location. Retain Morrow Bay, Vesper Market, Glassline, Brickwater, Afterhours, the NightGrid street/venue identities, and world persistence. Selectively adapt waterfront, coastal foliage and skyline design to the city's geography rather than silently relocating landmarks or replacing authored systems. Do not copy the image's third-party/AI-generated lettering verbatim into the game.

## Mandatory asset pipeline

1. **Start from authored high-quality geometry**, not endless `BoxMesh` façade toppings. Model a consistent architectural kit in a DCC tool such as Blender: realistic façade depth, storefront openings, correct building-scale windows, door thresholds, columns, supports, curbs, roof systems and collision shells. Use explicit dimensions and stable anchors.
2. **Use real PBR texture sets** (properly licensed): albedo/base color, tangent normal, roughness, metalness and, where appropriate, AO/height, emissive masks, clear coat and water masks. UV unwrap/trim-sheet the asset. Procedural color variation is supplementary, not a final substitute.
3. **Lighting/rendering:** tune Godot 4.3 Forward+ for atmospheric dusk, exposure, calibrated sun/sky, reflection quality, indirect fill and restrained bloom. Ground neon, lit interiors, street lamps and traffic lights in plausible practical sources. Preserve daytime readability and realistic dry/wet variants.
4. **Traffic and environment as a system:** use realistic building setbacks and accessible doorways; physically connected elevated rail supports; correctly scaled and grounded vehicles; street-side infrastructure and drainage that makes sense. Don't scatter visually attractive but disconnected objects.
5. **Texture/memory/geometry budgets:** assign import LODs, meshes/material atlases, culling/streaming and dynamic-light caps. Design against the actual player's RTX 3060 12 GB class of GPU with a provisional **1080p/60 target**, verified with measured frame timings; visual quality should degrade gracefully rather than default to blockout art.
6. **Preserve gameplay and save contracts:** keep road centerlines, intersection signals, stable venue addresses, entry/exit doors, quest interactions and seeded lot manifests unless an explicit backwards-compatible migration is included. A façade that looks great but blocks the club exit is a regression.

## Quality gate: visually compare real game frames

For each significant art PR, **capture and attach actual Windows/Forward+ in-engine screenshots** from a named permanent coordinate and identical camera/lens/clock. Provide at minimum: 16:9 street-eye view at dusk, daylight inspection, close material crop, and driving perspective. Compare the source reference, the old in-game frame and the new frame side-by-side with honest captions. Require a human review of:

- Silhouette and proportion against the approved image, especially depth of city, skyline, street, buildings and vehicles.
- Alignment and *physical plausibility* of buildings, entrances, transport, grading and collision.
- Natural PBR/reflection/weather treatment, no flat plastic surfaces, cartoon geometry or implausible neon everywhere.
- In-game performance metrics, visibility, pop-in, camera clipping, street and interior walkability, save/reload consistency.

**Not an art-quality gate:** green CI alone, counts of meshes/polygons/props, an exported Windows executable, an AI concept or SVG illustration mistaken for gameplay. They can support engineering tests but cannot establish visual acceptance.

## First approved implementation location

**Central Exchange at (0,0)** remains our controlled *engineering comparison location*, because its streets, crossings, traffic signals and geometry are stable. Rebuild the **whole street-level composition** (façades + road/curb + believable building depth + light/materials + actual transit/vehicle framing) toward the approved waterfront image's fidelity. Do not shoehorn the entire harbor into that junction; for the exact waterfront/palm/monorail/yacht composition, establish a **separate geographically consistent coastal boulevard** later without destabilizing existing districts. If a closer first location is preferable for a literal harbor match, select an existing waterfront district and document its world-space anchors before implementing.

**Sequence:** approve reference → replace one architectural frontage with authored realistic meshes → add true PBR materials and coherent motivated lighting → replace the most visible placeholder vehicle/environment props → actual Windows screenshot and frametime review → only then propagate architecture styles to neighboring blocks.

## Legacy art and references

- [The old Central Exchange stylized SVG mood study (draft PR #23)](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/23) was superseded by the approved photorealistic user reference. It is **not** a design target and must not be promoted as an accepted AAA concept.
- [Visual art reset issue #19](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/19), [vehicle redesign #20](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/20), [city zoning #21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21) remain unresolved until real visual review validates changes.
- Previous `docs/ART_DIRECTION.md` descriptions of existing procedural passes are **historical implementation notes only**, not approval of their art quality.
