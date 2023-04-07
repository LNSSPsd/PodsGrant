TARGET := iphone:clang:latest:7.0
ARCHS := arm64e arm64
INSTALL_TARGET_PROCESSES = bluetoothd


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PodsGrant

PodsGrant_FILES = Tweak.x Sharing_Tweak.x
PodsGrant_CFLAGS = -fobjc-arc

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	PodsGrant_CFLAGS = -fobjc-arc -DIS_ROOTLESS=1
endif

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
