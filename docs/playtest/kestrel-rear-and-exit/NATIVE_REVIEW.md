# Kestrel rear body and vehicle exit · Windows review

Source `bd38fb95804cb79e0256cf7ccaa54127cae1be8d`. The baseline pack came from `8e583a788e95599e27ee1e3de199975a7dc24d92`. The same camera rig, seed and graphics settings were used for both builds.

[Day and night comparison](Kestrel-Southworks-comparison.jpg). The contact sheet resizes the unaltered 1920 × 1080 gameplay frames and adds captions. The raw PNGs and manifests are in the native evidence ZIP.

Windows Godot 4.7.2-stable (official) Forward+/Vulkan on RTX 3060 12 GB and Ryzen 7 2700X. Seed 834726. The car was placed at (86.7, 0.84, 177.55). SSR, SSAO, glow and fog enabled. VSync disabled.

Both authored assets passed the source and import checks. All 77 Godot cases passed. The native Windows export launched with the exact source stamp.

## South Bus Works contact and exit

The actual vehicle stopped at X 82.150 m against the crate centered at X 85.0 m, with the car facing along X. The blocked-door test kept the player seated. The courier alighted at (85.44, 0.915, 180.81) after the opposite side cleared. The separate native exit capture records both states.

## Parked camera timing

Each row compares 180 settled post-draw intervals per build. Times are in milliseconds. Counters count frames above the stated budget.

| View | Frame p95 stock → revised | GPU p95 stock → revised | Worst revised | >16.67 ms | >33.3 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| rear-day.png | 7.43 → 6.70 | 3.58 → 5.44 | 8.77 | 0 | 0 |
| rear-night.png | 150.59 → 6.78 | 29.58 → 3.86 | 7.65 | 0 | 0 |
| rear-high.png | 8.44 → 6.95 | 3.91 → 4.11 | 7.50 | 0 | 0 |
| rear-low.png | 9.03 → 7.96 | 3.18 → 3.38 | 8.72 | 0 | 0 |
| quarter-day.png | 6.57 → 6.00 | 2.92 → 3.04 | 7.49 | 0 | 0 |

## Driving trace

The stock F8 recorder ran on the Southworks → Afterhours → Glassline route at 21:30. Two sessions per build each captured an initial pass and a repeat. Both cars reached 130 km/h with full condition. The camera rotates across the same 45 m segment. This reproducible lane-clear fixture disables ambient traffic processing and uses the default pedestrian settings. The first pass follows startup settling. The repeats use the same session. The second pair reverses launch order. The route stops on the first process frame after crossing the same 227 m endpoint. All frames, including any final-interval overshoot, are retained.

| Build and session | Pass | Frames | Distance m | F8 median ms | F8 p95 ms | F8 p99 ms | F8 max ms | F8 >16.67 ms | F8 >33.3 ms | Post-draw max ms | GPU p95 ms | Unfocused |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Stock 1 | first | 412 | 227.13 | 17.59 | 25.00 | 33.84 | 62.86 | 224 | 5 | 60.76 | 6.01 | 0 |
| Stock 1 | repeat | 375 | 227.13 | 19.05 | 31.25 | 37.25 | 48.16 | 236 | 8 | 40.06 | 7.98 | 0 |
| Revised 1 | first | 468 | 227.13 | 14.81 | 21.21 | 25.00 | 26.20 | 152 | 0 | 30.34 | 6.49 | 0 |
| Revised 1 | repeat | 314 | 229.53 | 19.47 | 68.59 | 133.33 | 142.50 | 184 | 25 | 1305.85 | 15.57 | 0 |
| Stock 2 | first | 407 | 227.13 | 18.33 | 24.24 | 31.40 | 51.27 | 258 | 4 | 34.13 | 7.19 | 0 |
| Stock 2 | repeat | 404 | 227.13 | 17.41 | 27.68 | 29.95 | 31.15 | 231 | 0 | 32.43 | 7.92 | 0 |
| Revised 2 | first | 483 | 227.13 | 15.00 | 21.92 | 22.72 | 25.51 | 144 | 0 | 25.75 | 6.40 | 0 |
| Revised 2 | repeat | 461 | 227.13 | 15.28 | 24.24 | 26.48 | 28.21 | 161 | 0 | 28.42 | 6.18 | 0 |

F8 measures the engine process interval. The separate post-draw clock retained the longer wall-clock gaps, including the legacy night still spike and the revised first-session repeat stall. In the slowest revised repeat frames the surface compiler counter stayed at 91 and no completed chunk loads appeared in the F8 rows. The traces establish stalls and their magnitude; they leave the cause unresolved.

The renderer matches the street and pursuit variants' source parts. The performance samples cover one parked vehicle and one lane-clear route. Creator approval, fleet load, weather-linked materials, the complete front coachwork and the full vehicle acceptance matrix remain open.
