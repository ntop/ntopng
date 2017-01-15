--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

local json = require ("dkjson")

-- datatable parameters
local current_page = _GET["currentPage"]
local per_page     = _GET["perPage"]
local sort_column  = _GET["sortColumn"]
local sort_order   = _GET["sortOrder"]

interface.select(ifname)
local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local host = interface.getHostInfo(host_info["host"],host_info["vlan"])
local categories = host["categories"]

if sort_column == nil then
   sort_column = getDefaultTableSort("host_categories")
else	
   if sort_column ~= "column_" and sort_column ~= "" then
      tablePreferences("host_categories", sort_column)
   end
end

if sort_column == "column_" then
sort_column = "column_bytes"
end

if sort_order == "asc" then
   funct = asc
else
   funct = rev
end

if current_page == nil then
   current_page = 1
else
   current_page = tonumber(current_page)
end

if per_page == nil then
   per_page = getDefaultTableSize()
else
   per_page = tonumber(per_page)
   tablePreferences("rows_number", per_page)
end
local to_skip = (current_page - 1) * per_page
if to_skip < 0 then to_skip = 0 end

local total_bytes = 0
for cat_name, cat_bytes in pairs(categories) do
   local cat_contents = {}
   cat_contents["column_id"] = cat_name
   cat_contents["column_label"] = capitalize(getCategoryLabel(cat_name))
   cat_contents["column_bytes"] = cat_bytes
   total_bytes = total_bytes + cat_bytes
   categories[cat_name] = cat_contents
end

local sorter = {}
for cat_name, cat_contents in pairs(categories) do
   if sort_column == "column_id" then sorter[cat_name] = cat_name
   elseif sort_column == "column_name" then sorter[cat_name] = cat_contents["column_name"]
   elseif sort_column == "column_bytes" then sorter[cat_name] = cat_contents["column_bytes"]
   else sorter[cat_name] = cat_name end
end

-- format bytes and add hyper links
for cat_name, cat_contents in pairs(categories) do
   if total_bytes > 0 then
      cat_contents["column_pct"] = round(cat_contents["column_bytes"] / total_bytes * 100, 2).."%"
   else
      cat_contents["column_pct"] = "NaN"
   end
   cat_contents["column_bytes"] = bytesToSize(cat_contents["column_bytes"])

   local label = getCategoryLabel(cat_name)
   local fname = getRRDName(ifid, hostinfo2hostkey(host_info), "categories/"..label..".rrd")
   if ntop.exists(fname) then
      cat_contents["column_label"] = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifid.."&"..hostinfo2url(host_info) .. "&page=historical&rrd_file=categories/".. label ..".rrd\"><b>"..cat_contents["column_label"].."</b></A>"
   end
end

local num_page = 0
local total_rows = 0
local result_data = {}
for cat_name,_ in pairsByValues(sorter, funct) do
   if to_skip > 0 then
      to_skip = to_skip - 1
   elseif num_page < per_page then
      table.insert(result_data, categories[cat_name])
      num_page = num_page + 1
   end
   total_rows = total_rows + 1
end
local result = {}
result["perPage"] = per_page
result["currentPage"] = current_page
result["totalRows"] = total_rows
result["data"] = result_data
result["sort"] = {{sort_column, sort_order}}

sendHTTPHeader('text/html; charset=iso-8859-1')
print(json.encode(result, nil))

