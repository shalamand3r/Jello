#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>

@interface JelloLayoutPickerCell : PSTableCell

@property (nonatomic, strong) UIView *backgroundContainer;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UILabel *backgroundLabel;
@property (nonatomic, strong) UIImageView *backgroundCheckmark;

@property (nonatomic, strong) UIView *nowPlayingContainer;
@property (nonatomic, strong) UIImageView *nowPlayingImageView;
@property (nonatomic, strong) UILabel *nowPlayingLabel;
@property (nonatomic, strong) UIImageView *nowPlayingCheckmark;

@end
