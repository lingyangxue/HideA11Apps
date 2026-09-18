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

    // 关键判断：iconView 是否在窗口最前
    UIWindow *win = iconView.window;
    if (!win) return NO;

    // 检查是不是被别的 App 覆盖了
    // 如果 iconView 的 superview 层级还在，就认为可见
    if (iconView.alpha < 0.01) return NO;
    if (iconView.hidden) return NO;

    // 检查窗口是不是被移动到了后台
    if (win.hidden) return NO;

    // 更宽松的检查：iconView 存在就认为可见
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

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // 关键：如果当前有 App 在前台显示，就不识别
    Class sbAppClass = NSClassFromString(@"SBApplicationController");
    if (sbAppClass) {
        id sharedCtrl = nil;
        if ([sbAppClass respondsToSelector:@selector(sharedInstance)]) {
            sharedCtrl = [sbAppClass performSelector:@selector(sharedInstance)];
        }
        if (sharedCtrl && [sharedCtrl respondsToSelector:@selector(applicationWithDisplayIdentifier:)]) {
            // 有些系统版本上这个接口名字不同，忽略
        }
    }

    // 更简单的判断：调用 isHomeScreenVisible
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
