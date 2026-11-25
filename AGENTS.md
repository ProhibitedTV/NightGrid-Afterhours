# NightGrid: Afterhours — repository development guidance

## Approved November 20, 2026 visual direction (mandatory)

The user explicitly approved a **photorealistic, AAA-fidelity cyberpunk open-world *environment*** reference (the neon coastal boulevard image uploaded in the design conversation, filename `image(20261120-150334).png`). The game should **not** target a low-poly, box-mesh or cartoon city. Read [the approved world target](docs/APPROVED_WORLD_FIDELITY_TARGET.md) before changing visual art or creating asset PRs. The **image itself has not yet been committed** to GitHub; the written spec records its appearance and the user's decision.

Build original Morrow Bay identity, not copyrighted GTA assets. The visual target is photoreal urban geometry, physically plausible roads and elevated infrastructure, believable proportions, distinctive high-density shop architecture, properly licensed and UV-unwrapped PBR material maps, realistic wet-surface/reflection response and controlled practical neon lighting. **The world is the primary subject**; do not drift into promotional character portraits to demonstrate world quality.

### Art workflow rules

- Do not submit more `BoxMesh` facades, primitive NPCs, added procedural rectangles or emission-only accents as an **AAA upgrade**. They are acceptable for prototype collisions and debug blockouts **only if clearly labeled**.
- Prioritize one **complete place** at a time. Start with a real existing Morrow Bay location, preserve established intersection geometry, permanent addresses, pathing, transport physics and seeded save persistence.
- Use authored DCC models (glTF) with sensible LODs/UVs, licensed textures, normals and PBR roughness/metalness. Keep materials, sources, licensing and import settings in the repository.
- Require side-by-side **real Godot Forward+/Vulkan screenshots** from a repeatable camera/clock plus GPU performance observations before claiming a successful visual redesign. An image generator result, original vector illustration and a green headless test are **not** proof of implemented visual fidelity.
- Do not replace documented **actual in-game** README screenshots with concept art. Label concepts clearly, keep a separate art reference gallery, and avoid unverified performance or AAA-quality claims.
- For technical changes, keep existing scene entrance/exit, camera collision, traffic cycles, gameplay interactions, player controls and v1 save compatibility. Add regression tests for layout, reachability, save/load and geometry changes, and check Windows export.
- If a planned scene would undermine frame rate on a 12 GB RTX 3060, propose real quality tiers and spatial streaming; keep the ambitious visual direction rather than silently reverting to cartoon style.

## Existing code quality and known blockers

Many early systems are functional but **visually provisional**. Read [first-playtest triage](docs/PLAYTEST_TRIAGE_2026_11_20.md) and open art issues [#19](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/19), [#20](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/20) and [#21](https://github.com/ProhibitedTV/NightGrid-Afterhours/issues/21). The previous stylized Central Exchange concept in closed PR #23 **was rejected as a fidelity reference**.

**Success criterion:** the user's next Windows playtest recognizably approaches the approved world image in visible geometry, lighting, scale, architecture and material realism, **while remaining a functional game**.

## Audio production contract (mandatory for new gameplay)

Use the [Anubis offline audio studio](docs/AUDIO_PRODUCTION_STUDIO.md) for new authored speech, NPC dialogue choices, environmental sound effects and ambience. New missions, venues, characters and interactions must identify their audible events and either extend the existing production catalogs or explicitly document an existing licensed sound/reuse or a temporary caption-only fallback. Do not create an unrelated generator for each gameplay feature.

- Assign durable line/cue IDs and original character identities. Bind spoken text and localized captions to the canonical gameplay source; do not reuse a published ID for changed speech without regenerating and reviewing it. Record trigger, spatial/room context, priority, loop/one-shot behavior and fallback. Keep optional dialogue routes in coverage planning, not only the main quest.
- Generate on the development workstation, using the Anubis full, character, group or individual-asset commands. Preserve locked synthetic cast references and exact model revisions, source/output rights and generation settings. Never use real-person voice imitation without permission; do not assume a code license covers model weights or outputs.
- Keep candidates, model caches and Python environments outside the shipped asset library. Publish only individually reviewed recordings with hash-bound metadata; use the speech QC and SFX verification commands. No unattended approval or silent replacement of accepted assets.
- Use the existing bounded game audio/mix interfaces, prewarm where appropriate, and retain captions when clips are missing or muted. No inference, model download, per-frame disk IO or network dependency during gameplay. Respect the independent audio controls, existing licensed music, pause/skip/cancel and streaming lifecycles.
- Add tests for actual cue triggers and asset parity; report missing recordings as pending rather than marking the feature voiced. Run strict chapter coverage before claiming a voiced release and verify native Windows audio, frame pacing and resource use. A green CPU authoring test is not evidence of neural synthesis or native audio fidelity.

