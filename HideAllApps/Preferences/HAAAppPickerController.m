#import "HAAAppPickerController.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface HAAAppPickerController ()
@property (nonatomic, strong) NSArray *allApps;
@property (nonatomic, strong) NSArray *filteredApps;
@property (nonatomic, strong) NSMutableSet *hiddenSet;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, copy) NSString *searchText;
@end

@implementation HAAAppPickerController

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kSuiteName];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择要隐藏的 App";

    NSArray *ids = [[self defaults] arrayForKey:@"hiddenBundleIDs"] ?: @[];
    self.hiddenSet = [NSMutableSet setWithSet:[NSSet setWithArray:ids]];
    self.searchText = @"";

    // 用屏幕宽度，避免 view.bounds 在 viewDidLoad 时还没算好
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 70)];
    headerView.backgroundColor = [UIColor clearColor];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(20, 15, screenWidth - 40, 40)];
    self.searchField.placeholder = @"搜索 App";
    self.searchField.font = [UIFont systemFontOfSize:17];
    self.searchField.borderStyle = UITextBorderStyleRoundedRect;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.searchField addTarget:self action:@selector(searchChanged:) forControlEvents:UIControlEventEditingChanged];
    [headerView addSubview:self.searchField];

    self.table.tableHeaderView = headerView;

    [self loadApps];
}

- (void)searchChanged:(UITextField *)tf {
    self.searchText = tf.text ?: @"";
    [self applyFilter];
}

- (void)loadApps {
    NSMutableArray *result = [NSMutableArray array];
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    if (wsClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id ws = [wsClass performSelector:@selector(defaultWorkspace)];
        if ([ws respondsToSelector:@selector(allInstalledApplications)]) {
            NSArray *all = [ws performSelector:@selector(allInstalledApplications)];
            for (id app in all) {
                NSString *bundle = nil, *name = nil;
                if ([app respondsToSelector:@selector(bundleIdentifier)])
                    bundle = [app performSelector:@selector(bundleIdentifier)];
                if ([app respondsToSelector:@selector(localizedName)])
                    name = [app performSelector:@selector(localizedName)];
                if (!bundle || !name) continue;
                if ([bundle hasPrefix:@"com.apple."]) continue;
                [result addObject:@{@"bundle": bundle, @"name": name}];
            }
        }
#pragma clang diagnostic pop
    }
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    self.allApps = result;
    self.filteredApps = result;
    [self reloadSpecifiers];
}

- (void)applyFilter {
    if (self.searchText.length == 0) {
        self.filteredApps = self.allApps;
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *app in self.allApps) {
            NSString *name = app[@"name"] ?: @"";
            NSString *bundle = app[@"bundle"] ?: @"";
            if ([name rangeOfString:self.searchText options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundle rangeOfString:self.searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:app];
            }
        }
        self.filteredApps = filtered;
    }
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    NSMutableArray *specs = [NSMutableArray array];
    for (NSDictionary *app in self.filteredApps) {
        NSString *bundle = app[@"bundle"];
        PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:app[@"name"]
                                                         target:self
                                                            set:@selector(setValue:forSpecifier:)
                                                            get:@selector(valueForSpecifier:)
                                                         detail:nil
                                                           cell:PSSwitchCell
                                                           edit:nil];
        [sp setProperty:bundle forKey:@"bundleID"];
        [sp setProperty:@([self.hiddenSet containsObject:bundle]) forKey:@"default"];
        [specs addObject:sp];
    }
    _specifiers = specs;
    return _specifiers;
}

- (id)valueForSpecifier:(PSSpecifier *)specifier {
    return @([self.hiddenSet containsObject:[specifier propertyForKey:@"bundleID"]]);
}

- (void)setValue:(id)value forSpecifier:(PSSpecifier *)specifier {
    NSString *bundle = [specifier propertyForKey:@"bundleID"];
    if ([value boolValue]) [self.hiddenSet addObject:bundle];
    else [self.hiddenSet removeObject:bundle];

    NSUserDefaults *d = [self defaults];
    [d setObject:self.hiddenSet.allObjects forKey:@"hiddenBundleIDs"];
    [d synchronize];
    notify_post(kDarwinNotification);
}

@end
