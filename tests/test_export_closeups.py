"""Pure offline identity tests; no game assets, dependencies, or .NET required."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "export_closeups", Path(__file__).resolve().parents[1] / "scripts/export_closeups.py")
export = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export)


class AssetIdentityTests(unittest.TestCase):
    def test_canonical_forms(self):
        expected = "/Game/Packages/A/Photo.Photo"
        for value in ("LiS/Content/Packages/A/Photo.uasset", "LIS/Content/Packages/A/Photo.uasset",
                      "/Game/Packages/A/Photo", expected):
            self.assertEqual(export.canonical_id(value), expected)
            self.assertEqual(export.output_name(value), export.output_name(expected))

    def test_distinct_object(self):
        self.assertEqual(export.canonical_id("/Game/A/Package.Other"), "/Game/A/Package.Other")

    def test_same_basename_different_package(self):
        self.assertNotEqual(export.output_name("/Game/A/Photo"), export.output_name("/Game/B/Photo"))

    def test_dedup_and_order(self):
        result = export.unique_assets(["/Game/B/X", "/Game/A/X", "LiS/Content/A/X.uasset"])
        self.assertEqual(list(result), ["/Game/A/X.X", "/Game/B/X.X"])

    def test_case_ambiguity_rejected(self):
        with self.assertRaises(ValueError):
            export.unique_assets(["/Game/A/Photo", "/Game/A/photo"])

    def test_collision_rejected(self):
        with patch.object(export, "output_name", return_value="collision.png"):
            with self.assertRaises(ValueError):
                export.unique_assets(["/Game/A/Photo", "/Game/B/Photo"])

    def test_invalid_inputs(self):
        for value in (None, "", " /Game/A", "/Game/A ", "/Game/../A", "C:/A.uasset",
                      "../A.uasset", "/Game/A//B", "/Game/A\\B", "/Game/A.umap",
                      "/Game/A.B.C", "/Engine/A", "/Game/A\nB", "/Game/"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                export.canonical_id(value)

    def test_bounded_safe_filename(self):
        name = export.output_name("/Game/" + "A" * 200)
        self.assertLessEqual(len(name), 149)
        self.assertNotIn("/", name)
        self.assertTrue(name.endswith(".png"))

    def test_picture_action_evidence_is_not_name_guessing(self):
        exports = [{"Name": "PictureDefault", "Type": "Actor", "Properties": {
            "Actions": [{"bShowPicture": False}, {"bShowPicture": True,
                        "ShowPictureIdentifier": "None"}]}}]
        evidence = export.picture_actions(exports)
        self.assertEqual(len(evidence), 1)
        self.assertEqual(evidence[0]["json_pointer"], "/0/Properties/Actions/1")
        self.assertEqual(evidence[0]["action"]["ShowPictureIdentifier"], "None")


if __name__ == "__main__":
    unittest.main()
