# Synaxis staff accessory intake (#467)

Four original fictional identity badge textures in assets/synaxis/badge_*.svg. These are graphic assets only; native rig fitting is pending. Use a chest BoneAttachment3D on the imported rig, verify bone names and local axes, validate rest/idle/walk attachment alignment, and keep legacy badges hidden. Add Owen's radio and Eli's tablet after #454 hand socket validation. Mika retains the original generator profile name Morrow Courier; preserve provenance hashes until deterministic regeneration. Native closeups and redistribution review required.

## Clean-checkout validation

Run `python tools/validate_synaxis_staff.py --all --check` to compare all four binary and normalized profile hashes, rig structure, materials and clips with committed manifests without editing them. The project preflight also publishes the actual joint names and local rest transforms as the `synaxis-staff-sockets` artifact. These data identify candidate attachment bones; native pose and fit review remain required before placing props.
