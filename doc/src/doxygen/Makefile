.PHONY: all
.SUFFIXES: .lua .lua.cpp

SOURCES = $(shell find ../api/lua_c/ -type f -name *.lua)
TARGETS = $(SOURCES:.lua=.lua.cpp)

all: $(TARGETS)
	#grep "//Lua" ../../../src/Lua.cpp | sed -e 's/^[[:space:]]*\/\/Lua //' > api.lua.cpp
	doxygen Doxyfile

%.lua.cpp : %.lua
	./lua2dox $< > $@

clean:
	rm -rf html xml
