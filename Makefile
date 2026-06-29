TARGET := iphone:clang:latest:14.0
INSTALL_ARCH_PROCESSES = arm64 arm64e
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

# --------------------------------------------------------------------------- #
# Tweak                                                                       #
# --------------------------------------------------------------------------- #
TWEAK_NAME = SkipSilenceYT

SkipSilenceYT_FILES = \
	Sources/SkipSilenceTweak/Tweak.x \
	Sources/SkipSilenceTweak/SSVoiceBoostState.c \
	Sources/SkipSilenceTweak/SSLUFS.c \
	Sources/SkipSilenceTweak/SSSilenceDetector.m \
	Sources/SkipSilenceTweak/SSSmartSpeedController.m \
	Sources/SkipSilenceTweak/SSAudioTap.m \
	Sources/SkipSilenceTweak/SSPrefs.m

SkipSilenceYT_CFLAGS = -fobjc-arc -Wno-deprecated-declarations \
                       -Wno-unused-variable -Wno-unused-function \
                       -I./Sources/SkipSilenceTweak
SkipSilenceYii_FRAMEWORKS = AVFoundation AudioToolbox MediaToolbox CoreMedia
SkipSilenceYT_FRAMEWORKS = AVFoundation AudioToolbox MediaToolbox CoreMedia
SkipSilenceYT_LDFLAGS = -framework AVFoundation -framework AudioToolbox \
                        -framework MediaToolbox -framework CoreMedia

include $(THEOS_MAKE_PATH)/tweak.mk

# --------------------------------------------------------------------------- #
# Preferences bundle                                                          #
# --------------------------------------------------------------------------- #
BUNDLE_NAME = SkipSilencePrefs

SkipSilencePrefs_FILES = \
	Sources/SkipSilencePrefs/SSPrefsRootController.m \
	Sources/SkipSilencePrefs/SSPrefsSwitchCell.m

SkipSilencePrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SkipSilencePrefs_FRAMEWORKS = UIKit
SkipSilencePrefs_PRIVATE_FRAMEWORKS = Preferences
SkipSilencePrefs_INSTALL_PATH = /Library/PreferenceBundles

# Bundle the Root.plist as a resource inside the preference bundle.
SkipSilencePrefs_BUNDLE_RESOURCES = layouts/Root.plist

include $(THEOS_MAKE_PATH)/bundle.mk

# --------------------------------------------------------------------------- #
# PreferenceLoader entry                                                      #
# --------------------------------------------------------------------------- #
after-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp $(THEOS_PROJECT_DIR)/SkipSilenceYT.entry.plist \
	    $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SkipSilence.plist$(ECHO_END)
