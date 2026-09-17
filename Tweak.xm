#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

static CFStringRef const PBHPreferences = CFSTR("com.moxuan1121.powerbutton");

static BOOL PBHEnabled(void) {
    CFPreferencesAppSynchronize(PBHPreferences);
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("Enabled"), PBHPreferences);
    BOOL enabled = !value || (CFGetTypeID(value) == CFBooleanGetTypeID() &&
                              CFBooleanGetValue((CFBooleanRef)value));
    if (value) CFRelease(value);
    return enabled;
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

static id PBHFlashlight(void) {
    static id flashlight;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class flashlightClass = objc_getClass("AVFlashlight");
        BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
        if (flashlightClass && [flashlightClass respondsToSelector:@selector(hasFlashlight)] &&
            sendBool(flashlightClass, @selector(hasFlashlight))) {
            flashlight = [flashlightClass new];
        }
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

static void (*PBHOriginalDouble)(id, SEL, id);
static void (*PBHOriginalTriple)(id, SEL, id);
static void (*PBHOriginalQuadruple)(id, SEL, id);
static void (*PBHOriginalLong)(id, SEL, UIGestureRecognizer *);

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

static void PBHQuadruple(id self, SEL command, id press) {
    if (!PBHEnabled() || !PBHPerformAction(PBHAction(CFSTR("QuadruplePressAction"), @"ai-window"))) {
        PBHOriginalQuadruple(self, command, press);
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

static BOOL PBHShouldHook(CFStringRef key, NSString *fallback) {
    return PBHEnabled() && ![PBHAction(key, fallback) isEqualToString:@"none"];
}

__attribute__((constructor)) static void PBHInitialize(void) {
    @autoreleasepool {
        Class actions = objc_getClass("SBLockHardwareButtonActions");
        if (!actions) return;

        if (PBHShouldHook(CFSTR("DoublePressAction"), @"media")) {
            MSHookMessageEx(actions, @selector(doublePress:), (IMP)PBHDouble, (IMP *)&PBHOriginalDouble);
        }
        if (PBHShouldHook(CFSTR("TriplePressAction"), @"flashlight")) {
            MSHookMessageEx(actions, @selector(triplePress:), (IMP)PBHTriple, (IMP *)&PBHOriginalTriple);
        }
        if (PBHShouldHook(CFSTR("QuadruplePressAction"), @"ai-window")) {
            MSHookMessageEx(actions, @selector(quadruplePress:), (IMP)PBHQuadruple, (IMP *)&PBHOriginalQuadruple);
        }
        if (PBHShouldHook(CFSTR("LongPressAction"), @"ai-camera")) {
            MSHookMessageEx(actions, @selector(longPress:), (IMP)PBHLong, (IMP *)&PBHOriginalLong);
        }
    }
}
