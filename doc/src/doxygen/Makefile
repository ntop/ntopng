all:
	grep "//Lua" ../../../src/Lua.cpp | sed -e 's/^[[:space:]]*\/\/Lua //' > api.lua.cpp
	doxygen Doxyfile

clean:
	rm -rf html xml
