# SquidGesture 1.3.7: side-button path

## Sample and scope

- Package: `com.lclrc.squidgesture`
- Version: `1.3.7`
- Architecture: fat `arm64` + `arm64e`
- Minimum OS recorded by Mach-O: iOS 15.0
- SHA-256: `ABA10272DAAA5D69BF47F54CA21997F4DD74995B8AE88DC08CD8BDF2F0957AD7`
- Injection filter: `com.apple.springboard`

The binary loads `SpringBoardFoundation`, `MediaRemote`, UIKit, Substrate, and RootHide's `libroothide`. Only the physical lock/side-button path is covered here.

## Hook registration recovered from the constructor

The arm64 constructor at `0x2cf58` calls `MSHookMessageEx`. For the class group corresponding to `SBLockHardwareButtonActions`, the registrations are:

| Selector | Replacement IMP | Original IMP slot |
| --- | ---: | ---: |
| `quadruplePress:` | `0x41800` | `0x5cbe8` |
| `triplePress:` | `0x41c90` | `0x5cbf0` |
| `doublePress:` | `0x420f8` | `0x5cbf8` |
| `longPress:` | `0x42e54` | `0x5cc00` |

All four replacements query `SBLockScreenManager.sharedInstance.coverSheetViewController.isAuthenticated` before dispatching to the tweak's action store (`SGActionStore sg_doAction:`). The long-press replacement also checks the recognizer's `state`, preventing repeated action dispatch as the recognizer changes state.

`hardwareButtonInteractionForLockButton` and `consumeTriplePressUp` also appear in the binary, but they belong to the accessibility-action implementation (`SGActionStore sg_triggerAccessibility`), not to the four side-button hook registrations above.

## Double-press purchase/Face ID passthrough

The replacement at `0x420f8` has an extra guard absent from the triple- and quadruple-press hooks:

1. Obtain `UIApplication.sharedApplication.keyWindow`.
2. Require the window to be an `SBTransientOverlayWindow`.
3. If available, read `_axRemoteServiceBundleIdentifier`.
4. Also inspect the window description as a compatibility fallback.
5. Match either `com.apple.PassbookUIService` or `com.apple.CoreAuthUI`.
6. On a match, invoke the saved original `doublePress:` IMP at `0x5cbf8` and return without calling `SGActionStore`.

The two service identifiers are stored encrypted in the file and are decoded at runtime by the double-press function. Emulating the deterministic decode prefix yields:

```text
0x551b0  com.apple.PassbookUIService
0x551f0  com.apple.CoreAuthUI
0x55230  SBTransientOverlayWindow
0x55270  SBLockScreenManager
```

This is the mechanism that preserves the system's side-button confirmation transaction. The tweak is not trying to reproduce Face ID or decide whether a purchase is valid; it detects that the system authentication overlay owns the interaction and hands the event back to SpringBoard's original handler.

## Reconstructed flow

```text
side-button double press
        |
        v
SBLockHardwareButtonActions.doublePress:
        |
        +-- purchase/CoreAuth transient overlay active? -- yes --> original doublePress:
        |
        +-- configured for original / disallowed while locked? --> original doublePress:
        |
        +-- master switch disabled / action unavailable? --> original doublePress:
        |
        +-- otherwise --> selected local action dispatcher
```

## Compatibility boundary

These are private SpringBoard interfaces and can change between iOS releases. This reconstructed package supports iOS 15.x. Disabling the master switch restores every original handler, and an unavailable/unknown action falls back to the original handler. Purchase authentication is always passed through regardless of configuration.

The reconstruction now registers these four methods with `MSHookMessageEx`, matching the original constructor instead of relying on automatic Logos hook setup. Each registration is conditional at SpringBoard startup; an action configured as `none` does not install its corresponding hook.
