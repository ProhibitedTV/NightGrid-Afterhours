# NightGrid visual north star — believable cyberpunk futurism

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

## Capture and quality gate

- Verify the train at **12:00**, **19:15** and **00:00** from street-level wide shot, track-level three-quarter exterior, end-cab close-up, door close-up and station departure.
- Capture **actual Godot output** only. Use Vulkan/Forward+ on a supported GPU for the release gallery; any Compatibility/Mesa captures must be labelled accordingly.
- Inspect glass sorting from both sides, train body normals, door slide clearance, cab lamp direction after reversal, passenger sightlines, platform edge gap, and road underpass clearance.
- Profile GPU and CPU independently with and without SSR, SSAO and haze. Check transparent overdraw. Keep visual effects configurable.
- Re-run `tests/transport_smoke.gd`, `tests/render_smoke.gd`, menu/save tests and a Windows export before merging.
- **Do not replace README screenshots with concept renders.** The existing screenshots are real but pre-upgrade.

## Next asset candidates

After the train, use the same quality bar for one complete street intersection (surface textures, drainage, lighting and signals), one crowded café, a player vehicle, then human characters. Each vertical slice should have independent measurable visual, interaction and performance acceptance criteria before applying the style across all districts.
