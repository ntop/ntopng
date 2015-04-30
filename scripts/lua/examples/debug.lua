--
-- (C) 2013 - ntop.org
--

-- debug lua example

-- Set package.path information to be able to require lua module
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

-- Here you can choose the type of your HTTP message {'text/html','application/json',...}. There are two main function that you can use:
-- function sendHTTPHeaderIfName(mime, ifname, maxage)
-- function sendHTTPHeader(mime)
-- For more information please read the scripts/lua/modules/lua_utils.lua file.
sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print('<html><head><title>debug Lua example</title></head>')
print('<body>')
print('<h1>How to debug your lua scripts</h1>')
print('<br><h2>How to print debug information</h2>')
print('<p><h4>ntopng Lua library comes with a standard trace event features:</h4></p>')

print('<p>There are five type of event:</p>')
print('<ul>')
print('<li> TRACE_ERROR    </li>')
print('<li> TRACE_WARNING  </li>')
print('<li> TRACE_NORMAL   </li>')
print('<li> TRACE_INFO     </li>')
print('<li> TRACE_DEBUG    </li>')
print('</ul>')

print('<p>Use the following function to modify the current trace level.</p>')
print('<pre><code>setTraceLevel(p_trace_level)</br>resetTraceLevel()</code></pre></br>') 


print('<p>There are two type of trace:</p>')
print('<ul>')
print('<li> TRACE_CONSOLE    </li>')
print('<li> TRACE_WEB  </li>')
print('</ul>')

print('<p>Default: Only the TRACE_ERROR is printed.</p></br>')

print('<p><h4>There are two way to print some debug information:</h4></p>')
print('<ul>')
print('<li> <a href="?trace=console">Trace event on the console.</a></li>')
print('<li> <a href="?trace=web">Trace event on the web.</a></li>')
print('</ul>')



if(_GET["trace"] == "console") then 
  print('<p><b>Code:</b><p>')
  print('<pre><code>traceError(TRACE_DEBUG,TRACE_CONSOLE, "Trace: ".._GET["trace"])</code></pre>') 
end

if(_GET["trace"] == "web") then 
  print('<p><b>Code:</b><p>')
  print('<pre><code>traceError(TRACE_DEBUG,TRACE_WEB, "Trace: ".._GET["trace"])</code></pre>')
end


if(_GET["trace"] == "console") then 
  print('<p><b>Output:</b><p>')
  print('<ul><li> <b>Show ntopng console</b></li></ul>')
  traceError(TRACE_ERROR,TRACE_CONSOLE, "Trace: ".._GET["trace"]) 
end

if(_GET["trace"] == "web") then 
  print('<p><b>Output:</b><p>')
  print('<ul><li>')
  traceError(TRACE_ERROR,TRACE_WEB, "Trace: ".._GET["trace"]) 
  print('</li></ul>')
end

print('</br><p><h4>Output format:</h4></p>')
print('<pre><code>#date #time [#calling_function] [#filename:#currentline] #trace_level: #message</code></pre>')
print('<p>NB: #calling_function will be show only if it is different from #filename:#currentline<p>')
print('<br><h2>How to read and print the _GET variables</h2>')
print('<p>Any lua scripts can be executed by passing one or more parameters. The simple way to get an input variable is "variable_name        = _GET["variable_name"]".<br><br>Try with this: <a href="?host=192.168.1.10&myparam=myparam&var=123456">/lua/examples/debug.lua?host=192.168.1.10&myparam=myparam&var=123456</a></p>')

-- Print _GET variable
print('<p>')
for key, value in pairs(_GET) do 
   print(key.."="..value.."<br>")
end
-- printGETParameters(_GET)
print('</p>')

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")




