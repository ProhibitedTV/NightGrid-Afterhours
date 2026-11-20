# Morrow Bay rendering handbook — ink and rain

NightGrid's visual identity is **cinematic neon noir with physically grounded surfaces**, not simulated photorealistic Los Angeles. The city uses deliberately exaggerated silhouettes, copper and concrete at midday, sea-glass blues at dusk, and restrained magenta/cyan storefront color at night. The street can look damp and reflective without a blanket of mirrorlike asphalt.

## Implemented architecture

- **Forward+ (Vulkan):** required for Godot 4.3 screen-space reflections (SSR) and enhanced glow. Screen-space reflections cannot reflect objects outside the camera or hidden behind other objects, so this is *not* ray tracing. The F4 key toggles SSR for comparisons.
- **Cached material triplets:** `scripts/material_library.gd` bakes seven families of tileable **albedo, tangent-space normal, and per-pixel roughness** maps (brick, concrete, asphalt, pavers, metal, glass, wet). The 21 GPU textures are cached and reused by world-space triplanar PBR materials across the city and enterable interiors; no external textures or unclear licensing. Windows use opaque tinted glass as a prototype approximation, not true transmissive glazing.
- **Fixed city lots:** all 112 non-landmark building slots are selected from curated authored profiles and saved explicitly by `scripts/world_plan.gd`; each has fixed dimensions, height, position, facade material and palette. The 8 authored landmark sites are protected. Cosmetic window activity and micro-details remain seeded; skyline silhouettes are fixed.
- **Wet locations:** 16 fixed, save-stable, triangulated irregular puddles lie 9 mm above asphalt with a micro-ripple normal/roughness response. They replace visible raised rectangular slabs. Screen-space reflections are approximate and not ray traced.
- **Light switching:** 81 fixed street fixture locations, a pool of **8 nearest active unshadowed OmniLight3D nodes**, and smooth dusk activation (after city lights need to come on). At noon the whole pool is fully off. The city's emissive sign materials also dim to zero during the day.
- **Lighting and grading:** one 170-meter directional shadow caster, filmic tone mapping, moderate thresholded neon bloom, switchable SSAO contact shading and exponential distance fog that shifts hue/density over the 24-hour cycle. No realtime shadows for pooled local lights; no SDFGI, SSIL or volumetric fog.
- **Vehicles:** street traffic, player cars and buses now share recognizable wheel cylinders, metal hubs, tinted glass and simple body trim. This is still procedural blockout geometry, not imported production car meshes.
- **Hero drivable sedan:** KESTREL S6 has a beveled original body mesh, tinted alpha windows, clearcoat paint, moving rims and physically motivated brake/headlights. Only a driven or police car uses live SpotLight3D beams; 12 parked cars remain unshadowed and share cached material maps. [Asset specification and visual QA](KESTREL_S6.md).
- **Central Exchange environmental hero:** one fixed street junction has material-consistent rain pockets, repair surfaces, crossed-paint wear, curb ramps, street drainage and authentic traffic hardware. 300+ ground-level details are batched, and only one unshadowed local night fixture is added. This treatment is NOT automatically repeated at all 81 intersections. [Technical brief and quality tests](CENTRAL_EXCHANGE.md).
- **Flagship Lantern Cup interior:** original brass/timber café built only while `lantern_cup` is entered; two small non-shadowed local worklights on top of the standard two interior diffuse lights, 12 emissive pendant diffusers, physically collidable booth seating, cached original brewing audio. No permanent world-wide café scene, and no measured new frame-time results. [Visual QA](LANTERN_CUP.md).
- **Mara, original human hero:** character-head and tailoring custom lofts + small rigged facial and sleeve geometry; active only in Lantern Cup's single streamed room, materials reused, zero new real-time lights. Idle, blink, head aim and purchase arm gesture update transforms only. Final character silhouette and GPU load still require actual renders and benchmarks. [Rig and QA](MARA_HERO.md).
- **Default native 1080p**, screen-space reflection max steps 24, SSR half-size project setting (where supported), F3 frame-rate overlay. SSR, bloom, SSAO and haze are independently selectable in the settings menu.

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
| Texture library | 21 × 128×128 RGBA8 maps (7 albedo + 7 normal + 7 roughness) ≈ 1.31 MiB raw pixels / ~1.75 MiB mipmapped, excluding material overhead |
| Local lights | 8 visible, unshadowed lights max, 49 authored fixture records |
| VRAM working-set goal | Under ~4 GB at native 1080p initially, leaving RAM for future art and NPC systems |

The GPU allowances sum to **16.7 ms** and are budget assignments, not measured subsystem costs. The CPU has a separate 16.7 ms frame deadline; do not add CPU and GPU frame times naively because much work can overlap.

**Render-risk estimate (untested):** PBR triplanar normal/roughness lookups and SSAO add GPU cost; disable **CONTACT SHADOWS / AO** first if necessary to establish a baseline.  at 1080p, our 24-step SSR work is gated by pixel coverage of low-roughness materials and the engine's half-size reflection setting. Pure worst-case half-resolution rays would process ~1.04 million pixels * 24 steps ≈ 24.9 million ray steps before overhead, masking and early exits. This is *not* the actual GPU operation count or a performance benchmark. SSR may need reducing to 16 steps or disabling in heavy scenes. Forward+ is a measured-performance experiment for the RTX 3060, not a promise of 60 FPS.

## Tuning plan

On the user's RTX 3060/Ryzen 7/32 GB PC, test each district at 12:00, 19:15 and 00:00 with F3 overlay, then repeat with F4 SSR disabled. Measure GPU and CPU frametimes with Godot profiler (not just average FPS). Check the cost of SSR, SSAO, haze, glow, and directional shadows separately. The headless GitHub smoke suite verifies resource wiring and scene contracts; it cannot prove appearance or target framerate on real hardware. If below 60 FPS, reduce SSR steps/reflections first, then shadow range and expensive surfaces, *before* deleting neighborhood content.

## Near-future quality work

Introduce authored UV-unwrapped facade geometry, higher-resolution scanned or authored texture atlases with permission, artist-designed storefront decals and ground clutter, denser fixed props, stable reflection probes for off-screen reflection fallback, procedural street lighting temperature variation, believable human character silhouettes and LODs. Current procedural microtexture maps are deliberately small stylized placeholders—they are texture-backed PBR, **not** AAA scanned assets.

## Expanded map rendering note

The new eight-district map groups decorative MultiMesh instances by material **and two-block chunk** to help visibility culling, rather than making an enormous all-city batch. The four new protected public plazas, 16 authored service frontages, 128 street trees, and 81 signal pairs add geometry and may increase frame time. Actual 3060 performance is **unmeasured**, so adding a second city ring does not imply we have achieved the 1080p/60 target. [Expansion guide](EXPANSION.md).
