#import "HAARootListController.h"
#import <notify.h>

#define kSuiteName @"com.yourname.hideallapps"
#define kDarwinNotification "com.yourname.hideallapps/prefsChanged"

@implementation HAARootListController

- (NSUserDefaults *)defaults { return [[NSUserDefaults alloc] initWithSuiteName:kSuiteName]; }

- (void)viewDidLoad { [super viewDidLoad]; self.title = @"HideAllApps"; }

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        [specs addObject:[PSSpecifier groupSpecifierWithName:@"功能开关"]];

        PSSpecifier *enable = [PSSpecifier preferenceSpecifierNamed:@"启用插件" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enable setProperty:@"enabled" forKey:@"key"];
        [enable setProperty:@NO forKey:@"default"];
        [specs addObject:enable];

        PSSpecifier *hideAll = [PSSpecifier preferenceSpecifierNamed:@"立即隐藏所有 App" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [hideAll setProperty:@"hideAll" forKey:@"key"];
        [hideAll setProperty:@NO forKey:@"default"];
        [specs addObject:hideAll];

        _specifiers = specs;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = [[self defaults] objectForKey:key];
    if (value == nil) value = [specifier propertyForKey:@"default"];
    return value ?: @0;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSUserDefaults *d = [self defaults];
    [d setObject:value forKey:key];
    [d synchronize];
    notify_post(kDarwinNotification);
}

@end
