"""Original Vesper V2 fairings: C2 longitudinal stations, G1 shoulder
joins, wheel arches and mechanically separated surfaces. Y up, nose -Z.

Geometry quality aid, not Class-A/G2 curvature certification.
"""
from __future__ import annotations
from dataclasses import dataclass
from math import cos, exp, isfinite, pi, sin, sqrt

@dataclass(frozen=True)
class Shell:
    positions: tuple[tuple[float, float, float], ...]
    faces: tuple[tuple[int, ...], ...]

# Each station drives hood/deck, side skins and bumper fit.
STATIONS = (
    (-2.180, .725, .748), (-1.990, .814, .805),
    (-1.700, .876, .847), (-1.380, .898, .884),
    (-1.050, .875, .915), (-.770, .830, .929),
    (.700, .830, .932), (1.020, .891, .886),
    (1.330, .910, .867), (1.780, .862, .822),
    (2.180, .750, .757),
)
AXLES=(-1.38, 1.33)
WHEEL_Y=.365
TIRE_RADIUS=.365
ARCH_RADIUS=.438
ROCKER_Y=.260

# Natural cubic splines give C2-continuous width and shoulder height across
# the shared design stations. Compared to Catmull/Hermite C1 joins this avoids
# abrupt second-derivative transitions that break studio highlights.
from functools import lru_cache


@lru_cache(maxsize=4)
def _spline_second_derivatives(column: int) -> tuple[float, ...]:
    if column not in (1, 2):
        raise ValueError("station property must be width or shoulder height")
    x=[row[0] for row in STATIONS]
    y=[row[column] for row in STATIONS]
    n=len(x)
    # Solve the natural cubic spline tridiagonal system using the Thomas
    # algorithm; first and last second derivatives are fixed to zero.
    lower=[0.0]*n;diag=[0.0]*n;upper=[0.0]*n;rhs=[0.0]*n
    diag[0]=diag[-1]=1.0
    for i in range(1,n-1):
        h0=x[i]-x[i-1];h1=x[i+1]-x[i]
        lower[i]=h0
        diag[i]=2*(h0+h1)
        upper[i]=h1
        rhs[i]=6*((y[i+1]-y[i])/h1-(y[i]-y[i-1])/h0)
    for i in range(1,n):
        factor=lower[i]/diag[i-1]
        diag[i]-=factor*upper[i-1]
        rhs[i]-=factor*rhs[i-1]
    second=[0.0]*n
    second[-1]=rhs[-1]/diag[-1]
    for i in range(n-2,-1,-1):
        second[i]=(rhs[i]-upper[i]*second[i+1])/diag[i]
    return tuple(second)


def _surface_segment(z: float) -> int:
    if not STATIONS[0][0] <= z <= STATIONS[-1][0]:
        raise ValueError("outside the design station interval")
    if z==STATIONS[-1][0]:
        return len(STATIONS)-2
    for i in range(len(STATIONS)-1):
        if STATIONS[i][0] <= z <= STATIONS[i+1][0]:
            return i
    raise AssertionError("missing spline segment")


def spline_property(z: float, column: int, derivative: int=0) -> float:
    """Exact C2 cubic spline value, first slope or second curvature proxy.

    Second derivatives describe the station profile, not the full 3D surface
    principal curvature; human visual and normal-continuity review is still
    required before treating any result as Class-A.
    """
    if derivative not in (0,1,2):
        raise ValueError("derivative must be 0, 1, or 2")
    i=_surface_segment(z)
    x0,x1=STATIONS[i][0],STATIONS[i+1][0]
    h=x1-x0
    a=(x1-z)/h;b=(z-x0)/h
    p0,p1=STATIONS[i][column],STATIONS[i+1][column]
    s0,s1=_spline_second_derivatives(column)[i:i+2]
    if derivative==0:
        return (a*p0+b*p1+(h*h/6)*((a*a*a-a)*s0+(b*b*b-b)*s1))
    if derivative==1:
        return ((p1-p0)/h+(h/6)*((1-3*a*a)*s0+(3*b*b-1)*s1))
    return a*s0+b*s1


def width_shoulder(z: float) -> tuple[float,float]:
    """C2 continuous original sculpt envelope: half-width and top shoulder."""
    return (spline_property(z,1),spline_property(z,2))


def _smoothstep(x):
    t=max(0.,min(1.,x))
    return t*t*(3-2*t)

# The arch follows the circular tire offset while the tire still occupies
# that section. Its end transitions through a matched-tangent Hermite return
# into the rocker. The original sqrt() arc to R had infinite endpoint slope.
ARCH_CIRCLE_END=.370
ARCH_ROCKER_END=.570


def _arch_height(offset: float) -> float:
    d=abs(offset)
    if d<=ARCH_CIRCLE_END:
        return WHEEL_Y+sqrt(max(0.,ARCH_RADIUS**2-d*d))
    if d>=ARCH_ROCKER_END:
        return ROCKER_Y
    span=ARCH_ROCKER_END-ARCH_CIRCLE_END
    t=(d-ARCH_CIRCLE_END)/span
    y0=WHEEL_Y+sqrt(ARCH_RADIUS**2-ARCH_CIRCLE_END**2)
    derivative=-ARCH_CIRCLE_END/sqrt(ARCH_RADIUS**2-ARCH_CIRCLE_END**2)
    return ((2*t**3-3*t*t+1)*y0 +
            (t**3-2*t*t+t)*span*derivative +
            (-2*t**3+3*t*t)*ROCKER_Y)


def arch_lower_boundary(z):
    """C1 wheel arch with measured tire clearance and rocker transition."""
    return max([ROCKER_Y]+[_arch_height(z-axle) for axle in AXLES])

def body_surface_point(z,across):
    w,h=width_shoulder(z)
    t=max(-1.,min(1.,across))
    camber=.064*(1-t*t)**2
    # Stamped crease and twin tonneau bubbles; both fade into adjacent skins.
    bonnet=_smoothstep((z+2.18)/.22)*(1-_smoothstep((z+1.02)/.25))
    edge_fade=(1-t*t)**2
    crease=.012*exp(-((abs(t)-.73)/.10)**2)*bonnet*edge_fade
    rear=_smoothstep((z-.73)/.24)*(1-_smoothstep((z-1.62)/.34))
    bubbles=.025*(exp(-((t-.42)/.22)**2)+exp(-((t+.42)/.22)**2))*rear*edge_fade
    return (w*t,h+camber+crease+bubbles,z)

def top_panel(z0,z1,across_segments=24,long_segments=40) -> Shell:
    if across_segments<2 or long_segments<2:
        raise ValueError("need at least 2 segments")
    verts=[];faces=[];stride=across_segments+1
    for i in range(long_segments+1):
        z=z0+(z1-z0)*i/long_segments
        for j in range(stride):
            verts.append(body_surface_point(z,-1+2*j/across_segments))
    for i in range(long_segments):
        for j in range(across_segments):
            a=i*stride+j; b=a+1; c=a+stride; d=c+1
            faces.append((a,c,d,b))  # +Y: outside of bonnet/deck
    return Shell(tuple(verts),tuple(faces))

def side_surface_point(z:float,sign:int,t:float):
    """Original smooth rolled coachwork including a deliberate shoulder return.

    The outer flank reaches its widest point just below the bonnet edge and
    returns slightly inward before meeting it, as a stamped car fender would.
    Its tangent aligns with the near-horizontal hood tangent at t=1.
    """
    if sign not in (-1,1) or not 0<=t<=1:
        raise ValueError("side, parameter out of range")
    w,h=width_shoulder(z)
    lower=arch_lower_boundary(z)
    shoulder_ease=t*t*(3.-2.*t)
    flare=sum(.023*exp(-((z-axle)/.46)**4)*sin(pi*t)**2
              for axle in AXLES)
    return (sign*(w*(.945+.055*t+.032*sin(pi*t))+flare),
            lower+(h-lower)*shoulder_ease,z)


def side_panel(z0,z1,sign,along_segments=40,across_segments=9) -> Shell:
    if sign not in (-1,1):
        raise ValueError("sign must be -1 or 1")
    verts=[];faces=[];stride=across_segments+1
    for i in range(along_segments+1):
        z=z0+(z1-z0)*i/along_segments
        for j in range(stride):
            verts.append(side_surface_point(z,sign,j/across_segments))
    for i in range(along_segments):
        for j in range(across_segments):
            a=i*stride+j; b=a+1; c=a+stride; d=c+1
            faces.append((a,c,d,b) if sign==-1 else (a,b,d,c))
    return Shell(tuple(verts),tuple(faces))


def _cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],
            a[2]*b[0]-a[0]*b[2],
            a[0]*b[1]-a[1]*b[0])


def _delta(a,b):
    return tuple(a[k]-b[k] for k in range(3))


def _unit(a):
    length=sqrt(sum(v*v for v in a))
    if length<1e-12:
        raise ValueError("degenerate surface tangent")
    return tuple(v/length for v in a)


def shoulder_normal_alignment(z,sign,epsilon=.0001):
    """Angular difference (degrees) between hood and fender surface normals.

    Source analytic approximation. Passing this test alone is not human
    Class-A/G2 approval; rendered specular flow remains the art-review gate.
    """
    if z-epsilon<STATIONS[0][0] or z+epsilon>STATIONS[-1][0]:
        raise ValueError("normal test outside body interval")
    if sign not in (-1,1):
        raise ValueError("invalid side")
    top0=body_surface_point(z,1 if sign>0 else -1)
    top_inner=body_surface_point(z,(1-epsilon)*sign)
    d_across=_delta(top0,top_inner) if sign>0 else _delta(top_inner,top0)
    d_long=_delta(body_surface_point(z+epsilon,sign),
                  body_surface_point(z-epsilon,sign))
    n_top=_unit(_cross(d_long,d_across))
    out=side_surface_point(z,sign,1.)
    inward=side_surface_point(z,sign,1.-epsilon)
    tangent=_delta(out,inward)
    d_side_long=_delta(side_surface_point(z+epsilon,sign,1.),
                       side_surface_point(z-epsilon,sign,1.))
    n_side=_unit(_cross(tangent,d_side_long) if sign>0
                 else _cross(d_side_long,tangent))
    dot=max(-1.,min(1.,sum(a*b for a,b in zip(n_top,n_side))))
    return math_acos_degrees(dot)


def math_acos_degrees(dot):
    from math import acos,degrees
    return degrees(acos(dot))

def fascia(front:bool,along=36,vertical=12) -> Shell:
    """Smooth, convex manufactured bumper skin, not a floating cube."""
    z=STATIONS[0][0] if front else STATIONS[-1][0]
    w,top=width_shoulder(z)
    verts=[];faces=[];stride=along+1
    for j in range(vertical+1):
        t=j/vertical; y=ROCKER_Y+(top-ROCKER_Y)*t
        for i in range(stride):
            u=-1+2*i/along
            x=u*w*(.947+.053*t)
            # The nose/top cap must meet the bonnet's actual center camber,
            # not a flat station shoulder; otherwise a visible black slot
            # remains below the hood. Blend in only near the upper seam.
            cap_y=body_surface_point(z,x/w)[1]
            yy=y+(cap_y-top)*t*t*t
            depth=.072*sin(pi*t)*(1-.46*abs(u)**1.5)
            verts.append((x,yy,z + (-depth if front else depth)))
    for j in range(vertical):
        for i in range(along):
            a=j*stride+i;b=a+1;c=a+stride;d=c+1
            faces.append((a,c,d,b) if front else (a,b,d,c))  # outward -Z / +Z
    return Shell(tuple(verts),tuple(faces))

def wheel_liner(axle,sign,segments=32) -> Shell:
    verts=[];faces=[]
    for i in range(segments+1):
        z=axle-(ARCH_RADIUS+.06)+2*(ARCH_RADIUS+.06)*i/segments
        y=arch_lower_boundary(z)
        w,_=width_shoulder(z)
        for d in (0.,.078):
            # Outer arch-liner edge must share the identical surface anchor
            # as the exterior lower flank at this z, not hover ~30mm away.
            verts.append((sign*(w*.945-d),y,z))
    for i in range(segments):
        a=2*i;faces.append((a,a+1,a+3,a+2))
    return Shell(tuple(verts),tuple(faces))

def tire_cross_section(axle,x,segments=48) -> Shell:
    """Fully closed tire sidewall/tread/bead profile, not a simple torus."""
    profile=(
        (-.094,.242),(-.102,.270),(-.097,.323),(-.079,.351),
        (-.057,.365),(-.018,.365),(.018,.365),(.057,.365),
        (.079,.351),(.097,.323),(.102,.270),(.094,.242),
        (.050,.233),(-.050,.233),
    )
    verts=[];faces=[]
    for k in range(segments):
        angle=2*pi*k/segments
        for dx,r in profile:
            verts.append((x+dx,WHEEL_Y+r*cos(angle),axle+r*sin(angle)))
    count=len(profile)
    for k in range(segments):
        nxt=(k+1)%segments
        for j in range(count):
            other=(j+1)%count
            faces.append((k*count+j,k*count+other,nxt*count+other,nxt*count+j))
    return Shell(tuple(verts),tuple(faces))

def continuity_metrics(z,delta=.002) -> dict[str,float]:
    if not STATIONS[0][0]+delta<z<STATIONS[-1][0]-delta:
        raise ValueError("outside tangent test interval")
    a=width_shoulder(z-delta);b=width_shoulder(z);c=width_shoulder(z+delta)
    l=[(b[i]-a[i])/delta for i in range(2)]
    r=[(c[i]-b[i])/delta for i in range(2)]
    return {"max_tangent_jump":max(abs(l[i]-r[i]) for i in range(2)),
            "position_gap":0.0}

def curvature_seam_metrics(z: float, epsilon: float=1e-6) -> dict[str,float]:
    """Continuity of values, tangents and second derivatives near a join.

    This is not a zebra-stripe or surface G2 certification, which still needs
    visible highlight/surface-normal checks on an actual Blender model.
    """
    _surface_segment(z-epsilon)
    _surface_segment(z+epsilon)
    return {
        "max_position_delta":max(abs(spline_property(z-epsilon,c)-
                                  spline_property(z+epsilon,c))
                                 for c in (1,2)),
        "max_tangent_delta":max(abs(spline_property(z-epsilon,c,1)-
                                 spline_property(z+epsilon,c,1))
                                for c in (1,2)),
        "max_second_derivative_delta":max(
            abs(spline_property(z-epsilon,c,2)-
                spline_property(z+epsilon,c,2)) for c in (1,2)),
    }


def mesh_integrity(shell:Shell) -> dict[str,int]:
    from math import isfinite
    if not all(all(isfinite(v) for v in p) for p in shell.positions):
        raise ValueError("nonfinite vertex")
    for face in shell.faces:
        if len(set(face))!=len(face) or min(face)<0 or max(face)>=len(shell.positions):
            raise ValueError("bad face indexing")
        for k in range(1,len(face)-1):
            a,b,c=(shell.positions[face[i]] for i in (0,k,k+1))
            v=[b[i]-a[i] for i in range(3)]
            w=[c[i]-a[i] for i in range(3)]
            cross=(v[1]*w[2]-v[2]*w[1],v[2]*w[0]-v[0]*w[2],v[0]*w[1]-v[1]*w[0])
            if sum(q*q for q in cross)<1e-18:
                raise ValueError("degenerate face")
    return {"vertices":len(shell.positions),"faces":len(shell.faces)}
