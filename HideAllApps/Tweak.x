#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "HAAManager.h"
#import "HAAGestureManager.h"
#import "HAAStatusBarIconManager.h"

@interface SBIconController : UIViewController
@end

@interface SPUIAppResultsViewController : UIViewController
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
    // 关键：主动初始化状态栏图标管理器
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
    NSString *bid = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bid = [self performSelector:@selector(bundleIdentifier)];
    }
    if (state == 0) {
        [[HAAStatusBarIconManager sharedManager] noteAppExited:bid];
    } else if (state >= 1) {
        [[HAAStatusBarIconManager sharedManager] noteAppBecameActive:bid];
    }
}
- (void)setActive:(BOOL)active {
    %orig;
    if (active) {
        NSString *bid = nil;
        if ([self respondsToSelector:@selector(bundleIdentifier)]) {
            bid = [self performSelector:@selector(bundleIdentifier)];
        }
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

// 关键：插件一加载就立刻初始化状态栏管理器
%ctor {
    NSLog(@"[HideAllApps] tweak loaded!");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[HideAllApps] ctor: initializing managers");
        [[HAAStatusBarIconManager sharedManager] refresh];
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
    });
}
