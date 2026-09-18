#import <Foundation/Foundation.h>

extern NSString * const kHAASuiteName;
extern NSString * const kHAAPrefsChangedDarwinNotification;

@interface HAAManager : NSObject
@property (nonatomic, assign) BOOL enabled;
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
@end
