# To use another compiler, such clang++, set the CXX variable
# CXX=clang++

# Out-of-source build support
BUILD_DIR ?= ./build

# variables used to generate a source snapshot of the GIT repo
COMMIT=$(shell git log --pretty=format:'%H' -n 1)
SHORT_COMMIT=$(shell git log --pretty=format:'%h' -n 1)
CXXFLAGS=-fPIC -pipe -std=c++11 -O2 -Iapi -Icli
TARGET=$(BUILD_DIR)/pict
TARGET_LIB_SO=$(BUILD_DIR)/libpict.so
TARGET_LIB_DYLIB=$(BUILD_DIR)/libpict.dylib
TEST_OUTPUT = $(BUILD_DIR)/test/rel.log $(BUILD_DIR)/test/rel.log.failures $(BUILD_DIR)/test/dbg.log
TEST_OUTPUT += $(BUILD_DIR)/test/.stdout $(BUILD_DIR)/test/.stderr

# Object files in build dir
OBJS = $(OBJS_API) $(OBJS_CLI)
OBJS_API = $(BUILD_DIR)/api/combination.o $(BUILD_DIR)/api/deriver.o $(BUILD_DIR)/api/exclusion.o
OBJS_API += $(BUILD_DIR)/api/model.o $(BUILD_DIR)/api/parameter.o $(BUILD_DIR)/api/pictapi.o
OBJS_API += $(BUILD_DIR)/api/task.o $(BUILD_DIR)/api/worklist.o
OBJS_CLI = $(BUILD_DIR)/cli/ccommon.o $(BUILD_DIR)/cli/cmdline.o
OBJS_CLI += $(BUILD_DIR)/cli/common.o $(BUILD_DIR)/cli/cparser.o $(BUILD_DIR)/cli/ctokenizer.o $(BUILD_DIR)/cli/gcd.o
OBJS_CLI += $(BUILD_DIR)/cli/gcdexcl.o $(BUILD_DIR)/cli/gcdmodel.o $(BUILD_DIR)/cli/model.o $(BUILD_DIR)/cli/mparser.o
OBJS_CLI += $(BUILD_DIR)/cli/pict.o $(BUILD_DIR)/cli/strings.o
IMAGE := pict:latest


# Pattern rule for compiling source to build dir
$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(CXX) $(OBJS) -o $@


$(TARGET_LIB_SO): $(OBJS)
	$(CXX) -fPIC -shared $(OBJS) -o $@

$(TARGET_LIB_DYLIB): $(OBJS)
	$(CXX) -dynamiclib $(OBJS) -o $@ -install_name @rpath/libpict.dylib


test: $(TARGET)
	cd test; perl test.pl ../$(TARGET) rel.log


clean:
	rm -f $(TARGET) $(TARGET_LIB_SO) $(TEST_OUTPUT) $(OBJS)
	rm -rf $(BUILD_DIR)


all: $(TARGET) $(TARGET_LIB_SO) $(TARGET_LIB_DYLIB)	


source: clean
	git archive --prefix="pict-$(COMMIT)/" -o "pict-$(SHORT_COMMIT).tar.gz" $(COMMIT)


.PHONY: all test clean source


image-build:
	@podman build --layers=true -t $(IMAGE) .


image-run:
	@podman run -it --rm -v ./doc/sample-models:/var/pict:Z $(IMAGE) create_volume.txt

build-lib:
	podman build --no-cache -t pict:lib-builder -f Containerfile.build
	@mkdir -p ./build
	podman run --rm pict:lib-builder ls -l /tmp/pict/build/
	podman run --rm -v $(CURDIR)/build:/build_out pict:lib-builder cp /tmp/pict/build/api/libpict.so /build_out/libpict.so

# Darwin (macOS) specific adjustments
ifeq ($(shell uname -s),Darwin)
    # Ensure arm64 target if on Apple Silicon
    ifeq ($(shell uname -m),arm64)
        CXXFLAGS += -target arm64-apple-macos11
    endif
    # Optional: ensure the dylib target is part of 'all' if not already
endif