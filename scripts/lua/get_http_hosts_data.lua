--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

-- Table parameters
all = _GET["all"]
currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]
protocol    = _GET["protocol"]
key         = _GET["host"]

if((sortColumn == nil) or (sortColumn == "column_")) then
   sortColumn = getDefaultTableSort("http_hosts")
else
   if((sortColumn ~= "column_") and (sortColumn ~= "")) then
      tablePreferences("sort_http_hosts", sortColumn)
   end
end

--io.write(sortColumn.."\n")

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder("http_hosts")
else
   if((sortColumn ~= "column_") and (sortColumn ~= "")) then
      tablePreferences("sort_order_http_hosts",sortOrder)
   end
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number",perPage)
end

interface.select(ifname)

hosts_stats = interface.listHTTPhosts(key)

to_skip = (currentPage-1) * perPage

if(all ~= nil) then
   perPage = 0
   currentPage = 0
end

print("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
num = 0
total = 0

now = os.time()
vals = {}
num = 0

sort_mode = mode

--
if(hosts_stats ~= nil) then
for key, value in pairs(hosts_stats) do
   num = num + 1
   postfix = string.format("0.%04u", num)
   ok = true

   if(sortColumn == "column_http_virtual_host") then
      vals[key] = key
      elseif(sortColumn == "column_server_ip") then
      vals[hosts_stats[key]["server.ip"]..postfix] = key
      elseif(sortColumn == "column_bytes_sent") then
      vals[hosts_stats[key]["bytes.sent"]+postfix] = key
      elseif(sortColumn == "column_bytes_rcvd") then
      vals[hosts_stats[key]["bytes.rcvd"]+postfix] = key
      elseif(sortColumn == "column_http_requests") then
      vals[hosts_stats[key]["http.requests"]+postfix] = key
      else
      vals[hosts_stats[key]["http.act_num_requests"]+postfix] = key
   end
end
end

table.sort(vals)


if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]

   if((key ~= nil) and (not(key == ""))) then
      value = hosts_stats[key]

      if(to_skip > 0) then
	 to_skip = to_skip-1
      else
	 if((num < perPage) or (all ~= nil)) then
	    if(num > 0) then print ",\n" end
	    print('{ ')
	    local k = string.gsub(key, "%.", "___") -- Needed as JQuery does not like . in id= field

	    print('\"key\" : \"'.. k ..'\",\n')
	    print(' \"column_http_virtual_host\" : \"<A HREF=\'http://'..key..'\'>'..key.."</A> <i class='fa fa-external-link'></i>")

	    print(" <A HREF='")
	    url = ntop.getHttpPrefix().."/lua/flows_stats.lua?vhost="..key
	    print(url.."'>")
	    print("<i class='fa fa-search-plus fa-lg'></i>")
	    print("</A>")

	    print("\",\n")
	    print(" \"column_server_ip\" : \"<A HREF='")
	    url = ntop.getHttpPrefix().."/lua/host_details.lua?" ..hostinfo2url(value["server.ip"]) .. "&page=http"
	    print(url.."'>")
	    print(value["server.ip"])
	    print("</A>\"")
	    print(",\n \"column_url\" : \""..url.."\"")
	    print(",\n \"column_bytes_sent\" : \"" .. bytesToSize(value["bytes.sent"]))
	    print("\",\n \"column_bytes_rcvd\" : \"" .. bytesToSize(value["bytes.rcvd"]))
	    print("\",\n \"column_http_requests\" : \"" .. formatValue(value["http.requests"]))

	    print("\",\n \"column_act_num_http_requests\" : \"" .. formatValue(value["http.act_num_requests"]).." ")
	    if(value["http.requests_trend"] == 1) then
	       print("<i class='fa fa-arrow-up'></i>")
	    elseif(value["http.requests_trend"] == 2) then
	       print("<i class='fa fa-arrow-down'></i>")
	    else
	       print("<i class='fa fa-minus'></i>")
	    end
	    print("\" } ")
	    num = num + 1
	 end
      end

      total = total + 1
   end
end -- for

print("\n], \"perPage\" : " .. perPage .. ",\n")

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

print("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
print("\"totalRows\" : " .. total .. " \n}")
