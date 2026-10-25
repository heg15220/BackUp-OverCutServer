"""Checks the generated game data against the real-world facts it must reproduce.
Run: python -I tools/data/test_build.py   (after build_melbourne.py and build_season_2012.py)
"""
import json
import math
import os
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
TRACK = os.path.join(ROOT, "data", "tracks", "melbourne_2012.json")
SEASON = os.path.join(ROOT, "data", "seasons", "2012.json")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class MelbourneTrack(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.t = load(TRACK)

    def test_length_matches_the_1996_2020_layout(self):
        self.assertTrue(5250 <= self.t["length_m"] <= 5350, self.t["length_m"])

    def test_arrays_are_parallel(self):
        n = len(self.t["points"])
        for key in ("heights", "width_left", "width_right", "kerb_left", "kerb_right", "kerb_high_left",
                    "kerb_high_right", "runoff_left", "runoff_right", "wall_left", "wall_right", "racing_line"):
            self.assertEqual(len(self.t[key]), n, key)

    def test_heights_are_real_terrain(self):
        h = self.t["heights"]
        self.assertTrue(all(math.isfinite(v) and -2.0 <= v <= 40.0 for v in h))
        self.assertGreater(max(h) - min(h), 2.0, "Albert Park is not perfectly flat")

    def test_walls_never_cut_the_track(self):
        for i in range(len(self.t["points"])):
            for side in ("left", "right"):
                edge = self.t["width_" + side][i] + self.t["kerb_" + side][i]
                self.assertGreaterEqual(self.t["wall_" + side][i], edge + 1.0, (i, side))

    def test_racing_line_stays_on_the_asphalt(self):
        for i, n in enumerate(self.t["racing_line"]):
            self.assertLessEqual(n, self.t["width_left"][i] - 0.9, i)
            self.assertGreaterEqual(n, -self.t["width_right"][i] + 0.9, i)

    def test_grid_has_24_slots_behind_the_line(self):
        self.assertEqual(len(self.t["grid"]), 24)

    def test_one_drs_zone_on_the_main_straight(self):
        self.assertEqual(len(self.t["drs_zones"]), 1)

    def test_environment_from_openstreetmap(self):
        env = self.t["environment"]
        self.assertGreater(len(env["lake"]), 20)
        self.assertGreater(len(env["trees"]), 3000)
        self.assertGreater(len(env["buildings"]), 200)

    def test_terrain_grid(self):
        g = self.t["terrain"]
        self.assertEqual(len(g["heights"]), g["nx"] * g["ny"])

    def test_race_distance(self):
        self.assertEqual(self.t["laps"], 58)


class Season2012(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s = load(SEASON)

    def test_calendar(self):
        self.assertEqual(len(self.s["calendar"]), 20)
        self.assertEqual(self.s["calendar"][0]["id"], "australia")
        self.assertTrue(self.s["calendar"][0]["available"])

    def test_points(self):
        self.assertEqual(self.s["points"], [25, 18, 15, 12, 10, 8, 6, 4, 2, 1])

    def test_teams_and_drivers(self):
        self.assertEqual(len(self.s["teams"]), 12)
        starters = [d for d in self.s["drivers"] if d["starter"]]
        self.assertEqual(len(starters), 24)
        codes = {d["code"] for d in starters}
        for code in ("VET", "HAM", "ALO", "RAI", "MSC", "BUT", "KAR", "PIC"):  # MSC: 2012 timing code
            self.assertIn(code, codes)
        for team in self.s["teams"]:
            for key in ("primary", "secondary", "accent"):
                self.assertRegex(team["colors"][key], r"^#[0-9A-Fa-f]{6}$")

    def test_real_melbourne_qualifying(self):
        q = self.s["real_results"]["australia"]["qualifying"]
        self.assertEqual(q[0]["code"], "HAM")
        self.assertAlmostEqual(q[0]["best_s"], 84.922, places=3)

    def test_team_pace_is_relative_to_the_fastest(self):
        pace = self.s["pace"]["australia"]
        self.assertAlmostEqual(min(pace.values()), 0.0, places=6)
        self.assertGreater(pace["hrt"], pace["mclaren"])


if __name__ == "__main__":
    unittest.main()
