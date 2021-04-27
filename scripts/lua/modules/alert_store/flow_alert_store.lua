--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
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

local flow_alert_store = classes.class(alert_store)

-- ##############################################

function flow_alert_store:init(args)
   self.super:init()

   self._table_name = "flow_alerts"
   self._alert_entity = alert_entities.flow
end

-- ##############################################

function flow_alert_store:insert(alert)
   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, cli_ip, srv_ip, cli_port, srv_port, vlan_id, "..
      "is_attacker_to_victim, is_victim_to_attacker, proto, l7_proto, l7_master_proto, l7_cat, "..
      "cli_name, srv_name, cli_country, srv_country, cli_blacklisted, srv_blacklisted, "..
      "cli2srv_bytes, srv2cli_bytes, cli2srv_pkts, srv2cli_pkts, first_seen, community_id, score, "..
      "flow_risk_bitmap, json) "..
      "VALUES (%u, %u, %u, %u, '%s', '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s', '%s', '%s', "..
      "'%s', %u, %u, %u, %u, %u, %u, %u, '%s', %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp,
      alert.severity,
      alert.cli_addr,
      alert.srv_addr,
      alert.cli_port,
      alert.srv_port,
      alert.vlan_id,
      ternary(alert.is_cli_attacker, 1, 0),
      ternary(alert.is_srv_attacker, 1, 0),
      alert.proto,
      alert.l7_proto,
      alert.l7_master_proto,
      alert.l7_cat,
      self:_escape(alert.cli_name),
      self:_escape(alert.srv_name),
      alert.cli_country_name,
      alert.srv_country_name,
      ternary(alert.cli_blacklisted, 1, 0),
      ternary(alert.srv_blacklisted, 1, 0),
      alert.cli2srv_bytes,
      alert.srv2cli_bytes,
      alert.cli2srv_packets,
      alert.srv2cli_packets,
      alert.first_seen,
      alert.community_id,
      alert.score,
      alert.flow_risk_bitmap or 0,
      self:_escape(alert.json)
   )

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters on client host address
--@param ip The host IP
--@return True if set is successful, false otherwise
function flow_alert_store:add_cli_ip_filter(ip)
   if not self._cli_ip then
      self._cli_ip = ip
      self._where[#self._where + 1] = string.format("cli_ip = '%s'", self._cli_ip)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters on server host address
--@param ip The host IP
--@return True if set is successful, false otherwise
function flow_alert_store:add_srv_ip_filter(ip)
   if not self._srv_ip then
      self._srv_ip = ip
      self._where[#self._where + 1] = string.format("srv_ip = '%s'", self._srv_ip)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters on host address, either as client or as server
--@param ip The host IP
--@return True if set is successful, false otherwise
function flow_alert_store:add_ip_filter(ip)
   if not self._ip then
      self._ip = ip
      self._where[#self._where + 1] = string.format("(srv_ip = '%s' OR cli_ip = '%s')", self._ip, self._ip)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters on VLAN ID
--@param vlan_id The VLAN ID
--@return True if set is successful, false otherwise
function flow_alert_store:add_vlan_id_filter(vlan_id)
   if not self._vlan_id and tonumber(vlan_id) then
      self._vlan_id = tonumber(vlan_id)
      self._where[#self._where + 1] = string.format("vlan_id = %u", self._vlan_id)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters on L7 Proto
--@param l7_proto The l7 proto
--@return True if set is successful, false otherwise
function flow_alert_store:add_l7_proto_filter(l7_proto)
   if not self._l7_proto then
      if not tonumber(l7_proto) then
         -- Try converting l7 proto name to number
         l7_proto = interface.getnDPIProtoId(l7_proto)
      end
      if tonumber(l7_proto) then
         self._l7_proto = tonumber(l7_proto)
         self._where[#self._where + 1] = string.format("l7_proto = %u", self._l7_proto)
         return true
      end
   end

   return false
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function flow_alert_store:_add_additional_request_filters()
   local cli_ip = _GET["cli_ip"]
   local srv_ip = _GET["srv_ip"]
   local vlan_id = _GET["vlan_id"]
   local l7_proto = _GET["l7_proto"]

   if not isEmptyString(vlan_id) then
      local vlan_id, op = self:strip_filter_operator(vlan_id)
      self:add_vlan_id_filter(vlan_id)
   end

   if not isEmptyString(cli_ip) then
      local ip, op = self:strip_filter_operator(cli_ip)
      local host = hostkey2hostinfo(ip)
      if not isEmptyString(host["host"]) then
         self:add_cli_ip_filter(host["host"])
      end
      if not isEmptyString(host["vlan"]) then
         self:add_vlan_id_filter(host["vlan"])
      end
   end

   if not isEmptyString(srv_ip) then
      local ip, op = self:strip_filter_operator(srv_ip)
      local host = hostkey2hostinfo(ip)
      if not isEmptyString(host["host"]) then
         self:add_srv_ip_filter(host["host"])
      end
      if not isEmptyString(host["vlan"]) then
         self:add_vlan_id_filter(host["vlan"])
      end
   end

   if not isEmptyString(l7_proto) then
      local l7_proto, op = self:strip_filter_operator(l7_proto)
      self:add_l7_proto_filter(l7_proto)
   end
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function flow_alert_store:format_record(value)
   local record = self:format_record_common(value, alert_entities.flow.entity_id)

   local score = tonumber(value["score"])
   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.flow.entity_id)
   local msg = alert_utils.formatFlowAlertMessage(ifid, value, alert_info)
   local application =  interface.getnDPIProtoName(tonumber(value["l7_proto"]))

   record["alert_name"] = alert_name
   record["score"] = score
   record["msg"] = msg
   record["cli_name"] = value["cli_name"]
   record["srv_name"] = value["srv_name"]
   record["cli_ip"] = hostinfo2hostkey(value, "cli")
   record["srv_ip"] = hostinfo2hostkey(value, "srv")
   record["cli_port"] = value["cli_port"]
   record["srv_port"] = value["srv_port"]
   record["vlan_id"] = value["vlan_id"]
   record["proto"] = value["proto"]
   record["is_attacker_to_victim"] = value["is_attacker_to_victim"] == "1"
   record["is_victim_to_attacker"] = value["is_victim_to_attacker"] == "1"
   record["l7_proto"] = {
      value = value["l7_proto"],
      label = application
   }
   record["cli_url"] = hostinfo2detailshref({ip = value["cli_ip"], vlan = value["vlan_id"]}, nil, value["cli_ip"], "", true)
   record["srv_url"] = hostinfo2detailshref({ip = value["srv_ip"], vlan = value["vlan_id"]}, nil, value["srv_ip"], "", true)

   return record
end

-- ##############################################

return flow_alert_store
