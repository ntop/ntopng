--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

-- Table parameters
all = _GET["all"]
currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]

id = _GET["id"]

if(sortOrder == nil) then
  sortOrder = "desc"
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(sortColumn == nil) then
  sortColumn = "column_index"
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
  perPage = tonumber(perPage)
  tablePreferences("rows_number",perPage)
end

interface.select(ifname)
communities = interface.getCommunities()

to_skip = (currentPage-1) * perPage

if (all ~= nil) then
  perPage = 0
  currentPage = 0
end

if (id == nil) then
  print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
end

num_communities = 0
for key, value in pairs(communities) do
  num_communities = num_communities + 1
end

total = 0

for key,value in pairs(communities) do
   if (id ~= nil and tostring(value) ~= id) then
      goto nextloop
   end
   print ('{ ')
   print ('\"key\" : \"'..tostring(value)..'\",')

   print ("\"column_index\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/")
      print("hosts_stats.lua?community=" ..tostring(value) .. "'>")

   print(tostring(value)..'</A>", ')

   print("\"column_id\" : \"" .. tostring(key) .. "\"")

   print(" } ")
   if (total < num_communities-1) then
      print ",\n"
   end
   total = total + 1
   ::nextloop::
end

if (id == nil) then
  print ("\n], \"perPage\" : " .. perPage .. ",\n")
  print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
  print ("\"totalRows\" : " .. total .. "}")
end
