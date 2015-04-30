# This file is the top android makefile for all sub-modules.

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

json_c_TOP := $(LOCAL_PATH)

JSON_C_BUILT_SOURCES := Android.mk

JSON_C_BUILT_SOURCES := $(patsubst %, $(abspath $(json_c_TOP))/%, $(JSON_C_BUILT_SOURCES))

.PHONY: json-c-configure json-c-configure-real
json-c-configure-real:
	echo $(JSON_C_BUILT_SOURCES)
	cd $(json_c_TOP) ; \
	$(abspath $(json_c_TOP))/autogen.sh && \
	CC="$(CONFIGURE_CC)" \
	CFLAGS="$(CONFIGURE_CFLAGS)" \
	LD=$(TARGET_LD) \
	LDFLAGS="$(CONFIGURE_LDFLAGS)" \
	CPP=$(CONFIGURE_CPP) \
	CPPFLAGS="$(CONFIGURE_CPPFLAGS)" \
	PKG_CONFIG_LIBDIR=$(CONFIGURE_PKG_CONFIG_LIBDIR) \
	PKG_CONFIG_TOP_BUILD_DIR=/ \
	ac_cv_func_malloc_0_nonnull=yes \
	ac_cv_func_realloc_0_nonnull=yes \
	$(abspath $(json_c_TOP))/$(CONFIGURE) --host=$(CONFIGURE_HOST) \
	--prefix=/system \
	&& \
	for file in $(JSON_C_BUILT_SOURCES); do \
		rm -f $$file && \
		make -C $$(dirname $$file) $$(basename $$file) ; \
	done

json-c-configure: json-c-configure-real

PA_CONFIGURE_TARGETS += json-c-configure

-include $(json_c_TOP)/Android.mk
