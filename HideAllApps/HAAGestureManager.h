#import <UIKit/UIKit.h>

@interface HAAGestureManager : NSObject
+ (instancetype)sharedManager;
- (void)installGesturesIntoSpringBoard;
@end
