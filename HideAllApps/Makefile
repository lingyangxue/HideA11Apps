ARCHS = arm64
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
HideAllAppsPrefs_FILES = Preferences/HAARootListController.m Preferences/HAAAppPickerController.m
HideAllAppsPrefs_INSTALL_PATH = /Library/PreferenceBundles
HideAllAppsPrefs_FRAMEWORKS = UIKit
HideAllAppsPrefs_PRIVATE_FRAMEWORKS = Preferences
HideAllAppsPrefs_CFLAGS = -fobjc-arc -fno-modules -Wno-everything
HideAllAppsPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard"
