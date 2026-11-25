# Traffic wheel art and motion

Port of #115 to current MultiMesh traffic. Two cached geometry size classes, shared stationary tire batches, one private four-instance rim batch per vehicle. No additional drawables, body collision changes, save fields, or per-frame mesh allocation. Phase uses actual post-slide displacement projected on the vehicle forward axis; sideways movement and teleport deltas are ignored. Phase resets on restore and ambient lease. Headless tests verify resource sharing, wheel envelopes and phase math; native visual and frame-time comparison remain necessary.
