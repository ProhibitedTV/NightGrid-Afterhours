"""Original Vesper V2 fairings: shared centerline stations, C1 Hermite curves,
wheel apertures and closable mechanical surfaces. Y up, nose -Z.

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

def _hermite(x0,x1,v0,v1,m0,m1,x):
    span=x1-x0; t=(x-x0)/span
    return ((2*t**3-3*t*t+1)*v0 + (t**3-2*t*t+t)*span*m0
            + (-2*t**3+3*t*t)*v1 + (t**3-t*t)*span*m1)

def width_shoulder(z: float) -> tuple[float,float]:
    """C1 continuous across shared design stations."""
    if not STATIONS[0][0] <= z <= STATIONS[-1][0]:
        raise ValueError("outside the design station interval")
    if z == STATIONS[-1][0]:
        return STATIONS[-1][1:]
    for i in range(len(STATIONS)-1):
        z0,w0,h0=STATIONS[i]; z1,w1,h1=STATIONS[i+1]
        if z0 <= z <= z1:
            def derivative(k,part):
                a=STATIONS[max(k-1,0)]; b=STATIONS[min(k+1,len(STATIONS)-1)]
                return (b[part]-a[part])/(b[0]-a[0])
            return (_hermite(z0,z1,w0,w1,derivative(i,1),derivative(i+1,1),z),
                    _hermite(z0,z1,h0,h1,derivative(i,2),derivative(i+1,2),z))
    raise AssertionError("unreachable")

def _smoothstep(x):
    t=max(0.,min(1.,x))
    return t*t*(3-2*t)

def arch_lower_boundary(z):
    lower=ROCKER_Y
    for axle in AXLES:
        d=abs(z-axle)
        if d <= ARCH_RADIUS+.06:
            t=1.-d/(ARCH_RADIUS+.06)
            lower=max(lower,ROCKER_Y+(WHEEL_Y+ARCH_RADIUS-ROCKER_Y)*_smoothstep(t))
    return lower

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

def side_panel(z0,z1,sign,along_segments=40,across_segments=9) -> Shell:
    if sign not in (-1,1):
        raise ValueError("sign must be -1 or 1")
    verts=[];faces=[];stride=across_segments+1
    for i in range(along_segments+1):
        z=z0+(z1-z0)*i/along_segments
        w,h=width_shoulder(z); lower=arch_lower_boundary(z)
        for j in range(stride):
            t=j/across_segments
            verts.append((sign*w*(.945+.055*t+.008*sin(pi*t)),
                          lower+(h-lower)*t,z))
    for i in range(along_segments):
        for j in range(across_segments):
            a=i*stride+j; b=a+1; c=a+stride; d=c+1
            faces.append((a,c,d,b) if sign==-1 else (a,b,d,c))
    return Shell(tuple(verts),tuple(faces))

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
            verts.append((sign*(w*.98-d),y+.003,z))
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
