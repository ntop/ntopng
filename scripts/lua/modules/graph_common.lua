--
-- (C) 2020-21 - ntop.org
--

-- Module for sharred methods between community graph_utils.lua
-- and pro/enterprise nv_graph_utils.lua

local ts_utils = require("ts_utils")
local dscp_consts = require("dscp_consts")
local have_nedge = ntop.isnEdge()

-- ##############################################

local graph_common = {}

-- ##############################################

-- label, relative_difference, seconds
graph_common.zoom_vals = {
    { "1m",  "now-60s",  60},
    { "5m",  "now-300s", 60*5},
    { "30m", "now-1800s", 60*30},
    { "1h",  "now-1h",   60*60*1},
    --{ "3h",  "now-3h",   60*60*3},
    --{ "6h",  "now-6h",   60*60*6},
    --{ "12h", "now-12h",  60*60*12},
    { "1d",  "now-1d",   60*60*24},
    { "1w",  "now-1w",   60*60*24*7},
    --{ "2w",  "now-2w",   60*60*24*14},
    { "1M",  "now-1mon", 60*60*24*31},
    --{ "6M",  "now-6mon", 60*60*24*31*6},
    { "1Y",  "now-1y",   60*60*24*366}
 }

 -- ##############################################

function graph_common.getZoomDuration(cur_zoom)
    for k,v in pairs(graph_common.zoom_vals) do
       if(graph_common.zoom_vals[k][1] == cur_zoom) then
      return(graph_common.zoom_vals[k][3])
       end
    end

    return(180)
 end

 -- ##############################################

 function graph_common.getZoomAtPos(cur_zoom, pos_offset)
    local pos = 1
    local new_zoom_level = cur_zoom
    for k,v in pairs(graph_common.zoom_vals) do
      if(graph_common.zoom_vals[k][1] == cur_zoom) then
        if (pos+pos_offset >= 1 and pos+pos_offset < table.len(graph_common.zoom_vals)) then
      new_zoom_level = graph_common.zoom_vals[pos+pos_offset][1]
      break
        end
      end
      pos = pos + 1
    end
    return new_zoom_level
  end

 -- ##############################################

local graph_menu_entries = {}

-- Menu entries are either populated by printSeries (optimized) or directly by
-- calling this function. In the latter case it is mandatory to check that the
-- series actually exist before calling this function.
--
-- The rule which determines how an entry is show is:
--    - If no timeseries exist at all for the entry, the entry will not be shown
--    - If the visualized interval is less then the entry timseries step, then
--      the entry will be shown but will be grayed out (disabled state)
--    - If timeseries exist for the entry in the visualized interval, the
--      entry will be shown and will be clickable
function graph_common.populateGraphMenuEntry(label, base_url, params, tab_id, needs_separator, separator_label, pending, extra_params, serie)
   local url = getPageUrl(base_url, params)
   local step = nil

   -- table.clone needed as entry_params is modified below
   local entry_params = table.clone(params)
   for k, v in pairs(splitUrl(base_url).params) do
      entry_params[k] = v
   end

   if(params.ts_schema ~= nil) then
      step = graph_common.getEntryStep(params.ts_schema)
   end

   local entry = {
      label = label,
      schema = params.ts_schema,
      params = entry_params, -- for graph_common.graphMenuGetActive
      url = url,
      tab_id = tab_id,
      needs_separator = needs_separator,
      separator_label = separator_label,
      pending = pending, -- true for batched operations
      step = step,
      extra_params = extra_params,
      graph_options = serie,
   }

   graph_menu_entries[#graph_menu_entries + 1] = entry
   return entry
end

-- ########################################################

function graph_common.makeMenuDivider()
   return '<div class="dropdown-divider"></div>'
end

-- ########################################################

function graph_common.makeMenuHeader(label)
   return '<li class="dropdown-header">'.. label ..'</li>'
end

-- ##############################################

function graph_common.graphMenuDivider()
   graph_menu_entries[#graph_menu_entries + 1] = {html=graph_common.makeMenuDivider()}
end

-- ##############################################

function graph_common.graphMenuHeader(label)
   graph_menu_entries[#graph_menu_entries + 1] = {html=graph_common.makeMenuHeader(label)}
end

-- ##############################################

function graph_common.graphMenuGetActive(schema, params)
   -- These tags are used to determine the active timeseries entry
   local match_tags = {ts_schema=1, ts_query=1, protocol=1, category=1, snmp_port_idx=1, exporter_ifname=1, l4proto=1, command=1, dscp_class=1}
   for _, entry in pairs(graph_menu_entries) do
      local extra_params = entry.extra_params or {}

      if entry.schema == schema and entry.params then
	 for k, v in pairs(params) do
	    if (match_tags[k] or extra_params[k]) and tostring(entry.params[k]) ~= tostring(v) then
	       goto continue
	    end
	 end

	 return entry
      end

      ::continue::
   end

   return nil
end

-- ########################################################

local function ignoreEntry(entry)
   return(entry.pending and (entry.pending > 0))
end

-- ########################################################

-- To be called after the menu has been populated. Returns the
-- min step of the entries.
function graph_common.getMinGraphEntriesStep()
   local min_step = nil

   for _, entry in pairs(graph_menu_entries) do
      if(not ignoreEntry(entry) and (entry.step)) then
	 if(min_step == nil) then
	    min_step = entry.step
	 else
	    min_step = math.min(entry.step, min_step)
	 end
      end
   end

   return(min_step)
end

-- ##############################################

function graph_common.getEntryStep(schema_name)
   if(starts(schema_name, "custom:") and (getCustomSchemaStep ~= nil)) then
      return(getCustomSchemaStep(schema_name))
   end

   if(starts(schema_name, "top:")) then
      schema_name = split(schema_name, "top:")[2]
   end

   local schema_obj = ts_utils.getSchema(schema_name)

   if(schema_obj) then
      return(schema_obj.options.step)
   end

   return(nil)
end

-- ########################################################

function graph_common.printEntry(idx, entry)
   local parts = {}

   parts[#parts + 1] = [[<a class='dropdown-item' href="]] .. entry.url .. [[" ]]

   if not isEmptyString(entry.tab_id) then
      parts[#parts + 1] = [[id="]] .. entry.tab_id .. [[" ]]
   end

   parts[#parts + 1] = [[> ]] .. entry.label .. [[</a>]]

   print(table.concat(parts, ""))
end

-- ########################################################

-- Prints the menu from the populated graph_menu_entries.
-- The entry_print_callback is called to print the actual entries.
function graph_common.printGraphMenuEntries(entry_print_callback, active_entry, start_time, end_time)
   local active_entries = {}
   local active_idx = 1 -- index in active_entries
   local tdiff = (end_time - start_time)

   -- Sort entries based on label, preserving groups
   local graph_menu_entries_sorted = {}
   local sort_table = {}
   local needs_separator = false
   local separator_label = nil
   local first
   for _, entry in ipairs(graph_menu_entries) do
     if entry.needs_separator 
        or entry.label == nil -- divider
     then
       -- sort group
       first = true
       for k,v in pairsByKeys(sort_table) do
         if first then
           v.needs_separator = needs_separator
           v.separator_label = separator_label
           first = false
         end
         graph_menu_entries_sorted[#graph_menu_entries_sorted+1] = v
       end

       -- backup group separator, if any
       needs_separator = entry.needs_separator or false
       separator_label = entry.separator_label
       -- reset group separator on this item
       entry.needs_separator = false
       entry.separator_label = nil

       -- append
       sort_table = {}
       if entry.label == nil then -- divider
         graph_menu_entries_sorted[#graph_menu_entries_sorted+1] = entry
       else
         sort_table[entry.label] = entry
       end
     else
       -- append
       sort_table[entry.label] = entry
     end
   end
   -- sort group
   first = true
   for k,v in pairsByKeys(sort_table) do
      if first then
         v.needs_separator = needs_separator
         v.separator_label = separator_label
         first = false
      end
      graph_menu_entries_sorted[#graph_menu_entries_sorted+1] = v
   end

   -- Print entries
   needs_separator = false
   separator_label = nil
   for _, entry in ipairs(graph_menu_entries_sorted) do

      if active_idx ~= 1 then
	 needs_separator = needs_separator or entry.needs_separator
	 separator_label = separator_label or entry.separator_label
      end

      if(entry.step) then
	 entry.disabled = (tdiff <= entry.step)
      end

      if(active_entry == entry) then
	 -- Always consider the selected entry as active
	 entry.pending = 0
      end

      if(ignoreEntry(entry)) then
	 -- not verified, act like it does not exist
	 goto continue
      end

      if(needs_separator) then
	 print(graph_common.makeMenuDivider())
	 needs_separator = false
      end
      if(separator_label) then
	 print(graph_common.makeMenuHeader(separator_label))
	 separator_label = nil
      end

      if entry.html then
	   print(entry.html)
      else
	 entry_print_callback(active_idx, entry)
	 active_entries[#active_entries + 1] = entry
	 active_idx = active_idx + 1
      end

      ::continue::
   end

   -- NOTE: only return the graph_menu_entries which are non-pending
   return active_entries
end

-- ##############################################

function graph_common.printSeries(options, tags, start_time, end_time, base_url, params)
   local series = options.timeseries
   local needs_separator = false
   local separator_label = nil
   local batch_id_to_entry = {}
   local device_timeseries_mac = options.device_timeseries_mac
   local mac_tags = nil
   local mac_params = nil
   local mac_baseurl = ntop.getHttpPrefix() .. "/lua/mac_details.lua?page=historical"
   local is_pro = ntop.isPro()
   local is_enterprise = ntop.isEnterpriseM()
   local tdiff = (end_time - start_time)

   if params.tskey then
      -- this can contain a MAC address for local broadcast domain hosts
      -- table.clone needed as tags is modified below
      tags = table.clone(tags)
      tags.host = params.tskey
   end

   if(device_timeseries_mac ~= nil) then
      -- table.clone needed as mac_tags is modified below
      mac_tags = table.clone(tags)
      mac_tags.host = nil
      mac_tags.mac = device_timeseries_mac
      -- table.clone needed as mac_params is modified below
      mac_params = table.clone(params)
      mac_params.host = device_timeseries_mac
   end

   for _, serie in ipairs(series) do
      if ((have_nedge and serie.nedge_exclude) or (not have_nedge and serie.nedge_only)) or
	 (serie.pro_skip and is_pro) or
	 (serie.skip) or
      (serie.enterprise_only and (not is_enterprise)) then
	 goto continue
      end

      local query_start = start_time

      if(serie.schema ~= nil) then
	 local step = graph_common.getEntryStep(serie.schema)

	 if step and (tdiff <= step) then
	    -- This entry will not be clickable but maybe it will be
	    -- shown in disabled state if any data for it exists, so
	    -- remove the time constraint
	    query_start = 0
	 end
      end

      if serie.separator then
	 needs_separator = true
	 separator_label = serie.label
      else
	 local k = serie.schema
	 local v = serie.label
	 local exists = false
	 local entry_tags = tags
	 local entry_params = table.merge(params, serie.extra_params)
	 local entry_baseurl = base_url
	 local override_link = nil

	 -- Contains the list of batch_ids to be associated to this menu entry.
	 -- The entry can only be shown when all the batch_ids have been confirmed
	 -- in getBatchedListSeriesResult
	 local batch_ids = {}

	 if starts(k, "custom:") then
	    if not ntop.isPro() then
	       goto continue
	    end

	    -- exists by default, otherwise specify a serie.check below
	    exists = true

	    if(serie.custom_schema == nil) then
	       serie.custom_schema = graph_common.getCustomSchemaOptions(k)
	    end
	 end

	 local to_check = serie.check or (serie.custom_schema and serie.custom_schema.bases)

	 if(to_check ~= nil) then
	    exists = true

	    -- In the case of custom series, the serie can only be shown if all
	    -- the component series exists
	    for idx, serie in pairs(to_check) do
	       local exist_tags = tags

	       if starts(k, "custom:") then
		  exist_tags = graph_common.getCustomSchemaTags(k, exist_tags, idx)
	       end

	       local batch_id = ts_utils.batchListSeries(serie, table.merge(exist_tags, serie.extra_params), query_start)

	       if batch_id == nil then
		  exists = false
		  break
	       end

	       batch_ids[#batch_ids +1] = batch_id
	    end
	 elseif not exists then
	    if(mac_tags ~= nil) and (starts(k, "mac:")) then
	       -- This is a mac timeseries shown under the host
	       entry_tags = mac_tags
	       entry_params = mac_params
	       entry_baseurl = mac_baseurl
	    end

	    -- only show if there has been an update within the specified time frame
	    local batch_id = ts_utils.batchListSeries(k, table.merge(entry_tags, serie.extra_params), query_start)

	    if batch_id ~= nil then
	       -- assume it exists for now, will verify in getBatchedListSeriesResult
	       exists = true
	       batch_ids[#batch_ids +1] = batch_id
	    end
	 end

	 if exists then
	    local entry = graph_common.populateGraphMenuEntry(v, entry_baseurl, table.merge(entry_params, {ts_schema=k}), nil,
							      needs_separator, separator_label, #batch_ids --[[ pending ]], serie.extra_params, serie)

	    if entry then
	       for _, batch_id in pairs(batch_ids) do
		  batch_id_to_entry[batch_id] = entry
	       end
	    end

	    needs_separator = false
	    separator_label = nil
	 end
      end

      ::continue::
   end

   -- DSCP
   if options.dscp_classes then
      local schema = options.dscp_classes
      -- table.clone needed as dscp_tags is modified below
      local dscp_tags = table.clone(tags)
      dscp_tags.dscp_class = nil

      local series = ts_utils.listSeries(schema, dscp_tags, start_time)

      if not table.empty(series) then
	 graph_common.graphMenuDivider()
	 graph_common.graphMenuHeader(i18n("dscp"))

	 local by_class = {}
	 for _, serie in pairs(series) do
	    local sortkey = serie.dscp_class

	    if sortkey == "unknown" then
	       -- place at the end
	       sortkey = "z" .. sortkey
	    end

	    by_class[sortkey] = serie.dscp_class
	 end

	 for _, class in pairsByKeys(by_class, asc) do
	    local label = dscp_consts.ds_class_descr(class)
	    graph_common.populateGraphMenuEntry(label, base_url, table.merge(params, {ts_schema=schema, dscp_class=class}))
	 end
      end
   end

   -- nDPI applications
   if options.top_protocols then
      local schema = split(options.top_protocols, "top:")[2]
      -- table.clone needed as proto_tags is modified below
      local proto_tags = table.clone(tags)
      proto_tags.protocol = nil

      local series = ts_utils.listSeries(schema, proto_tags, start_time)

      if not table.empty(series) then
	 graph_common.graphMenuDivider()
	 graph_common.graphMenuHeader(i18n("applications"))

	 local by_protocol = {}

	 for _, serie in pairs(series) do
	    by_protocol[serie.protocol] = 1
	 end

	 for protocol in pairsByKeys(by_protocol, asc_insensitive) do
	    local proto_id = protocol
	    graph_common.populateGraphMenuEntry(protocol, base_url, table.merge(params, {ts_schema=schema, protocol=proto_id}))
	 end
      end
   end

   -- L4 protocols
   if options.l4_protocols then
      local schema = options.l4_protocols
      -- table.clone needed as l4_tags is modified below
      local l4_tags = table.clone(tags)
      l4_tags.l4proto = nil

      local series = ts_utils.listSeries(schema, l4_tags, start_time)

      if not table.empty(series) then
	 graph_common.graphMenuDivider()
	 graph_common.graphMenuHeader(i18n("protocols"))

	 local by_protocol = {}

	 for _, serie in pairs(series) do
	    local sortkey = serie.l4proto

	    if sortkey == "other_ip" then
	       -- place at the end
	       sortkey = "z" .. sortkey
	    end

	    by_protocol[sortkey] = serie.l4proto
	 end

	 for _, protocol in pairsByKeys(by_protocol, asc_insensitive) do
	    local proto_id = protocol
	    local label

	    if proto_id == "other_ip" then
	       label = i18n("other")
	    else
	       label = string.upper(protocol)
	    end

	    graph_common.populateGraphMenuEntry(label, base_url, table.merge(params, {ts_schema=schema, l4proto=proto_id}))
	 end
      end
   end

   -- nDPI application categories
   if options.top_categories then
      local schema = split(options.top_categories, "top:")[2]
      -- table.clone needed as cat_tags is modified below
      local cat_tags = table.clone(tags)
      cat_tags.category = nil
      local series = ts_utils.listSeries(schema, cat_tags, start_time)

      if not table.empty(series) then
	 graph_common.graphMenuDivider()
	 graph_common.graphMenuHeader(i18n("categories"))

	 local by_category = {}

	 for _, serie in pairs(series) do
	    by_category[getCategoryLabel(serie.category)] = serie.category
	 end

	 for label, category in pairsByKeys(by_category, asc_insensitive) do
	    graph_common.populateGraphMenuEntry(label, base_url, table.merge(params, {ts_schema=schema, category=category}))
	 end
      end
   end

   -- Perform the batched operations
   local result = ts_utils.getBatchedListSeriesResult()

   for batch_id, res in pairs(result) do
      local entry = batch_id_to_entry[batch_id]

      if entry and not table.empty(res) and entry.pending then
	 -- entry exists, decrement the number of pending requests
	 entry.pending = entry.pending - 1
      end
   end
end

-- ###############################################

--- Load additiona custom schemas
-- See README.charts for an explanation
local locally_defined_custom_schemas = {
   ["custom:flows_vs_local_hosts"] = {
      bases = {"iface:flows", "iface:local_hosts"},
      types = {"line", "bar"},
      axis = {1,2},
   }, ["custom:flows_vs_traffic"] = {
      bases = {"iface:traffic", "iface:flows"},
      types = {"line", "bar"},
      axis = {1,2},
   }, ["custom:memory_vs_flows_hosts"] = {
      bases = {"process:resident_memory", "iface:flows", "iface:hosts"},
      types = {"line", "bar", "bar"},
      axis = {1,2,2},
      exclude = {virtual_bytes=1},
      tags_override = {{ifid=getSystemInterfaceId()},},
   }, ["custom:snmp_traffic_vs_errors"] = {
      bases = {"snmp_if:traffic", "snmp_if:errors"},
      types = {"line", "bar"},
      axis = {1,2},
   }, ["custom:host_ndpi_and_flows"] = {
      bases = {"host:ndpi", "host:ndpi_flows"},
      types = {"line", "bar"},
      axis = {1,2},
   }, ["custom:iface_ndpi_and_flows"] = {
      bases = {"iface:ndpi", "iface:ndpi_flows"},
      types = {"line", "bar"},
      axis = {1,2},
   }, ["custom:zmq_msg_rcvd_vs_drops"] = {
      bases = {"iface:zmq_rcvd_msgs", "iface:zmq_msg_drops"},
      types = {"area", "area"},
      axis = {1,2},
   }, ["custom:iface_tcp_syn_vs_tcp_synack"] = {
      bases = {"iface:tcp_syn", "iface:tcp_synack"},
      types = {"area", "area"},
      axis = {1,1},
   }, ["custom:flow_script:stats"] = {
      bases = {"flow_script:skipped_calls", "flow_script:pending_calls", "flow_script:successful_calls"},
      types = {"area", "area", "line"},
      axis = {1, 1, 1},
   }, ["custom:flow_check:vs_total"] = {
      bases = {"flow_check:duration", "flow_check:total_stats", "flow_check:num_calls"},
      types = {"line", "line", "bar"},
      axis = {1, 1, 2},
      tags_ignore = {nil, {check=1}},
      exclude = {nil, {num_calls=1}},
   }, ["custom:elem_check:vs_total"] = {
      bases = {"elem_check:duration", "elem_check:total_stats", "elem_check:num_calls"},
      types = {"line", "line", "bar"},
      axis = {1, 1, 2},
      tags_ignore = {nil, {check=1}},
      exclude = {nil, {num_calls=1}},
   }, ["custom:flow_check:total_stats"] = {
      bases = {"flow_check:total_stats"},
      types = {"line"},
      axis = {1},
      tags_ignore = {nil, {check=1}},
      exclude = {num_calls=1},
   },
}

-- ##############################################

function graph_common.getCustomSchemaOptions(schema_id)
   return(locally_defined_custom_schemas[schema_id] or ts_utils.custom_schemas[schema_id])
end

-- ##############################################

local function getCustomSchemaStep(schema_id)
   local schema_options = graph_common.getCustomSchemaOptions(schema_id)

   if((schema_options ~= nil) and (schema_options.bases[1])) then
      local schema_obj = ts_utils.getSchema(schema_options.bases[1])

      if(schema_obj ~= nil) then
         return(schema_obj.options.step)
      end
   end

   return(nil)
end

-- ##############################################

function graph_common.getCustomSchemaTags(schema_id, query_tags, base_idx)
   local tags = query_tags
   local schema_options = graph_common.getCustomSchemaOptions(schema_id)

   if(not schema_options) then
      return(tags)
   end

   if schema_options.tags_override and schema_options.tags_override[base_idx] then
      -- table.clone needed tags is modified below
      tags = table.clone(tags)

      for tag, override in pairs(schema_options.tags_override[base_idx]) do
         tags[tag] = override
      end
   end

   if schema_options.tags_ignore and schema_options.tags_ignore[base_idx] then
      -- table.clone needed tags is modified below
      tags = table.clone(tags)

      for tag in pairs(schema_options.tags_ignore[base_idx]) do
         tags[tag] = nil
      end
   end

   return(tags)
end

return graph_common
