//
//  SSPrefsSwitchCell.m
//  SkipSilencePrefs
//
//  Custom switch cell so the preferences panel matches the YTLite
//  visual style (rounded switch tinted with the YouTube red).
//

#import <UIKit/UIKit.h>
#import <Preferences/PSTableCell.h>

@interface SSPrefsSwitchCell : PSTableCell
@end

@implementation SSPrefsSwitchCell

- (void)layoutSubviews {
    [super layoutSubviews];
    // Match YouTube's red accent color.
    self.switchControl.onTintColor = [UIColor colorWithRed:0.812 green:0.094 blue:0.094 alpha:1.0];
}

@end
