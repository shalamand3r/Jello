#import "AMRootListController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <notify.h>

@interface AMRootListController () <UIColorPickerViewControllerDelegate> {
    UIImage *_cachedGithubIcon;
}
@property (nonatomic, retain) NSArray *allSpecifiers;
@property (nonatomic, strong) UIImageView *headerImageView;
@property (nonatomic, assign) BOOL resetInProgress;
@end

@implementation AMRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITableView *tableView = [self valueForKey:@"_table"];
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 180)];

    self.headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 20, 100, 100)];
    self.headerImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.headerImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.headerImageView.center = CGPointMake(headerView.center.x, self.headerImageView.center.y);
    self.headerImageView.layer.cornerRadius = 22;
    self.headerImageView.layer.masksToBounds = YES;
    [headerView addSubview:self.headerImageView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 130, headerView.bounds.size.width, 40)];
    titleLabel.text = @"Jello";
    titleLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:titleLabel];
    
    tableView.tableHeaderView = headerView;
    [self amlUpdateHeaderArtwork];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateNavigationPreview)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
                                               
    UIBarButtonItem *paintbrush = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"paintbrush"]
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:nil
                                                                  action:nil];
    
    UIAction *chooseColorAction = [UIAction actionWithTitle:@"Custom Color"
                                                      image:[UIImage systemImageNamed:@"paintpalette"]
                                                 identifier:nil
                                                    handler:^(__kindof UIAction * _Nonnull action) {
        [self selectCustomColor];
    }];
    
    UIAction *albumArtworkAction = [UIAction actionWithTitle:@"Album Artwork"
                                                       image:[UIImage systemImageNamed:@"photo.artframe"]
                                                  identifier:nil
                                                     handler:^(__kindof UIAction * _Nonnull action) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.shalamand3r.jello"];
        [prefs setInteger:0 forKey:@"colorMode"];
        [prefs synchronize];
        notify_post("com.shalamand3r.jello.preferences.changed");
    }];
    
    UIAction *lockscreenTintAction = [UIAction actionWithTitle:@"Follow Lockscreen Tint"
                                                         image:[UIImage systemImageNamed:@"lock"]
                                                    identifier:nil
                                                       handler:^(__kindof UIAction * _Nonnull action) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.shalamand3r.jello"];
        [prefs setInteger:2 forKey:@"colorMode"];
        [prefs synchronize];
        notify_post("com.shalamand3r.jello.preferences.changed");
    }];
    
    paintbrush.menu = [UIMenu menuWithTitle:@"" children:@[chooseColorAction, albumArtworkAction, lockscreenTintAction]];
    
    self.navigationItem.rightBarButtonItem = paintbrush;
}



- (void)updateNavigationPreview {
    UIColor *tintColor = [UIColor colorWithRed:72/255.0 green:178/255.0 blue:199/255.0 alpha:1.0];
    
    CGFloat barWidth = 4.0;
    CGFloat barSpacing = 2.0;
    NSInteger numBars = 6;
    CGFloat totalWidth = (barWidth * numBars) + (barSpacing * (numBars - 1));
    UIView *navView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalWidth, 20)];
    
    for (NSInteger i = 0; i < numBars; i++) {
        CALayer *bar = [CALayer layer];
        bar.backgroundColor = tintColor.CGColor;
        bar.cornerRadius = 2.0;
        bar.anchorPoint = CGPointMake(0.5, 1.0);
        bar.frame = CGRectMake(i * (barWidth + barSpacing), 0, barWidth, 20);
        
        CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];
        NSMutableArray *values = [NSMutableArray array];
        
        float k0 = 0.15 + ((float)arc4random() / UINT32_MAX) * 0.20;
        float k1 = 0.75 + ((float)arc4random() / UINT32_MAX) * 0.25;
        float k2 = 0.30 + ((float)arc4random() / UINT32_MAX) * 0.40;
        float k3 = 0.15 + ((float)arc4random() / UINT32_MAX) * 0.25;
        float k4 = 0.70 + ((float)arc4random() / UINT32_MAX) * 0.30;
        
        [values addObject:@(k0)];
        [values addObject:@(k1)];
        [values addObject:@(k2)];
        [values addObject:@(k3)];
        [values addObject:@(k4)];
        [values addObject:values.firstObject]; 
        
        anim.values = values;
        anim.duration = 0.8 + ((float)arc4random() / UINT32_MAX) * 0.4;
        anim.repeatCount = HUGE_VALF;
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        anim.removedOnCompletion = NO;
        
        [bar addAnimation:anim forKey:@"dance"];
        [navView.layer addSublayer:bar];
    }
    
    self.navigationItem.titleView = navView;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateNavigationPreview];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"";
    self.navigationItem.title = @"";
    
    UIColor *tintColor = [UIColor colorWithRed:72/255.0 green:178/255.0 blue:199/255.0 alpha:1.0];
    [UISwitch appearanceWhenContainedInInstancesOfClasses:@[[self class]]].onTintColor = tintColor;
    self.view.tintColor = tintColor;
    [self amlUpdateHeaderArtwork];
    
    if (!_cachedGithubIcon) {
        [self fetchGithubLogo];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self amlUpdateHeaderArtwork];
}

- (void)amlUpdateHeaderArtwork {
    if (!self.headerImageView) return;
    
    NSString *resourceName = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? @"JelloIconDark" : @"JelloIconLight";
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:resourceName ofType:@"png"];
    self.headerImageView.image = [UIImage imageWithContentsOfFile:path];
}

- (NSArray *)specifiers {
    if (!_allSpecifiers) {
        _allSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    
    NSMutableArray *filtered = [NSMutableArray array];
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.shalamand3r.jello"];
    NSInteger style = [prefs integerForKey:@"visualizerStyle"];
    
    for (PSSpecifier *spec in _allSpecifiers) {
        NSString *specId = [spec propertyForKey:@"id"];

        if (style != 1) {
            if ([specId isEqualToString:@"blendGroup"] || [specId isEqualToString:@"circleIntersectionStyle"] || [specId isEqualToString:@"rotateCircle"] || [specId isEqualToString:@"circleRotationSpeed"] || [specId isEqualToString:@"circleGroup"] || [specId isEqualToString:@"circleSizeGroup"] || [specId isEqualToString:@"circleSize"] || [specId isEqualToString:@"circleCount"] || [specId isEqualToString:@"circleDynamicSize"] || [specId isEqualToString:@"circleTransparentBlending"]) continue;
        } else {
            if (![prefs boolForKey:@"rotateCircle"]) {
                if ([specId isEqualToString:@"circleRotationSpeed"]) continue;
            }
            NSInteger circleCount = [prefs objectForKey:@"circleCount"] ? [prefs integerForKey:@"circleCount"] : 2;
            if (circleCount != 2) {
                if ([specId isEqualToString:@"circleTransparentBlending"]) continue;
            }
        }
        if (style != 2) {
            if ([specId isEqualToString:@"barsGroup"] || 
                [specId isEqualToString:@"barsThickness"] || 
                [specId isEqualToString:@"barsSpacingGroup"] || 
                [specId isEqualToString:@"barsSpacing"] || 
                [specId isEqualToString:@"barsRadiusGroup"] || 
                [specId isEqualToString:@"barsCornerRadius"] || 
                [specId isEqualToString:@"barsRoundTopOnly"]) continue;
        }
        if (style != 4) {
            if ([specId isEqualToString:@"waveformGroup"] || 
                [specId isEqualToString:@"waveformThickness"] || 
                [specId isEqualToString:@"waveformSpacingGroup"] || 
                [specId isEqualToString:@"waveformSpacing"] || 
                [specId isEqualToString:@"waveformRadiusGroup"] || 
                [specId isEqualToString:@"waveformCornerRadius"]) continue;
        }
        if (style != 3) {
            if ([specId isEqualToString:@"importCustomJSON"]) continue;
        }
        [filtered addObject:spec];
    }
    
    _specifiers = filtered;
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
    
    NSString *key = [specifier propertyForKey:@"key"];
    
    if ([key isEqualToString:@"framerate"] || [key isEqualToString:@"pollingRate"]) {
        PSSpecifier *framerateSpec = [self specifierForID:@"framerate"];
        PSSpecifier *pollingSpec = [self specifierForID:@"pollingRate"];
        
        if (framerateSpec && pollingSpec) {
            NSInteger framerate = [[self readPreferenceValue:framerateSpec] integerValue];
            if (framerate == 0) framerate = 60;
            
            NSInteger pollingRate = [[self readPreferenceValue:pollingSpec] integerValue];
            if (pollingRate == 0) pollingRate = 30;
            
            if (pollingRate > framerate) {
                pollingRate = framerate;
                [self setPreferenceValue:@(pollingRate) specifier:pollingSpec];
                
                if ([self respondsToSelector:@selector(cachedCellForSpecifier:)]) {
                    id cell = [self performSelector:@selector(cachedCellForSpecifier:) withObject:pollingSpec];
                    if (cell && [cell respondsToSelector:@selector(control)]) {
                        UISlider *slider = [cell performSelector:@selector(control)];
                        if ([slider isKindOfClass:[UISlider class]]) {
                            [slider setValue:pollingRate animated:YES];
                        }
                    }
                }
                
                [self reloadSpecifier:pollingSpec];
            }
        }
    }
    
    
    if ([key isEqualToString:@"visualizerStyle"] || [key isEqualToString:@"rotateCircle"] || [key isEqualToString:@"circleIntersectionStyle"] || [key isEqualToString:@"circleCount"]) {
        [self reloadSpecifiers];
    }
}

- (void)importCustomJSON:(id)sender {
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeJSON] asCopy:YES];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json"] inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *sourceURL = urls.firstObject;
    if (!sourceURL) return;

    NSString *destPath = @"/var/mobile/Library/Preferences/com.shalamand3r.jello.custom.json";
    NSError *error = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
    }
    
    if ([[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:destPath] error:&error]) {
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:destPath error:nil];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                       message:@"Custom shape imported successfully!"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        notify_post("com.shalamand3r.jello.preferences.changed");
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                       message:[NSString stringWithFormat:@"Failed to import: %@", error.localizedDescription]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)openGithub {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/shalamand3r/Jello"] options:@{} completionHandler:nil];
}

- (void)openPlayground {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://shalamand3r.github.io/jello-playground"] options:@{} completionHandler:nil];
}

- (void)selectCustomColor {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    
    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.delegate = self;
    picker.supportsAlpha = NO;
    
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.shalamand3r.jello"];
    NSString *hexColor = [prefs stringForKey:@"customColorHex"];
    if (hexColor) {
        picker.selectedColor = [self colorFromHex:hexColor];
    }
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)colorPicker {
    UIColor *selectedColor = colorPicker.selectedColor;
    NSString *hexColor = [self hexStringFromColor:selectedColor];
    
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.shalamand3r.jello"];
    [prefs setObject:hexColor forKey:@"customColorHex"];
    [prefs setInteger:1 forKey:@"colorMode"];
    [prefs synchronize];
    
    notify_post("com.shalamand3r.jello.preferences.changed");
}

- (NSString *)hexStringFromColor:(UIColor *)color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255)];
}

- (UIColor *)colorFromHex:(NSString *)hexString {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if ([cleanString length] == 3) {
        cleanString = [NSString stringWithFormat:@"%@%@%@%@%@%@",
                       [cleanString substringWithRange:NSMakeRange(0, 1)], [cleanString substringWithRange:NSMakeRange(0, 1)],
                       [cleanString substringWithRange:NSMakeRange(1, 1)], [cleanString substringWithRange:NSMakeRange(1, 1)],
                       [cleanString substringWithRange:NSMakeRange(2, 1)], [cleanString substringWithRange:NSMakeRange(2, 1)]];
    }
    if ([cleanString length] == 6) {
        unsigned int baseValue;
        [[NSScanner scannerWithString:cleanString] scanHexInt:&baseValue];
        float red = ((baseValue >> 16) & 0xFF) / 255.0f;
        float green = ((baseValue >> 8) & 0xFF) / 255.0f;
        float blue = ((baseValue >> 0) & 0xFF) / 255.0f;
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
    }
    return [UIColor whiteColor];
}

- (void)resetSettings {
    if (self.resetInProgress) return;
    self.resetInProgress = YES;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    
    NSString *suiteName = @"com.shalamand3r.jello";
    CFStringRef suiteRef = (__bridge CFStringRef)suiteName;
    
    CFPreferencesSetAppValue(CFSTR("enabled"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("visualizerStyle"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("circleCount"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("circleDynamicSize"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("circleSize"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("circleIntersectionStyle"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("rotateCircle"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("circleRotationSpeed"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("circleTransparentBlending"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("colorMode"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("customColorHex"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("barsThickness"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("barsCornerRadius"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("barsRoundTopOnly"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("barsSpacing"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("waveformThickness"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("waveformCornerRadius"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("waveformSpacing"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("placement"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("amplitudeLevel"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("opacity"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("visualizerHeight"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("framerate"), NULL, suiteRef);
    CFPreferencesSetAppValue(CFSTR("pollingRate"), NULL, suiteRef);
    
    CFPreferencesAppSynchronize(suiteRef);
    
    NSString *customJsonPath = @"/var/mobile/Library/Preferences/com.shalamand3r.jello.custom.json";
    if ([[NSFileManager defaultManager] fileExistsAtPath:customJsonPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:customJsonPath error:nil];
    }
    
    self.allSpecifiers = nil;
    [self reloadSpecifiers];
    
    notify_post("com.shalamand3r.jello.preferences.changed");
    
    self.resetInProgress = NO;
}

- (void)fetchGithubLogo {
    if (_cachedGithubIcon) return;
    NSURL *url = [NSURL URLWithString:@"https://github.com/shalamand3r.png"];
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 29, 29)];
                imageView.image = image;
                imageView.layer.cornerRadius = 7;
                imageView.layer.masksToBounds = YES;
                imageView.layer.contentsGravity = kCAGravityResizeAspectFill;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                CGFloat scale = [UIScreen mainScreen].scale;
#pragma clang diagnostic pop
                UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, NO, scale);
                [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *squircleImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();

                _cachedGithubIcon = squircleImage;
                dispatch_async(dispatch_get_main_queue(), ^{
                    PSSpecifier *githubSpecifier = [self specifierForID:@"GitHubCell"];
                    if (githubSpecifier) {
                        [githubSpecifier setProperty:squircleImage forKey:@"iconImage"];
                        [self reloadSpecifier:githubSpecifier];

                        NSIndexPath *indexPath = [self indexPathForSpecifier:githubSpecifier];
                        if (indexPath) {
                            UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];
                            if (cell) {
                                UIView *spinner = [cell.imageView viewWithTag:1234];
                                if (spinner) {
                                    [spinner removeFromSuperview];
                                }
                            }
                        }
                    }
                });
            }
        }
    }] resume];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];

    if ([[specifier propertyForKey:@"action"] isEqualToString:@"resetSettings"]) {
        cell.textLabel.textColor = [UIColor systemRedColor];
    }

    return cell;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
