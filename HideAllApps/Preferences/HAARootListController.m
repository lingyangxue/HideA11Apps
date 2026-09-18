#import "HAARootListController.h"
#import "HAAAppPickerController.h"
#import <notify.h>
#import <spawn.h>

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
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *a) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重启"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        // 直接 kill SpringBoard
        pid_t pid;
        const char *args[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char * const *)args, NULL);
        // 备用路径
        posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char * const *)args, NULL);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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

        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"隐藏手势（只能选一个）"];
        [group2 setProperty:@"打开其中一个开关后，另一个会自动关闭" forKey:@"footerText"];
        [specs addObject:group2];

        NSArray *names = @[@"关闭", @"上滑", @"左滑", @"右滑", @"状态栏单击", @"状态栏双击"];
        for (NSInteger i = 0; i < names.count; i++) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:names[i] target:self set:@selector(setGestureValue:specifier:) get:@selector(gestureValue:) detail:nil cell:PSSwitchCell edit:nil];
            [sp setProperty:@(i) forKey:@"gestureIndex"];
            [specs addObject:sp];
        }

        PSSpecifier *group3 = [PSSpecifier groupSpecifierWithName:@"摇一摇（只隐藏，独立开关）"];
        [group3 setProperty:@"摇一摇手机只隐藏，恢复请用上面的状态栏双击手势" forKey:@"footerText"];
        [specs addObject:group3];

        PSSpecifier *shake = [PSSpecifier preferenceSpecifierNamed:@"启用摇一摇隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [shake setProperty:@"shakeEnabled" forKey:@"key"];
        [shake setProperty:@NO forKey:@"default"];
        [specs addObject:shake];

        PSSpecifier *groupSB = [PSSpecifier groupSpecifierWithName:@"状态栏显示 App 图标"];
        [groupSB setProperty:@"打开过的 App 图标会显示在状态栏，App 完全退出后消失。任何界面都会显示" forKey:@"footerText"];
        [specs addObject:groupSB];

        PSSpecifier *sbEnable = [PSSpecifier preferenceSpecifierNamed:@"启用状态栏图标" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [sbEnable setProperty:@"statusBarIconEnabled" forKey:@"key"];
        [sbEnable setProperty:@NO forKey:@"default"];
        [specs addObject:sbEnable];

        PSSpecifier *groupSize = [PSSpecifier groupSpecifierWithName:@"图标大小（拖动滑块）"];
        [groupSize setProperty:@"范围 8pt ~ 26pt" forKey:@"footerText"];
        [specs addObject:groupSize];

        PSSpecifier *sizeSlider = [PSSpecifier preferenceSpecifierNamed:@"大小"
                                                                 target:self
                                                                    set:@selector(setSizeSlider:specifier:)
                                                                    get:@selector(getSizeSlider:)
                                                                 detail:nil
                                                                   cell:PSSliderCell
                                                                   edit:nil];
        [sizeSlider setProperty:@8  forKey:@"min"];
        [sizeSlider setProperty:@26 forKey:@"max"];
        [sizeSlider setProperty:@14 forKey:@"default"];
        [specs addObject:sizeSlider];

        PSSpecifier *groupPos = [PSSpecifier groupSpecifierWithName:@"水平位置（拖动滑块）"];
        [groupPos setProperty:@"最左 ← → 最右" forKey:@"footerText"];
        [specs addObject:groupPos];

        PSSpecifier *posSlider = [PSSpecifier preferenceSpecifierNamed:@"水平"
                                                                target:self
                                                                   set:@selector(setPosSlider:specifier:)
                                                                   get:@selector(getPosSlider:)
                                                                detail:nil
                                                                  cell:PSSliderCell
                                                                  edit:nil];
        [posSlider setProperty:@0.0 forKey:@"min"];
        [posSlider setProperty:@1.0 forKey:@"max"];
        [posSlider setProperty:@0.5 forKey:@"default"];
        [specs addObject:posSlider];

        PSSpecifier *groupY = [PSSpecifier groupSpecifierWithName:@"垂直位置（拖动滑块）"];
        [groupY setProperty:@"0 = 最顶，24 = 往下。默认 8" forKey:@"footerText"];
        [specs addObject:groupY];

        PSSpecifier *ySlider = [PSSpecifier preferenceSpecifierNamed:@"垂直"
                                                              target:self
                                                                 set:@selector(setYSlider:specifier:)
                                                                 get:@selector(getYSlider:)
                                                              detail:nil
                                                                cell:PSSliderCell
                                                                edit:nil];
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

        PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:@"注销（重启 SpringBoard）"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:[HAAConfirmRespringController class]
                                                                 cell:PSLinkCell
                                                                 edit:nil];
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

- (id)getSizeSlider:(PSSpecifier *)specifier {
    double v = [[self defaults] doubleForKey:@"statusBarIconSize"];
    if (v < 6) v = 14;
    return @(v);
}
- (void)setSizeSlider:(id)value specifier:(PSSpecifier *)specifier {
    double v = [value doubleValue];
    NSUserDefaults *d = [self defaults];
    [d setDouble:v forKey:@"statusBarIconSize"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getPosSlider:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"statusBarIconPos"];
    if (!v) return @0.5;
    return v;
}
- (void)setPosSlider:(id)value specifier:(PSSpecifier *)specifier {
    double v = [value doubleValue];
    NSUserDefaults *d = [self defaults];
    [d setDouble:v forKey:@"statusBarIconPos"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

- (id)getYSlider:(PSSpecifier *)specifier {
    id v = [[self defaults] objectForKey:@"statusBarIconY"];
    if (!v) return @8;
    return v;
}
- (void)setYSlider:(id)value specifier:(PSSpecifier *)specifier {
    double v = [value doubleValue];
    NSUserDefaults *d = [self defaults];
    [d setDouble:v forKey:@"statusBarIconY"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

@end
