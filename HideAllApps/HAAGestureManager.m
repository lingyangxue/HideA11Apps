#import "HAAGestureManager.h"
#import "HAAManager.h"
#import <objc/runtime.h>

static const void *kHAAGestureInstalledKey = &kHAAGestureInstalledKey;

@interface HAAGestureManager () <UIGestureRecognizerDelegate>
@end

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

    // UIScreenEdgePan：系统级边缘手势（不会接收中央区域）
    UIScreenEdgePanGestureRecognizer *leftEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftEdge:)];
    leftEdge.edges = UIRectEdgeLeft;
    leftEdge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:leftEdge];

    UIScreenEdgePanGestureRecognizer *rightEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightEdge:)];
    rightEdge.edges = UIRectEdgeRight;
    rightEdge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:rightEdge];

    // UIPan 兜底：只接收左右 50pt 内的触摸（不接收状态栏中央区域）
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.minimumNumberOfTouches = 1;
    pan.maximumNumberOfTouches = 1;
    pan.cancelsTouchesInView = NO;
    pan.delegate = self;
    [view addGestureRecognizer:pan];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    UIView *view = gestureRecognizer.view;
    if (!view) return NO;
    CGPoint p = [touch locationInView:view];
    CGFloat w = view.bounds.size.width;
    // 只接收左右边缘 50pt 内的触摸
    if (p.x <= 50) return YES;
    if (p.x >= w - 50) return YES;
    return NO;
}

- (void)installGesturesIntoSpringBoard {
    // 给 SBIconController.view 加
    Class iconCtrlClass = NSClassFromString(@"SBIconController");
    if (iconCtrlClass) {
        id shared = nil;
        if ([iconCtrlClass respondsToSelector:@selector(sharedInstance)]) {
            shared = [iconCtrlClass performSelector:@selector(sharedInstance)];
        }
        if (shared && [shared respondsToSelector:@selector(view)]) {
            UIView *v = [shared performSelector:@selector(view)];
            if (v) [self setupGesturesOnView:v];
        }
    }

    // 给 SpringBoard 所有主窗口加（不加状态栏窗口）
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        NSString *cls = NSStringFromClass(w.class);
        if ([cls containsString:@"StatusBar"]) continue;
        if ([cls containsString:@"Keyboard"]) continue;
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

- (void)handleLeftEdge:(UIScreenEdgePanGestureRecognizer *)gr {
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

- (void)handleRightEdge:(UIScreenEdgePanGestureRecognizer *)gr {
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

    if (startLoc.x <= 50) {
        if (!m.leftDownEnabled) return;
        [m toggleHidden];
        return;
    }
    if (startLoc.x >= size.width - 50) {
        if (!m.rightDownEnabled) return;
        [m toggleHidden];
        return;
    }
}

@end
