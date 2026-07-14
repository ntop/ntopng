--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local classes = require "classes"
local alert = require "alert"
local mitre = require "mitre_utils"
local alert_entities = require "alert_entities"
local format_utils = require "format_utils"

-- ##############################################

local alert_as_ranking_changed = classes.class(alert)

-- ##############################################

alert_as_ranking_changed.meta = {
   alert_key = other_alert_keys.alert_as_ranking_changed,
   i18n_title = "alerts_dashboard.as_ranking_changed",
   icon = "fas fa-exclamation-triangle",
   entities = {
      alert_entities.as,
   }

   -- Mitre Att&ck Matrix values
   -- mitre_values = {
   --   mitre_tactic =
   --   mitre_technique =
   --   mitre_id =
   -- }
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_as_ranking_changed:init(changes)
   self.super:init()
   self.alert_type_params = { changes = changes }
end

-- ##############################################

local function findPosition(ranking, exporter_ip, interface_id)
   for id, t in pairs(ranking) do
      if((ranking[id].exporter_ip == exporter_ip)
	 and (ranking[id].interface_id == interface_id)) then
	 return(id)
      end
   end

   return nil
end

-- ##############################################

local function formatRanking(ranking, prev_ranking, verbose, show_icons)
   local result = ""
   local skip_duplicates = false

   for id, t in pairs(ranking) do
      if(skip_duplicates
	 and (ranking[id].exporter_ip == prev_ranking[id].exporter_ip)
	 and (ranking[id].interface_id == prev_ranking[id].interface_id)) then
	 -- nothing changed
      elseif(t.exporter_ip ~= nil) then
	 local ex
	 local ifname
	 local volume = format_utils.bytesToSize(t.value)
	 local use_sym_names = true
	 local href

	 if(use_sym_names) then
	    ex = getExporterName(t.exporter_ip, false) -- lua_utils_get.lua
	    ifname = format_portidx_name(t.exporter_ip, t.interface_id, true)  -- lua_utils_gui.lua
	 else
	    ex = t.exporter_ip
	    ifname = t.interface_id
	 end

	 href = ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_interface_details.lua?host=".. ntop.inet_ntoa(t.exporter_ip) .. "&snmp_port_idx=".. t.interface_id

	 if(show_rank) then ex = ex .. "[rank "..tostring(id).."]" end
	 ex = " <A HREF=\""..href.."\" target=\"_blank\">"..ex .. ":" .. ifname .. "</A>"

	 if(verbose) then
	    ex = ex .. " (".. volume ..")"
	 end

	 if(show_icons and verbose) then
	    local prev_pos = findPosition(prev_ranking, ranking[id].exporter_ip, ranking[id].interface_id)

	    if(prev_pos == nil) then
	       ex = ex .. ' [ <font color=blue><b>' .. i18n("new") .. '</b></font> ]'
	    else
	       local diff = prev_pos - id
	       local icon
	       
	       if(diff == 0) then
		  icon = '<font color=gray><b>=</b></font>'
	       elseif (diff > 0) then
		  icon = '<font color=green><b>+'..diff..'</b></font>'
	       else
		  icon = '<font color=red><b>'..diff..'</b></font>'
	       end
		  
	       ex = ex .. " [ " ..icon.." ] "
	    end
	 end

	 if(verbose) then
	    ex = ex .. "<br>\n"
	 end
	 
	 if result == "" then
	    result = ex -- set
	 else	    
	    if(verbose) then
	       result = result.." ".. ex .. "\n" -- append
	    else
	       result = result..",".. ex .. "\n"-- append
	    end
	 end
      end
   end

   if(result == "") then
      result = "<>"
   else
      if(verbose) then
	 result = "<br>" .. result
      end
   end

   return result
end

-- ##############################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_as_ranking_changed.format(ifid, alert, alert_type_params, local_explorer, verbose)
   local alert_consts = require("alert_consts")
   local changes = alert_type_params.changes or {}
   local direction

   current = formatRanking(changes.current or {},  changes.previous or {}, verbose, true)
   prev    = formatRanking(changes.previous or {}, changes.current or {},  verbose, false)

   if(changes.ingress_traffic) then
      direction = "Ingress"
   else
      direction = "Egress"
   end

   return i18n("alert_messages.alert_as_ranking_changed",
	       {
		  num_changes = changes.num_changes,
		  direction = direction,
		  current_ranking = current,
		  previous_ranking = prev
	       }
   )
end

-- #######################################################

return alert_as_ranking_changed
