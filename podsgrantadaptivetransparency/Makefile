TARGET := iphone:clang:latest:13.0
ARCHS := arm64e arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = podsgrantadaptivetransparency

podsgrantadaptivetransparency_FILES = Tweak.x
podsgrantadaptivetransparency_CFLAGS = -fobjc-arc
podsgrantadaptivetransparency_PRIVATE_FRAMEWORKS = PersonalAudio

include $(THEOS_MAKE_PATH)/tweak.mk
