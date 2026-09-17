#import <UIKit/UIKit.h>

@interface HAAGestureManager : NSObject
+ (instancetype)sharedManager;
- (void)setupGesturesOnView:(UIView *)view;
- (void)setupStatusBarGestures:(UIView *)view;
- (void)installGesturesIntoSpringBoard;
- (void)handleShake;
@end
