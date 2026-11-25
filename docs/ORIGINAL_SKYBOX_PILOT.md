# NightGrid original skybox pilot (pre-alpha)

Eight original AI-generated coastal scene artworks were converted to 1536×768 2:1 WebP textures. Files are in `assets/skyboxes/nightgrid_original/` and are creator-supplied, game-specific art; no third-party stock licensing. The conversion moved sky/cloud imagery into the upper hemisphere, attenuated the lower hemisphere and softened the horizontal seam. **They are NOT genuine 360° captures, verified seamless HDRIs, or correct radiometric light probes.** The original PNGs and conversion recipe are in the separately downloadable conversation asset pack; the GitHub source stores only 395 KB of optimized game textures.

## Operation
- Four clock phases: dawn (05–08), daytime (08–16), evening (16–20), night (20–05). Time phase changes are discrete while the existing lighting clock continues smoothly; true art-to-art blending is future work.
- Five preview weather states: clear, cloudy, overcast, rain, storm. They alter the sky, sun energy and fog **only**; this pilot does not yet provide physically simulated precipitation, storms, lightning or weather persistence. Clear is the initial state.
- In gameplay **F2** cycles sky weather. Use **Y** to freeze the game clock, **T** to advance the hour to explore hours, **F10** for genuine Windows PNG+metadata, and **F8** for CPU frame interval traces.
- Command line: `NightGrid-Afterhours.exe -- --sky-weather=storm` starts with storm skies. Add `--procedural-sky` after `--` to revert to the original procedural sky without touching a save.
- Procedural fallback is retained in `day_night.gd`. Panorama texture changes only when the chosen phase or weather changes, **not every 200ms**. Sky radiance map is limited to 256 for RTX 3060 experiments.
- Sunny/day/night conditions can be viewed without starting a new world. F10 metadata records `sky_preset` and `sky_weather` for honest comparisons.

## Known limits / acceptance
1. **Full 360° yaw/elevation inspection required.** Original scenic images were not captured equirectangular, so clouds, sun/moon alignment, lower hemisphere and extreme elevations may exhibit mismatch or stretching. Fixed seam feathering is approximate; no claim of photoreal/full-sphere completion.
2. The sun/moon is baked into the generated image while Godot's physical directional light rotates independently. Match yaw/altitude and smooth transitions in a follow-up only after native screenshots. Do not claim the baked sun is a physically accurate HDR light.
3. Test the five weather modes at dawn, noon, dusk and midnight from a fixed camera and on RTX 3060 12GB Windows Forward+/Vulkan. In particular compare both performance p50/p95/p99 and *wall-clock stalls* during sky switches, 360° seams, moon direction, city fog and wet-pavement compatibility.
4. Screen-space reflections, ambient irradiance, wet ground, harbor water and city lighting may require art tuning. FILMIC remains the default; F11 ACES/AgX still works. Real 60 FPS remains unverified.
5. Run `godot --headless --path . --script res://tests/skybox_cycle_smoke.gd`; this validates resource types/preset choice and fallback only, not actual GPU quality.

Creator-approved artistic direction, **not a new public beta release**. Published beta.7 tag is unaffected.
