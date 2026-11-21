# West Docks — Dock Watch façade/roof pilot

**Evidence:** a real Windows beta `v0.1.0-beta.1` 1600×~900 night screenshot from the player at **West Docks, 22:07**, facing the Dock Watch Desk, with an elevated roadway and two vehicles in the foreground. The image shows a prototype's uniform opaque building panels, visibly pasted-on windows, flat lighting and repeated visual geometry. It has not been added to the repo; it is an attached user playtest screenshot, **not** an after-state render.

## Narrow engineering intervention

The permanent address **Dock Watch Desk** is catalogued by `civic_services.gd` at grid parcel **(-4,-1), lot 0**, in the western edge of Morrow Bay. Preserve it. The rest of the block remains the existing beta artwork.

That one building now uses an already proven **photographic-material architectural construction path** instead of the generic opaque `BoxMesh` façade + thin window cards:

- Existing facade geometry replaced by material-sorted `ArrayMesh` surfaces with actually missing wall geometry at windows, inset glazing and separately backed rooms instead of a flat wall painted blue.
- Reuse the imported **Poly Haven CC0 2K Blue Metal Plate** albedo / tangent-space normal / roughness and scanned **2K bitumen roof** (sources and licenses already in `assets/pbr/polyhaven/SOURCE.json`).
- West-facing lane/side elevation has its own structural panel and recessed-window mesh, and the scanned steel and roof finish closes the four corner returns, rooftop membrane, steel coping and canopy seals.
- All geometry is **visual-only**. The original physical building collider, street coordinates, pavement, civil desk access, game save manifest, world seed, traffic lanes, controls and player exit behavior are unchanged. The Dock Watch storefront sign preserves the civic-site identity.

This is an **incremental reuse of authored mesh topology and scanned PBR**, not a new DCC-produced building model. It does **not** make the surrounding waterfront photoreal and is not grounds for claiming AAA fidelity. The **civic storefront's legacy counter and signage meshes** still sit in front of this facade, as shown in the player's beta screenshot; they need a separate architecturally integrated redesign.

## Why not an entire city generator rewrite?

The screenshot exposes a **systemic asset quality** problem. Blindly replacing all 128px generated façades with a more detailed procedural shader would still produce an oddly regular, uninhabited city. The approved art direction instead calls for genuinely authored glTF kits, photographic materials, believable architectural variation, coherent transit/road geography, appropriate lighting and real Windows capture comparisons. This pilot tests one real address and one reusable material/mesh pipeline without disturbing seeded saves or shipping another unreviewed citywide art pass.

## CI / Windows acceptance

`tests/dock_watch_fidelity_smoke.gd` runs on the real playable scene and checks (1) the exact civic address, (2) one scan-based building in the correct existing parcel, (3) transparent recessed glazing with backing and true side windows, (4) roof/facade mesh families using the imported PBR maps, (5) one original collision shell with no underlying visual cube, (6) unchanged seed and save manifest after streaming reentry.

**Still required before visual approval:** retake the **same West Docks 22:07 Windows Forward+ camera** before/after, one midday frame, and one ground-level facade crop; mark F7 and capture F10 to attach actual frame context. Review car/window silhouettes, rooftop edge, civic-service overlay, frame-time p95/p99 and streamed asset popping. None of these results can be inferred from a headless green CI run. The current beta release does **not** contain this change; a new versioned build will be needed after merging.
