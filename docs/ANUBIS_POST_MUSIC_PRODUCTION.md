# Post-music production pilot — #570, #571–575

Run from the **existing** Anubis WSL checkout once the current music command returns. Do not pull while music is running. Use root WSL, mounted Z:, no second clone. The launcher takes the same factory and generation locks as music. Close unrelated GPU tools, Godot editors and games first.

    bash tools/asset_refinement/run_post_music.sh

This only prints the plan. To generate:

    bash tools/asset_refinement/run_post_music.sh --execute

Architecture runs first (four Brickwater profile families B1–B4, dimensions from world_plan.gd, original enclosed wall geometry, openings, roof, PBR, two detail levels). Eight named office cast candidates plus sixteen distinct street, service, dock, club and security-base candidates follow (existing Ara 0.13.0, Node 24/npx required, may use existing npm cache or download the pinned package/data). Candidate outputs use Z:/NightGrid-Afterhours/Visual/Architecture/postmusic-001 and Z:/NightGrid-Afterhours/Characters/postmusic-001. Repeat same command to skip verified outputs; partial character folders are preserved. Street profiles use clothing IDs from the pinned Ara source (src/core/params.ts); role-specific fictional uniform insignia, accessories and real visual variation need native fitting and review. No auto publishing. Existing core/remaining-staff candidates in other directories are not overwritten; compare those first before repeating exports if they are already suitable.

Use --lane buildings or --lane characters for independent retries. --batch postmusic-002 selects a new batch. Building candidates are archetypes, not actual mapped lots, not full furnished interiors, and not yet Blender-sculpted or native reviewed. Upper glazing is deliberately provisional. Existing actual city anchors, collision, doors, UV2 and scene integration remain a Codex task.

Native bake experiment (explicit Windows console executable, NOT headless baker):

    bash tools/asset_refinement/run_post_music.sh --execute --lane lighting --godot '/mnt/c/path/to/Godot_v4.7.2-stable_win64_console.exe'

Or include --godot in the full run to execute all three sequentially. Fresh isolated scratch project under Z:/NightGrid-Afterhours/Visual/Lighting/postmusic-001, containing only reception source inputs. Existing checked-in atlas is deliberately excluded. Editor plugin uses Godot 4.7.2 native Bake Lightmaps button and file_selected dialog signal, not a nonexistent LightmapGI.bake GDScript method. Windows watchdog monitors only spawned Godot PID, stops at 85C or missing telemetry, low space or timeout. Do not interrupt Windows interop by closing WSL; if interrupted inspect the spawned Godot process before running another job. The plugin and automation have not yet been tested on real Anubis; fail closed and preserve logs, retry with a new batch. Native validation and existing fixed-camera baked-vs-realtime capture script must pass before validated-bake.json. No auto integration. High quality first, Ultra comparisons later.

## Codex handoff

Inspect candidate.json for each model, GLBs, source hashes, and lighting project logs/evidence/validated-bake.json if present. Compare against current NAS staff exports and actual in-game visuals; don't replace approved assets blindly. Build a canonical lot inventory from the actual city registry, select a true lot, fit the candidate, refine PBR and shape in Blender, add collision/doors/interior and static UV2; preserve existing road/door/save contracts. For character assets expand roles beyond the twenty-four candidate profiles (street identities, uniforms, musicians, venues, etc.) and test real poses and performance. Do not treat structural validation as art acceptance. For lighting inspect native logs and images, refine editor pilot if it fails, compare High/Ultra, then stage one fixed-interior production bake. Keep dynamic sun/weather/actors and realtime shadows separate. No runtime engine fork, no overwrite of Codex recovery lighting, and no competing GPU jobs.
