# Imported pedestrian rig interface (#99)
The adapter `scripts/pedestrian_rig_visual.gd` hosts an authored/verified
rigged scene, not the old primitive humanoid. Specify skeleton, animation
player and optional fabric surface in an inherited/wrapper scene. A weighted
mesh must bind to the selected skeleton. The production pool passes a verified
PackedScene, and the adapter finds its imported rig and sets the authored clips'
loop flags. Models use meter scale, local +Z forward and feet at the origin.
The adapter preserves the imported skin and animation tracks.
Visual readiness is a structural gate, not proof of asset provenance or art quality.

The pool can drive set_pedestrian_style and set_locomotion from actual measured
meters/second. Idle/walk hysteresis and transition blending prevent flicker,
and gait speed scales to motion. A designated clothing surface gets six
reusable PBR material variants; skin, hair and other surfaces are untouched.
Reset pooled occupants using reset_pedestrian_visual before showing the body.
The four production characters retain their authored clothing and skin atlases.
The synthetic weighted-triangle fixture is used exclusively by the adapter
regression. [Production asset sources and redistribution](../assets/models/nightgrid/pedestrians/SOURCE.md).
