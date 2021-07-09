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
local tag_utils = require "tag_utils"

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
   local is_client = ternary(alert.is_client, 1, 0)
   local is_server = ternary(alert.is_server, 1, 0)
   local ip_version = alert.ip_version
   local ip = alert.ip
   local vlan_id = alert.vlan_id

   if not ip then -- Compatibility with Lua alerts
      local host_info = hostkey2hostinfo(alert.entity_val)
      ip = host_info.host
      vlan_id = host_info.vlan
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, ip_version, ip, vlan_id, name, is_attacker, is_victim, is_client, is_server, tstamp, tstamp_end, severity, score, granularity, json) "..
      "VALUES (%u, %u, '%s', %u, '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      ip_version,
      ip,
      vlan_id or 0,
      self:_escape(alert.name),
      is_attacker,
      is_victim,
      is_client,
      is_server,
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
   local where_clause = self:build_where_clause()

   local q = string.format("SELECT ip, name, vlan_id, count(*) count FROM %s WHERE %s GROUP BY ip ORDER BY count DESC LIMIT %u",
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

--@brief Add ip filter
function host_alert_store:add_ip_filter(ip)
   self:add_filter_condition('ip', 'eq', ip);
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function host_alert_store:_add_additional_request_filters()
   local vlan_id = _GET["vlan_id"]
   local ip_version = _GET["ip_version"]
   local ip = _GET["ip"]
   local role = _GET["role"]
   local role_cli_srv = _GET["role_cli_srv"]

   self:add_filter_condition_list('vlan_id', vlan_id, 'number')
   self:add_filter_condition_list('ip_version', ip_version)
   self:add_filter_condition_list('ip', ip)
   self:add_filter_condition_list('host_role', role)
   self:add_filter_condition_list('role_cli_srv', role_cli_srv)
end

-- ##############################################

--@brief Get info about additional available filters
function host_alert_store:_get_additional_available_filters()
   local filters = {
      ip_version = {
         value_type = 'ip_version',
	 i18n_label = i18n('tags.ip_version'),
      },
      ip = {
         value_type = 'ip',
	 i18n_label = i18n('tags.ip'),
      },
      role = {
	 value_type = 'role',
	 i18n_label = i18n('tags.role'),
      },
      role_cli_srv = {
	 value_type = 'role_cli_srv',
	 i18n_label = i18n('tags.role_cli_srv'),
      },
   }

   return filters
end 

-- ##############################################

local RNAME = {
   IP = { name = "ip", export = true},
   IS_VICTIM = { name = "is_victim", export = true},
   IS_ATTACKER = { name = "is_attacker", export = true},
   IS_CLIENT = { name = "is_client", export = true},
   IS_SERVER = { name = "is_server", export = true},
   VLAN_ID = { name = "vlan_id", export = true},
   ALERT_NAME = { name = "alert_name", export = true},
   DESCRIPTION = { name = "description", export = true},
   MSG = { name = "msg", export = true, elements = {"name", "value", "description"}}
}

function host_alert_store:get_rnames()
   return RNAME
end

--@brief Convert an alert coming from the DB (value) to an host_info table
function host_alert_store:_alert2hostinfo(value)
   return {ip = value["ip"], vlan = value["vlan_id"], name = value["name"]}
end

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function host_alert_store:format_record(value, no_html)
   local href_icon = "<i class='fas fa-laptop'></i>"
   local record = self:format_json_record_common(value, alert_entities.host.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.host.entity_id)
   local alert_fullname = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true, alert_entities.host.entity_id)
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
   record[RNAME.IP.name]["label"] = hostinfo2label(self:_alert2hostinfo(value), true --[[ Show VLAN --]])

   record[RNAME.IS_VICTIM.name] = ""
   record[RNAME.IS_ATTACKER.name] = ""
   record[RNAME.IS_CLIENT.name] = ""
   record[RNAME.IS_SERVER.name] = ""

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

   if value["is_client"] == true or value["is_client"] == "1" then
      if no_html then
         record[RNAME.IS_CLIENT.name] = tostring(true) -- when no_html is enabled a default value must be present
      else
         record[RNAME.IS_CLIENT.name] = '<i class="fas fa-long-arrow-alt-right"></i>'
         record["role_cli_srv"] = {
           label = i18n("client"),
           value = "client",
         }
      end
   elseif no_html then
      record[RNAME.IS_CLIENT.name] = tostring(false)  -- when no_html is enabled a default value must be present
   end

   if value["is_server"] == true or value["is_server"] == "1" then
      if no_html then
         record[RNAME.IS_SERVER.name] = tostring(true) -- when no_html is enabled a default value must be present
      else
         record[RNAME.IS_SERVER.name] = '<i class="fas fa-long-arrow-alt-left"></i>'
         record["role_cli_srv"] = {
           label = i18n("server"),
           value = "server",
         }
      end
   elseif no_html then
      record[RNAME.IS_SERVER.name] = tostring(false)  -- when no_html is enabled a default value must be present
   end

   record[RNAME.VLAN_ID.name] = value["vlan_id"] or 0

   record[RNAME.ALERT_NAME.name] = alert_name

   record[RNAME.DESCRIPTION.name] = msg

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   if no_html then
      msg = noHtml(msg)
   end

   record[RNAME.MSG.name] = {
     name = noHtml(alert_name),
     fullname = alert_fullname,
     value = tonumber(value["alert_id"]),
     description = msg,
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info, value)
   }

   return record
end

-- ##############################################

return host_alert_store
