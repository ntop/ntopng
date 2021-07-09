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
local alert_roles = require "alert_roles"
local tag_utils = require "tag_utils"
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
      "(alert_id, tstamp, tstamp_end, severity, ip_version, cli_ip, srv_ip, cli_port, srv_port, vlan_id, "..
      "is_cli_attacker, is_cli_victim, is_srv_attacker, is_srv_victim, proto, l7_proto, l7_master_proto, l7_cat, "..
      "cli_name, srv_name, cli_country, srv_country, cli_blacklisted, srv_blacklisted, "..
      "cli2srv_bytes, srv2cli_bytes, cli2srv_pkts, srv2cli_pkts, first_seen, community_id, score, "..
      "flow_risk_bitmap, alerts_map, json) "..
      "VALUES (%u, %u, %u, %u, %u, '%s', '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s', '%s', '%s', "..
      "'%s', %u, %u, %u, %u, %u, %u, %u, '%s', %u, %u, X'%s', '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp,
      ntop.mapScoreToSeverity(alert.score),
      alert.ip_version,
      alert.cli_ip,
      alert.srv_ip,
      alert.cli_port,
      alert.srv_port,
      alert.vlan_id,
      ternary(alert.is_cli_attacker, 1, 0),
      ternary(alert.is_cli_victim, 1, 0),
      ternary(alert.is_srv_attacker, 1, 0),
      ternary(alert.is_srv_victim, 1, 0),
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
      alert.alerts_map,
      self:_escape(alert.json)
   )

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Performs a query for the top client hosts by alert count
function flow_alert_store:top_cli_ip_historical()
   -- Preserve all the filters currently set
   local where_clause = self:build_where_clause()

   local q = string.format("SELECT cli_ip, vlan_id, cli_name, count(*) count FROM %s WHERE %s GROUP BY cli_ip ORDER BY count DESC LIMIT %u",
			   self._table_name, where_clause, self._top_limit)

   local q_res = interface.alert_store_query(q) or {}

   return q_res
end

-- ##############################################

--@brief Performs a query for the top server hosts by alert count
function flow_alert_store:top_srv_ip_historical()
   -- Preserve all the filters currently set
   local where_clause = self:build_where_clause()

   local q = string.format("SELECT srv_ip, vlan_id, srv_name, count(*) count FROM %s WHERE %s GROUP BY srv_ip ORDER BY count DESC LIMIT %u",
			   self._table_name, where_clause, self._top_limit)

   local q_res = interface.alert_store_query(q) or {}

   return q_res
end

-- ##############################################

--@brief Merge top clients and top servers to build a top hosts 
function flow_alert_store:top_ip_merge(top_cli_ip, top_srv_ip)
   local all_ip = {}
   local top_ip = {}
   local ip_names = {}

   for _, p in ipairs(top_cli_ip) do
      all_ip[p.cli_ip] = tonumber(p.count)
      ip_names[p.cli_ip] = {
         name = p.cli_name,
         vlan_id = p.vlan_id,
      }
   end 
   for _, p in ipairs(top_srv_ip) do
      all_ip[p.srv_ip] = (all_ip[p.srv_ip] or 0) + tonumber(p.count)
      ip_names[p.srv_ip] = {
         name = p.srv_name,
         vlan_id = p.vlan_id,
      }
   end 

   for ip, count in pairsByValues(all_ip, rev) do
      top_ip[#top_ip + 1] = {
         ip = ip,
         count = count,
         name = ip_names[ip]["name"],
         vlan_id = ip_names[ip]["vlan_id"],
      }
      if #top_ip >= self._top_limit then break end
   end

   return top_ip
end

-- ##############################################

--@brief Stats used by the dashboard
function flow_alert_store:_get_additional_stats()
   local stats = {}
   stats.top = {}
   stats.top.cli_ip = self:top_cli_ip_historical()
   stats.top.srv_ip = self:top_srv_ip_historical()
   stats.top.ip = self:top_ip_merge(stats.top.cli_ip, stats.top.srv_ip)
   return stats
end

-- ##############################################

--@brief Add filters on L7 Proto
--@param values The l7 proto comma-separated list
--@return True if set is successful, false otherwise
function flow_alert_store:add_l7_proto_filter(values)
   if isEmptyString(values) then
      return false
   end

   local list = split(values, ',')

   for _, value_op in ipairs(list) do
      local l7_proto, op = self:strip_filter_operator(value_op)

      if not tonumber(l7_proto) then
         -- Try converting l7 proto name to number
         l7_proto = interface.getnDPIProtoId(l7_proto)
      end

      if tonumber(l7_proto) then
         l7_proto = tonumber(l7_proto)
         self:add_filter_condition('l7_proto', op, l7_proto, 'number')
      end
   end

   return false
end

-- ##############################################

--@brief Add ip filter
function flow_alert_store:add_ip_filter(ip)
   self:add_filter_condition('ip', 'eq', ip);
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function flow_alert_store:_add_additional_request_filters()
   local ip_version = _GET["ip_version"]
   local ip = _GET["ip"]
   local cli_ip = _GET["cli_ip"]
   local srv_ip = _GET["srv_ip"]
   local cli_port = _GET["cli_port"]
   local srv_port = _GET["srv_port"]
   local vlan_id = _GET["vlan_id"]
   local l7_proto = _GET["l7_proto"]
   local role = _GET["role"]

   self:add_filter_condition_list('vlan_id', vlan_id, 'number')
   self:add_filter_condition_list('ip_version', ip_version)
   self:add_filter_condition_list('ip', ip)
   self:add_filter_condition_list('cli_ip', cli_ip)
   self:add_filter_condition_list('srv_ip', srv_ip)
   self:add_filter_condition_list('cli_port', cli_port, 'number')
   self:add_filter_condition_list('srv_port', srv_port, 'number')
   self:add_filter_condition_list('flow_role', role)
   self:add_filter_condition_list('l7_proto', l7_proto)

   self:add_l7_proto_filter(l7_proto)
end

-- ##############################################

--@brief Get info about additional available filters
function flow_alert_store:_get_additional_available_filters()
   local filters = {
      ip_version = {
         value_type = 'ip_version',
	 i18n_label = i18n('tags.ip_version'),
      },
      ip = {
         value_type = 'ip',
	 i18n_label = i18n('tags.ip'),
      },
      cli_ip = {
         value_type = 'ip',
	 i18n_label = i18n('tags.cli_ip'),
      },
      srv_ip = {
         value_type = 'ip',
	 i18n_label = i18n('tags.srv_ip'),
      },
      cli_port = {
         value_type = 'port',
	 i18n_label = i18n('tags.cli_port'),
      }, 
      srv_port = {
         value_type = 'port',
	 i18n_label = i18n('tags.srv_port'),
      },
      role = {
	 value_type = 'role',
	 i18n_label = i18n('tags.role'),
      },
      l7_proto = {
         value_type = 'l7_proto',
	 i18n_label = i18n('tags.l7_proto'),
      }, 
   }

   return filters
end 

-- ##############################################

local RNAME = {
   ADDITIONAL_ALERTS = { name = "additional_alerts", export = true},
   ALERT_NAME = { name = "alert_name", export = true},
   DESCRIPTION = { name = "description", export = true},
   MSG = { name = "msg", export = true, elements = {"name", "value", "description"}},
   FLOW = { name = "flow", export = true, elements = {"srv_ip.label", "srv_ip.value", "srv_port", "cli_ip.label", "cli_ip.value", "cli_port"}},
   VLAN_ID = { name = "vlan_id", export = true},
   PROTO = { name = "proto", export = true},
   L7_PROTO = { name = "l7_proto", export = true},
}

-- ##############################################

function flow_alert_store:get_rnames()
   return RNAME
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to an host_info table, either for the client or for the server
--@param value The alert as read from the database
--@param as_client A boolean indicating whether the hostinfo should be build for the client or for the server
function flow_alert_store:_alert2hostinfo(value, as_client)
   if as_client then
      return {ip = value["cli_ip"], vlan = value["vlan_id"], name = value["cli_name"]}
   else
      return {ip = value["srv_ip"], vlan = value["vlan_id"], name = value["srv_name"]}
   end
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function flow_alert_store:format_record(value, no_html)
   local href_icon = "<i class='fas fa-laptop'></i>"
   local record = self:format_json_record_common(value, alert_entities.flow.entity_id, no_html)
   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.flow.entity_id)
   local alert_fullname = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true, alert_entities.flow.entity_id)
   local l4_protocol = l4_proto_to_string(value["proto"])
   local l7_protocol =  interface.getnDPIFullProtoName(tonumber(value["l7_master_proto"]), tonumber(value["l7_proto"]))
   local show_cli_port = (value["cli_port"] ~= '' and value["cli_port"] ~= '0')
   local show_srv_port = (value["srv_port"] ~= '' and value["srv_port"] ~= '0')   
   local msg = alert_utils.formatFlowAlertMessage(ifid, value, alert_info)

   local active_url = ""
   local historical_url = ""

   local attacker = ""
   local victim = ""
   
   -- Add link to historical flow
   if interfaceHasNindexSupport() and not no_html then
      local op_suffix = tag_utils.SEPARATOR .. 'eq'
      local href = string.format('%s/lua/pro/nindex_query.lua?begin_epoch=%u&end_epoch=%u&cli_ip=%s%s&srv_ip=%s%s&cli_port=%s%s&srv_port=%s%s&l4proto=%%s',
         ntop.getHttpPrefix(), tonumber(value["first_seen"]), tonumber(value["tstamp_end"]), 
         value["cli_ip"], op_suffix,
         value["srv_ip"], op_suffix,
         ternary(show_cli_port, tostring(value["cli_port"]), ''), op_suffix,
         ternary(show_srv_port, tostring(value["srv_port"]), ''), op_suffix,
         l4_protocol, op_suffix)
      historical_url = href
   end

   -- Add link to active flow
   local alert_json = json.decode(value.json)
   if not no_html and alert_json then
      local active_flow = interface.findFlowByKeyAndHashId(alert_json["ntopng.key"], alert_json["hash_entry_id"])
      if active_flow and active_flow["seen.first"] < tonumber(value["tstamp"]) then
	 local href = string.format("%s/lua/flow_details.lua?flow_key=%u&flow_hash_id=%u",
            ntop.getHttpPrefix(), active_flow["ntopng.key"], active_flow["hash_entry_id"])
         active_url = href
      end
   end

   -- Unpack all flow alerts, iterating the alerts_map. The alerts_map is stored as an HEX.
   local other_alerts_by_score = {} -- Table used to keep messages ordered by score
   local additional_alerts = {}
   local nibble_num = 0 -- Current nibble being processed
   for alerts_map_nibble_id = #value.alerts_map, 1, -1 do
      -- Extract the nibble
      local alerts_map_hex_nibble = value.alerts_map:sub(alerts_map_nibble_id, alerts_map_nibble_id)
      -- Convert the HEX nibble into a decimal value
      local alerts_map_nibble = tonumber(alerts_map_hex_nibble, 16)

      if alerts_map_nibble > 0 then
	 for bit_num = 0, 7 do
	    -- Checks the bits set in this current nibble
	    local has_bit = alerts_map_nibble & (1 << bit_num) == (1 << bit_num)

	    if has_bit then -- The bit is set
	       -- The actual alert id is the bit number times the current byte multiplied by 8
	       local alert_id = math.floor(8 * nibble_num / 2) + bit_num

	       if alert_id ~= tonumber(value["alert_id"]) then -- Do not add the predominant alert to the list of additional alerts
		  local message = alert_consts.alertTypeLabel(alert_id, true, alert_entities.flow.entity_id)

		  local alert_score = ntop.getFlowAlertScore(alert_id)
		  if alert_score > 0 then
		     message = message .. string.format(" [%s: %s]",
							i18n("score"),
							format_utils.formatValue(alert_score))
		  end

		  if not other_alerts_by_score[alert_score] then
		     other_alerts_by_score[alert_score] = {}
		  end
		  other_alerts_by_score[alert_score][#other_alerts_by_score[alert_score] + 1] = message
		  additional_alerts[#additional_alerts + 1] = message
	       end
	    end
	 end
      end

      -- Increment the nibble
      nibble_num = nibble_num + 1
   end

   -- Print additional issues, sorted by score
   record[RNAME.ADDITIONAL_ALERTS.name] = ''
   local cur_additional_alert = 0
   for _, messages in pairsByKeys(other_alerts_by_score, rev) do
      for _, message in pairsByValues(messages, asc) do
	 local cur_msg = ''
	 if cur_additional_alert > 0 then
	    -- Every 4 issues print a newline
	    cur_msg = cur_additional_alert % 4 ~= 0 and ", " or "<br>"
	 end
	 cur_additional_alert = cur_additional_alert + 1

	 cur_msg = cur_msg..message
	 record[RNAME.ADDITIONAL_ALERTS.name] = record[RNAME.ADDITIONAL_ALERTS.name] ..cur_msg
      end
   end

   -- Host reference
   local cli_ip = hostinfo2hostkey(value, "cli")
   local srv_ip = hostinfo2hostkey(value, "srv")

   if no_html then
      msg = noHtml(msg)
   end

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
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info)
   }

   -- Format Client  
 
   local reference_html = "" 
   if not no_html then
      reference_html = hostinfo2detailshref({ip = value["cli_ip"], vlan = value["vlan_id"]}, nil, href_icon, "", true)
      if reference_html == href_icon then
	 reference_html = ""
      end
   end
  
   local flow_cli_ip = {
      value = cli_ip,
      label = cli_ip,
      reference = reference_html
   }

   flow_cli_ip["label"] = hostinfo2label(self:_alert2hostinfo(value, true --[[ As client --]]), true --[[ Show VLAN --]])

   -- Format Server
 
   reference_html = "" 
   if not no_html then
      reference_html = hostinfo2detailshref({ip = value["srv_ip"], vlan = value["vlan_id"]}, nil, href_icon, "", true)
      if reference_html == href_icon then
	 reference_html = ""
      end
   end

   local flow_srv_ip = {
      value = srv_ip,
      label = srv_ip,
      reference = reference_html
   }

   flow_srv_ip["label"] = hostinfo2label(self:_alert2hostinfo(value, false --[[ As server --]]), true --[[ Show VLAN --]])
   
   local flow_cli_port = value["cli_port"]
   local flow_srv_port = value["srv_port"]

   record[RNAME.FLOW.name] = {
      cli_ip = flow_cli_ip,
      srv_ip = flow_srv_ip,
      cli_port = flow_cli_port,
      srv_port = flow_srv_port,
      historical_url = historical_url,
      active_url = active_url
   }

   record[RNAME.VLAN_ID.name] = value["vlan_id"]
   record[RNAME.PROTO.name] = {
      value = value["proto"],
      label = l4_protocol
   }

   if value["is_cli_victim"]   == "1" then record["cli_role"] = { value = 'victim',   label = i18n("victim"),   tag_label = i18n("victim") } end
   if value["is_cli_attacker"] == "1" then record["cli_role"] = { value = 'attacker', label = i18n("attacker"), tag_label = i18n("attacker") } end
   if value["is_srv_victim"]   == "1" then record["srv_role"] = { value = 'victim',   label = i18n("victim"),   tag_label = i18n("victim") } end
   if value["is_srv_attacker"] == "1" then record["srv_role"] = { value = 'attacker', label = i18n("attacker"), tag_label = i18n("attacker") } end

   record[RNAME.L7_PROTO.name] = {
      value = ternary(tonumber(value["l7_proto"]) ~= 0, value["l7_proto"], value["l7_master_proto"]),
      label = l4_protocol..":"..l7_protocol
   }

   return record
end

-- ##############################################

return flow_alert_store
