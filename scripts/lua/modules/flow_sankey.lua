--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
local flow_data = require "flow_data"
local format_utils = require "format_utils"
local flow_data_preset = require "flow_data_preset"
local format_utils = require "format_utils"

-- ##########################################

local ROOT_ID = "root"
local other_id = "other"
local separator = "|"
local node_key_id_separator = ";"
local flow_sankey = {}

-- ##########################################

local function queriesSearchInfo(key, query)
   if not query then
      return nil
   end

   local info = {}
   local select_query = query.select_query
   for _, query_info in pairs(select_query or {}) do
      if (query_info.key == key) or (query_info.rename == key) then
         return query_info
      end
   end
   return nil
end

-- ##########################################

local function searchOtherLink(links, other_link_info)
   for index, info in pairs(links) do
      if (other_link_info.source_node_id == info.source_node_id) and 
         (other_link_info.target_node_id == info.target_node_id) then
         return index, info
      end
   end

   return nil, nil
end

-- ##########################################

local function findNode(node_id, nodes)
   for _, values in pairs(nodes) do
      if values.node_id == node_id then return true end
   end
   return false
end

-- ###################################################

-- Here we order by traffic and aggregate nodes, up to max_nodes_per_level then
-- the other nodes will be aggregated into a single node "Other"
local function formatNodes(nodes, max_nodes_per_level)
   local formatted_nodes = {}
   for depth_id, depth_nodes in pairs(nodes or {}) do
      local current_depth_nodes = 0
      for node_id, node_info in pairsByField(depth_nodes or {}, "value", rev) do
         -- Increase the counter
         current_depth_nodes = current_depth_nodes + 1

         if (current_depth_nodes == max_nodes_per_level + 1) then
            formatted_nodes[#formatted_nodes + 1] = {
               label = i18n('others'),
               node_id = string.format("%s%s%s", depth_id, node_key_id_separator, other_id)
            }
         elseif (current_depth_nodes <= max_nodes_per_level) then
            formatted_nodes[#formatted_nodes + 1] = {
               label = node_info.label,
               node_id = string.format("%s%s%s", depth_id, node_key_id_separator, node_id),
               link = node_info.link
            }
         end
      end
   end

   return formatted_nodes
end

-- ###################################################

-- Now let's format the links, some nodes may be changed due to the addition of the Other node
local function formatLinks(links, nodes)
   local formatted_links = {}

   for link_id, link_info in pairs(links or {}) do
      local is_other_node_used = false
      local new_index = #formatted_links + 1
      local new_formatted_link = {}
      -- If one node is not available, it means that the source or target
      -- changed to the Others node
      if not (findNode(link_info.source_node_id, nodes)) then
         is_other_node_used = true
         local tmp = split(link_info.source_node_id, node_key_id_separator)
         link_info.source_node_id = string.format("%s%s%s", tmp[1], node_key_id_separator, other_id)
      end

      if not (findNode(link_info.target_node_id, nodes)) then
         is_other_node_used = true
         local tmp = split(link_info.target_node_id, node_key_id_separator)
         link_info.target_node_id = string.format("%s%s%s", tmp[1], node_key_id_separator, other_id)
      end

      if is_other_node_used then
         local index, info = searchOtherLink(formatted_links, link_info)
         if index then
            new_index = index
            link_info.value = link_info.value + info.value
            link_info.label = link_info.formatter(info.value)
         end
      end

      if link_info.formatter then
         link_info.label = link_info.formatter(link_info.value)
         link_info.formatter = nil
      end

      formatted_links[new_index] = link_info
   end

   return formatted_links
end

-- ###################################################

local function findKeyInfo(key, query)
   if not (query) or not (query.select_query) then
      return nil
   end

   for _, info in pairs(query.select_query) do
      local select_key = nil
      if info.rename then
         select_key = info.rename
      else
         select_key = info.key
      end
      if select_key == key then
         return info
      end
   end

   return nil
end

-- ##########################################

local function addRootNode(nodes, query)
   if not nodes[ROOT_ID] then
      -- Format the root node
      local label = query.root.formatter(query.root.id)
      local link = nil
      nodes[ROOT_ID] = {
         [ROOT_ID] = {
            node_id = ROOT_ID, 
            label = label, 
            link = link
         }
      }
   end
end

-- ##########################################

-- This function push each node given to the nodes table
local function unifyNodes(new_nodes, nodes, query)
   -- Iterate all the nodes
   -- The nodes list is done in the following way:
   -- SRC_ASN
   --        1010 = 127837
   --        15024 = 498217
   for node_level_key, values in pairsByKeys(new_nodes or {}) do
      -- Create the new "depth" in the nodes list
      if not nodes[node_level_key] then
         nodes[node_level_key] = {}
      end
      -- Get the formatters if available
      local node_level_key_info = findKeyInfo(node_level_key, query)
      for node_id, node_value in pairsByValues(values or {}, rev) do
         -- Now check the presence of the new node in the list of all nodes
         if not nodes[node_level_key][node_id] then
            local label = node_id
            local node_link = nil
	    
            if node_level_key_info then
               if node_level_key_info.depends_on then
                  -- In this case, the key is structured in the following way:
                  -- FIRSTVALUE_SECONDVALUE, so simply split on the _ to get the 2 values
                  local tmp = split(node_id, "_")
                  if #tmp == 2 then
                     label = node_level_key_info.formatter(tmp[1], tmp[2])
                     node_link = node_level_key_info.linker(tmp[1], tmp[2])
                  end
               else
                  if node_level_key_info.formatter then
                     label = node_level_key_info.formatter(node_id)
                  end
                  if node_level_key_info.linker then
                     node_link = node_level_key_info.linker(node_id)
                  end
               end
            end
            nodes[node_level_key][node_id] = {
               node_id = id,
               label = label,
               link = node_link,
               value = 0
            }
         end

         -- Increase the value
         nodes[node_level_key][node_id]["value"] = nodes[node_level_key][node_id]["value"] + node_value
	   ::continue::
      end
   end

   if query.root then 
      addRootNode(nodes, query)
   end
end

-- ##########################################

-- This function push each node given to the nodes table
local function unifyLinks(new_links, links)
   for key, info in pairs(new_links or {}) do
      -- Link not available yet, create a new one
      if not links[key] then
         -- SRC_ASN.34978|root
         -- Splitted in SRC_ASN.34978 and root, the IDs of the two nodes
         local linked_nodes_keys = split(key, separator)
         if #linked_nodes_keys == 2 then
            links[key] = {
               source_node_id = linked_nodes_keys[1],
               target_node_id = linked_nodes_keys[2],
               formatter = info.formatter,
               value = 0,
            }
         end
      end

      links[key]["value"] = links[key]["value"] + info.value
   end
end

-- ##########################################

-- @brief This function updates the weight of each node
-- @param stats List, containing all the values returned from the DB
-- @param query List, containing useful data, like where conditions, ecc
--              (e.g. see: scripts/lua/pro/rest/v2/get/as/as_table.lua) 
-- @return a list of nodes and links for the requested data
local function updateNodesAndLinks(stats, query)
   local nodes = {}
   local links = {}

   -- Update the nodes & the links by iterating the query, 
   -- so we know the order of the nodes
   local link_key = nil
   for key, info in pairs(stats or {}) do
      local tmp_key = key
      local value_formatter = nil
      local total_value = 0
      -- First get the weight of the link, it's needed to update the nodes and links
	   for key, value in pairs(info or {}) do
         if type(value) == "number" then
            -- Calculate the value of the link
            total_value = total_value + value
            if not value_formatter then
               query_info = queriesSearchInfo(key, query)
               if query_info then
                  value_formatter = query_info.formatter
               end
            end 
         end
      end

      -- Now add the node or update the node
      for node, value in pairs(info or {}) do
         if value and type(value) == "string" then
            if not nodes[node] then
               nodes[node] = {}
            end
            query_info = queriesSearchInfo(node, query)
            if query_info and query_info.depends_on then
               value = string.format("%s_%s", (info[query_info.depends_on] or query_info.depends_on), value)
            end
            nodes[node][value] = 
               (nodes[node][value] or 0) + total_value
         
         end
      end

      -- Add the root node
      if query.root then
         local root_info = query.root
         if root_info.add_root_last then
            tmp_key = string.format("%s%s%s%s%s", tmp_key, separator, ROOT_ID, node_key_id_separator, ROOT_ID)
         else -- By default it add the root at the start
            tmp_key = string.format("%s%s%s%s%s", ROOT_ID, node_key_id_separator, ROOT_ID, separator, tmp_key)
         end
      end

      -- Now update the links
      local general_link_key_split = split(tmp_key, separator)

      -- Now iterate all the splitted keys, to create a link for each element
      -- e.g   src_asn | transit_asn | my_asn   we need to create 2 links:
      --     src_asn -> transit_asn
      --     transit_asn -> my_asn
      for i = 2, #general_link_key_split do
         local link_key = string.format("%s%s%s", general_link_key_split[i - 1], separator, general_link_key_split[i])
         if not links[link_key] then
            links[link_key] = {
               value = 0,
               formatter = value_formatter
            }
         end
         links[link_key]["value"] = total_value + links[link_key]["value"]
      end
   end

   return nodes, links
end

-- ##########################################

-- @brief Given a list of queries to be run, it will generate a sankey
-- @param queries Queries to run
-- @param max_nodes_per_level number, representing the maximum number of nodes per level
--                            in case the number is surpassed, the "Other" node is added
-- @return a list composed by nodes and links
function flow_sankey.generateSankey(queries, max_nodes_per_level, isHistorical)
   -- In case of multiple queries, run each query one by one,
   -- then merge the data.
   -- In case the rename_key_field and each queries search for different data,
   -- the nodes from different queries are going to be recognized as different
   -- and so the data are not going to be merged
   local nodes = {}
   local links = {}

   if not isHistorical then interface.aggregateASNFlows() end

   for _, query in pairs(queries) do
      local table_stats = flow_data.getStats({query})
      local single_query_nodes = {}
      local single_query_links = {}
      single_query_nodes, single_query_links = updateNodesAndLinks(table_stats, query)
      unifyNodes(single_query_nodes, nodes, query, max_nodes_per_level)
      unifyLinks(single_query_links, links, nodes)
   end
   local formatted_nodes = formatNodes(nodes, max_nodes_per_level)
   local formatted_links = formatLinks(links, formatted_nodes)
   
   return formatted_nodes, formatted_links
end

-- ##########################################

function flow_sankey.getOperators()
   local flowfilter_utils = require "flowfilter_utils"
   return flowfilter_utils.flowfilter_operators_sql
end

-- ##########################################

return flow_sankey
