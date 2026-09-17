#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

extern void MRMediaRemoteSendCommand(unsigned int command, id userInfo);

static CFStringRef const PBHPreferences = CFSTR("com.moxuan1121.powerbuttonhooks");

static BOOL PBHEnabled(void) {
    CFPreferencesAppSynchronize(PBHPreferences);
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("Enabled"), PBHPreferences);
    BOOL enabled = !value || (CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue(value));
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

static BOOL PBHPerformAction(NSString *action) {
    if ([action isEqualToString:@"media"]) {
        MRMediaRemoteSendCommand(2, nil); // MediaRemote play/pause toggle.
        return YES;
    }
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
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    Class overlayClass = objc_getClass("SBTransientOverlayWindow");
    if (!window || !overlayClass || ![window isKindOfClass:overlayClass]) return NO;

    static NSArray<NSString *> *serviceIDs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        serviceIDs = @[@"com.apple.PassbookUIService", @"com.apple.CoreAuthUI"];
    });

    NSString *description = window.description;
    SEL bundleSelector = NSSelectorFromString(@"_axRemoteServiceBundleIdentifier");
    NSString *bundleID = nil;
    if ([window respondsToSelector:bundleSelector]) {
        id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        bundleID = sendObject(window, bundleSelector);
    }

    for (NSString *serviceID in serviceIDs) {
        if ([bundleID isEqualToString:serviceID] || [description containsString:serviceID]) return YES;
    }
    return NO;
}

%hook SBLockHardwareButtonActions

- (void)doublePress:(id)press {
    if (PBHIsPurchaseAuthenticationActive() || !PBHEnabled() ||
        !PBHPerformAction(PBHAction(CFSTR("DoublePressAction"), @"media"))) {
        %orig;
    }
}

- (void)triplePress:(id)press {
    if (!PBHEnabled() || !PBHPerformAction(PBHAction(CFSTR("TriplePressAction"), @"flashlight"))) {
        %orig;
    }
}

- (void)quadruplePress:(id)press {
    if (!PBHEnabled() || !PBHPerformAction(PBHAction(CFSTR("QuadruplePressAction"), @"ai-window"))) {
        %orig;
    }
}

- (void)longPress:(UIGestureRecognizer *)recognizer {
    if (!PBHEnabled()) {
        %orig;
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan &&
        !PBHPerformAction(PBHAction(CFSTR("LongPressAction"), @"ai-camera"))) {
        %orig;
    }
}

%end
