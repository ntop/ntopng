--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"

local flow_data = {}
local callback_utils = require "callback_utils"
local flow_data_preset = require "flow_data_preset"
local trace_stats = false
local flow_data_historical = nil
local node_key_id_separator = ";"

if ntop.isEnterpriseL and ntop.isEnterpriseL() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" ..
                     package.path
   flow_data_historical = require "flow_data_historical"
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key to pair the values,
--        using the columns, basically simulating a group by
-- @param data List, generate by formatEmptyStats
-- @return a unique key composed by the elements requested
local function formatKey(data, query_info)
   local key = ""
   local separator = "|"
   -- Iterate all the select and create a unique ID, so if multiple queries for example
   -- have the same result, merge all these results
   for _, select_info in pairs(query_info.select_query) do
      if select_info.is_key then
         local node_key = nil
         local value = nil
         -- Find the info inside the preformatted empty data
         if (select_info.key) and (data[select_info.key]) then
               node_key = select_info.key
               value = data[select_info.key]
         elseif (select_info.rename) and (data[select_info.rename]) then
               node_key = select_info.rename
               value = data[select_info.rename]
         end
         
         if select_info.depends_on then
            value = string.format("%s_%s", (data[select_info.depends_on] or select_info.depends_on), value)
         end

         if value then
               key = string.format("%s%s%s%s%s", key, node_key, node_key_id_separator, value, separator)
         end
      end
   end

   key = key:sub(1, -2)

   return key
end

-- ###################################################

local function formatEmptyStats(flow, query_info)
   local empty_stats = {}

   -- IMPORTANT: Here the "duplicated" values are removed, if requested,
   -- see remove_if_equal_to; means that if the value is equal to the given one
   -- then that value is removed from the statistics, for example the ASN and PEER ASN
   -- must be different, otherwise there is no use in the PEER ASN and it has to be removed
   -- from the returned flow
   for _, select_info in pairs(query_info.select_query or {}) do
      local key
      if (select_info.rename) and (flow[select_info.rename]) then
         key = select_info.rename
         empty_stats[key] = flow[key]
      else
         key = select_info.key
         empty_stats[key] = flow[key]
      end

      -- In case of the values that needs to be added (e.g. Bytes)
      -- Start from 0, otherwise the same value maybe be added multiple times
      if not select_info.is_key then
         empty_stats[key] = 0
      end
   end

   -- Now remove the remove_if_equal_to
   for _, select_info in pairs(query_info.select_query or {}) do
      local condition = select_info.remove_if_equal_to
      if condition then
         local key = nil
         if (select_info.rename) then
               key = select_info.rename
         else
               key = select_info.key
         end
         -- The condition is a table, multiple possibilities are available
         for _, tmp in pairs(condition) do
            -- Two possibilities, condition is a value or condition is a key of the data
            if (tostring(empty_stats[key]) == tostring(tmp)) or (tostring(empty_stats[key]) == tostring(empty_stats[tmp])) then
               empty_stats[key] = nil
            end
         end
      end
   end

   return empty_stats
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @param invert_direction Boolean, true if traffic directions needs to be inverted
-- @param flow List, containing all the elements
-- @param current_element List, containing the statistics previously collected, needs to be updated
-- @return an updated list of stats, contained in current_element
local function updateStats(stats, flow, query_info)
   -- Iterate the requested fields
   for _, select_info in pairs(query_info.select_query or {}) do
      if (not select_info.is_key) then -- Not a key, so a value to be updated (e.g. bytes)
         local key = nil
         if (select_info.rename) then
               key = select_info.rename
         else
               key = select_info.key
         end

         stats[key] = tonumber(stats[key]) + (tonumber(flow[key]) or 0)
      end
   end

   return stats
end

-- ###################################################

function flow_data.getStats(queries)
   local results = {}

   for _, query_info in pairs(queries or {}) do
      -- Function used to, given a flow, merge all the same data togheter
      local function formatData(_, flow)
         -- Create an empty table, composed only by key values then create a unique key, where only
         -- flows with the same exact requested data are going to have the same key
         -- e.g. key = 1.1.1.1|2222|
         --      table = ip: 1.1.1.1
         --              asn: 2222
         --              bytes_sent: 0
         --              bytes_rcvd: 0
         local empty = formatEmptyStats(flow, query_info)
         if not empty then goto skip_flow end
         local key = formatKey(empty, query_info)
         if not results[key] then -- Entry still not created
               results[key] = empty
         end

         -- Now update the data (e.g. bytes_sent and bytes_rcvd)
         results[key] = updateStats(results[key], flow, query_info)
         ::skip_flow::
      end

      local query_result = {}
      if flow_data_historical then
         query_result = flow_data_historical.retrieveFlowData(query_info)
      end

      for _, flow in pairs(query_result or {}) do formatData(_, flow) end
   end

   -- Now we have equal table for live and historical, so now format the data and run the checks
   return results
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns Array of stats to format
-- @return an Array of formatted elements
function flow_data.formatStats(stats_to_format, queries)
   local formatted_stats = {}
   local formatters_linkers = {}

   -- Get the formatters and linkers
   for _, info in pairs(queries or {}) do
      local select_query = info.select_query or {}
      for _, select_info in pairs(select_query) do
         local key = (select_info.rename or select_info.key)
         formatters_linkers[key] = {
            linker = select_info.linker,
            formatter = select_info.formatter,
            depends_on = select_info.depends_on
         }
      end
   end

   -- For each element, see if there is a defined formatter in
   -- scripts/lua/modules/flow_data_preset.lua:format_functions
   -- if there is, split the value in { id = id, name = formattedName }
   -- otherwise keep that as it is
   for _, values in pairs(stats_to_format) do
      local formatted_element = {}
      for key, value in pairs(values or {}) do
         -- Format the data
         if formatters_linkers[key] and type(value) == "string" then
            local label = value
            local url_link = nil
            if formatters_linkers[key].depends_on then
               local depend_value = (values[formatters_linkers[key].depends_on] or formatters_linkers[key].depends_on)
               if depend_value then
                  label = formatters_linkers[key]["formatter"](depend_value, value)
                  url_link = formatters_linkers[key]["linker"](depend_value, value)
               end
            else
               label = formatters_linkers[key]["formatter"](value)
               if formatters_linkers[key]["linker"] then
                  url_link = formatters_linkers[key]["linker"](value)
               end
            end

            formatted_element[key] = {
               id = value,
               name = label,
               url = url_link
            }
         else
            formatted_element[key] = value
         end
      end

      formatted_stats[#formatted_stats + 1] = formatted_element
   end

   return formatted_stats
end

-- ###################################################

function flow_data.getOperators()
   local flowfilter_utils = require "flowfilter_utils"
   return flowfilter_utils.flowfilter_operators_sql
end

-- ###################################################

return flow_data
