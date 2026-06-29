//
//  SSPrefsRootController.m
//  SkipSilencePrefs
//
//  PreferenceLoader bundle that the user sees as "Skip Silence" inside
//  the YTLite section of Settings.app. Mirrors the layout of Overcast's
//  Smart Speed / Voice Boost settings panel.
//

#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSSwitchTableCell.h>
#import <Preferences/PSSliderTableCell.h>
#import <Preferences/PSSpecifier.h>

@interface SSPrefsRootController : PSListController
@end

@implementation SSPrefsRootController

- (instancetype)initWithSpecifiers:(NSArray *)specifiers {
    self = [super initWithSpecifiers:specifiers];
    if (self) {
        // Reload the specifiers from our Root.plist resource.
        NSString *plistPath = [[NSBundle bundleForClass:[self class]]
            pathForResource:@"Root" ofType:@"plist"];
        if (plistPath) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:plistPath];
            NSArray *items = d[@"items"];
            [self setSpecifiers:[self filteredSpecifiersFromItems:items]];
        }
    }
    return self;
}

- (NSArray *)filteredSpecifiersFromItems:(NSArray *)items {
    NSMutableArray *specs = [NSMutableArray array];
    for (NSDictionary *item in items) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:item[@"label"]
                                                          target:self
                                                             set:item[@"set"] ? [item[@"set"] stringByAppendingString:@":"] : @selector(setValue:forSpecifier:)
                                                             get:item[@"get"] ? [item[@"get"] stringByAppendingString:@":"] : @selector(getValueForSpecifier:)
                                                          detail:item[@"detailCellClass"] ?: nil
                                                            cell:item[@"cellType"] ?: [NSNumber numberWithInt:1]
                                                            edit:nil];
        if (item[@"key"])   [spec setProperty:item[@"key"]   forKey:@"key"];
        if (item[@"default"]) [spec setProperty:item[@"default"] forKey:@"default"];
        if (item[@"min"])   [spec setProperty:item[@"min"]   forKey:@"min"];
        if (item[@"max"])   [spec setProperty:item[@"max"]   forKey:@"max"];
        if (item[@"isSwitch"]) [spec setProperty:@YES forKey:@"isSwitch"];
        [spec setIdentifier:item[@"label"]];
        [specs addObject:spec];
    }
    return specs;
}

// PSListController generic accessor / mutator backed by NSUserDefaults.
- (id)getValueForSpecifier:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    if (!key) return nil;
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setValue:(id)value forSpecifier:(PSSpecifier *)spec {
    NSString *key = [spec property forKey:@"key"];
    if (!key) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *n = (NSNumber *)value;
        if (strcmp([n objCType], @encode(BOOL)) == 0) {
            [d setBool:[n boolValue] forKey:key];
        } else if (strcmp([n objCType], @encode(float)) == 0 ||
                   strcmp([n objCType], @encode(double)) == 0) {
            [d setFloat:[n floatValue] forKey:key];
        } else {
            [d setObject:n forKey:key];
        }
    } else {
        [d setObject:value forKey:key];
    }
    [d synchronize];
    // Notify the tweak to reload.
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (CFStringRef)@"com.ytlite.skipsilence.prefschanged",
        NULL, NULL, true);
    [self reloadSpecifier:spec];
}

@end
