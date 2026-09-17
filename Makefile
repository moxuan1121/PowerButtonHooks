ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.6
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PowerButtonHooks
PowerButtonHooks_FILES = Tweak.xm
PowerButtonHooks_CFLAGS = -fobjc-arc
PowerButtonHooks_FRAMEWORKS = UIKit AVFoundation
PowerButtonHooks_PRIVATE_FRAMEWORKS = MediaRemote

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
