//
//  SSPrefsRootController.m
//  SkipSilencePrefs
//
//  Standard PreferenceLoader bundle controller. PSListController
//  automatically loads specifiers from Root.plist (which is bundled
//  as a resource). We only override the `specifiers` getter to load
//  the plist lazily, matching the Theos preference_bundle template.
//

#import <Foundation/Foundation.h>
#import <Preferences/Preferences.h>

@interface SSPrefsRootController : PSListController
@end

@implementation SSPrefsRootController

- (NSString *)bundleName {
    return @"SkipSilencePrefs";
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *plistPath = [[NSBundle bundleForClass:[self class]]
            pathForResource:@"Root" ofType:@"plist"];
        if (plistPath) {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root"
                                                     target:self];
        }
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Skip Silence";
}

@end
