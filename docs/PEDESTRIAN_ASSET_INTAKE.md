# CC0 pedestrian source intake (candidate art only)
Source: tevy.dev, catalog https://tevy.dev/models.json, CC0-1.0
(https://creativecommons.org/publicdomain/zero/1.0/). Source site repository:
https://github.com/iruizsalinas/tevy (models CC0, website code MIT).
Version 1, LOD1 for casual-walker, dog-walker, road-worker and hiker.
Exact byte lengths and publisher SHA-256 digests are pinned in
tools/pedestrian_asset_sources.json. Each is listed as 8,999 triangles with
idle/walk/look_around/wave clips and +Z forward in meters.
Run python tools/fetch_pedestrian_assets.py --out /tmp/pedestrian-intake.
Or use the separate Pedestrian asset intake workflow for a verified review
artifact; it has read-only repository permissions and does not commit art.
No runtime network access or production dependency.
The source ships EXT_meshopt_compression and potentially KHR_texture_basisu;
inspect the actual report, then use an offline compatible glTF conversion
pipeline if Godot cannot import directly. Do not merely strip extension
declarations. Keep conversion recipes, hashes and source notices in the repo
when final assets are committed. Validate texture decode, skeleton, in-place
loops, material separation, actual facing/scale, feet contact and native
Forward+ appearance. The source catalog is not proof of visual quality.
Do not enable world population or call this art-final before native review.
