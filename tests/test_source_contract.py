import pathlib
import unittest


ROOT = pathlib.Path(__file__).parents[1]
SOURCE = (ROOT / "Tweak.xm").read_text(encoding="utf-8")
MAKEFILE = (ROOT / "Makefile").read_text(encoding="utf-8")


class SourceContractTest(unittest.TestCase):
    def test_purchase_confirmation_always_passthroughs(self):
        self.assertIn("com.apple.PassbookUIService", SOURCE)
        self.assertIn("com.apple.CoreAuthUI", SOURCE)
        self.assertIn(
            "if (SGIsPurchaseAuthenticationActive() || SGShouldUseOriginal(mode)) {\n        %orig;",
            SOURCE,
            "double press must preserve system auth",
        )

    def test_all_power_gestures_are_hooked(self):
        for selector in ("doublePress:", "triplePress:", "quadruplePress:", "longPress:"):
            self.assertIn(selector, SOURCE)

    def test_roothide_only_build(self):
        self.assertIn("THEOS_PACKAGE_SCHEME = roothide", MAKEFILE)


if __name__ == "__main__":
    unittest.main()
