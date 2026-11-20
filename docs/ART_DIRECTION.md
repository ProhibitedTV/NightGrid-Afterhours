# NightGrid visual north star — photorealistic, believable cyberpunk metropolis

> **APPROVED NEW DIRECTION (NOV 20, 2026):** The user has replaced the former low-poly/procedural-box visual goal with an **ultrarealistic AAA-style cyberpunk open-world environment** reference, depicting a dense, lived-in neon waterfront boulevard, wet roads, coherent city infrastructure and skyline, realistic architecture and PBR materials. **[Read the canonical approved-image fidelity standard before making *any* new visual asset or art-direction decision.](APPROVED_WORLD_FIDELITY_TARGET.md)** The image is a desired aesthetic, not actual gameplay, and the previous passes below are historical milestones rather than quality sign-off. **No more cube-heavy, cartoon/low-poly visual work packaged as finished art.**

**Art brief:** hyper-realistic *materials, lighting, scale, wear and engineering* combined with highly art-directed cyberpunk futurism. Real-world visual logic; boldly fictional design. Think lived-in late-night infrastructure rather than generic neon box props.

## Common quality bar for the entire game

1. **Silhouette and authored design** — a recognizable identity from 50 m away; clear massing, hierarchy and asymmetry. Avoid a box stack pretending to be the final asset.
2. **Engineering credibility** — show load paths, fasteners, joints, service access, plausible door geometry and dimensioned human circulation. Vehicle moving parts and transit wayfinding should make sense.
3. **Materials** — independent PBR roughness/normal response for paint, alloy, rubber, glass and wet ground. Physically believable metalness, not chrome everywhere.
4. **Lighting** — color contrast motivated by actual fixtures; practical warm interior lighting beneath restrained signage and cyan/red line identity. Do not saturate entire scenes in emission.
5. **Scale and habitation** — readable grab bars, seating, protection edges, handrails, drainage, signs, warning stripes, grime around joints and platform details.
6. **Animation and sound** — operate visible mechanisms when the gameplay state changes; do not animate arbitrary cosmetic props independently of transit state.
7. **Performance** — use reused materials and MultiMeshes for repeats; reserve local lights and alpha blending for meaningful hero areas. Target 1080p/60 on an RTX 3060 **after measuring**, not before.
8. **Persistence** — locations and props must remain stable across save/load. Visual-only changes must not silently modify passenger or traffic geometry.

## First vertical slice: M-Line CICADA M8

The original M-Line is elevated, two-car and reversible at five fixed stations. This pass upgrades it into a high-identity rolling-stock showcase:

| Design system | Built in this pass | Future production-art requirement |
|---|---|---|
| Exterior | Bevelled procedural carbody mesh, painted alloy, copper reveals, luminous waistline, roof HVAC, panel seams | Sculpted curved nose/roof with custom topology, artist-UV'd texture sheets |
| Cabin | Actual openings in carbody, tinted alpha glass, seat cushions, ceiling lighting, handrails | Inhabited riders, complete cockpit, accessible walkable interior |
| Mobility | Bogie frames, flanged steel wheels, suspension blocks, gangway bellows/coupler | Animated wheel rotations/suspension, detailed mechanical rig |
| Passenger doors | Sliding twin panels, vision lites, status light and safety chevrons timed to dwell; original synthesized rolling ambience and arrival chime | Door motor/warning sound, closing interlock and full boarding animation |
| Lighting | Head/tail marker lights and bounded forward spot beam at travel speed; next-station cab display | Night-only fixture controls and area-specific HDR grading |
| Station | Taller canopy, platform slab, tactile safety edge, roof strip fixtures, architectural columns, glass windbreaks, signs, elevators | Real station circulation, validated accessibility, dynamic destination boards |
| Guideway | Sleeper MultiMesh, dual steel rails, structural steel caps and elevated pylons | Track fastening atlas, rails with realistic cross section and cable conduits |

**Quality claim:** This is a high-detail *procedural vertical-slice* toward AAA. It is **not yet an AAA-certified finished train asset**. The stock renderer is Godot 4.3 Forward+, and no physically based scanned texture atlas, motion-captured passengers, authored sound or final performance test is included.

## Second vertical slice: KESTREL S6

The first drivable car family has been rebuilt around one original four-seat futuristic fastback EV. It now has a beveled procedural monocoque, four visually articulated wheels, metallic clearcoat paint, a glazed canopy showing real seats and driver controls, detailed underbody construction and trim, kinetic brake/reverse lighting, bounded projected headlamps, sound that responds to speed, and a dedicated red/blue pursuit edition. The existing collider, movement, camera, player interactions and save schema remain intact. Full geometry and polish criteria are documented in [KESTREL S6](KESTREL_S6.md). As with the train, this is a testable procedural hero **pass toward AAA**, not a claim of authored final production artwork.

## Third vertical slice: CENTRAL EXCHANGE

The street-level benchmark is the fixed crossroads at the four downtown districts' shared origin. [Central Exchange](CENTRAL_EXCHANGE.md) now integrates weathered crosswalk paint, surface reflectors, asphalt repair and rainwater, recessed cast-iron storm drains, real curb openings for sloped pedestrian approaches, credible traffic signal mast/control hardware, small-scale street signs, bollards and one bounded night-only practical light. Existing traffic-light logic, lane geometry, saved street coordinates and game physics are preserved. Visual compliance must be inspected in the rendered game; physical accessibility and full AAA production art remain future work.

## Fourth vertical slice: LANTERN CUP

The original Vesper Market café is a complete **paired exterior and enterable interior** benchmark: working lanterns, glazed street façade and signage outside, plus brass/wood/ceramic interiors, slatted ceilings, upholstery and proper collision, stocked espresso service, 12 pendant lamps, restrained warm local lights, animated machine steam, and source-owned spatial pump ambience inside. Staffed purchase/health recovery, world seed and prior interaction/save contracts continue to work. A one-off shift-note discovery beside a booth gives the player something useful to find beyond the counter; it saves via the existing journal-intel array. Full QA and production-art limitations: [Lantern Cup](LANTERN_CUP.md).

## Fifth vertical slice: MARA — character language

The real Lantern Cup contact now owns an original generated humanlike mesh with a tailored barista outfit, anatomically motivated face/eyes/hair, functional accessory detailing, articulated upper-body/head/arm pivots and fixed-geometry idle, blink, speech and serving performance. Dialogue at the counter uses **3/Y** inside the existing venue menu; real health, police attention, local jobs and discovered notes alter the script, while coffee purchases animate her serving hand. The character is spawned **only** for the Lantern Cup active room and does not modify its G/H interactions, world seeds or saves. Character visual requirements and limitations: [Mara Hero](MARA_HERO.md).

## Final pre-playtest slice: inhabited Lantern Cup

Five authored café regulars extend the Mara character benchmark with varied silhouettes, garments and simple context-appropriate actions. The customers occupy existing banquette seats, have stable identities and activity phases, respond via optional **G** neighborhood gossip, and do not alter the central walking route, service desk, Lantern Cup shift note or save schema. Their mesh counts are bounded, materials shared, and there are no extra customer lights/colliders. The first hands-on review should use [the five-minute playtest route](PLAYTEST_CHECKLIST.md) to assess motion, clipping, lighting, scene consistency, usability and actual framerate.

## Capture and quality gate

- Verify the train at **12:00**, **19:15** and **00:00** from street-level wide shot, track-level three-quarter exterior, end-cab close-up, door close-up and station departure.
- Capture **actual Godot output** only. Use Vulkan/Forward+ on a supported GPU for the release gallery; any Compatibility/Mesa captures must be labelled accordingly.
- Inspect glass sorting from both sides, train body normals, door slide clearance, cab lamp direction after reversal, passenger sightlines, platform edge gap, and road underpass clearance.
- Profile GPU and CPU independently with and without SSR, SSAO and haze. Check transparent overdraw. Keep visual effects configurable.
- Re-run `tests/transport_smoke.gd`, `tests/render_smoke.gd`, menu/save tests and a Windows export before merging.
- **Do not replace README screenshots with concept renders.** The existing screenshots are real but pre-upgrade.

## Next asset candidates

After the train, use the same quality bar for one complete street intersection (surface textures, drainage, lighting and signals), one crowded café, a player vehicle, then human characters. Each vertical slice should have independent measurable visual, interaction and performance acceptance criteria before applying the style across all districts.
