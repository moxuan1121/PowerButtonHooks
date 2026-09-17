import pathlib
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
        self.assertIn("TARGET = iphone:clang:latest:15.6", MAKEFILE)
        control = (ROOT / "control").read_text(encoding="utf-8")
        self.assertIn("firmware (>= 15.6), firmware (<< 15.7)", control)

    def test_requested_actions_and_settings_are_wired(self):
        contracts = {
            "media": "MRMediaRemoteSendCommand(2, nil)",
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
