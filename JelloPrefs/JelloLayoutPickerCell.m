#import "JelloLayoutPickerCell.h"

@implementation JelloLayoutPickerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        
        CGFloat containerWidth = 110;
        CGFloat containerSpacing = 30;
        
        UIView *mainContainer = [[UIView alloc] init];
        mainContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:mainContainer];
        
        [NSLayoutConstraint activateConstraints:@[
            [mainContainer.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [mainContainer.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [mainContainer.heightAnchor constraintEqualToConstant:180],
            [mainContainer.widthAnchor constraintEqualToConstant:(containerWidth * 2) + containerSpacing]
        ]];
        
        self.backgroundContainer = [[UIView alloc] init];
        self.backgroundContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [mainContainer addSubview:self.backgroundContainer];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.backgroundContainer.leadingAnchor constraintEqualToAnchor:mainContainer.leadingAnchor],
            [self.backgroundContainer.topAnchor constraintEqualToAnchor:mainContainer.topAnchor],
            [self.backgroundContainer.bottomAnchor constraintEqualToAnchor:mainContainer.bottomAnchor],
            [self.backgroundContainer.widthAnchor constraintEqualToConstant:containerWidth]
        ]];
        UIColor *jelloTeal = [UIColor colorWithRed:72/255.0 green:178/255.0 blue:199/255.0 alpha:1.0];
        
        self.backgroundImageView = [[UIImageView alloc] init];
        self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
        UIImageSymbolConfiguration *bgConfig = [UIImageSymbolConfiguration configurationWithPaletteColors:@[jelloTeal, [UIColor clearColor]]];
        self.backgroundImageView.image = [UIImage systemImageNamed:@"iphone" withConfiguration:bgConfig];
        self.backgroundImageView.tintColor = jelloTeal;
        [self.backgroundContainer addSubview:self.backgroundImageView];
        
        self.backgroundLabel = [[UILabel alloc] init];
        self.backgroundLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundLabel.text = @"Background";
        self.backgroundLabel.textAlignment = NSTextAlignmentCenter;
        self.backgroundLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        [self.backgroundContainer addSubview:self.backgroundLabel];
        
        self.backgroundCheckmark = [[UIImageView alloc] init];
        self.backgroundCheckmark.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundCheckmark.contentMode = UIViewContentModeScaleAspectFit;
        self.backgroundCheckmark.tintColor = jelloTeal;
        [self.backgroundContainer addSubview:self.backgroundCheckmark];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.backgroundContainer.topAnchor constant:10],
            [self.backgroundImageView.centerXAnchor constraintEqualToAnchor:self.backgroundContainer.centerXAnchor],
            [self.backgroundImageView.widthAnchor constraintEqualToConstant:75],
            [self.backgroundImageView.heightAnchor constraintEqualToConstant:95],
            
            [self.backgroundLabel.topAnchor constraintEqualToAnchor:self.backgroundImageView.bottomAnchor constant:5],
            [self.backgroundLabel.centerXAnchor constraintEqualToAnchor:self.backgroundContainer.centerXAnchor],
            
            [self.backgroundCheckmark.topAnchor constraintEqualToAnchor:self.backgroundLabel.bottomAnchor constant:12],
            [self.backgroundCheckmark.centerXAnchor constraintEqualToAnchor:self.backgroundContainer.centerXAnchor],
            [self.backgroundCheckmark.widthAnchor constraintEqualToConstant:28],
            [self.backgroundCheckmark.heightAnchor constraintEqualToConstant:28]
        ]];
        
        UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapBackground)];
        [self.backgroundContainer addGestureRecognizer:bgTap];
        
        self.nowPlayingContainer = [[UIView alloc] init];
        self.nowPlayingContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [mainContainer addSubview:self.nowPlayingContainer];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.nowPlayingContainer.trailingAnchor constraintEqualToAnchor:mainContainer.trailingAnchor],
            [self.nowPlayingContainer.topAnchor constraintEqualToAnchor:mainContainer.topAnchor],
            [self.nowPlayingContainer.bottomAnchor constraintEqualToAnchor:mainContainer.bottomAnchor],
            [self.nowPlayingContainer.widthAnchor constraintEqualToConstant:containerWidth]
        ]];
        
        self.nowPlayingImageView = [[UIImageView alloc] init];
        self.nowPlayingImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.nowPlayingImageView.contentMode = UIViewContentModeScaleAspectFit;
        UIImageSymbolConfiguration *npConfig = [UIImageSymbolConfiguration configurationWithPaletteColors:@[jelloTeal, jelloTeal, [UIColor clearColor]]];
        self.nowPlayingImageView.image = [UIImage systemImageNamed:@"platter.filled.bottom.iphone" withConfiguration:npConfig];
        self.nowPlayingImageView.tintColor = jelloTeal;
        [self.nowPlayingContainer addSubview:self.nowPlayingImageView];
        
        self.nowPlayingLabel = [[UILabel alloc] init];
        self.nowPlayingLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.nowPlayingLabel.text = @"Now Playing";
        self.nowPlayingLabel.textAlignment = NSTextAlignmentCenter;
        self.nowPlayingLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        [self.nowPlayingContainer addSubview:self.nowPlayingLabel];
        
        self.nowPlayingCheckmark = [[UIImageView alloc] init];
        self.nowPlayingCheckmark.translatesAutoresizingMaskIntoConstraints = NO;
        self.nowPlayingCheckmark.contentMode = UIViewContentModeScaleAspectFit;
        self.nowPlayingCheckmark.tintColor = jelloTeal;
        [self.nowPlayingContainer addSubview:self.nowPlayingCheckmark];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.nowPlayingImageView.topAnchor constraintEqualToAnchor:self.nowPlayingContainer.topAnchor constant:10],
            [self.nowPlayingImageView.centerXAnchor constraintEqualToAnchor:self.nowPlayingContainer.centerXAnchor],
            [self.nowPlayingImageView.widthAnchor constraintEqualToConstant:75],
            [self.nowPlayingImageView.heightAnchor constraintEqualToConstant:95],
            
            [self.nowPlayingLabel.topAnchor constraintEqualToAnchor:self.nowPlayingImageView.bottomAnchor constant:5],
            [self.nowPlayingLabel.centerXAnchor constraintEqualToAnchor:self.nowPlayingContainer.centerXAnchor],
            
            [self.nowPlayingCheckmark.topAnchor constraintEqualToAnchor:self.nowPlayingLabel.bottomAnchor constant:12],
            [self.nowPlayingCheckmark.centerXAnchor constraintEqualToAnchor:self.nowPlayingContainer.centerXAnchor],
            [self.nowPlayingCheckmark.widthAnchor constraintEqualToConstant:28],
            [self.nowPlayingCheckmark.heightAnchor constraintEqualToConstant:28]
        ]];
        
        UITapGestureRecognizer *npTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapNowPlaying)];
        [self.nowPlayingContainer addGestureRecognizer:npTap];
        
        [self updateSelectionState];
    }
    return self;
}

- (void)didTapBackground {
    [self setPlacementValue:0];
}

- (void)didTapNowPlaying {
    [self setPlacementValue:1];
}

- (void)setPlacementValue:(NSInteger)value {
    if ([self.specifier respondsToSelector:@selector(performSetterWithValue:)]) {
        [self.specifier performSelector:@selector(performSetterWithValue:) withObject:@(value)];
    }
    [self updateSelectionState];
}

- (void)updateSelectionState {
    NSInteger value = 0;
    if ([self.specifier respondsToSelector:@selector(performGetter)]) {
        id val = [self.specifier performSelector:@selector(performGetter)];
        if (val) {
            value = [val integerValue];
        }
    }
    
    if (value == 0) {
        self.backgroundCheckmark.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        self.nowPlayingCheckmark.image = [UIImage systemImageNamed:@"circle"];
    } else {
        self.backgroundCheckmark.image = [UIImage systemImageNamed:@"circle"];
        self.nowPlayingCheckmark.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    }
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self updateSelectionState];
}

@end
