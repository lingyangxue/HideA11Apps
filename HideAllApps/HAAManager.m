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

    UISwipeGestureRecognizer *up = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeUp:)];
    up.direction = UISwipeGestureRecognizerDirectionUp;
    [view addGestureRecognizer:up];

    UISwipeGestureRecognizer *left = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeLeft:)];
    left.direction = UISwipeGestureRecognizerDirectionLeft;
    [view addGestureRecognizer:left];

    UISwipeGestureRecognizer *right = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeRight:)];
    right.direction = UISwipeGestureRecognizerDirectionRight;
    [view addGestureRecognizer:right];
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
    }
}

- (BOOL)gestureMatches:(HAAGestureType)type {
    HAAManager *m = [HAAManager sharedManager];
    return m.enabled && m.gestureType == type;
}

- (void)handleSwipeUp:(UISwipeGestureRecognizer *)gr {
    if ([self gestureMatches:HAAGestureTypeSwipeUp]) [self fireToggle];
}
- (void)handleSwipeLeft:(UISwipeGestureRecognizer *)gr {
    if ([self gestureMatches:HAAGestureTypeSwipeLeft]) [self fireToggle];
}
- (void)handleSwipeRight:(UISwipeGestureRecognizer *)gr {
    if ([self gestureMatches:HAAGestureTypeSwipeRight]) [self fireToggle];
}
- (void)handleStatusBarSingleTap:(UITapGestureRecognizer *)gr {
    if ([self gestureMatches:HAAGestureTypeStatusBarSingleTap]) [self fireToggle];
}

// 双击状态栏 = 只恢复
- (void)handleStatusBarDoubleTap:(UITapGestureRecognizer *)gr {
    if (![self gestureMatches:HAAGestureTypeStatusBarDoubleTap]) return;
    [[HAAManager sharedManager] showAllNow];
}

// 摇一摇 = 只隐藏（独立开关，和状态栏手势互不影响）
- (void)handleShake {
    HAAManager *m = [HAAManager sharedManager];
    if (!m.enabled || !m.shakeEnabled) return;
    [m hideAllNow];
}

- (void)fireToggle {
    [[HAAManager sharedManager] toggleHidden];
}

@end
