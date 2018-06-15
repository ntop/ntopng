BASE_DIR := ../api/lua_c
NTOP_BASE_DIR := $(BASE_DIR)/ntop
INTERFACE_BASE_DIR := $(BASE_DIR)/interface

all:
	#grep "//Lua" ../../../src/Lua.cpp | sed -e 's/^[[:space:]]*\/\/Lua //' > api.lua.cpp
	./lua2dox $(INTERFACE_BASE_DIR)/interface_misc.lua > $(INTERFACE_BASE_DIR)/interface_misc.lua.cpp
	./lua2dox $(INTERFACE_BASE_DIR)/interface_flows.lua > $(INTERFACE_BASE_DIR)/interface_flows.lua.cpp
	./lua2dox $(INTERFACE_BASE_DIR)/interface_hosts.lua > $(INTERFACE_BASE_DIR)/interface_hosts.lua.cpp
	./lua2dox $(INTERFACE_BASE_DIR)/interface_ndpi.lua > $(INTERFACE_BASE_DIR)/interface_ndpi.lua.cpp
	./lua2dox $(INTERFACE_BASE_DIR)/interface_macs.lua > $(INTERFACE_BASE_DIR)/interface_macs.lua.cpp
	./lua2dox $(INTERFACE_BASE_DIR)/interface_dump.lua > $(INTERFACE_BASE_DIR)/interface_dump.lua.cpp

	./lua2dox $(NTOP_BASE_DIR)/ntop_misc.lua > $(NTOP_BASE_DIR)/ntop_misc.lua.cpp
	./lua2dox $(NTOP_BASE_DIR)/ntop_cache.lua > $(NTOP_BASE_DIR)/ntop_cache.lua.cpp
	./lua2dox $(NTOP_BASE_DIR)/ntop_prefs.lua > $(NTOP_BASE_DIR)/ntop_prefs.lua.cpp
	./lua2dox $(NTOP_BASE_DIR)/ntop_fs.lua > $(NTOP_BASE_DIR)/ntop_fs.lua.cpp
	./lua2dox $(NTOP_BASE_DIR)/ntop_network.lua > $(NTOP_BASE_DIR)/ntop_network.lua.cpp
	./lua2dox $(NTOP_BASE_DIR)/ntop_users.lua > $(NTOP_BASE_DIR)/ntop_users.lua.cpp
	doxygen Doxyfile

clean:
	rm -rf html xml
