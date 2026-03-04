# GNUmakefile for SmallCal (Linux/GNUstep)
#
# Calendar app with .ics and CalDAV support. Uses SmallStepLib for app
# lifecycle, menus, window style, and file dialogs.
#
# Build SmallStepLib first: cd ../SmallStepLib && make && make install
# Then: make

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = SmallCal

SmallCal_OBJC_FILES = \
	main.m \
	App/AppDelegate.m \
	UI/CalendarWindow.m \
	Model/ICalEvent.m \
	Model/ICalParser.m \
	Model/CalDAVClient.m

SmallCal_HEADER_FILES = \
	App/AppDelegate.h \
	UI/CalendarWindow.h \
	Model/ICalEvent.h \
	Model/ICalParser.h \
	Model/CalDAVClient.h

SmallCal_INCLUDE_DIRS = \
	-I. \
	-IApp \
	-IUI \
	-IModel \
	-I../SmallStepLib/SmallStep/Core \
	-I../SmallStepLib/SmallStep/Platform/Linux

# SmallStep framework (from SmallStepLib)
SMALLSTEP_FRAMEWORK := $(shell find ../SmallStepLib -name "SmallStep.framework" -type d 2>/dev/null | head -1)
ifneq ($(SMALLSTEP_FRAMEWORK),)
  SMALLSTEP_LIB_DIR := $(shell cd $(SMALLSTEP_FRAMEWORK)/Versions/0 2>/dev/null && pwd)
  SMALLSTEP_LIB_PATH := -L$(SMALLSTEP_LIB_DIR)
  SMALLSTEP_LDFLAGS := -Wl,-rpath,$(SMALLSTEP_LIB_DIR)
else
  SMALLSTEP_LIB_PATH :=
  SMALLSTEP_LDFLAGS :=
endif

SmallCal_LIBRARIES_DEPEND_UPON = -lobjc -lgnustep-gui -lgnustep-base
SmallCal_LDFLAGS = $(SMALLSTEP_LIB_PATH) $(SMALLSTEP_LDFLAGS) -Wl,--allow-shlib-undefined
SmallCal_ADDITIONAL_LDFLAGS = $(SMALLSTEP_LIB_PATH) $(SMALLSTEP_LDFLAGS) -lSmallStep
SmallCal_TOOL_LIBS = -lSmallStep -lobjc

include $(GNUSTEP_MAKEFILES)/application.make
