all:
	#grep "//Lua" ../../../src/Lua.cpp | sed -e 's/^[[:space:]]*\/\/Lua //' > api.lua.cpp
	./lua2dox ../api/lua/ntop.lua > ../api/lua/ntop.lua.cpp
	./lua2dox ../api/lua/interface.lua > ../api/lua/interface.lua.cpp
	doxygen Doxyfile

clean:
	rm -rf html xml
