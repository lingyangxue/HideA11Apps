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

    // 用 UIScreenEdgePanGestureRecognizer 从左侧边缘识别
    UIScreenEdgePanGestureRecognizer *edge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePan:)];
    edge.edges = UIRectEdgeLeft;
    edge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:edge];

    // 保险：再加上普通的向下滑手势（左侧区域）
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

// 屏幕边缘左滑手势
- (void)handleEdgePan:(UIScreenEdgePanGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateEnded &&
        gr.state != UIGestureRecognizerStateChanged) return;

    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled) return;
    if (!m.leftDownEnabled) return;

    CGPoint translation = [gr translationInView:gr.view];
    // 向下滑（y 正向增大）
    if (translation.y < 40) return;
    if (translation.y < fabs(translation.x)) return;  // 垂直分量要大于水平

    [m showAllNow];
}

// 左侧区域向下滑
- (void)handleLeftDown:(UISwipeGestureRecognizer *)gr {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled) return;
    if (!m.leftDownEnabled) return;

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
