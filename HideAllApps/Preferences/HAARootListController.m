#import "HAARootcomListController.h"
#import "HAAAppPicker.yController.h"
#import <notify.h>
our#import <spawn.hname>

#define kSuiteName @".hideallapps"
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

        // ===== 隐藏手势 =====
        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"隐藏手势（只能选一个）"];
        [group2 setProperty:@"打开其中一个开关后，另一个会自动关闭" forKey:@"footerText"];
        [specs addObject:group2];

        NSArray *names = @[@"关闭", @"上滑", @"左滑", @"右滑", @"状态栏单击", @"状态栏双击"];
        for (NSInteger i = 0; i < names.count; i++) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:names[i] target:self set:@selector(setGestureValue:specifier:) get:@selector(gestureValue:) detail:nil cell:PSSwitchCell edit:nil];
            [sp setProperty:@(i) forKey:@"gestureIndex"];
            [specs addObject:sp];
        }

        // ===== 摇一摇 =====
        PSSpecifier *group3 = [PSSpecifier groupSpecifierWithName:@"摇一摇（只隐藏，独立开关）"];
        [group3 setProperty:@"摇一摇手机只隐藏，恢复请用上面的状态栏双击手势" forKey:@"footerText"];
        [specs addObject:group3];

        PSSpecifier *shake = [PSSpecifier preferenceSpecifierNamed:@"启用摇一摇隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [shake setProperty:@"shakeEnabled" forKey:@"key"];
        [shake setProperty:@NO forKey:@"default"];
        [specs addObject:shake];

        // ===== 状态栏图标 总开关 =====
        PSSpecifier *groupSB = [PSSpecifier groupSpecifierWithName:@"状态栏显示 App 图标"];
        [groupSB setProperty:@"打开过的 App 图标会显示在状态栏，App 完全退出后消失" forKey:@"footerText"];
        [specs addObject:groupSB];

        PSSpecifier *sbEnable = [PSSpecifier preferenceSpecifierNamed:@"启用状态栏图标" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [sbEnable setProperty:@"statusBarIconEnabled" forKey:@"key"];
        [sbEnable setProperty:@NO forKey:@"default"];
        [specs addObject:sbEnable];

        // ===== 图标大小（互斥单选）=====
        PSSpecifier *groupSize = [PSSpecifier groupSpecifierWithName:@"图标大小"];
        [specs addObject:groupSize];

        NSArray *sizeNames = @[@"很小（10pt）", @"小（12pt）", @"中（14pt）", @"大（16pt）", @"很大（18pt）", @"超大（22pt）"];
        NSArray *sizeVals  = @[@10, @12, @14, @16, @18, @22];
        for (NSInteger i = 0; i < sizeNames.count; i++) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:sizeNames[i] target:self set:@selector(setSizeValue:specifier:) get:@selector(sizeValue:) detail:nil cell:PSSwitchCell edit:nil];
            [sp setProperty:sizeVals[i] forKey:@"sizeValue"];
            [specs addObject:sp];
        }

        // ===== 图标位置（互斥单选）=====
        PSSpecifier *groupPos = [PSSpecifier groupSpecifierWithName:@"图标位置（从左到右）"];
        [groupPos setProperty:@"注意：位置靠右会盖住信号/电量图标，建议选「偏右」或「居中」" forKey:@"footerText"];
        [specs addObject:groupPos];

        NSArray *posNames = @[@"最左", @"偏左", @"居中", @"偏右", @"最右"];
        NSArray *posVals  = @[@0.1, @0.3, @0.5, @0.7, @0.9];
        for (NSInteger i = 0; i < posNames.count; i++) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:posNames[i] target:self set:@selector(setPosValue:specifier:) get:@selector(posValue:) detail:nil cell:PSSwitchCell edit:nil];
            [sp setProperty:posVals[i] forKey:@"posValue"];
            [specs addObject:sp];
        }

        // ===== 单独隐藏的 App =====
        PSSpecifier *group4 = [PSSpecifier groupSpecifierWithName:@"单独选择要隐藏的 App"];
        [group4 setProperty:@"这些 App 会一直隐藏（即使未启用「隐藏所有」）" forKey:@"footerText"];
        [specs addObject:group4];

        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:@"选择隐藏的 App" target:self set:nil get:nil detail:[HAAAppPickerController class] cell:PSLinkCell edit:nil];
        [specs addObject:pick];

        // ===== 注销 =====
        PSSpecifier *groupR = [PSSpecifier groupSpecifierWithName:@"重启桌面"];
        [groupR setProperty:@"点击下方按钮重启 SpringBoard，让插件完全生效" forKey:@"footerText"];
        [specs addObject:groupR];

        PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:@"注销（重启 SpringBoard）" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [respring setProperty:NSStringFromSelector(@selector(respringTapped)) forKey:@"action"];
        [specs addObject:respring];

        _specifiers = specs;
    }
    return _specifiers;
}

// ====== 通用读写 ======
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

// ====== 手势互斥 ======
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

// ====== 大小互斥 ======
- (id)sizeValue:(PSSpecifier *)specifier {
    NSInteger myVal = [[specifier propertyForKey:@"sizeValue"] integerValue];
    NSInteger cur = [[self defaults] integerForKey:@"statusBarIconSize"];
    if (cur <= 0) cur = 14;
    return @(myVal == cur);
}

- (void)setSizeValue:(id)value specifier:(PSSpecifier *)specifier {
    NSInteger myVal = [[specifier propertyForKey:@"sizeValue"] integerValue];
    NSUserDefaults *d = [self defaults];
    if ([value boolValue]) {
        [d setInteger:myVal forKey:@"statusBarIconSize"];
        [d synchronize];
        notify_post(kDarwinNotification);
    } else {
        NSInteger cur = [[d objectForKey:@"statusBarIconSize"] integerValue];
        if (cur == myVal) {
            [d setInteger:14 forKey:@"statusBarIconSize"];
            [d synchronize];
            notify_post(kDarwinNotification);
        }
    }
    [self reloadSpecifiers];
}

// ====== 位置互斥 ======
- (id)posValue:(PSSpecifier *)specifier {
    double myVal = [[specifier propertyForKey:@"posValue"] doubleValue];
    double cur = [[[self defaults] objectForKey:@"statusBarIconPos"] doubleValue];
    if (cur <= 0) cur = 0.9;
    return @(fabs(myVal - cur) < 0.01);
}

- (void)setPosValue:(id)value specifier:(PSSpecifier *)specifier {
    double myVal = [[specifier propertyForKey:@"posValue"] doubleValue];
    NSUserDefaults *d = [self defaults];
    if ([value boolValue]) {
        [d setDouble:myVal forKey:@"statusBarIconPos"];
        [d synchronize];
        notify_post(kDarwinNotification);
    } else {
        double cur = [[d objectForKey:@"statusBarIconPos"] doubleValue];
        if (fabs(cur - myVal) < 0.01) {
            [d setDouble:0.9 forKey:@"statusBarIconPos"];
            [d synchronize];
            notify_post(kDarwinNotification);
        }
    }
    [self reloadSpecifiers];
}

// ====== 注销 ======
- (void)respringTapped {
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char * const *)args, NULL);
}

@end
