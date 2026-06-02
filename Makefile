export THEOS_PACKAGE_SCHEME = rootless
export TARGET = iphone:16.5:15.0
export ARCHS = arm64 arm64e

FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = JelloWaveform JelloLockscreen
BUNDLE_NAME = JelloPrefs

JelloWaveform_FILES = WaveformBridge.xm
JelloWaveform_CFLAGS = -fobjc-arc

JelloLockscreen_FILES = Lockscreen.xm
JelloLockscreen_FRAMEWORKS = UIKit QuartzCore
JelloLockscreen_PRIVATE_FRAMEWORKS = MediaRemote
JelloLockscreen_CFLAGS = -fobjc-arc

JelloPrefs_FILES = JelloPrefs/AMRootListController.m JelloPrefs/JelloLayoutPickerCell.m
JelloPrefs_INSTALL_PATH = /Library/PreferenceBundles
JelloPrefs_FRAMEWORKS = UIKit
JelloPrefs_PRIVATE_FRAMEWORKS = Preferences
JelloPrefs_CFLAGS = -fobjc-arc
JelloPrefs_RESOURCE_DIRS = JelloPrefs/Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp JelloPrefs/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/JelloPrefs.plist$(ECHO_END)
