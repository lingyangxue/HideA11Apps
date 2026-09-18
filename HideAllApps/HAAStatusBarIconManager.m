#import "HAAStatusBarIconManager.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@interface HAAStatusBarIconManager ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) NSMutableArray *iconViews;
@property (nonatomic, strong) NSMutableArray *visibleBundleIDs;
@end

@implementation HAAStatusBarIconManager

+ (instancetype)sharedManager {
    static HAAStatusBarIconManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[HAAStatusBarIconManager alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _iconViews = [NSMutableArray array];
        _visibleBundleIDs = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;
        static int token = 0;
        notify_register_dispatch(kDarwinNotification, &token, dispatch_get_main_queue(), ^(int t) {
            [weakSelf refresh];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf refresh];
        });
        // 启动就创建一个明显的测试红方块，验证代码是否跑起来
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf debugShowRedBlock];
        });
    }
    return self;
}

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kSuiteName];
}

- (BOOL)isEnabled {
    NSUserDefaults *d = [self defaults];
    return [d boolForKey:@"enabled"] && [d boolForKey:@"statusBarIconEnabled"];
}

- (CGFloat)iconSize {
    double s = [[self defaults] doubleForKey:@"statusBarIconSize"];
    if (s < 6) s = 14;
    return (CGFloat)s;
}

- (CGFloat)positionRatio {
    id v = [[self defaults] objectForKey:@"statusBarIconPos"];
    if (!v) return 0.5;
    return [v doubleValue];
}

- (CGFloat)verticalOffset {
    id v = [[self defaults] objectForKey:@"statusBarIconY"];
    if (!v) return 8;
    return [v doubleValue];
}

- (void)debugShowRedBlock {
    NSLog(@"[HideAllApps] debugShowRedBlock called");
    CGRect screen = [UIScreen mainScreen].bounds;
    UIWindow *w = [[UIWindow alloc] initWithFrame:screen];
    w.windowLevel = UIWindowLevelStatusBar + 2000;
    w.backgroundColor = [UIColor clearColor];
    w.userInteractionEnabled = NO;
    w.hidden = NO;
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    w.rootViewController = vc;
    UIView *red = [[UIView alloc] initWithFrame:CGRectMake(20, 0, 60, 40)];
    red.backgroundColor = [UIColor redColor];
    [vc.view addSubview:red];
    // 3秒后自动消失，避免长期干扰
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [w setHidden:YES];
    });
}

- (void)ensureOverlayWindow {
    if (self.overlayWindow) return;
    NSLog(@"[HideAllApps] ensureOverlayWindow creating...");
    CGRect screen = [UIScreen mainScreen].bounds;
    self.overlayWindow = [[UIWindow alloc] initWithFrame:screen];
    self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 1000;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.userInteractionEnabled = NO;
    self.overlayWindow.hidden = NO;
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    vc.view.frame = screen;
    self.overlayWindow.rootViewController = vc;
    self.container = [[UIView alloc] init];
    self.container.backgroundColor = [UIColor clearColor];
    self.container.userInteractionEnabled = NO;
    [vc.view addSubview:self.container];
    NSLog(@"[HideAllApps] ensureOverlayWindow done");
}

- (void)noteAppBecameActive:(NSString *)bundleID {
    NSLog(@"[HideAllApps] noteAppBecameActive: %@", bundleID);
    if (![self isEnabled]) return;
    if (!bundleID || bundleID.length == 0) return;
    if ([bundleID hasPrefix:@"com.apple."]) return;
    if (![self.visibleBundleIDs containsObject:bundleID]) {
        [self.visibleBundleIDs addObject:bundleID];
    }
    [self refresh];
}

- (void)noteAppExited:(NSString *)bundleID {
    NSLog(@"[HideAllApps] noteAppExited: %@", bundleID);
    if (!bundleID) return;
    [self.visibleBundleIDs removeObject:bundleID];
    [self refresh];
}

- (UIImage *)iconForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![[UIImage class] respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = [[UIImage class] methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [UIImage class];
    inv.selector = sel;
    NSString *bid = bundleID;
    [inv setArgument:&bid atIndex:2];
    NSInteger fmt = 0;
    [inv setArgument:&fmt atIndex:3];
    CGFloat sc = [UIScreen mainScreen].scale;
    [inv setArgument:&sc atIndex:4];
    [inv invoke];
    __unsafe_unretained UIImage *img = nil;
    [inv getReturnValue:&img];
    return img;
}

- (void)refresh {
    NSLog(@"[HideAllApps] refresh called, enabled=%d", [self isEnabled]);
    if (![self isEnabled]) {
        [self teardown];
        return;
    }
    [self ensureOverlayWindow];
    if (!self.container || !self.overlayWindow) return;
    [self.overlayWindow setHidden:NO];
    for (UIView *v in self.iconViews) [v removeFromSuperview];
    [self.iconViews removeAllObjects];
    CGFloat size = [self iconSize];
    CGFloat spacing = 4;
    CGFloat x = 0;
    NSArray *bidsToShow = self.visibleBundleIDs;
    if (bidsToShow.count == 0) {
        bidsToShow = @[@"com.apple.Preferences"];
    }
    NSLog(@"[HideAllApps] drawing %lu icons, size=%f", (unsigned long)bidsToShow.count, size);
    for (NSString *bid in bidsToShow) {
        UIImage *icon = [self iconForBundleID:bid];
        if (!icon) {
            NSLog(@"[HideAllApps] icon nil for %@", bid);
            continue;
        }
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
        iv.frame = CGRectMake(x, 0, size, size);
        iv.layer.cornerRadius = size * 0.22;
        iv.clipsToBounds = YES;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [self.container addSubview:iv];
        [self.iconViews addObject:iv];
        x += size + spacing;
    }
    CGFloat winW = self.overlayWindow.bounds.size.width;
    CGFloat totalW = MAX(x - spacing, 1);
    CGFloat ratio = [self positionRatio];
    CGFloat startX = (winW - totalW) * ratio;
    if (startX < 4) startX = 4;
    if (startX + totalW > winW - 4) startX = winW - totalW - 4;
    CGFloat y = [self verticalOffset];
    self.container.frame = CGRectMake(startX, y, totalW, size);
    NSLog(@"[HideAllApps] container frame = %@", NSStringFromCGRect(self.container.frame));
}

- (void)teardown {
    for (UIView *v in self.iconViews) [v removeFromSuperview];
    [self.iconViews removeAllObjects];
    [self.container removeFromSuperview];
    self.container = nil;
    [self.overlayWindow setHidden:YES];
    self.overlayWindow = nil;
    [self.visibleBundleIDs removeAllObjects];
}

@end
