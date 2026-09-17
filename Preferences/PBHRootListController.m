#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

static NSString *const PBHDomain = @"com.moxuan1121.powerbutton";

@interface PBHRootListController : PSListController
@end


@implementation PBHRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"电源键动作"];
    [group setProperty:@"商店购买和系统认证期间，双击始终交还给系统。AI 两项需要已安装 RegionShot。"
                  forKey:@"footerText"];
    [items addObject:group];

    PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"启用"
        target:self set:@selector(setPreferenceValue:specifier:)
        get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [enabled setProperty:@"Enabled" forKey:@"key"];
    [enabled setProperty:@YES forKey:@"default"];
    [enabled setProperty:[UIImage systemImageNamed:@"power"] forKey:@"iconImage"];
    [items addObject:enabled];

    NSArray<NSString *> *titles = @[@"媒体播放 / 暂停", @"手电筒", @"AI 窗口", @"AI 相机"];
    NSArray<NSString *> *values = @[@"media", @"flashlight", @"ai-window", @"ai-camera"];
    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"双击", @"DoublePressAction", @"media", @"playpause.fill"],
        @[@"三连击", @"TriplePressAction", @"flashlight", @"lightbulb.fill"],
        @[@"四连击", @"QuadruplePressAction", @"ai-window", @"sparkles"],
        @[@"长按", @"LongPressAction", @"ai-camera", @"camera.fill"]
    ];

    for (NSArray<NSString *> *row in rows) {
        PSSpecifier *action = [PSSpecifier preferenceSpecifierNamed:row[0]
            target:self set:@selector(setPreferenceValue:specifier:)
            get:@selector(readPreferenceValue:) detail:NSClassFromString(@"PSListItemsController")
            cell:PSLinkListCell edit:nil];
        [action setProperty:row[1] forKey:@"key"];
        [action setProperty:row[2] forKey:@"default"];
        [action setProperty:values forKey:@"validValues"];
        [action setProperty:titles forKey:@"validTitles"];
        [action setProperty:[UIImage systemImageNamed:row[3]] forKey:@"iconImage"];
        [items addObject:action];
    }

    _specifiers = items.copy;
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:PBHDomain];
    return [preferences objectForKey:[specifier propertyForKey:@"key"]]
        ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:PBHDomain];
    [preferences setObject:value forKey:[specifier propertyForKey:@"key"]];
    [preferences synchronize];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"PowerButton";
}

@end
