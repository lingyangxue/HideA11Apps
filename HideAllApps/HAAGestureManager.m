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

    // 左侧向下滑 → 恢复（独立开关控制，见 handleLeftDown）
    UISwipeGestureRecognizer *leftDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftDown:)];
    leftDown.direction = UISwipeGestureRecognizerDirectionDown;
    leftDown.numberOfTouchesRequired = 1;
    leftDown.cancelsTouchesInView = NO;
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
        if (w.bounds.size.width > 300 && w.bounds.size.height > 600) {
            [self setupGesturesOnView:w];
        }
    }
}

- (BOOL)gestureMatches:(HAAGestureType)type {
    HAAManager *m = [HAAManager sharedManager];
    return m.enabled && m.gestureType == type;
}

// 左侧向下滑 → 只恢复（受独立开关控制）
- (void)handleLeftDown:(UISwipeGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled) return;
    if (!m.leftDownEnabled) return;  // 开关关闭就不响应

    CGPoint loc = [gr locationInView:gr.view];
    CGSize size = gr.view.bounds.size;

    if (loc.x > 150) return;
    if (loc.y < size.height * 0.10 || loc.y > size.height * 0.90) return;

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
