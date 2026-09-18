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

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.minimumNumberOfTouches = 1;
    pan.maximumNumberOfTouches = 1;
    pan.cancelsTouchesInView = NO;
    pan.delegate = self;
    [view addGestureRecognizer:pan];
}

#pragma mark - UIGestureRecognizerDelegate

// 关键：只接收屏幕左右边缘的触摸，其他区域（包括状态栏中央）都不接收
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    UIView *view = gestureRecognizer.view;
    if (!view) return NO;

    CGPoint point = [touch locationInView:view];
    CGSize size = view.bounds.size;

    // 左右边缘 50pt 内才接收
    if (point.x <= 50) return YES;
    if (point.x >= size.width - 50) return YES;
    return NO;
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
}

- (BOOL)inYZone:(CGFloat)y height:(CGFloat)h {
    HAAManager *m = [HAAManager sharedManager];
    CGFloat ratio = y / h;
    if (ratio < m.zoneTopRatio) return NO;
    if (ratio > m.zoneBottomRatio) return NO;
    return YES;
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
