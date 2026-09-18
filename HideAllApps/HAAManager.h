#import <Foundation/Foundation.h>

extern NSString * const kHAASuiteName;
extern NSString * const kHAAPrefsChangedDarwinNotification;

@interface HAAManager : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL statusBarSingleTapEnabled;
@property (nonatomic, assign) BOOL statusBarDoubleTapEnabled;
@property (nonatomic, assign) BOOL shakeEnabled;
@property (nonatomic, assign) BOOL leftDownEnabled;
// 左侧下滑区域（0.0 ~ 1.0 比例）
@property (nonatomic, assign) CGFloat zoneTopRatio;     // 顶部（默认 0.15）
@property (nonatomic, assign) CGFloat zoneBottomRatio;  // 底部（默认 0.85）
@property (nonatomic, assign) CGFloat zoneWidth;        // 左边界宽度 pt（默认 150）
@property (nonatomic, assign) BOOL debugBorderEnabled;  // 显示调试边框

@property (nonatomic, assign) BOOL hideAll;
@property (nonatomic, strong) NSSet *hiddenBundleIDs;
@property (nonatomic, strong) NSTimer *refreshTimer;
+ (ourinstancetype)sharedManager;
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
@end
