# Imported pedestrian rig interface (#99)
The adapter `scripts/pedestrian_rig_visual.gd` hosts an authored/verified
rigged scene, not the old primitive humanoid. Specify skeleton, animation
player and optional fabric surface in an inherited/wrapper scene. A weighted
mesh must bind to the selected skeleton; both idle and walk must be looping,
nonempty clips. Author in-place locomotion at real meter scale, +Z forward
and feet at local origin. The adapter does not fix retargeting or root motion.
Visual readiness is a structural gate, not proof of asset provenance or art quality.

The pool can drive set_pedestrian_style and set_locomotion from actual measured
meters/second. Idle/walk hysteresis and transition blending prevent flicker,
and gait speed scales to motion. A designated clothing surface gets six
reusable PBR material variants; skin, hair and other surfaces are untouched.
Reset pooled occupants using reset_pedestrian_visual before showing the body.
No placeholder meshes or downloaded assets are shipped. The smoke uses a
synthetic weighted triangle exclusively in test code. A production asset still
needs documented redistribution rights, native render/animation inspection,
root-motion verification, clothing and skin diversity, and performance capture.
