--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

require "lua_utils"
local alert_store = require "alert_store"
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local alert_roles = require "alert_roles"
local json = require "dkjson"

-- ##############################################

local host_alert_store = classes.class(alert_store)

-- ##############################################

function host_alert_store:init(args)
   self.super:init()

   self._table_name = "host_alerts"
   self._alert_entity = alert_entities.host
end

-- ##############################################

function host_alert_store:insert(alert)
   local is_attacker = ternary(alert.is_attacker, 1, 0)
   local is_victim = ternary(alert.is_victim, 1, 0)
   local ip = alert.ip
   local vlan_id = alert.vlan_id

   if not ip then -- Compatibility with Lua alerts
      local host_info = hostkey2hostinfo(alert.entity_val)
      ip = host_info.host
      vlan_id = host_info.vlan
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, ip, vlan_id, name, is_attacker, is_victim, tstamp, tstamp_end, severity, score, granularity, json) "..
      "VALUES (%u, '%s', %u, '%s', %u, %u, %u, %u, %u, %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      ip,
      vlan_id or 0,
      self:_escape(alert.name),
      is_attacker,
      is_victim,
      alert.tstamp,
      alert.tstamp_end,
      ntop.mapScoreToSeverity(alert.score),
      alert.score,
      alert.granularity,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Performs a query for the top hosts by alert count
function host_alert_store:top_ip_historical()
   -- Preserve all the filters currently set
   local where_clause = table.concat(self._where, " AND ")

   local q = string.format("SELECT ip, count(*) count FROM %s WHERE %s GROUP BY ip ORDER BY count DESC LIMIT %u",
			   self._table_name, where_clause, self._top_limit)

   local q_res = interface.alert_store_query(q) or {}

   return q_res
end

-- ##############################################

--@brief Stats used by the dashboard
function host_alert_store:_get_additional_stats()
   local stats = {}
   stats.top = {}
   stats.top.ip = self:top_ip_historical()
   return stats
end

-- ##############################################

--@brief Add filters on host address
--@param ip The host IP
--@return True if set is successful, false otherwise
function host_alert_store:add_ip_filter(ip)
   if not self._ip then
      self._ip = ip
      self._where[#self._where + 1] = string.format("ip = '%s'", self._ip)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters on VLAN ID
--@param ip The VLAN ID
--@return True if set is successful, false otherwise
function host_alert_store:add_vlan_id_filter(vlan_id)
   if not self._vlan_id and tonumber(vlan_id) then
      self._vlan_id = tonumber(vlan_id)
      self._where[#self._where + 1] = string.format("vlan_id = %u", self._vlan_id)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filter on role
--@param role The role (attacker or victim)
--@return True if set is successful, false otherwise
function host_alert_store:add_role_filter(role)
   if not self._role then
      if role == 'attacker' then
	 self._role = alert_roles.alert_role_is_attacker.role_id
         self._where[#self._where + 1] = "is_attacker = 1"
      elseif role == 'victim' then
	 self._role = alert_roles.alert_role_is_victim.role_id
         self._where[#self._where + 1] = "is_victim = 1"
      end
      return true
   end

   return false
end


-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function host_alert_store:_add_additional_request_filters()
   local ip = _GET["ip"]
   local vlan_id = _GET["vlan_id"]
   local role = _GET["role"]

   if not isEmptyString(vlan_id) then
      local vlan_id, op = self:strip_filter_operator(vlan_id)
      self:add_vlan_id_filter(vlan_id)
   end

   if not isEmptyString(ip) then
      local ip, op = self:strip_filter_operator(ip)
      local host = hostkey2hostinfo(ip)
      self._entity_value = hostinfo2hostkey(host)

      if not isEmptyString(host["host"]) then
         self:add_ip_filter(host["host"])
      end
      if not isEmptyString(host["vlan"]) then
         self:add_vlan_id_filter(host["vlan"])
      end
   end

   if not isEmptyString(role) then
      local role, op = self:strip_filter_operator(role)
      self:add_role_filter(role)
   end
end

-- ##############################################

--@brief Get info about additional available filters
function host_alert_store:_get_additional_available_filters()
   local filters = {
      alert_id = {
         value_type = 'alert_id',
	 i18n_label = i18n('tags.alert_id'),
      }, 
      ip = {
         value_type = 'ip',
	 i18n_label = i18n('tags.ip'),
      },
      role = {
	 value_type = 'role',
	 i18n_label = i18n('tags.role'),
      },
   }

   return filters
end 

-- ##############################################

local RNAME = {
   IP = { name = "ip", export = true},
   IS_VICTIM = { name = "is_victim", export = true},
   IS_ATTACKER = { name = "is_attacker", export = true},
   VLAN_ID = { name = "vlan_id", export = true},
   ALERT_NAME = { name = "alert_name", export = true},
   MSG = { name = "msg", export = true, elements = {"name", "value"}}
}

function host_alert_store:get_rnames()
   return RNAME
end

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function host_alert_store:format_record(value, no_html)
   local href_icon = "<i class='fas fa-laptop'></i>"
   local record = self:format_json_record_common(value, alert_entities.host.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.host.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)
   local host = hostinfo2hostkey(value)
   local reference_html = nil

   reference_html = hostinfo2detailshref({ip = value["ip"], vlan = value["vlan_id"]}, nil, href_icon, "", true)
   if reference_html == href_icon then
      reference_html = nil
   end

   record[RNAME.IP.name] = {
      value = host,
      label = host,
      shown_label = host,
      reference = reference_html 
   }

   -- Checking that the name of the host is not empty
   if value["name"] and (not isEmptyString(value["name"])) then
      record[RNAME.IP.name]["label"] = value["name"]
   end

   record[RNAME.IP.name]["shown_label"] = record[RNAME.IP.name]["label"]
   record[RNAME.IS_VICTIM.name] = ""
   record[RNAME.IS_ATTACKER.name] = ""

   if value["is_victim"] == true or value["is_victim"] == "1" then
      if no_html then
         record[RNAME.IS_VICTIM.name] = tostring(true) -- when no_html is enabled a default value must be present
      else
         record[RNAME.IS_VICTIM.name] = '<i class="fas fa-sad-tear"></i>'
         record["role"] = {
            label = i18n("victim"),
            value = "victim",
          }
      end
   elseif no_html then
      record[RNAME.IS_VICTIM.name] = tostring(false) -- when no_html is enabled a default value must be present
   end

   if value["is_attacker"] == true or value["is_attacker"] == "1" then
      if no_html then
         record[RNAME.IS_ATTACKER.name] = tostring(true) -- when no_html is enabled a default value must be present
      else
         record[RNAME.IS_ATTACKER.name] = '<i class="fas fa-skull"></i>'
         record["role"] = {
           label = i18n("attacker"),
           value = "attacker",
         }
      end
   elseif no_html then
      record[RNAME.IS_ATTACKER.name] = tostring(false)  -- when no_html is enabled a default value must be present
   end

   record[RNAME.VLAN_ID.name] = value["vlan_id"] or 0

   record[RNAME.ALERT_NAME.name] = alert_name

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   record[RNAME.MSG.name] = {
     name = noHtml(alert_name),
     value = tonumber(value["alert_id"]),
     description = msg,
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info, value)
   }

   return record
end

-- ##############################################

return host_alert_store
