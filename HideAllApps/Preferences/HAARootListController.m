#import "HAARootListController.h"
#import "HAAAppPickerController.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@implementation HAARootListController

- (NSUserDefaults *)defaults { return [[NSUserDefaults alloc] initWithSuiteName:kSuiteName]; }

- (void)viewDidLoad { [super viewDidLoad]; self.title = @"HideAllApps"; }

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        // ===== 功能开关 =====
        [specs addObject:[PSSpecifier groupSpecifierWithName:@"功能开关"]];

        PSSpecifier *enable = [PSSpecifier preferenceSpecifierNamed:@"启用插件" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enable setProperty:@"enabled" forKey:@"key"];
        [enable setProperty:@NO forKey:@"default"];
        [specs addObject:enable];

        PSSpecifier *hideAll = [PSSpecifier preferenceSpecifierNamed:@"立即隐藏所有 App" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [hideAll setProperty:@"hideAll" forKey:@"key"];
        [hideAll setProperty:@NO forKey:@"default"];
        [specs addObject:hideAll];

        // ===== 隐藏手势（互斥单选）=====
        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"隐藏手势（只能选一个）"];
        [group2 setProperty:@"打开其中一个开关后，另一个会自动关闭" forKey:@"footerText"];
        [specs addObject:group2];

        NSArray *names = @[@"关闭", @"上滑", @"左滑", @"右滑", @"状态栏单击", @"状态栏双击"];
        for (NSInteger i = 0; i < names.count; i++) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:names[i] target:self set:@selector(setGestureValue:specifier:) get:@selector(gestureValue:) detail:nil cell:PSSwitchCell edit:nil];
            [sp setProperty:@(i) forKey:@"gestureIndex"];
            [specs addObject:sp];
        }

        // ===== 摇一摇（独立开关，只隐藏）=====
        PSSpecifier *group3 = [PSSpecifier groupSpecifierWithName:@"摇一摇（只隐藏，独立开关）"];
        [group3 setProperty:@"摇一摇手机只隐藏，恢复请用上面的状态栏双击手势" forKey:@"footerText"];
        [specs addObject:group3];

        PSSpecifier *shake = [PSSpecifier preferenceSpecifierNamed:@"启用摇一摇隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [shake setProperty:@"shakeEnabled" forKey:@"key"];
        [shake setProperty:@NO forKey:@"default"];
        [specs addObject:shake];

        // ===== 单独隐藏的 App =====
        PSSpecifier *group4 = [PSSpecifier groupSpecifierWithName:@"单独选择要隐藏的 App"];
        [group4 setProperty:@"这些 App 会一直隐藏（即使未启用「隐藏所有」）" forKey:@"footerText"];
        [specs addObject:group4];

        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:@"选择隐藏的 App" target:self set:nil get:nil detail:[HAAAppPickerController class] cell:PSLinkCell edit:nil];
        [specs addObject:pick];

        _specifiers = specs;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = [[self defaults] objectForKey:key];
    if (value == nil) value = [specifier propertyForKey:@"default"];
    return value ?: @0;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSUserDefaults *d = [self defaults];
    [d setObject:value forKey:key];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)gestureValue:(PSSpecifier *)specifier {
    NSInteger idx = [[specifier propertyForKey:@"gestureIndex"] integerValue];
    NSInteger cur = [[self defaults] integerForKey:@"gestureType"];
    return @(idx == cur);
}

- (void)setGestureValue:(id)value specifier:(PSSpecifier *)specifier {
    NSInteger idx = [[specifier propertyForKey:@"gestureIndex"] integerValue];
    NSUserDefaults *d = [self defaults];
    if ([value boolValue]) {
        [d setInteger:idx forKey:@"gestureType"];
        [d synchronize];
        notify_post(kDarwinNotification);
    } else {
        if ([[d objectForKey:@"gestureType"] integerValue] == idx) {
            [d setInteger:0 forKey:@"gestureType"];
            [d synchronize];
            notify_post(kDarwinNotification);
        }
    }
    [self reloadSpecifiers];
}

@end
