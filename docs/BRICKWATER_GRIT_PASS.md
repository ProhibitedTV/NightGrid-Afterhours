# Brickwater grit pass — painted masonry and continuous wetness

User direction: gritty, weathered alley, graffiti and wet ground. Extends #145, #146, #149 and #150.

- Three original path-only graffiti artworks (muted faded mauve/cream, green-gray, chalk), two wall runoff overlays with damp base and vertical staining; independent of font availability, no copied tags/brands. Matte, non-emissive alpha textures sit within 19mm of the actual wall. No physical obstructions.
- Replace the three discrete puddle polygons and transparent ground grime plane with one opaque spatial shader on the existing photographic pavement. Reuses existing licensed concrete color, normal and packed ARM, plus original weathering and a new hand-authored grayscale wetness atlas. Water covers five irregular pooled cores plus damp wall edges and seepage with gradual transitions, not a uniform mirror. Roughness, normal strength and dielectric coat vary with the mask. No screen reads or new global render effects; uses the existing optional SSR/ambient lighting settings. This is a static wet-night art state, not real-time rainfall.
- Original physics floor, prop collision, addresses, architecture, and shared city dry materials unchanged. Existing signage and lamps preserved.

Validation: focused smoke verifies texture bindings, wetness contrast, matte wall placement and unchanged dry material; native Forward+ check still needed for actual wet reflections, blending/layering, shader visual quality and performance. No native acceptance claim.
