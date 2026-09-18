#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import "HAAManager.h"
#import "HAAGestureManager.h"

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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
    });
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
    [[HAAManager sharedManager] refreshAllIconViews];
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
    static int showBorderToken = 0;
    notify_register_dispatch("com.yourname.hideallapps/showBorder",
                             &showBorderToken,
                             dispatch_get_main_queue(), ^(int t) {
        [[HAAManager sharedManager] showDebugBorder];
    });

    static int hideBorderToken = 0;
    notify_register_dispatch("com.yourname.hideallapps/hideBorder",
                             &hideBorderToken,
                             dispatch_get_main_queue(), ^(int t) {
        [[HAAManager sharedManager] hideDebugBorder];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HAAGestureManager sharedManager] installGesturesIntoSpringBoard];
        [[HAAManager sharedManager] refreshAllIconViews];
    });
}
