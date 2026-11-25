# Physical pedestrian pool pilot (#99)
Standalone, deliberately not installed in World. The pool creates up to 12
CharacterBody3D capsules once from a caller-supplied PackedScene visual. No
placeholder asset ships with the pilot. A headless empty scene is a test fixture
only. A later integration must supply original or license-verified rigged art
with suitable idle/walk clips; optional visual hooks are set_pedestrian_style
and set_locomotion (meters/second).

Activation requires a live predicate (certified full link, local collision,
actual camera and loaded parcel readiness) and actual sampled floor height.
Call on the physics tick, reserve no more than two changes per cycle and use
the logical planner. Freeze active phases via active_positions().keys() and
call step once each tick. Recycle only with the real hidden/distance predicate;
capture_live must succeed before disabling the slot. Displaced actors need safe
recovery, not teleports. Before live rollout, ensure occupied parcels remain
loaded and validate support throughout each route, dynamic obstacle avoidance,
camera margins, phase persistence on save, motion animation, and native FPS.
This pilot provides no witness entries or heat mutations. It does not make
pedestrians visible in normal gameplay. Do not use permissive test predicates
or empty test visuals in the game.
