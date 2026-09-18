#import <UIKit/UIKit.h>

@interface HAAStatusBarIconManager : NSObject
+ (instancetype)sharedManager;
- (void)refresh;
- (void)noteAppBecameActive:(NSString *)bundleID;
- (void)noteAppExited:(NSString *)bundleID;
@end
