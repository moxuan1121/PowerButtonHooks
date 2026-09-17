#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static CFStringRef const SGPreferences = CFSTR("com.moxuan1121.powerbuttonhooks");

typedef NS_ENUM(NSUInteger, SGMode) {
    SGModeOriginal,
    SGModeNotify,
    SGModeNotifyAndOriginal,
};

static SGMode SGModeForKey(CFStringRef key) {
    CFPreferencesAppSynchronize(SGPreferences);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, SGPreferences);
    SGMode mode = SGModeOriginal;

    if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
        if (CFEqual(value, CFSTR("notify"))) mode = SGModeNotify;
        else if (CFEqual(value, CFSTR("notify-original"))) mode = SGModeNotifyAndOriginal;
    }

    if (value) CFRelease(value);
    return mode;
}

static BOOL SGBoolPreference(CFStringRef key) {
    CFPreferencesAppSynchronize(SGPreferences);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, SGPreferences);
    BOOL enabled = value && CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue(value);
    if (value) CFRelease(value);
    return enabled;
}

static void SGPost(CFStringRef name) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(), name, NULL, NULL, true
    );
}

static BOOL SGIsAuthenticated(void) {
    Class managerClass = objc_getClass("SBLockScreenManager");
    if (!managerClass || ![managerClass respondsToSelector:@selector(sharedInstance)]) return NO;

    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    id manager = sendObject(managerClass, @selector(sharedInstance));
    SEL coverSheetSelector = NSSelectorFromString(@"coverSheetViewController");
    if (![manager respondsToSelector:coverSheetSelector]) return NO;
    id coverSheet = sendObject(manager, coverSheetSelector);
    SEL authenticatedSelector = NSSelectorFromString(@"isAuthenticated");
    return [coverSheet respondsToSelector:authenticatedSelector] && sendBool(coverSheet, authenticatedSelector);
}

static BOOL SGIsPurchaseAuthenticationActive(void) {
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

static BOOL SGShouldUseOriginal(SGMode mode) {
    return mode == SGModeOriginal || (SGBoolPreference(CFSTR("DisableWhenLocked")) && !SGIsAuthenticated());
}

%hook SBLockHardwareButtonActions

- (void)doublePress:(id)press {
    SGMode mode = SGModeForKey(CFSTR("DoublePressMode"));
    if (SGIsPurchaseAuthenticationActive() || SGShouldUseOriginal(mode)) {
        %orig;
        return;
    }
    SGPost(CFSTR("com.moxuan1121.powerbuttonhooks.double"));
    if (mode == SGModeNotifyAndOriginal) %orig;
}

- (void)triplePress:(id)press {
    SGMode mode = SGModeForKey(CFSTR("TriplePressMode"));
    if (SGShouldUseOriginal(mode)) {
        %orig;
        return;
    }
    SGPost(CFSTR("com.moxuan1121.powerbuttonhooks.triple"));
    if (mode == SGModeNotifyAndOriginal) %orig;
}

- (void)quadruplePress:(id)press {
    SGMode mode = SGModeForKey(CFSTR("QuadruplePressMode"));
    if (SGShouldUseOriginal(mode)) {
        %orig;
        return;
    }
    SGPost(CFSTR("com.moxuan1121.powerbuttonhooks.quadruple"));
    if (mode == SGModeNotifyAndOriginal) %orig;
}

- (void)longPress:(UIGestureRecognizer *)recognizer {
    SGMode mode = SGModeForKey(CFSTR("LongPressMode"));
    if (SGShouldUseOriginal(mode)) {
        %orig;
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        SGPost(CFSTR("com.moxuan1121.powerbuttonhooks.long"));
    }
    if (mode == SGModeNotifyAndOriginal) %orig;
}

%end
