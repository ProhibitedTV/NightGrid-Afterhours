# Morrow Bay rendering handbook — ink and rain

NightGrid's visual identity is **printed graphic noir**, not simulated photorealistic Los Angeles. The city uses deliberately exaggerated silhouettes, copper and concrete at midday, sea-glass blues at dusk, and restrained magenta/cyan storefront color at night. The street can look damp and reflective without a blanket of mirrorlike asphalt.

## Implemented architecture

- **Forward+ (Vulkan):** required for Godot 4.3 screen-space reflections (SSR) and enhanced glow. Screen-space reflections cannot reflect objects outside the camera or hidden behind other objects, so this is *not* ray tracing. The F4 key toggles SSR for comparisons.
- **Cached surface maps:** `scripts/material_library.gd` builds seven small tileable texture maps (brick, concrete, asphalt, pavers, metal, glass, wet) once on CPU. The material variants reuse these GPU textures, apply world triplanar mapping, and use varied PBR metallic/roughness settings. Source-owned and reproducible; no external asset license ambiguity.
- **Fixed city lots:** all 112 non-landmark building slots are selected from curated authored profiles and saved explicitly by `scripts/world_plan.gd`; each has fixed dimensions, height, position, facade material and palette. The 8 authored landmark sites are protected. Cosmetic window activity and micro-details remain seeded; skyline silhouettes are fixed.
- **Wet locations:** 16 hand-placed, shallow reflective patches use a low-roughness wet surface. They sit on roads, never require water simulation, and allow limited localized SSR reflections.
- **Light switching:** 81 fixed street fixture locations, a pool of **8 nearest active unshadowed OmniLight3D nodes**, and smooth dusk activation (after city lights need to come on). At noon the whole pool is fully off. The city's emissive sign materials also dim to zero during the day.
- **Shadows:** one directional shadow caster, 170-meter shadow distance. No realtime shadows for the pooled local lights; no SDFGI, SSIL, or volumetric fog. Bloom intensity is moderate.
- **Default native 1080p**, screen-space reflection max steps 24, SSR half-size project setting (where supported), F3 frame-rate overlay.

## RTX 3060 12GB engineering envelope

NVIDIA's desktop GeForce RTX 3060 12GB configuration has **3,584 CUDA cores, 12 GB GDDR6, and a 170 W board power rating**. A common reference-class card uses a 192-bit bus at roughly **360 GB/s**. These specs describe capacity and throughput, *not benchmarked game performance*. Driver revisions, engine shader complexity, actual Ryzen 7 model, cooling, resolution, and scene occupancy determine real framerate.

| Metric | Engineering budget (not benchmark result) |
|---|---|
| Resolution | 1920 × 1080 = 2,073,600 displayed pixels |
| Frame cadence | 60 FPS target → 16.67 milliseconds per frame |
| Geometry + material/lighting | ~6.0 ms GPU allowance |
| Directional shadow pass | ~2.0 ms GPU allowance |
| Half-resolution SSR | ~2.5 ms GPU allowance |
| Glow/tonemap/post | ~1.5 ms GPU allowance |
| Other effects + headroom | ~4.7 ms GPU allowance |
| Texture library | Seven 128×128 RGBA8 maps = 0.44 MiB raw pixels; with mipmaps ~0.58 MiB, excluding runtime material overhead |
| Local lights | 8 visible, unshadowed lights max, 49 authored fixture records |
| VRAM working-set goal | Under ~4 GB at native 1080p initially, leaving RAM for future art and NPC systems |

The GPU allowances sum to **16.7 ms** and are budget assignments, not measured subsystem costs. The CPU has a separate 16.7 ms frame deadline; do not add CPU and GPU frame times naively because much work can overlap.

**Render-risk estimate (untested):** at 1080p, our 24-step SSR work is gated by pixel coverage of low-roughness materials and the engine's half-size reflection setting. Pure worst-case half-resolution rays would process ~1.04 million pixels * 24 steps ≈ 24.9 million ray steps before overhead, masking and early exits. This is *not* the actual GPU operation count or a performance benchmark. SSR may need reducing to 16 steps or disabling in heavy scenes. Forward+ is a measured-performance experiment for the RTX 3060, not a promise of 60 FPS.

## Tuning plan

On the user's RTX 3060/Ryzen 7/32 GB PC, test each district at 12:00, 19:15 and 00:00 with F3 overlay, then repeat with F4 SSR disabled. Measure GPU and CPU frametimes with Godot profiler (not just average FPS). Check the cost of glow and shadows separately. If below 60 FPS, reduce SSR steps/reflections first, then shadow range and expensive surfaces, *before* deleting neighborhood content.

## Near-future quality work

Introduce authored UV-unwrapped facade geometry and true physically based authored texture atlases, artist-designed storefront decals and ground clutter, denser fixed props, stable reflection probes for off-screen reflection fallback, and cinematic light grading. Current procedural microtexture maps are deliberately small stylized placeholders—they are texture-backed PBR, **not** AAA scanned assets.

## Expanded map rendering note

The new eight-district map groups decorative MultiMesh instances by material **and two-block chunk** to help visibility culling, rather than making an enormous all-city batch. The four new protected public plazas, 16 authored service frontages, 128 street trees, and 81 signal pairs add geometry and may increase frame time. Actual 3060 performance is **unmeasured**, so adding a second city ring does not imply we have achieved the 1080p/60 target. [Expansion guide](EXPANSION.md).
