#import <MediaRemote/MediaRemote.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import <notify.h>
#import <objc/runtime.h>
#import <os/log.h>

static const char *MLWaveformNotifyName = "com.shalamand3r.jello.waveform";
static CFStringRef const MLPrefsChangedNotification = CFSTR("com.shalamand3r.jello.preferences.changed");
static NSString *const MLPrefsSuiteName = @"com.shalamand3r.jello";
static NSString *const MLPlacementPreferenceKey = @"placement";
static NSString *const MLStylePreferenceKey = @"visualizerStyle";
static NSString *const MLHeightPreferenceKey = @"visualizerHeight";
static NSString *const MLOpacityPreferenceKey = @"opacity";
static NSString *const MLAmplitudePreferenceKey = @"amplitudeLevel";

@interface MLWaveformView : UIView {
    CAShapeLayer *_jelloLayer;
    CAShapeLayer *_jelloLayerMid;
    CAShapeLayer *_jelloLayerHigh;

    CALayer *_bars[6];
    UIColor *_tintColor;
    float _amplitudes[6];
    float _targetAmplitudes[6];
    CADisplayLink *_displayLink;
    CALayer *_circleContainerLayer;
    int _notifyToken;
    BOOL _running;
    BOOL _enabled;

    NSInteger _visualizerStyle;
    CGFloat _heightPercent;
    CGFloat _opacityPercent;
    NSInteger _amplitudeLevel;
    NSInteger _pollingRate;
    BOOL _rotateCircle;
    NSInteger _circleCount;
    BOOL _circleDynamicSize;
    NSInteger _circleIntersectionStyle;
    CGFloat _circleSizePercent;
    
    NSInteger _framerate;
    
    CGFloat _circleRotationSpeed;
    CGFloat _waveformSpacing;
    CGFloat _waveformThickness;
    CGFloat _waveformCornerRadius;
    CGFloat _barsSpacing;
    CGFloat _barsThickness;
    CGFloat _barsCornerRadius;
    BOOL _barsRoundTopOnly;
    CGFloat _rotationAngle;
    NSTimeInterval _lastUpdate;
    NSTimeInterval _idleTime;
    NSMutableArray<CAShapeLayer *> *_customLayers;
    NSDictionary *_customShapeData;
    NSInteger _colorMode;
    UIColor *_customColor;
}
- (void)start;
- (void)stop;
- (void)reloadPreferences;
- (void)updateTintColor:(UIColor *)color;
- (void)displayLinkTick;
@end

@interface CSFixedFooterViewController : UIViewController
@end

@interface SBMediaController : NSObject
@end

@interface MLDisplayLinkProxy : NSObject
@property (nonatomic, weak) MLWaveformView *target;
+ (instancetype)proxyWithTarget:(MLWaveformView *)target;
- (void)displayLinkTick:(CADisplayLink *)displayLink;
@end

static char MLWaveformViewAssociationKey;
static char MLNowPlayingWaveformViewAssociationKey;
static NSHashTable<MLWaveformView *> *MLActiveVisualizers = nil;
static UIColor *currentVibrancyColor = nil;
static NSArray<UIColor *> *MLArtworkTintColors;
static UIColor *MLArtworkTintColor;

static CGFloat MLClampCGFloat(CGFloat value, CGFloat minimum, CGFloat maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

static CGPoint MLMidPoint(CGPoint a, CGPoint b) {
    return CGPointMake((a.x + b.x) * 0.5, (a.y + b.y) * 0.5);
}

static UIColor *MLColorWithAlpha(UIColor *color, CGFloat alpha) {
    return [(color ?: UIColor.whiteColor) colorWithAlphaComponent:alpha];
}

static size_t MLColorResolution = 64;

static NSArray<UIColor *> *MLTopColorsForImage(UIImage *image) {
    if (!image) return nil;

    size_t sampleSize = MLColorResolution;
    static const NSUInteger bucketCount = 512;
    UInt8 *pixels = (UInt8 *)calloc(sampleSize * sampleSize * 4, sizeof(UInt8));
    if (!pixels) return nil;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels,
                                                 sampleSize,
                                                 sampleSize,
                                                 8,
                                                 sampleSize * 4,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free(pixels);
        return nil;
    }

    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0, 0, sampleSize, sampleSize), image.CGImage);
    CGContextRelease(context);

    NSUInteger counts[bucketCount] = {0};
    CGFloat redSums[bucketCount] = {0};
    CGFloat greenSums[bucketCount] = {0};
    CGFloat blueSums[bucketCount] = {0};
    CGFloat scores[bucketCount] = {0};
    CGFloat paletteRedSum = 0.0;
    CGFloat paletteGreenSum = 0.0;
    CGFloat paletteBlueSum = 0.0;
    CGFloat paletteWeightSum = 0.0;

    for (NSUInteger i = 0; i < sampleSize * sampleSize; i++) {
        UInt8 redByte = pixels[(i * 4) + 0];
        UInt8 greenByte = pixels[(i * 4) + 1];
        UInt8 blueByte = pixels[(i * 4) + 2];
        UInt8 alphaByte = pixels[(i * 4) + 3];
        if (alphaByte < 24) continue;

        CGFloat red = redByte / 255.0;
        CGFloat green = greenByte / 255.0;
        CGFloat blue = blueByte / 255.0;
        CGFloat maxComponent = MAX(red, MAX(green, blue));
        CGFloat minComponent = MIN(red, MIN(green, blue));
        CGFloat saturation = maxComponent <= 0.001 ? 0.0 : (maxComponent - minComponent) / maxComponent;
        CGFloat brightness = maxComponent;

        NSUInteger redBucket = redByte >> 5;
        NSUInteger greenBucket = greenByte >> 5;
        NSUInteger blueBucket = blueByte >> 5;
        NSUInteger bucket = (redBucket << 6) | (greenBucket << 3) | blueBucket;

        CGFloat score = 1.0 + (saturation * 0.75);
        if (brightness < 0.10 || brightness > 0.97) score *= 0.16;
        if (saturation < 0.08) score *= 0.38;
        CGFloat paletteWeight = score * 0.42;

        counts[bucket]++;
        redSums[bucket] += red;
        greenSums[bucket] += green;
        blueSums[bucket] += blue;
        scores[bucket] += score;
        paletteRedSum += red * paletteWeight;
        paletteGreenSum += green * paletteWeight;
        paletteBlueSum += blue * paletteWeight;
        paletteWeightSum += paletteWeight;
    }
    free(pixels);

    NSMutableArray *bucketScores = [NSMutableArray array];
    for (NSUInteger i = 0; i < bucketCount; i++) {
        if (counts[i] == 0) continue;
        [bucketScores addObject:@{@"bucket": @(i), @"score": @(scores[i])}];
    }
    
    [bucketScores sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        CGFloat s1 = [obj1[@"score"] doubleValue];
        CGFloat s2 = [obj2[@"score"] doubleValue];
        if (s1 < s2) return NSOrderedDescending;
        if (s1 > s2) return NSOrderedAscending;
        return NSOrderedSame;
    }];

    if (bucketScores.count == 0) return nil;

    NSMutableArray<UIColor *> *topColors = [NSMutableArray array];
    for (int idx = 0; idx < MIN(3, (int)bucketScores.count); idx++) {
        NSUInteger bestBucket = [bucketScores[idx][@"bucket"] unsignedIntegerValue];
        CGFloat red = redSums[bestBucket] / (CGFloat)counts[bestBucket];
        CGFloat green = greenSums[bestBucket] / (CGFloat)counts[bestBucket];
        CGFloat blue = blueSums[bestBucket] / (CGFloat)counts[bestBucket];
        if (paletteWeightSum > 0.0) {
            CGFloat blend = 0.07;
            red = (red * (1.0 - blend)) + ((paletteRedSum / paletteWeightSum) * blend);
            green = (green * (1.0 - blend)) + ((paletteGreenSum / paletteWeightSum) * blend);
            blue = (blue * (1.0 - blend)) + ((paletteBlueSum / paletteWeightSum) * blend);
        }
        UIColor *rawColor = [UIColor colorWithRed:red green:green blue:blue alpha:1.0];

        CGFloat hue = 0.0;
        CGFloat saturation = 0.0;
        CGFloat brightness = 0.0;
        CGFloat alpha = 1.0;
        UIColor *finalColor = rawColor;
        if ([rawColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
            if (brightness < 0.24 && saturation < 0.18) {
                finalColor = [UIColor colorWithHue:hue
                                  saturation:MLClampCGFloat(saturation, 0.0, 0.12)
                                  brightness:MLClampCGFloat(brightness, 0.08, 0.24)
                                       alpha:1.0];
            } else {
                saturation = MLClampCGFloat(MAX(saturation, 0.24), 0.0, 0.82);
                brightness = MLClampCGFloat(brightness, 0.18, 0.88);
                finalColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
            }
        }
        [topColors addObject:finalColor];
    }
    
    while (topColors.count > 0 && topColors.count < 3) {
        [topColors addObject:topColors.lastObject];
    }
    
    return topColors;
}


static UIColor *MLTintColor(void) {
    return MLArtworkTintColor ?: UIColor.whiteColor;
}

static void MLApplyTintToActiveVisualizers(void) {
    for (MLWaveformView *view in MLActiveVisualizers) {
        [view updateTintColor:nil];
    }
}

static void MLSetArtworkColors(NSArray<UIColor *> *topColors) {
    if (topColors.count >= 3) {
        MLArtworkTintColors = topColors;
        MLArtworkTintColor = topColors.firstObject;
    } else if (topColors.count > 0) {
        MLArtworkTintColors = @[topColors.firstObject, topColors.firstObject, topColors.firstObject];
        MLArtworkTintColor = topColors.firstObject;
    }
    MLApplyTintToActiveVisualizers();
}

static void MLUpdateArtworkTintFromImage(UIImage *image) {
    MLSetArtworkColors(MLTopColorsForImage(image));
}

static void MLUpdateArtworkTintFromNowPlayingInfo(NSDictionary *info) {
    NSData *artworkData = nil;
    id value = info[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
    if ([value isKindOfClass:NSData.class]) {
        artworkData = value;
    }
    if (!artworkData) return;

    UIImage *image = [UIImage imageWithData:artworkData];
    MLUpdateArtworkTintFromImage(image);
}

static void MLRefreshArtworkTint(void) {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        if (!information) return;
        MLUpdateArtworkTintFromNowPlayingInfo((__bridge NSDictionary *)information);
    });
}

static void MLPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    MLWaveformView *view = (__bridge MLWaveformView *)observer;
    [view reloadPreferences];
}

static UIColor *MLColorFromHex(NSString *hexString) {
    if (!hexString) return [UIColor whiteColor];
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

@implementation MLDisplayLinkProxy

+ (instancetype)proxyWithTarget:(MLWaveformView *)target {
    MLDisplayLinkProxy *proxy = [MLDisplayLinkProxy new];
    proxy.target = target;
    return proxy;
}

- (void)displayLinkTick:(CADisplayLink *)displayLink {
    MLWaveformView *target = self.target;
    if (target) {
        [target displayLinkTick];
    } else {
        [displayLink invalidate];
    }
}

@end

@implementation MLWaveformView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.alpha = 0.0f;
        _notifyToken = NOTIFY_TOKEN_INVALID;
        _amplitudeLevel = 1;
        _heightPercent = 75.0;
        _rotateCircle = NO;
        _circleCount = 2;
        _circleSizePercent = 50.0;
        _circleDynamicSize = NO;
        _circleIntersectionStyle = 1;
        _opacityPercent = 40.0;
        _barsRoundTopOnly = NO;
        _colorMode = 0;
        _customColor = nil;
        _tintColor = MLTintColor();

        _circleContainerLayer = [CALayer layer];
        _circleContainerLayer.frame = self.bounds;
        [self.layer addSublayer:_circleContainerLayer];
        
        _jelloLayer = [CAShapeLayer layer];
        _jelloLayer.masksToBounds = NO;
        _jelloLayer.lineJoin = kCALineJoinRound;
        [_circleContainerLayer addSublayer:_jelloLayer];
        
        _jelloLayerMid = [CAShapeLayer layer];
        _jelloLayerMid.masksToBounds = NO;
        _jelloLayerMid.lineJoin = kCALineJoinRound;
        [_circleContainerLayer addSublayer:_jelloLayerMid];
        
        _jelloLayerHigh = [CAShapeLayer layer];
        _jelloLayerHigh.lineCap = kCALineCapRound;
        _jelloLayerHigh.lineJoin = kCALineJoinRound;
        [_circleContainerLayer addSublayer:_jelloLayerHigh];
        
        _customLayers = [NSMutableArray array];
        
        for (int i = 0; i < 6; i++) {
            _bars[i] = [CALayer layer];
            [_circleContainerLayer addSublayer:_bars[i]];
        }

        [self updateTintColor:_tintColor];
        [self reloadPreferences];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        MLPrefsChanged,
                                        MLPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                       (__bridge const void *)(self),
                                       MLPrefsChangedNotification,
                                       NULL);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeIfStale) object:nil];
    if (_notifyToken != NOTIFY_TOKEN_INVALID) {
        notify_cancel(_notifyToken);
        _notifyToken = NOTIFY_TOKEN_INVALID;
    }
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)updateTintColor:(UIColor *)color {
    UIColor *baseColor = MLTintColor();
    if (_colorMode == 1 && _customColor) {
        baseColor = _customColor;
    } else if (_colorMode == 2 && currentVibrancyColor) {
        baseColor = currentVibrancyColor;
    }
    
    _tintColor = color ?: baseColor;
    CGFloat opacity = MLClampCGFloat(_opacityPercent / 100.0, 0.05, 1.0);
    CGColorRef cgColor = MLColorWithAlpha(_tintColor, opacity).CGColor;
    
    UIColor *secondaryColor = baseColor;
    if (_colorMode == 0) {
        secondaryColor = MLTintColor();
    }
    CGColorRef secondaryCgColor = MLColorWithAlpha(secondaryColor, opacity * 0.8).CGColor;
    
    if (_colorMode == 0 && _visualizerStyle == 0 && MLArtworkTintColors.count >= 3) {
        _jelloLayer.fillColor = MLColorWithAlpha(MLArtworkTintColors[0], opacity).CGColor;
        _jelloLayerMid.fillColor = MLColorWithAlpha(MLArtworkTintColors[1], opacity).CGColor;
        _jelloLayerHigh.fillColor = MLColorWithAlpha(MLArtworkTintColors[2], opacity).CGColor;
    } else if (_colorMode == 0 && _visualizerStyle == 1 && _circleCount == 3 && MLArtworkTintColors.count >= 3) {
        _jelloLayer.fillColor = MLColorWithAlpha(MLArtworkTintColors[0], opacity).CGColor;
        _jelloLayerMid.fillColor = MLColorWithAlpha(MLArtworkTintColors[1], opacity).CGColor;
        _jelloLayerHigh.fillColor = MLColorWithAlpha(MLArtworkTintColors[2], opacity).CGColor;
    } else if (_visualizerStyle == 1 && _circleCount == 2) {
        _jelloLayer.fillColor = cgColor;
        _jelloLayerMid.fillColor = secondaryCgColor;
        _jelloLayerHigh.fillColor = cgColor;
    } else {
        _jelloLayer.fillColor = cgColor;
        _jelloLayerMid.fillColor = cgColor;
        _jelloLayerHigh.fillColor = cgColor;
    }
    
    NSString *blendMode = nil;
    if (_visualizerStyle == 1) {
        if (_circleIntersectionStyle == 1) {
            blendMode = @"screenBlendMode";
        }
    }
    
    _jelloLayer.compositingFilter = blendMode;
    _jelloLayerMid.compositingFilter = blendMode;
    _jelloLayerHigh.compositingFilter = blendMode;
    
    for (int i = 0; i < 6; i++) {
        _bars[i].backgroundColor = cgColor;
        _bars[i].compositingFilter = blendMode;
    }
    
    for (CAShapeLayer *l in _customLayers) {
        l.compositingFilter = blendMode;
    }
    
    for (CAShapeLayer *layer in _customLayers) {
        if (layer.lineWidth > 0.0) {
            layer.strokeColor = cgColor;
            layer.fillColor = [UIColor clearColor].CGColor;
        } else {
            layer.fillColor = cgColor;
            layer.strokeColor = nil;
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _circleContainerLayer.frame = self.bounds;
    [self updateTintColor:nil];
    [self layoutVisualizerAnimated:NO];
}

- (void)setLayerActionsDisabled:(BOOL)disabled animated:(BOOL)animated {
    [CATransaction setDisableActions:disabled];
    if (animated) {
        [CATransaction setAnimationDuration:0.11];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    }
}

- (CGRect)visualizerRect {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat rectHeight = height * MLClampCGFloat(_heightPercent / 100.0, 0.05, 1.0);
    return CGRectMake(0.0, height - rectHeight, width, rectHeight);
}

- (CGPoint)pointForAmplitude:(CGFloat)amplitude position:(CGFloat)position {
    CGRect rect = [self visualizerRect];
    CGFloat bottomInset = MAX(8.0, CGRectGetHeight(rect) * 0.08);
    CGFloat topInset = MAX(8.0, CGRectGetHeight(rect) * 0.04);
    CGFloat usableHeight = MAX(1.0, CGRectGetHeight(rect) - bottomInset - topInset);
    CGFloat x = CGRectGetMinX(rect) + (CGRectGetWidth(rect) * MLClampCGFloat(position, 0.0, 1.0));
    CGFloat y = CGRectGetMaxY(rect) - bottomInset - (usableHeight * sqrt(MLClampCGFloat(amplitude, 0.0, 1.0)));
    return CGPointMake(x, y);
}

- (CGPathRef)newJelloPathForAmplitudes:(CGFloat *)amplitudes count:(NSUInteger)count {
    CGRect rect = [self visualizerRect];
    CGFloat bottom = CGRectGetMaxY(rect);
    if (count == 0) return CGPathCreateMutable();

    CGPoint points[6];
    for (NSUInteger i = 0; i < count; i++) {
        CGFloat position = count <= 1 ? 0.0 : (CGFloat)i / (CGFloat)(count - 1);
        points[i] = [self pointForAmplitude:amplitudes[i] position:position];
    }

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect), bottom);
    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
    CGPoint previous = points[0];
    for (NSUInteger i = 1; i < count; i++) {
        CGPoint current = points[i];
        CGPoint mid = MLMidPoint(previous, current);
        CGPathAddQuadCurveToPoint(path, NULL, previous.x, previous.y, mid.x, mid.y);
        previous = current;
    }
    CGPathAddQuadCurveToPoint(path, NULL, previous.x, previous.y, previous.x, previous.y);
    CGPathAddLineToPoint(path, NULL, CGRectGetMaxX(rect), bottom);
    CGPathCloseSubpath(path);
    return path;
}

- (CGPathRef)newCirclePathForAmplitudes:(CGFloat *)amplitudes count:(NSUInteger)count {
    CGMutablePathRef path = CGPathCreateMutable();
    CGRect rect = self.bounds;
    CGFloat cx = CGRectGetMidX(rect);
    CGFloat cy = CGRectGetMidY(rect);
    
    CGFloat expandedAmplitudes[24];
    for (int i = 0; i < 6; i++) {
        expandedAmplitudes[i] = amplitudes[i];
        expandedAmplitudes[11 - i] = amplitudes[i];
        expandedAmplitudes[12 + i] = amplitudes[i];
        expandedAmplitudes[23 - i] = amplitudes[i];
    }
    
    CGFloat baseRadiusMultiplier = _circleSizePercent / 200.0;
    CGFloat baseRadius = MIN(rect.size.width, rect.size.height) * baseRadiusMultiplier;
    
    if (_circleDynamicSize) {
        CGFloat bassBump = (_amplitudes[0] + _amplitudes[1]) / 2.0;
        CGFloat dynamicBumpFactor = _amplitudeLevel == 0 ? 0.12 : (_amplitudeLevel == 2 ? 0.40 : 0.25);
        CGFloat bumpMultiplier = 1.0 + (bassBump * dynamicBumpFactor);
        baseRadius *= bumpMultiplier;
    }
    
    if (baseRadius < 20.0) baseRadius = 20.0;
    
    CGFloat heightMultiplier = MLClampCGFloat(_heightPercent / 50.0, 0.1, 3.0);
    CGFloat maxHeight = baseRadius * 0.6 * heightMultiplier;
    
    CGPoint points[24];
    for (int i = 0; i < 24; i++) {
        CGFloat angle = (i / 24.0) * M_PI * 2.0;
        CGFloat r = baseRadius + (expandedAmplitudes[i] * maxHeight);
        points[i] = CGPointMake(cx + r * cos(angle), cy + r * sin(angle));
    }
    
    CGPoint lastMid = CGPointMake((points[23].x + points[0].x) / 2.0, (points[23].y + points[0].y) / 2.0);
    CGPathMoveToPoint(path, NULL, lastMid.x, lastMid.y);
    
    for (int i = 0; i < 24; i++) {
        CGPoint current = points[i];
        CGPoint next = points[(i + 1) % 24];
        CGPoint nextMid = CGPointMake((current.x + next.x) / 2.0, (current.y + next.y) / 2.0);
        CGPathAddQuadCurveToPoint(path, NULL, current.x, current.y, nextMid.x, nextMid.y);
    }
    
    CGPathCloseSubpath(path);
    return path;
}

- (void)layoutJelloAnimated:(BOOL)animated {
    [CATransaction begin];
    [self setLayerActionsDisabled:YES animated:NO];
    _jelloLayer.frame = self.bounds;
    _jelloLayerMid.frame = self.bounds;
    _jelloLayerHigh.frame = self.bounds;
    
    CGFloat lowAmplitudes[6];
    CGFloat midAmplitudes[6];
    CGFloat highAmplitudes[6];
    
    CGFloat lowWeights[6]  = {1.0, 0.9, 0.6, 0.4, 0.2, 0.1};
    CGFloat midWeights[6]  = {0.3, 0.6, 1.0, 1.0, 0.6, 0.3};
    CGFloat highWeights[6] = {0.1, 0.2, 0.4, 0.6, 0.9, 1.0};
    
    for (int i = 0; i < 6; i++) {
        lowAmplitudes[i]  = _amplitudes[i] * lowWeights[i];
        midAmplitudes[i]  = _amplitudes[i] * midWeights[i];
        highAmplitudes[i] = _amplitudes[i] * highWeights[i];
    }

    CGPathRef pathLow = [self newJelloPathForAmplitudes:lowAmplitudes count:6];
    _jelloLayer.path = pathLow;
    CGPathRelease(pathLow);

    CGPathRef pathMid = [self newJelloPathForAmplitudes:midAmplitudes count:6];
    _jelloLayerMid.path = pathMid;
    CGPathRelease(pathMid);

    CGPathRef pathHigh = [self newJelloPathForAmplitudes:highAmplitudes count:6];
    _jelloLayerHigh.path = pathHigh;
    CGPathRelease(pathHigh);
    
    [CATransaction commit];
}

- (void)layoutCircleAnimated:(BOOL)animated {
    [CATransaction begin];
    [self setLayerActionsDisabled:YES animated:NO];
    _jelloLayer.frame = self.bounds;
    _jelloLayerMid.frame = self.bounds;
    _jelloLayerHigh.frame = self.bounds;
    
    CGFloat lowAmplitudes[6];
    CGFloat midAmplitudes[6];
    CGFloat highAmplitudes[6];
    
    if (_circleCount == 3) {
        _jelloLayerHigh.hidden = NO;
        
        for (int i = 0; i < 6; i++) {
            lowAmplitudes[i] = 0.0;
            midAmplitudes[i] = 0.0;
            highAmplitudes[i] = 0.0;
        }
        lowAmplitudes[0] = _amplitudes[0];
        lowAmplitudes[3] = _amplitudes[3];
        
        midAmplitudes[1] = _amplitudes[1];
        midAmplitudes[4] = _amplitudes[4];
        
        highAmplitudes[2] = _amplitudes[2];
        highAmplitudes[5] = _amplitudes[5];
    } else {
        _jelloLayerHigh.hidden = YES;
        for (int i = 0; i < 6; i++) {
            if (i % 2 == 0) {
                lowAmplitudes[i] = _amplitudes[i];
                midAmplitudes[i] = 0.0;
            } else {
                lowAmplitudes[i] = 0.0;
                midAmplitudes[i] = _amplitudes[i];
            }
            highAmplitudes[i] = 0.0;
        }
    }
    
    CGPathRef pathLow = [self newCirclePathForAmplitudes:lowAmplitudes count:6];
    CGPathRef pathMid = [self newCirclePathForAmplitudes:midAmplitudes count:6];
    CGPathRef pathHigh = (_circleCount == 3) ? [self newCirclePathForAmplitudes:highAmplitudes count:6] : NULL;
    
    if (_rotateCircle) {
        CGAffineTransform transform = CGAffineTransformMakeTranslation(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
        transform = CGAffineTransformRotate(transform, _rotationAngle);
        transform = CGAffineTransformTranslate(transform, -self.bounds.size.width / 2.0, -self.bounds.size.height / 2.0);
        
        CGPathRef rotatedLow = CGPathCreateCopyByTransformingPath(pathLow, &transform);
        _jelloLayer.path = rotatedLow;
        CGPathRelease(rotatedLow);
        
        CGPathRef rotatedMid = CGPathCreateCopyByTransformingPath(pathMid, &transform);
        _jelloLayerMid.path = rotatedMid;
        CGPathRelease(rotatedMid);
        
        if (pathHigh) {
            CGPathRef rotatedHigh = CGPathCreateCopyByTransformingPath(pathHigh, &transform);
            _jelloLayerHigh.path = rotatedHigh;
            CGPathRelease(rotatedHigh);
        }
    } else {
        _jelloLayer.path = pathLow;
        _jelloLayerMid.path = pathMid;
        if (pathHigh) _jelloLayerHigh.path = pathHigh;
    }
    
    CGPathRelease(pathLow);
    CGPathRelease(pathMid);
    if (pathHigh) CGPathRelease(pathHigh);
    
    [CATransaction commit];
}

- (CGPathRef)newCustomPathForAmplitudes:(CGFloat *)amplitudes layerData:(NSDictionary *)layerData count:(NSUInteger)count {
    CGMutablePathRef path = CGPathCreateMutable();
    if (!layerData) return path;

    CGRect rect = self.bounds;
    NSArray *pointsArray = layerData[@"points"];
    if (![pointsArray isKindOfClass:[NSArray class]] || pointsArray.count == 0) return path;

    NSString *system = layerData[@"system"];
    NSString *smoothing = layerData[@"smoothing"];
    BOOL closed = [layerData[@"closed"] boolValue];

    CGFloat originX = [layerData[@"originX"] doubleValue];
    CGFloat originY = [layerData[@"originY"] doubleValue];
    CGFloat cx = rect.size.width * originX;
    CGFloat cy = rect.size.height * originY;

    CGFloat breatheAmplitude = [layerData[@"breatheAmplitude"] doubleValue];
    CGFloat breatheSpeed = [layerData[@"breatheSpeed"] doubleValue];
    if (breatheSpeed == 0.0) breatheSpeed = 1.0;
    
    CGFloat idleOffset = 0.0;
    if (breatheAmplitude > 0.0) {
        idleOffset = sin(_idleTime * breatheSpeed) * breatheAmplitude;
    }

    NSMutableArray *calculatedPoints = [NSMutableArray array];
    
    CGFloat globalScale = MIN(rect.size.width, rect.size.height) * 0.4 * (_heightPercent / 100.0);
    if (globalScale < 20.0) globalScale = 50.0; 

    for (NSDictionary *ptDict in pointsArray) {
        if (![ptDict isKindOfClass:[NSDictionary class]]) continue;
        
        NSInteger bucket = [ptDict[@"bucket"] integerValue];
        if (bucket < 0) bucket = 0;
        if (bucket > 5) bucket = 5;
        
        CGFloat multiplier = [ptDict[@"multiplier"] doubleValue];
        if (multiplier == 0.0) multiplier = 1.0;
        
        CGFloat amp = amplitudes[bucket] * multiplier * globalScale;

        if ([system isEqualToString:@"polar"]) {
            CGFloat angle = [ptDict[@"angle"] doubleValue] * (M_PI / 180.0);
            CGFloat baseRadius = [layerData[@"baseRadius"] doubleValue] + idleOffset;
            CGFloat r = baseRadius + amp;
            CGPoint p = CGPointMake(cx + r * cos(angle), cy + r * sin(angle));
            [calculatedPoints addObject:[NSValue valueWithCGPoint:p]];
        } else {
            CGFloat baseX = [ptDict[@"x"] doubleValue] * rect.size.width;
            CGFloat baseY = [ptDict[@"y"] doubleValue] * rect.size.height;
            CGFloat dirX = [ptDict[@"dirX"] doubleValue];
            CGFloat dirY = [ptDict[@"dirY"] doubleValue];
            CGPoint p = CGPointMake(baseX + (amp * dirX) + (idleOffset * dirX), baseY + (amp * dirY) + (idleOffset * dirY));
            [calculatedPoints addObject:[NSValue valueWithCGPoint:p]];
        }
    }

    if (calculatedPoints.count > 0) {
        CGPoint firstPoint = [calculatedPoints[0] CGPointValue];
        CGPathMoveToPoint(path, NULL, firstPoint.x, firstPoint.y);
        
        if ([smoothing isEqualToString:@"curve"] && calculatedPoints.count > 1) {
            CGPoint previous = firstPoint;
            for (NSUInteger i = 1; i <= calculatedPoints.count + (closed ? 1 : 0); i++) {
                if (i == calculatedPoints.count && !closed) break;
                CGPoint current = [calculatedPoints[i % calculatedPoints.count] CGPointValue];
                CGPoint mid = CGPointMake((previous.x + current.x) / 2.0, (previous.y + current.y) / 2.0);
                CGPathAddQuadCurveToPoint(path, NULL, previous.x, previous.y, mid.x, mid.y);
                previous = current;
            }
        } else {
            for (NSUInteger i = 1; i < calculatedPoints.count; i++) {
                CGPoint p = [calculatedPoints[i] CGPointValue];
                CGPathAddLineToPoint(path, NULL, p.x, p.y);
            }
            if (closed) {
                CGPathAddLineToPoint(path, NULL, firstPoint.x, firstPoint.y);
            }
        }
        
        if (closed) {
            CGPathCloseSubpath(path);
        }
    }
    
    return path;
}

- (void)layoutCustomAnimated:(BOOL)animated {
    [CATransaction begin];
    [self setLayerActionsDisabled:YES animated:NO];
    
    _jelloLayer.hidden = YES;
    _jelloLayerMid.hidden = YES;
    _jelloLayerHigh.hidden = YES;
    
    NSArray *layersArray = _customShapeData[@"layers"];
    if (![layersArray isKindOfClass:[NSArray class]]) {
        layersArray = @[];
    }
    
    while (_customLayers.count < layersArray.count) {
        CAShapeLayer *newLayer = [CAShapeLayer layer];
        newLayer.frame = self.bounds;
        [_circleContainerLayer addSublayer:newLayer];
        [_customLayers addObject:newLayer];
    }
    while (_customLayers.count > layersArray.count) {
        CAShapeLayer *last = _customLayers.lastObject;
        [last removeFromSuperlayer];
        [_customLayers removeLastObject];
    }
    
    CGFloat mainAmplitudes[6];
    NSUInteger count = 6;
    for (NSUInteger i = 0; i < count; i++) {
        mainAmplitudes[i] = _amplitudes[i];
    }
    
    CGFloat opacity = MLClampCGFloat(_opacityPercent / 100.0, 0.05, 1.0);
    CGColorRef cgColor = MLColorWithAlpha(_tintColor, opacity).CGColor;
    
    for (NSUInteger i = 0; i < layersArray.count; i++) {
        NSDictionary *layerData = layersArray[i];
        if (![layerData isKindOfClass:[NSDictionary class]]) continue;
        
        CAShapeLayer *layer = _customLayers[i];
        layer.frame = self.bounds;
        layer.hidden = NO;
        
        id overrideData = layerData[@"overrideColor"];
        CGColorRef layerColor = cgColor;
        
        if ([overrideData isKindOfClass:[NSString class]]) {
            NSString *overrideStr = (NSString *)overrideData;
            if ([overrideStr isEqualToString:@"abundant"]) {
                layerColor = MLColorWithAlpha(_colorMode == 1 && _customColor ? _customColor : MLTintColor(), opacity).CGColor;
            } else {
                UIColor *layerBaseColor = MLTintColor();
                if (_colorMode == 1 && _customColor) {
                    layerBaseColor = _customColor;
                } else if (_colorMode == 2 && currentVibrancyColor) {
                    layerBaseColor = currentVibrancyColor;
                }
                
                if (i == 0) {
                    layerColor = MLColorWithAlpha(layerBaseColor, opacity).CGColor;
                } else {
                    UIColor *secColor = layerBaseColor;
                    if (_colorMode == 0) secColor = MLTintColor();
                    layerColor = MLColorWithAlpha(secColor, opacity).CGColor;
                }
            }
        } else if ([overrideData isKindOfClass:[NSArray class]]) {
            NSArray *colorArr = (NSArray *)overrideData;
            if (colorArr.count >= 4) {
                CGFloat r = [colorArr[0] doubleValue];
                CGFloat g = [colorArr[1] doubleValue];
                CGFloat b = [colorArr[2] doubleValue];
                CGFloat a = [colorArr[3] doubleValue];
                a = a * opacity;
                UIColor *customColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
                layerColor = customColor.CGColor;
            }
        }
        
        BOOL isOutline = [layerData[@"isOutline"] boolValue];
        if (isOutline) {
            layer.fillColor = [UIColor clearColor].CGColor;
            layer.strokeColor = layerColor;
            layer.lineWidth = [layerData[@"lineWidth"] doubleValue] ?: 2.0;
        } else {
            layer.fillColor = layerColor;
            layer.strokeColor = nil;
            layer.lineWidth = 0.0;
        }
        
        CGPathRef path = [self newCustomPathForAmplitudes:mainAmplitudes layerData:layerData count:count];
        
        CGFloat rotationSpeed = [layerData[@"rotationSpeed"] doubleValue];
        if (rotationSpeed != 0.0) {
            CGFloat currentAngle = _rotationAngle * rotationSpeed;
            CGAffineTransform transform = CGAffineTransformMakeTranslation(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
            transform = CGAffineTransformRotate(transform, currentAngle);
            transform = CGAffineTransformTranslate(transform, -self.bounds.size.width / 2.0, -self.bounds.size.height / 2.0);
            CGPathRef rotatedPath = CGPathCreateCopyByTransformingPath(path, &transform);
            layer.path = rotatedPath;
            CGPathRelease(rotatedPath);
        } else {
            layer.path = path;
        }
        
        CGPathRelease(path);
    }
    
    [CATransaction commit];
}

- (void)layoutBarsAnimated:(BOOL)animated {
    [CATransaction begin];
    [self setLayerActionsDisabled:YES animated:NO];
    
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    CGFloat maxWidth = width * (_barsSpacing / 100.0);
    if (maxWidth > width) maxWidth = width;
    
    CGFloat maxGap = maxWidth / 6.0;
    CGFloat mappedThickness = 55.0 + (_barsThickness - 5.0) * (45.0 / 95.0);
    
    CGFloat gap = maxGap * (1.0 - (mappedThickness / 100.0));
    CGFloat barWidth = (maxWidth - (gap * 5)) / 6.0;
    
    CGFloat globalScale = height * (_heightPercent / 100.0);
    
    CGFloat startX = (width - maxWidth) / 2.0;
    
    for (int i = 0; i < 6; i++) {
        CGFloat amp = _amplitudes[i] * globalScale;
        if (amp < barWidth) amp = barWidth;
        
        CGFloat x = startX + i * (barWidth + gap);
        CGFloat y = height - amp;
        
        _bars[i].frame = CGRectMake(x, y, barWidth, amp);
        _bars[i].cornerRadius = (barWidth / 2.0) * (_barsCornerRadius / 100.0);
        
        if (_barsRoundTopOnly) {
            _bars[i].maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        } else {
            _bars[i].maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        }
    }
    
    [CATransaction commit];
}


- (void)layoutWaveformAnimated:(BOOL)animated {
    [CATransaction begin];
    [self setLayerActionsDisabled:YES animated:NO];
    
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    CGFloat maxWidth = width * (_waveformSpacing / 100.0);
    if (maxWidth > width) maxWidth = width;
    
    CGFloat maxGap = maxWidth / 6.0;
    CGFloat mappedThickness = 55.0 + (_waveformThickness - 5.0) * (45.0 / 95.0);
    
    CGFloat gap = maxGap * (1.0 - (mappedThickness / 100.0));
    CGFloat barWidth = (maxWidth - (gap * 5)) / 6.0;
    
    CGFloat globalScale = height * (_heightPercent / 100.0);
    
    CGFloat startX = (width - maxWidth) / 2.0;
    
    for (int i = 0; i < 6; i++) {
        CGFloat amp = _amplitudes[i] * globalScale;
        if (amp < barWidth) amp = barWidth; 
        
        CGFloat x = startX + i * (barWidth + gap);
        CGFloat y = (height - amp) / 2.0;
        
        _bars[i].frame = CGRectMake(x, y, barWidth, amp);
        _bars[i].cornerRadius = (barWidth / 2.0) * (_waveformCornerRadius / 100.0);
        
        _bars[i].maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }
    
    [CATransaction commit];
}

- (void)layoutVisualizerAnimated:(BOOL)animated {
    _jelloLayer.hidden = YES;
    _jelloLayerMid.hidden = YES;
    _jelloLayerHigh.hidden = YES;

    for (CAShapeLayer *l in _customLayers) l.hidden = YES;
    for (int i = 0; i < 6; i++) {
        _bars[i].hidden = YES;
    }
    
    if (_visualizerStyle == 1) {
        _jelloLayer.hidden = NO;
        _jelloLayerMid.hidden = NO;
        if (_circleCount == 3) {
            _jelloLayerHigh.hidden = NO;
        }
        [self layoutCircleAnimated:animated];
    } else if (_visualizerStyle == 2 || _visualizerStyle == 4) {
        for (int i = 0; i < 6; i++) {
            _bars[i].hidden = NO;
        }
        if (_visualizerStyle == 4) {
            [self layoutWaveformAnimated:animated];
        } else {
            [self layoutBarsAnimated:animated];
        }
    } else if (_visualizerStyle == 3) {
        for (CAShapeLayer *l in _customLayers) l.hidden = NO;
        [self layoutCustomAnimated:animated];
    } else {
        _jelloLayer.hidden = NO;
        _jelloLayerMid.hidden = NO;
        _jelloLayerHigh.hidden = NO;
        [self layoutJelloAnimated:animated];
    }
}

- (void)setAmplitudesToZero {
    for (NSUInteger i = 0; i < 6; i++) {
        _amplitudes[i] = 0.0f;
    }
}

- (void)setTargetAmplitudesToZero {
    for (NSUInteger i = 0; i < 6; i++) {
        _targetAmplitudes[i] = 0.0f;
    }
}

- (void)displayLinkTick {
    BOOL changed = NO;
    CGFloat maxTarget = 0.0f;
    float shapedTargets[6];
    CGFloat amplitudeScale = _amplitudeLevel == 0 ? 0.52f : (_amplitudeLevel == 2 ? 1.18f : 0.8f);
    
    CGFloat allowedDiscrepancy = _amplitudeLevel == 0 ? 0.10f : (_amplitudeLevel == 2 ? 0.42f : 0.17f);
    CGFloat excessScale = _amplitudeLevel == 0 ? 0.12f : (_amplitudeLevel == 2 ? 0.75f : 0.24f);
    CGFloat chaseFactor = _amplitudeLevel == 0 ? 0.22f : (_amplitudeLevel == 2 ? 0.30f : 0.24f);

    for (NSUInteger i = 0; i < 6; i++) {
        NSUInteger previousIndex = i == 0 ? i : i - 1;
        NSUInteger nextIndex = i == 5 ? i : i + 1;
        float neighborAverage = (_targetAmplitudes[previousIndex] + _targetAmplitudes[nextIndex]) * 0.5f;
        float discrepancy = _targetAmplitudes[i] - neighborAverage;
        if (fabsf(discrepancy) > allowedDiscrepancy) {
            float sign = discrepancy < 0.0f ? -1.0f : 1.0f;
            float excess = fabsf(discrepancy) - allowedDiscrepancy;
            shapedTargets[i] = neighborAverage + (sign * (allowedDiscrepancy + (excess * excessScale)));
        } else {
            shapedTargets[i] = _targetAmplitudes[i];
        }
        shapedTargets[i] = MLClampCGFloat(shapedTargets[i] * amplitudeScale, 0.0f, 1.0f);
    }

    for (NSUInteger i = 0; i < 6; i++) {
        maxTarget = MAX(maxTarget, _targetAmplitudes[i]);
        float desired = shapedTargets[i];

        float delta = desired - _amplitudes[i];
        CGFloat framerateMultiplier = _framerate > 0 ? (60.0f / (CGFloat)_framerate) : 1.0f;
        CGFloat actualChaseFactor = MIN(chaseFactor * framerateMultiplier, 1.0f);

        if (fabsf(delta) > 0.0015f) {
            _amplitudes[i] += delta * actualChaseFactor;
            changed = YES;
        } else {
            _amplitudes[i] = desired;
        }
    }

    NSTimeInterval now = CACurrentMediaTime();
    NSTimeInterval dt = now - _lastUpdate;
    if (dt > 0.1) dt = 0.016; 
    _idleTime += dt;
    _lastUpdate = now;

    if (_visualizerStyle == 1 && _rotateCircle) {
        CGFloat mappedSpeed = (_circleRotationSpeed / 100.0) * 0.70;
        _rotationAngle += mappedSpeed * dt;
        changed = YES;
    } else if (_visualizerStyle == 2 || _visualizerStyle == 3 || _visualizerStyle == 4) {
        changed = YES; 
        _rotationAngle += dt; 
    }

    if (changed || self.alpha > 0.01f) {
        [self layoutVisualizerAnimated:NO];
    }

    if (!changed && maxTarget < 0.018f && _visualizerStyle != 2 && _visualizerStyle != 3 && _visualizerStyle != 4 && !(_visualizerStyle == 1 && _rotateCircle)) {
        _displayLink.paused = YES;
    }
}

- (void)ensureDisplayLink {
    if (_displayLink) return;

    MLDisplayLinkProxy *proxy = [MLDisplayLinkProxy proxyWithTarget:self];
    _displayLink = [CADisplayLink displayLinkWithTarget:proxy selector:@selector(displayLinkTick:)];
    if (@available(iOS 15.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(15, _framerate, _framerate);
    } else {
        _displayLink.preferredFramesPerSecond = _framerate;
    }
    _displayLink.paused = YES;
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(_displayLink, @selector(displayLinkTick:), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)updateWithPackedState:(uint64_t)packed {
    float maxAmplitude = 0.0f;
    for (NSUInteger i = 0; i < 6; i++) {
        float amplitude = (float)((packed >> (i * 8)) & 0xff) / 255.0f;
        _targetAmplitudes[i] = amplitude;
        if (amplitude > maxAmplitude) maxAmplitude = amplitude;
    }

    _lastUpdate = CACurrentMediaTime();
    BOOL shouldAnimateIn = self.alpha < 0.05f && maxAmplitude > 0.018f;
    if (shouldAnimateIn) {
        [self setAmplitudesToZero];
        [self layoutVisualizerAnimated:NO];
    }

    [self ensureDisplayLink];
    _displayLink.paused = NO;

    CGFloat targetAlpha = maxAmplitude > 0.018f ? 1.0f : 0.0f;
    
    if (fabs(self.alpha - targetAlpha) > 0.01f) {
        NSTimeInterval animDuration = _framerate < 30 ? 0.0 : 0.18;
        [UIView animateWithDuration:animDuration animations:^{
            self.alpha = targetAlpha;
        }];
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeIfStale) object:nil];
    [self performSelector:@selector(fadeIfStale) withObject:nil afterDelay:0.85];
}

- (void)loadCustomShapeJSON {
    NSString *path = @"/var/mobile/Library/Preferences/com.shalamand3r.jello.custom.json";
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            NSError *error = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!error && [json isKindOfClass:[NSDictionary class]]) {
                _customShapeData = json;
            }
        }
    }
}

- (void)reloadPreferences {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MLPrefsSuiteName];
    NSInteger amplitudeValue = [defaults integerForKey:MLAmplitudePreferenceKey];
    NSInteger nextAmplitudeLevel = amplitudeValue == 0 || amplitudeValue == 2 ? amplitudeValue : 1;
    CGFloat nextHeightPercent = [defaults doubleForKey:MLHeightPreferenceKey];
    if (nextHeightPercent <= 0.0) nextHeightPercent = 85.0;
    nextHeightPercent = round(nextHeightPercent / 5.0) * 5.0;
    nextHeightPercent = MLClampCGFloat(nextHeightPercent, 5.0, 100.0);
    CGFloat nextOpacityPercent = [defaults doubleForKey:MLOpacityPreferenceKey];
    if (nextOpacityPercent <= 0.0) nextOpacityPercent = 50.0;
    nextOpacityPercent = round(nextOpacityPercent / 10.0) * 10.0;
    nextOpacityPercent = MLClampCGFloat(nextOpacityPercent, 10.0, 100.0);
    
    CGFloat nextWaveformSpacing = [defaults doubleForKey:@"waveformSpacing"];
    if (nextWaveformSpacing <= 0.0) nextWaveformSpacing = 65.0;
    
    CGFloat nextWaveformThickness = [defaults doubleForKey:@"waveformThickness"];
    if (nextWaveformThickness <= 0.0) nextWaveformThickness = 80.0;
    
    CGFloat nextWaveformCornerRadius = [defaults doubleForKey:@"waveformCornerRadius"];
    if (nextWaveformCornerRadius <= 0.0 && [defaults objectForKey:@"waveformCornerRadius"] == nil) nextWaveformCornerRadius = 100.0;
    
    CGFloat nextBarsSpacing = [defaults doubleForKey:@"barsSpacing"];
    if (nextBarsSpacing <= 0.0) nextBarsSpacing = 100.0;
    
    CGFloat nextBarsThickness = [defaults doubleForKey:@"barsThickness"];
    if (nextBarsThickness <= 0.0) nextBarsThickness = 85.0;
    
    CGFloat nextBarsCornerRadius = [defaults doubleForKey:@"barsCornerRadius"];
    if (nextBarsCornerRadius <= 0.0 && [defaults objectForKey:@"barsCornerRadius"] == nil) nextBarsCornerRadius = 30.0;
    
    BOOL nextBarsRoundTopOnly = [defaults objectForKey:@"barsRoundTopOnly"] ? [defaults boolForKey:@"barsRoundTopOnly"] : YES;
    
    NSInteger styleValue = [defaults integerForKey:MLStylePreferenceKey];
    NSInteger nextVisualizerStyle = (styleValue >= 0 && styleValue <= 4) ? styleValue : 0;
    
    BOOL nextRotateCircle = [defaults objectForKey:@"rotateCircle"] ? [defaults boolForKey:@"rotateCircle"] : YES;
    CGFloat nextCircleRotationSpeed = [defaults objectForKey:@"circleRotationSpeed"] ? [defaults doubleForKey:@"circleRotationSpeed"] : 15.0;
    NSInteger nextCircleCount = [defaults objectForKey:@"circleCount"] ? [defaults integerForKey:@"circleCount"] : 3;
    BOOL nextCircleDynamicSize = [defaults objectForKey:@"circleDynamicSize"] ? [defaults boolForKey:@"circleDynamicSize"] : YES;
    CGFloat nextCircleSizePercent = [defaults objectForKey:@"circleSize"] ? [defaults doubleForKey:@"circleSize"] : 55.0;
    NSInteger nextCircleIntersectionStyle = [defaults objectForKey:@"circleIntersectionStyle"] ? [defaults integerForKey:@"circleIntersectionStyle"] : 1;
    NSInteger nextFramerate = [defaults objectForKey:@"framerate"] ? [defaults integerForKey:@"framerate"] : 60;
    
    if (nextFramerate < 15) nextFramerate = 15;
    NSInteger nextPollingRate = [defaults objectForKey:@"pollingRate"] ? [defaults integerForKey:@"pollingRate"] : 30;
    if (nextPollingRate <= 0) nextPollingRate = 1;
    else nextPollingRate = round(nextPollingRate / 5.0) * 5;

    BOOL nextEnabled = [defaults objectForKey:@"enabled"] ? [defaults boolForKey:@"enabled"] : YES;
    NSInteger nextColorMode = [defaults integerForKey:@"colorMode"];
    NSString *customColorHex = [defaults stringForKey:@"customColorHex"];
    UIColor *nextCustomColor = nil;
    if (nextColorMode == 1 && customColorHex) {
        nextCustomColor = MLColorFromHex(customColorHex);
    }

    BOOL amplitudeChanged = _amplitudeLevel != nextAmplitudeLevel;
    BOOL heightChanged = fabs(_heightPercent - nextHeightPercent) > 0.5;
    BOOL opacityChanged = fabs(_opacityPercent - nextOpacityPercent) > 0.5;
    BOOL styleChanged = _visualizerStyle != nextVisualizerStyle;
    BOOL rotateChanged = _rotateCircle != nextRotateCircle;
    BOOL colorChanged = (_colorMode != nextColorMode) || (_customColor != nextCustomColor && ![_customColor isEqual:nextCustomColor]);
    
    if (nextVisualizerStyle == 3) {
        [self loadCustomShapeJSON];
        styleChanged = YES; 
    }
    
    _amplitudeLevel = nextAmplitudeLevel;
    _heightPercent = nextHeightPercent;
    _opacityPercent = nextOpacityPercent;
    _visualizerStyle = nextVisualizerStyle;
    _rotateCircle = nextRotateCircle;
    _colorMode = nextColorMode;
    _customColor = nextCustomColor;
    _circleRotationSpeed = nextCircleRotationSpeed;
    _circleCount = nextCircleCount;
    _circleDynamicSize = nextCircleDynamicSize;
    _circleIntersectionStyle = nextCircleIntersectionStyle;
    _circleSizePercent = nextCircleSizePercent;

    
    if (_framerate != nextFramerate) {
        _framerate = nextFramerate;
        if (_displayLink) {
            if (@available(iOS 15.0, *)) {
                _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(15, _framerate, _framerate);
            } else {
                _displayLink.preferredFramesPerSecond = _framerate;
            }
        }
    }
    
    if (_pollingRate != nextPollingRate) {
        _pollingRate = nextPollingRate;
        int token;
        notify_register_check("com.shalamand3r.jello.pollingRate", &token);
        notify_set_state(token, _pollingRate);
        notify_post("com.shalamand3r.jello.pollingRate");
    }
    
    if (_visualizerStyle != 1 || _circleCount == 3) {
        _jelloLayerMid.hidden = NO;
        _jelloLayerHigh.hidden = NO;
    }
    
    _waveformSpacing = nextWaveformSpacing;
    _waveformThickness = nextWaveformThickness;
    _waveformCornerRadius = nextWaveformCornerRadius;
    _barsSpacing = nextBarsSpacing;
    _barsThickness = nextBarsThickness;
    _barsCornerRadius = nextBarsCornerRadius;
    _barsRoundTopOnly = nextBarsRoundTopOnly;

    if (opacityChanged || colorChanged) {
        [self updateTintColor:nil];
    }

    BOOL enabledChanged = _enabled != nextEnabled;
    _enabled = nextEnabled;
    
    if (enabledChanged) {
        self.hidden = !_enabled;
        if (!_enabled && _running) {
            [self stop];
        } else if (_enabled && !_running) {
            [self start];
        }
    }

    if (!amplitudeChanged && !heightChanged && !opacityChanged && !styleChanged && !rotateChanged && !enabledChanged && !colorChanged) {
        [self layoutVisualizerAnimated:NO];
        return;
    }

    [self layoutVisualizerAnimated:NO];
}

- (void)fadeIfStale {
    if (CACurrentMediaTime() - _lastUpdate < 0.80) return;
    [self setTargetAmplitudesToZero];
    [self ensureDisplayLink];
    _displayLink.paused = NO;
    [UIView animateWithDuration:0.28 animations:^{
        self.alpha = 0.0f;
    }];
}

- (void)start {
    if (!_enabled || _running) return;
    _running = YES;
    [self ensureDisplayLink];

    __weak typeof(self) weakSelf = self;
    notify_register_dispatch(MLWaveformNotifyName, &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        uint64_t packed = 0;
        notify_get_state(token, &packed);
        [weakSelf updateWithPackedState:packed];
    });

    if (_notifyToken != NOTIFY_TOKEN_INVALID) {
        uint64_t packed = 0;
        notify_get_state(_notifyToken, &packed);
        [self updateWithPackedState:packed];
    }
}

- (void)stop {
    if (!_running) return;
    _running = NO;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeIfStale) object:nil];
    [self setTargetAmplitudesToZero];
    [self ensureDisplayLink];
    _displayLink.paused = NO;
    if (_notifyToken != NOTIFY_TOKEN_INVALID) {
        notify_cancel(_notifyToken);
        _notifyToken = NOTIFY_TOKEN_INVALID;
    }
    NSTimeInterval animDuration = _framerate < 30 ? 0.0 : 0.20;
    [UIView animateWithDuration:animDuration animations:^{
        self.alpha = 0.0f;
    }];
}

@end

static MLWaveformView *MLVisualizerForController(UIViewController *controller) {
    return objc_getAssociatedObject(controller, &MLWaveformViewAssociationKey);
}

static void MLSetVisualizerForController(UIViewController *controller, MLWaveformView *visualizer) {
    objc_setAssociatedObject(controller, &MLWaveformViewAssociationKey, visualizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSInteger MLPlacementPreference(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MLPrefsSuiteName];
    return [defaults integerForKey:MLPlacementPreferenceKey] == 1 ? 1 : 0;
}

static void MLRegisterVisualizer(MLWaveformView *visualizer) {
    if (!visualizer) return;
    if (!MLActiveVisualizers) {
        MLActiveVisualizers = [NSHashTable weakObjectsHashTable];
    }
    [MLActiveVisualizers addObject:visualizer];
    [visualizer updateTintColor:nil];
}

static void MLAttachVisualizerToContainer(MLWaveformView *visualizer, UIView *container, CGFloat zPosition) {
    if (!visualizer || !container) return;
    visualizer.layer.zPosition = zPosition;
    if (visualizer.superview == container) {
        [container sendSubviewToBack:visualizer];
        return;
    }

    [visualizer removeFromSuperview];
    [container insertSubview:visualizer atIndex:0];
    [visualizer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor].active = YES;
    [visualizer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor].active = YES;
    [visualizer.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;
    [visualizer.topAnchor constraintEqualToAnchor:container.topAnchor].active = YES;
}

static void MLInstallLockscreenVisualizer(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class] || !controller.view) return;
    if (MLPlacementPreference() != 0) {
        [MLVisualizerForController(controller) stop];
        return;
    }

    UIView *container = controller.view.superview ?: controller.view;
    MLWaveformView *existing = MLVisualizerForController(controller);
    if (existing) {
        MLAttachVisualizerToContainer(existing, container, -1000.0);
        [existing start];
        return;
    }

    MLWaveformView *visualizer = [[MLWaveformView alloc] initWithFrame:CGRectZero];
    visualizer.translatesAutoresizingMaskIntoConstraints = NO;
    MLSetVisualizerForController(controller, visualizer);
    MLRegisterVisualizer(visualizer);

    MLAttachVisualizerToContainer(visualizer, container, -1000.0);

    [visualizer start];
    MLRefreshArtworkTint();
}

static void MLStopLockscreenVisualizer(UIViewController *controller) {
    [MLVisualizerForController(controller) stop];
}

static MLWaveformView *MLNowPlayingVisualizerForView(UIView *view) {
    return objc_getAssociatedObject(view, &MLNowPlayingWaveformViewAssociationKey);
}

static void MLSetNowPlayingVisualizerForView(UIView *view, MLWaveformView *visualizer) {
    objc_setAssociatedObject(view, &MLNowPlayingWaveformViewAssociationKey, visualizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void MLInstallNowPlayingVisualizer(UIView *view) {
    if (!view) return;
    if (MLPlacementPreference() != 1) {
        [MLNowPlayingVisualizerForView(view) stop];
        return;
    }

    MLWaveformView *existing = MLNowPlayingVisualizerForView(view);
    if (existing) {
        MLAttachVisualizerToContainer(existing, view, -100.0);
        [existing start];
        return;
    }

    MLWaveformView *visualizer = [[MLWaveformView alloc] initWithFrame:CGRectZero];
    visualizer.translatesAutoresizingMaskIntoConstraints = NO;
    MLSetNowPlayingVisualizerForView(view, visualizer);
    MLRegisterVisualizer(visualizer);

    MLAttachVisualizerToContainer(visualizer, view, -100.0);
    [visualizer start];
    MLRefreshArtworkTint();
}



%hook CSActivityItemContentView

- (void)layoutSubviews {
    %orig;
    MLInstallNowPlayingVisualizer((UIView *)self);
}

%end

%hook CSFixedFooterViewController

- (void)viewDidLoad {
    %orig;
    MLInstallLockscreenVisualizer(self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    MLInstallLockscreenVisualizer(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MLInstallLockscreenVisualizer(self);
    
}



- (void)viewDidDisappear:(BOOL)animated {
    MLStopLockscreenVisualizer(self);
    %orig;
}

%end

%hook SBMediaController

- (void)setNowPlayingInfo:(NSDictionary *)info {
    %orig;
    MLUpdateArtworkTintFromNowPlayingInfo(info);
    MLRefreshArtworkTint();
}

%end

%hook CSCoverSheetViewController
- (void)setVibrancyConfiguration:(id)config {
    %orig;
    if ([config respondsToSelector:@selector(color)]) {
        currentVibrancyColor = [config performSelector:@selector(color)];
        MLRefreshArtworkTint();
    }
}
%end
