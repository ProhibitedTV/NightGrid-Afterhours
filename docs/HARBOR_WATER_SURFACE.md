# North Quay and West Docks water material pilot (#34)
Replaces uniform metallic teal water with two joined, non-overlapping harbor
planes and one shared opaque spatial PBR shader. World-space directional
wave normals provide continuous moving highlights; smaller ripples fade
with camera distance. Shallow color varies by distance to the north/west
quay. Metallic is zero, roughness varies, and existing sun/sky/environment
lighting drives the response. It is an approximation, not a simulated ocean:
no refraction, screen/depth texture copy, extra lights, tessellation, FFT,
collision changes or runtime mesh generation. Existing shoreline and quay
collisions remain unchanged. No new scene nodes; two fixed planes.

Native acceptance is outstanding. Capture real Godot Forward+/Vulkan from
North Quay and West Docks at identical old/new camera, lens and clock, noon
and dusk/night, including an elevated northwest view to inspect the plane
junction, and a driving view to assess distracting shimmer. Compare on RTX
3060 at 1080p and record p50/p95 frame times. Ensure piers remain grounded,
water stays below roads, no moire or hard horizon seam. Do not claim final
photoreal art from headless smoke; the distant port infrastructure remains
provisional and needs authored geometry. No README screenshot changes here.
