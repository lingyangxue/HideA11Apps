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

    // 方式 1：UIScreenEdgePanGestureRecognizer（左侧边缘）
    UIScreenEdgePanGestureRecognizer *edge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePan:)];
    edge.edges = UIRectEdgeLeft;
    edge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:edge];

    // 方式 2：Pan 手势（手动判断方向和起点）
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

// 屏幕边缘手势
- (void)handleEdgePan:(UIScreenEdgePanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.leftDownEnabled) return;

    if (gr.state == UIGestureRecognizerStateEnded) {
        CGPoint translation = [gr translationInView:gr.view];
        if (translation.y > 30 && fabs(translation.y) > fabs(translation.x)) {
            [m showAllNow];
        }
    }
}

// Pan 手势：起点在左侧 + 向下滑 + 在选定的区域
- (void)handlePan:(UIPanGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.leftDownEnabled) return;

    CGPoint startLoc = [gr locationInView:gr.view];
    CGPoint translation = [gr translationInView:gr.view];
    CGSize size = gr.view.bounds.size;

    if (gr.state == UIGestureRecognizerStateEnded) {
        // 起点必须在屏幕左侧 150pt 内
        if (startLoc.x > 150) return;
        // 向下滑超过 30pt
        if (translation.y < 30) return;
        // 垂直分量要大于水平
        if (fabs(translation.y) < fabs(translation.x)) return;

        // 按选项判断 y 范围
        CGFloat yRatio = startLoc.y / size.height;
        NSInteger zone = m.leftDownZone;
        BOOL inZone = NO;

        switch (zone) {
            case 0:  // 左侧上半：15% ~ 40%
                inZone = (yRatio >= 0.15 && yRatio <= 0.40);
                break;
            case 1:  // 左侧中段：40% ~ 60%
                inZone = (yRatio >= 0.40 && yRatio <= 0.60);
                break;
            case 2:  // 左侧下半：60% ~ 85%
                inZone = (yRatio >= 0.60 && yRatio <= 0.85);
                break;
            case 3:  // 整个左侧：15% ~ 85%
            default:
                inZone = (yRatio >= 0.15 && yRatio <= 0.85);
                break;
        }

        if (!inZone) return;
        [m showAllNow];
    }
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
