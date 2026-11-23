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


R9 = Body('cinder_r9', 4.66, 1.31, .670, .358, (-1.43, 1.44), (-.38, .49), (-1.11, 1.25),
         (-.97, .87), .16, (.40, -.30),
         ((-2.33, .792, .47), (-2.24, .896, .559), (-1.96, .967, .668), (-1.53, .995, .825),
          (-1.19, .969, .851), (-.75, .923, .783), (.03, .900, .757), (.63, .978, .800),
          (1.43, 1.010, .913), (1.82, 1.000, .849), (2.12, .971, .780), (2.33, .864, .712)))


def mix(a, b, t):
    return a + (b - a) * t


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
    longitudinal = body.radius * 1.20
    distance = min(abs(z - wheel) for wheel in body.axles)
    if distance >= longitudinal:
        return body.sill
    # The upright ends are in the fenders. The upper portion follows the tyres.
    return body.radius * .98 + sqrt(max(0.0, longitudinal**2 - distance**2)) * .99


def belt(body, z):
    width, y = interpolate(body.panels, z)
    return width - .046, y - .026


def deck(body, z, fraction):
    width, shoulder = interpolate(body.panels, z)
    bow = .036
    return (width-.047)*fraction, shoulder+bow*(1-abs(fraction)**1.5), z


def side_profile(body, z, side):
    width, shoulder = interpolate(body.panels, z)
    bottom = min(shoulder - .07, arch_minimum(body, z))
    return [(side*(width + inset), mix(bottom, shoulder, column), z)
            for column, inset in ((0, -.081), (.105, -.043), (.44, -.015), (.79, 0), (1, -.047))]


def cabin_width(body, z):
    mid = sum(body.roof_band) * .5
    return body.roof_width * (1.0 - .095 * abs(z-mid) / max(.6, body.roof_band[1] - body.roof_band[0]))


def canopy(body, z, side):
    first, last = body.roof_band
    front, rear = body.glass
    if z < first:
        t = max(0.0, (z - front) / (first - front))
        x, y = belt(body, front)
        return side * mix(x, cabin_width(body, first), t), mix(y, body.roof-.047, t), z
    if z > last:
        t = min(1.0, (z - last) / (rear - last))
        x, y = belt(body, rear)
        return side * mix(cabin_width(body, last), x, t), mix(body.roof-.047, y, t), z
    return side*cabin_width(body, z), body.roof-.046, z


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
    chunks = 18
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
    at = last - .18
    x, waist = belt(body, at)
    ellipsoid(dark, (side*(x+.033), waist-.087, at), (.025, .029, .112), rings=4)
    ellipsoid(surfaces[ALLOY], (side*(x+.049), waist-.086, at+.009), (.015, .013, .070), rings=4)
    if first < -.68:
        x, waist = belt(body, first + .18)
        tube(dark, (side*x, waist+.055, first+.18), (side*(x+.136), waist+.158, first+.12), .029, 6)
        ellipsoid(paint, (side*(x+.174), waist+.174, first+.12), (.103, .055, .104), rings=5)
        ellipsoid(surfaces[ALLOY], (side*(x+.178), waist+.174, first+.201), (.078, .040, .010), rings=5)


DECK_COLS = (-1, -.96, -.88, -.77, -.64, -.518, -.509, -.48, -.39, -.25, -.21, -.10,
             0, .10, .21, .25, .39, .48, .509, .518, .64, .77, .88, .96, 1)
HEAD_Z = (-2.245, -1.854)
DUCT_Z = (-1.749, -1.305)
BONNET_Z = (-2.275, -1.154)
LOUVRE_Z = tuple((1.278+i*.095, 1.317+i*.095) for i in range(7))
SIDE_INTAKE = (.882, 1.008)


def on_deck(body, lateral, z, offset=0.):
    # Swept lamp treatment and a tighter outside radius under the front fender.
    if HEAD_Z[0] <= z <= HEAD_Z[1]:
        t = (z - HEAD_Z[0]) / (HEAD_Z[1] - HEAD_Z[0])
        sign = -1 if lateral < 0.0 else 1
        lateral += sign*.095*sin(pi*t*.92)*max(0., 1-4.5*abs(abs(lateral)-.75))
    x, y, z = deck(body, z, lateral)
    feature = max(0., min(1., (-1.11-z)*5, (z+2.32)*5))
    ridge = max(0., 1.-abs(abs(lateral)-.53)*5.8)**1.4
    bonnet = .016*max(0., 1.-abs(lateral)*3.)*feature
    return (x, y + offset + .032*ridge*feature + bonnet, z)


def cap(body, surfaces, side, z):
    cols = DECK_COLS
    rows = (0., .10, .20, .38, .52, .67, .79, .92, 1.)
    profile = side_profile(body, z, 1)
    edge = [(v, x, y) for v,(x,y,_) in zip((0.,.105,.44,.79,1.), profile)]

    def point(u, v, recess=0.):
        if v >= .999:
            return on_deck(body, u, z)
        radius = abs(u) ** 8
        width, edge_y = interpolate(edge,v)
        x = u * width
        top = on_deck(body, u, z)[1]
        low = profile[0][1] - .010 * (1-radius)
        depth = .049*(1-radius)*(1-v)
        # Keep the mouth between the axial end and the fascia backing.
        return (x, mix(mix(low, top, v), edge_y, radius), z-side*(depth+recess))

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
        return 'skin'

    normal = (0, 0, side)
    for u, w in zip(cols, cols[1:]):
        for v, h in zip(rows, rows[1:]):
            part = channel((u+w)*.5, (v+h)*.5)
            if part != 'skin':
                continue
            material = CARBON if h <= .20 else PAINT
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

    def strip(material, x0, x1, center, thickness, depth, rake=0.):
        segments = max(2, round(abs(x1-x0)*14))
        for index in range(segments):
            a,b = (mix(x0,x1,i/segments) for i in (index,index+1))
            va,vb = (center+abs(u)*rake for u in (a,b))
            quad(surfaces[material], point(a,va,depth), point(b,vb,depth),
                 point(b,vb+thickness,depth), point(a,va+thickness,depth), normal)

    if side < 0:
        for a,b in ((-.48,.48), (-.88,-.64), (.64,.88)):
            socket(a,b,.20,.67,.145,CARBON)
            for i in range(5):
                strip(ALLOY,a+.018,b-.018,.254+i*.075,.011,.129)
            for i in range(1, 8 if a == -.48 else 3):
                u = mix(a,b,i/(8 if a == -.48 else 3))
                quad(surfaces[DARK], point(u-.007,.24,.131), point(u+.007,.24,.131),
                     point(u+.007,.63,.131), point(u-.007,.63,.131), normal)
        return
    for a,b in ((-.96,-.25), (.25,.96)):
        socket(a,b,.67,.92,.053,CARBON)
        strip(TAIL, a+.029,b-.029,.724,.029,.034,.046)
        strip(TAIL, a+.029,b-.029,.789,.025,.034,.043)
        center = .34 if a > 0 else -.34
        strip(REVERSE,center-.054,center+.054,.711,.024,.034)
        strip(OPTIC,a+.017,b-.017,.700,.164,.010,.025)
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
    cols = [u for u in DECK_COLS if low <= sign*u <= high]
    # Use the same z rows as the top skin, keeping the entire lip welded visually.
    steps = [z for z in sampled_stations(body) if a <= z <= b]
    band_depth = -.034 if kind == 'head' else -.079
    for start,end in zip(steps,steps[1:]):
        for u,direction in ((cols[0],1),(cols[-1],-1)):
            quad(surfaces[CARBON], on_deck(body,u,start), on_deck(body,u,end),
                 on_deck(body,u+direction*.015,end,band_depth),
                 on_deck(body,u+direction*.015,start,band_depth), (0,1,0))
        for u,v in zip(cols, cols[1:]):
            quad(surfaces[DARK],on_deck(body,u,start,band_depth),on_deck(body,u,end,band_depth),
                 on_deck(body,v,end,band_depth),on_deck(body,v,start,band_depth),(0,1,0))
            if kind == 'head':
                quad(surfaces[OPTIC],on_deck(body,u,start,-.004),on_deck(body,u,end,-.004),
                     on_deck(body,v,end,-.004),on_deck(body,v,start,-.004),(0,1,0))
    for z,direction in ((a,1),(b,-1)):
        for u,v in zip(cols,cols[1:]):
            quad(surfaces[CARBON], on_deck(body,u,z), on_deck(body,v,z),
                 on_deck(body,v,z+direction*.012,band_depth),on_deck(body,u,z+direction*.012,band_depth),(0,1,0))
    if kind == 'head':
        # The trim bezel is visible through the lens. An oversized secondary
        # shield closes off oblique views underneath the projector pocket.
        for start,end in zip(steps, steps[1:]):
            left,right = cols[0]-.027,cols[-1]+.027
            lower = start-.028 if start == steps[0] else start
            upper = end+.018 if end == steps[-1] else end
            quad(surfaces[DARK],on_deck(body,left,lower,-.065),on_deck(body,left,upper,-.065),
                 on_deck(body,right,upper,-.065),on_deck(body,right,lower,-.065),(0,1,0))
        at = on_deck(body,sign*.79,a+.08,-.025)
        ellipsoid(surfaces[ALLOY],at,(.080,.012,.037),rings=5,segments=12)
        ellipsoid(surfaces[DARK],(at[0],at[1]+.007,at[2]),(.050,.013,.032),rings=5,segments=12)
        ellipsoid(surfaces[OPTIC],(at[0],at[1]+.016,at[2]),(.039,.009,.028),rings=5,segments=12)
        for center in (.664,.754,.847):
            for start,end in zip(steps,steps[1:]):
                if start < a+.018 or end > b-.034:
                    continue
                phase = (start-a)/(b-a)
                width = .021 if center == .664 else .033
                lateral = center-.032*(1-phase)
                for material, extra, y in ((HEAD,0.,-.014),(ALLOY,.014,-.025)):
                    u,v = sorted((sign*(lateral-extra),sign*(lateral+width+extra)))
                    quad(surfaces[material],on_deck(body,u,start,y),on_deck(body,u,end,y),
                         on_deck(body,v,end,y),on_deck(body,v,start,y),(0,1,0))
    elif kind == 'duct':
        for bend in (.21,.40,.59,.78):
            z = mix(a,b,bend)
            quad(surfaces[CARBON], on_deck(body,cols[0]+.02,z,-.059),
                 on_deck(body,cols[-1]-.02,z,-.059),on_deck(body,cols[-1]-.02,z+.025,-.033),
                 on_deck(body,cols[0]+.02,z+.025,-.033),(0,1,0))


def sampled_stations(body):
    hood,tail = body.glass
    limit = body.length*.5
    dimensions = {round(mix(-limit, limit, i/104.0),6) for i in range(105)}
    boundaries = [hood,tail,-limit,limit,*body.roof_band,*HEAD_Z,*DUCT_Z,*SIDE_INTAKE,
                  *BONNET_Z,BONNET_Z[0]+.010,BONNET_Z[1]-.010]
    boundaries.extend(z for pair in LOUVRE_Z for z in pair)
    boundaries.extend(e+margin for e in body.doors for margin in (-.010,.010))
    boundaries.extend(z for left,right in (HEAD_Z, DUCT_Z) for z in (left+.021,right-.038))
    for axle in body.axles:
        boundaries.extend(axle+body.radius*1.20*cos(i*pi/20.0) for i in range(21))
    return sorted(dimensions | {round(z,6) for z in boundaries})


def body_art(body):
    chassis, front, rear = ([Mesh() for _ in range(15)] for _ in range(3))
    hood, tail = body.glass
    limit = body.length*.5
    steps = sampled_stations(body)
    for a, b in zip(steps, steps[1:]):
        midpoint = (a+b)*.5
        pieces = front if midpoint < hood else (rear if midpoint > tail else chassis)
        inside_door = body.doors[0]-.009 < midpoint < body.doors[-1]+.009
        for side in [-1, 1]:
            first, last = side_profile(body, a, side), side_profile(body, b, side)
            skin(pieces[CARBON], first[:2], last[:2], (side, 0, 0))
            if not inside_door:
                if SIDE_INTAKE[0] < midpoint < SIDE_INTAKE[1]:
                    skin(pieces[PAINT], first[3:], last[3:], (side,0,0))
                    for i in (1,3):
                        p,q = first[i],last[i]
                        quad(pieces[CARBON],p,q,(q[0]-side*.095,*q[1:]),(p[0]-side*.095,*p[1:]),(side,0,0))
                    inner = lambda point: (point[0]-side*.095,*point[1:])
                    quad(pieces[DARK],inner(first[1]),inner(last[1]),inner(last[3]),inner(first[3]),(side,0,0))
                    for z,profile in ((a,first),(b,last)):
                        if z in SIDE_INTAKE:
                            quad(pieces[CARBON],profile[1],profile[3],inner(profile[3]),inner(profile[1]),(side,0,0))
                else:
                    skin(pieces[PAINT], first[1:], last[1:], (side, 0, 0))
            if first[0][1] > body.sill+.03 or last[0][1] > body.sill+.03:
                depth = .184
                poly = [first[0], last[0], (last[0][0]-side*depth, last[0][1]-.015, b),
                        (first[0][0]-side*depth, first[0][1]-.015, a)]
                pieces[DARK].face(poly, (0, -1, 0))
        if pieces is not chassis:
            for u,v in zip(DECK_COLS,DECK_COLS[1:]):
                width = abs(u+v)*.5
                if HEAD_Z[0] < midpoint < HEAD_Z[1] and .48 < width < .96:
                    continue
                if DUCT_Z[0] < midpoint < DUCT_Z[1] and .21 < width < .48:
                    continue
                if any(left < midpoint < right for left,right in LOUVRE_Z) and .10 < width < .64:
                    continue
                channel = CARBON if pieces is rear and width < .64 and 1.25 < midpoint < 1.91 else PAINT
                bonnet_edge = .509 < width < .518 and BONNET_Z[0] < midpoint < BONNET_Z[1]
                bonnet_ends = width < .518 and (BONNET_Z[0] < midpoint < BONNET_Z[0]+.010
                                               or BONNET_Z[1]-.010 < midpoint < BONNET_Z[1])
                panel = [on_deck(body,width,z) for width,z in ((u,a),(u,b),(v,b),(v,a))]
                if bonnet_edge or bonnet_ends:
                    seam = [(x,y-.005,z) for x,y,z in panel]
                    pieces[DARK].face(seam,(0,1,0))
                    for i in range(4):
                        j = (i+1)%4
                        quad(pieces[DARK],panel[i],panel[j],seam[j],seam[i],(0,1,0))
                else:
                    pieces[channel].face(panel,(0,1,0))
    for sign in (-1,1):
        deck_opening(front,body,sign,*HEAD_Z,.48,.96,'head')
        deck_opening(front,body,sign,*DUCT_Z,.21,.48,'duct')
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
    arcs = [mix(roof_left, roof_right, index/14.0) for index in range(15)]
    for a,b in zip(arcs, arcs[1:]):
        lines = [[(canopy(body,z,1)[0]*factor, body.roof-.046*abs(factor)**1.8, z)
                  for factor in (-1, -.88, -.55, 0, .55, .88, 1)] for z in (a,b)]
        skin(chassis[PAINT], *lines, (0,1,0))
        inner = [[(x*.997,y-.028,z) for x,y,z in line] for line in lines]
        skin(chassis[DARK], *inner, (0,-1,0))
        for edge, direction in ((0,-1),(-1,1)):
            quad(chassis[DARK],lines[0][edge],lines[1][edge],inner[1][edge],inner[0][edge],(direction,0,0))
    for at, roof, facing in ((hood,roof_left,-1), (tail,roof_right,1)):
        x, y = belt(body, at)
        top_a, top_b = canopy(body, roof, -1), canopy(body, roof, 1)
        lower_a, lower_b = (-x, y, at), (x, y, at)
        glass_normal = normalize((0, abs(roof - at), facing * (top_a[1] - y)))
        # Bonded windscreen: the black ceramic border overlaps the laminate and
        # disappears behind the rounded shoulder of the stamped body pillar.
        outer = [lower_a, lower_b, top_b, top_a]
        inset = []
        for corner, opposite, vertical in [(lower_a, lower_b, top_a), (lower_b, lower_a, top_b),
                                           (top_b, top_a, lower_b), (top_a, top_b, lower_a)]:
            inset.append(tuple(value + (across - value) * .024 + (up - value) * .061
                               for value, across, up in zip(corner, opposite, vertical)))
        quad(chassis[GLASS], *inset, glass_normal)
        for index in range(4):
            following = (index + 1) % 4
            quad(chassis[DARK], outer[index], outer[following], inset[following], inset[index], glass_normal)
        for side in [-1, 1]:
            width = .093 if facing == -1 else .125
            windshield_pillar(chassis[PAINT], chassis[DARK], (side*x, y, at),
                             canopy(body, roof, side), glass_normal, side, width)
        if facing == -1:
            # Parked blades lie just above the actual sloped glass and are
            # anchored at the cowl, below the driver's sightline.
            def on_windscreen(lateral, up):
                return (lateral * mix(x, top_b[0], up),
                        mix(y, top_b[1], up) + glass_normal[1] * .016,
                        mix(at, roof, up) + glass_normal[2] * .016)

            for pivot, tip in [(-.67, -.15), (.20, .68)]:
                tube(chassis[DARK], on_windscreen(pivot, .028), on_windscreen(tip - .12, .156), .010, 5)
                tube(chassis[DARK], on_windscreen(tip - .24, .138), on_windscreen(tip + .10, .166), .008, 5)
    for side in [-1, 1]:
        # A real rocker lip bridges the footwell and door threshold. It stays
        # with the chassis when the hinged panel opens.
        start, end = body.doors[0], body.doors[-1]
        floor_y = body.sill + .10
        quad(chassis[DARK], (side*.81,floor_y,start),(side*.81,floor_y,end),
             (side*.891,floor_y+.014,end),(side*.891,floor_y+.014,start),(0,1,0))
        for pillar in body.doors[1:-1]:
            x, y = belt(body,pillar)
            tube(chassis[DARK], (side*(x-.021),y,pillar), canopy(body,pillar,side), .040, 7)
        for a,b in ((hood,body.doors[0]-.010),(body.doors[-1]+.010,tail)):
            x,y = belt(body,a)
            u,v = belt(body,b)
            if b-a > .04:
                window_patch(chassis[GLASS], (side*x,y,a), (side*u,v,b), canopy(body,a,side), canopy(body,b,side), (side,0,0))
        for axle in body.axles:
            ring = []
            for index in range(21):
                theta = index*pi/20
                z = axle + body.radius*1.20*cos(theta)
                x = interpolate(body.panels,z)[0]-.077
                ring.append((side*x, arch_minimum(body,z)+.009, z))
            for a,b in zip(ring,ring[1:]):
                tube(chassis[DARK],a,b, .021, 5)
            # The curved inner tub encloses the tyre from the passenger side.
            # Its inner plate prevents a sightline from the open door through
            # the far wheel and out underneath the quarter panel.
            inner_x = side*(interpolate(body.panels,axle)[0]-.338)
            interior = [(inner_x,max(.15,y-.040),z) for _,y,z in ring]
            for a,b,u,v in zip(ring,ring[1:],interior,interior[1:]):
                quad(chassis[DARK],a,b,v,u,(0,-1,0))
            shield = [(inner_x,.13,interior[0][2]), *interior, (inner_x,.13,interior[-1][2])]
            chassis[DARK].face(shield,(-side,0,0))

    z,y = 2.04, .974
    for x in [-.55,.55]:
        tube(rear[TITANIUM],(x,.78,z+.10),(x,y,z),.040,8)
    top = [(-.874,y,z-.17),(.874,y,z-.17),(.814,y+.028,z+.10),(-.814,y+.028,z+.10)]
    bottom = [(x, height-.023, along) for x,height,along in top]
    rear[CARBON].face(top,(0,1,0))
    rear[CARBON].face(bottom,(0,-1,0))
    for a,b,c,d in zip(top,top[1:]+top[:1],bottom[1:]+bottom[:1],bottom):
        quad(rear[CARBON],a,b,c,d,((a[0]+b[0])*.5,0,(a[2]+b[2])*.5-z))
    return chassis, front, rear


def build_wheel():
    parts = [Mesh() for _ in range(15)]
    profile = [(-.130,.246),(-.138,.308),(-.125,.348),(-.091,.359),(.083,.359),
               (.119,.349),(.133,.324),(.141,.268),(.129,.240)]
    rings = [[(x,r*cos(i*2*pi/48),r*sin(i*2*pi/48)) for i in range(48)] for x,r in profile]
    for inner, outer in zip(rings,rings[1:]):
        for index in range(48):
            next_index = (index+1)%48
            point = outer[index]
            quad(parts[TYRE],inner[index],outer[index],outer[next_index],inner[next_index],(0,point[1],point[2]))
    for side in [-1,1]:
        x = side*.133
        for radius, strength in ((.252,.012),(.225,.010)):
            points = [(x,radius*cos(i*2*pi/32),radius*sin(i*2*pi/32)) for i in range(32)]
            for i in range(32):
                tube(parts[ALLOY],points[i],points[(i+1)%32],strength,6)
        for spoke in range(10):
            angle = 2*pi*spoke/10
            pos = lambda factor, turn: (x, factor*cos(angle+turn),factor*sin(angle+turn))
            quad(parts[ALLOY], pos(.049,-.35),pos(.225,-.045),pos(.235,.055),pos(.083,.23),(side,0,0))
        tube(parts[DARK], (x-side*.075,0,0), (x+side*.008,0,0), .061, 20)
        tube(parts[ALLOY], (x-side*.11,0,0), (x-side*.092,0,0), .188, 30)
        for k in range(5):
            turn = k*2*pi/5
            y,z = .043*cos(turn),.043*sin(turn)
            tube(parts[ALLOY],(x,y,z),(x+side*.016,y,z),.009,7)
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
    )
]
MATERIALS[PAINT]['extensions'] = {'KHR_materials_clearcoat': {'clearcoatFactor': .78, 'clearcoatRoughnessFactor': .12}}
MATERIALS[CARBON]['pbrMetallicRoughness']['baseColorTexture'] = {'index': 0}
for channel, alpha in ((GLASS,.60),(OPTIC,.29)):
    MATERIALS[channel]['alphaMode'] = 'BLEND'
    MATERIALS[channel]['pbrMetallicRoughness']['baseColorFactor'][3] = alpha

SOCKETS = {
    'KeyLeft': (-.661,.61,-2.300), 'KeyRight': (.661,.61,-2.300),
    'TailThrow': (0,.535,2.336), 'SillLightLeft': (-.755,.155,-.020),
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
    for name, owner, channel in (('HeadLenses',front,HEAD),('TailLenses',rear,TAIL),
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
        door(part,R9,side,(a+.012,b-.012))
        meshes[name] = surfaces_from(part,pivots[name])
    totals = write_model(OUT,'cinder_r9',meshes,MATERIALS,SOCKETS,'NightGrid Cinder R9 authoring',
                         'carbon_twill.png',pivots=pivots)
    wheels = write_model(OUT,'wheel',{'Wheel':surfaces_from(build_wheel())},MATERIALS,{},
                         'NightGrid Cinder R9 wheel authoring','carbon_twill.png')
    names = ('cinder_r9.gltf','cinder_r9.bin','wheel.gltf','wheel.bin','carbon_twill.png','rain_beads.png')
    manifest = {'id':'nightgrid.cinder_r9','author':'NightGrid Afterhours',
                'license':'Original NightGrid project artwork. No separate public license declared.',
                'source':'tools/art/author_cinder_r9.py','units':'metres','up':'+Y','forward':'-Z',
                'triangles': totals | wheels,'sockets':SOCKETS,
                'sha256': {name:sha256((OUT/name).read_bytes()).hexdigest() for name in names}}
    (OUT/'source.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')


if __name__ == '__main__':
    main()
