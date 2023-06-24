TARGET := iphone:clang:latest:7.0
ARCHS := arm64e arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = podsgrantsettings

podsgrantsettings_FILES = ../general.c PGSRootListController.m PGSProductIDMappingController.m PGSProductIDEditingViewController.m PGSSelectTargetProductIDViewController.m PGSCreditsViewController.m
//podsgrantsettings_FRAMEWORKS = UIKit
//podsgrantsettings_PRIVATE_FRAMEWORKS = Preferences
podsgrantsettings_INSTALL_PATH = /Library/PreferenceBundles
podsgrantsettings_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
