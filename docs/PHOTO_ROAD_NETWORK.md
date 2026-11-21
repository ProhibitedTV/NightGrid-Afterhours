# Photographic street network

Extends the real Central Exchange photo-asphalt pilot to the existing 9×9
road grid. Replaces the 18 overlapping visual road boxes with two
material-sorted meshes (dry running lanes and darker damp gutters). Each
junction and road segment has world-anchored 3.5m UVs and explicit tangent
normals; intersections and crossing approaches remain dry. Uses the same
bundled [Poly Haven CC0 Bitumen](https://polyhaven.com/a/bitumen)
diffuse, OpenGL normal and roughness maps as Central Exchange; see
[original provenance](../assets/pbr/polyhaven/SOURCE.json). No runtime
downloads, new lights, collision, save fields or per-frame geometry. The
existing hero road overlay, road paint, curb assemblies, signals, ground
collider and layout are unchanged. No claim of native visual or FPS acceptance.

Review actual before/after images from the same camera and clock. The
automated gallery capture uses Godot 4.7.2 Compatibility; native Forward+
F10 screenshots and F8 frame traces at Morrow Bay's market and Central
Exchange still determine material/reflection acceptance. Watch for
repeating texture, overly dark asphalt, and visible transitions at the
hero overlay. The new scene test verifies exact original footprint,
non-overlap, UV/tangent geometry, shared maps and two-drawable budget.

## Capture evidence
The [seven-image capture run](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44954026080) completed successfully using source 1645d87; the intervening 4f818a0 commit changes only test tolerances/type annotations. Its actual gallery and manifest are committed. Vesper Market still has visibly blocky bus and building silhouettes; this is a material replacement, not an overall art acceptance. Final combined revision must pass preflight and Windows export.
