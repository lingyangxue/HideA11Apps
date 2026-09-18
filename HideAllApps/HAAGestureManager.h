#import <UIKit/UIKit.h>

@interface HAAGestureManager : NSObject
+ (instancetype)sharedManager;
- (void)installGesturesIntoSpringBoard;
- (void)setHomeScreenActive:(BOOL)active;
@end
