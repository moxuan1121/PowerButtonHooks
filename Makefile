ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PowerButton
PowerButton_FILES = Tweak.xm
PowerButton_CFLAGS = -fobjc-arc
PowerButton_FRAMEWORKS = UIKit AVFoundation
PowerButton_LIBRARIES = roothide

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
