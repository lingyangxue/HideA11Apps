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

        PSSpecifier *groupLD = [PSSpecifier groupSpecifierWithName:@"左侧下滑恢复（独立开关）"];
        [groupLD setProperty:@"在屏幕左侧向下滑，恢复显示所有 App" forKey:@"footerText"];
        [specs addObject:groupLD];

        PSSpecifier *leftDown = [PSSpecifier preferenceSpecifierNamed:@"启用左侧下滑恢复" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [leftDown setProperty:@"leftDownEnabled" forKey:@"key"];
        [leftDown setProperty:@NO forKey:@"default"];
        [specs addObject:leftDown];

        PSSpecifier *groupZone = [PSSpecifier groupSpecifierWithName:@"左侧下滑触发区域（拖动调节）"];
        [groupZone setProperty:@"调整后打开下面的「显示调试边框」可以看到区域范围" forKey:@"footerText"];
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

        PSSpecifier *widthSlider = [PSSpecifier preferenceSpecifierNamed:@"左边界宽度" target:self set:@selector(setZoneWidth:specifier:) get:@selector(getZoneWidth:) detail:nil cell:PSSliderCell edit:nil];
        [widthSlider setProperty:@50  forKey:@"min"];
        [widthSlider setProperty:@300 forKey:@"max"];
        [widthSlider setProperty:@150 forKey:@"default"];
        [specs addObject:widthSlider];

        PSSpecifier *debugBorder = [PSSpecifier preferenceSpecifierNamed:@"显示调试边框（3 秒）" target:self set:@selector(setDebugBorder:specifier:) get:@selector(getDebugBorder:) detail:nil cell:PSSwitchCell edit:nil];
        [debugBorder setProperty:@NO forKey:@"default"];
        [specs addObject:debugBorder];

        PSSpecifier *groupSB = [PSSpecifier groupSpecifierWithName:@"状态栏显示 App 图标"];
        [groupSB setProperty:@"显示最近打开的最多 6 个 App 图标" forKey:@"footerText"];
        [specs addObject:groupSB];

        PSSpecifier *sbEnable = [PSSpecifier preferenceSpecifierNamed:@"启用状态栏图标" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [sbEnable setProperty:@"statusBarIconEnabled" forKey:@"key"];
        [sbEnable setProperty:@NO forKey:@"default"];
        [specs addObject:sbEnable];

        PSSpecifier *groupSize = [PSSpecifier groupSpecifierWithName:@"图标大小（拖动滑块）"];
        [groupSize setProperty:@"范围 8pt ~ 26pt" forKey:@"footerText"];
        [specs addObject:groupSize];

        PSSpecifier *sizeSlider = [PSSpecifier preferenceSpecifierNamed:@"大小" target:self set:@selector(setSizeSlider:specifier:) get:@selector(getSizeSlider:) detail:nil cell:PSSliderCell edit:nil];
        [sizeSlider setProperty:@8  forKey:@"min"];
        [sizeSlider setProperty:@26 forKey:@"max"];
        [sizeSlider setProperty:@14 forKey:@"default"];
        [specs addObject:sizeSlider];

        PSSpecifier *groupPos = [PSSpecifier groupSpecifierWithName:@"水平位置（拖动滑块）"];
        [groupPos setProperty:@"最左 ← → 最右" forKey:@"footerText"];
        [specs addObject:groupPos];

        PSSpecifier *posSlider = [PSSpecifier preferenceSpecifierNamed:@"水平" target:self set:@selector(setPosSlider:specifier:) get:@selector(getPosSlider:) detail:nil cell:PSSliderCell edit:nil];
        [posSlider setProperty:@0.0 forKey:@"min"];
        [posSlider setProperty:@1.0 forKey:@"max"];
        [posSlider setProperty:@0.05 forKey:@"default"];
        [specs addObject:posSlider];

        PSSpecifier *groupY = [PSSpecifier groupSpecifierWithName:@"垂直位置（拖动滑块）"];
        [groupY setProperty:@"0 = 最顶，24 = 往下。默认 8" forKey:@"footerText"];
        [specs addObject:groupY];

        PSSpecifier *ySlider = [PSSpecifier preferenceSpecifierNamed:@"垂直" target:self set:@selector(setYSlider:specifier:) get:@selector(getYSlider:) detail:nil cell:PSSliderCell edit:nil];
        [ySlider setProperty:@0  forKey:@"min"];
        [ySlider setProperty:@24 forKey:@"max"];
        [ySlider setProperty:@8  forKey:@"default"];
        [specs addObject:ySlider];

        PSSpecifier *group4 = [PSSpecifier groupSpecifierWithName:@"单独选择要隐藏的 App"];
        [group4 setProperty:@"这些 App 会一直隐藏（即使未启用「隐藏所有」）" forKey:@"footerText"];
        [specs addObject:group4];

        PSSpecifier *pick = [PSSpecifier preferenceSpecifierNamed:@"选择隐藏的 App" target:self set:nil get:nil detail:[HAAAppPickerController class] cell:PSLinkCell edit:nil];
        [specs addObject:pick];

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
    return @NO;
}
- (void)setDebugBorder:(id)value specifier:(PSSpecifier *)specifier {
    if (![value boolValue]) return;
    notify_post("com.yourname.hideallapps/showBorder");
    [self reloadSpecifiers];
}

- (id)getSizeSlider:(PSSpecifier *)specifier {
    double v = [[self defaults] doubleForKey:@"statusBarIconSize"];
    if (v < 6) v = 14;
    return @(v);
}
- (void)setSizeSlider:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setDouble:[value doubleValue] forKey:@"statusBarIconSize"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getPosSlider:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"statusBarIconPos"];
    return v ?: @0.05;
}
- (void)setPosSlider:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setDouble:[value doubleValue] forKey:@"statusBarIconPos"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getYSlider:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"statusBarIconY"];
    return v ?: @8;
}
- (void)setYSlider:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setDouble:[value doubleValue] forKey:@"statusBarIconY"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

@end
