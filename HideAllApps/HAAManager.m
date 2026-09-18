#import "HAAManager.h"
#import <notify.h>
#import <UIKit/UIKit.h>

NSString * const kHAASuiteName = @"com.yourname.hideallapps";
NSString * const kHAAPrefsChangedDarwinNotification = @"com.yourname.hideallapps/prefsChanged";

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
    self.enabled    = [d boolForKey:@"enabled"];
    self.hideAll    = [d boolForKey:@"hideAll"];
    NSArray *arr    = [d arrayForKey:@"hiddenBundleIDs"] ?: @[];
    self.hiddenBundleIDs = [NSSet setWithArray:arr];

    if (self.hideAll && self.enabled) [self startRefreshTimer];
    else [self stopRefreshTimer];
}

- (BOOL)shouldHideBundleID:(NSString *)bundleID {
    if (!self.enabled) return NO;
    if (!bundleID || bundleID.length == 0) return NO;
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return NO;
    if (self.hideAll) return YES;
    return [self.hiddenBundleIDs containsObject:bundleID];
}

- (void)toggleHidden {
    if (!self.enabled) return;
    if (self.hideAll) [self showAllNow];
    else [self hideAllNow];
}

- (void)hideAllNow {
    if (!self.enabled) return;
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
    if (!self.enabled) return;
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
    if (!iconView) return;
    if (![iconView isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)iconView;

    NSString *cls = NSStringFromClass(view.class);
    if (![cls isEqualToString:@"SBIconView"] &&
        ![cls isEqualToString:@"SBFolderIconView"]) {
        return;
    }

    if (!self.enabled) {
        view.alpha = 1.0;
        return;
    }

    BOOL hide = NO;
    id icon = nil;
    if ([view respondsToSelector:@selector(icon)]) {
        icon = [view performSelector:@selector(icon)];
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

    // 只改 alpha
    view.alpha = hide ? 0.0 : 1.0;
}

- (void)refreshAllIconViews {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self _walkView:window depth:0];
    }
}

- (void)_walkView:(UIView *)view depth:(int)depth {
    if (depth > 25) return;
    NSString *cls = NSStringFromClass(view.class);
    if ([cls isEqualToString:@"SBIconView"] || [cls isEqualToString:@"SBFolderIconView"]) {
        [self applyHiddenStateToIconView:view];
        return;
    }
    for (UIView *sub in view.subviews) [self _walkView:sub depth:depth + 1];
}

@end
