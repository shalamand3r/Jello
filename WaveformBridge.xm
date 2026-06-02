#import <Foundation/Foundation.h>
#import <math.h>
#import <notify.h>

@interface MRUWaveformData : NSObject
- (NSArray *)amplitudes;
@end

static const char *MLWaveformNotifyName = "com.shalamand3r.jello.waveform";

static int MLWaveformNotifyToken = NOTIFY_TOKEN_INVALID;
static NSTimeInterval MLLastPublishTime = 0.0;
static double MLPollingRate = 30.0;



static void MLReloadPreferences(void) {
    int token;
    notify_register_check("com.shalamand3r.jello.pollingRate", &token);
    uint64_t rate = 0;
    notify_get_state(token, &rate);
    
    if (rate >= 1 && rate <= 60) {
        MLPollingRate = (double)rate;
    } else {
        MLPollingRate = 30.0;
    }
}

static void MLPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    MLReloadPreferences();
}

static uint8_t MLQuantizedAmplitude(id value) {
    float amplitude = 0.0f;
    if ([value respondsToSelector:@selector(floatValue)]) {
        amplitude = [value floatValue];
    }

    if (amplitude < 0.0f) amplitude = 0.0f;
    if (amplitude > 1.0f) amplitude = 1.0f;
    return (uint8_t)lrintf(amplitude * 255.0f);
}

static uint64_t MLPackedAmplitudes(MRUWaveformData *waveformData) {
    NSArray *amplitudes = nil;
    if ([waveformData respondsToSelector:@selector(amplitudes)]) {
        amplitudes = [waveformData amplitudes];
    }
    if (![amplitudes isKindOfClass:NSArray.class] || amplitudes.count == 0) return 0;

    uint64_t packed = 0;
    NSUInteger count = MIN((NSUInteger)6, amplitudes.count);
    for (NSUInteger i = 0; i < count; i++) {
        packed |= ((uint64_t)MLQuantizedAmplitude(amplitudes[i])) << (i * 8);
    }
    return packed;
}

static void MLPublishWaveformData(MRUWaveformData *waveformData) {
    if (MLWaveformNotifyToken == NOTIFY_TOKEN_INVALID) {
        notify_register_check(MLWaveformNotifyName, &MLWaveformNotifyToken);
    }
    if (MLWaveformNotifyToken == NOTIFY_TOKEN_INVALID) return;

    uint64_t packed = MLPackedAmplitudes(waveformData);
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval minimumInterval = 1.0 / MLPollingRate;
    if (packed != 0 && MLLastPublishTime > 0.0 && now - MLLastPublishTime < minimumInterval) {
        return;
    }

    MLLastPublishTime = now;
    notify_set_state(MLWaveformNotifyToken, packed);
    notify_post(MLWaveformNotifyName);
}

%hook MRUWaveformController

- (void)audioAnalyzer:(id)audioAnalyzer didUpdateWaveform:(MRUWaveformData *)waveformData {
    MLPublishWaveformData(waveformData);
    %orig;
}

- (void)setWaveform:(MRUWaveformData *)waveformData {
    MLPublishWaveformData(waveformData);
    %orig;
}

%end

%ctor {
    MLReloadPreferences();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    MLPrefsChanged,
                                    CFSTR("com.shalamand3r.jello.pollingRate"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    notify_register_check(MLWaveformNotifyName, &MLWaveformNotifyToken);
}
