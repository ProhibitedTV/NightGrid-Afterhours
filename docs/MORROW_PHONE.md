# Morrow OS — smartphone

Open on foot with P, or from Pause > Smartphone on controller. The compact device menu occupies the right side, uses the existing paused-world focus and weapon-suspension contract, and closes after routing. Escape/B returns from an app to the launcher, then to the original pause or gameplay state. P puts the phone away. No phone during the corporate prologue, while driving/riding transit, inside an active service dialogue, or while the equipment wheel is open.

Seven original apps are connected to existing gameplay:
- QuotaDrop: active order, pickup/delivery stage, payout and completed runs; take offer/navigation or decline an uncollected offer to cycle the six existing authored routes. Declining never pays, increments completed runs or switches a carried package. Pickup remains physical; existing automatic assignment is retained. Inactive account cannot route a gig.
- Workboard: eight authored private-contact and civic contracts, their actual rewards, opening status, brief, and route to the relevant counter. Completed contracts disappear and active ones route to turn-in. No remote acceptance or payout.
- Wallet: current cash and BTC holdings; no invented bank balance or remote exchange.
- Contacts: Mara's actual mission state and route to Lantern Cup, plus revoked corporate access after offboarding.
- Housing: actual deposit, funds saved, tenancy eligibility and hotel waypoint. Pay in person; no remote rental or save.
- Transit: nearest real M-Line station and City Loop stop (direct distance), with routes.
- Messages: state-derived offboarding, platform notices and hotel information. No simulated incoming texts, persistent inbox or notifications yet.

A bounded optional courier_offer_offset persists the selected route in the existing v1 snapshot; missing field restores zero for legacy slots. The phone does not duplicate wallet, mission ledger or ownership. All route actions use the existing world waypoint system. The menu is intentionally a paused first implementation, not a physical held-phone animation. Future work: in-world device model and thumb animation, a true explicit accept gate (current selection still uses existing automatic assignment), persistent authored message threads, contacts and notification scheduling, and a tested live-world mode.

Validation: independent world smoke for app focus, route, economy invariants and pause ownership. Run exact-head preflight and Windows export; verify actual 720p/1080p layout, controller access and held-weapon safety. Reconcile menu/world and workflow changes with PR #310 before merge.

The launcher now uses seven original SVG icons and a two-column D-pad focus grid. Asset source is `assets/phone/`. Decline clears a waypoint near the old order target and refreshes the existing objective.

## Work beyond QuotaDrop

The duty flag is optional in the existing v1 save format (legacy defaults online). Offline suppresses physical courier pickup, the world marker, radar and atlas pin, and journal objective; carried orders must be resolved first. Going offline does not block civic or private work. Mara's referral now recognizes either a successful courier delivery or newly completed legitimate paid local/civic contract while her mission is active. The existing story event, receipt and reward are preserved; no additional credits are minted. Workboard reads the authoritative catalogs and existing active/completed contract ledgers, and routes only to current valid listings. No new jobs, real estate purchases, or simulated investment returns are added in this slice.
