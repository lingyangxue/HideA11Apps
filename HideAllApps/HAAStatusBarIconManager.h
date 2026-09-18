#import <UIKit/UIKit.h>

@interface HAAStatusBarIconManager : NSObject
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) NSMutableArray *iconViews;
@property (nonatomic, strong) NSMutableArray *visibleBundleIDs;
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, weak) UIWindow *registeredStatusBarWin;
+ (instancetype)sharedManager;
- (void)registerStatusBarWindow:(UIWindow *)win;
- (void)setupIfNeeded;
- (void)refresh;
- (void)teardown;
@end
