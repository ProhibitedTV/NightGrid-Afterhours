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
    tire_cross_section, mesh_integrity, spline_property, curvature_seam_metrics,
    side_surface_point, shoulder_normal_alignment, ARCH_CIRCLE_END, ARCH_ROCKER_END,
)


class TestVehicleBodySurface(unittest.TestCase):
    def test_c1_station_spline(self):
        # Interpolation must give one continuous manufactured shoulder, rather
        # than separately generated panels meeting at mismatched heights.
        for z,_,_ in STATIONS[1:-1]:
            audit=continuity_metrics(z)
            self.assertLess(audit["max_tangent_jump"],.015,z)
            self.assertLess(audit["position_gap"],1e-9,z)

    def test_original_c2_profile_curvature_at_design_stations(self):
        # A smooth professional car body requires more than C0/C1 joins:
        # abrupt second-derivative jumps break continuous specular highlights.
        for z,_,_ in STATIONS[1:-1]:
            seam=curvature_seam_metrics(z)
            self.assertLess(seam["max_position_delta"],.00001,z)
            self.assertLess(seam["max_tangent_delta"],.00002,z)
            self.assertLess(seam["max_second_derivative_delta"],.00005,z)
            for c in (1,2):
                self.assertAlmostEqual(spline_property(z,c),width_shoulder(z)[c-1],places=10)

    def test_sculpt_bounds_and_nonnegative_body_dimensions(self):
        for i in range(1001):
            z=STATIONS[0][0]+(STATIONS[-1][0]-STATIONS[0][0])*i/1000
            w,h=width_shoulder(z)
            self.assertGreater(w,.60)
            self.assertLess(w,.99)
            self.assertGreater(h,.65)
            self.assertLess(h,1.1)

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
        min_clearance=1.
        for axle in AXLES:
            for i in range(1001):
                offset=-TIRE_RADIUS+2*TIRE_RADIUS*i/1000
                z=axle+offset
                upper_tire=WHEEL_Y+math.sqrt(max(0.,TIRE_RADIUS**2-offset**2))
                clearance=arch_lower_boundary(z)-upper_tire
                min_clearance=min(min_clearance,clearance)
                self.assertGreaterEqual(clearance,.045,
                                        f"wheel clips body at {z:.3f}m")
        self.assertGreater(min_clearance,.04)
        self.assertLess(arch_lower_boundary(0.0),.30)

    def test_arch_returns_continuously_to_lower_rocker(self):
        for axle in AXLES:
            for sign in (-1,1):
                for joint in (ARCH_CIRCLE_END,ARCH_ROCKER_END):
                    boundary=axle+sign*joint
                    self.assertLess(abs(arch_lower_boundary(boundary-0.000001)-
                                        arch_lower_boundary(boundary+0.000001)),.002)
                far=axle+sign*(ARCH_ROCKER_END+.001)
                self.assertAlmostEqual(arch_lower_boundary(far),.260,places=6)

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

    def test_wheel_liner_outer_rim_follows_flank(self):
        for axle in AXLES:
            for side in (-1,1):
                liner=wheel_liner(axle,side,48)
                for x,y,z in liner.positions[::2]:
                    width,_=width_shoulder(z)
                    self.assertAlmostEqual(x,side*width*.945,places=7)
                    self.assertAlmostEqual(y,arch_lower_boundary(z),places=7)

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

    def test_rolled_shoulders_have_one_controlled_return(self):
        for side in (-1,1):
            for z in (-1.92,-1.42,-1.05,0.,.93,1.50,1.96):
                values=[side_surface_point(z,side,t/200)[0]*side
                        for t in range(201)]
                slopes=[b-a for a,b in zip(values,values[1:])]
                signs=[x>0 for x in slopes if abs(x)>1e-8]
                switches=sum(a!=b for a,b in zip(signs,signs[1:]))
                self.assertLessEqual(switches,1,
                    "shoulder must have one engineered widest point")
                width,_=width_shoulder(z)
                self.assertAlmostEqual(values[-1],width,places=7)
                self.assertLess(max(values),width*1.055)
                self.assertGreater(values[0],width*.93)
                self.assertGreater(max(values),width)
            mesh=side_panel(-2.18,-.78,side,32,12)
            outward=self._face_normal(mesh,mesh.faces[20])
            self.assertGreater(outward[0]*side,0)

    def test_hood_side_joint_has_matching_normals(self):
        # Positions matching is insufficient. True shoulder craftsmanship
        # needs visually aligned normals from both surfaces on each side.
        for z in (-1.90,-1.50,-1.15,-.93,.90,1.24,1.62,1.99):
            for side in (-1,1):
                angle=shoulder_normal_alignment(z,side)
                self.assertLess(angle,1.0,
                                f"disconnected shading at {z}m / side {side}")

    def test_wheel_arch_has_continuous_tangent_at_return(self):
        # No infinite circle sqrt() slope or hard kink at arch-to-rocker join.
        for axle in AXLES:
            for joint in (ARCH_CIRCLE_END,ARCH_ROCKER_END):
                for side in (-1,1):
                    z=axle+side*joint
                    e=.0001
                    left=(arch_lower_boundary(z)-arch_lower_boundary(z-e))/e
                    right=(arch_lower_boundary(z+e)-arch_lower_boundary(z))/e
                    self.assertLess(abs(left-right),.035,
                                    f"sharp wheel-arch tangent at {z}m")

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
