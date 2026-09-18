#import "HAAStatusBarIconManager.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@interface HAAStatusBarIconManager ()
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) NSMutableArray *iconViews;
@property (nonatomic, strong) NSMutableArray *visibleBundleIDs;
@property (nonatomic, strong) NSTimer *pollTimer;
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
        self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                          target:self
                                                        selector:@selector(scanApps)
                                                        userInfo:nil
                                                         repeats:YES];
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
    if (!v) return 0.05;
    return [v doubleValue];
}

- (CGFloat)verticalOffset {
    id v = [[self defaults] objectForKey:@"statusBarIconY"];
    if (!v) return 8;
    return [v doubleValue];
}

- (UIView *)hostView {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        NSString *cls = NSStringFromClass(w.class);
        if ([cls containsString:@"StatusBar"]) continue;
        if ([cls containsString:@"Keyboard"]) continue;
        if ([cls containsString:@"Alert"]) continue;
        if (w.bounds.size.width > 300 && w.bounds.size.height > 600) return w;
    }
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (kw) return kw;
    if ([UIApplication sharedApplication].windows.count > 0) return [UIApplication sharedApplication].windows.firstObject;
    return nil;
}

- (void)scanApps {
    if (![self isEnabled]) return;

    Class appCtrlClass = NSClassFromString(@"SBApplicationController");
    if (!appCtrlClass) return;

    id shared = nil;
    if ([appCtrlClass respondsToSelector:@selector(sharedInstance)]) {
        shared = [appCtrlClass performSelector:@selector(sharedInstance)];
    }
    if (!shared) return;

    NSArray *apps = nil;
    if ([shared respondsToSelector:@selector(allApplications)]) {
        apps = [shared performSelector:@selector(allApplications)];
    }
    if (!apps) return;

    NSMutableArray *running = [NSMutableArray array];
    for (id app in apps) {
        NSString *bid = nil;
        if ([app respondsToSelector:@selector(bundleIdentifier)]) {
            bid = [app performSelector:@selector(bundleIdentifier)];
        }
        if (!bid || bid.length == 0) continue;
        if ([bid hasPrefix:@"com.apple."]) continue;

        BOOL isRunning = NO;
        if ([app respondsToSelector:@selector(isRunning)]) {
            isRunning = [app performSelector:@selector(isRunning)];
        }
        if (!isRunning) continue;
        [running addObject:bid];
    }

    NSMutableArray *newList = [NSMutableArray array];
    for (NSString *bid in running) {
        if (![newList containsObject:bid]) [newList addObject:bid];
    }
    while (newList.count > 6) [newList removeLastObject];

    if (![newList isEqualToArray:self.visibleBundleIDs]) {
        [self.visibleBundleIDs setArray:newList];
        [self refresh];
    }
}

- (void)noteAppBecameActive:(NSString *)bundleID {
    if (![self isEnabled]) return;
    if (!bundleID || bundleID.length == 0) return;
    if ([bundleID hasPrefix:@"com.apple."]) return;
    [self.visibleBundleIDs removeObject:bundleID];
    [self.visibleBundleIDs insertObject:bundleID atIndex:0];
    while (self.visibleBundleIDs.count > 6) [self.visibleBundleIDs removeLastObject];
    [self refresh];
}

- (void)noteAppExited:(NSString *)bundleID {
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
    if (![self isEnabled]) {
        [self teardown];
        return;
    }

    UIView *host = [self hostView];
    if (!host) return;

    if (!self.container || self.container.superview != host) {
        [self.container removeFromSuperview];
        self.container = [[UIView alloc] init];
        self.container.backgroundColor = [UIColor clearColor];
        self.container.userInteractionEnabled = NO;
        [host addSubview:self.container];
    }
    [host bringSubviewToFront:self.container];

    for (UIView *v in self.iconViews) [v removeFromSuperview];
    [self.iconViews removeAllObjects];

    CGFloat size = [self iconSize];
    CGFloat spacing = 4;
    CGFloat x = 0;

    NSArray *bidsToShow = self.visibleBundleIDs;
    if (bidsToShow.count == 0) {
        bidsToShow = @[@"com.apple.Preferences"];
    }

    for (NSString *bid in bidsToShow) {
        UIImage *icon = [self iconForBundleID:bid];
        if (!icon) continue;
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
        iv.frame = CGRectMake(x, 0, size, size);
        iv.layer.cornerRadius = size * 0.22;
        iv.clipsToBounds = YES;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [self.container addSubview:iv];
        [self.iconViews addObject:iv];
        x += size + spacing;
    }

    CGFloat hostW = host.bounds.size.width;
    CGFloat totalW = MAX(x - spacing, 1);
    CGFloat ratio = [self positionRatio];
    CGFloat startX = (hostW - totalW) * ratio;
    if (startX < 4) startX = 4;
    if (startX + totalW > hostW - 4) startX = hostW - totalW - 4;

    CGFloat y = [self verticalOffset];
    self.container.frame = CGRectMake(startX, y, totalW, size);
}

- (void)teardown {
    for (UIView *v in self.iconViews) [v removeFromSuperview];
    [self.iconViews removeAllObjects];
    [self.container removeFromSuperview];
    self.container = nil;
    [self.visibleBundleIDs removeAllObjects];
}

@end
