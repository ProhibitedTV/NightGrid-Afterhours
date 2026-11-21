# Central Exchange — original 3D walk-in retail storefronts (vertical slice phase 3)

**Location:** Central Exchange, fixed parcels **(-1, 0), lot 1** and **(0, 0), lot 0**. Continuation of [phase 1 photo-PBR street furniture](CENTRAL_EXCHANGE_PHOTOREAL_VERTICAL_SLICE.md) and [phase 2 original concrete curbs](CENTRAL_EXCHANGE_ORIGINAL_CURB_KIT.md). Parent issue [#21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21).

## What is now genuinely in the playable world

The two already authored corner buildings previously offered four continuous ground-floor **display windows**, but their centers were blocked by the same invisible full-volume StaticBody3D boxes as every other building. The old door would have been a visual illusion.

This change adds two **original NightGrid authored, UV/tangent-bearing, imported glTF 2.0 storefronts**, with real physical 3D geometry. They replace the two middle ground-floor flat-glass bays of the permanent Brickwater and Afterhours/steel corner buildings; the remaining side-facing geometry, two outside display bays, upper stories and original rooftop envelopes are retained.

Each shop model has:

- A **2.84m-wide, 3.17m-clear-height physically open pedestrian entry** with modeled metal jambs and header but **no solid door or fake threshold collision**.
- A **3.35m-deep, three-dimensional entry room**, with a floor aligned to the actual street grade (about 1–2cm above terrain), walls, ceiling, deep rear counter, 20 modelled stock units on the back shelving and six more individual items behind the shop display glazing.
- **Two transparently glazed recessed side display bays** with fully dimensional 1m-deep backdrop shelving and actual separate glass planes, mullions and visible stock, rather than old bright colored rectangles backed by an opaque box.
- Separate 3D metal framing, deep soffits, stock shelving, concrete floor and door threshold, real concrete/brick/steel/bitumen photo-PBR, and two small warm practical ceiling lenses with actual glTF emissive materials. There are **no new real-time dynamic lights**, so the practical lens is visibly luminous without a currently verified dynamic light spill onto the pavement.
- **Brickwater** brick-façade variant: **1,834 source triangles / 3,668 UV/tangent vertices**. **Afterhours** photographed steel/brick interior variant: **1,846 triangles / 3,692 UV/tangent vertices**. Both are just **six source material surfaces**, not hundreds of runtime BoxMesh nodes.

### Physics is not a visual trick

`scripts/city_details.gd` creates actual **four-component StaticBody3D building collision shells** at these **two and only these two** save-stable retail parcels, in the normal chunk's earliest collision-building stage. The four-part partition includes:

1. **Two full-depth left/right solid building flanks** protecting the display walls, side rooms, original neighboring lot boundaries and upper-story windows.
2. **A full-height solid rear wall** beginning at exactly 3.35m behind the original parcel-front coordinate.
3. **A solid overhead lintel** above 3.17m of doorway clearance.

The result is a **real 3D walkable entry bay**, not a fully explorable multi-story shop and **not a new H-to-interior gameplay interaction**. It does not falsely claim a stocked commerce system, new quests, or a continuity-preserving door into every existing remote venue. Existing venues still use the known interior-space H transition; all other lots, including Dock Watch and the Crane & Gear warehouse, keep their original collider and existing door/civic contracts. Existing world seed, parcel manifests, traffic signals, 60Hz physics, curb slopes, collision stage order and street addresses are untouched.

The visitor can walk in from the actual sidewalk, explore the 3.35m room and see the counter from street level. A later game-design milestone can connect these two boutique pilot spaces to merch transactions and distinct interactions rather than presenting decorative shelves as a working shop.

### Grounded photographs, original geometry

The source-authoring file `tools/author_exchange_storefronts.py` converts **already audited** CC0 photographic 2K maps from [Poly Haven Brick Wall 001](https://polyhaven.com/a/brick_wall_001), [Blue Metal Plate](https://polyhaven.com/a/blue_metal_plate), [Bitumen](https://polyhaven.com/a/bitumen), and our previously source-pinned [Concrete Floor 01](https://polyhaven.com/a/concrete_floor_01) into **12 optimized 1K PBR maps** (each of four materials has diffuse/albedo, tangent-space OpenGL normal and glTF-style **R=AO, G=roughness, B=metalness** packed texture; concrete is never metallic).

Original model geometry and 12 material maps are all pinned under `assets/models/nightgrid/central_exchange_storefront/` as **two glTFs, two binary buffers, twelve maps and `SOURCE.json`**. The manifest includes SHA-256 hashes for every original source photograph and derived model/texture, exact source authoring script hash, licensing and the **two permanent parcel keys**. [Poly Haven CC0](https://polyhaven.com/license) permits commercial redistribution. There are **no image generation service dependencies or runtime download requests**, and regular retail/game builds do not need Python or Pillow. An isolated branch-scoped GitHub Actions source-authoring workflow runs once.

## Tests and truthful release gate

```bash
python tools/check_exchange_storefronts.py
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/central_exchange_walk_in_shops_smoke.gd
godot --headless --path . --script res://tests/central_exchange_authored_curbs_smoke.gd
```

The **source auditor** verifies upstream CC0 hashes, full model source, texture dependencies, actual material maps, alpha-glass and emissive lenses, at least 1,700 model triangles, six glTF source surfaces, and exact doorway dimensions.

The **real-game smoke** boots the playable scene, verifies both actual generated and saved parcel identities, aligns façades to the original frontage plane, validates **two exact four-part real physics shells**, tests real Godot physics ray queries through both entry openings and against each rear wall, confirms two imported authentic photo-PBR glTFs and existing crossings/signals, restores a save snapshot, streams both buildings entirely out and in, and checks the same identities/collisions without rerolling the city.

## Visual review before photoreal approval

- At **Central Exchange, street-front z=14.12**, take identical real-game F10 Windows Godot 4.7.2 Forward+/Vulkan **22:07 and 12:00** shots from player/street and 1m inside the two shop doorways; compare against earlier baseline. The two building centers are **x=-18.5m** (brick) and **x=+18.5m** (steel).
- Walk into the entry, test the shoulder clearance at both jambs and the corner storefront collision, then test the actual rear counter/back wall. The full building is **not** intentionally penetrable past 3.35m. Make sure the world floor, player foot placement and real prefab threshold do not float/clip.
- Check the photographed PBR sampling and alpha-glass sorting at day/night, the two coherent mirrored shop silhouettes, the side display cases, mesh tangents, upper-floor continuity and distance LOD/pop-in.
- Use F7 incident markers and paired **F8** traces for 1080p RTX 3060 12GB night/day cold/warm traversal. No headless test is genuine GPU visual proof or a 60fps claim.
- The next independent deliverables after native approval are an active shop system tied to canonical identities, practical light spill at night with a measured two-light budget, ambient sounds/commerce, and production DCC art replacing the remaining prototype façades.

**Realistic 3D walk-in pilot ≠ complete photoreal AAA block.** This document describes exactly which assets and gameplay transitions are implemented, with unresolved native screenshot/performance QA disclosed.
