#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import "HAAManager.h"
#import "HAAGestureManager.h"
#import "HAAStatusBarIconManager.h"

@interface SBIconController : UIViewController
@end

@interface SPUIAppResultsViewController : UIViewController
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

%hook SBIconView
- (void)setIcon:(id)icon { %orig; [[HAAManager sharedManager] applyHiddenStateToIconView:self]; }
- (void)didMoveToWindow { %orig; [[HAAManager sharedManager] applyHiddenStateToIconView:self]; }
- (void)layoutSubviews { %orig; [[HAAManager sharedManager] applyHiddenStateToIconView:self]; }
%end

%hook SBIconController
- (void)viewDidLoad {
    %orig;
    [[HAAGestureManager sharedManager] setupGesturesOnView:self.view];
    [[HAAStatusBarIconManager sharedManager] refresh];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
        [[HAAStatusBarIconManager sharedManager] refresh];
    });
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[HAAManager sharedManager] refreshAllIconViews];
    [[HAAStatusBarIconManager sharedManager] refresh];
}
%end

%hook UIWindow
- (void)didMoveToWindow {
    %orig;
    NSString *cls = NSStringFromClass(self.class);
    if ([cls containsString:@"StatusBar"]) {
        [[HAAGestureManager sharedManager] setupStatusBarGestures:self];
    }
}
%end

%hook UIApplication
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake) {
        [[HAAGestureManager sharedManager] handleShake];
    }
}
%end

%hook SBApplication
- (void)setProcessState:(NSInteger)state {
    %orig;
    NSString *bid = [self bundleIdentifier];
    if (state == 0) {
        [[HAAStatusBarIconManager sharedManager] noteAppExited:bid];
    } else if (state >= 1) {
        [[HAAStatusBarIconManager sharedManager] noteAppBecameActive:bid];
    }
}
- (void)setActive:(BOOL)active {
    %orig;
    if (active) {
        NSString *bid = [self bundleIdentifier];
        [[HAAStatusBarIconManager sharedManager] noteAppBecameActive:bid];
    }
}
%end

%hook SPUIAppResultsViewController
- (void)setResults:(NSArray *)results {
    HAAManager *mgr = [HAAManager sharedManager];
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:results.count];
    for (id result in results) {
        NSString *bundleID = nil;
        if ([result respondsToSelector:@selector(applicationBundleIdentifier)])
            bundleID = [result performSelector:@selector(applicationBundleIdentifier)];
        if (!bundleID && [result respondsToSelector:@selector(bundleIdentifier)])
            bundleID = [result performSelector:@selector(bundleIdentifier)];
        if (bundleID && [mgr shouldHideBundleID:bundleID]) continue;
        [filtered addObject:result];
    }
    %orig(filtered);
}
%end

%ctor {
    // 监听注销通知
    static int respringToken = 0;
    notify_register_dispatch("com.yourname.hideallapps/respring",
                             &respringToken,
                             dispatch_get_main_queue(), ^(int t) {
        exit(0);
    });

    // 监听调试边框通知
    static int borderToken = 0;
    notify_register_dispatch("com.yourname.hideallapps/showBorder",
                             &borderToken,
                             dispatch_get_main_queue(), ^(int t) {
        [[HAAManager sharedManager] showDebugBorder];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HAAStatusBarIconManager sharedManager] refresh];
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
    });
}
