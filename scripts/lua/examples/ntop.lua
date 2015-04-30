--
-- (C) 2013 - ntop.org
--

-- Ntop lua class example

function printTable(table,key)
  if (key ~= nil) then print(""..key..":<ul>") end
  for k, v in pairs(table) do
    if (type(v) == "table") then
       printTable(table[k],k)
    else
      if (type(v) == "boolean") then
        if (v) then v = "true" else v = "false" end
      end
      print("<li>"..k .." = "..v.."<br>")
    end
  end
  print("</ul>")
end
-- Set package.path information to be able to require lua module
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if ( (dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"

-- Here you can choose the type of your HTTP message {'text/html','application/json',...}. There are two main function that you can use:
-- function sendHTTPHeaderIfName(mime, ifname, maxage)
-- function sendHTTPHeader(mime)
-- For more information please read the scripts/lua/modules/lua_utils.lua file.
sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print('<html><head><title>ntopng API Lua example</title></head>')
print('<body>')
print('<h1>Examples of ntop lua class</h1>')
print('<p>This class provides a set of general functions used to interact with ntopng configuration. In the following page we provide an example of which information can you get by this class.<br><b>For more information, please read the source code of this file and the doxygen of API Lua.</b></p>')


print('<br><h2>Global variables</h2>')
print('<p>There are a few global variables that are defined by default when ntopng is running. The following list show the main variables:</p>')
print('<ul>')
print('<li>ifname = ' .. ifname)

print('</ul>')
print('</body></html>\n')


print('<br><h2>General information</h2>')
print('<p>The ntopng lua class provide a few methods to get information about the ntopng running instance.</p>')


print('<h4>ntopng information</h4>')
print('<pre><code>ntop.getInfo()</code></pre>')
print('<ul>')
for key, value in pairs(ntop.getInfo()) do
   print("<li>".. key.." = "..value.."<br>")
end
print('</ul>')

print('<h4>ntopng directory</h4>')
print('<pre><code>ntop.getDirs()</code></pre>')
print('<ul>')
for key, value in pairs(ntop.getDirs()) do
   print("<li>".. key.." = "..value.."<br>")
end
print('</ul>')

print('<h4>ntopng uptime</h4>')
print('<pre><code>ntop.getUptime()</code></pre>')
print('<ul>')
print("<li>uptime = "..ntop.getUptime().."<br>")
print('</ul>')

print('<h4>ntopng get time msec</h4>')
print('<pre><code>ntop.gettimemsec()</code></pre>')
print('<ul>')
print("<li>time = "..ntop.gettimemsec().."<br>")
print('</ul>')

print('<h4>ntopng check trace mode</h4>')
print('<pre><code>ntop.verboseTrace()</code></pre>')
print('<ul>')
if (ntop.verboseTrace()) then
  print("<li>mode = MAX_TRACE_LEVEL<br>")
else
  print("<li>mode != MAX_TRACE_LEVEL<br>")
end
print('</ul>')

print('<h4>ntopng check if the system is windows</h4>')
print('<pre><code>ntop.isWindows()</code></pre>')
print('<ul>')
if (ntop.isWindows()) then
  print("<li>true<br>")
else
  print("<li>false<br>")
end
print('</ul>')

print('<h4>ntopng dumpFile</h4>')
print('<p>Dumps the specified file onto the returned web page. Usually it is used to create simple server-side page includes. In this case we have dump the file containing the header html.</p>')


print('<br><h2>Preference values</h2>')
-- print('<p>The ntopng lua class provide a few methods to get information about the redis cache.</p>')
print('<pre><code>ntop.getPrefs()</code></pre>')
printTable(ntop.getPrefs())



print('<br><h2>Redis</h2>')
print('<p>The ntopng lua class provide a few methods to get information about the redis cache.</p>')

print('<h4>ntopng set and get (key,value) in redis cache</h4>')
print('<pre><code>key_name = "ntopng.prefs."..ifname..".name"\ntest_name = "redis_cache_set_name"\nkey_speed = "ntopng.prefs."..ifname..".speed"\ntest_speed = "123456"\n\nntop.setCache(key_name,test_name)\nntop.setCache(key_speed,test_speed)\n\nntop.getCache(key_name)\nntop.getCache(key_speed)</code></pre>')
key_name = 'ntopng.prefs.'..ifname..'.name'
test_name = "redis_cache_set_name"
key_speed = 'ntopng.prefs.'..ifname..'.speed'
test_speed = "123456"

ntop.setCache(key_name,test_name)
ntop.setCache(key_speed,test_speed)

print('<p>Output:<ul>')
-- print("<li> Set: ".. key_name .." = ".. test_name .."<br>")
print("<li>".. key_name .." = ".. ntop.getCache(key_name) .."<br>")
-- print("<li> Set: ".. key_speed .." = ".. test_speed .."<br>")
print("<li>".. key_speed .." = ".. ntop.getCache(key_speed) .."<br>")
print('</ul></p>')

print('<h4>ntopng delete (key,value) from redis cache</h4>')
print('<pre><code>ntop.delCache(key_name)</code></pre>')
ntop.delCache(key_name)

print('<p>Output:<ul>')
-- print("<li> Set: ".. key_name .." = ".. test_name .."<br>")
print("<li>".. key_name .." = ".. ntop.getCache(key_name) .."<br>")
-- print("<li> Set: ".. key_speed .." = ".. test_speed .."<br>")
print("<li>".. key_speed .." = ".. ntop.getCache(key_speed) .."<br>")
print('</ul></p>')



print('<h4>ntopng set and get hash in redis cache</h4>')
print('<pre><code>ntop.setHashCache(\"ntopng.alternate_names\", \"127.0.0.1\", \"test_name\")\n\nntop.getHashCache(\"ntopng.alternate_names\", \"127.0.0.1\")</code></pre>')

ntop.setHashCache("ntopng.alternate_names", "127.0.0.1", "test_name")

print('<p>Output:<ul>')
print("<li>ntopng.alternate_names = "..ntop.getHashCache("ntopng.alternate_names", "127.0.0.1") .."<br>")
print('</ul></p>')


print('<br><h2>Address resolution</h2>')
print('<p>The ntopng lua class provide a few methods to get information about the address resolution.</p>')

print('<h4>ntopng resolve the IP address and get host name</h4>')
print('<pre><code>ntop.resolveAddress("127.0.0.1")</code></pre>')

print('<ul>')
print("<li>127.0.0.1 = "..ntop.resolveAddress("127.0.0.1").."<br>")
print('</ul>')

print('<br><h2>Logging</h2>')
-- print('<p>The ntopng lua class provide a few methods to get information about the address resolution.</p>')

print('<h4>Syslog</h4>')
print('<pre><code>ntop.syslog(true,"Sample syslog LOG_ERROR message by ntopng lua API.")\nntop.syslog(false,"Sample syslog LOG_INFO message by ntopng lua API.")</code></pre>')

ntop.syslog(true,"Sample syslog LOG_ERROR message by ntopng lua API.")
ntop.syslog(false,"Sample syslog LOG_INFO message by ntopng lua API.")

print('<ul>')
print("<li>Check the output: tail -f /var/log/system.log .<br>By default, syslog configuration does not show in the system.log file the messages with Level set to info.<br>")
print('</ul>')

print('<br><h2>Users</h2>')
print('<h4>List of current ntop users</h4>')
print('<pre><code>ntop.getUsers()</code></pre>')
printTable(ntop.getUsers())

print('<br><h4>Create new ntop user</h4>')
print('<pre><code>ntop.addUser("test","test_full_name","test_pw")</code></pre>')
ntop.addUser("test","test_full_name","test_pw")

print('<h4>List of current ntop users</h4>')
printTable(ntop.getUsers())

print('<br><h4>Reset user password</h4>')
print('<pre><code>ntop.resetUserPassword("test","test_pw","new_pw")</code></pre>')
ntop.resetUserPassword("test","test_pw","new_pw")

print('<br><h4>Delete user</h4>')
print('<pre><code>ntop.deleteUser("test")</code></pre>')
ntop.deleteUser("test")

print('<h4>List of current ntop users</h4>')
printTable(ntop.getUsers())



print('<br><h4>TDB</h4>')
print('<p><ul>')
print('<li>getMembersCache')
print('<li>delHashCache')
print('<li>getHashKeysCache')
print('<li>delHashCache')
print('<li>setPopCache')
print('<li>dumpDailyStats')
print('<li>getHostId')
print('<li>getIdToHost')
print('<li>ZMQ')
print('</ul></p>')

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")




