--
-- (C) 2013 - ntop.org
--

-- Ntop lua class example



-- Set package.path information to be able to require lua module
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path


function printTable(table,key)

  -- traceError(TRACE_DEBUG,TRACE_CONSOLE, "Extern\n")
  if (key ~= nil) then print(""..key..":<ul>") end
  for k, v in pairs(table) do
    -- traceError(TRACE_DEBUG,TRACE_CONSOLE, "Intern\n")
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

require "lua_utils"

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


interface.select(ifname)
local debug = true
-- setTraceLevel(TRACE_DEBUG) -- Debug mode

host_ip       = _GET["host"]
hostinfotype  = _GET["hostinfotype"]
aggregated  = _GET["aggregated"]
interfacetype = _GET["interfacetype"]
showjson  = _GET["showjson"]
flowtype      = _GET["flowtype"]
aggregated  = _GET["aggregated"]
protocol  = _GET["protocol"]

-- Here you can choose the type of your HTTP message {'text/html','application/json',...}. There are two main function that you can use:
-- function sendHTTPHeaderIfName(mime, ifname, maxage)
-- function sendHTTPHeader(mime)
-- For more information please read the scripts/lua/modules/lua_utils.lua file.

-- Test key 2 host and host 2 key
-- hosts_stats = interface.getHostsInfo()
-- for key, value in pairs(hosts_stats) do
--   print ("key:"..key.."</br>")
--   info = hostkey2hostinfo(key)
--   print ("Host: "..info["host"].."@"..info["vlan"].."<br>")
--   host = interface.getHostInfo(key)
--   print ("key:"..key.."<br>")
--   if(host == nil) then
--     print ("Null<br>")
--     else
--       print ("Found<br>")
--     end
-- end


print('<h1>Examples of interface lua class</h1>')
print('<p>This class provides to hook to objects that describe flows and hosts and it allows you to access to live monitoring data.<br><b>For more information, please read the source code of this file and the doxygen of API Lua.</b></p>')

print('<hr><h2>Generic information of Network interface</h2>')
print('<p>By default ntopng set the \"ntop_interface\"  global variable in lua stack, it is the network interface name where ntopng is running.<br>Every time when you want use the interface class, in order to refresh the \"ntop_interface\" global variable , please remember to call the method <b>interface.select(ifname))</b> before to use the interface class.</p>')
print('<ul>')
print('<li>Network interface name = ' .. interface.select(ifname))
print('<li>Network interface id = ' .. interface.name2id(ifname))
if (interface.isRunning()) then
  print('<li>'..ifname..' is running')
else
  print('<li>'..ifname..' is not running')
end
print('</ul>')

print('<h4>Available Interfaces</h4>')
print('<pre><code>interface.getIfNames()</code></pre>')
printTable(interface.getIfNames())

print('<hr><h4>Switch network interface</h4>')
print('<p>In order to switch the network interface where ntopng is running, you need to use the method <b>setActiveInterfaceId(id)</b>, for more information please read the documentation and if you are looking for a complete and correctly example how to switch interface and active a new session, please read the source code of the <b>set_active_interface.lua</b> script.</p>')

print('<hr><h2 id="interface_information">Interface information</h2>')
print('<p>The interface lua class provide a few methods to get information about the active network interface.</p>')

print('<h4>Get interface statistics information</h4>')
print('<p>Available examples:<ul>')
print('<li><a href="?interfacetype=show#interface_information">Show statistics information</a>')
print('</ul></p>')
print('<p><b>Output:</b><p>')
print('<ul>')
if (interfacetype == "show") then
  print('<pre><code>ifstats = interface.getStats()</code></pre>')
  ifstats = interface.getStats()
  for key, value in pairs(ifstats) do
   if (type(ifstats[key]) == "table") then
    printTable(ifstats[key],key)
    elseif (type(ifstats[key]) == "boolean") then
      if (value) then value = "true" else value = "false" end
      print("<li>".. key.." = " ..value.."<br>")
    else
     print("<li>".. key.." = " ..value.."<br>")

   end
 end
end --if
print('</ul>')

print('<hr><h2 id="host_information">Host information</h2>')
print('<p>The interface lua class provide a few methods to get information about the hosts.</p>')

print('<h4>Get hosts information</h4>')
print('<p>This is an example how to use the interface methods to get storage information. In order to extract all information about an host you can use the method "interface.getHostInfo(host_ip,vlan_id)". Please read the doxygen documentation for more information.</p>')

print('<p>Available examples:<ul>')
print('<li><a href="?hostinfotype=minimal_one_host#host_information">Minimal information of one host.</a>')
print('<li><a href="?hostinfotype=minimal_all_host#host_information">Minimal information of all host.</a>')
print('<li><a href="?hostinfotype=more_one_host#host_information">More information of one host.</a>')
print('<li><a href="?hostinfotype=more_all_host#host_information">More information of all host.</a>')
print('</ul></p>')

print('<p><b>Output:</b><p>')
print('<ul>')

if (hostinfotype == "minimal_one_host" ) or (hostinfotype == "minimal_all_host") then
  print('<pre><code>hosts = interface.getHosts()</code></pre>')
  hosts = interface.getHosts()

  if (hosts == nil) then if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Host null\n") end end

  for key, value in pairs(hosts) do
    if (hosts[key]["ip"] ~= nil) then
    host_info = hosts[key]["ip"]
  else
    host_info = hosts[key]["mac"]
  end
    print("<li> Key: ".. key)
    print("<ul>")
    print("<li> Ip: "..host_info)
    print("<li> Vlan: "..hosts[key]["vlan"])
    print("<li> Sent Byte + Received Byte: " .. hosts[key]["traffic"])
    print("</ul>")
    print("<br>")

    if (hostinfotype == "minimal_one_host" ) then break end
  end
end

if (hostinfotype == "more_one_host" ) or (hostinfotype == "more_all_host") then

  if(hostinfotype == "more_all_host") then
    print('<pre><code>hosts = interface.getHostsInfo()</code></pre>')
  end

  hosts = interface.getHostsInfo()
  if (hosts == nil) then if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Host null\n") end end
  for key, value in pairs(hosts) do
      random_host = key
      if (hostinfotype == "more_one_host") then break end
      print("<li> HostName: ".. key.."<br>")
      printTable(hosts[key],key)
  end
  if (hostinfotype == "more_one_host") then
    print('<pre><code>hosts = interface.getHostInfo('..random_host..')</code></pre>')
    print("<li> HostName: ".. random_host.."<br>")
    printTable(interface.getHostInfo(random_host))
  end
end
print('</ul>')

random_host = nil
print('<hr><h4 id="json_format">Export information in JSON format</h4>')
print('<p>This is an example how to use the interface methods to export information in json format.</p>')
print('<a href="?showjson=1#json_format">Show host:</a>')

if(showjson ~= nil) then
  print('<br><p>Available hosts:<ul>')
  print('<pre><code>hosts_json = interface.getHosts()</code></pre>')
  print('<li><a href="/lua/do_export_data.lua" target="_blank"> All hosts</a>')

  hosts_json = interface.getHosts()
  for key, value in pairs(hosts_json) do
    random_host = key
    print('<li>'..key)
    print('<ul>')
    if (hosts_json[key]["ip"] ~= nil) then
      host_info = hosts_json[key]["ip"]
    else
      host_info = hosts_json[key]["mac"]
    end
    print('<li><a href="/lua/host_get_json.lua?host=' .. host_info..'&vlan='..hosts_json[key]["vlan"]..'" target="_blank"> All information</a>')
    print('<li><a href="/lua/get_host_activitymap.lua?host=' .. key..'" target="_blank"> Only Activity Map </a>')
    print('</ul>')
  end
  print('</ul></p>')
end

print('<hr><h2 id="flow_information">Flow information</h2>')
print('<p>The interface lua class provide a few methods to get information about the flows.</p>')

print('<h4>Get flows information</h4>')
print('<p>This is an example how to use the interface methods to get flows information.</p>')

print('<p>Available examples:<ul>')
print('<li><a href="?flowtype=description#flow_information">Flows description.</a>')
print('<li><a href="?flowtype=peers#flow_information">Flow peers</a>')
-- print('<li><a href="?flowtype=more_one_host">More information of one host.</a>')
-- print('<li><a href="?flowtype=more_all_host">More information of all host.</a>')
print('</ul></p>')

print('<p><b>Output:</b><p>')

if (flowtype == "description" ) then
  print('<pre><code>flows_stats = interface.getFlowsInfo()\nprintTable(flows_stats)</code></pre>')
  flows_stats = interface.getFlowsInfo()
  printTable(flows_stats)
end

if (flowtype == "peers" ) then
  print('<pre><code>flows_stats = interface.getFlowPeers()\nprintTable(flows_peers,"Peers")</code></pre>')
  flows_peers = interface.getFlowPeers()
  printTable(flows_peers,"Peers")
end


print('<hr><h2 id="aggregated_information">Aggregated Hosts information</h2>')

print('<p>Available protocol:<ul>')
print('<li><a href="?aggregated=1#aggregated_information">All</a>')
print('<li><a href="?aggregated=1&protocol=5#aggregated_information">DNS</a>')
print('<li><a href="?aggregated=1&protocol=7#aggregated_information">HTTP</a>')
print('<li><a href="?aggregated=1&protocol=254#aggregated_information">Operation System</a>')
print('<li><a href="?aggregated=1&protocol=38#aggregated_information">EPP</a>')
print('</ul></p>')

print('<p><b>Output:</b><p>')
print('<ul>')

if (aggregated ~= nil) then
  if(protocol == nil) then
    print('<pre><code>aggregated = interface.getAggregatedHostsInfo()</code></pre>')
    hosts_stats = interface.getAggregatedHostsInfo()
  else
    print('<pre><code>aggregated = interface.getAggregatedHostsInfo('..tonumber(protocol)..')</code></pre>')
    hosts_stats = interface.getAggregatedHostsInfo(tonumber(protocol))
  end

  if (table.empty(hosts_stats)) then
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Aggregated null\n") end
    print('<div class="alert alert-warning">No aggregated hosts found.</div>')
  end

  for key, value in pairs(hosts_stats) do
      printTable(hosts_stats[key],key)
  end
end
print('</ul>')

print('<hr><h4>TDB</h4>')
print('<p><ul>')
print('<li>findFlowByKey')
print('<li>findHost')
print('<li>getEndpoint')
print('<li>incrDrops')
print('<li>getAggregationsForHost')
print('<li>getAggregationFamilies')
print('<li>getNumAggregatedHosts')
print('<li>getNdpiProtoName')
print('<li>flushHostContacts')
print('<li>restoreHost')

print('</ul></p>')

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


