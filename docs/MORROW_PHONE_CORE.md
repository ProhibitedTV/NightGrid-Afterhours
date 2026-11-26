# Morrow OS — integration core

P opens the phone on foot, or use Smartphone in the pause menu. Nine apps expose existing live game state and route to physical destinations. No phone-side payouts, save schema changes, remote purchases, or automatic contract acceptance. Music and street cred reflect the currently merged PocketBeat / Blue Hour career. The current implementation includes band progression, cassette merchandise, offer cycling and off-duty mode. PR #315 is a historical draft with incompatible alternate career logic; do not treat it as current gameplay documentation. Native visual and controller playtest pending.

The nine apps are QuotaDrop, Wallet, Contacts, Housing, Transit, Messages, Workboard, Music and Street Cred. Route actions set the existing world waypoint and close the phone; browsing does not accept contracts or change balances. The phone is unavailable during the corporate prologue, while driving or riding transit, during an arcade or music session, a service interaction, or equipment selection. It is a paused menu, not an animated physical handset.

## QuotaDrop offer selection
Before collecting an order, Decline / next offer cycles through the six authored offers without payment or progress. Carried orders cannot be declined; use the existing abandon/retry flow. The optional bounded `courier_offer_offset` save field preserves the chosen route, including mid-delivery; old saves default to zero. Duty toggles and musician progression are described below.

## Technical consulting
Workboard lists two optional one-time diagnosis contracts at Crane & Gear and Grid Annex Four. Visit during open hours, examine the fictional evidence and select a repair. Wrong choices do not pay; wallet-capacity failure remains retryable. Completion uses the existing receipt ledger. No additional save schema or remote payout. The Paper City follow-up investigation is described below.

## The Paper City
After either technical consulting contract, a four-stage evidence investigation opens at Harbor Reading Room, Southworks Records and Dock Watch. Workboard routes to the current lead and the journal tracks progress. The final choice distinguishes documented inconsistencies from unsupported accusations. The existing ledger pays once; a bounded optional save stage is validated against prerequisites and completion receipt. Legacy saves remain valid.

## Off-duty mode
Go off duty before collecting cargo to hide the delivery beacon, radar/map pin, route action and pickup prompt. Resume the same offer from QuotaDrop without payment or progression changes. An active carried order must be delivered or abandoned first. The optional boolean save field defaults to on duty for old saves; carried orders cannot be restored off duty. The story journal directs the player to resume QuotaDrop instead of routing to an inactive delivery.

## Band recruitment
After buying and practicing the PocketBeat M3 three times and completing a legitimate Blue Hour opening set, invite Rhea Vale at Copper Cup's music desk and Milo Static at Dock Nine's staffed counter. Both choices cost nothing and award no cash or cred. The bounded roster lives in the existing progression ledger and the Music app reports collaborators. Older saves default to no recruits. Rehearsals, naming and merchandise are implemented as described below; full instrument-specific ensemble performance remains future work.

## Band rehearsal
The recruited trio rehearses at Copper Cup via its existing music desk. Two distinct 16-beat patterns, 13 required hits, 0.72-second beats, 0.20-second hit window. Successful claims at the actual reachable desk record one bounded rehearsal; retries, cancelled sets and duplicates do not count. No cash or cred. Optional roster-validated count survives saves; two rehearsals unlock the Blue Hour trio debut. The pads are existing sampler audio, not full band audio or animated NPC performance.

## First paid trio booking
After recruiting both collaborators and passing two rehearsals, the Blue Hour counter offers the one-time $240 trio debut. A distinct 24-beat pattern requires 20 correct hits at 0.65-second spacing and a 0.18-second hit window. A successful rhythm claim at the reachable open venue settles exactly one payout and 30 Street Cred via the existing receipt ledger. A full wallet rejects settlement without consuming the booking. Encore and showcase bookings and merchandise are described below. Solo opening sets return after both encores. The pads remain sampler cues, not a full mixed band performance or animated stage.

## Encore and showcase bookings
After the debut, two different Blue Hour encore arrangements (20 beats, 17 correct, $120 and 12 Street Cred each) advance the trio to a one-time Static Room showcase (32 beats, 27 correct, $480 and 45 Street Cred). The sequence is bounded, venue-gated and uses authoritative ledger receipts/run counts. Solo Blue Hour sets return after both encores, rather than replacing solo play indefinitely. Save validation rejects out-of-order completion, and cash overflow does not consume a booking. These are rhythm challenges using existing sampler pads; full ensemble audio and animated stage performances remain future work.

## Band identity and cassette merchandise
Choose one of six permanent names at Copper Cup after recruitment. After the debut and before the showcase, Copper Cup's music desk offers an offline pressing service: 12 After the Last Shift tapes for $60, $12 per tape at paid bookings. Up to four tapes sell on each encore and eight at the showcase. Sales occur only when the booking settles, use available inventory, and respect wallet capacity. Stock, sales, batches and band name survive saves; no passive income or duplicated claims. Three-batch cap, with a maximum stock of 36. This reconciles the original Off Grid Records business mechanic through the existing music desk instead of adding an unverified location. Remaining stage animation/ensemble audio, standalone record shop and physical merchandise assets are not delivered here.

## Scene reputation
Music, Community and Underground ranks are read-only projections of the existing ledger's actual completed activities and receipts. Music counts completed street/solo sets, encores, soundcheck, debut and showcase. Community includes authored favors, the garden trail, and capped taxi/freight contributions; Underground reflects relevant technical and investigation receipts. Each score is capped at 100; purchases, cash and waiting do not raise it. The journal and phone Cred app display these alongside unchanged global Street Cred. No new save schema, discounts, unlock rules or parallel XP wallet.

## Current Workboard and music navigation

Workboard lists available local and civic contracts, technical consulting, the current Paper City lead, rotating taxi fares and freight jobs, and the Southworks Circuit and Brickwater Loop. Completed one-time jobs disappear; active work routes toward the current destination. Taxi and freight require physical pickup/delivery in an eligible vehicle. Racing records and first-prize receipts persist independently; the reference pace and responsive non-contact opponent are separate systems.

Music shows instrument progress, current contacts, street and live set counts, and merchandise for a named band. It routes to Copper Cup, Blue Hour after soundcheck, Static Room for the music contact when eligible, Blue Hour while the demo delivery is active, Dock Nine when Milo can be recruited, and Static Room when the showcase becomes available. The world adapter rechecks career eligibility on selection. No remote recruitment, purchase or performance is performed by these actions.

Cred shows the three capped scores with ranks: Unknown (0), New face (1–19), Recognized (20–49), Respected (50–84), Scene icon (85–100). These are informational projections, not new purchase discounts or independent balances.

## Acceptance

Run `godot --headless --path . --script res://tests/morrow_phone_core_smoke.gd` and full preflight/Windows export. On the exact tested build, inspect keyboard P and pause-menu controller access, launcher/app focus, readable rows at 720p and 1080p, route selection, rejection of unavailable actions, and restoration of input when closing. Verify carried-order guards, both duty states, physical music bookings, all three reputation rows, and unchanged wallet while browsing. Record actual screenshots and pass/fail results; automated tests alone do not establish native layout quality.

## Native music presentation acceptance (merged #399, #403, #405, #406)

These changes add a reversible skeletal performance layer, a physical sampler resident at Blue Hour, isolated solo/trio equipment previews and direct rhythm feedback. The ambient musician is not the player's ensemble; the preview shows equipment, not a live concert. Do not infer graphical quality from headless success.

Record the full source SHA from BUILD-INFO.txt, resolution, renderer, input device and graphics preset. On a new or backed-up save:

| Test | Pass condition |
| --- | --- |
| Blue Hour 19:00–04:00 | One visible sampler performer near the venue, correct feet/stand/pad alignment, no intersecting patrons or pavement. Leave beyond 24m, return, repeat after closing; no persistent animation or duplicate performer. |
| Solo session | PocketBeat preview readable at 720p and 1080p; next lane, beat window, required hits, ON BEAT / WRONG PAD / MISSED and final outcome readable without clipping. |
| Trio rehearsal and paid bookings | Bass/synth/sampler art visible and proportionate in the preview; menu focus, scrolling and keyboard/controller input work. No duplicate viewport after repeated cancellation/reopening. |
| Audio | Original intro stops before playable timing window; pad cues audible and adjustable; no stuck loop on cancellation or return to the world. |
| Settlement | Failed/cancelled sets cannot pay or advance career; successful valid claim once only; verify cash, ledger and merchandise after save/reload. |
| Navigation | Before soundcheck, route to Static Room; active delivery routes to Blue Hour; completed demo removes the contact action. Verify Milo and showcase availability against actual progress. |

Use F10 for real world captures and paired JSON, F7 for issue markers and F8 for comparable native frame traces. For the paused UI, capture the actual screen separately if F10 suppresses overlays; include source SHA and resolution. Report native results in #398 and #362. Keep visual alignment, audio mix, controller feel and 60 FPS target unverified until observed. Pending #407/#408 are not acceptance requirements for this baseline.
