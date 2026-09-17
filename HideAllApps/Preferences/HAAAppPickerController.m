#import "HAAAppPickerController.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface HAAAppPickerController ()
@property (nonatomic, strong) NSArray *apps;
@property (nonatomic, strong) NSMutableSet *hiddenSet;
@end

@implementation HAAAppPickerController

- (NSUserDefaults *)defaults { return [[NSUserDefaults alloc] initWithSuiteName:kSuiteName]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择要隐藏的 App";
    NSArray *ids = [[self defaults] arrayForKey:@"hiddenBundleIDs"] ?: @[];
    self.hiddenSet = [NSMutableSet setWithArray:ids];
    [self loadApps];
}

- (void)loadApps {
    NSMutableArray *result = [NSMutableArray array];
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    if (wsClass) {
        id ws = [wsClass performSelector:@selector(defaultWorkspace)];
        if ([ws respondsToSelector:@selector(allInstalledApplications)]) {
            NSArray *all = [ws performSelector:@selector(allInstalledApplications)];
            for (id app in all) {
                NSString *bundle = nil, *name = nil;
                if ([app respondsToSelector:@selector(bundleIdentifier)]) bundle = [app performSelector:@selector(bundleIdentifier)];
                if ([app respondsToSelector:@selector(localizedName)])    name   = [app performSelector:@selector(localizedName)];
                if (!bundle || !name) continue;
                if ([bundle hasPrefix:@"com.apple."]) continue;
                [result addObject:@{@"bundle": bundle, @"name": name}];
            }
        }
    }
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    self.apps = result;
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    NSMutableArray *specs = [NSMutableArray array];
    for (NSDictionary *app in self.apps) {
        NSString *bundle = app[@"bundle"];
        PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:app[@"name"] target:self set:@selector(setValue:forSpecifier:) get:@selector(valueForSpecifier:) detail:nil cell:PSSwitchCell edit:nil];
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
