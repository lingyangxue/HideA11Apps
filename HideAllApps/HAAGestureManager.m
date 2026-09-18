#import "HAAGestureManager.h"
#import "HAAManager.h"
#import <objc/runtime.h>

static const void *kHAAGestureInstalledKey = &kHAAGestureInstalledKey;

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

    UIScreenEdgePanGestureRecognizer *leftEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftEdgePan:)];
    leftEdge.edges = UIRectEdgeLeft;
    leftEdge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:leftEdge];

    UIScreenEdgePanGestureRecognizer *rightEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightEdgePan:)];
    rightEdge.edges = UIRectEdgeRight;
    rightEdge.cancelsTouchesInView = NO;
    [view addGestureRecognizer:rightEdge];
}

- (void)installGesturesIntoSpringBoard {
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

@end
