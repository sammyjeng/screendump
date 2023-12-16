TARGET = iphone:16.5:14.0

include $(THEOS)/makefiles/common.mk


TWEAK_NAME = screendumpbb
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_FRAMEWORKS := IOSurface IOKit
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS := IOMobileFramebuffer IOSurface

ADDITIONAL_OBJCFLAGS += -I../vncbuild/include -Iinclude
ADDITIONAL_LDFLAGS += -Wl,-segalign,4000
ADDITIONAL_CFLAGS = -w

export ARCHS = arm64
$(TWEAK_NAME)_ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk
