ARCHS = arm64e
TARGET = iphone:clang:16.5:17.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HideAllApps
HideAllApps_FILES = Tweak.x HAAManager.m HAAGestureManager.m
HideAllApps_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
HideAllApps_FRAMEWORKS = UIKit Foundation
HideAllApps_PRIVATE_FRAMEWORKS = SpringBoardUI SpringBoardFoundation
HideAllApps_CODESIGN_FLAGS = -SHideAllApps.entitlements
include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = HideAllAppsPrefs
HideAllAppsPrefs_FILES = Preferences/HAARootListController.m
HideAllAppsPrefs_FILES += Preferences/HAAAppPickerController.m
HideAllAppsPrefs_INSTALL_PATH = /Library/PreferenceBundles
HideAllAppsPrefs_FRAMEWORKS = UIKit
HideAllAppsPrefs_PRIVATE_FRAMEWORKS = Preferences
HideAllAppsPrefs_CFLAGS = -
