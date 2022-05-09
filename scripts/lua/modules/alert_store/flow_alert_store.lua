--
-- (C) 2021-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

require "lua_utils"
local alert_store = require "alert_store"
local flow_risk_utils = require "flow_risk_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local tag_utils = require "tag_utils"
local network_utils = require "network_utils"
local json = require "dkjson"
local pools = require "pools"
local historical_flow_utils = require "historical_flow_utils"

local href_icon = "<i class='fas fa-laptop'></i>"

-- ##############################################

local flow_alert_store = classes.class(alert_store)

-- ##############################################

function flow_alert_store:init(args)
   local table_name = "flow_alerts"

   self.super:init()

   if ntop.isClickHouseEnabled() then
      -- Alerts from historical flows (see also RecipientQueue::enqueue)
      table_name = "flow_alerts_view"
      self._write_table_name = "flows"
   end

   self._table_name = table_name
   self._alert_entity = alert_entities.flow
end

-- ##############################################

-- Get the 'real' field name (used by flow alerts where the flow table is a view
-- and we write to the real table which has different column names)
function alert_store:get_column_name(field, is_write)
   local col = field
   if is_write then
      col = historical_flow_utils.get_flow_column_by_tag(field) 
      if col then
         return col
      end
   end
   return field
end

-- ##############################################

--@brief Labels alerts according to specified filters
function alert_store:acknowledge(label)
   local where_clause = self:build_where_clause(true)

   -- Prepare the final query
   local q
   if ntop.isClickHouseEnabled() then
      local table_name = self._table_name
      if self._write_table_name then
         table_name = self._write_table_name
      end

      -- This is using the historical 'flows' table
      q = string.format("ALTER TABLE `%s` UPDATE `%s` = %u, `%s` = '%s', `%s` = %u WHERE %s", 
         table_name,
         self:get_column_name('alert_status', true),
         alert_consts.alert_status.acknowledged.alert_status_id, 
         self:get_column_name('user_label', true),
         self:_escape(label), 
         self:get_column_name('user_label_tstamp', true),
         os.time(), 
         where_clause)
   else
      q = string.format("UPDATE `%s` SET `alert_status` = %u, `user_label` = '%s', `user_label_tstamp` = %u WHERE %s", self._table_name, alert_consts.alert_status.acknowledged.alert_status_id, self:_escape(label), os.time(), where_clause)
   end

   local res = interface.alert_store_query(q)
   return res and table.len(res) == 0
end

-- ##############################################

--@brief Deletes data according to specified filters
function alert_store:delete()
   local where_clause = self:build_where_clause(true)

   -- Prepare the final query
   local q
   if ntop.isClickHouseEnabled() then
      local table_name = self._table_name
      if self._write_table_name then
         table_name = self._write_table_name
      end

      q = string.format("ALTER TABLE `%s` DELETE WHERE %s ", table_name, where_clause)
   else
      q = string.format("DELETE FROM `%s` WHERE %s ", self._table_name, where_clause)
   end

   local res = interface.alert_store_query(q)
   return res and table.len(res) == 0
end

-- ##############################################

function alert_store:_get_tstamp_column_name()
   if ntop.isClickHouseEnabled() then
      return "first_seen"
   else
      return "tstamp"
   end
end

-- ##############################################

function flow_alert_store:insert(alert)
   local hex_prefix = ""
   local extra_columns = ""
   local extra_values = ""

   -- Note: this is no longer called when ClickHouse is enabled
   -- as a view on the historical is used. See RecipientQueue::enqueue

   if(ntop.isClickHouseEnabled()) then
      extra_columns = "rowid, "
      extra_values = "generateUUIDv4(), "
   else
      hex_prefix = "X"
   end

   -- Note
   -- The database contains first_seen, tstamp, tstamp_end for historical reasons.
   -- The time index is set on first_seen, thus:
   -- - tstamp and first_seen contains the same value alert.first_seen
   -- - tstamp_end is set to alert.tstamp (which is the time the alert has been emitted as there is no engage on flows)
   -- - first_seen is used to lookups as this is the indexed field
   -- - tstamp (instead of first_seen) is used in select and for visualization as it's in common to all tables

   local insert_stmt = string.format("INSERT INTO %s "..
      "(%salert_id, interface_id, tstamp, tstamp_end, severity, ip_version, cli_ip, srv_ip, cli_port, srv_port, vlan_id, "..
      "is_cli_attacker, is_cli_victim, is_srv_attacker, is_srv_victim, proto, l7_proto, l7_master_proto, l7_cat, "..
      "cli_name, srv_name, cli_country, srv_country, cli_blacklisted, srv_blacklisted, "..
      "cli2srv_bytes, srv2cli_bytes, cli2srv_pkts, srv2cli_pkts, first_seen, community_id, score, "..
      "flow_risk_bitmap, alerts_map, cli_host_pool_id, srv_host_pool_id, cli_network, srv_network, json) "..
      "VALUES (%s%u, %u, %u, %u, %u, %u, '%s', '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s', '%s', '%s', "..
      "'%s', %u, %u, %u, %u, %u, %u, %u, '%s', %u, %u, %s'%s', %u, %u, %u, %u, '%s'); ",
      self._table_name,
      extra_columns,
      extra_values,
      alert.alert_id,
      self:_convert_ifid(interface.getId()),
      alert.first_seen,
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
      hex_prefix,
      alert.alerts_map,
      alert.cli_host_pool_id or pools.DEFAULT_POOL_ID,
      alert.srv_host_pool_id or pools.DEFAULT_POOL_ID,
      alert.cli_network or network_utils.UNKNOWN_NETWORK,
      alert.srv_network or network_utils.UNKNOWN_NETWORK,
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

   local q
   if ntop.isClickHouseEnabled() then
      q = string.format("SELECT cli_ip, vlan_id, cli_name, count(*) count FROM %s WHERE %s GROUP BY cli_ip, vlan_id, cli_name ORDER BY count DESC LIMIT %u",
         self._table_name, where_clause, self._top_limit)
   else
      q = string.format("SELECT cli_ip, vlan_id, cli_name, count(*) count FROM %s WHERE %s GROUP BY cli_ip ORDER BY count DESC LIMIT %u",
         self._table_name, where_clause, self._top_limit)
   end

   local q_res = interface.alert_store_query(q) or {}

   return q_res
end

-- ##############################################

--@brief Performs a query for the top server hosts by alert count
function flow_alert_store:top_srv_ip_historical()
   -- Preserve all the filters currently set
   local where_clause = self:build_where_clause()

   local q
   if ntop.isClickHouseEnabled() then
      q = string.format("SELECT srv_ip, vlan_id, srv_name, count(*) count FROM %s WHERE %s GROUP BY srv_ip, vlan_id, srv_name ORDER BY count DESC LIMIT %u",
         self._table_name, where_clause, self._top_limit)
   else
      q = string.format("SELECT srv_ip, vlan_id, srv_name, count(*) count FROM %s WHERE %s GROUP BY srv_ip ORDER BY count DESC LIMIT %u",
         self._table_name, where_clause, self._top_limit)
   end

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
      p.name = p.cli_name
      p.ip = p.cli_ip
   end 
   for _, p in ipairs(top_srv_ip) do
      all_ip[p.srv_ip] = (all_ip[p.srv_ip] or 0) + tonumber(p.count)
      ip_names[p.srv_ip] = {
         name = p.srv_name,
         vlan_id = p.vlan_id,
      }
      p.name = p.srv_name
      p.ip = p.srv_ip
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
   local cli_name = _GET["cli_name"]
   local srv_name = _GET["srv_name"]
   local cli_port = _GET["cli_port"]
   local srv_port = _GET["srv_port"]
   local vlan_id = _GET["vlan_id"]
   local l7proto = _GET["l7proto"]
   local role = _GET["role"]
   local cli_country = _GET["cli_country"]
   local srv_country = _GET["srv_country"]

   local cli_host_pool_id = _GET["cli_host_pool_id"]
   local srv_host_pool_id = _GET["srv_host_pool_id"]
   local cli_network = _GET["cli_network"]
   local srv_network = _GET["srv_network"]

   -- Filter out flows with no alert
   self:add_filter_condition_list('alert_id', "0"..tag_utils.SEPARATOR.."neq", 'number')

   self:add_filter_condition_list('vlan_id', vlan_id, 'number')
   self:add_filter_condition_list('ip_version', ip_version)
   self:add_filter_condition_list('ip', ip)
   self:add_filter_condition_list('cli_ip', cli_ip)
   self:add_filter_condition_list('srv_ip', srv_ip)
   self:add_filter_condition_list('cli_name', cli_name)
   self:add_filter_condition_list('srv_name', srv_name)
   self:add_filter_condition_list('cli_country', cli_country)
   self:add_filter_condition_list('srv_country', srv_country)
   self:add_filter_condition_list('cli_port', cli_port, 'number')
   self:add_filter_condition_list('srv_port', srv_port, 'number')
   self:add_filter_condition_list('flow_role', role)
   self:add_filter_condition_list('l7proto', l7proto, 'number')

   self:add_filter_condition_list('cli_host_pool_id', cli_host_pool_id, 'number')
   self:add_filter_condition_list('srv_host_pool_id', srv_host_pool_id, 'number')
   self:add_filter_condition_list('cli_network', cli_network, 'number')
   self:add_filter_condition_list('srv_network', srv_network, 'number')

end

-- ##############################################

--@brief Get info about additional available filters
function flow_alert_store:_get_additional_available_filters()
   local filters = {
      vlan_id    = tag_utils.defined_tags.vlan_id,
      ip_version = tag_utils.defined_tags.ip_version,
      ip         = tag_utils.defined_tags.ip,
      cli_ip     = tag_utils.defined_tags.cli_ip,
      srv_ip     = tag_utils.defined_tags.srv_ip,
      cli_name   = tag_utils.defined_tags.cli_name,
      srv_name   = tag_utils.defined_tags.srv_name,
      cli_port   = tag_utils.defined_tags.cli_port,
      srv_port   = tag_utils.defined_tags.srv_port,
      cli_country = tag_utils.defined_tags.cli_country,
      srv_country = tag_utils.defined_tags.srv_country,
      role       = tag_utils.defined_tags.role,
      l7proto    = tag_utils.defined_tags.l7proto,
      info       = tag_utils.defined_tags.info,

      cli_host_pool_id       = tag_utils.defined_tags.cli_host_pool_id,
      srv_host_pool_id       = tag_utils.defined_tags.srv_host_pool_id,
      cli_network       = tag_utils.defined_tags.cli_network,
      srv_network       = tag_utils.defined_tags.srv_network,
   }

   return filters
end 

-- ##############################################

local RNAME = {
   ADDITIONAL_ALERTS = { name = "additional_alerts", export = true},
   ALERT_NAME = { name = "alert_name", export = true},
   DESCRIPTION = { name = "description", export = true},
   FLOW_RELATED_INFO = { name = "flow_related_info", export = true },
   MSG = { name = "msg", export = true, elements = {"name", "value", "description"}},
   FLOW = { name = "flow", export = true, elements = {"srv_ip.label", "srv_ip.value", "srv_port", "cli_ip.label", "cli_ip.value", "cli_port"}},
   
   VLAN_ID = { name = "vlan_id", export = true},
   PROTO = { name = "proto", export = true},
   L7_PROTO = { name = "l7_proto", export = true},
   LINK_TO_PAST_FLOWS = { name = "link_to_past_flows", export = false},

   CLI_HOST_POOL_ID = { name = "cli_host_pool_id", export = false },
   SRV_HOST_POOL_ID = { name = "srv_host_pool_id", export = false },
   CLI_NETWORK = { name = "cli_network", export = false },
   SRV_NETWORK = { name = "srv_network", export = false },
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
      return {ip = value["cli_ip"], name = value["cli_name"]}
   else
      return {ip = value["srv_ip"], name = value["srv_name"]}
   end
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function flow_alert_store:format_record(value, no_html)
   local record = self:format_json_record_common(value, alert_entities.flow.entity_id, no_html)
   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.flow.entity_id)
   local alert_fullname = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true, alert_entities.flow.entity_id)
   local l4_protocol = l4_proto_to_string(value["proto"])
   local l7_protocol =  interface.getnDPIFullProtoName(tonumber(value["l7_master_proto"]), tonumber(value["l7_proto"]))
   local show_cli_port = (value["cli_port"] ~= '' and value["cli_port"] ~= '0')
   local show_srv_port = (value["srv_port"] ~= '' and value["srv_port"] ~= '0') 
   local msg = alert_utils.formatFlowAlertMessage(interface.getId(), value, alert_info)
   local active_url = ""
   local attacker = ""
   local victim = ""
   -- Add link to active flow
   local alert_json = json.decode(value.json)
  
   local flow_related_info = addExtraFlowInfo(alert_json, value)
    
   if not no_html and alert_json then
      local active_flow = interface.findFlowByKeyAndHashId(alert_json["ntopng.key"], alert_json["hash_entry_id"])
      if active_flow and active_flow["seen.first"] < tonumber(value["tstamp_end"]) then
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

		  local alert_risk = ntop.getFlowAlertRisk(alert_id)
		  if alert_risk > 0 then
		     message = string.format("%s %s", message, flow_risk_utils.get_documentation_link(alert_risk))
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
	    cur_msg = cur_additional_alert and "<br>"
	 end
	 cur_additional_alert = cur_additional_alert + 1

	 cur_msg = cur_msg..message
	 record[RNAME.ADDITIONAL_ALERTS.name] = record[RNAME.ADDITIONAL_ALERTS.name] ..cur_msg
      end
   end

   -- Handle VLAN as a separate field
   local cli_ip = value["cli_ip"]
   local srv_ip = value["srv_ip"]

   local shorten_msg

   record[RNAME.ADDITIONAL_ALERTS.name] = {
      descr = record[RNAME.ADDITIONAL_ALERTS.name],
   }

   if no_html then
      msg = noHtml(msg)
      flow_related_info  = noHtml(flow_related_info)
   else
      record[RNAME.DESCRIPTION.name] = {
         descr = msg,
         shorten_descr = shorten_msg,
      }
   end

   record[RNAME.FLOW_RELATED_INFO.name] = {
    descr = flow_related_info
  }

   record[RNAME.ALERT_NAME.name] = alert_name

   local cli_host_pool_id = RNAME.CLI_HOST_POOL_ID.name
   record[cli_host_pool_id] = {
     value = value['cli_host_pool_id'],
     label = getPoolName(value['cli_host_pool_id']),
   }

   local srv_host_pool_id = RNAME.SRV_HOST_POOL_ID.name
   record[srv_host_pool_id] = {
     value = value['srv_host_pool_id'],
     label = getPoolName(value['srv_host_pool_id']),
   }

   local cli_network = RNAME.CLI_NETWORK.name
   record[cli_network] = {
     value = value['cli_network'],
     label = getLocalNetworkAliasById(value['cli_network']),
   }

   local srv_network = RNAME.SRV_NETWORK.name
   record[srv_network] = {
     value = value['srv_network'],
     label = getLocalNetworkAliasById(value['srv_network']),
   }

   -- Removing the server network if the host has no network
   if value['srv_network'] == '65535' then
    record[srv_network]['label'] = ''
    record[srv_network]['value'] = ''
   end

   if value['cli_network'] == '65535' then
    record[cli_network]['label'] = ''
    record[cli_network]['value'] = ''
   end

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
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
      reference_html = hostinfo2detailshref({ip = value["cli_ip"], value["vlan_id"]}, nil, href_icon, "", true, nil, false)
      if reference_html == href_icon then
	 reference_html = ""
      end
   end

   -- In case no country is found, let's check if the host is in memory and retrieve country info
   local country = value["cli_country"]

   if isEmptyString(country) or country == "nil" then
      local host_info = interface.getHostMinInfo(cli_ip)
      if host_info then
         country = host_info["country"] or ""
      end
   end
  
   local flow_cli_ip = {
      value = cli_ip,
      label = cli_ip,
      reference = reference_html,
      country = country,
      blacklisted = value["cli_blacklisted"]
   }

   if no_html then
      flow_cli_ip["label"] = cli_name_long
   else
      if not isEmptyString(value["cli_name"]) and value["cli_name"] ~= flow_cli_ip["value"] then
         flow_cli_ip["name"] = value["cli_name"]
      end

      -- Shortened label if necessary for UI purposes
      flow_cli_ip["label"] = hostinfo2label(self:_alert2hostinfo(value, true --[[ As client --]]), false --[[ Show VLAN --]], true --[[ Shorten --]])
      flow_cli_ip["label_long"] = hostinfo2label(self:_alert2hostinfo(value, true --[[ As client --]]), false --[[ Show VLAN --]], false)
   end

   -- Format Server

   reference_html = ""
   if not no_html then
      reference_html = hostinfo2detailshref({ip = value["srv_ip"], vlan = value["vlan_id"]}, nil, href_icon, "", true)
      if reference_html == href_icon then
	 reference_html = ""
      end
   end

   -- In case no country is found, let's check if the host is in memory and retrieve country info
   country = value["srv_country"]

   if isEmptyString(country) or country == "nil" then
      local host_info = interface.getHostMinInfo(srv_ip)
      if host_info then
         country = host_info["country"] or ""
      end
   end

   local flow_srv_ip = {
      value = srv_ip,
      label = srv_ip,
      reference = reference_html,
      country = country,
      blacklisted = value["srv_blacklisted"]
   }

   if no_html then
      flow_srv_ip["label"] = srv_name_long
   else
      if not isEmptyString(value["srv_name"]) and value["srv_name"] ~= flow_srv_ip["value"] then
         flow_srv_ip["name"] = value["srv_name"]
      end
      
      -- Shortened label if necessary for UI purposes
      flow_srv_ip["label"] = hostinfo2label(self:_alert2hostinfo(value, false --[[ As server --]]), false --[[ Show VLAN --]], true --[[ Shorten --]])
      flow_srv_ip["label_long"] = hostinfo2label(self:_alert2hostinfo(value, false --[[ As server --]]), false --[[ Show VLAN --]], false)
   end

   local flow_cli_port = value["cli_port"]
   local flow_srv_port = value["srv_port"]

   local vlan 
   if value["vlan_id"] and tonumber(value["vlan_id"]) ~= 0 then
      vlan = {
         label = value["vlan_id"],
         title = value["vlan_id"],
         value = tonumber(value["vlan_id"]),
      }
   end

   record[RNAME.FLOW.name] = {
      vlan = vlan,
      cli_ip = flow_cli_ip,
      srv_ip = flow_srv_ip,
      cli_port = flow_cli_port,
      srv_port = flow_srv_port,
      active_url = active_url,
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
      l4_label = l4_protocol,
      l7_label = l7_protocol,
      label = l4_protocol..":"..l7_protocol,
   }

   -- Add link to historical flow
   if ntop.isEnterpriseM() and hasClickHouseSupport() and not no_html then
      local op_suffix = tag_utils.SEPARATOR .. 'eq'
      local href = string.format('%s/lua/pro/db_search.lua?epoch_begin=%u&epoch_end=%u&cli_ip=%s%s&srv_ip=%s%s&cli_port=%s%s&srv_port=%s%s&l4proto=%s%s',
         ntop.getHttpPrefix(), 
         tonumber(value["tstamp"]) - (5*60),
         tonumber(value["tstamp_end"]) + (5*60), 
         value["cli_ip"], op_suffix,
         value["srv_ip"], op_suffix,
         ternary(show_cli_port, tostring(value["cli_port"]), ''), op_suffix,
         ternary(show_srv_port, tostring(value["srv_port"]), ''), op_suffix,
         l4_protocol, op_suffix)

      record[RNAME.LINK_TO_PAST_FLOWS.name] = href
   end

   -- Add BPF filter
   local rules = {}
   rules[#rules+1] = 'host ' .. value["cli_ip"]
   rules[#rules+1] = 'host ' .. value["srv_ip"]
   if value["cli_port"] and tonumber(value["cli_port"]) > 0 then
      rules[#rules+1] = 'port ' .. tostring(value["cli_port"])
      rules[#rules+1] = 'port ' .. tostring(value["srv_port"])
   end

   record['filter'] = {
      epoch_begin = tonumber(value["tstamp"]), 
      epoch_end = tonumber(value["tstamp_end"]) + 1,
      bpf = table.concat(rules, " and "),
   }

   return record
end

-- ##############################################

local function get_label_link(label, tag, value, add_hyperlink)
   if add_hyperlink then
     return "<a href=\"" .. ntop.getHttpPrefix() .. "/lua/alert_stats.lua?status=" .. _GET['status'] .. "&page=" .. _GET['page'] .. "&" .. 
        tag .. "=" .. value .. tag_utils.SEPARATOR .. "eq\" " .. ">" .. label .. "</a>"
   else
      return label
   end
end

-- ##############################################

local function get_flow_link(fmt, add_hyperlink)
   local label = ''

   local value = fmt['flow']['cli_ip']['value']
   local vlan = ''
   local tag = 'cli_ip'
   local vlan_id = 0

   if fmt['flow']['vlan'] and fmt['flow']['vlan']["value"] ~= 0 then
    vlan_id = tonumber(fmt['flow']['vlan']["value"])
    vlan = '@' .. get_label_link(fmt['flow']['vlan']['label'], 'vlan_id', fmt['flow']['vlan']["value"], add_hyperlink)
   end

   local reference = hostinfo2detailshref({ip = fmt['flow']['cli_ip']['value'], vlan = vlan_id}, nil, href_icon, "", true)

   local cli_ip = "" 
   local srv_ip = ""

   if fmt['flow']['cli_ip']['label_long'] ~= fmt['flow']['cli_ip']['value'] then
    if add_hyperlink then
      cli_ip = " [ " .. get_label_link(fmt['flow']['cli_ip']['value'], 'cli_ip', value, add_hyperlink) .. " ]"
    end
    value = fmt['flow']['cli_ip']['label_long']
    tag = 'cli_name'
   end
   label = label .. get_label_link(fmt['flow']['cli_ip']['label_long'], tag, value, add_hyperlink) .. cli_ip

   if fmt['flow']['cli_port'] then
      label = label .. vlan .. ':' .. get_label_link(fmt['flow']['cli_port'], 'cli_port', fmt['flow']['cli_port'], add_hyperlink)
   end

   if add_hyperlink then
    label = label .. " " .. reference
   end

   label = label .. ' <i class="fas fa-exchange-alt fa-lg" aria-hidden="true"></i> '

   reference = hostinfo2detailshref({ip = fmt['flow']['srv_ip']['value'], vlan = vlan_id}, nil, href_icon, "", true)
   local value = fmt['flow']['srv_ip']['value']
   local tag = 'srv_ip'
   if fmt['flow']['srv_ip']['label_long'] ~= fmt['flow']['srv_ip']['value'] then
    if add_hyperlink then
      srv_ip = " [ " .. get_label_link(fmt['flow']['srv_ip']['value'], 'srv_ip', value, add_hyperlink) .. " ]"
    end   
    value = fmt['flow']['srv_ip']['label_long']
    tag = 'srv_name'
   end
   label = label .. get_label_link(fmt['flow']['srv_ip']['label_long'], tag, value, add_hyperlink) .. srv_ip

   if fmt['flow']['srv_port'] then
      label = label .. vlan .. ':' .. get_label_link(fmt['flow']['srv_port'], 'srv_port', fmt['flow']['srv_port'], add_hyperlink)
   end

   if add_hyperlink then
    label = label .. " " .. reference
   end

   return label
end

-- ##############################################

--@brief Edit specifica proto info, like converting 
--       timestamp to date/time for TLS Certificate Validity
local function editProtoDetails(proto_info)
  for proto, info in pairs(proto_info) do
    if proto == "tls" then
      info = format_tls_info(info)
    elseif proto == "dns" then
      info = format_dns_query_info(info)
    elseif proto == "http" then
      info = format_http_info(info)
    elseif proto == "icmp" then
      info = format_icmp_info(info)
    end
  end

  return proto_info
end

-- ##############################################

--@brief Get a label/title for the alert coming from the DB (value)
function flow_alert_store:get_alert_label(value)
   local fmt = self:format_record(value, false)
   return fmt['msg']['name'] .. ' | ' .. get_flow_link(fmt, false)
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a list of items to be printed in the details page
function flow_alert_store:get_alert_details(value)
   local details = {}
   local fmt = self:format_record(value, false)
   local add_hyperlink = true
   local json = json.decode(value["json"]) or {}
   local proto_info = json["proto"]
   local traffic_info = {}   
   
   details[#details + 1] = {
      label = i18n("alerts_dashboard.alert"),
      content = get_label_link(fmt['alert_id']['label'], 'alert_id', fmt['alert_id']['value'], add_hyperlink)
   }

   details[#details + 1] = {
      label = i18n("flow_details.flow_peers_client_server"),
      content = get_flow_link(fmt, add_hyperlink)
   }

   details[#details + 1] = {
      label = i18n("protocol") .. " / " .. i18n("application"),
      content = get_label_link(fmt['l7_proto']['l4_label'] .. ':' .. fmt['l7_proto']['l7_label'], 'l7proto', fmt['l7_proto']['value'], add_hyperlink)
   }

   details[#details + 1] = {
      label = i18n("show_alerts.alert_datetime"),
      content = fmt['tstamp']['label'],
   }

   details[#details + 1] = {
      label = i18n("score"),
      content = '<span style="color: ' .. fmt['score']['color'] .. '">' .. fmt['score']['label'] .. '</span>',
   }

   details[#details + 1] = {
      label = i18n("description"),
      content =  fmt['msg']['description'],
   }

   details[#details + 1] = {
      label = i18n("flow_details.additional_alert_type"),
      content = fmt['additional_alerts']['descr'],
   }

   if(proto_info and (proto_info.l7_error_code ~= nil) and (proto_info.l7_error_code ~= 0)) then
      details[#details + 1] = {
        label = i18n("l7_error_code"),
        content = proto_info.l7_error_code
      }
      
      proto_info.l7_error_code = nil -- Avoid to print it twice in the flow details section
   end
   
   proto_info = editProtoDetails(proto_info or {})
   traffic_info = format_common_info(value, traffic_info)

   details[#details + 1] = {
      label = i18n("flow_details.traffic_info"),
      content = traffic_info
   }

   for k, info in pairs(proto_info or {}) do
      details[#details + 1] = {
         label = i18n("alerts_dashboard.flow_related_info"),
         content = info
      }
   end

   --[[
   details[#details + 1] = {
      label = "Title",
      content = {
         [1] = "Content 1",
         [2] = "Content 2",
      }
   }
   --]]

   return details 
end

-- ##############################################

return flow_alert_store
