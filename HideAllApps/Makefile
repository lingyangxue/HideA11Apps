ARCHS = arm64
TARGET = iphone:clang:16.5:17.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = HideAllAppsPrefs
HideAllAppsPrefs_FILES = HAARootListController.m HAAAppPickerController.m
HideAllAppsPrefs_INSTALL_PATH = /Library/PreferenceBundles
HideAllAppsPrefs_FRAMEWORKS = UIKit
HideAllAppsPrefs_PRIVATE_FRAMEWORKS = Preferences
HideAllAppsPrefs_CFLAGS = -fobjc-arc -fno-modules -Wno-everything
HideAllAppsPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
