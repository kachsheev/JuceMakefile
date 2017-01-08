MAKEFILE_PATH := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
# Detecting OS
ifeq ($(OS),)

endif

ifneq ($(AR),)
	AR = ar
endif

BUILD_PATH = $(MAKEFILE_PATH)/build
SRC_PATH = $(MAKEFILE_PATH)/juce/modules
INCLUDE_PATH = $(SRC_PATH)

ifeq ($(config),)
	config = RELEASE
endif
ifeq ($(config),DEBUG)
	LIB_PATH = $(BUILD_PATH)/debug/lib
	OBJ_PATH = $(BUILD_PATH)/debug/obj
	FLAGS = -Og
endif
ifeq ($(config),RELEASE)
	LIB_PATH = $(BUILD_PATH)/release/lib
	OBJ_PATH = $(BUILD_PATH)/release/obj
	FLAGS = -O3
endif

# Build config
CXX_FLAGS = \
	$(FLAGS) \
	-std=c++14 -lGL -ldl -lpthread -lrt \
	-I$(INCLUDE_PATH) \
	-DLINUX=1 \
	-DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1 \
	$(shell pkg-config --cflags alsa freetype2 libcurl x11 xext xinerama) \
	$(shell pkg-config --libs alsa freetype2 libcurl x11 xext xinerama)

SOURCES = $(shell ls $(SRC_PATH)/*/*.cpp | grep -v audio_plugin_client)
OBJECTS = $(foreach source, $(SOURCES), $(addprefix $(OBJ_PATH)/, $(subst $(SRC_PATH)/,,$(source:.cpp=.o))))
SHARED_OBJECTS = $(OBJECTS:.o=_shared.o)
STATIC_OBJECTS = $(OBJECTS:.o=_static.o)

LOCAL_SHARED_LIBS = $(OBJECTS:.o=.so)
LOCAL_STATIC_LIBS = $(OBJECTS:.o=.a)
LOCAL_LIBS = $(LOCAL_SHARED_LIBS) $(LOCAL_STATIC_LIBS)

SHARED_LIBS = $(addprefix $(LIB_PATH)/,$(notdir $(LOCAL_SHARED_LIBS)))
STATIC_LIBS = $(addprefix $(LIB_PATH)/,$(notdir $(LOCAL_STATIC_LIBS)))
LIBS = $(SHARED_LIBS) $(STATIC_LIBS)

all: shared static
	for file in $(LOCAL_LIBS); do \
		cp $$file $(LIB_PATH); \
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
	$(CXX) -fpic $(CXX_FLAGS) -c $^ -o $@

$(OBJ_PATH)/%_static.o: $(SRC_PATH)/%.cpp
	$(CXX) $(CXX_FLAGS) -c $^ -o $@

$(OBJ_PATH)/%.so: $(OBJ_PATH)/%_shared.o
	$(CXX) -shared -o $@ $^

$(OBJ_PATH)/%.a: $(OBJ_PATH)/%_static.o
	$(AR) rc $@ $^
