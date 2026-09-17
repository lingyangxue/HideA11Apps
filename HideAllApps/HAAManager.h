#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HAAGestureType) {
    HAAGestureTypeNone = 0,
    HAAGestureTypeSwipeUp,
    HAAGestureTypeSwipeLeft,
    HAAGestureTypeSwipeRight,
    HAAGestureTypeStatusBarSingleTap,
    HAAGestureTypeStatusBarDoubleTap,
};

extern NSString * const kHAASuiteName;
extern NSString * const kHAAPrefsChangedDarwinNotification;

@interface HAAManager : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger gestureType;
@property (nonatomic, assign) BOOL hideAll;
@property (nonatomic, strong) NSSet *hiddenBundleIDs;
@property (nonatomic, strong) NSTimer *refreshTimer;
+ (instancetype)sharedManager;
- (void)reload;
- (BOOL)shouldHideBundleID:(NSString *)bundleID;
- (void)toggleHidden;
- (void)refreshAllIconViews;
- (void)applyHiddenStateToIconView:(id)iconView;
- (void)startRefreshTimer;
- (void)stopRefreshTimer;
@end
