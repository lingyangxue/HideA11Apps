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

    // 左侧边缘
    UIScreenEdgePanGestureRecognizer *leftEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftEdgePan:)];
    leftEdge.edges = UIRectEdgeLeft;
    leftEdge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:leftEdge];

    // 右侧边缘
    UIScreenEdgePanGestureRecognizer *rightEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightEdgePan:)];
    rightEdge.edges = UIRectEdgeRight;
    rightEdge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:rightEdge];
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
        if ([cls containsString:@"StatusBar"]) {
            [self setupStatusBarGestures:w];
            continue;  // 状态栏窗口不加边缘手势
        }
        if (w.bounds.size.width > 300 && w.bounds.size.height > 600) {
            [self setupGesturesOnView:w];
        }
    }
}

// 左侧下滑 → 切换
- (void)handleLeftEdgePan:(UIScreenEdgePanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.activated || !m.leftDownEnabled) return;
    if (gr.state != UIGestureRecognizerStateEnded) return;

    CGPoint t = [gr translationInView:gr.view];
    CGSize size = gr.view.bounds.size;
    CGPoint loc = [gr locationInView:gr.view];

    if (t.y < 30) return;
    if (fabs(t.y) < fabs(t.x)) return;

    CGFloat yRatio = loc.y / size.height;
    if (yRatio < m.zoneTopRatio) return;
    if (yRatio > m.zoneBottomRatio) return;

    [m toggleHidden];
}

// 右侧下滑 → 切换
- (void)handleRightEdgePan:(UIScreenEdgePanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.activated || !m.rightDownEnabled) return;
    if (gr.state != UIGestureRecognizerStateEnded) return;

    CGPoint t = [gr translationInView:gr.view];
    CGSize size = gr.view.bounds.size;
    CGPoint loc = [gr locationInView:gr.view];

    if (t.y < 30) return;
    if (fabs(t.y) < fabs(t.x)) return;

    CGFloat yRatio = loc.y / size.height;
    if (yRatio < m.zoneTopRatio) return;
    if (yRatio > m.zoneBottomRatio) return;

    [m toggleHidden];
}

- (void)handleStatusBarSingleTap:(UITapGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.activated || !m.statusBarSingleTapEnabled) return;
    [self fireToggle];
}

- (void)handleStatusBarDoubleTap:(UITapGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.activated || !m.statusBarDoubleTapEnabled) return;
    [self fireToggle];
}

- (void)handleShake {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.activated || !m.shakeEnabled) return;
    [m hideAllNow];
}

- (void)fireToggle {
    [[HAAManager sharedManager] toggleHidden];
}

@end
