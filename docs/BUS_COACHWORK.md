# Original city bus coachwork pilot

Replaces the existing four NPC buses' stacked rectangular visual blocks with
an original closed cross-section shell with modeled chamfered ends and roof,
segmented glazing, curb-side door panels, trim and restrained emissive
head/tail lights. The body is one mesh (six surfaces), shared by livery.
Wheels retain the existing four tires and four hubs but their visual axle
height is lowered to -1.30m relative to the existing 1.75m bus route, leaving
about 1cm road clearance; geometry remains within the original lateral
collision width. Actual collision dimensions, boarding and route schedules
are unchanged. Door graphics are not openable doors; windows are opaque PBR
surfaces rather than an interior. The new body is generated once from an
original fixed mesh recipe, not a random shape; no new binary assets or
per-frame meshes. Native closeups of wheel/skirt intersection, door design,
livery, shadows, and traffic continuity remain necessary before claiming
realism or measured frame pacing. This branch intentionally does not alter
the active gallery capture on #111.

Follow-up: four circular wheel-arch cutouts replace the long continuous skirt faces. Twelve samples per arch, dark inner well liners and a recessed underside retain a 0.53m nominal arch radius around the 0.44m tires. The existing tire and body colliders are not changed. Test the actual skirt vertices and clearance; native visual review still required. Wheel-arch geometry is authored, not a black painted decal.
