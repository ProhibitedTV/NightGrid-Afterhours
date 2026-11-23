# Kestrel S6 production brief

Revision A · creator review · #210 / #184

The Kestrel is an original Morrow Bay four-seat electric sports fastback. Keep the low, wide stance, deep metallic crimson, inclined windscreen, short tail, and dual-blade lamp signature of the [creator-approved Jade Wash direction](../art/concepts/kestrel_s6/jade_wash_approved_direction.png). Hard cyan reflections should follow convex surfaces. Warm shop light should reveal the graphite duct geometry and tinted cabin. The body stampings should read in daylight, with the lamps off.

The [original dimensional study](../art/concepts/kestrel_s6/dimensional_study.svg) proposes the package and cutlines. The [creator's gameplay baseline](../art/references/kestrel_s6/jade_wash_gameplay_baseline.png) records the visual gap that prompted this pass. The direction image was supplied in the November 23, 2026 conversation. The gameplay baseline is the creator's supplied frame and its build SHA is unknown. Both originals are committed for review. The specific shapes on the dimensional study and the fit of the glTF candidate await creator approval.

| Creator-supplied reference | SHA-256 |
| --- | --- |
| Approved direction, `1000000622.png` | `cfb3ca8338a7b34aff3bafe41cefbf7348e295cd3421cdc0c0ae7071e07da119` |
| Gameplay baseline, `1000000621.png` | `b9d6c3ecc8dffd2e32442cd80191e96a8c558333c6d6872664ac35deeacda9f6` |

## Package

| Datum | Current main at `3ec2af18` | Production proposal for review |
| --- | --- | --- |
| Body and axle coordinate system | Body-local metres, +Y up, −Z forward. Body origin at vehicle collision center. | Same coordinate system and origin. Export child nodes at scale 1. |
| Length and width | Physics envelope 4.70 × 2.35 m. Loft has a 4.63 m cap-to-cap length and 2.34 m maximum width. Mirrors are outside the envelope. | 4.70 m body length, up to 2.35 m over the rear quarters, 2.27 m at the front fenders. Review flare width against the full tire sweep before signing off. |
| Axles | Front Z −1.48 m and rear Z +1.49 m. Wheelbase 2.97 m. Wheel centers X ±1.10 m, Y −0.43 m. | Preserve both axles and steering origins. Draft 0.87 m front and 0.86 m rear overhangs. |
| Tires | Radius 0.41 m. Tread mesh width 0.27 m. The parked tire outer width is about 2.47 m before steering. | Keep the current tire and swept envelope for the first component. Resolve the visible poke with the wheel and fender pair in #215. |
| Collision and ground | 2.35 × 1.65 × 4.70 m box, vehicle movement and camera collision owned by the live controller. The visual tire ground datum is Y −0.84 m. Legacy canopy roof is Y +1.245 m. | Roof study 1.46 m above tread contact, sill about 0.18 m above tread contact. Lower roof requires a driver's eye, seated head clearance and rear occupant fit study before adoption. |
| Glass and seating | Windscreen foot near Z −1.30 m, old roof edge near Z −0.82 m. Four silhouette seats; controls and entry are part of the normal car. | Keep A-pillar foot and seat anchors registered to the chassis. Final canopy and hip-point dimensions depend on occupied clearance and camera checks in #212. |

The sketch describes the whole-car intent. The first glTF is fitted to current main's chassis length, original lower fascia and existing headlamp locations. Its cover spans roughly 2.05 m, with a 4 mm wall and a 0.23 m maximum duct package depth. Its local bounds and semantic socket translations can be inspected in the [source manifest](../../assets/models/nightgrid/kestrel_s6_front/source.json).

## Assembly and surface direction

- Make the bonnet a stamped and hemmed panel with a slight central bulge and two folds that flow into the lamp brow. The under-hood tray and a real open duct must back each planned extraction slot. Place hood releases and hinges behind the visible cutlines.
- Give the two front fenders a curved shoulder, closed returns at the doors and a separate inner wheel liner. The doors have a framed skin, a lower sill crease, a recessed handle and a continuous weather strip. Give the fastback roof a continuous painted rail and bonded glass border.
- Use a replaceable polymer front cover over an enclosed crash structure. The center opening feeds the heat exchanger and the side openings feed the front wheel ducts. Fit a removable mesh insert and undertray lip into the same housing. Mount the license plate at the brow and leave service access to the tow eye. Keep the side duct openings visible from a street-eye camera.
- Fit the rear quarter panels to a closed rear deck and cabin bulkhead. Shape depth around the light sockets and hatch opening before adding lens materials. Use a closed lower diffuser, with plausible drain and service channels. #31 remains the native rear-body acceptance gate.
- Use a deep red tinted basecoat, neutral clearcoat, restrained micro-normal, muted black polymer ducts and a satin grille. The candidate bakes original tangent-space microtexture and records the portable glTF clearcoat values. The Godot review fixture binds `crimson_finish.tres` to the named paint surface to hold clearcoat and normal import settings constant. Production paint should get a dedicated mask/roughness atlas and shared weather-film integration after main has the owning weather inputs. Prefer existing SSR and scene lighting. Current main's sky weather presets do not establish a car wetness signal.
- Preserve the police bar, existing beam and lamp states, seats, actor/camera transform, saves and traffic mounting contract. A shared police fascia requires a separate pushbar fit check. Automatic fleet replacement remains subject to art and integration approval.

## First component and review

`tools/author_kestrel_fascia.py` bakes the near and reduced LODs offline without external assets or runtime downloads. Geometry is wholly original. The UV-mapped upper cover, hole walls, shaped return ducts, recessed grille bars, core fins and lower tray are separate surfaces in one assembly. Empty nodes carry mounting, tray, cooling and tow-eye datums. The LODs preserve every opening and socket. The near asset budget is 3,200 triangles with five surfaces and one 128² normal. The reduced asset budget is 1,350 triangles. Keep the part attached to the original visual root; it adds no collision shape or lights.

`tools/review_kestrel_fascia.gd` stages the same stock Kestrel and candidate at one Jade Wash mark in the real game renderer. It keeps the original greenhouse, headlamps and rear. It hides the stock splitter and old visible nose cap only for the candidate capture. The review fixture leaves the default player and fleet visuals in place. Current main supports a weather sky choice and authored damp alley material; a matched wetness simulation is outside this first component.

Run `python tools/author_kestrel_fascia.py` and `python tools/check_kestrel_fascia.py` using Python 3.11 or newer. For the native review, set `NIGHTGRID_KESTREL_REVIEW_DIR` to a new absolute directory and `NIGHTGRID_SOURCE_REVISION` to the build SHA. Launch the source project or exported PCK with Godot 4.7.2 using `--rendering-method forward_plus --rendering-driver vulkan --resolution 1920x1080 --script res://tools/review_kestrel_fascia.gd`.

Creator review should focus on the bumper crown in noon and neon, intake balance, the flatter red bar above the grille and how the side returns meet the fenders. The next component is the bonnet and front fender interface, including hood seam datums and the real apertures for the future lamp housing. The rear closure, cabin, production lamps, wheels, wetness and full native performance gate remain on #211–#217.
