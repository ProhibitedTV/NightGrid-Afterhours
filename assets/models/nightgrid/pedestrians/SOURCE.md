# Morrow Bay pedestrian assets

The game imports four different tevy v1 LOD1 models under CC0 1.0. Each has 8,999 triangles, a 55-joint humanoid rig and idle, walk, look-around and wave clips. The models use their own texture atlases for skin and clothing, with base color, normals and roughness. Godot generates additional mesh LODs and embeds the imported textures. [Publisher and license](https://github.com/iruizsalinas/tevy#license) · [CC0 legal code](https://creativecommons.org/publicdomain/zero/1.0/) · [Original verified source artifact](https://github.com/ProhibitedTV/NightGrid-Afterhours/actions/runs/44962383100).

| Publisher source | Source SHA-256 | Converted SHA-256 |
| --- | --- | --- |
| [Casual Walker](https://tevy.dev/models/casual-walker/v1/lod1.glb) | `ed578eebe688843f684391719158a08bf454665fd63f16df6b4745a57cffda9f` | `35406a5902ff654d8868468d3aa7f3dc5e5f2b7c916ef385485e9f2e39835c48` |
| [Dog Walker](https://tevy.dev/models/dog-walker/v1/lod1.glb) | `a5408cf77434f9a74b112bc4924f07e1f86191edfac7f11eb4bb29b7d28b0ef4` | `29b468e9635355019d93ad4b3ae08836a6e982c3a306923f5733d55967484c75` |
| [Road Worker](https://tevy.dev/models/road-worker/v1/lod1.glb) | `a7b66ac6b58404ad4d076b25dd77412191ef2462c6f5f06e72eb9cd854d4d17b` | `45c3f0593a9671278545c1ad8aca247b144c054795e672f85884a8772046eb78` |
| [Hiker](https://tevy.dev/models/hiker/v1/lod1.glb) | `bbf5f07bf23991a967cd29ef6c692d852047f1fc0d6860f689108e8e485b2f6e` | `36e82b2d9e73038743bb5cb2a9c530b9272a1ce2a7bb57b67e7209f7fbae290d` |

The offline conversion checks the source hash, decodes Meshopt buffer views, expands quantized vertex accessors and keeps the original KTX2 maps, bones and animation. The tools do their work before Godot imports the assets. Use Node 24 and the following pinned packages in a scratch authoring folder.

```powershell
New-Item -ItemType Directory -Force dist/pedestrian-authoring
npm install --prefix dist/pedestrian-authoring --save-exact --ignore-scripts @gltf-transform/core@4.3.0 @gltf-transform/extensions@4.3.0 @gltf-transform/functions@4.3.0 meshoptimizer@0.24.0
node tools/prepare_pedestrian_models.mjs dist/pedestrian-source assets/models/nightgrid/pedestrians dist/pedestrian-authoring
```

Place the verified source files in `dist/pedestrian-source` first. The four asset file names match the publisher model IDs. The game and regressions use the committed converted GLBs offline.

The rig adapter shares one Godot material override per source. It retains the original color, normal and green-channel roughness maps, disables metallic sampling for skin and cloth, and reduces the specular and normal strength after native daylight review.
