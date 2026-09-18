#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
    });
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[HAAManager sharedManager] refreshAllIconViews];
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

// 监听 App 激活（iOS 17 用这个通知）
%hook SBApplication
- (void)setActive:(BOOL)active {
    %orig;
    if (active) {
        NSString *bid = [self bundleIdentifier];
        [[HAAStatusBarIconManager sharedManager] noteAppBecameActive:bid];
    }
}
- (void)setProcessState:(NSInteger)state {
    %orig;
    // state: 0=never, 1=running, 2=suspended, 3=background, 4=foreground
    if (state == 0) {
        NSString *bid = [self bundleIdentifier];
        [[HAAStatusBarIconManager sharedManager] noteAppExited:bid];
    } else if (state >= 1) {
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
    });
}
