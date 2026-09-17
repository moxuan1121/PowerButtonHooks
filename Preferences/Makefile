ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.6
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PowerButtonPreferences
PowerButtonPreferences_FILES = PBHRootListController.m
PowerButtonPreferences_CFLAGS = -fobjc-arc
PowerButtonPreferences_FRAMEWORKS = UIKit
PowerButtonPreferences_PRIVATE_FRAMEWORKS = Preferences
PowerButtonPreferences_INSTALL_PATH = /Library/PreferenceBundles
PowerButtonPreferences_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
