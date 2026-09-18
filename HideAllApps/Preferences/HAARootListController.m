#import "HAARootListController.h"
#import "HAAAppPickerController.h"
#import <notify.h>
#import <spawn.h>
#import <dlfcn.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@interface HAAConfirmRespringController : PSListController
@end

@implementation HAAConfirmRespringController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"注销";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重启桌面"
                                                                   message:@"确定要重启 SpringBoard 吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self doRespring];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doRespring {
    notify_post("com.yourname.hideallapps/respring");
    Class sbcClass = NSClassFromString(@"FBSystemService");
    if (sbcClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id shared = nil;
        if ([sbcClass respondsToSelector:@selector(sharedInstance)]) shared = [sbcClass performSelector:@selector(sharedInstance)];
        if (shared && [shared respondsToSelector:@selector(exitImmediately)]) {
            [shared performSelector:@selector(exitImmediately)];
#pragma clang diagnostic pop
            return;
        }
#pragma clang diagnostic pop
    }
    void (*exitFunc)(int) = (void (*)(int))dlsym(RTLD_DEFAULT, "exit");
    if (exitFunc) exitFunc(0);
}

@end

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

        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"隐藏手势（独立开关，可同时开）"];
        [group2 setProperty:@"每个开关独立，可以同时打开或都关闭" forKey:@"footerText"];
        [specs addObject:group2];

        PSSpecifier *sbSingle = [PSSpecifier preferenceSpecifierNamed:@"状态栏单击" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [sbSingle setProperty:@"statusBarSingleTapEnabled" forKey:@"key"];
        [sbSingle setProperty:@NO forKey:@"default"];
        [specs addObject:sbSingle];

        PSSpecifier *sbDouble = [PSSpecifier preferenceSpecifierNamed:@"状态栏双击" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [sbDouble setProperty:@"statusBarDoubleTapEnabled" forKey:@"key"];
        [sbDouble setProperty:@NO forKey:@"default"];
        [specs addObject:sbDouble];

        PSSpecifier *group3 = [PSSpecifier groupSpecifierWithName:@"摇一摇（只隐藏，独立开关）"];
        [group3 setProperty:@"摇一摇手机只隐藏，恢复请用上面的状态栏双击手势" forKey:@"footerText"];
        [specs addObject:group3];

        PSSpecifier *shake = [PSSpecifier preferenceSpecifierNamed:@"启用摇一摇隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [shake setProperty:@"shakeEnabled" forKey:@"key"];
        [shake setProperty:@NO forKey:@"default"];
        [specs addObject:shake];

        // ===== 左侧下滑 =====
        PSSpecifier *groupL = [PSSpecifier groupSpecifierWithName:@"左侧下滑（独立开关）"];
        [groupL setProperty:@"在屏幕左侧向下滑" forKey:@"footerText"];
        [specs addObject:groupL];

        PSSpecifier *leftEnable = [PSSpecifier preferenceSpecifierNamed:@"启用左侧下滑" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [leftEnable setProperty:@"leftDownEnabled" forKey:@"key"];
        [leftEnable setProperty:@NO forKey:@"default"];
        [specs addObject:leftEnable];

        PSSpecifier *leftRecover = [PSSpecifier preferenceSpecifierNamed:@"左侧下滑 → 恢复显示" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [leftRecover setProperty:@"leftDownRecoverEnabled" forKey:@"key"];
        [leftRecover setProperty:@NO forKey:@"default"];
        [specs addObject:leftRecover];

        PSSpecifier *leftHide = [PSSpecifier preferenceSpecifierNamed:@"左侧下滑 → 隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [leftHide setProperty:@"leftDownHideEnabled" forKey:@"key"];
        [leftHide setProperty:@NO forKey:@"default"];
        [specs addObject:leftHide];

        // ===== 右侧下滑 =====
        PSSpecifier *groupR2 = [PSSpecifier groupSpecifierWithName:@"右侧下滑（独立开关）"];
        [groupR2 setProperty:@"在屏幕右侧向下滑" forKey:@"footerText"];
        [specs addObject:groupR2];

        PSSpecifier *rightEnable = [PSSpecifier preferenceSpecifierNamed:@"启用右侧下滑" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [rightEnable setProperty:@"rightDownEnabled" forKey:@"key"];
        [rightEnable setProperty:@NO forKey:@"default"];
        [specs addObject:rightEnable];

        PSSpecifier *rightRecover = [PSSpecifier preferenceSpecifierNamed:@"右侧下滑 → 恢复显示" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [rightRecover setProperty:@"rightDownRecoverEnabled" forKey:@"key"];
        [rightRecover setProperty:@NO forKey:@"default"];
        [specs addObject:rightRecover];

        PSSpecifier *rightHide = [PSSpecifier preferenceSpecifierNamed:@"右侧下滑 → 隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [rightHide setProperty:@"rightDownHideEnabled" forKey:@"key"];
        [rightHide setProperty:@NO forKey:@"default"];
        [specs addObject:rightHide];

        // ===== 触发区域 =====
        PSSpecifier *groupZone = [PSSpecifier groupSpecifierWithName:@"下滑触发区域（拖动调节，左右通用）"];
        [groupZone setProperty:@"调整后打开「显示调试边框」可以看到区域范围（左红右蓝）" forKey:@"footerText"];
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
        [widthSlider setProperty:@50  forKey:@"min"];
        [widthSlider setProperty:@300 forKey:@"max"];
        [widthSlider setProperty:@150 forKey:@"default"];
        [specs addObject:widthSlider];

        PSSpecifier *debugBorder = [PSSpecifier preferenceSpecifierNamed:@"显示调试边框" target:self set:@selector(setDebugBorder:specifier:) get:@selector(getDebugBorder:) detail:nil cell:PSSwitchCell edit:nil];
        [debugBorder setProperty:@NO forKey:@"default"];
        [specs addObject:debugBorder];

        // ===== 单独隐藏的 App =====
        PSSpecifier *group4 = [PSSpecifier groupSpecifierWithName:@"单独选择要隐藏的 App"];
        [group4 setProperty:@"这些 App 会一直隐藏（即使未启用「隐藏所有」）" forKey:@"footerText"];
        [specs addObject:group4];

        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:@"选择隐藏的 App" target:self set:nil get:nil detail:[HAAAppPickerController class] cell:PSLinkCell edit:nil];
        [specs addObject:pick];

        // ===== 注销 =====
        PSSpecifier *groupR = [PSSpecifier groupSpecifierWithName:@"重启桌面"];
        [groupR setProperty:@"点击下方按钮，会弹出确认对话框" forKey:@"footerText"];
        [specs addObject:groupR];

        PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:@"注销（重启 SpringBoard）" target:self set:nil get:nil detail:[HAAConfirmRespringController class] cell:PSLinkCell edit:nil];
        [specs addObject:respring];

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
    if (on) {
        notify_post("com.yourname.hideallapps/showBorder");
    } else {
        notify_post("com.yourname.hideallapps/hideBorder");
    }
}

@end
