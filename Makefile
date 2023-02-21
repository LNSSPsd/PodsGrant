TARGET := iphone:clang:latest:7.0
ARCHS := arm64e
INSTALL_TARGET_PROCESSES = bluetoothd


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PodsGrant

PodsGrant_FILES = Tweak.x
PodsGrant_LIBRARIES = rocketbootstrap
PodsGrant_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += podsgrantsbvolumechanger
SUBPROJECTS += podsgrantsharingdhook
include $(THEOS_MAKE_PATH)/aggregate.mk
