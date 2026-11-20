# CENTRAL EXCHANGE — AAA environment concept target (v1)

![Concept art: Central Exchange cinematic environment target, NOT a Godot screenshot](central_exchange_aaa_target.svg)

> **ORIGINAL CONCEPT ART — NOT IN-GAME FOOTAGE.** This is a proposed **target illustration**, created as scalable SVG and a 2560 × 1440 PNG export. It expresses intended material response, proportion, city density, atmosphere, and silhouette. It does not prove that the game can yet produce the image, and the stylized illustration itself is not a final photorealistic Unreal/Godot raster.

## Canonical location

- **Playable landmark:** Central Exchange at world `(x=0, z=0)`, the junction of **Vesper Market (NW), Glassline (NE), Brickwater (SW), Afterhours (SE)**.
- **Actual road width:** 14 m, unchanged. **Four working pedestrian crossings**, stop lines and phase-controlled signals. **Eight curb ramp approaches**, **eight storm-drain sockets**, working signal head at NE (+9.2,+9.2), and lived-in street furniture. See [current integration](../CENTRAL_EXCHANGE.md).
- **Concept camera:** pedestrian-eye 35 mm-ish cinematic street-level view toward the junction, after a recent downpour at **20:18**. A broad crosswalk spans the foreground and perspective converges into distant blocks. A believable EV and human pedestrians provide scale. The illustration is a cinematic design composition, not a dimensionally surveyed in-engine perspective.
- **Visual contrast:** left: human-scaled, older brick/metal Vesper shops lit by **warm sodium/amber practicals**. Right: monolithic **Glassline glass/aluminium** terraces lit by selective aqua/cool LED strips, plus **Afterhours** secondary pink signage. The four districts retain their existing real boundaries.

## Build specifications — what has to change in the game

| System | Target shown | Implementation/QA criterion |
|---|---|---|
| City architectural silhouettes | Distinct, irregular but structurally grounded retail vs corporate towers | Replace generic whole-wall BoxMesh blocks with authored modular façades, cornice/profile, recessed window bays, visible floor levels, proper setbacks and service entries; preserve world-manifest stable addresses |
| Materials | Pitted brick mortar, brushed anodized aluminium, varied reinforced concrete, dirty glazed windows | Imported UVs, PBR albedo/roughness/normal/metallic maps with controlled tiling; wet/dry masks and hardware-level edge wear, not uniformly bright neon |
| Street & drainage | 14 m asphalt with patched aggregate, faded thermoplastic zebra, pooled water in low points | Per-zone decal/normal masks and calibrated roughness; use existing collision road, keep signal cycle and turn lanes untouched; avoid flat mirror-road shaders |
| Vertical detail | Mast controls, cable routing, bolted signs, utilities, air ducting, rainwater channels | Real mechanical sizes and anchors; no sign/door floating apart from building shell; keep crosswalk fully walkable |
| Street-level habitation | Couriers, umbrellas, shop interiors, grounded EV, clutter in alleys | Replace primitive NPC/car placeholders with authored human/car geometry; character silhouettes should remain believable at 2 m, 10 m and 35 m |
| Light/weather | Twilight blue-hour ambient, soft fog, localized practicals, amber-vs-cyan reflection | Mix physically motivated light sources and restrained filmic grading; compare noon, 20:18, midnight, dry vs wet. No blanket luminous signage or neon bloom |
| Rendering | Believable 35 mm lens contrast and controlled focus | Capture *real* Windows Forward+ output at 2560×1440 and 1080p with identical camera position; report GPU frame times and real screenshot, not procedural component count |

## Proposed focused implementation sequence

1. **Lock world footprint:** one 58 m × 58 m immediate block and its neighboring ground-floor façades, entrances, signal hardware and physical curb locations. Make city/building placement deterministic and prove no overlap.
2. **Replace two high-salience architecture façades** (Vesper left, Glassline right) with accurately modeled modular assets. The first benchmark must be a complete *building assembly*, not hundreds of floating surface cubes.
3. **Upgrade the near-street PBR surfaces**, curb/crosswalk/drainage, local light units and shopfront transparencies. Preserve walkability, visibility of lane markings and the original traffic-light controller.
4. **Integrate believable human/car scale assets** in a bounded set rather than adding more stylized placeholders. No unvalidated new traffic/nav/quest system.
5. **Render side-by-side**: original screenshot, art target, updated in-engine screenshot, same aspect, matching time and approximate camera direction. Human visual review is required before extending these assets beyond Central Exchange.

## Acceptance — visually meaningful, not test-count-based

The revised Central Exchange needs **real gameplay screenshots** from the pedestrian/crosswalk view at 20:18 and noon, physically credible architecture/window proportions, no exposed rectangular proxy humans or implausible car shell in the hero frame, stable collision/entrances after save and load, and measured 1080p frame timing on a known GPU. Keep the implementation *location-scoped* until approved.

**Current code limitations:** procedural BoxMesh city shells, decals as box MultiMeshes, pre-upgrade KESTREL car model, stylized NPCs and as-yet-unverified Windows PBR performance. Do **not** mark this artwork as game footage, a shippable model, or achieved AAA quality.

**Related tracking:** [Visual art reset #19](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/19), [Vehicle design #20](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/20), [City zoning #21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21).
