#import "HAAStatusBarIconManager.h"
#import <notify.h>
#import <objc/message.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@interface HAAStatusBarIconManager ()
@property (nonatomic, strong) UIWindow *overlayWindow;
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
            [weakSelf updatePollingState];
            [weakSelf refresh];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf updatePollingState];
            [weakSelf refresh];
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

#pragma mark - Overlay Window

- (void)ensureOverlayWindow {
    if (self.overlayWindow) return;

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
}

#pragma mark - Polling

- (void)updatePollingState {
    if ([self isEnabled]) {
        if (!self.pollTimer) {
            self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                              target:self
                                                            selector:@selector(pollRunningApps)
                                                            userInfo:nil
                                                             repeats:YES];
        }
        [self pollRunningApps];
    } else {
        if (self.pollTimer) {
            [self.pollTimer invalidate];
            self.pollTimer = nil;
        }
        [self teardown];
    }
}

- (NSArray *)runningBundleIDs {
    NSMutableArray *running = [NSMutableArray array];

    Class appCtrlClass = NSClassFromString(@"SBApplicationController");
    if (!appCtrlClass) return running;

    id shared = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([appCtrlClass respondsToSelector:@selector(sharedInstance)]) {
        shared = [appCtrlClass performSelector:@selector(sharedInstance)];
    }
    if (!shared && [appCtrlClass respondsToSelector:@selector(sharedInstanceIfExists)]) {
        shared = [appCtrlClass performSelector:@selector(sharedInstanceIfExists)];
    }
    if (!shared) return running;

    NSArray *apps = nil;
    if ([shared respondsToSelector:@selector(allApplications)]) {
        apps = [shared performSelector:@selector(allApplications)];
    }
    if (!apps && [shared respondsToSelector:NSSelectorFromString(@"applications")]) {
        apps = [shared performSelector:NSSelectorFromString(@"applications")];
    }
    if (!apps) return running;

    for (id app in apps) {
        NSString *bid = nil;
        if ([app respondsToSelector:@selector(bundleIdentifier)]) {
            bid = [app performSelector:@selector(bundleIdentifier)];
        }
#pragma clang diagnostic pop
        if (!bid || bid.length == 0) continue;
        if ([bid hasPrefix:@"com.apple."]) continue;

        BOOL isRunning = NO;

        if ([app respondsToSelector:@selector(isRunning)]) {
            BOOL (*fn)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            isRunning = fn(app, @selector(isRunning));
        }
        if (!isRunning && [app respondsToSelector:NSSelectorFromString(@"isRunningOrSuspended")]) {
            BOOL (*fn)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            isRunning = fn(app, NSSelectorFromString(@"isRunningOrSuspended"));
        }
        if (!isRunning && [app respondsToSelector:NSSelectorFromString(@"backgroundState")]) {
            NSInteger (*fn)(id, SEL) = (NSInteger (*)(id, SEL))objc_msgSend;
            NSInteger state = fn(app, NSSelectorFromString(@"backgroundState"));
            if (state >= 2) isRunning = YES;
        }

        if (!isRunning) continue;
        [running addObject:bid];
    }

    return running;
}

- (void)pollRunningApps {
    if (![self isEnabled]) return;

    NSArray *running = [self runningBundleIDs];
    NSArray *cur = [self.visibleBundleIDs copy];

    if (![cur isEqualToArray:running]) {
        [self.visibleBundleIDs setArray:running];
        [self refresh];
    }
}

#pragma mark - Icon Rendering

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

    [self ensureOverlayWindow];
    if (!self.container || !self.overlayWindow) return;

    [self.overlayWindow setHidden:NO];
    [self.overlayWindow makeKeyAndVisible];
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

    CGFloat winW = self.overlayWindow.bounds.size.width;
    CGFloat totalW = MAX(x - spacing, 1);
    CGFloat ratio = [self positionRatio];
    CGFloat startX = (winW - totalW) * ratio;
    if (startX < 4) startX = 4;
    if (startX + totalW > winW - 4) startX = winW - totalW - 4;

    CGFloat y = [self verticalOffset];
    self.container.frame = CGRectMake(startX, y, totalW, size);
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
