# PowerButton

RootHide-only iOS 15 clean-room recreation of the physical side-button gesture hooks found in `SquidGesture 1.3.7`. It intentionally contains only the double-, triple-, quadruple-, and long-press path; unrelated screen, status-bar, dock, volume, and edge gestures are excluded.

## What it hooks

`SBLockHardwareButtonActions`:

- `doublePress:`
- `triplePress:`
- `quadruplePress:`
- `longPress:`

The double-press hook always passes through to Apple's original implementation while a purchase/authentication overlay belongs to either:

- `com.apple.PassbookUIService`
- `com.apple.CoreAuthUI`

This is the important reason a configured double-press action does not steal the second side-button press used by Apple Pay or App Store Face ID confirmation.

## Settings and actions

Package and preferences identifier: `com.moxuan1121.powerbutton`

The Settings bundle contains a master switch plus selectors for double press, triple press, quadruple press, and long press. Every selector can dispatch one of four actions:

- Media play/pause through MediaRemote.
- Flashlight toggle through the same `AVFlashlight` interface used by the studied package.
- RegionShot AI window through `com.moxuan.regionshot/AIWindow`.
- RegionShot AI camera through `com.moxuan.regionshot/AICamera`.

AI actions require [RegionShot](https://github.com/moxuan1121/RegionShot) to be installed. Defaults are media for double press, flashlight for triple press, AI window for quadruple press, and AI camera for long press.

The bundle is installed at `/Library/PreferenceBundles/PowerButtonPreferences.bundle`. RootHide's package scheme relocates that path into the device's current randomized `.jbroot-*` root, so no device-specific `.jbroot-E05E6FF9B17D8763` value is hard-coded.

## Build

The repository is intentionally pinned to the RootHide package scheme:

```sh
make package FINALPACKAGE=1
```

GitHub Actions builds the new arm64e ABI with Xcode on macOS and uploads the resulting `.deb` as the `PowerButton-roothide` artifact.

## Reverse-engineering notes

See [docs/reverse-engineering.md](docs/reverse-engineering.md) for the binary evidence, call flow, and the purchase-confirmation analysis.

This repository does not contain the original proprietary binary or decompiled source. The implementation is a minimal behavioral reconstruction of the observed interfaces.
