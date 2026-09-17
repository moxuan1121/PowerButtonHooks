#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>
#import <spawn.h>

extern char **environ;

static NSString *const PBHDomain = @"com.moxuan1121.powerbutton";

static id PBHReadPreference(NSString *key, id fallback) {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)PBHDomain
    );
    return value ? CFBridgingRelease(value) : fallback;
}

static void PBHWritePreference(NSString *key, id value) {
    CFPreferencesSetAppValue(
        (__bridge CFStringRef)key, (__bridge CFPropertyListRef)value,
        (__bridge CFStringRef)PBHDomain
    );
    CFPreferencesAppSynchronize((__bridge CFStringRef)PBHDomain);
}

static NSArray<NSArray<NSString *> *> *PBHActions(void) {
    return @[
        @[@"无", @"none"],
        @[@"媒体播放 / 暂停", @"media"],
        @[@"手电筒", @"flashlight"],
        @[@"AI 窗口", @"ai-window"],
        @[@"AI 相机", @"ai-camera"]
    ];
}

@interface PBHActionListController : PSListController
@end

@interface PBHRootListController : PSListController
@end

@implementation PBHActionListController {
    NSString *_preferenceKey;
    NSString *_defaultAction;
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    _preferenceKey = [[specifier propertyForKey:@"key"] copy];
    _defaultAction = [[specifier propertyForKey:@"default"] copy];
    self.title = [specifier propertyForKey:@"actionTitle"];
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"选择分发动作"];
    [group setProperty:@"选择“无”后，重启 SpringBoard 才会完全停止该动作的挂钩。" forKey:@"footerText"];
    [items addObject:group];

    NSString *current = PBHReadPreference(_preferenceKey, _defaultAction);
    for (NSArray<NSString *> *entry in PBHActions()) {
        NSString *title = [current isEqualToString:entry[1]] ? [@"✓ " stringByAppendingString:entry[0]] : entry[0];
        PSSpecifier *choice = [PSSpecifier preferenceSpecifierNamed:title
            target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [choice setProperty:entry[1] forKey:@"actionValue"];
        [items addObject:choice];
    }
    _specifiers = items.copy;
    return _specifiers;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *choice = _specifiers[indexPath.row + 1];
    NSString *value = [choice propertyForKey:@"actionValue"];
    if (!value) return;
    PBHWritePreference(_preferenceKey, value);
    [self.navigationController popViewControllerAnimated:YES];
}

@end


@implementation PBHRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"电源键动作"];
    [group setProperty:@"商店购买和系统认证期间，双击始终交还给系统。选择“无”后需重启 SpringBoard 才会卸载对应挂钩。"
                  forKey:@"footerText"];
    [items addObject:group];

    PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"启用"
        target:self set:@selector(setPreferenceValue:specifier:)
        get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [enabled setProperty:@"Enabled" forKey:@"key"];
    [enabled setProperty:@YES forKey:@"default"];
    [enabled setProperty:[UIImage systemImageNamed:@"power"] forKey:@"iconImage"];
    [items addObject:enabled];

    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"双击", @"DoublePressAction", @"media"],
        @[@"三连击", @"TriplePressAction", @"flashlight"],
        @[@"长按", @"LongPressAction", @"ai-camera"]
    ];

    for (NSArray<NSString *> *row in rows) {
        PSSpecifier *action = [PSSpecifier preferenceSpecifierNamed:row[0]
            target:self set:nil get:nil detail:PBHActionListController.class
            cell:PSLinkCell edit:nil];
        [action setProperty:row[1] forKey:@"key"];
        [action setProperty:row[2] forKey:@"default"];
        [action setProperty:row[0] forKey:@"actionTitle"];
        [items addObject:action];
    }

    _specifiers = items.copy;
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return PBHReadPreference([specifier propertyForKey:@"key"], [specifier propertyForKey:@"default"]);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    PBHWritePreference([specifier propertyForKey:@"key"], value);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"PowerButton";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"重启 SB" style:UIBarButtonItemStylePlain
        target:self action:@selector(respring)];
}

- (void)respring {
    pid_t pid;
    char *arguments[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, jbroot("/usr/bin/killall"), NULL, NULL, arguments, environ);
}

@end
