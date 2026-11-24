"""Deterministic bicubic Bezier surface cages for original automotive body panels.

A geometric authoring primitive, not automatic Class-A surface certification.
Cages can be edited in Blender after import; use local sculpting for wear and
organic material response, not as a substitute for engineered body creases.
"""
from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Sequence

Vec3 = tuple[float, float, float]
Cage = Sequence[Sequence[Vec3]]


@dataclass(frozen=True)
class PatchMesh:
    positions: tuple[Vec3, ...]
    normals: tuple[Vec3, ...]
    uvs: tuple[tuple[float, float], ...]
    triangles: tuple[tuple[int, int, int], ...]


def _bernstein(t: float) -> tuple[float, float, float, float]:
    q = 1.0-t
    return (q*q*q, 3*t*q*q, 3*t*t*q, t*t*t)


def _derivative(t: float) -> tuple[float, float, float, float]:
    q=1.0-t
    return (-3*q*q, 3*q*q-6*t*q, 6*t*q-3*t*t, 3*t*t)


def _validate(cage: Cage) -> None:
    if len(cage) != 4 or any(len(row) != 4 for row in cage):
        raise ValueError('Bezier cage must contain 4 x 4 points')
    if any(len(p)!=3 or not all(math.isfinite(x) for x in p)
           for row in cage for p in row):
        raise ValueError('Bezier cage has invalid coordinates')


def evaluate(cage: Cage, u: float, v: float) -> tuple[Vec3, Vec3]:
    """Return position and analytical +Y-oriented normal for an X/Z patch."""
    _validate(cage)
    if not 0.0 <= u <= 1.0 or not 0.0 <= v <= 1.0:
        raise ValueError('surface coordinates must be in [0,1]')
    bu,bv=_bernstein(u),_bernstein(v)
    du,dv=_derivative(u),_derivative(v)
    pos=[0.,0.,0.]; tu=[0.,0.,0.]; tv=[0.,0.,0.]
    for i in range(4):
        for j in range(4):
            point=cage[i][j]
            for k in range(3):
                pos[k]+=point[k]*bu[i]*bv[j]
                tu[k]+=point[k]*du[i]*bv[j]
                tv[k]+=point[k]*bu[i]*dv[j]
    # Patch u goes along +X and v along +Z; dv x du points to +Y.
    n=(tv[1]*tu[2]-tv[2]*tu[1],
       tv[2]*tu[0]-tv[0]*tu[2],
       tv[0]*tu[1]-tv[1]*tu[0])
    mag=math.sqrt(sum(x*x for x in n))
    if mag < 1e-10:
        raise ValueError('surface derivative is degenerate')
    return tuple(pos),tuple(x/mag for x in n)


def tessellate(cage: Cage, u_segments: int, v_segments: int) -> PatchMesh:
    _validate(cage)
    if not 1 <= u_segments <= 256 or not 1 <= v_segments <= 256:
        raise ValueError('surface segment count must be 1..256')
    positions=[]; normals=[]; uvs=[]; faces=[]
    for row in range(v_segments+1):
        v=row/v_segments
        for col in range(u_segments+1):
            u=col/u_segments
            p,n=evaluate(cage,u,v)
            positions.append(p); normals.append(n); uvs.append((u,v))
    width=u_segments+1
    for row in range(v_segments):
        for col in range(u_segments):
            a=row*width+col
            b=a+1
            c=a+width
            d=c+1
            faces.extend(((a,c,b),(b,c,d)))
    return PatchMesh(tuple(positions),tuple(normals),tuple(uvs),tuple(faces))


def seam_report(left: Cage, right: Cage) -> dict[str,float]:
    """Measure C0/C1 alignment when left u=1 and right u=0 join."""
    _validate(left);_validate(right)
    position=0.; derivative=0.
    for j in range(4):
        a,b=left[3][j],right[0][j]
        da=tuple(a[k]-left[2][j][k] for k in range(3))
        db=tuple(right[1][j][k]-b[k] for k in range(3))
        position=max(position,math.dist(a,b))
        derivative=max(derivative,math.dist(da,db))
    return {'max_position_gap_m':position,'max_handle_mismatch_m':derivative}
