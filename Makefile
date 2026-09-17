ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PowerButtonHooks
PowerButtonHooks_FILES = Tweak.xm
PowerButtonHooks_CFLAGS = -fobjc-arc
PowerButtonHooks_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
