#!/usr/bin/env python3
"""Repeatable source-geometry quality measurements for the Vesper V2.

Reports measured manufacturing proxies, *not* artistic quality/AAA certification.
The report travels with each Blender/GLB build to make regressions visible.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from vehicle_body_surface import (
    STATIONS, AXLES, WHEEL_Y, TIRE_RADIUS, ARCH_RADIUS,
    arch_lower_boundary, body_surface_point, curvature_seam_metrics,
    fascia, side_panel, top_panel, tire_cross_section, mesh_integrity,
    width_shoulder, shoulder_normal_alignment,
    ARCH_CIRCLE_END, ARCH_ROCKER_END,
)


def normal(shell, face):
    a,b,c=(shell.positions[i] for i in face[:3])
    u=tuple(b[k]-a[k] for k in range(3))
    v=tuple(c[k]-a[k] for k in range(3))
    return (u[1]*v[2]-u[2]*v[1],
            u[2]*v[0]-u[0]*v[2],
            u[0]*v[1]-u[1]*v[0])


def calculate() -> dict:
    seam_results=[curvature_seam_metrics(z) for z,_,_ in STATIONS[1:-1]]
    gap=max(j["max_position_delta"] for j in seam_results)
    curvature=max(j["max_second_derivative_delta"] for j in seam_results)
    max_edge_error=0.
    for side in (-1,1):
        for j in range(500):
            z=-2.18+4.36*j/499
            w,h=width_shoulder(z)
            x,y,_=body_surface_point(z,side)
            max_edge_error=max(max_edge_error,abs(x-side*w),abs(y-h))
    # G1 hood-to-fender alignment and arch transition quality. Measure
    # both sides and both panels, not just the longitudinal station profile.
    shoulder_angles=[shoulder_normal_alignment(z,sign)
                     for z in (-1.93,-1.61,-1.14,-.94,.87,1.26,1.68,1.96)
                     for sign in (-1,1)]
    arch_tangent_jumps=[]
    for axle in AXLES:
        for joint in (ARCH_CIRCLE_END,ARCH_ROCKER_END):
            for side in (-1,1):
                z=axle+side*joint
                eps=.0001
                before=(arch_lower_boundary(z)-arch_lower_boundary(z-eps))/eps
                after=(arch_lower_boundary(z+eps)-arch_lower_boundary(z))/eps
                arch_tangent_jumps.append(abs(before-after))
    clearance=math.inf
    for axle in AXLES:
        for i in range(1001):
            d=-TIRE_RADIUS+2*TIRE_RADIUS*i/1000
            upper=WHEEL_Y+math.sqrt(max(0.,TIRE_RADIUS**2-d*d))
            clearance=min(clearance,arch_lower_boundary(axle+d)-upper)
    bonnet=top_panel(-2.18,-.78,24,48)
    front=fascia(True,36,12)
    rear=fascia(False,36,12)
    wheels=tire_cross_section(AXLES[0],-.805,48)
    components={"bonnet":bonnet,"front_fascia":front,
                "rear_fascia":rear,"front_tire":wheels}
    counts={name:mesh_integrity(piece) for name,piece in components.items()}
    normals={"bonnet_y":normal(bonnet,bonnet.faces[10])[1],
             "front_z":normal(front,front.faces[18])[2],
             "rear_z":normal(rear,rear.faces[18])[2]}
    report={
        "geometry_stage":"original curvature-continuous studio source study",
        "source_format":"parametric Python source; Blender high/LOD validation separate",
        "station_count":len(STATIONS),
        "curvature_seam_max_second_derivative_delta":curvature,
        "station_seam_max_position_delta_m":gap,
        "hood_fender_shared_edge_max_deviation_m":max_edge_error,
        "min_wheel_clearance_m":clearance,
        "max_hood_fender_normal_gap_deg":max(shoulder_angles),
        "max_wheel_arch_tangent_jump":max(arch_tangent_jumps),
        "outward_normals_sample":normals,
        "component_mesh_counts":counts,
        "warning":"Numeric geometry proxies do not prove aesthetic quality, G2 surface joins or native Godot FPS",
    }
    if gap>1e-5 or curvature>1e-4 or max_edge_error>1e-6:
        raise ValueError("Body spline / shared manufactured-edge continuity regression")
    if clearance<.045:
        raise ValueError(f"Fender intersects tire: clearance {clearance:.4f}m")
    if max(shoulder_angles)>1.0:
        raise ValueError(f"Fender/hood specular tangent discontinuity: {max(shoulder_angles):.3f} degrees")
    if max(arch_tangent_jumps)>.035:
        raise ValueError("Wheel-arch rocker transition has a sharp tangent kink")
    if not (normals["bonnet_y"]>0 and normals["front_z"]<0 and normals["rear_z"]>0):
        raise ValueError("One or more major exterior surfaces point inward")
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args()
    result=calculate()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(result,indent=2,sort_keys=True))


if __name__=="__main__":
    main()
