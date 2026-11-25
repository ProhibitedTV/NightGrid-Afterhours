# Codex handoff — Brickwater gold slice (#156)

Work on `art/brickwater-gold-slice`, **not main**. PR #156 stacks on #154/#143 and contains the pinned asset tree from #153 via merge ancestry. Check latest HEAD and concurrent branches before edits. Preserve AGENTS.md and docs/APPROVED_WORLD_FIDELITY_TARGET.md. Read docs/BRICKWATER_GOLD_SLICE.md for the cumulative implementation. Concept reference is not a gameplay image; original concept may need user-provided binary. Do not commit synthetic screenshots.

## Confirmed at handoff preparation
- 793df00 architecture: actual Brickwater geometry test and Windows export passed; outdated ordinary masonry regression failed.
- f24046a corrected masonry contract and wet shader: Windows export + Brickwater and masonry smoke passed (run 44968603582, job 137043155756); full suite was still running.
- e15eb99 overhead: Windows export passed; full tests not verified at preparation.
- efa42d3 signs/night windows: structure passed; native rendering and latest tests not yet verified. Never treat a prior build as proof of current HEAD.

## First Codex task: get real visual evidence before expanding
1. Fetch branch, inspect current CI and fix any actual errors (particularly shader compilation, imported glass material names, steel/cable clearances). Run focused QA, then full preflight.
2. Import Godot 4.7.2 project. Run the capture harness at 1920x1080 Windows Forward+ Vulkan with separate output folders for baseline 78442f9 and candidate (copy same harness to baseline). See docs/BRICKWATER_GOLD_SLICE.md. Capture manifests, raw PNGs and hashes. Linux software Compatibility captures are diagnostic only. Native GPU counters/F8 during real traversal, not frozen scene, on RTX 3060 12GB class hardware.
3. Look at actual frames: check aperture orientation, glass visibility, masonry seams, fire escape support/rail/stair joints, cable mounts (must attach to actual masonry, not window glass), signage legibility, puddle response, sidewalk/foot/vehicle clearance, casting, no z-fighting or duplicate old silhouettes. Fix issues before more features. Compare at identical camera/lens/time.
4. Next creative work: replace generic street-facing storefronts around the alley mouth with authored storefront geometry and plausible closed/enterable status, integrate visible interiors and logical address/door anchors. Work within stable saved lot shapes, avoid inventing new navigation exits. Add restrained local steam/haze only after native GPU measurements, not a global fog change.
5. Then improve actual protagonist silhouette/clothing/animation (#132) and neighboring street depth; keep art passes scoped and measurable.

No auto-merge or release promotion until visual reviews and full regression are complete. See #134, #144–#152. Keep capture and implementation branches distinct from HUD PR #155 and the parallel gallery effort. Goal: approved composition, not merely additional meshes or green CI. 
