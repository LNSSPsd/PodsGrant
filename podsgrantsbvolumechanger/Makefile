TARGET := iphone:clang:latest:7.0
ARCHS := arm64e
#INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PodsGrantSBVolumeChanger

PodsGrantSBVolumeChanger_FILES = Tweak.x
PodsGrantSBVolumeChanger_LIBRARIES = rocketbootstrap
PodsGrantSBVolumeChanger_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
