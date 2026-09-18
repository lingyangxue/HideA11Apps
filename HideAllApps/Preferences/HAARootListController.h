#import <UIKit/UIKit.h>

@interface PSViewController : UIViewController
@end

@interface PSListController : PSViewController {
    NSMutableArray *_specifiers;
}
@property (nonatomic, strong) NSString *title;
- (NSArray *)specifiers;
- (void)reloadSpecifiers;
@end

@interface PSSpecifier : NSObject
+ (PSSpecifier *)groupSpecifierWithName:(NSString *)name;
+ (PSSpecifier *)preferenceSpecifierNamed:(NSString *)name
                                   target:(id)target
                                      set:(SEL)set
                                      get:(SEL)get
                                   detail:(Class)detail
                                     cell:(NSInteger)cell
                                     edit:(Class)edit;
- (void)setProperty:(id)property forKey:(id)key;
- (id)propertyForKey:(id)key;
@end

enum {
    PSGroupCell = 0,
    PSLinkCell = 1,
    PSLinkListCell = 2,
    PSListItemCell = 3,
    PSTitleValueCell = 4,
    PSSwitchCell = 6,
    PSButtonCell = 9,
    PSSliderCell = 5
};

@interface HAARootListController : PSListController
@end
