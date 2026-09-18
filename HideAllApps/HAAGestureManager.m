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

    // Pan 兜底（要求起点在左右边缘）
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.minimumNumberOfTouches = 1;
    pan.maximumNumberOfTouches = 1;
    pan.cancelsTouchesInView = NO;
    [view addGestureRecognizer:pan];
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
            continue;
        }
        if (w.bounds.size.width > 300 && w.bounds.size.height > 600) {
            [self setupGesturesOnView:w];
        }
    }
}

- (BOOL)inYZone:(CGFloat)y height:(CGFloat)h {
    HAAManager *m = [HAAManager sharedManager];
    CGFloat ratio = y / h;
    if (ratio < m.zoneTopRatio) return NO;
    if (ratio > m.zoneBottomRatio) return NO;
    return YES;
}

// 左侧边缘手势
- (void)handleLeftEdgePan:(UIScreenEdgePanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.leftDownEnabled) return;
    if (gr.state != UIGestureRecognizerStateEnded) return;

    CGPoint t = [gr translationInView:gr.view];
    CGSize size = gr.view.bounds.size;
    CGPoint loc = [gr locationInView:gr.view];

    if (t.y < 30) return;
    if (fabs(t.y) < fabs(t.x)) return;
    if (![self inYZone:loc.y height:size.height]) return;

    [m toggleHidden];
}

// 右侧边缘手势
- (void)handleRightEdgePan:(UIScreenEdgePanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.rightDownEnabled) return;
    if (gr.state != UIGestureRecognizerStateEnded) return;

    CGPoint t = [gr translationInView:gr.view];
    CGSize size = gr.view.bounds.size;
    CGPoint loc = [gr locationInView:gr.view];

    if (t.y < 30) return;
    if (fabs(t.y) < fabs(t.x)) return;
    if (![self inYZone:loc.y height:size.height]) return;

    [m toggleHidden];
}

// Pan 兜底：起点必须在屏幕左右边缘
- (void)handlePan:(UIPanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled) return;
    if (gr.state != UIGestureRecognizerStateEnded) return;

    CGPoint startLoc = [gr locationInView:gr.view];
    CGPoint t = [gr translationInView:gr.view];
    CGSize size = gr.view.bounds.size;

    if (t.y < 30) return;
    if (fabs(t.y) < fabs(t.x)) return;
    if (![self inYZone:startLoc.y height:size.height]) return;

    // 起点在左侧
    if (startLoc.x <= m.zoneWidth) {
        if (!m.leftDownEnabled) return;
        [m toggleHidden];
        return;
    }
    // 起点在右侧
    if (startLoc.x >= size.width - m.zoneWidth) {
        if (!m.rightDownEnabled) return;
        [m toggleHidden];
        return;
    }
}

- (void)handleStatusBarSingleTap:(UITapGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.statusBarSingleTapEnabled) return;
    [self fireToggle];
}

- (void)handleStatusBarDoubleTap:(UITapGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.statusBarDoubleTapEnabled) return;
    [self fireToggle];
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
