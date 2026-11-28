# Post-music production pilot — #570, #571–575

Run from the **existing** Anubis WSL checkout once the current music command returns. Do not pull while music is running. Use root WSL, mounted Z:, no second clone. The launcher takes the same factory and generation locks as music. Close unrelated GPU tools, Godot editors and games first.

    bash tools/asset_refinement/run_post_music.sh

This only prints the plan. To generate:

    bash tools/asset_refinement/run_post_music.sh --execute

Architecture runs first (four Brickwater profile families B1–B4, dimensions from world_plan.gd, original enclosed wall geometry, openings, roof, PBR, two detail levels). Eight named office cast candidates plus sixteen distinct street, service, dock, club and security-base candidates follow (existing Ara 0.13.0, Node 24/npx required, may use existing npm cache or download the pinned package/data). Candidate outputs use Z:/NightGrid-Afterhours/Visual/Architecture/postmusic-001 and Z:/NightGrid-Afterhours/Characters/postmusic-001. Repeat same command to skip verified outputs; partial character folders are preserved. Street profiles use clothing IDs from the pinned Ara source (src/core/params.ts); role-specific fictional uniform insignia, accessories and real visual variation need native fitting and review. No auto publishing. Existing core/remaining-staff candidates in other directories are not overwritten; a uniquely hash-verified exact-profile candidate with the required clips is reused from sibling batches when available. Conflicting or outdated candidates remain untouched.

Use --lane buildings or --lane characters for independent retries. --batch postmusic-002 selects a new batch. Building candidates are archetypes, not actual mapped lots, not full furnished interiors, and not yet Blender-sculpted or native reviewed. Upper glazing is deliberately provisional. Existing actual city anchors, collision, doors, UV2 and scene integration remain a Codex task.

Native bake experiment (explicit Windows console executable, NOT headless baker):

    bash tools/asset_refinement/run_post_music.sh --execute --lane lighting --godot '/mnt/c/path/to/Godot_v4.7.2-stable_win64_console.exe'

The default `reception` profile stages the established pilot. Use `--lighting-profile synaxis-ground` to stage the actual playable envelope with its seven authored probe positions. Both profiles verify source dependencies in a fresh NAS project. They exclude the existing atlas and let the native editor bake after both scanning and importing settle. The WSL launcher retains the production locks throughout the foreground run. The Windows watchdog retains the spawned process handle and stops that process on timeout, low disk space, missing thermal telemetry or an 85 °C reading.

On Anubis, `postmusic-004` completed the isolated reception bake and native witness comparison on the RTX 3060. The supervisor writes `validated-bake.json` only after the independent UV2 and directional-atlas checks and the fixed-camera comparison pass. Review the results before replacing the live atlas. Run the playable export separately to check room transitions, actors and direct shadows.

The `postmusic-synaxis-ground-002` run produced a fresh directionally baked envelope and validated 11 mesh bindings and seven authored probes. The independent capture still found zero indirect lift at the reception return when the witness was isolated from the direct spotlight. This candidate remains at the review gate. The playable calibrated atlas stays in use while the return area needs a better-motivated fixture contribution or probe placement.

For the finished batch, point the existing native reviewer at the candidate root:

    godot --path <review-project> --resolution 1920x1080 --rendering-method forward_plus --rendering-driver vulkan --script res://tools/asset_refinement/validate_character.gd -- --batch <NAS-candidate-root> <new-evidence-directory>

The reviewer checks each manifest hash and captures every named animation in the same scene setup. It preserves single-model mode. The geometry validator also accepts a second argument for a new 1080p architecture PNG. These reviews leave the NAS sources and approval records intact.

## Codex handoff

Inspect candidate.json for each model, GLBs, source hashes, and lighting project logs/evidence/validated-bake.json if present. Compare against current NAS staff exports and actual in-game visuals; don't replace approved assets blindly. Build a canonical lot inventory from the actual city registry, select a true lot, fit the candidate, refine PBR and shape in Blender, add collision/doors/interior and static UV2; preserve existing road/door/save contracts. For character assets expand roles beyond the twenty-four candidate profiles (street identities, uniforms, musicians, venues, etc.) and test real poses and performance. Do not treat structural validation as art acceptance. For lighting inspect native logs and images, refine editor pilot if it fails, compare High/Ultra, then stage one fixed-interior production bake. Keep dynamic sun/weather/actors and realtime shadows separate. No runtime engine fork, no overwrite of Codex recovery lighting, and no competing GPU jobs.
