# Kestrel front bumper native review

Exported source commit `8e583a788e95599e27ee1e3de199975a7dc24d92`. Current-main base `3ec2af18`. The same exported PCK generated each pair using the review-only fascia fixture.

[Day and night comparison](Kestrel-Jade-Wash-comparison.jpg). The underlying real game frames are 1920 × 1080 PNGs. The contact sheet resizes the frames and adds captions.

Godot 4.7.2-stable (official), Windows Forward+/Vulkan. RTX 3060 12 GB, Ryzen 7 2700X. Seed 834726. Mark (-86.54, 0.84, 83.4). SSR, SSAO, fog and glow on with VSync disabled.

The source revision passed the fascia topology and provenance check, Godot import, 77 Godot regression cases, 90-frame headless boot, Windows x64 export and native packaged startup. The reference and source are linked in the production brief.

Each row contains 180 frame-post-draw intervals after the view settled. The stock and candidate frames use the same camera, clock, chassis and crimson color. The candidate changes the bumper geometry and its PBR finish. GPU timing is the measured viewport render time.

| View | Mode | Median ms | p95 ms | p99 ms | Max ms | GPU p95 ms | Render CPU p95 ms | >16.67 ms | >33.3 ms | Draw calls | Unfocused |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Overcast daylight | stock | 5.28 | 8.80 | 9.22 | 9.59 | 5.15 | 3.46 | 0 | 0 | 1060 | 0 |
| Overcast daylight | candidate | 5.34 | 8.71 | 8.98 | 9.24 | 5.17 | 3.43 | 0 | 0 | 1064 | 0 |
| Jade Wash at 22:06 | stock | 6.12 | 9.38 | 9.72 | 11.38 | 5.35 | 4.10 | 0 | 0 | 1057 | 0 |
| Jade Wash at 22:06 | candidate | 7.36 | 10.67 | 12.60 | 13.45 | 5.33 | 4.56 | 0 | 0 | 1068 | 0 |
| Intake inspection at 22:06 | stock | 6.32 | 10.20 | 11.17 | 11.56 | 4.82 | 3.98 | 0 | 0 | 1045 | 0 |
| Intake inspection at 22:06 | candidate | 7.17 | 10.54 | 11.99 | 14.44 | 4.87 | 4.43 | 0 | 0 | 1056 | 0 |

This stationary setup samples the cost of one front assembly. Sustained driving, weather-linked wetness, traffic-wide replacement and creator acceptance remain outside this measurement.

The fitted cap follows the original bonnet edge and the three vents have visible depth. The remaining prototype bonnet, box headlamps and tall greenhouse still dominate the silhouette. The front fender return should be reviewed together with the bonnet and lamp apertures before production integration.
