TARGET := iphone:clang:latest:7.0
ARCHS := arm64e
INSTALL_TARGET_PROCESSES = sharingd


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PodsGrantSharingDHook

PodsGrantSharingDHook_FILES = Tweak.x
PodsGrantSharingDHook_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
