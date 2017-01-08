MAKEFILE_PATH := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))

# Detecting OS
ifeq ($(OS),Windows_NT)
	OS_DETECT := Windows
else
	OS_DETECT := $(shell uname -s)
endif

ifeq ($(OS_DETECT), Windows)
	SHARED_LIB_SUFFIX = dll
	STATIC_LIB_SUFFIX = lib
endif

ifeq ($(OS_DETECT), Linux)
	SHARED_LIB_SUFFIX = so
	STATIC_LIB_SUFFIX = a
endif

ifneq ($(AR),)
	AR = ar
endif

BUILD_PATH = $(MAKEFILE_PATH)/build
SRC_PATH = $(MAKEFILE_PATH)/juce/modules
INCLUDE_PATH = $(SRC_PATH)

JUCE_LIBS = \
		alsa \
		freetype2 \
		libcurl \
		x11 \
		xext \
		xinerama \
		gl \
		zlib

JUCE_DEFINES = \
	-DLINUX=1 \
	-DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1

ifeq ($(config),)
	config = RELEASE
endif
ifeq ($(config),DEBUG)
	LIB_PATH = $(BUILD_PATH)/debug/lib
	OBJ_PATH = $(BUILD_PATH)/debug/obj
	FLAGS = -O0 -g -ggdb
	JUCE_DEFINES +=  -DDEBUG=1 -D_DEBUG=1
endif
ifeq ($(config),RELEASE)
	LIB_PATH = $(BUILD_PATH)/release/lib
	OBJ_PATH = $(BUILD_PATH)/release/obj
	FLAGS = -O3
	JUCE_DEFINES += -DDEBUG=0 -DNDEBUG=1
endif

# Build config
CXX_FLAGS = \
	$(FLAGS) \
	-fpermissive \
	-std=c++14 -lpthread \
	-I$(INCLUDE_PATH) \
	$(JUCE_DEFINES) \
	$(shell pkg-config --cflags $(JUCE_LIBS)) \
	$(shell pkg-config --libs $(JUCE_LIBS))

SOURCES = $(shell ls $(SRC_PATH)/*/*.cpp | grep -v audio_plugin_client)
OBJECTS = $(foreach source,$(SOURCES),$(addprefix $(OBJ_PATH)/, $(subst $(SRC_PATH)/,,$(source:.cpp=.o))))
SHARED_OBJECTS = $(OBJECTS:.o=_shared.o)
STATIC_OBJECTS = $(OBJECTS:.o=_static.o)

LOCAL_SHARED_LIBS = $(OBJECTS:.o=.$(SHARED_LIB_SUFFIX))
LOCAL_STATIC_LIBS = $(OBJECTS:.o=.$(STATIC_LIB_SUFFIX))
LOCAL_LIBS = $(LOCAL_SHARED_LIBS) $(LOCAL_STATIC_LIBS)

SHARED_LIBS = $(addprefix $(LIB_PATH)/lib,$(notdir $(LOCAL_SHARED_LIBS)))
STATIC_LIBS = $(addprefix $(LIB_PATH)/lib,$(notdir $(LOCAL_STATIC_LIBS)))
LIBS = $(SHARED_LIBS) $(STATIC_LIBS)

all: shared static
	@for file in $(LOCAL_LIBS); do \
		if [ ! -f $(LIB_PATH)/lib`basename $$file` ]; \
		then \
			echo Copying lib`basename $$file` to $(LIB_PATH); \
			cp $$file $(LIB_PATH)/lib`basename $$file`; \
		else \
			echo Exist: lib`basename $$file`; \
		fi \
	done

clean: .rm_build_dir

.PHONY: clean

# ----------

shared: .make_build_dir $(SHARED_OBJECTS) $(LOCAL_SHARED_LIBS)

static: .make_build_dir $(STATIC_OBJECTS) $(LOCAL_STATIC_LIBS)

# ----------

.make_build_dir:
	@mkdir -p $(shell dirname $(OBJECTS)) 
	@mkdir -p $(LIB_PATH)

.rm_build_dir:
	@rm -rf $(BUILD_PATH)

# ----------

$(OBJ_PATH)/%_shared.o: $(SRC_PATH)/%.cpp
	$(CXX) -fpic -DJUCE_DLL_BUILD=1 $(CXX_FLAGS) -c $^ -o $@

$(OBJ_PATH)/%_static.o: $(SRC_PATH)/%.cpp
	$(CXX) $(CXX_FLAGS) -c $^ -o $@

$(OBJ_PATH)/%.$(SHARED_LIB_SUFFIX): $(OBJ_PATH)/%_shared.o
	$(CXX) -shared -o $@ $^

$(OBJ_PATH)/%.$(STATIC_LIB_SUFFIX): $(OBJ_PATH)/%_static.o
	$(AR) rc $@ $^
