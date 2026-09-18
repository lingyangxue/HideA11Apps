#import "HAAManager.h"
#import <notify.h>
#import <UIKit/UIKit.h>

NSString * const kHAASuiteName = @"com.yourname.hideallapps";
NSString * const kHAAPrefsChangedDarwinNotification = @"com.yourname.hideallapps/prefsChanged";

// ⚠️ 修改这里即可改变激活密码
NSString * const kHAActivationPassword = @"HideAllApps2024";

@interface HAAManager ()
@property (nonatomic, assign) int notifyToken;
@end

@implementation HAAManager

+ (instancetype)sharedManager {
    static HAAManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[HAAManager alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hiddenBundleIDs = [NSSet set];
        [self reload];
        __weak typeof(self) weakSelf = self;
        notify_register_dispatch(kHAAPrefsChangedDarwinNotification.UTF8String,
                                 &_notifyToken,
                                 dispatch_get_main_queue(), ^(int token) {
            [weakSelf reload];
            [weakSelf refreshAllIconViews];
        });
    }
    return self;
}

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kHAASuiteName];
}

- (void)reload {
    NSUserDefaults *d = [self defaults];
    self.activated                  = [d boolForKey:@"activated"];
    self.enabled                    = [d boolForKey:@"enabled"];
    self.statusBarSingleTapEnabled  = [d boolForKey:@"statusBarSingleTapEnabled"];
    self.statusBarDoubleTapEnabled  = [d boolForKey:@"statusBarDoubleTapEnabled"];
    self.shakeEnabled               = [d boolForKey:@"shakeEnabled"];

    self.leftDownEnabled            = [d boolForKey:@"leftDownEnabled"];
    self.rightDownEnabled           = [d boolForKey:@"rightDownEnabled"];

    id topV = [d objectForKey:@"zoneTopRatio"];
    self.zoneTopRatio = topV ? [topV doubleValue] : 0.15;
    id botV = [d objectForKey:@"zoneBottomRatio"];
    self.zoneBottomRatio = botV ? [botV doubleValue] : 0.85;
    id widV = [d objectForKey:@"zoneWidth"];
    self.zoneWidth = widV ? [widV doubleValue] : 150.0;

    self.debugBorderEnabled         = [d boolForKey:@"debugBorderEnabled"];
    self.hideAll                    = [d boolForKey:@"hideAll"];
    NSArray *arr                    = [d arrayForKey:@"hiddenBundleIDs"] ?: @[];
    self.hiddenBundleIDs            = [NSSet setWithArray:arr];

    if (self.hideAll && self.activated) [self startRefreshTimer];
    else [self stopRefreshTimer];
}

// 关键：所有功能都要求 activated == YES
- (BOOL)isActive {
    return self.enabled && self.activated;
}

- (BOOL)shouldHideBundleID:(NSString *)bundleID {
    if (![self isActive]) return NO;
    if (!bundleID || bundleID.length == 0) return NO;
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return NO;
    if (self.hideAll) return YES;
    return [self.hiddenBundleIDs containsObject:bundleID];
}

- (void)toggleHidden {
    if (![self isActive]) return;
    if (self.hideAll) [self showAllNow];
    else [self hideAllNow];
}

- (void)hideAllNow {
    if (![self isActive]) return;
    if (self.hideAll) { [self refreshAllIconViews]; return; }
    self.hideAll = YES;
    NSUserDefaults *d = [self defaults];
    [d setBool:YES forKey:@"hideAll"];
    [d synchronize];
    notify_post(kHAAPrefsChangedDarwinNotification.UTF8String);
    [self startRefreshTimer];
    [self refreshAllIconViews];
}

- (void)showAllNow {
    if (![self isActive]) return;
    if (!self.hideAll) { [self refreshAllIconViews]; return; }
    self.hideAll = NO;
    NSUserDefaults *d = [self defaults];
    [d setBool:NO forKey:@"hideAll"];
    [d synchronize];
    notify_post(kHAAPrefsChangedDarwinNotification.UTF8String);
    [self stopRefreshTimer];
    [self refreshAllIconViews];
}

- (void)startRefreshTimer {
    [self stopRefreshTimer];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                         target:self
                                                       selector:@selector(refreshAllIconViews)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopRefreshTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

- (void)applyHiddenStateToIconView:(id)iconView {
    if (![self isActive]) {
        // 未激活：把所有图标恢复显示
        if ([iconView isKindOfClass:[UIView class]]) {
            UIView *v = (UIView *)iconView;
            v.alpha = 1.0;
            v.userInteractionEnabled = YES;
        }
        return;
    }
    if (!iconView) return;
    if (![iconView isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)iconView;
    BOOL hide = NO;
    id icon = nil;
    if ([iconView respondsToSelector:@selector(icon)]) {
        icon = [iconView performSelector:@selector(icon)];
    }
    if (icon) {
        NSString *bundleID = nil;
        if ([icon respondsToSelector:@selector(applicationBundleIdentifier)]) {
            bundleID = [icon performSelector:@selector(applicationBundleIdentifier)];
        }
        if (!bundleID && [icon respondsToSelector:@selector(application)]) {
            id app = [icon performSelector:@selector(application)];
            if ([app respondsToSelector:@selector(bundleIdentifier)]) {
                bundleID = [app performSelector:@selector(bundleIdentifier)];
            }
        }
        if (!bundleID && self.hideAll) hide = YES;
        else if (bundleID) hide = [self shouldHideBundleID:bundleID];
    }
    view.alpha = hide ? 0.0 : 1.0;
    view.userInteractionEnabled = !hide;
}

- (void)refreshAllIconViews {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self _walkView:window depth:0];
    }
}

- (void)_walkView:(UIView *)view depth:(int)depth {
    if (depth > 25) return;
    NSString *cls = NSStringFromClass(view.class);
    BOOL isIconClass = NO;
    if ([cls isEqualToString:@"SBIconView"]) isIconClass = YES;
    if ([cls isEqualToString:@"SBFolderIconView"]) isIconClass = YES;
    if ([cls containsString:@"IconView"] && [cls containsString:@"SB"]) isIconClass = YES;
    if (isIconClass) [self applyHiddenStateToIconView:view];
    for (UIView *sub in view.subviews) [self _walkView:sub depth:depth + 1];
}

#pragma mark - Debug Border

- (void)showDebugBorder {
    if (![self isActive]) return;
    UIView *host = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        NSString *cls = NSStringFromClass(w.class);
        if ([cls containsString:@"StatusBar"]) continue;
        if ([cls containsString:@"Keyboard"]) continue;
        if (w.bounds.size.width > 300 && w.bounds.size.height > 600) {
            host = w;
            break;
        }
    }
    if (!host) host = [UIApplication sharedApplication].keyWindow;
    if (!host) return;

    CGSize size = host.bounds.size;

    for (UIView *v in host.subviews) {
        if (v.tag == 99991) [v removeFromSuperview];
    }

    CGFloat y = size.height * self.zoneTopRatio;
    CGFloat h = size.height * (self.zoneBottomRatio - self.zoneTopRatio);

    UIView *leftBorder = [[UIView alloc] init];
    leftBorder.tag = 99991;
    leftBorder.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.25];
    leftBorder.layer.borderColor = [UIColor redColor].CGColor;
    leftBorder.layer.borderWidth = 3.0;
    leftBorder.userInteractionEnabled = NO;
    leftBorder.frame = CGRectMake(0, y, self.zoneWidth, h);
    [host addSubview:leftBorder];

    UIView *rightBorder = [[UIView alloc] init];
    rightBorder.tag = 99991;
    rightBorder.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.25];
    rightBorder.layer.borderColor = [UIColor blueColor].CGColor;
    rightBorder.layer.borderWidth = 3.0;
    rightBorder.userInteractionEnabled = NO;
    rightBorder.frame = CGRectMake(size.width - self.zoneWidth, y, self.zoneWidth, h);
    [host addSubview:rightBorder];

    [host bringSubviewToFront:leftBorder];
    [host bringSubviewToFront:rightBorder];
}

- (void)hideDebugBorder {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        for (UIView *v in w.subviews) {
            if (v.tag == 99991) [v removeFromSuperview];
        }
    }
}

@end
