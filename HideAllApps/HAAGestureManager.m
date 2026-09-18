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

// 判断主屏是否可见
- (BOOL)isHomeScreenVisible {
    Class iconCtrlClass = NSClassFromString(@"SBIconController");
    if (!iconCtrlClass) return NO;
    id shared = nil;
    if ([iconCtrlClass respondsToSelector:@selector(sharedInstance)]) {
        shared = [iconCtrlClass performSelector:@selector(sharedInstance)];
    }
    if (!shared) return NO;

    UIView *iconView = nil;
    if ([shared respondsToSelector:@selector(view)]) {
        iconView = [shared performSelector:@selector(view)];
    }
    if (!iconView) return NO;

    // 检查这个 view 是否在窗口里 + 窗口是否 key
    if (!iconView.window) return NO;
    if (iconView.window.isKeyWindow == NO) return NO;
    if (iconView.alpha < 0.01) return NO;
    if (iconView.hidden) return NO;

    return YES;
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

// 关键：只有主屏可见时才允许识别（在别的 App 里返回 NO）
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [self isHomeScreenVisible];
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

    if (startLoc.x <= 30) {
        if (!m.leftDownEnabled) return;
        [m toggleHidden];
        return;
    }
    if (startLoc.x >= size.width - 30) {
        if (!m.rightDownEnabled) return;
        [m toggleHidden];
        return;
    }
}

@end
