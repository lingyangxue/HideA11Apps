#import "HAAGestureManager.h"
#import "HAAManager.h"
#import <objc/runtime.h>

static const void *kHAAGestureInstalledKey   = &kHAAGestureInstalledKey;
static const void *kHAAStatusBarInstalledKey = &kHAAStatusBarInstalledKey;

@implementation HAAGestureManager

+ (instancetype)sharedManager {
    static HAAGestureManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[HAAGestureManager alloc] init]; });
    return shared;
}

- (void)setupGesturesOnView:(UIView *)view {
    if (!view) return;
    if (objc_getAssociatedObject(view, kHAAGestureInstalledKey)) return;
    objc_setAssociatedObject(view, kHAAGestureInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 左侧向下滑 → 恢复显示
    UISwipeGestureRecognizer *leftDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftDown:)];
    leftDown.direction = UISwipeGestureRecognizerDirectionDown;
    leftDown.numberOfTouchesRequired = 1;
    [view addGestureRecognizer:leftDown];
}

- (void)setupStatusBarGestures:(UIView *)view {
    if (!view) return;
    if (objc_getAssociatedObject(view, kHAAStatusBarInstalledKey)) return;
    objc_setAssociatedObject(view, kHAAStatusBarInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.userInteractionEnabled = YES;

    UITapGestureRecognizer *single = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleStatusBarSingleTap:)];
    single.numberOfTapsRequired = 1;
    single.cancelsTouchesInView = NO;
    [view addGestureRecognizer:single];

    UITapGestureRecognizer *double_ = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleStatusBarDoubleTap:)];
    double_.numberOfTapsRequired = 2;
    double_.cancelsTouchesInView = NO;
    [view addGestureRecognizer:double_];

    [single requireGestureRecognizerToFail:double_];
}

- (void)installGesturesIntoSpringBoard {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        NSString *cls = NSStringFromClass(w.class);
        if ([cls containsString:@"StatusBar"]) { [self setupStatusBarGestures:w]; }
    }
}

- (BOOL)gestureMatches:(HAAGestureType)type {
    HAAManager *m = [HAAManager sharedManager];
    return m.enabled && m.gestureType == type;
}

// 左侧向下滑 = 只恢复
- (void)handleLeftDown:(UISwipeGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled) return;
    // 必须从屏幕左侧 30pt 内开始滑
    CGPoint loc = [gr locationInView:gr.view];
    if (loc.x > 60) return;
    [m showAllNow];
}

- (void)handleStatusBarSingleTap:(UITapGestureRecognizer *)gr {
    if ([self gestureMatches:HAAGestureTypeStatusBarSingleTap]) [self fireToggle];
}

- (void)handleStatusBarDoubleTap:(UITapGestureRecognizer *)gr {
    if ([self gestureMatches:HAAGestureTypeStatusBarDoubleTap]) [self fireToggle];
}

- (void)handleShake {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.shakeEnabled) return;
    [m hideAllNow];
}

- (void)fireToggle {
    [[HAAManager sharedManager] toggleHidden];
}

@end
