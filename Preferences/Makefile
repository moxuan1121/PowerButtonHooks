ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PowerButtonHooksPreferences
PowerButtonHooksPreferences_FILES = PBHRootListController.m
PowerButtonHooksPreferences_CFLAGS = -fobjc-arc
PowerButtonHooksPreferences_FRAMEWORKS = UIKit
PowerButtonHooksPreferences_PRIVATE_FRAMEWORKS = Preferences
PowerButtonHooksPreferences_INSTALL_PATH = /Library/PreferenceBundles
PowerButtonHooksPreferences_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
