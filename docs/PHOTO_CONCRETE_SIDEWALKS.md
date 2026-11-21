# Photographic sidewalk and curb material pass

Part of #19 and #21. All 64 permanent parcel slabs and ordinary streamed curb strips use the existing CC0 [Poly Haven concrete_floor_01](https://polyhaven.com/a/concrete_floor_01) scan bundled in the original Central Exchange curb kit. Its verified base color, GL normal and packed ARM images are reused without copying binaries. Green is roughness; concrete is nonmetallic. World-aligned 2m texture scale maintains continuity across parcels. Cached material variants share the same textures. Existing tactile/slab seams, hero curb glTFs, street props, landscape, interiors, collision and parcel positions are untouched.

This replaces the generic procedural tile material on the public slab and flat color on ordinary curb strips; does not claim new sidewalk geometry. Concrete tint is deliberately restrained and brighter than asphalt. Review repeating texture and luminance in daylight and at night. Existing render smoke now validates all 64 real parcel meshes and exact shared photo channels. Native Forward+ visual and frame-time acceptance remain pending.

[Source and hashes](../assets/models/nightgrid/central_exchange_curb/SOURCE.json). No added lights, runtime downloads or save migration.
