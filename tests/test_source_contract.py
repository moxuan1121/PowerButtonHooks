import pathlib
import struct
import unittest


ROOT = pathlib.Path(__file__).parents[1]
SOURCE = (ROOT / "Tweak.xm").read_text(encoding="utf-8")
MAKEFILE = (ROOT / "Makefile").read_text(encoding="utf-8")
PREFERENCES = (ROOT / "Preferences" / "PBHRootListController.m").read_text(encoding="utf-8")


class SourceContractTest(unittest.TestCase):
    def test_purchase_confirmation_always_passthroughs(self):
        self.assertIn("com.apple.PassbookUIService", SOURCE)
        self.assertIn("com.apple.CoreAuthUI", SOURCE)
        self.assertIn(
            "if (PBHIsPurchaseAuthenticationActive() || !PBHEnabled() ||",
            SOURCE,
            "double press must preserve system auth",
        )

    def test_all_power_gestures_are_hooked(self):
        for selector in ("doublePress:", "triplePress:", "quadruplePress:", "longPress:"):
            self.assertIn(selector, SOURCE)

    def test_roothide_only_build(self):
        self.assertIn("THEOS_PACKAGE_SCHEME = roothide", MAKEFILE)
        self.assertIn("TARGET = iphone:clang:16.5:15.6", MAKEFILE)
        control = (ROOT / "control").read_text(encoding="utf-8")
        self.assertIn("firmware (>= 15.6), firmware (<< 15.7)", control)
        self.assertIn("Package: com.moxuan1121.powerbutton", control)
        self.assertIn("Name: PowerButton", control)

    def test_settings_identity_and_icon_scales(self):
        self.assertIn('@"com.moxuan1121.powerbutton"', PREFERENCES)
        expected = {
            "PowerButtonIcon.png": (29, 29),
            "PowerButtonIcon@2x.png": (58, 58),
            "PowerButtonIcon@3x.png": (87, 87),
        }
        for name, size in expected.items():
            data = (ROOT / "Preferences" / "Resources" / name).read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", data[16:24]), size)

    def test_requested_actions_and_settings_are_wired(self):
        contracts = {
            "media": 'dlsym(mediaRemote, "MRMediaRemoteSendCommand")',
            "flashlight": "setFlashlightLevel:withError:",
            "ai-window": "com.moxuan.regionshot/AIWindow",
            "ai-camera": "com.moxuan.regionshot/AICamera",
        }
        for value, implementation in contracts.items():
            self.assertIn(implementation, SOURCE)
            self.assertIn(f'@"{value}"', PREFERENCES)

        for key in ("Enabled", "DoublePressAction", "TriplePressAction", "QuadruplePressAction", "LongPressAction"):
            self.assertIn(f'@"{key}"', PREFERENCES)


if __name__ == "__main__":
    unittest.main()
