--
-- (C) 2020-24 - ntop.org
--

-- Module for sharred methods between community graph_utils.lua

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
    { "10m",  "now-600s", 60*10},
    { "30m", "now-1800s", 60*30},
    { "1h",  "now-1h",   60*60*1},
    { "2h",  "now-2h",   60*60*2},
    { "3h",  "now-3h",   60*60*3},
    { "6h",  "now-6h",   60*60*6},
    -- 12h does not compare the previous 12 hours, but the same 
    -- time window from the previous day
    { "12h", "now-12h",  60*60*24},
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
      	   if (match_tags[k] or extra_params[k]) and (entry.params[k]) and (tostring(entry.params[k]) ~= tostring(v)) then
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

-- ##############################################

return graph_common
