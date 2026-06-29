//
//  SSPrefsSwitchCell.m
//  SkipSilencePrefs
//
//  Custom switch cell that tints the UISwitch with YouTube's brand
//  red. PSSwitchTableCell inherits from PSControlTableCell, which
//  exposes a `control` property of type UIControl. We downcast it
//  to UISwitch to set the onTintColor.
//

#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>

@interface SSPrefsSwitchCell : PSSwitchTableCell
@end

@implementation SSPrefsSwitchCell

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    if ([self.control isKindOfClass:[UISwitch class]]) {
        [(UISwitch *)self.control setOnTintColor:
            [UIColor colorWithRed:0.812 green:0.094 blue:0.094 alpha:1.0]];
    }
}

@end
