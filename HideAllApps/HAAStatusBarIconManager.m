#import "HAAStatusBarIconManager.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

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

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appBecameActive:)
                                                     name:@"SBApplicationDidBecomeActiveNotification"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidExitNote:)
                                                     name:@"SBApplicationDidExitNotification"
                                                   object:nil];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf setupIfNeeded];
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
    NSInteger s = [[self defaults] integerForKey:@"statusBarIconSize"];
    if (s <= 0) s = 14;
    return (CGFloat)s;
}

- (CGFloat)positionRatio {
    id v = [[self defaults] objectForKey:@"statusBarIconPos"];
    if (!v) return 0.9;
    return [v doubleValue];
}

- (UIWindow *)statusBarWindow {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        NSString *cls = NSStringFromClass(w.class);
        if ([cls containsString:@"StatusBar"]) {
            return w;
        }
    }
    return nil;
}

- (void)setupIfNeeded {
    if (self.container && self.container.superview) return;
    UIWindow *sbw = [self statusBarWindow];
    if (!sbw) return;

    self.container = [[UIView alloc] init];
    self.container.backgroundColor = [UIColor clearColor];
    self.container.userInteractionEnabled = NO;
    [sbw addSubview:self.container];
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
    [self setupIfNeeded];
    if (!self.container) return;

    for (UIView *v in self.iconViews) [v removeFromSuperview];
    [self.iconViews removeAllObjects];

    CGFloat size = [self iconSize];
    CGFloat spacing = 4;
    CGFloat x = 0;

    for (NSString *bid in self.visibleBundleIDs) {
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

    UIWindow *sbw = [self statusBarWindow];
    if (!sbw) return;
    CGFloat winW = sbw.bounds.size.width;
    CGFloat winH = sbw.bounds.size.height;

    CGFloat totalW = MAX(x - spacing, 1);
    CGFloat ratio = [self positionRatio];
    CGFloat startX = (winW - totalW) * ratio;

    if (startX < 4) startX = 4;
    if (startX + totalW > winW - 4) startX = winW - totalW - 4;

    self.container.frame = CGRectMake(startX, (winH - size) / 2.0, totalW, size);
}

- (void)appDidLaunch:(NSString *)bundleID {
    if (!bundleID) return;
    if (![self isEnabled]) return;
    if ([bundleID hasPrefix:@"com.apple."]) return;

    if (![self.visibleBundleIDs containsObject:bundleID]) {
        [self.visibleBundleIDs addObject:bundleID];
    }
    [self refresh];
}

- (void)appDidExit:(NSString *)bundleID {
    if (!bundleID) return;
    [self.visibleBundleIDs removeObject:bundleID];
    [self refresh];
}

- (void)teardown {
    for (UIView *v in self.iconViews) [v removeFromSuperview];
    [self.iconViews removeAllObjects];
    [self.container removeFromSuperview];
    self.container = nil;
    [self.visibleBundleIDs removeAllObjects];
}

#pragma mark - Notifications

- (NSString *)bundleIDFromNote:(NSNotification *)note {
    id obj = note.object;
    NSString *bid = nil;
    if (obj && [obj respondsToSelector:@selector(bundleIdentifier)]) {
        bid = [obj performSelector:@selector(bundleIdentifier)];
    }
    if (!bid) {
        NSDictionary *ui = note.userInfo;
        bid = ui[@"bundleID"] ?: ui[@"SBApplicationBundleIdentifierKey"];
    }
    return bid;
}

- (void)appBecameActive:(NSNotification *)note {
    NSString *bid = [self bundleIDFromNote:note];
    [self appDidLaunch:bid];
}

- (void)appDidExitNote:(NSNotification *)note {
    NSString *bid = [self bundleIDFromNote:note];
    [self appDidExit:bid];
}

@end
