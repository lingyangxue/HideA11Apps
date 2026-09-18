#import <Foundation/Foundation.h>

extern NSString * const kHAASuiteName;
extern NSString * const kHAAPrefsChangedDarwinNotification;
extern NSString * const kHAActivationPassword;

@interface HAAManager : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL activated;   // ← 新增
@property (nonatomic, assign) BOOL statusBarSingleTapEnabled;
@property (nonatomic, assign) BOOL statusBarDoubleTapEnabled;
@property (nonatomic, assign) BOOL shakeEnabled;
@property (nonatomic, assign) BOOL leftDownEnabled;
@property (nonatomic, assign) BOOL rightDownEnabled;
@property (nonatomic, assign) CGFloat zoneTopRatio;
@property (nonatomic, assign) CGFloat zoneBottomRatio;
@property (nonatomic, assign) CGFloat zoneWidth;
@property (nonatomic, assign) BOOL debugBorderEnabled;
@property (nonatomic, assign) BOOL hideAll;
@property (nonatomic, strong) NSSet *hiddenBundleIDs;
@property (nonatomic, strong) NSTimer *refreshTimer;

+ (instancetype)sharedManager;
- (void)reload;
- (BOOL)shouldHideBundleID:(NSString *)bundleID;
- (void)toggleHidden;
- (void)hideAllNow;
- (void)showAllNow;
- (void)refreshAllIconViews;
- (void)applyHiddenStateToIconView:(id)iconView;
- (void)startRefreshTimer;
- (void)stopRefreshTimer;
- (void)showDebugBorder;
- (void)hideDebugBorder;
@end
