#!/usr/bin/env python3
"""Cinder R9 source-authored wheel arch fit and manufactured return tests.

No rendering required. These are physical-clearance/continuity checks, not
claims of visually approved Class-A automotive surfacing.
"""
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "art"))
from author_cinder_r9 import (
    R9, ARCH_WIDTH, ARCH_CIRCLE_JOIN, ARCH_CLEARANCE_RADIUS,
    ARCH_TIRE_CENTER_Y, arch_minimum, side_profile,
)


class CinderWheelArches(unittest.TestCase):
    def test_radial_gap_above_both_tires(self):
        minimum = 1.
        for axle in R9.axles:
            for i in range(1001):
                offset = R9.radius * (2*i/1000 - 1)
                upper_tire = ARCH_TIRE_CENTER_Y + math.sqrt(
                    max(0., R9.radius**2-offset**2))
                clearance = arch_minimum(R9, axle+offset)-upper_tire
                minimum = min(minimum, clearance)
                self.assertGreaterEqual(
                    clearance, .0355, f"wheel clips arch at {axle+offset:.4f} m")
        self.assertAlmostEqual(minimum, ARCH_CLEARANCE_RADIUS-R9.radius, places=4)

    def test_swept_tire_clearance_at_full_ackermann_lock(self):
        # Both front wheel angles can reach approximately +/-0.413 radians
        # (inner wheel). Check a conservative 0.42 radian against the entire
        # actual tire top circumference AND its outermost sidewalls, not only
        # a cross-section with steering centered. This does not simulate
        # suspension travel, camber, body width, or driving collision shapes.
        required = .040
        tire_sidewall = .143 * .92  # authoring profile, imported axial scale
        worst = 1.0
        for axle in R9.axles:
            for angle in (-.42, 0.0, .42):
                for x in (-tire_sidewall, tire_sidewall):
                    for i in range(2501):
                        phi = math.pi*i/2500
                        upper = ARCH_TIRE_CENTER_Y + R9.radius*math.cos(phi)
                        z_local = R9.radius*math.sin(phi)
                        z_at_lock = (-x*math.sin(angle)
                                     + z_local*math.cos(angle))
                        gap = arch_minimum(R9, axle+z_at_lock)-upper
                        worst = min(worst, gap)
                        self.assertGreaterEqual(
                            gap, required,
                            f"steered tire meets arch at {angle:.3f} rad")
        self.assertGreater(worst, .040)

    def test_c1_arch_and_rocker_tangents(self):
        for axle in R9.axles:
            for side in (-1, 1):
                for joint in (ARCH_CIRCLE_JOIN, ARCH_WIDTH):
                    z = axle + side*joint
                    epsilon = .0001
                    before = (arch_minimum(R9,z)-arch_minimum(R9,z-epsilon))/epsilon
                    after = (arch_minimum(R9,z+epsilon)-arch_minimum(R9,z))/epsilon
                    self.assertLess(abs(before-after), .035, f"sharp seam at z={z:.4f}")

    def test_curve_returns_to_sill_and_is_monotone(self):
        for axle in R9.axles:
            heights = [arch_minimum(R9,axle+ARCH_WIDTH*i/200) for i in range(201)]
            self.assertTrue(all(b <= a+1e-7 for a,b in zip(heights,heights[1:])))
            self.assertAlmostEqual(heights[-1],R9.sill,places=6)
            self.assertAlmostEqual(arch_minimum(R9,axle+ARCH_WIDTH+.001),R9.sill,places=6)

    def test_arch_and_inner_lip_share_rocker_endpoints(self):
        # side_profile() is also used by the wheel tub and arch flange.
        # Guarantee the generated lip closes to the rocker at both ends.
        for axle in R9.axles:
            for sign in (-1,1):
                for offset in (-ARCH_WIDTH, ARCH_WIDTH):
                    flank = side_profile(R9,axle+offset,sign)
                    self.assertAlmostEqual(flank[0][1],R9.sill,places=6)
                    self.assertGreater(flank[-1][1],flank[0][1])

    def test_radius_and_clearance_contract(self):
        self.assertGreater(ARCH_CIRCLE_JOIN,0)
        self.assertLess(ARCH_CIRCLE_JOIN,R9.radius)
        self.assertLess(R9.radius, ARCH_CLEARANCE_RADIUS)
        self.assertGreater(ARCH_WIDTH,ARCH_CIRCLE_JOIN)
        self.assertGreater(ARCH_WIDTH,R9.radius)


if __name__=="__main__":
    unittest.main()
