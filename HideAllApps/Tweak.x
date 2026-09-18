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
        [[HAAStatusBarIconManager sharedManager] registerStatusBarWindow:self];
    }
}
%end

// 关键：hook UIStatusBarWindow，把实例注册给 manager
%hook UIStatusBarWindow
- (void)didMoveToWindow {
    %orig;
    [[HAAStatusBarIconManager sharedManager] registerStatusBarWindow:self];
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
