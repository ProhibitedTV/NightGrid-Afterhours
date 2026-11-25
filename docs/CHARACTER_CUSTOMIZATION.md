# Character customization: San Andreas milestone

## Delivery stack
1. Threadline physical store: fixed address, walk-in checkout, persistent USD/BTC ownership before housing. Initial 9 full colorways (default free).
2. Fitting and independent slots: live avatar preview, cancel/close restores committed look; 3 jackets and 3 trousers purchasable separately, mix with owned base outfits; optional backward-compatible save fields. This revision implements material-level slots only.
3. Garment geometry: inspect pinned Ara/MakeHuman assets and author separate shirt, jacket, trousers and shoe donor meshes. Validate skeleton hierarchy/rest transforms, joint maps, coverage and clipping across idle, gait, seated driving, combat and all wardrobe combinations. Never replace the active animation controller. Bake reusable UV/PBR assets offline, record source/license/hash; no runtime generation. Add true per-slot asset IDs after visual acceptance.
4. Accessories: hats, glasses, watches, earrings and bags; validate bone attachment transforms, body/hat/hair overlap, hand/equipment conflict and seated camera. Add removable default per slot and optional appearance previews.
5. Retail UX: dedicated category tabs, full-body orbit and details zoom, color/size cards, preview comparison, fitting room lighting and clerk animations; keyboard/mouse/controller parity, no hidden purchases, outfit restore on every exit. Add favorite looks and owned-only home wardrobe.
6. District fashion: Threadline value streetwear (Vesper), Quay Standard workwear (North Quay), Vesper Line tailoring and Nocturne/Obscura boutiques (Glassline/Afterhours). Fixed physical stores, own signage, stock lists, staff and soundscape; no pay-to-win or real currency. Economy balance against gig income and rent.
7. Acceptance: old save defaults, duplicate/insufficient payment rejection, corrupt or unowned slot rejection, preview cancel/exit/reload, outfit and piece persistence, no clipped animation, native screenshots, frame traces and controller test. No claim of full mesh customization until native visual evidence.

## Initial separate pieces
Ash, Oxide, Midnight jackets; Charcoal, Sand, Deep Teal cargo trousers. Catalog prices are fictional 2036 inflation-adjusted. A selected full outfit clears independent overrides; selecting individual pieces modifies only its slot. Ownership and equipped state are separate. No unapproved cosmetic becomes permanently equipped by preview. Asset cache is bounded by catalog and source material count, not combination count.

## Accessory pilot
Four original geometry pieces: smoke shades, clear frames, digital watch and brass watch. Cached bone-attached meshes follow Head and LeftHand, with wrist direction derived from the rig rest pose. No collisions or extra skeletons. Free reset entries restore the base jacket/pants or remove glasses/watch independently; owned items remain in inventory. Corporate attire hides accessories and restores the prior look. Preview failure prevents debit. Fit, lens appearance, wrist clearance and hand interactions still require native visual review; these are authored interim geometry, not validated premium assets.

## Fitting interface pass
All/outfits/jackets/trousers/glasses/watches category filters; H/F or LB/RB switches categories, existing 1/2/3 or A/X/Y actions browse and confirm, R/D-pad down compares the actual committed look against try-on. Right-stick horizontal or RMB drag rotates the character; vertical stick or mouse wheel zooms. Compare never writes progression; close restores actual clothing and original heading. Wardrobe menus now use their physical counter reachability instead of generic venue coordinates. Existing home-purchase behavior retained for compatibility. Native camera framing and UI input parity await playtest.

## Shop atmosphere increment
Threadline has a named shopkeeper, Tess Vale, with a distinct retail tag, greeting on first checkout interaction each visit, and purchase acknowledgment. Existing staff pose rig is reused; animation is disabled and the clerk hidden outside the occupied ground floor. Added countertop POS, payment signage, branded wall and shelf accents and a retail playlist from existing NightGrid tracks. No voice assets, new dynamic lights, or collision changes; native quality remains unverified. The clerk is intentionally static at her station pending better store-specific authored actors.

## District stock pass
Five stable physical clothing locations: Threadline (-3,-2 east), Quay Standard (0,-4 west), Vesper Line (-1,-2 east), Nocturne (0,2 west), Obscura (1,-3 west). Four new outfits and one jacket variant are retailer-exclusive; home retains legacy purchase compatibility and can equip owned exclusives. Checkout validates the specific store and available inventory. Shared interior and clerk are temporary until distinct shop art and staff pass; native testing pending.

## Brand identity increment
Five distinct shopkeepers, palette and light colors, feature walls and music groups. Threadline patch wall, Quay canvas/tool panel, Vesper fabric library, Nocturne violet light installation (static, no strobe), Obscura brass signature display. Each feature is catalog-driven and priced; existing static batches, one local light, and occupied-floor NPC processing are reused. Journal fashion directory provides a waypoint action for each address. The shells and interim character rigs are shared; native visual/audio/controller validation pending.

## Personal looks and owned collection
Three persistent complete outfit presets, including base outfit and every independent slot. Optional save field defaults empty for old snapshots; validation rejects unknown slots, unknown preset names and unowned base/pieces. At checkout or home, cycle to OWNED to browse all owned items (across stores); LOOKS displays preset slots. R/D-pad down saves the actual committed outfit, not a try-on; overwriting requires a second press, browsing or equipping cancels pending overwrite. Equip is free and never changes ownership. Native UI and save regression checks are pending.

## Second Signal / Brickwater thrift
Sixth fixed retailer, east parcel (-3,1), with Rook Serrano, upcycled feature wall, DIY branding and a retail playlist. Eight low-cost original material variants, four permanent staples (including existing common items) and a three-day curated rotating rack. Day index advances at midnight (including advance_hour) and is optional in old snapshots; capped and validated. Checkout freezes the stock at opening, so midnight cannot invalidate an existing quote; reopening uses the new drop. Ownership never expires and acquired finds remain in the owned category and personal looks. Rotation is deterministic, no gambling, no real money. Static shelf displays show the wider catalog rather than live inventory; native routing and visual tests pending.

## DIY merchandise / original art
Four fictional music/scene patches (Dead Carrier, Voltage Debt, Ghost Shift, NightGrid FM), authored 256px vector textures, stocked permanently at Second Signal. Independent patch slot reuses the existing skin-weighted Morrow Dispatch backpack patch primitive, preserving animation and UVs; reset restores the original patch, and owned looks/save validation automatically support it. Display cards share the same art. No extra avatar mesh or per-frame decal processing. If the fitted surface is absent the preview fails closed before debit. Native import, legibility and fit remain unverified. The music progression branch is not on main; future verified gig/achievement rewards should grant owned cosmetic IDs through a dedicated receipt-backed ledger transaction, not simulate a purchase or debit cash. No gig rewards implemented in this commit.

## Integration polish
Direct wardrobe service input dispatch prevents GUI focus consuming controller purchase shortcuts. Keyboard repeat is blocked while shopping to prevent accidental repeated actions. Category and item navigation reset orbit/zoom; patch selection presents the backpack, with prices on the merch display and a dedicated preview caption. Switching categories restores the committed appearance before the next preview. The smoke includes closing an unpaid patch preview after a paid patch. README documents all six stores and controls. These are static review changes; automated native checks must still run.

## Retail collection expansion

35 outfit colorways (including the pre-owned Dispatch), 37 individually purchasable pieces, and five no-charge reset actions. New stock: 18 outfits and 18 jacket/trouser colorways, three of each per retailer. All new IDs are permanent and exclusive to their home retailer; existing saves, ownership and pricing anchors are preserved. Three thrift drops each gain one outfit and one piece; owned finds never expire. New stock has short fitting-room finish notes, and display fixtures show outfit and individual garment examples with actual inflation-adjusted price tags. Display examples are static, not an assertion of live thrift stock. Existing weighted meshes are reused: names describe palette and finish, not new silhouettes, fabric simulations, or separate tailoring meshes. No new live assets or skeletons. Added catalog/stock consistency checks to the existing walk-in smoke. Native visual and CI verification remain required.

| Store | New collection | New pieces |
|---|---|---|
| vesper_threadline | Threadline / Concrete; Threadline / Copper Hour; Threadline / Rain City | Concrete jacket; Olive cargo trousers; Copper Hour jacket |
| quay_standard | Quay / Breakwater; Quay / Forge Shift; Quay / Silt | Breakwater jacket; Forge cargo trousers; Silt work jacket |
| vesper_line | Vesper / Meridian; Vesper / Oxblood; Vesper / Pearl | Meridian jacket; Pearl trousers; Oxblood jacket |
| nocturne | Nocturne / Afterimage; Nocturne / Eclipse; Nocturne / Ember | Afterimage jacket; Eclipse trousers; Ember jacket |
| obscura | Obscura / Archivist; Obscura / Porcelain; Obscura / Monolith | Archivist jacket; Porcelain trousers; Monolith jacket |
| second_signal | Second Signal / Overprint; Second Signal / Scrapyard; Second Signal / Deadstock | Overprint jacket; Scrapyard trousers; Deadstock jacket |

## Accessory collection and main integration

12 new exclusive accessory IDs, two per retailer. Six eyewear styles include original round and wide lens geometry; six watches include round analog-style dials and compact digital faces, with distinct colors and materials. The existing Head/LeftHand attachment transforms and per-ID cache are reused. No collision or additional animation skeleton. Catalog now has 35 outfits and 49 individual cosmetics (84 total); Second Signal's two new accessories are permanent staples. Native lens transparency, fitting, occlusion and wrist/hand pose checks remain mandatory. Preflight adds an actual rig attachment/reuse smoke for all 16 eyewear/watch IDs. The street-cred smoke now verifies coexistence of fashion and street progression in one save. Main was reconciled with a two-parent merge preserving both systems.

## Headwear collection

12 retailer-exclusive hats, four silhouettes (cap, beanie, bucket and fedora), including a new independent HEADWEAR category and free remove action. The same original bounded geometry is used on the animated Head attachment and two static priced samples in each shop. Hat ownership, look presets, preview cancellation, old saves and corporate attire use the existing slot/attachment contracts. New total: 35 outfits and 61 individual cosmetics, 96 unique IDs including the pre-owned Dispatch. Headwear is interim geometry with a provisional head-relative fit: native crown/hair clipping, glasses overlap, camera and pose review required. No body mesh replacement or collision added. The headless rig smoke now exercises all 28 accessory IDs and a simultaneous hat/glasses/watch look. The separate fitted clothing authoring pipeline remains review-only.

## Local scene merchandise

Eight original 256px vector patch designs extend the weighted backpack slot to 12 choices: Rust Choir, Null Rent, Scrap Angel and After Union at Second Signal; Black Relay and Laser Wake at Nocturne; Night Bus at Threadline; Dock Rat at Quay Standard. Four new permanent thrift staples. The same exact textures appear on a bounded eight-card wall display at participating shops, with actual 2036 prices. No real band logos or music rights assumed; fictional scene branding only. 104 unique cosmetics (35 outfit colorways and 69 pieces). Existing save and preview contracts unchanged. Native import and legibility pending.
