#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

static CFStringRef const PBHPreferences = CFSTR("com.moxuan1121.powerbutton");

@interface AVFlashlight : NSObject
- (float)flashlightLevel;
- (void)setFlashlightLevel:(float)level withError:(NSError **)error;
@end

static BOOL PBHBooleanPreference(CFStringRef key, BOOL fallback) {
    CFPreferencesAppSynchronize(PBHPreferences);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, PBHPreferences);
    BOOL enabled = value && CFGetTypeID(value) == CFBooleanGetTypeID()
        ? CFBooleanGetValue((CFBooleanRef)value)
        : fallback;
    if (value) CFRelease(value);
    return enabled;
}

static BOOL PBHEnabled(void) {
    return PBHBooleanPreference(CFSTR("Enabled"), YES);
}

static NSString *PBHAction(CFStringRef key, NSString *fallback) {
    CFPreferencesAppSynchronize(PBHPreferences);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, PBHPreferences);
    NSString *action = value && CFGetTypeID(value) == CFStringGetTypeID()
        ? [(__bridge NSString *)value copy]
        : fallback;
    if (value) CFRelease(value);
    return action;
}

static void PBHPost(CFStringRef name) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(), name, NULL, NULL, true
    );
}

static AVFlashlight *PBHFlashlight(void) {
    static AVFlashlight *flashlight;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        flashlight = [objc_getClass("AVFlashlight") new];
    });
    return flashlight;
}

static BOOL PBHToggleMedia(void) {
    typedef void (*SendCommand)(unsigned int, id);
    static SendCommand sendCommand;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *mediaRemote = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY
        );
        sendCommand = mediaRemote ? (SendCommand)dlsym(mediaRemote, "MRMediaRemoteSendCommand") : NULL;
    });
    if (!sendCommand) return NO;
    sendCommand(2, nil);
    return YES;
}

static BOOL PBHPerformAction(NSString *action) {
    if ([action isEqualToString:@"media"]) return PBHToggleMedia();
    if ([action isEqualToString:@"flashlight"]) {
        id flashlight = PBHFlashlight();
        SEL levelSelector = NSSelectorFromString(@"flashlightLevel");
        SEL setSelector = NSSelectorFromString(@"setFlashlightLevel:withError:");
        if (!flashlight || ![flashlight respondsToSelector:levelSelector] ||
            ![flashlight respondsToSelector:setSelector]) return NO;

        float (*sendFloat)(id, SEL) = (float (*)(id, SEL))objc_msgSend;
        void (*setLevel)(id, SEL, float, NSError **) =
            (void (*)(id, SEL, float, NSError **))objc_msgSend;
        setLevel(flashlight, setSelector, sendFloat(flashlight, levelSelector) > 0.0f ? 0.0f : 1.0f, NULL);
        return YES;
    }
    if ([action isEqualToString:@"ai-window"]) {
        PBHPost(CFSTR("com.moxuan.regionshot/AIWindow"));
        return YES;
    }
    if ([action isEqualToString:@"ai-camera"]) {
        PBHPost(CFSTR("com.moxuan.regionshot/AICamera"));
        return YES;
    }
    return NO;
}

static BOOL PBHIsPurchaseAuthenticationActive(void) {
    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    UIWindow *window = sendObject(UIApplication.sharedApplication, NSSelectorFromString(@"keyWindow"));
    Class overlayClass = objc_getClass("SBTransientOverlayWindow");
    if (!window || !overlayClass || ![window isKindOfClass:overlayClass]) return NO;

    NSString *bundleID = nil;
    SEL bundleSelector = NSSelectorFromString(@"_axRemoteServiceBundleIdentifier");
    if ([window respondsToSelector:bundleSelector]) bundleID = sendObject(window, bundleSelector);
    for (NSString *serviceID in @[@"com.apple.PassbookUIService", @"com.apple.CoreAuthUI"]) {
        if ([bundleID isEqualToString:serviceID] || [window.description containsString:serviceID]) return YES;
    }
    return NO;
}

static BOOL PBHLowPowerSessionActive;
static BOOL PBHLowPowerEnabledByPlugin;

static BOOL PBHSetLowPowerMode(BOOL enabled) {
    Class batterySaverClass = objc_getClass("_CDBatterySaver");
    SEL batterySaverSelector = NSSelectorFromString(@"batterySaver");
    SEL setPowerModeSelector = NSSelectorFromString(@"setPowerMode:error:");
    if (!batterySaverClass || ![batterySaverClass respondsToSelector:batterySaverSelector]) return NO;

    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id batterySaver = sendObject(batterySaverClass, batterySaverSelector);
    if (!batterySaver || ![batterySaver respondsToSelector:setPowerModeSelector]) return NO;

    BOOL (*setPowerMode)(id, SEL, NSInteger, NSError **) =
        (BOOL (*)(id, SEL, NSInteger, NSError **))objc_msgSend;
    return setPowerMode(batterySaver, setPowerModeSelector, enabled ? 1 : 0, NULL);
}

static BOOL PBHIsActualDeviceLock(void) {
    Class presentationManagerClass = objc_getClass("SBCoverSheetPresentationManager");
    SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
    SEL dismissedSelector = NSSelectorFromString(@"hasBeenDismissedSinceKeybagLock");
    if (!presentationManagerClass ||
        ![presentationManagerClass respondsToSelector:sharedInstanceSelector]) return NO;

    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id presentationManager = sendObject(presentationManagerClass, sharedInstanceSelector);
    if (!presentationManager || ![presentationManager respondsToSelector:dismissedSelector]) return NO;

    BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return !sendBool(presentationManager, dismissedSelector);
}

static void PBHHandleUILockState(BOOL locked) {
    if (locked) {
        if (!PBHIsActualDeviceLock() || PBHLowPowerSessionActive || !PBHEnabled() ||
            !PBHBooleanPreference(CFSTR("LowPowerOnLock"), NO)) return;

        PBHLowPowerSessionActive = YES;
        if (!NSProcessInfo.processInfo.lowPowerModeEnabled) {
            PBHLowPowerEnabledByPlugin = PBHSetLowPowerMode(YES);
        }
        return;
    }

    if (!PBHLowPowerSessionActive) return;
    if (PBHLowPowerEnabledByPlugin && NSProcessInfo.processInfo.lowPowerModeEnabled) {
        PBHSetLowPowerMode(NO);
    }
    PBHLowPowerSessionActive = NO;
    PBHLowPowerEnabledByPlugin = NO;
}

static void (*PBHOriginalDouble)(id, SEL, id);
static void (*PBHOriginalTriple)(id, SEL, id);
static void (*PBHOriginalLong)(id, SEL, UIGestureRecognizer *);
static void (*PBHOriginalSetUILocked)(id, SEL, BOOL);
static void (*PBHOriginalPostLockCompletedNotification)(id, SEL, BOOL);
static BOOL PBHUsesLockCompletionHook;

static void PBHDouble(id self, SEL command, id press) {
    if (PBHIsPurchaseAuthenticationActive() || !PBHEnabled() ||
        !PBHPerformAction(PBHAction(CFSTR("DoublePressAction"), @"media"))) {
        PBHOriginalDouble(self, command, press);
    }
}

static void PBHTriple(id self, SEL command, id press) {
    if (!PBHEnabled() || !PBHPerformAction(PBHAction(CFSTR("TriplePressAction"), @"flashlight"))) {
        PBHOriginalTriple(self, command, press);
    }
}

static void PBHLong(id self, SEL command, UIGestureRecognizer *recognizer) {
    if (!PBHEnabled()) {
        PBHOriginalLong(self, command, recognizer);
    } else if (recognizer.state == UIGestureRecognizerStateBegan &&
               !PBHPerformAction(PBHAction(CFSTR("LongPressAction"), @"ai-camera"))) {
        PBHOriginalLong(self, command, recognizer);
    }
}

static void PBHSetUILocked(id self, SEL command, BOOL locked) {
    PBHOriginalSetUILocked(self, command, locked);
    if (!locked) {
        PBHHandleUILockState(NO);
    } else if (!PBHUsesLockCompletionHook) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PBHHandleUILockState(YES);
        });
    }
}

static void PBHPostLockCompletedNotification(id self, SEL command, BOOL argument) {
    PBHOriginalPostLockCompletedNotification(self, command, argument);
    dispatch_async(dispatch_get_main_queue(), ^{
        PBHHandleUILockState(YES);
    });
}

static BOOL PBHShouldHook(CFStringRef key, NSString *fallback) {
    return ![PBHAction(key, fallback) isEqualToString:@"none"];
}

static void PBHHook(Class target, SEL selector, IMP replacement, IMP *original) {
    if (target && class_getInstanceMethod(target, selector)) {
        MSHookMessageEx(target, selector, replacement, original);
    }
}

__attribute__((constructor)) static void PBHInitialize(void) {
    @autoreleasepool {
        Class button = objc_getClass("SBLockHardwareButton");
        if (!button) return;

        if (PBHShouldHook(CFSTR("DoublePressAction"), @"media")) {
            PBHHook(button, @selector(doublePress:), (IMP)PBHDouble, (IMP *)&PBHOriginalDouble);
        }
        if (PBHShouldHook(CFSTR("TriplePressAction"), @"flashlight")) {
            PBHHook(button, @selector(triplePress:), (IMP)PBHTriple, (IMP *)&PBHOriginalTriple);
        }
        if (PBHShouldHook(CFSTR("LongPressAction"), @"ai-camera")) {
            PBHHook(button, @selector(longPress:), (IMP)PBHLong, (IMP *)&PBHOriginalLong);
        }

        Class lockScreenManager = objc_getClass("SBLockScreenManager");
        SEL lockStateSelector = NSSelectorFromString(@"_reallySetUILocked:");
        if (!class_getInstanceMethod(lockScreenManager, lockStateSelector)) {
            lockStateSelector = NSSelectorFromString(@"_setUILocked:");
        }
        PBHHook(lockScreenManager, lockStateSelector, (IMP)PBHSetUILocked,
                (IMP *)&PBHOriginalSetUILocked);

        SEL lockCompletedSelector = NSSelectorFromString(@"_postLockCompletedNotification:");
        if (class_getInstanceMethod(lockScreenManager, lockCompletedSelector)) {
            PBHHook(lockScreenManager, lockCompletedSelector,
                    (IMP)PBHPostLockCompletedNotification,
                    (IMP *)&PBHOriginalPostLockCompletedNotification);
            PBHUsesLockCompletionHook = YES;
        }
    }
}
