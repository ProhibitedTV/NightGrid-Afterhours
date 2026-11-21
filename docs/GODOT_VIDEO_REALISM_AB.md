# Evidence-based Godot rendering A/B: Coding Quests tutorial

**User reference:** [Why 3D Games Look Bad in Godot](https://www.youtube.com/watch?v=0792U-wuwjA) by **Coding Quests**, published October 2026; creator's exact [companion article, “How to Make Godot 3D Look Better: 12 Changes, Same Models”](https://codingquests.io/blog/how-to-make-godot-3d-look-better).

**Engine migration:** The original **tagged beta.3** is a **Godot 4.3.0** executable, using Filmic baseline and an ACES preview because [Godot 4.3 does not support AgX](https://docs.godotengine.org/en/4.3/classes/class_environment.html). **Beta.4 and the current development source use Godot 4.7.2 stable**, supporting both ACES and the **actual AgX** tonemapper, with optional AgX contrast/white properties. The default remains Filmic. To avoid conflating an engine upgrade with an art upgrade, we retain all three named modes and log the mode used in every F10 capture. [Full migration and compatibility](GODOT_4_7_2_MIGRATION.md).

## Tutorial — what is actually demonstrated

The author retains the same village models and switches on twelve rendering changes in sequence, showing each change at a fixed reference camera:

1. Low-angle side-lit warm directional sun and shadow contact/softening.
2. A coloured **sky that lights shadows**, not only a decorative skybox.
3. **AgX tonemapping** and exposure/highlight control, with a mild colour grade.
4. **SSAO + SSIL** for surface contact and nearby screen-space bounce.
5. **SDFGI** for longer-range diffuse bounced light.
6. Light **distance fog**, ground mist and subtle volumetric haze to establish depth while retaining road readability.
7. Leaf card **normal shaping** and wind so a tree canopy shades as a volume.
8. Grass **root-anchored motion** from vertex colour, painted terrain dirt/variation masks.
9. Dense **MultiMesh** foliage with distance/shadow culling.
10. Motivated visible **practical lights** and an isolated character fill.
11. Camera lens/FOV and cautious depth-of-field (author intentionally excluded their lens change from the final comparison because it affected gameplay framing).
12. MSAA/TAA, debanding and subtle lens/grain polish.

**Performance caveat:** all effects together initially produced **46–50 FPS even on the author's RTX 5080** at 1080p. Their cheaper shadow map (8192 → 4096), reduced soft-shadow quality, shorter shadow distance, MSAA 2x and shorter grass draw distance lifted the capped run to **75 FPS**. Those numbers are for their scene/hardware, **not a benchmark for Morrow Bay**. The [community follow-up](https://www.reddit.com/r/godot/comments/1xwf2nk/updating_the_visuals/) also observed high SSAO/SSIL cost for modest visual gain; prioritize measurable impact. <https://codingquests.io/blog/how-to-make-godot-3d-look-better>

## NightGrid current state versus tutorial

| Area | Existing NightGrid beta | Controlled next step |
|---|---|---|
| Tonemap | **Filmic**, not default Linear; thus already avoids the video's most naive blowout | On Godot **4.7.2**, compare Filmic to **ACES** and real **AgX** with matched 1.11 exposure, sky ambient and fog |
| Sky | Animated-colour `ProceduralSkyMaterial` visible in the distance, but **ambient is hardcoded COLOR**, so the sky does not actually shape diffuse shadow tint | F11 toggles **SKY ambient** at 78% contribution, retaining a portion of calibrated colour fill |
| Sun | A single time-of-day directional shadow source, at night only ~0.13 energy | Keep clock motion and hue, test shorter shadow range **170 → 96m** and angular width 0.7°, without raising full-night sun energy |
| Occlusion/GI | SSAO on; **SSIL and SDFGI off** | Leave the heavy techniques OFF for 3060 until isolated A/B timings |
| Fog | 0.0085 at night, which can hide block detail; **volumetric fog off** | Lower experimental night fog to 0.0052 and midday 0.0036; do **not** enable volumetrics |
| 3D architecture | One-off PBR architectural pilots in Central Exchange and Dock Watch but most city/vehicles remain primitive | Follow issue [#51](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/51) for true authored glTF city/vehicle asset replacement; lighting alone cannot produce believable buildings |
| Ground/plant assets | Some scanned PBR, basic wet-street shading and authored fern, with batched details | Handle vegetation normals/shaders and pavement material layers in a separate small scoped location, not a citywide shader rewrite |

## Reproducible player A/B controls

**Godot 4.7.2 F11** cycles three explicitly labelled modes **without moving the player, changing the game time, changing the save, or changing graphics setting preferences**. Tagged beta.3 has only Filmic and ACES.

- `filmic_baseline`: untouched original Filmic curve, ambient COLOR, 170m shadow distance and original fog. **Default on every launch.**
- `sky_aces_experiment`: compatible ACES tone mapping with 1.11 exposure, actual dynamic SKY ambient contributing 78%, shorter (96m) directional shadow cascade and thinner distance haze. No new GI/volumetric/SSIL effect or new scene light.
- `sky_agx_experiment`: actual 4.7.2 **AgX** tone mapping, retaining the **identical 1.11 exposure, SKY ambient, sun shadows and fog** as the ACES preview. That isolates the tone curve. No expensive GI or global switch in default rendering.

**Recommended matched capture:** Go to **West Docks, Dock Watch Desk** at the same camera position as the 22:07 screenshot. Press **Y** to pause the day/night clock, then **F10** in Filmic baseline mode, press **F11** and **F10** for ACES, then **F11** and **F10** for AgX **without moving**. Press F11 a third time to restore Filmic. (Tagged beta.3 toggles just Filmic and ACES.) For performance, use identical F8 CSV runs (start/stop once per preset) along the same cold and warm routes; note whether sky lighting introduces a hitch. Use F7 to mark visual or lighting anomalies.

The JSON metadata of every F10 frame and each JSONL event now include `render_profile`. An F11 change also records an explicit `render_profile_switched` event. This supports correct before/after comparison instead of screenshots of different time-of-day or build. **The original beta.2 does not have the A/B experiment; it first ships in tagged beta.3.** The Filmic baseline remains the default in all versions; the **AgX mode first ships in the beta.4 Godot 4.7.2 release**.

## Promotion gate / what is not verified

Before making the experimental preset the default or enabling any costly options, compare the *actual* Windows Godot Forward+/Vulkan captured frames for street silhouettes, properly grounded vehicles, material highlight rolloff, fog visibility and shadow contact. Compare p95/p99 GPU/CPU frame time and F8 1% lows on the RTX 3060-class machine. If the sky source produces worse temporal stability or cost, keep Filmic baseline. Headless tests prove setting reversibility and save contracts only, **not visual quality**.

We should not use post-processing to camouflage bad car meshes or repeated windows. First upgrade genuine geometry/material assets, then light them.
