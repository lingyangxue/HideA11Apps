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

        [specs addObject:[PSSpecifier groupSpecifierWithName:@"功能开关"]];

        PSSpecifier *enable = [PSSpecifier preferenceSpecifierNamed:@"启用插件" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enable setProperty:@"enabled" forKey:@"key"];
        [enable setProperty:@NO forKey:@"default"];
        [specs addObject:enable];

        PSSpecifier *hideAll = [PSSpecifier preferenceSpecifierNamed:@"立即隐藏所有 App" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [hideAll setProperty:@"hideAll" forKey:@"key"];
        [hideAll setProperty:@NO forKey:@"default"];
        [specs addObject:hideAll];

        PSSpecifier *groupL = [PSSpecifier groupSpecifierWithName:@"左侧下滑（独立开关）"];
        [groupL setProperty:@"在屏幕左侧向下滑，切换隐藏/恢复显示" forKey:@"footerText"];
        [specs addObject:groupL];

        PSSpecifier *leftEnable = [PSSpecifier preferenceSpecifierNamed:@"启用左侧下滑" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [leftEnable setProperty:@"leftDownEnabled" forKey:@"key"];
        [leftEnable setProperty:@NO forKey:@"default"];
        [specs addObject:leftEnable];

        PSSpecifier *groupR = [PSSpecifier groupSpecifierWithName:@"右侧下滑（独立开关）"];
        [groupR setProperty:@"在屏幕右侧向下滑，切换隐藏/恢复显示" forKey:@"footerText"];
        [specs addObject:groupR];

        PSSpecifier *rightEnable = [PSSpecifier preferenceSpecifierNamed:@"启用右侧下滑" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [rightEnable setProperty:@"rightDownEnabled" forKey:@"key"];
        [rightEnable setProperty:@NO forKey:@"default"];
        [specs addObject:rightEnable];

        PSSpecifier *groupZone = [PSSpecifier groupSpecifierWithName:@"下滑触发区域（拖动调节）"];
        [groupZone setProperty:@"调整后打开「显示调试边框」可以看到区域（左红右蓝）" forKey:@"footerText"];
        [specs addObject:groupZone];

        PSSpecifier *topSlider = [PSSpecifier preferenceSpecifierNamed:@"区域顶部位置" target:self set:@selector(setZoneTop:specifier:) get:@selector(getZoneTop:) detail:nil cell:PSSliderCell edit:nil];
        [topSlider setProperty:@0.0 forKey:@"min"];
        [topSlider setProperty:@1.0 forKey:@"max"];
        [topSlider setProperty:@0.15 forKey:@"default"];
        [specs addObject:topSlider];

        PSSpecifier *bottomSlider = [PSSpecifier preferenceSpecifierNamed:@"区域底部位置" target:self set:@selector(setZoneBottom:specifier:) get:@selector(getZoneBottom:) detail:nil cell:PSSliderCell edit:nil];
        [bottomSlider setProperty:@0.0 forKey:@"min"];
        [bottomSlider setProperty:@1.0 forKey:@"max"];
        [bottomSlider setProperty:@0.85 forKey:@"default"];
        [specs addObject:bottomSlider];

        PSSpecifier *widthSlider = [PSSpecifier preferenceSpecifierNamed:@"左右边界宽度" target:self set:@selector(setZoneWidth:specifier:) get:@selector(getZoneWidth:) detail:nil cell:PSSliderCell edit:nil];
        [widthSlider setProperty:@50 forKey:@"min"];
        [widthSlider setProperty:@300 forKey:@"max"];
        [widthSlider setProperty:@150 forKey:@"default"];
        [specs addObject:widthSlider];

        PSSpecifier *debugBorder = [PSSpecifier preferenceSpecifierNamed:@"显示调试边框" target:self set:@selector(setDebugBorder:specifier:) get:@selector(getDebugBorder:) detail:nil cell:PSSwitchCell edit:nil];
        [debugBorder setProperty:@NO forKey:@"default"];
        [specs addObject:debugBorder];

        PSSpecifier *groupA = [PSSpecifier groupSpecifierWithName:@"单独选择要隐藏的 App"];
        [groupA setProperty:@"这些 App 会一直隐藏" forKey:@"footerText"];
        [specs addObject:groupA];

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

- (id)getZoneTop:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"zoneTopRatio"];
    return v ?: @0.15;
}
- (void)setZoneTop:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setDouble:[value doubleValue] forKey:@"zoneTopRatio"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getZoneBottom:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"zoneBottomRatio"];
    return v ?: @0.85;
}
- (void)setZoneBottom:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setDouble:[value doubleValue] forKey:@"zoneBottomRatio"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getZoneWidth:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"zoneWidth"];
    return v ?: @150;
}
- (void)setZoneWidth:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setDouble:[value doubleValue] forKey:@"zoneWidth"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getDebugBorder:(PSSpecifier *)specifier {
    return @([[self defaults] boolForKey:@"debugBorderEnabled"]);
}
- (void)setDebugBorder:(id)value specifier:(PSSpecifier *)specifier {
    BOOL on = [value boolValue];
    NSUserDefaults *d = [self defaults];
    [d setBool:on forKey:@"debugBorderEnabled"];
    [d synchronize];
    if (on) notify_post("com.yourname.hideallapps/showBorder");
    else    notify_post("com.yourname.hideallapps/hideBorder");
}

@end
