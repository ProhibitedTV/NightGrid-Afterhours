# CENTRAL EXCHANGE — hero junction / street-level art benchmark

The third NightGrid visual slice focuses on **one genuinely playable intersection at world coordinate (0, 0)**, where Vesper Market, Glassline, Brickwater and Afterhours meet. After upgrading the M-Line and KESTREL S6, this environmental asset tests whether the same hyper-realistic-yet-stylized cyberpunk art direction can hold up at pedestrian eye level and while driving through it.

## The design: infrastructure first, future second

- **Four crosswalks** retain the existing authored zebra geometry, but are overlaid with 216 deterministic abrasion marks that expose darker road pigment. Surface-set raised-bead reflectors catch night lighting without acting as a speed bump.
- **Eight pedestrian ramp approaches** slope from the 14 cm sidewalk down to roadway elevation. Four adjoining blocks have **short openings cut into their inner curb endpoints** so the ramps do not overlap the original raised continuous curbs. This is readable *visual* accessibility treatment; it has **not** been certified for real wheelchair physics, ADA/AODA slope compliance, or pedestrian pathfinding.
- **Eight cast-metal storm grates** have recessed dark sockets and individual slats. Weathering is concentrated near curbs where drainage would collect water.
- **Three irregular resurfacing patches**, two local shallow reflective puddles, sealed hairline cracks, dark gutter reflectors and thermoplastic road-paint fragments add material variation rather than blank wet mirror asphalt.
- **Actual traffic signal mounts**, a base, cross-arm, cable/control box, warning stripe and sidewalks signs physically support the original independently controlled NS and EW signal heads. **Traffic controls remain governed exclusively by `traffic_signals.gd`**: green/yellow/all-red rules, roadway, lane width and stop-bar positions are unchanged.
- **Morrow Bay wayfinding:** neighbourhood-specific signage, stamped service identity, reflective bollards, warm copper/teal contrasts, one restrained pooled practical night light, readable navigation at street level.
- **Draw calls and lighting:** 326+ repeated wear/marking details share a handful of MultiMeshes; one additional non-shadow-casting OmniLight3D is fully off by day, fades in at night via the existing `day_night.gd` clock. No dynamic geometry generation during gameplay, no time-dependent procedural randomness.

## Integration contract

`scripts/central_exchange_hero.gd` is a static visual-only Node3D constructed during normal world creation. Its node and position are fixed across **all world seeds**. The four adjacent lots retain existing seeded profiles (with only a short curb endpoint opening); no existing landmark or venue changes its location.

Existing `scripts/city_details.gd`, `scripts/traffic_signals.gd` and `scripts/world.gd` still own streets, lane following, traffic authority, player mobility and game save files. The hero intersection never spawns a parallel signal controller or collision body. `scripts/day_night.gd` takes an optional fifth node to coordinate hero practical lighting; older four-argument calls remain supported.

**The actual vehicular road remains 14 m wide** and the traffic lights' 72-second cycles remain unchanged. None of the visual pavement treatment is promoted to a physics barrier. An entire intersection has been improved as a *hero scene*, not all 81 signalized junctions.

## Quality gates and limitations

- The new `tests/hero_intersection_smoke.gd` checks counts, real sloped mesh ramps, 81 signal-controller locations and conflict-free phasing, day/night lighting and snapshot stability. It runs in GitHub Actions alongside all earlier full-game tests and Windows export.
- Check **actual** game captures at **noon**, **twilight** and **midnight** from all four street-corner viewpoints, the lower pedestrian approach, and KESTREL driving through each direction.
- Inspect PBR textures, any z-fighting where scratches meet original zebras, curb opening edges, drainage slots, traffic head physical connection and generated sign placement. Move objects if they obstruct navigation.
- Performance target is **1920×1080 / 60 FPS on RTX 3060 12GB**, **not measured**. Profile GPU lighting, SSR puddles, transparent vehicle glass and geometry batch cost on real hardware.
- This is a high-detail **procedural vertical slice toward AAA**, not proof of AAA completeness. It still needs hand-authored displacement/normal textures, wider surface decals, weather particles, animation, traffic and pedestrian reactions, proper ramp collision/navigation, human crowds and verified rendered footage. Existing README screenshots are pre-upgrade.

## Recommended next asset

An **inhabited, enterable late-night café** with cohesive interior/exterior: counter, barista/owner, seating, signs, menu boards, lighting and interactive quests. This would prove the hero language can reach interior spaces rather than just infrastructure.
