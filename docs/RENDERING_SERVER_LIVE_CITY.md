# November 2026: fewer city nodes, physically anchored practical lighting

## Source material and what it actually teaches

The user shared [Firebelley Games — “Stop Using Nodes for Everything in Godot”](https://www.youtube.com/watch?v=1PnG3r1rKcs) (April 13, 2026). The [video's public description](https://www.youtube.com/watch?v=1PnG3r1rKcs) says its developer draws 100+ Alchemortis items within one frame using **RenderingServer**, avoiding expensive per-object scene nodes.

This is chiefly a **CPU-side object creation and lifecycle** optimization. It is **NOT** a photorealism or shading tutorial. The preceding [Coding Quests tutorial](https://www.youtube.com/watch?v=0792U-wuwjA) was about sky ambient lighting, tone mapping, shadows, haze and material presentation. The screenshot evidence is three **real beta.4 Windows Forward+/Vulkan frames at Vesper Market, 19:34**: Filmic has readable ground and flat light; ACES is substantially darker and loses local vehicle/pavement detail; AgX contains highlights better but the physical roads and shopfronts remain unlit. These captures have slightly different camera positions; they are **qualitative comparisons, not pixel-perfect A/B evidence**.

Godot's official [Optimization using Servers](https://docs.godotengine.org/en/4.7/tutorials/performance/using_servers.html) explains the direct server approach and its explicit lifetime ownership. We use `RenderingServer.instance_create`, `instance_set_base`, `instance_set_scenario`, `instance_geometry_set_material_override`, and `free_rid` for Godot 4.7.2 **3D** static visuals. Godot's scene-tree `Node3D` remains the correct abstraction for collisions, player vehicles, UI, signs and scripted interactions.

## Real repo changes

### 1. Static city visual batches avoid one scene node per material bucket

Previously `CityDetails._flush_instance_key` created a new `MultiMeshInstance3D` node **for every material/color/spatial bucket** in the streamed city and the globally painted roadway. It was batched on the GPU already, but still allocated and attached many scene nodes, concentrated during the same frame that finished a chunk.

Now `scripts/render_batch_owner.gd` is **one lightweight owner per completed/staged city chunk**, plus one global owner for road paint. Each of the **same spatially grouped MultiMesh resources** gets a raw RenderingServer instance with the original material and world transform. The owner retains the MultiMesh and material to keep their RIDs alive, and frees all visual instance RIDs from `_exit_tree`. A cancelled staged request, an unloaded far block and scene teardown all use the **same existing `queue_free`** path. Collision shells, authored recessed-window façades, mesh coordinates, labels and v1 save/seed manifest are unchanged.

This avoids the corresponding per-batch **scene nodes**; it does **not** magically reduce the number of draw calls per material or remove the need for authored geometry. The already existing `MultiMesh` batches are **preserved** rather than replaced with tens of thousands of new individual draw calls.

New on-demand `get_render_batch_stats()` returns active RID batch count, one-owner-per-chunk count and live detail instance count. This is sampled for **F7 markers and F10 evidence only**, not every frame. Continuous `get_streaming_stats()` also identifies the renderer and count of cumulative batches created.

### 2. The screenshot's nighttime lighting mismatch is fixed at its source

The old `NightLighting` pooled eight shadow-free `OmniLight3D` nodes, but positioned them on an arbitrary **`ix*58+8.9, iz*58+8.9` grid**, instead of the physical lamp heads in `CityDetails._lamp`. A glowing cap could therefore have **no nearby light on the ground**, like the player's three Vesper Market screenshots.

Now **four** of the eight shared nodes are selected from the actual poles produced by `_build_intersections` (only even-parity intersections), at the actual emitting cap **`(ix*58-9.98, 6.76, iz*58-8.6)`**. The remaining **four** are leased to the nearest actually existing normal-lot shop canopy/sign positions, using immutable world-plan coordinates and warm/cool district-appropriate colour. This puts a **real pool of light near storefront entrances and sidewalks**, without adding hundreds of nodes, lighting invisible buildings or altering the saved city.

Each of the eight lights remains **shadow-free**, local, range-limited (pole **18m**, shop **11.5m**) and disabled entirely during daylight. Selection is refreshed approximately every **0.45s**; existing fixed-focus controls and day/night fade are retained.

### 3. Regression and field measurement

New `tests/render_server_city_smoke.gd` asserts global/staged scene-tree batching, one retained resource for every RID, original physical colliders, complete chunk lifetime cleanup, and identical world and visual instance counts after streaming unload/reload.

New `tests/practical_lighting_smoke.gd` asserts **every** light maps to a real generated pole head or existing lot sign, max eight active unshadowed lights, both active shop/pole groups at night, and full daytime disable. Original tests for 60Hz physics, F7/F8/F10, transit, police, shop access and save persistence remain mandatory.

Both tests run in the Godot 4.7.2 `Project preflight` and Windows x64 export runs, but **CI doesn't benchmark Windows Vulkan or inspect real emitted lighting**. Future tests should collect player F10 pairs and F8 cold/warm traces.

## Windows 1080p/60 quality gate

On **tagged beta.5** (the original beta.4 does not contain these changes), return to Vesper Market **19:34** near the `DOCK 9` / `LAST SHIFT` storefronts. Freeze clock using Y, take F10 in Filmic, F11 for ACES/F10, F11 for AgX/F10, without moving between the frames. In each mode inspect road reflection under the lamp, illumination on street-level brick and shopfronts, player car silhouette, and headlight/screen-space artifacts. F7 creates an immediate log marker (including server visual counts and active light allocation). Drive across multiple district chunk boundaries with F8 enabled and compare p95/p99 frame intervals and streaming stage times against beta.4.

**Honest limits:** The older boxy cars, repeated opaque walls, overly wide roads and uninhabited buildings in the screenshots are still **asset-art defects** tracked in [#51](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/51). Direct RenderingServer calls and eight physically grounded light sources will not turn generic geometry into AAA quality. The desired next art pass is original UV-unwrapped licensed glTF streetscape and believable vehicles—not more primitive box detail.
