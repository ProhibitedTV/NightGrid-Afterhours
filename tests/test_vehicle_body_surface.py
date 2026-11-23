"""Evidence for Vesper's shared manufactured body surfacing, not AAA signoff."""
import math
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"/"vehicles"))
from vehicle_body_surface import (
    STATIONS, ARCH_RADIUS, AXLES, WHEEL_Y, TIRE_RADIUS,
    width_shoulder, body_surface_point, arch_lower_boundary,
    continuity_metrics, side_panel, top_panel, fascia, wheel_liner,
    tire_cross_section, mesh_integrity,
)


class TestVehicleBodySurface(unittest.TestCase):
    def test_c1_station_spline(self):
        # Interpolation must give one continuous manufactured shoulder, rather
        # than separately generated panels meeting at mismatched heights.
        for z,_,_ in STATIONS[1:-1]:
            audit=continuity_metrics(z)
            self.assertLess(audit["max_tangent_jump"],.015,z)
            self.assertLess(audit["position_gap"],1e-9,z)

    def test_sides_fit_hood_and_rear_deck_at_every_station(self):
        for z in [-2.18,-1.99,-1.70,-1.38,-.78,.70,1.33,2.18]:
            w,h=width_shoulder(z)
            for sign in [-1,1]:
                x,y,_=body_surface_point(z,sign)
                self.assertAlmostEqual(x,sign*w,places=6)
                self.assertAlmostEqual(y,h,places=6)
        for sign in (-1,1):
            shape=side_panel(-2.18,-.78,sign,30,9)
            for i in range(31):
                x,y,z=shape.positions[i*10+9]
                expected=body_surface_point(z,sign)
                self.assertAlmostEqual(x,expected[0],places=6)
                self.assertAlmostEqual(y,expected[1],places=6)

    def test_arch_clearance_and_rockers(self):
        for z in AXLES:
            self.assertGreater(arch_lower_boundary(z),
                               WHEEL_Y+TIRE_RADIUS+.040)
        self.assertLess(arch_lower_boundary(0.0),.30)

    def test_all_manufactured_parts_have_valid_faces(self):
        parts=[
            top_panel(-2.18,-.78,16,36),
            top_panel(.70,2.18,16,36),
            fascia(True,24,8),fascia(False,24,8),
            side_panel(-2.18,-.779,-1,32,8),
            side_panel(-.772,.700,1,32,8),
            side_panel(.707,2.18,-1,32,8),
            wheel_liner(AXLES[0],-1,24),
            tire_cross_section(AXLES[0],-.805,32),
        ]
        for part in parts:
            result=mesh_integrity(part)
            self.assertGreater(result["faces"],10)
            self.assertGreater(result["vertices"],10)

    def test_tire_is_closed_and_not_a_thin_torus(self):
        t=tire_cross_section(AXLES[0],-.805,32)
        # Every edge of an indexed tire surface belongs to exactly two faces.
        from collections import Counter
        edges=Counter()
        for quad in t.faces:
            for i in range(4):
                a,b=quad[i],quad[(i+1)%4]
                edges[tuple(sorted((a,b)))]+=1
        self.assertEqual(set(edges.values()),{2})
        ys=[v[1] for v in t.positions]
        self.assertGreater(max(ys)-min(ys),.70)

    def test_fascia_top_is_continuous_with_hood_and_tonneau(self):
        for front in (True, False):
            surface=fascia(front,24,8)
            for p in surface.positions[-25:]:
                x,y,z=p
                width,_=width_shoulder(z)
                expected=body_surface_point(z,x/width)[1]
                self.assertAlmostEqual(y,expected,places=6)
            w,_=width_shoulder(surface.positions[-1][2])
            self.assertAlmostEqual(surface.positions[-25][0],-w,places=6)
            self.assertAlmostEqual(surface.positions[-1][0],w,places=6)

    @staticmethod
    def _face_normal(shell, face):
        a,b,c=[shell.positions[idx] for idx in face[:3]]
        u=[b[i]-a[i] for i in range(3)]
        v=[c[i]-a[i] for i in range(3)]
        return (u[1]*v[2]-u[2]*v[1],
                u[2]*v[0]-u[0]*v[2],
                u[0]*v[1]-u[1]*v[0])

    def test_major_exterior_surface_winding_faces_out(self):
        # Godot single-sided PBR shading requires a bonnet facing +Y, front
        # bumper -Z, and rear bumper +Z. Imported two-sided mesh would hide it.
        bonnet=top_panel(-2.18,-.78,16,36)
        self.assertGreater(self._face_normal(bonnet,bonnet.faces[8])[1],0)
        front=fascia(True,24,8)
        rear=fascia(False,24,8)
        self.assertLess(self._face_normal(front,front.faces[30])[2],0)
        self.assertGreater(self._face_normal(rear,rear.faces[30])[2],0)

    def test_shoulders_have_no_self_folding_width(self):
        for side in (-1,1):
            mesh=side_panel(-2.18,-.78,side,32,12)
            for i in range(33):
                columns=mesh.positions[i*13:(i+1)*13]
                scaled=[x*side for x,_,_ in columns]
                self.assertTrue(all(b>a for a,b in zip(scaled,scaled[1:])),
                                "shoulder reverses near the upper body crease")
            outward=self._face_normal(mesh,mesh.faces[20])
            self.assertGreater(outward[0]*side,0)

    def test_invalid_external_station_rejected(self):
        with self.assertRaisesRegex(ValueError,"station"):
            width_shoulder(3.0)

    def test_interior_panel_is_finite(self):
        for z in [s[0] for s in STATIONS]:
            for t in [-1,-.5,0,.5,1]:
                self.assertTrue(all(math.isfinite(v)
                    for v in body_surface_point(z,t)))


if __name__=="__main__":
    unittest.main()
