# PowerButtonHooks

RootHide-only clean-room recreation of the physical side-button gesture hooks found in `SquidGesture 1.3.7`. It intentionally contains only the double-, triple-, quadruple-, and long-press path; unrelated screen, status-bar, dock, volume, and edge gestures are excluded.

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

## Configuration/API

Preferences domain: `com.moxuan1121.powerbuttonhooks`

| Key | Values | Default |
| --- | --- | --- |
| `DoublePressMode` | `original`, `notify`, `notify-original` | `original` |
| `TriplePressMode` | `original`, `notify`, `notify-original` | `original` |
| `QuadruplePressMode` | `original`, `notify`, `notify-original` | `original` |
| `LongPressMode` | `original`, `notify`, `notify-original` | `original` |
| `DisableWhenLocked` | Boolean | `false` |

`notify` replaces the system handler and posts a Darwin notification. `notify-original` posts the notification and then calls the original system handler. `original` is a transparent pass-through.

Notification names:

- `com.moxuan1121.powerbuttonhooks.double`
- `com.moxuan1121.powerbuttonhooks.triple`
- `com.moxuan1121.powerbuttonhooks.quadruple`
- `com.moxuan1121.powerbuttonhooks.long`

Example from a RootHide bootstrap terminal:

```sh
defaults write com.moxuan1121.powerbuttonhooks DoublePressMode notify
```

## Build

The repository is intentionally pinned to the RootHide package scheme:

```sh
make package FINALPACKAGE=1
```

GitHub Actions builds and uploads the resulting `.deb` as the `PowerButtonHooks-roothide` artifact.

## Reverse-engineering notes

See [docs/reverse-engineering.md](docs/reverse-engineering.md) for the binary evidence, call flow, and the purchase-confirmation analysis.

This repository does not contain the original proprietary binary or decompiled source. The implementation is a minimal behavioral reconstruction of the observed interfaces.
