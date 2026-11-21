# Traffic rolling wheels (post-beta.7 candidate)

All 29 ambient traffic vehicles share two tire meshes and two rim meshes by
size. Original six-spoke rim faces, central hub and machined rim ring replace
the solid visual hub cylinder; one surface per rim, no extra mesh instances
or lights. Four rims rotate around their axle from actual post-collision
horizontal displacement projected onto vehicle forward, not intended speed.
Stopped actors do not roll. Invalid or teleport-size displacements are
ignored, and save restoration clears cosmetic phase without changing save
schema, route, collision or boarding. The tire is rotationally symmetric
and doesn't need animation. Tests inspect the actual 29 vehicles and exercise
the phase calculation with controlled displacements, not a native visual or
frame-rate benchmark. This is a separate post-beta.7 candidate; do not merge
into the release milestone until the current gallery and release are verified.

Additional contact-direction regression: pure lateral slide does not rewrite wheel transforms; forward moves the bottom contact point toward the rear; reverse unwinds the phase. Tiny longitudinal displacement is a no-op to avoid redundant transform writes.