# Photographic masonry replacement

Part of #19/#21. Ordinary buildings whose persistent lot profile specifies BRICK
now use the existing [Poly Haven brick_wall_001 CC0 scan](https://polyhaven.com/a/brick_wall_001)
rather than 128px procedural masonry. The source diffuse, GL normal and roughness
maps are shared by cached materials, with continuous world mapping at a 2.5m
tile scale and a subdued multiplier retaining each lot's district tint.
Preserves exact shell geometry and collision, saved profile, floor/window layout,
entrances, existing authored hero frontages and all non-brick materials. No extra
binary assets, mesh instances, lights, or per-frame work.

This is a material replacement, not new complete building architecture. Review
brick scale, tint, corner alignment, glass/brick transitions and repetition in
actual gallery and native Forward+ screenshots. Native frame timing remains
unmeasured. The real-scene regression checks ordinary brick lot meshes and
collider sizes against the existing manifest across two parcels.

[Source license and hashes](../assets/pbr/polyhaven/SOURCE.json).
