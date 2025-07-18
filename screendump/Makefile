TARGET = iphone:16.5:10.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = screendumpd
export ARCHS = arm64
$(TOOL_NAME)_ARCHS = arm64
$(TOOL_NAME)_FILES = main.mm
$(TOOL_NAME)_FRAMEWORKS := IOSurface IOKit
$(TOOL_NAME)_PRIVATE_FRAMEWORKS := IOMobileFramebuffer IOSurface
$(TOOL_NAME)_OBJCFLAGS += -Ivncbuild/include -Iinclude
$(TOOL_NAME)_LDFLAGS += -Wl,-segalign,4000 -Lvncbuild/lib  -lvncserver -lpng -llzo2 -ljpeg -lssl -lcrypto -lz
$(TOOL_NAME)_CFLAGS = -w
$(TOOL_NAME)_CODESIGN_FLAGS = "-Sen.plist"
$(TOOL_NAME)_INSTALL_PATH = /usr/libexec


include $(THEOS_MAKE_PATH)/tool.mk
