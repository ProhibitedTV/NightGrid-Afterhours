# MARA — fifth hero asset: first character benchmark

**Mara** is an original fictional café operator at Lantern Cup in Vesper Market. This vertical slice replaces her generic three-box contact mannequin with an identifiable, animated character constructed *inside the real enterable room*. It sets a reusable art, dialogue and performance standard for other Morrow Bay NPCs.

## Visual character language

Mara wears a tailored graphite/teal café utility jacket with rolled cuffs, a leather work apron with cross-body straps, an illuminated name badge, boots and a pen on her waist. Her dark swept hair has a sharp side lock and copper clip; her face includes a sculpted tapered jaw/forehead/cheek loft, separately modelled ears, eyeballs and irises, pupils and catchlights, upper lids, brows, freckles, nose bridge/tip and animated mouth. Her service headset is a small non-light-emitting prop. Colour and roughness are chosen by surface type: diffuse skin, matte fabric, worn leather, copper hardware, varied hair roughness and glossy eyes. Geometry is generated once when her actual café interior loads; no external art, animation files, fonts or recordings are imported.

## Built and used in gameplay

The rig has separate pivots for hips/legs, breathing upper body, expressive head, left and right arms. Fixed-geometry animations are intentionally lightweight and distinct: breathing/weight-shift idle; paired eye-blinks and head look toward the real player while talking; lip motion while speaking; and a serving-arm gesture triggered by a **successful** paid coffee order. An injured player's greeting, police attention, discovered shift notes, and active courier side job influence the dialogue lines.

Enter the existing Lantern Cup at its permanent address using **H**, walk up to the counter and press **G**, then choose **3** (keyboard) or **Y** (controller) to **Talk to Mara**. The button only appears in this interior. Four authored conversation subjects cycle with each press: **night shift**, **Vesper Market**, **shift notes**, and **neighborhood work**. All are deterministic and use existing real gameplay state; they are not uncontrolled or dynamically generated text. The service and job buttons remain 1/A and 2/X.

Her opening greeting appears automatically in the same venue panel. **Speaking is free**, including after business hours, and does not change money, quest or inventory. A real successful $18 coffee purchase continues to restore 20 health when needed and triggers the serving gesture; failed purchases do not. The shift note remains inspectable at the rear booth and Mara acknowledges it once discovered.

## Save, lifecycle and performance contract

The actual **v1 JSON save schema is unchanged**. The rumor flag was already persisted in `civic_intel`; new dialogue topics/animation frames are transient, and reset naturally upon closing/reentering the venue. The character is reconstructed from stable venue ID on an indoor F9 load. Exiting with **H** frees Mara with the café; other cafes and all civic interiors retain their generic contact. No second NPC is installed behind the counter, and no new movement/navmesh collision bodies are created.

Mara uses reused materials, one custom lofted body mesh and one face/hair loft each, low-sided limb cylinders and facial ellipsoids. There are **zero real-time character lights**. Rig motion only updates transforms on one active NPC. This is not proof of 1080p/60 or a final production-scanned human; actual RTX 3060 GPU captures and frametime measurements are still required.

## QA

The new `tests/mara_character_smoke.gd` boots the actual live Godot game and checks the unique rig, face/uniform/hair detailing, correct counter location, context-aware dialogue, keyboard/controller menu action, no-cost talk, responsive head/eyes, purchase-driven gesture, saved rumor and cash, reconstruction after save/load, unload on exit and no leakage into other business types. It runs with existing preflight, venues, interiors and Windows build.

**Visual acceptance:** inspect from service counter and side window at 6AM, noon and closing; confirm Mara is **behind** the bar, no floating pieces or doubled silhouette, head/eye geometry correctly aligned, brows and hands plausible in 3/4 view, apron follows breathing without clipping the counter, expression readable at 2–4m, and color values look human under both practical café lights. Performance-test multiple future NPCs before broad reuse.

**Remaining AAA art:** sculpted high-resolution head/body, UV-authored PBR skin/cloth/hair, individual fingers/cloth physics, blink-safe iris/eyelid rig, authored mocap and talking facial blendshapes, production voice/foley, and real visual iteration. The procedural representation is a substantially improved playable **hero-quality blockout**, not a finished hyperreal character. No fabricated new in-engine screenshots were committed.

## Next quality target

Use this rig as a starting specification for **ambient café customers**: seated and standing AI agents with varied procedural appearance, stable save-related identities, usable chair anchors and runtime animation budgets. That should be accompanied by true photometric screenshots and profiling before expanding citywide.
