#import <UIKit/UIKit.h>

@interface HAAStatusBarIconManager : NSObject
+ (instancetype)sharedManager;
- (void)refresh;
@end
