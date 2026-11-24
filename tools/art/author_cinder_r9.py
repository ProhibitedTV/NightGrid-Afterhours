"""Author the Cinder R9 body and wheels in metres, with Godot forward along -Z."""

from collections import defaultdict
from dataclasses import dataclass, field
from math import cos, pi, sin, sqrt
from pathlib import Path
import json
import struct
import sys
import zlib
from hashlib import sha256

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from author_kestrel_fascia import Surface, write_model


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/nightgrid/road_cars'
PAINT, DARK, ALLOY, GLASS, SEAT, LEATHER, HEAD, TAIL, REVERSE, BELT, TYRE, CARBON, TITANIUM, OPTIC, UNDER = range(15)
SEAM, GRILLE, PROJECTOR, FORGED, REFLECTOR = range(15, 20)
CALIPER = 20
SIDE_ROWS = (0., .09, .22, .35, .49, .66, .81, .93, 1.)
# The visible wheel-arch lip follows a circular tire clearance envelope,
# then returns smoothly to the rocker. Width includes the rocker transition.
ARCH_WIDTH = .520
ARCH_CIRCLE_JOIN = .340
ARCH_CLEARANCE_RADIUS = .415  # .358m tyre + 57 mm axial-straight clearance; >=40mm under steering sweep
ARCH_TIRE_CENTER_Y = .358


@dataclass
class Mesh:
    positions: list = field(default_factory=list)
    normals: list = field(default_factory=list)
    texcoords: list = field(default_factory=list)
    indices: list = field(default_factory=list)

    def face(self, points, desired, tint=(1, 1, 1, 1), uvs=None):
        a, b, c = points[:3]
        u, v = ([one - other for one, other in zip(point, a)] for point in (b, c))
        cross = (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0])
        reverse = sum(left * right for left, right in zip(cross, desired)) < 0.0
        length = sqrt(sum(value * value for value in cross))
        if length < 1e-10:
            return
        normal = tuple(value / length * (-1 if reverse else 1) for value in cross)
        start = len(self.positions)
        self.positions.extend(points)
        self.normals.extend([normal] * len(points))
        if uvs is None:
            direction = max(range(3), key=lambda index: abs(normal[index]))
            first, second = [(2, 1), (0, 2), (0, 1)][direction]
            uvs = [(p[first] * .33, p[second] * .33) for p in points]
        self.texcoords.extend(uvs)
        for index in range(1, len(points) - 1):
            triangle = (0, index + 1, index) if reverse else (0, index, index + 1)
            self.indices.extend(start + offset for offset in triangle)





@dataclass(frozen=True)
class Body:
    name: str
    length: float
    roof: float
    roof_width: float
    radius: float
    axles: tuple
    roof_band: tuple
    glass: tuple
    doors: tuple
    sill: float
    seat: tuple
    panels: tuple  # longitudinal station, half width, shoulder height


R9 = Body('cinder_r9', 4.66, 1.31, .639, .358, (-1.43, 1.44), (-.34, .39), (-1.16, 1.25),
         (-.97, .87), .16, (.40, -.30),
         ((-2.33, .829, .487), (-2.18, .908, .558), (-1.92, .960, .675), (-1.49, .991, .806),
          (-1.14, .966, .819), (-.75, .925, .792), (.06, .899, .785), (.71, .973, .831),
          (1.43, 1.012, .890), (1.79, 1.002, .862), (2.11, .971, .804), (2.33, .884, .754)))


def mix(a, b, t):
    return a + (b - a) * t


def ease(first, last, at):
    t = min(1., max(0., (at-first)/(last-first)))
    return t*t*(3.-2.*t)


def interpolate(rows, z):
    def gradient(index, channel):
        def segment(i):
            return (rows[i+1][channel] - rows[i][channel]) / (rows[i+1][0] - rows[i][0])
        if index == 0:
            return segment(0)
        if index == len(rows)-1:
            return segment(index-1)
        before, after = segment(index-1), segment(index)
        return 2.0*before*after/(before+after) if before*after > 0 else 0.0

    for i, (low, high) in enumerate(zip(rows, rows[1:])):
        if z <= high[0]:
            span = high[0] - low[0]
            t = max(0.0, (z - low[0]) / span)
            blend = t*t*(3-2*t)
            return tuple(mix(low[c], high[c], blend) + span*t*(1-t)*((1-t)*gradient(i,c)-t*gradient(i+1,c))
                         for c in range(1, len(low)))
    return rows[-1][1:]


def arch_minimum(body, z):
    """C1 wheel opening with 57 mm straight-ahead gap, protecting full steering lock.

    The old fractional-power semiellipse became tangent-discontinuous at
    +/-ARCH_WIDTH. That generated a pinched lower fender and open-ended inner
    arch lip in oblique/reflection views. The close wheel arc is a true
    circular offset; a cubic Hermite return matches its tangent to the sill.
    """
    distance = min(abs(z-axle) for axle in body.axles)
    if distance <= ARCH_CIRCLE_JOIN:
        return ARCH_TIRE_CENTER_Y + sqrt(ARCH_CLEARANCE_RADIUS**2-distance**2)
    if distance >= ARCH_WIDTH:
        return body.sill
    span = ARCH_WIDTH-ARCH_CIRCLE_JOIN
    t = (distance-ARCH_CIRCLE_JOIN)/span
    center = sqrt(ARCH_CLEARANCE_RADIUS**2-ARCH_CIRCLE_JOIN**2)
    first = ARCH_TIRE_CENTER_Y+center
    tangent = -ARCH_CIRCLE_JOIN/center
    return ((2*t**3-3*t*t+1)*first
            +(t**3-2*t*t+t)*span*tangent
            +(-2*t**3+3*t*t)*body.sill)


def belt(body, z):
    width, y = interpolate(body.panels, z)
    return width - .046, y - .026


def end_sweep(z, lateral):
    # Wrap the painted nose and tail into the shoulders using the same
    # longitudinal mapping for the bumper, deck and quarter panels.
    wrap = .135*(1.-ease(-2.33,-1.93,z)) - .115*ease(1.96,2.33,z)
    return z + wrap*abs(lateral)**2.65


def side_profile(body, z, side):
    width, shoulder = interpolate(body.panels, z)
    bottom = min(shoulder-.044, arch_minimum(body,z))
    between_axles = ease(-1.24,-.70,z)*(1.-ease(.75,1.30,z))
    intake_draw = ease(.21,.86,z)*(1.-ease(.97,1.22,z))
    wheel_opening = ease(.24,.72,bottom)
    profile = (-.073+.055*wheel_opening,-.042+.038*wheel_opening,
               -.060+.021*wheel_opening,-.081,-.068,-.029,0.,-.019,-.047)
    cove = (0.,0.,.012,.039,.053,.027,0.,0.,0.)
    scoop = (0.,0.,.012,.027,.019,0.,0.,0.,0.)
    return [(side*(width+shape-cove[i]*between_axles-scoop[i]*intake_draw),
             mix(bottom,shoulder,column),end_sweep(z,side))
            for i,(column,shape) in enumerate(zip(SIDE_ROWS,profile))]


def cabin_width(body, z):
    mid = sum(body.roof_band)*.5
    return body.roof_width - .077*((z-mid)/.52)**2


def roof_skin(body, lateral, z):
    return (cabin_width(body,z)*lateral,
            body.roof-.067*abs(lateral)**2.35-.034*((z-.015)/.49)**2,z)


def canopy(body, z, side):
    first, last = body.roof_band
    front, rear = body.glass
    if z < first:
        t = max(0.0, (z - front) / (first - front))
        x, y = belt(body, front)
        top = roof_skin(body,side,first)
        return mix(x*side,top[0],t), mix(y,top[1],t)+.045*sin(pi*t), z
    if z > last:
        t = min(1.0, (z - last) / (rear - last))
        x, y = belt(body, rear)
        top = roof_skin(body,side,last)
        return mix(top[0],x*side,t), mix(top[1],y,t)+.032*sin(pi*t), z
    return roof_skin(body,side,z)


def quad(surface, a, b, c, d, normal, tint=(1, 1, 1, 1)):
    points = tuple(dict.fromkeys((a, b, c, d)))
    if len(points) > 2:
        surface.face(points, normal, tint)


def skin(mesh, first, last, outward, tint=(1, 1, 1, 1)):
    for across in range(len(first) - 1):
        quad(mesh, first[across], last[across], last[across+1], first[across+1], outward, tint)


def tube(mesh, start, end, radius, segments, tint=(1, 1, 1, 1)):
    direction = normalize(tuple(b-a for a, b in zip(start, end)))
    reference = (0., 0., 1.) if abs(direction[2]) < .8 else (0., 1., 0.)
    first = normalize(cross(direction, reference))
    second = cross(direction, first)
    rings = []
    for anchor in (start, end):
        rings.append([tuple(v + radius * (a*cos(i*2*pi/segments) + b*sin(i*2*pi/segments))
                            for v, a, b in zip(anchor, first, second)) for i in range(segments)])
    for i in range(segments):
        n = (i+1) % segments
        outward = tuple(a-b for a,b in zip(rings[0][i], start))
        quad(mesh, rings[0][i], rings[0][n], rings[1][n], rings[1][i], outward, tint)
    for ring, normal in zip(rings, [tuple(-d for d in direction), direction]):
        mesh.face(ring, normal, tint)


def windshield_pillar(paint, seal, start, end, glass_normal, side, width):
    """Tapered stamped rail with a recessed glazing channel."""
    axis = normalize(tuple(b - a for a, b in zip(start, end)))
    crosswise = normalize(cross(glass_normal, axis))
    if crosswise[0] * side < 0:
        crosswise = tuple(-value for value in crosswise)
    face = normalize(cross(axis, crosswise))
    if sum(x * y for x, y in zip(face, glass_normal)) < 0:
        face = tuple(-value for value in face)
    section = [(-.67, .020), (-.28, .038), (.54, .032), (.72, .008),
               (.67, -.044), (.40, -.060), (-.42, -.048), (-.69, -.024)]
    outer, inner = [
        [tuple(p + a * width * taper * u + b * v for p, u, v in zip(point, crosswise, face))
         for a, b in section]
        for point, taper in [(start, 1.0), (end, .83)]
    ]
    for index in range(len(section)):
        following = (index + 1) % len(section)
        midpoint = tuple((a + b) * .5 - p for a, b, p in zip(outer[index], outer[following], start))
        quad(seal if index in (0, 6, 7) else paint,
             outer[index], inner[index], inner[following], outer[following], midpoint)
    for ring, sign in ((outer, -1), (inner, 1)):
        seal.face(ring, tuple(sign * value for value in axis))


def cross(a, b):
    return a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]


def normalize(a):
    length = sqrt(sum(x*x for x in a))
    return tuple(x / length for x in a)


def unify_normals(mesh, threshold=.62):
    """Soften the adjacent samples while retaining the hard panel edges."""
    groups = defaultdict(list)
    for p, n in zip(mesh.positions, mesh.normals):
        groups[tuple(round(v, 5) for v in p)].append(n)
    normals = []
    for p, base in zip(mesh.positions, mesh.normals):
        cluster = groups[tuple(round(v, 5) for v in p)]
        matches = [n for n in cluster if sum(a*b for a, b in zip(base, n)) > threshold]
        normals.append(normalize(tuple(sum(n[i] for n in matches) for i in range(3))))
    mesh.normals = normals


def ellipsoid(mesh, at, size, tint=(1, 1, 1, 1), rings=7, segments=14):
    def ring(index):
        latitude = mix(-pi*.5+.035, pi*.5-.035, index / rings)
        return [(at[0]+cos(latitude)*cos(i*2*pi/segments)*size[0], at[1]+sin(latitude)*size[1],
                 at[2]+cos(latitude)*sin(i*2*pi/segments)*size[2]) for i in range(segments)]
    previous = ring(0)
    mesh.face(previous, (0, -1, 0), tint)
    for layer in range(1, rings+1):
        current = ring(layer)
        for index in range(segments):
            next_index = (index+1) % segments
            desired = tuple(v-c for v,c in zip(current[index], at))
            quad(mesh, previous[index], previous[next_index], current[next_index], current[index], desired, tint)
        previous = current
    mesh.face(previous, (0, 1, 0), tint)


def compartment(body, surfaces):
    dark, seat, leather, alloy = [surfaces[index] for index in (DARK, SEAT, LEATHER, ALLOY)]
    front, rear = body.glass
    floor = body.sill + .10
    quad(dark, (-.83, floor, front), (.83, floor, front), (.83, floor, rear), (-.83, floor, rear), (0, 1, 0))
    for at, facing in ((front, -1), (rear, 1)):
        w, h = belt(body, at)
        quad(dark, (-w, floor, at), (w, floor, at), (w, h, at), (-w, h, at), (0, 0, facing))
    base = belt(body, front)[1]
    ellipsoid(dark, (0, base-.115, front+.04), (.81, .145, .235))
    ellipsoid(leather, (0, body.seat[0]-.08, .10), (.132, .159, .775))
    ellipsoid(surfaces[BELT], (-.44, base-.055, front+.212), (.202, .046, .044))
    wheel_center = (-.45, base-.04, front+.43)
    rim = [(wheel_center[0]+.171*cos(i*2*pi/18), wheel_center[1]+.171*sin(i*2*pi/18),
            wheel_center[2]+.032*sin(i*2*pi/18)) for i in range(18)]
    for index in range(18):
        tube(leather, rim[index], rim[(index+1) % 18], .019, 6)
    tube(alloy, wheel_center, (wheel_center[0], wheel_center[1], front+.1), .050, 9)
    for index in [0, 6, 11]:
        tube(alloy, wheel_center, rim[index], .019, 6)
    cushion,where = body.seat
    for x in [-.465, .465]:
        ellipsoid(seat, (x, cushion-.013, where-.05), (.263, .071, .307))
        ellipsoid(seat, (x, cushion+.263, where+.212), (.267, .338, .099))
        ellipsoid(seat, (x, cushion+.488, where+.242), (.122, .126, .099))
        for sign in [-1, 1]:
            ellipsoid(leather, (x+sign*.219, cushion+.027, where-.048), (.060, .060, .273), rings=4)
            ellipsoid(leather, (x+sign*.190, cushion+.250, where+.147), (.052, .257, .065), rings=4)


def window_patch(mesh, a, b, left, right, outward):
    # Glass channels sit within the seals, with their lower edge inside the trim.
    def slide(p, q, f):
        return tuple(mix(x, y, f) for x, y in zip(p, q))
    quad(mesh, slide(a, left, .016), slide(b, right, .016), slide(right, b, .034), slide(left, a, .034), outward)


def door(surfaces, body, side, interval):
    first, last = interval
    chunks = 24
    positions = [mix(first, last, i/chunks) for i in range(chunks+1)]
    paint, dark, glass, leather = [surfaces[index] for index in (PAINT, DARK, GLASS, LEATHER)]
    for a, b in zip(positions, positions[1:]):
        left, right = side_profile(body, a, side), side_profile(body, b, side)
        skin(paint, left[1:], right[1:], (side, 0, 0))
        interior_a = [(x-side*.075, y, z) for x, y, z in left[1:]]
        interior_b = [(x-side*.075, y, z) for x, y, z in right[1:]]
        skin(leather, interior_a, interior_b, (-side, 0, 0))
        quad(dark, left[-1], right[-1], interior_b[-1], interior_a[-1], (0, 1, 0))
        quad(dark, left[1], right[1], interior_b[0], interior_a[0], (0, -1, 0))
        top_a, top_b = canopy(body, a, side), canopy(body, b, side)
        window_patch(glass, left[-1], right[-1], top_a, top_b, (side, 0, 0))
    for point, facing in ((first, -1), (last, 1)):
        outside = side_profile(body, point, side)[1:]
        inside = [(x-side*.075, y, z) for x, y, z in outside]
        skin(dark, outside, inside, (0, 0, facing))
    at = last-.208
    for tap in range(6):
        a,b = (mix(at-.071,at+.071,i/6) for i in (tap,tap+1))
        p,q = [side_profile(body,z,side)[6] for z in (a,b)]
        reach = .011*sin(pi*(tap+.5)/6)
        quad(surfaces[SEAM],(p[0]+side*.002,p[1]+reach,p[2]),(q[0]+side*.002,q[1]+reach,q[2]),
             (q[0]+side*.002,q[1]-.010,q[2]),(p[0]+side*.002,p[1]-.010,p[2]),(side,0,0))
        quad(paint,(p[0]+side*.004,p[1]+reach-.003,p[2]),(q[0]+side*.004,q[1]+reach-.003,q[2]),
             (q[0]+side*.004,q[1]-.004,q[2]),(p[0]+side*.004,p[1]-.004,p[2]),(side,0,0))
    if first < -.68:
        x, waist = belt(body, first + .18)
        tube(dark,(side*x,waist+.050,first+.18),(side*(x+.106),waist+.132,first+.127),.022,8)
        ellipsoid(paint,(side*(x+.141),waist+.151,first+.111),(.095,.044,.094),rings=7,segments=18)
        ellipsoid(surfaces[GRILLE],(side*(x+.141),waist+.151,first+.181),(.077,.033,.018),rings=5)
        ellipsoid(surfaces[ALLOY],(side*(x+.141),waist+.151,first+.191),(.071,.029,.007),rings=5)


HALF_DECK = (0., .10, .21, .25, .32, .39, .429, .451, .458, .48, .56, .64, .71, .77, .83, .88, .92, .96, 1.)
DECK_COLS = tuple(-u for u in reversed(HALF_DECK[1:])) + HALF_DECK
HEAD_Z = (-2.253, -1.774)
DUCT_Z = (-1.718, -1.337)
BONNET_Z = (-2.280, -1.190)
LOUVRE_Z = tuple((1.278+i*.095, 1.317+i*.095) for i in range(7))
SIDE_INTAKE = (.891, 1.013)


def on_deck(body, lateral, z, offset=0.):
    width, shoulder = interpolate(body.panels,z)
    edge = abs(lateral)
    if z < body.glass[0]:
        fore = ease(-2.315,-2.105,z)
        taper = ease(-2.173,-1.774,z)
        trail = 1.-ease(-1.77,-1.18,z)
        # Swept polycarbonate assembly broad at the leading end, pinched
        # into the shoulder at the aft tip. The paint uses the same outline.
        inner = .48 + (.024*fore + .153*taper)*trail
        outer = .96 - (.035*(1.-fore)+.010*taper)*trail
        edge, = interpolate(((0.,0.),(.325,.325),(.48,inner),(.96,outer),(1.,1.)),edge)
        feature = ease(-2.32,-1.99,z)*(1.-ease(-1.61,-1.16,z))
        fender = .046*feature*sin(pi*ease(.35,1.,edge))**2
        crown = 1.-mix(edge**1.6,edge**2,feature)
        bonnet = (.028+.005*feature)*crown
        bulge = .010*(1.-ease(.18,.58,edge))*feature
        height = shoulder + fender + bonnet + bulge
    else:
        height = shoulder + .028*(1.-edge**1.6)
    return ((width-.047)*edge*(-1 if lateral < 0 else 1),height+offset,end_sweep(z,edge))


def cap(body, surfaces, side, z):
    cols = DECK_COLS
    rows = sorted({*SIDE_ROWS, .10, .20, .29, .38, .52, .67, .73, .79, .87, .92, .964})
    profile = side_profile(body, z, 1)
    edge = [(v,x,y) for v,(x,y,_) in zip(SIDE_ROWS,profile)]

    def edge_at(v):
        for (a,x,y),(b,u,w) in zip(edge,edge[1:]):
            if v <= b:
                t = (v-a)/(b-a)
                return mix(x,u,t),mix(y,w,t)
        raise ValueError('Fascia edge outside the side panel')

    def point(u, v, recess=0.):
        if v >= .999:
            return on_deck(body, u, z)
        radius = abs(u)
        width, edge_y = edge_at(v)
        blend = sin(pi*v)*(1.-radius**5)
        squeeze = (1.-.12*(v-.39)*blend) if side < 0 else (1.+.037*blend)
        x = u*width*squeeze
        top = on_deck(body, u, z)[1]
        low = profile[0][1]-.026*(1.-radius**2)
        tuck = (.066 if side < 0 else .063)*(1.-radius**3)*(1.-v)**1.85
        brow = (.031 if side < 0 else .018)*blend*sin(pi*v*1.11)
        rake = sin(pi*v)*sin(pi*radius)*(-.046 if side < 0 else .024)
        height = mix(mix(low,top,v),edge_y,radius**7) + rake
        return (x,height,end_sweep(z,u)-side*(tuck-brow+recess))

    def channel(u, v):
        edge = abs(u)
        if side < 0 and .20 < v < .67:
            if edge < .48 or .64 < edge < .88:
                return 'intake'
        if side > 0:
            if .67 < v < .92 and .25 < edge < .96:
                return 'lamp'
            if v < .38 and edge < .88:
                return 'diffuser'
            if .38 < v < .67 and edge < .25:
                return 'plate'
        return 'skin'

    normal = (0, 0, side)
    for u, w in zip(cols, cols[1:]):
        for v, h in zip(rows, rows[1:]):
            part = channel((u+w)*.5, (v+h)*.5)
            if part != 'skin':
                continue
            material = CARBON if h <= (.20 if side < 0 else .10) else PAINT
            quad(surfaces[material], point(u,v), point(w,v), point(w,h), point(u,h), normal)

    def socket(a, b, c, d, depth, material):
        border = sorted({a, b, *(t for t in cols if a < t < b)})
        for u,v in zip(border, border[1:]):
            # Match all perimeter vertices at the edge of the cut.
            for high, direction in ((c,-1),(d,1)):
                quad(surfaces[material], point(u,high), point(v,high),
                     point(v,high-direction*.018,depth), point(u,high-direction*.018,depth), normal)
            quad(surfaces[DARK], point(u,c+.018,depth), point(v,c+.018,depth),
                 point(v,d-.018,depth), point(u,d-.018,depth), normal)
        for width, direction in ((a,-1),(b,1)):
            edge = sorted({c, d, *(t for t in rows if c < t < d)})
            for v,h in zip(edge, edge[1:]):
                quad(surfaces[material], point(width,v), point(width,h),
                     point(width-direction*.016,h,depth), point(width-direction*.016,v,depth), normal)

    def strip(material, x0, x1, center, thickness, depth):
        segments = max(2, round(abs(x1-x0)*14))
        for index in range(segments):
            a,b = (mix(x0,x1,i/segments) for i in (index,index+1))
            va,vb = center,center
            if callable(center):
                va,vb = center(a),center(b)
            quad(surfaces[material], point(a,va,depth), point(b,vb,depth),
                 point(b,vb+thickness,depth), point(a,va+thickness,depth), normal)

    if side < 0:
        for a,b in ((-.48,.48), (-.88,-.64), (.64,.88)):
            socket(a,b,.20,.67,.145,CARBON)
            for i in range(7):
                strip(GRILLE,a+.018,b-.018,.233+i*.059,.012,.122)
            dividers = 11 if a == -.48 else 3
            for i in range(1,dividers):
                u = mix(a,b,i/dividers)
                quad(surfaces[GRILLE],point(u-.005,.228,.127),point(u+.005,.228,.127),
                     point(u+.005,.649,.127),point(u-.005,.649,.127),normal)
        # Recessed centre badge and small outboard parking sensors follow the skin.
        nose = [point(u,v,-.003) for u,v in ((-.047,.87),(0,.816),(.047,.87),(0,.924))]
        surfaces[GRILLE].face(nose,normal)
        surfaces[ALLOY].face([point(u,v,-.005) for u,v in ((-.032,.872),(0,.838),(.032,.872),(0,.905))],normal)
        for u in (-.94,-.548,.548,.94):
            x,y,p = point(u,.45,-.002)
            ellipsoid(surfaces[SEAM],(x,y,p),(.011,.010,.004),rings=4,segments=9)
        return
    for a,b in ((-.96,-.25), (.25,.96)):
        socket(a,b,.67,.92,.063,CARBON)

        def ribbon(u):
            corner = ease(.67,.89,abs(u))
            return .786 + .051*corner - .015*(1.-ease(.29,.45,abs(u)))

        strip(TAIL,a+.018,b-.018,ribbon,.037,.036)
        outside = (-.906,-.535) if a < 0 else (.535,.906)
        strip(TAIL,*outside,lambda u: ribbon(u)-.056,.029,.034)
        center = .412 if a > 0 else -.412
        strip(REVERSE,center-.075,center+.075,.719,.022,.032)
        strip(OPTIC,a+.015,b-.015,.694,.209,.009)
    socket(-.25,.25,.38,.67,.048,SEAM)
    strip(GRILLE,-.176,.176,.451,.152,.035)
    strip(ALLOY,-.143,.143,.560,.010,.031)
    for u in (-.96,.96):
        strip(REFLECTOR,u-.023,u+.023,.279,.056,-.002)
    socket(-.88,.88,0.,.38,.135,CARBON)
    for u in (-.75,-.57,-.37,.37,.57,.75):
        a,b = point(u,.045,.132), point(u,.30,.124)
        tip, top = point(u,.045,-.032), point(u,.24,-.011)
        for facing in (-1,1):
            shift = facing*.011
            verts = [(x+shift,y,z) for x,y,z in (a,b,top,tip)]
            surfaces[CARBON].face(verts,(facing,0,side))
        quad(surfaces[CARBON], (tip[0]-.011,*tip[1:]), (tip[0]+.011,*tip[1:]),
             (top[0]+.011,*top[1:]), (top[0]-.011,*top[1:]), normal)
    for x in (-.25,.25):
        exhaust(surfaces, x, .255, z)


def exhaust(surfaces, x, y, z):
    for i in range(20):
        a,b = (j*2*pi/20 for j in (i,i+1))

        def point(theta, scale, depth):
            return (x+.064*cos(theta)*scale,y+.037*sin(theta)*scale,z+depth)

        outer = [point(t,1.0,.016) for t in (a,b)]
        rim = [point(t,.83,.016) for t in (a,b)]
        back = [point(t,.83,-.105) for t in (a,b)]
        tail = [point(t,1.03,-.121) for t in (a,b)]
        direction = (cos(a),sin(a),.3)
        quad(surfaces[TITANIUM],*outer,tail[1],tail[0],direction)
        quad(surfaces[TITANIUM],*outer,rim[1],rim[0],(0,0,1))
        quad(surfaces[DARK],*rim,back[1],back[0],(-direction[0],-direction[1],0))
        surfaces[DARK].face([*back,(x,y,z-.105)],(0,0,1))


def deck_opening(surfaces, body, sign, a, b, low, high, kind):
    a,b = round(a,6),round(b,6)
    cols = [u for u in DECK_COLS if low <= sign*u <= high]
    # Use the same z rows as the top skin, keeping the entire lip welded visually.
    steps = [z for z in sampled_stations(body) if a <= z <= b]
    band_depth = -.115 if kind == 'head' else -.070

    # An automotive cover is a bonded polycarbonate shell, not a single
    # infinitely thin alpha-blended plane. Maintain the exact original
    # perimeter/curvature so the edge still meets the authored body recess.
    cover_thickness = .0036

    def cover_point(u,z):
        blend_u = (u-cols[0])/(cols[-1]-cols[0])
        blend_z = (z-a)/(b-a)
        crown = .011*sin(pi*blend_u)*sin(pi*blend_z)
        return on_deck(body,u,z,-.004+crown)

    def inside_cover_point(u,z):
        x,y,depth = cover_point(u,z)
        return x,y-cover_thickness,depth

    def bonded_cover_cell(u,v,start,end):
        # Upper and lower skins with deliberately opposing normals. A small
        # perimeter skirt creates an actual visible lens edge in close-ups.
        upper = [cover_point(t,z) for t,z in ((u,start),(u,end),(v,end),(v,start))]
        lower = [inside_cover_point(t,z) for t,z in ((u,start),(u,end),(v,end),(v,start))]
        quad(surfaces[OPTIC],*upper,(0,1,0))
        quad(surfaces[OPTIC],*reversed(lower),(0,-1,0))
        if u == cols[0]:
            quad(surfaces[OPTIC],upper[0],upper[1],lower[1],lower[0],(-1,0,0))
        if v == cols[-1]:
            quad(surfaces[OPTIC],upper[3],lower[3],lower[2],upper[2],(1,0,0))
        if start == steps[0]:
            quad(surfaces[OPTIC],upper[0],lower[0],lower[3],upper[3],(0,0,-1))
        if end == steps[-1]:
            quad(surfaces[OPTIC],upper[1],upper[2],lower[2],lower[1],(0,0,1))
    for start,end in zip(steps,steps[1:]):
        for u,direction in ((cols[0],1),(cols[-1],-1)):
            inner = u + direction*.011
            quad(surfaces[SEAM],on_deck(body,u,start),on_deck(body,u,end),
                 on_deck(body,inner,end,-.007),on_deck(body,inner,start,-.007),(0,1,0))
            quad(surfaces[CARBON],on_deck(body,inner,start,-.007),on_deck(body,inner,end,-.007),
                 on_deck(body,u+direction*.021,end,band_depth),
                 on_deck(body,u+direction*.021,start,band_depth),(0,1,0))
        for u,v in zip(cols, cols[1:]):
            quad(surfaces[DARK],on_deck(body,u,start,band_depth),on_deck(body,u,end,band_depth),
                 on_deck(body,v,end,band_depth),on_deck(body,v,start,band_depth),(0,1,0))
            if kind == 'head':
                bonded_cover_cell(u,v,start,end)
    for z,direction in ((a,1),(b,-1)):
        for u,v in zip(cols,cols[1:]):
            quad(surfaces[CARBON], on_deck(body,u,z), on_deck(body,v,z),
                 on_deck(body,v,z+direction*.012,band_depth),on_deck(body,u,z+direction*.012,band_depth),(0,1,0))
    if kind == 'head':
        # Two separately turned optic modules sit inside each bonded cover.
        for lateral,z,radius in ((.699,a+.125,.043),(.770,a+.244,.032)):
            projector(surfaces,on_deck(body,sign*lateral,z,-.063),radius)
        for start,end in zip(steps,steps[1:]):
            if start < a+.021 or end > b-.038:
                continue
            leading = 1.-ease(a+.026,a+.128,start)
            trailing = ease(b-.202,b-.054,start)
            side_line = .886-.178*leading+.011*trailing
            for material,edge,y in ((HEAD,0.,-.022),(GRILLE,.009,-.034)):
                u,v = sorted((sign*(side_line-edge),sign*(side_line+.018+edge)))
                lateral_b = sign*((.886-.178*(1.-ease(a+.026,a+.128,end))+.011*ease(b-.202,b-.054,end))-side_line)
                quad(surfaces[material],on_deck(body,u,start,y),on_deck(body,u+lateral_b,end,y),
                     on_deck(body,v+lateral_b,end,y),on_deck(body,v,start,y),(0,1,0))
        x,y,z = on_deck(body,sign*.886,a+.094,-.046)
        ellipsoid(surfaces[REFLECTOR],(x,y,z),(.015,.009,.044),rings=4,segments=10)
    elif kind == 'duct':
        for bend in (.21,.40,.59,.78):
            z = mix(a,b,bend)
            quad(surfaces[CARBON], on_deck(body,cols[0]+.02,z,-.059),
                 on_deck(body,cols[-1]-.02,z,-.059),on_deck(body,cols[-1]-.02,z+.025,-.033),
                 on_deck(body,cols[0]+.02,z+.025,-.033),(0,1,0))


def projector(surfaces, center, radius):
    axis = (0.,.74,-.673)
    x,y,z = center
    profile = ((1.30,-.041,DARK),(1.20,-.014,GRILLE),(1.02,.004,ALLOY),
               (.91,.008,ALLOY),(.81,.001,GRILLE),(.69,.004,PROJECTOR),
               (.36,.015,PROJECTOR),(.0,.019,PROJECTOR))
    rings = [[(x+radius*r*cos(i*pi/10), y+.673*radius*r*sin(i*pi/10)+d*axis[1],
               z+.74*radius*r*sin(i*pi/10)+d*axis[2]) for i in range(20)] for r,d,_ in profile]
    for i,(outer,inner) in enumerate(zip(rings,rings[1:])):
        material = surfaces[profile[i+1][2]]
        for j in range(20):
            k = (j+1)%20
            quad(material,outer[j],outer[k],inner[k],inner[j],axis)


def windscreen(body, surfaces, along, roof, facing):
    def point(lateral,t,extra=0.):
        x,y,z = on_deck(body,lateral,along,-.015)
        u,v,w = roof_skin(body,lateral,roof)
        crown = (1.-lateral**2)*sin(pi*t)
        return (mix(x,u,t),mix(y,v,t)+.025*crown+extra,
                mix(z,w,t)+facing*(.067*crown+extra*.72))

    normal = (0.,.6,facing)
    cols = (-1.,-.955,-.83,-.62,-.40,-.20,0.,.20,.40,.62,.83,.955,1.)
    rows = (0.,.055,.16,.30,.48,.64,.81,.938,1.)
    for a,b in zip(cols,cols[1:]):
        quad(surfaces[SEAM],on_deck(body,a,along),on_deck(body,b,along),point(b,0.),point(a,0.),normal)
        for u,v in zip(rows,rows[1:]):
            rubber = max(abs(a),abs(b)) == 1. or u == 0. or v == 1.
            material = SEAM if rubber else GLASS
            quad(surfaces[material],point(a,u),point(b,u),point(b,v),point(a,v),normal)
    for side in (-1,1):
        windshield_pillar(surfaces[PAINT],surfaces[SEAM],point(side,0.),roof_skin(body,side,roof),
                         normalize(normal),side,.052 if facing < 0 else .075)
    if facing < 0:
        for pivot,tip in [(-.67,-.15),(.20,.68)]:
            tube(surfaces[DARK],point(pivot,.028,.009),point(tip-.12,.156,.009),.008,5)
            for left in range(5):
                a,b = [mix(tip-.24,tip+.10,i/5) for i in (left,left+1)]
                tube(surfaces[DARK],point(a,.144,.010),point(b,.144,.010),.006,5)


def rear_aero(mesh, mounts, body):
    # Low cambered wing, tapered end sections and a pair of swept supports.
    chord = ((-.156,.0),(-.115,.016),(-.039,.023),(.049,.014),(.105,.005),(.111,.0),
             (.056,-.008),(-.047,-.009),(-.115,-.007),(-.156,0.))
    sections = []
    for x in (-.822,-.793,-.69,-.49,-.25,0.,.25,.49,.69,.793,.822):
        y = .961 + .022*(abs(x)/.822)**1.7
        scale = 1.-.21*(abs(x)/.822)**2
        sections.append([(x,y+height,2.062+offset*scale+.035*abs(x)) for offset,height in chord])
    for a,b in zip(sections,sections[1:]):
        for i in range(len(chord)-1):
            quad(mesh,a[i],b[i],b[i+1],a[i+1],(0,1 if i < 5 else -1,0))
    for ring,direction in ((sections[0],-1),(sections[-1],1)):
        mesh.face(ring[:-1],(direction,0,0))
    for sign in (-1,1):
        x = sign*.553
        bottom = on_deck(body,sign*.606,2.17,-.011)
        for shift,normal_x in ((-.020,-1),(.020,1)):
            braced = [(bottom[0]+shift,bottom[1],bottom[2]-.061),(x+shift,.958,2.014),
                      (x+shift,.955,2.076),(bottom[0]+shift,bottom[1]-.003,bottom[2]+.033)]
            mounts.face(braced,(normal_x,0,0))
        quad(mounts,(bottom[0]-.020,bottom[1],bottom[2]-.061), (bottom[0]+.020,bottom[1],bottom[2]-.061),
             (x+.020,.958,2.014),(x-.020,.958,2.014),(0,.3,-1))


def sampled_stations(body):
    hood,tail = body.glass
    limit = body.length*.5
    dimensions = {round(mix(-limit, limit, i/104.0),6) for i in range(105)}
    boundaries = [hood,tail,-limit,limit,*body.roof_band,*HEAD_Z,*DUCT_Z,*SIDE_INTAKE,
                  *BONNET_Z,BONNET_Z[0]+.006,BONNET_Z[1]-.006]
    boundaries.extend(z for pair in LOUVRE_Z for z in pair)
    boundaries.extend(e+margin for e in body.doors for margin in (-.005,.005))
    boundaries.extend(z for left,right in (HEAD_Z, DUCT_Z) for z in (left+.021,right-.038))
    for axle in body.axles:
        boundaries.extend(axle+ARCH_WIDTH*cos(i*pi/24.0) for i in range(25))
    return sorted(dimensions | {round(z,6) for z in boundaries})


def body_art(body):
    chassis, front, rear = ([Mesh() for _ in MATERIALS] for _ in range(3))
    hood, tail = body.glass
    limit = body.length*.5
    steps = sampled_stations(body)
    for a, b in zip(steps, steps[1:]):
        midpoint = (a+b)*.5
        pieces = front if midpoint < hood else (rear if midpoint > tail else chassis)
        inside_door = body.doors[0]-.005 < midpoint < body.doors[-1]+.005
        for side in [-1, 1]:
            first, last = side_profile(body, a, side), side_profile(body, b, side)
            rocker = CARBON if -.99 < midpoint < .97 else PAINT
            skin(pieces[rocker],first[:2],last[:2],(side,0,0))
            if not inside_door:
                if SIDE_INTAKE[0] < midpoint < SIDE_INTAKE[1]:
                    skin(pieces[PAINT], first[5:], last[5:], (side,0,0))
                    for i in (1,5):
                        p,q = first[i],last[i]
                        quad(pieces[CARBON],p,q,(q[0]-side*.095,*q[1:]),(p[0]-side*.095,*p[1:]),(side,0,0))
                    inner = lambda point: (point[0]-side*.095,*point[1:])
                    quad(pieces[DARK],inner(first[1]),inner(last[1]),inner(last[5]),inner(first[5]),(side,0,0))
                    for z,profile in ((a,first),(b,last)):
                        if z in SIDE_INTAKE:
                            quad(pieces[CARBON],profile[1],profile[5],inner(profile[5]),inner(profile[1]),(side,0,0))
                else:
                    skin(pieces[PAINT], first[1:], last[1:], (side, 0, 0))
            if first[0][1] > body.sill+.03 or last[0][1] > body.sill+.03:
                depth = .184
                poly = [first[0], last[0], (last[0][0]-side*depth, last[0][1]-.015, last[0][2]),
                        (first[0][0]-side*depth, first[0][1]-.015, first[0][2])]
                pieces[DARK].face(poly, (0, -1, 0))
        if pieces is not chassis:
            for u,v in zip(DECK_COLS,DECK_COLS[1:]):
                width = abs(u+v)*.5
                if HEAD_Z[0] < midpoint < HEAD_Z[1] and .48 < width < .96:
                    continue
                if DUCT_Z[0] < midpoint < DUCT_Z[1] and .25 < width < .429:
                    continue
                if any(left < midpoint < right for left,right in LOUVRE_Z) and .10 < width < .64:
                    continue
                channel = CARBON if pieces is rear and width < .64 and 1.25 < midpoint < 1.91 else PAINT
                bonnet_edge = .451 < width < .458 and BONNET_Z[0] < midpoint < BONNET_Z[1]
                bonnet_ends = width < .458 and (BONNET_Z[0] < midpoint < BONNET_Z[0]+.006
                                               or BONNET_Z[1]-.006 < midpoint < BONNET_Z[1])
                panel = [on_deck(body,width,z) for width,z in ((u,a),(u,b),(v,b),(v,a))]
                if bonnet_edge or bonnet_ends:
                    seam = [(x,y-.0035,z) for x,y,z in panel]
                    pieces[SEAM].face(seam,(0,1,0))
                    for i in range(4):
                        j = (i+1)%4
                        quad(pieces[SEAM],panel[i],panel[j],seam[j],seam[i],(0,1,0))
                else:
                    pieces[channel].face(panel,(0,1,0))
    for sign in (-1,1):
        deck_opening(front,body,sign,*HEAD_Z,.48,.96,'head')
        deck_opening(front,body,sign,*DUCT_Z,.25,.429,'duct')
        for a,b in LOUVRE_Z:
            deck_opening(rear,body,sign,a,b,.10,.64,'louvre')
        x = sign*.747
        for start,end in ((-.57,-.10),(.05,.51)):
            tube(chassis[CARBON],(x,.175,start),(x,.175,end),.024,8)
            tube(chassis[UNDER],(x,.157,start+.035),(x,.157,end-.035),.010,7)
    cap(body, front, -1, -limit)
    cap(body, rear, 1, limit)
    compartment(body, chassis)

    roof_left, roof_right = body.roof_band
    arcs = [mix(roof_left, roof_right, index/16.0) for index in range(17)]
    cross_roof = (-1.,-.96,-.88,-.73,-.55,-.30,0.,.30,.55,.73,.88,.96,1.)
    for a,b in zip(arcs,arcs[1:]):
        lines = [[roof_skin(body,factor,z) for factor in cross_roof] for z in (a,b)]
        skin(chassis[PAINT],*lines,(0,1,0))
        inner = [[(x*.998,y-.022,z) for x,y,z in line] for line in lines]
        skin(chassis[DARK],*inner,(0,-1,0))
        for edge,direction in ((0,-1),(-1,1)):
            quad(chassis[SEAM],lines[0][edge],lines[1][edge],inner[1][edge],inner[0][edge],(direction,0,0))
    windscreen(body,chassis,hood,roof_left,-1)
    windscreen(body,chassis,tail,roof_right,1)
    for side in [-1, 1]:
        # A real rocker lip bridges the footwell and door threshold. It stays
        # with the chassis when the hinged panel opens.
        start, end = body.doors[0], body.doors[-1]
        floor_y = body.sill + .10
        quad(chassis[DARK], (side*.81,floor_y,start),(side*.81,floor_y,end),
             (side*.891,floor_y+.014,end),(side*.891,floor_y+.014,start),(0,1,0))
        for a,b in ((hood,body.doors[0]-.005),(body.doors[-1]+.005,tail)):
            x,y = belt(body,a)
            u,v = belt(body,b)
            if b-a > .04:
                window_patch(chassis[GLASS], (side*x,y,a), (side*u,v,b), canopy(body,a,side), canopy(body,b,side), (side,0,0))
        for axle in body.axles:
            ring = []
            for index in range(25):
                z = axle+ARCH_WIDTH*cos(index*pi/24)
                ring.append(side_profile(body,z,side)[0])
            lip = [(x-side*.024,y-.007,z) for x,y,z in ring]
            skin(chassis[SEAM],ring,lip,(0,-1,0))
            # The curved inner tub encloses the tyre from the passenger side.
            # Its inner plate prevents a sightline from the open door through
            # the far wheel and out underneath the quarter panel.
            inner_x = side*(interpolate(body.panels,axle)[0]-.338)
            interior = [(inner_x,max(.15,y-.040),z) for _,y,z in ring]
            for a,b,u,v in zip(lip,lip[1:],interior,interior[1:]):
                quad(chassis[DARK],a,b,v,u,(0,-1,0))
            shield = [(inner_x,.13,interior[0][2]), *interior, (inner_x,.13,interior[-1][2])]
            chassis[DARK].face(shield,(-side,0,0))

    rear_aero(rear[CARBON],rear[TITANIUM],body)
    return chassis, front, rear


def build_wheel():
    parts = [Mesh() for _ in MATERIALS]

    def ring_mesh(mesh, profile, desired):
        samples = 48
        rings = [[(x,r*cos(i*2*pi/samples),r*sin(i*2*pi/samples)) for i in range(samples)] for x,r in profile]
        for a,b in zip(rings,rings[1:]):
            for i in range(samples):
                j = (i+1)%samples
                quad(mesh,a[i],b[i],b[j],a[j],desired(b[i]))

    sidewalls = [(-.119,.274),(-.143,.298),(-.139,.329),(-.121,.349),(-.085,.358),(-.061,.359),
                 (-.057,.356),(-.052,.359),(-.006,.359),(-.003,.355),(.003,.355),(.006,.359),
                 (.058,.359),(.061,.356),(.066,.359),(.094,.358),(.124,.346),(.139,.324),(.143,.294),(.121,.274)]
    ring_mesh(parts[TYRE],sidewalls, lambda p: (p[0]*2.,p[1],p[2]))
    for side in [-1,1]:
        rim = [(side*x,r) for x,r in ((.063,.241),(.107,.247),(.130,.258),(.138,.270),(.129,.277),(.113,.275))]
        ring_mesh(parts[FORGED],rim,lambda p: (side,.18*p[1],.18*p[2]))
        ring_mesh(parts[ALLOY],[(side*.131,.257),(side*.135,.270)],lambda _: (side,0,0))
        ring_mesh(parts[TITANIUM],[(side*.041,.087),(side*.041,.199),(side*.034,.205),(side*.015,.205)],
                  lambda p: (side,.1*p[1],.1*p[2]))
        for spoke in range(5):
            angle = 2*pi*spoke/5

            def pos(r, arc, depth):
                return (side*depth,r*cos(angle+arc),r*sin(angle+arc))

            for branch in (-1,1):
                face = [pos(.061,branch*.095,.069),pos(.145,branch*.123,.084),pos(.253,branch*.333,.124),
                        pos(.257,branch*.235,.126),pos(.158,branch*.027,.093)]
                parts[FORGED].face(face,(side,0,0))
                back = [(x-side*.020,y,z) for x,y,z in face]
                for i in range(len(face)):
                    j = (i+1)%len(face)
                    quad(parts[FORGED],face[i],face[j],back[j],back[i],(side*.4,face[j][2]-face[i][2],face[i][1]-face[j][1]))
        ring_mesh(parts[FORGED],[(side*.073,0.001),(side*.073,.062),(side*.054,.076)],lambda _: (side,0,0))
        for k in range(5):
            turn = k*2*pi/5
            y,z = .043*cos(turn),.043*sin(turn)
            ellipsoid(parts[ALLOY],(side*.073,y,z),(.007,.008,.008),rings=4,segments=8)
    return parts


# Caliper slot clearance is intentionally modeled: a real disc cannot occupy
# the same space as the casting. Axial dimensions below use local wheel X.
# Spinning disc sits approximately 0.015–0.041 m on the viewed wheel side.
BRAKE_ROTOR_AXIAL_MIN = .015
BRAKE_ROTOR_AXIAL_MAX = .041
BRAKE_CALIPER_SLOT_LO = .012
BRAKE_CALIPER_SLOT_HI = .047
BRAKE_CALIPER_BRIDGE_RADIUS = .214


def build_brake_caliper(side):
    """Original opposed-jaw four-wheel caliper with a rotor-clearance slot.

    The old radial solid casting intersected the rotating titanium rotor.
    Two separate curved jaws now occupy axial positions on either side of the
    rotor, connected only by a radial outer bridge beyond the 205 mm disc.
    Dark friction pads are inset into the slot, without penetrating the disc.
    Mount the completed mesh alongside the spinning wheel on its non-spinning
    steering knuckle; never parent the caliper to the spinning wheel.
    """
    if side not in (-1, 1):
        raise ValueError("caliper side must be -1 or +1")
    parts = [Mesh() for _ in MATERIALS]
    segments = 14
    angle = pi / 5.0
    half_sector = .235
    jaw_inner, jaw_outer = .168, .226
    bridge_inner = BRAKE_CALIPER_BRIDGE_RADIUS

    def at(axial, radius, position):
        theta = angle-half_sector+2.0*half_sector*position/segments
        return side*axial, radius*cos(theta), radius*sin(theta)

    def shell(axial_outer, axial_inner, lower, upper, material):
        """Closed circumferential curved plate with axial wall thickness."""
        for i in range(segments):
            j = i+1
            # Both top and bottom faces of the casting, never an infinitely
            # thin decal pressed over the spinning brake rotor.
            quad(parts[material],
                 at(axial_outer,lower,i),at(axial_outer,upper,i),
                 at(axial_outer,upper,j),at(axial_outer,lower,j),
                 (side,0,0))
            quad(parts[material],
                 at(axial_inner,lower,j),at(axial_inner,upper,j),
                 at(axial_inner,upper,i),at(axial_inner,lower,i),
                 (-side,0,0))
            mid=angle-half_sector+(i+.5)*2*half_sector/segments
            radial=(0,cos(mid),sin(mid))
            quad(parts[material],
                 at(axial_outer,upper,i),at(axial_inner,upper,i),
                 at(axial_inner,upper,j),at(axial_outer,upper,j),radial)
            quad(parts[material],
                 at(axial_outer,lower,j),at(axial_inner,lower,j),
                 at(axial_inner,lower,i),at(axial_outer,lower,i),
                 (0,-radial[1],-radial[2]))
        for pos in (0,segments):
            theta=angle-half_sector+pos*2*half_sector/segments
            desired=(0,-sin(theta),cos(theta)) if pos==0 else (0,sin(theta),-cos(theta))
            quad(parts[material],
                 at(axial_outer,lower,pos),at(axial_inner,lower,pos),
                 at(axial_inner,upper,pos),at(axial_outer,upper,pos),
                 desired)

    # Two caliper casting halves with the rotational disc free between them.
    shell(.103,.061,jaw_inner,jaw_outer,CALIPER)
    shell(.008,-.012,jaw_inner,jaw_outer,CALIPER)
    # The disc spans 15–41 mm; both dark friction pad faces leave >=3 mm of
    # axial rotor clearance. Pads are not artificial floating black polygons.
    shell(.061,.047,.171,.200,DARK)
    shell(.012,.007,.171,.200,DARK)
    # Fixed radial bridge occupies only the outer rim past the disc (205 mm).
    # It connects upper jaws while preserving a through-slot for disc rotation.
    shell(.061,.008,bridge_inner,jaw_outer,CALIPER)

    for offset in (-.132,.132):
        theta=angle+offset
        ellipsoid(parts[ALLOY],
                  (side*.111,.194*cos(theta),.194*sin(theta)),
                  (.006,.008,.008),rings=4,segments=10)
    return parts

MATERIALS = [
    {"name": name, "pbrMetallicRoughness": {"baseColorFactor": [*rgb, 1.],
        "metallicFactor": metal, "roughnessFactor": rough}}
    for name, rgb, metal, rough in (
        ('Paint',(.31,.025,.045),.42,.23), ('Graphite',(.022,.026,.031),.00,.8),
        ('MachinedAlloy',(.39,.42,.47),.82,.31), ('Glazing',(.025,.035,.042),.00,.09),
        ('Seat',(.054,.062,.074),.00,.82), ('DoorCard',(.022,.026,.030),.00,.78),
        ('Headlamp',(.83,.90,.96),.00,.27), ('Taillamp',(.54,.011,.021),.00,.25),
        ('ReverseLamp',(.18,.20,.20),.00,.29), ('Instrument',(.18,.65,.67),.00,.28),
        ('Tire',(.017,.019,.021),.00,.86), ('CarbonComposite',(.60,.62,.65),.16,.29),
        ('Titanium',(.39,.32,.26),.86,.27), ('OpticCover',(.16,.20,.24),.00,.11),
        ('Underglow',(.04,.62,.75),.00,.31),
        ('PanelReveal',(.049,.025,.028),.01,.55), ('Grille',(.072,.079,.084),.59,.51),
        ('ProjectorOptic',(.28,.35,.44),.37,.13), ('ForgedAlloy',(.11,.125,.151),.81,.34),
        ('MarkerReflector',(.36,.071,.025),.11,.32),
        ('BrakeCaliper',(.55,.145,.075),.34,.32),
    )
]
MATERIALS[PAINT]['extensions'] = {'KHR_materials_clearcoat': {'clearcoatFactor': .78, 'clearcoatRoughnessFactor': .12}}
MATERIALS[CARBON]['pbrMetallicRoughness']['baseColorTexture'] = {'index': 0}
# Front and back of the bonded lens now each blend; a lower alpha keeps the
# complete assembly as transmissive as the original single-sided cover.
for channel, alpha in ((GLASS,.60),(OPTIC,.16)):
    MATERIALS[channel]['alphaMode'] = 'BLEND'
    MATERIALS[channel]['pbrMetallicRoughness']['baseColorFactor'][3] = alpha

SOCKETS = {
    'KeyLeft': (-.644,.567,-2.193), 'KeyRight': (.644,.567,-2.193),
    'TailThrow': (0,.583,2.323), 'SillLightLeft': (-.755,.155,-.020),
    'SillLightRight': (.755,.155,-.020),
}


def surfaces_from(channels, pivot=(0.,0.,0.)):
    compiled = []
    for index, mesh in enumerate(channels):
        if not mesh.indices:
            continue
        if index not in (HEAD, TAIL, REVERSE, BELT, UNDER):
            unify_normals(mesh)
        surface = Surface(index)
        remap = []
        for position, normal, uv in zip(mesh.positions, mesh.normals, mesh.texcoords):
            local = tuple(a-b for a,b in zip(position,pivot))
            vertex = tuple(round(v,7) for v in (*local,*normal,*uv))
            if vertex not in surface.lookup:
                surface.lookup[vertex] = len(surface.vertices)
                surface.vertices.append(vertex)
            remap.append(surface.lookup[vertex])
        surface.indices = [remap[i] for i in mesh.indices]
        compiled.append(surface)
    return compiled


def bake_carbon(path):
    """Bake a tile of alternating diagonal 2x2 twill and strand variation."""
    rows = bytearray()
    size = 128
    for y in range(size):
        rows.append(0)
        for x in range(size):
            warp = (x//8+y//8)%4 < 2
            strand, along = (x,y) if warp else (y,x)
            crown = sin(pi*((strand%8+.5)/8))
            fiber = cos(strand*pi) * 1.1 + cos(along*pi/8) * 1.5
            shade = round((15 if warp else 20)+crown*(28 if warp else 21)+fiber)
            rows.extend((shade,shade+1,shade+3))

    def chunk(tag, data):
        return struct.pack('>I',len(data)) + tag + data + struct.pack('>I',zlib.crc32(tag+data))

    header = struct.pack('>IIBBBBB',size,size,8,2,0,0,0)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',header)+chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b''))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bake_carbon(OUT/'carbon_twill.png')
    cabin, front, rear = body_art(R9)
    meshes, pivots = {}, {}
    for name, owner, channel in (('HeadLenses',front,HEAD),('HeadProjectors',front,PROJECTOR),('TailLenses',rear,TAIL),
                                 ('ReverseLenses',rear,REVERSE),('SillLenses',cabin,UNDER)):
        part = [Mesh() for _ in MATERIALS]
        part[channel], owner[channel] = owner[channel], part[channel]
        meshes[name] = surfaces_from(part)
    for name, part in (('Cabin',cabin), ('FrontClip',front), ('RearClip',rear)):
        meshes[name] = surfaces_from(part)
    for side, name in ((-1,'DoorL0'),(1,'DoorR0')):
        a,b = R9.doors
        part = [Mesh() for _ in MATERIALS]
        hinge,y = belt(R9,a)
        pivots[name] = (side*hinge, y-.11, a)
        door(part,R9,side,(a+.006,b-.006))
        meshes[name] = surfaces_from(part,pivots[name])
    totals = write_model(OUT,'cinder_r9',meshes,MATERIALS,SOCKETS,'NightGrid Cinder R9 authoring',
                         'carbon_twill.png',pivots=pivots)
    wheels = write_model(
        OUT,'wheel', {
            'Wheel':surfaces_from(build_wheel()),
            'BrakeCaliperL':surfaces_from(build_brake_caliper(-1)),
            'BrakeCaliperR':surfaces_from(build_brake_caliper(1))
        }, MATERIALS, {},
        'NightGrid Cinder R9 wheel and independent stationary caliper authoring',
        'carbon_twill.png')
    names = ('cinder_r9.gltf','cinder_r9.bin','wheel.gltf','wheel.bin','carbon_twill.png','rain_beads.png')
    manifest = {'id':'nightgrid.cinder_r9','author':'NightGrid Afterhours',
                'license':'Original NightGrid project artwork. No separate public license declared.',
                'source':'tools/art/author_cinder_r9.py','units':'metres','up':'+Y','forward':'-Z',
                'triangles': totals | wheels,'sockets':SOCKETS,
                'sha256': {name:sha256((OUT/name).read_bytes()).hexdigest() for name in names}}
    (OUT/'source.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')


if __name__ == '__main__':
    main()
