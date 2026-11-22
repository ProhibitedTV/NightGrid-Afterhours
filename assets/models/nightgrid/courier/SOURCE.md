# Morrow courier source and redistribution

The game ships one self-contained skinned glTF with 28 clips. The base human, skin, eyebrows, eyelashes, eyes and short hair derive from MakeHuman assets released under CC0 1.0 by Data Collection AB, Joel Palmius and Jonas Hauquier. The game includes no MakeHuman or Ara runtime code. [MakeHuman license](https://static.makehumancommunity.org/about/license.html) · [Ara asset notices](https://github.com/olatunde85/3d-gen/blob/9d3b9f9933cbeb9529630a270ffc7fe01bd05511/scripts/ASSETS_LICENSE.txt).

The outfit was built using Ara's exportable clothing, materials, boots, scarf, gloves and backpack, assembled and recolored with the project-owned [appearance profile](appearance.json). The NightGrid finishing script removes the decorative scarf knot, preserves the remaining collar, and projects the original Morrow Dispatch fabric patch onto the pack with its joint weights. [Ara clothing documentation](https://ara3dgen.com/docs/characters/) · [Package license](https://github.com/olatunde85/3d-gen/blob/9d3b9f9933cbeb9529630a270ffc7fe01bd05511/LICENSE).

The game uses Ara's retargeting of CMU motion capture for the base gait, backwards walk, strafing, turns and chair clips. The equipped locomotion builds on those takes. Ara's other selected poses and transitions ship in the same character export. CMU permits inclusion in commercial and noncommercial products and restricts resale of motion data on its own. [Ara clip provenance](https://ara3dgen.com/docs/animations/) · [CMU terms](https://mocap.cs.cmu.edu/).

> The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

## Rebuild

Use Node 24, Python 3.11 and `ara3d@0.13.0` in a job-local tool directory. The authoring CLI downloads its pinned data archive on first use. The game and its CI import the committed GLB offline.

- Ara source revision `9d3b9f9933cbeb9529630a270ffc7fe01bd05511`.
- NPM integrity `sha512-vWOekB/cDHukamIjsWfKDWo9MjsrP8Gqz8DtDD78t3c10NTeMtEJUi9b9HFQmhgZwJJQXp7kAH3ErOOGEp3eog==`.
- Unmodified export SHA-256 `aa35ae647f7d51a0abf273e230a8f52ae285df6b75d302c80bf2aa344eb78331`.
- Prepared GLB SHA-256 `bea46cabc9cf7389aee3d304e6fb42fd81fb669e6957a8f2df59e22a023e906c`.

```powershell
npx ara3d@0.13.0 export --params assets/models/nightgrid/courier/appearance.json --out dist/courier-source --animations idle,walk,run,walk_back,strafe_left,strafe_right,turn_left_45,turn_right_45,jump_start,jump_air,jump_land,use_press,open_door,pick_up,sit_down,sit_idle,stand_up,pistol_idle,pistol_aim,pistol_fire,pistol_walk,pistol_run,pistol_strafe_left,pistol_strafe_right,rifle_reload,board_car,drive_car,alight_car
python tools/prepare_courier_glb.py dist/courier-source/Morrow_Courier.glb assets/models/nightgrid/courier/morrow_courier.glb
```

Godot 4.7.2 uses its glTF skin and texture importer. The runtime sets clip loops once and reuses the animation library across scene reloads.
