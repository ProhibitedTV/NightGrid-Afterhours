# Morrow Bay — archived 33-frame development gallery

**NightGrid: Afterhours | November 21 development archive — visual review pending**

Walk the streets after dark, see the city in daylight, explore local businesses and ride public transit.

[Download the Windows beta](https://github.com/ProhibitedTV/NightGrid-Afterhours/releases) · [Playtest guide](../../PLAYTEST_CHECKLIST.md) · [Send feedback](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/new) · [Back to project](../../../README.md)

These original PNG blobs were preserved from [PR #127](https://github.com/ProhibitedTV/NightGrid-Afterhours/pull/127) at commit `cf4bd97ebbac94af5f8cf740058c5318cd4f65b6`. The recorded capture revision is `f6dd913713d3534b439fca4bae1aef2c63ee065b`. All 33 GitHub file sizes match the manifest and all recorded hashes are distinct. Pixel-level visual acceptance remains pending; this is an archive, not a current-main showcase or release approval. Some shots use staged camera positions, time of day and vehicles for composition; the gameplay-camera shots show the regular HUD. Linux Mesa OpenGL Compatibility at 1280×720 is not the native Windows Vulkan renderer or a performance benchmark. Development screenshots can be newer than the released beta.

**Explore the gallery:** [City streets](#city-streets-and-neighborhoods) · [Nightlife and businesses](#after-dark-and-neighborhood-businesses) · [Interiors](#inside-morrow-bay) · [Transit and vehicles](#public-transit-and-vehicles) · [Gameplay](#playing-afterhours)

Select any screenshot to inspect it at full resolution.

## City streets and neighborhoods

| **Central Exchange at night** | **Central Exchange in daylight** |
|:--:|:--:|
| ![Central Exchange at night](01-morrow-bay-neon-night.png) | ![Central Exchange in daylight](10-central-exchange-daylight.png) |

| **Moon Noodles at night** | **Brickwater brick and street architecture** |
|:--:|:--:|
| ![Moon Noodles at night](02-vesper-market-nightlife.png) | ![Brickwater brick and street architecture](11-brickwater-streetfront.png) |

| **Afterhours illuminated steel storefront** | **Horizon Commons in daylight** |
|:--:|:--:|
| ![Afterhours illuminated steel storefront](12-afterhours-streetfront.png) | ![Horizon Commons in daylight](04-horizon-commons-daylight.png) |

| **North Quay Exchange** | **Pier Nine Depot, West Docks** |
|:--:|:--:|
| ![North Quay Exchange](13-north-quay-exchange.png) | ![Pier Nine Depot, West Docks](14-pier-nine-depot.png) |

| **Southworks Hall** | **Helix Espresso in Glassline** |
|:--:|:--:|
| ![Southworks Hall](15-southworks-hall.png) | ![Helix Espresso in Glassline](21-helix-espresso.png) |

## After dark and neighborhood businesses

| **Lantern Cup café, Vesper Market** | **Prism Club, Glassline** |
|:--:|:--:|
| ![Lantern Cup café, Vesper Market](16-lantern-cup-exterior.png) | ![Prism Club, Glassline](17-prism-club-exterior.png) |

| **Static Room, Afterhours** | **Dock Nine Social, Brickwater** |
|:--:|:--:|
| ![Static Room, Afterhours](18-static-room-exterior.png) | ![Dock Nine Social, Brickwater](19-dock-nine-social.png) |

| **Blue Hour nightclub** | **Neon Bao street food** |
|:--:|:--:|
| ![Blue Hour nightclub](20-blue-hour-exterior.png) | ![Neon Bao street food](22-neon-bao-streetfood.png) |

| **Crane & Gear, West Docks** | **Morrow Bay Police Department** |
|:--:|:--:|
| ![Crane & Gear, West Docks](23-crane-and-gear.png) | ![Morrow Bay Police Department](24-mbpd-dispatch-exterior.png) |

| **Eastside Fire 4, Horizon Gardens** |   |
|:--:|:--:|
| ![Eastside Fire 4, Horizon Gardens](25-eastside-fire.png) |   |

## Inside Morrow Bay

| **Inside Quay Fresh** | **Inside Lantern Cup** |
|:--:|:--:|
| ![Inside Quay Fresh](05-quay-fresh-interior.png) | ![Inside Lantern Cup](28-lantern-cup-interior.png) |

| **Inside Prism Club** | **Inside Static Room** |
|:--:|:--:|
| ![Inside Prism Club](29-prism-club-interior.png) | ![Inside Static Room](30-static-room-interior.png) |

| **Inside the MBPD dispatch center** | **Inside Horizon Health** |
|:--:|:--:|
| ![Inside the MBPD dispatch center](31-mbpd-dispatch-interior.png) | ![Inside Horizon Health](32-horizon-health-interior.png) |

| **Inside Crane & Gear** |   |
|:--:|:--:|
| ![Inside Crane & Gear](33-crane-and-gear-interior.png) |   |

## Public transit and vehicles

| **M-Line rail at Helix Terminal** | **City bus — staged vehicle portrait** |
|:--:|:--:|
| ![M-Line rail at Helix Terminal](03-m-line-helix-terminal.png) | ![City bus — staged vehicle portrait](08-city-bus-coachwork.png) |

| **Civilian sedan — staged vehicle portrait** |   |
|:--:|:--:|
| ![Civilian sedan — staged vehicle portrait](09-civilian-sedan-coachwork.png) |   |

## Playing Afterhours

| **Courier on foot, normal player camera** | **Vesper Market with gameplay HUD** |
|:--:|:--:|
| ![Courier on foot, normal player camera](26-courier-street-view.png) | ![Vesper Market with gameplay HUD](27-vesper-player-view.png) |

| **Title screen** | **City map** |
|:--:|:--:|
| ![Title screen](06-title-menu.png) | ![City map](07-city-map-menu.png) |

[Capture method](../README.md) · [Source revision, renderer and image checksums](capture-manifest.json)

## Local visual review

Install Pillow if needed and run `python tools/review_screenshot_gallery.py` from the repository root. It verifies the 33 original hashes before producing review-only contact sheets and a checklist in `exports/gallery-review`. The originals are never modified. CI additionally checks the archive's Git blob identities, hashes, manifest and gallery links. Contact sheets are not replacements for the original captures or visual acceptance.

## Repeat the historical camera set on current main

The separate `Capture expanded gameplay review (artifact only)` manually dispatched workflow runs the 33-camera harness against a selected revision, verifies file set and hashes, and uploads a review artifact. It never pushes or overwrites the historical or native showcase gallery. For native Godot review, set `NIGHTGRID_EXPANDED_CAPTURE_DIR` to a new absolute directory, `NIGHTGRID_SOURCE_REVISION` to the checked-out commit, then run `godot --path . --rendering-method forward_plus --rendering-driver vulkan --resolution 1920x1080 --script res://tools/capture_expanded_gallery.gd`. The capture harness uses staged camera/actor positions, not performance measurements. Newly captured frames require visual acceptance; the historical archive stays unchanged. The updated harness has not yet completed a graphical capture.
