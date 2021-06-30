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
   local ip = alert.ip
   local vlan_id = alert.vlan_id

   if not ip then -- Compatibility with Lua alerts
      local host_info = hostkey2hostinfo(alert.entity_val)
      ip = host_info.host
      vlan_id = host_info.vlan
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, ip, vlan_id, name, is_attacker, is_victim, is_client, is_server, tstamp, tstamp_end, severity, score, granularity, json) "..
      "VALUES (%u, '%s', %u, '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
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
   local where_clause = table.concat(self._where, " AND ")

   local q = string.format("SELECT ip, name, count(*) count FROM %s WHERE %s GROUP BY ip ORDER BY count DESC LIMIT %u",
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
--@param values The host IP comma-separated list
--@return True if set is successful, false otherwise
function host_alert_store:add_ip_filter(values)
   if isEmptyString(values) then
      return false
   end

   local list = split(values, ',')

   for _, value_op in ipairs(list) do
      local value, op = self:strip_filter_operator(value_op)

      local host = hostkey2hostinfo(value)
      if not isEmptyString(host["host"]) then
         self:add_filter_condition('ip', op, host["host"])
         if not isEmptyString(host["vlan"]) then
            self:add_filter_condition('vlan_id', op, host["vlan"], 'number')
         end
         return true
      end
   end

   return false
end

-- ##############################################

--@brief Add filter on role
--@param role The role (attacker or victim)
--@return True if set is successful, false otherwise
function host_alert_store:add_role_filter(role)
   if not isEmptyString(role) then
      local role, op = self:strip_filter_operator(role)
      if not op or not tag_utils.tag_operators[op] then op = 'eq' end
      local sql_op = tag_utils.tag_operators[op]
      if role == 'attacker' then
         self:add_filter_condition_raw('role', string.format("is_attacker %s 1", sql_op))
      elseif role == 'victim' then
         self:add_filter_condition_raw('role', string.format("is_victim %s 1", sql_op))
      elseif role == 'no_attacker_no_victim' then
         self:add_filter_condition_raw('role', "(is_attacker = 0 AND is_victim = 0)")
      end
      return true
   end

   return false
end

-- ##############################################

--@brief Add filter on client/server role
--@param role_cli_srv The client/server role (client or server)
--@return True if set is successful, false otherwise
function host_alert_store:add_role_cli_srv_filter(role_cli_srv)
   if not isEmptyString(role_cli_srv) then
      local role_cli_srv, op = self:strip_filter_operator(role_cli_srv)
      if role_cli_srv == 'client' then
         self:add_filter_condition('is_client', op, 1, 'number')
      elseif role_cli_srv == 'server' then
         self:add_filter_condition('is_server', op, 1, 'number')
      end
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function host_alert_store:_add_additional_request_filters()
   local vlan_id = _GET["vlan_id"]
   local ip = _GET["ip"]
   local role = _GET["role"]
   local role_cli_srv = _GET["role_cli_srv"]

   self:add_filter_condition_list('vlan_id', vlan_id, 'number')

   -- Custom filters
   self:add_ip_filter(ip)
   self:add_role_filter(role)
   self:add_role_cli_srv_filter(role_cli_srv)
end

-- ##############################################

--@brief Get info about additional available filters
function host_alert_store:_get_additional_available_filters()
   local filters = {
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
     value = tonumber(value["alert_id"]),
     description = msg,
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info, value)
   }

   return record
end

-- ##############################################

return host_alert_store
