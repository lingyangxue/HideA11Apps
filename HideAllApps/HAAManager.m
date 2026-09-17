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
    self.enabled     = [d boolForKey:@"enabled"];
    self.gestureType = [d integerForKey:@"gestureType"];
    self.hideAll     = [d boolForKey:@"hideAll"];
    NSArray *arr     = [d arrayForKey:@"hiddenBundleIDs"] ?: @[];
    self.hiddenBundleIDs = [NSSet setWithArray:arr];
}

- (BOOL)shouldHideBundleID:(NSString *)bundleID {
    if (!self.enabled) return NO;
    if (!bundleID || bundleID.length == 0) return NO;
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return NO;
    if (self.hideAll) return YES;
    return [self.hiddenBundleIDs containsObject:bundleID];
}

- (void)toggleHidden {
    BOOL newValue = !self.hideAll;
    self.hideAll = newValue;
    NSUserDefaults *d = [self defaults];
    [d setBool:newValue forKey:@"hideAll"];
    [d synchronize];
    notify_post(kHAAPrefsChangedDarwinNotification.UTF8String);
}

- (void)applyHiddenStateToIconView:(id)iconView {
    if (!iconView) return;
    id icon = nil;
    if ([iconView respondsToSelector:@selector(icon)]) {
        icon = [iconView performSelector:@selector(icon)];
    }
    if (!icon) return;
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
    if (!bundleID) return;
    BOOL hide = [self shouldHideBundleID:bundleID];
    UIView *view = (UIView *)iconView;
    view.alpha = hide ? 0.0 : 1.0;
    view.userInteractionEnabled = !hide;
}

- (void)refreshAllIconViews {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self _walkView:window];
    }
}

- (void)_walkView:(UIView *)view {
    Class iconViewClass = NSClassFromString(@"SBIconView");
    if (iconViewClass && [view isKindOfClass:iconViewClass]) {
        [self applyHiddenStateToIconView:view];
    }
    for (UIView *sub in view.subviews) { [self _walkView:sub]; }
}

@end
