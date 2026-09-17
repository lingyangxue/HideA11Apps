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

        // ===== 触发手势（开关形式，只能开一个）=====
        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"触发手势（打开任意一个即可，会互斥）"];
        [group2 setProperty:@"打开其中一个开关后，另一个会自动关闭" forKey:@"footerText"];
        [specs addObject:group2];
NSArray *names = @[@"关闭", @"上滑", @"左滑", @"右滑", @"状态栏单击", @"状态栏双击", @"摇一摇"];
        for (NSInteger i = 0; i < names.count; i++) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:names[i] target:self set:@selector(setGestureValue:specifier:) get:@selector(gestureValue:) detail:nil cell:PSSwitchCell edit:nil];
            [sp setProperty:@(i) forKey:@"gestureIndex"];
            [specs addObject:sp];
        }

        // ===== 单独隐藏的 App =====
        PSSpecifier *group3 = [PSSpecifier groupSpecifierWithName:@"单独选择要隐藏的 App"];
        [group3 setProperty:@"这些 App 会一直隐藏（即使未启用「隐藏所有」）" forKey:@"footerText"];
        [specs addObject:group3];

        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:@"选择隐藏的 App" target:self set:nil get:nil detail:[HAAAppPickerController class] cell:PSLinkCell edit:nil];
        [specs addObject:pick];

        _specifiers = specs;
    }
    return _specifiers;
}

// ===== 通用 read/set =====
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

// ===== 手势开关逻辑 =====
- (id)gestureValue:(PSSpecifier *)specifier {
    NSInteger idx = [[specifier propertyForKey:@"gestureIndex"] integerValue];
    NSInteger cur = [[self defaults] integerForKey:@"gestureType"];
    return @(idx == cur);
}

- (void)setGestureValue:(id)value specifier:(PSSpecifier *)specifier {
    NSInteger idx = [[specifier propertyForKey:@"gestureIndex"] integerValue];
    if ([value boolValue]) {
        NSUserDefaults *d = [self defaults];
        [d setInteger:idx forKey:@"gestureType"];
        [d synchronize];
        notify_post(kDarwinNotification);
    } else {
        // 用户手动关掉当前选中的，就设为「关闭」(0)
        NSUserDefaults *d = [self defaults];
        if ([[d objectForKey:@"gestureType"] integerValue] == idx) {
            [d setInteger:0 forKey:@"gestureType"];
            [d synchronize];
            notify_post(kDarwinNotification);
        }
    }
    [self reloadSpecifiers];
}

@end
