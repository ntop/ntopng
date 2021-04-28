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

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, ip, vlan_id, name, is_attacker, is_victim, tstamp, tstamp_end, severity, granularity, json) "..
      "VALUES (%u, '%s', %u, '%s', %u, %u, %u, %u, %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.ip,
      alert.vlan_id,
      self:_escape(alert.symbolic_name),
      is_attacker,
      is_victim,
      alert.tstamp,
      alert.tstamp_end,
      alert.severity,
      alert.granularity,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
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

--@brief Add filters according to what is specified inside the REST API
function host_alert_store:_add_additional_request_filters()
   local ip = _GET["ip"]
   local vlan_id = _GET["vlan_id"]

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
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function host_alert_store:format_record(value)
   local record = self:format_record_common(value, alert_entities.host.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.host.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)
   local host = hostinfo2hostkey(value)
   local reference = nil
   
   if (interface.getHostMinInfo(host)).name then
      reference = "/lua/host_details.lua?host=" .. host
   end
   record["ip"] = {
      value = host,
      label = host,
      reference = reference
   }

   -- Checking that the name of the host is not empty
   if value["name"] and (not isEmptyString(value["name"])) then
      record["host"]["label"] = value["name"]
   end

   record["alert_name"] = alert_name
   record["is_attacker"] = value["is_attacker"] == "1"
   record["is_victim"] = value["is_victim"] == "1"
   record["vlan_id"] = value["vlan_id"] or 0
   record["msg"] = msg
   record["ip_url"] = hostinfo2detailshref({ip = value["ip"], vlan = value["vlan_id"]}, nil, value["ip"], "", true)

   return record
end

-- ##############################################

return host_alert_store
