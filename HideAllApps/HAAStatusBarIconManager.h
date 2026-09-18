#import <UIKit/UIKit.h>

@interface HAAStatusBarIconManager : NSObject
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) NSMutableArray *iconViews;
@property (nonatomic, strong) NSMutableArray *visibleBundleIDs;
+ (instancetype)sharedManager;
- (void)setupIfNeeded;
- (void)appDidLaunch:(NSString *)bundleID;
- (void)appDidExit:(NSString *)bundleID;
- (void)refresh;
- (void)teardown;
@end
