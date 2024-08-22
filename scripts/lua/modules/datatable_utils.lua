--
-- (C) 2020-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

local datatable_utils = {}

local REDIS_KEY = "ntopng.prefs.%s.table.%s.columns"

local function get_username()
   local username = _SESSION["user"] or ''
   if (isNoLoginUser()) then username = 'no_login' end

   return username
end

---Save the columns visibility inside Redis 
---@param table_name string The HTML table id
---@param columns string String containing ids separeted by comma
function datatable_utils.save_column_preferences(table_name, columns)
   -- avoid the save of nil value
   if columns == nil then return end

   local key = string.format(REDIS_KEY, get_username(), table_name)
   local cols = split(columns, ",")

   ntop.setPref(key, json.encode(cols))
end

---Load saved column visibility from Redis
---@param table_name string The HTML table id
---@return table
function datatable_utils.load_saved_column_preferences(table_name)
   local key = string.format(REDIS_KEY, get_username(), table_name)
   local columns = ntop.getPref(key)

   if isEmptyString(columns) then
      return { -1 }
   end

   return json.decode(columns)
end

---Check if there are saved visible columns
---@param table_name string The HTML table id
---@return boolean
function datatable_utils.has_saved_column_preferences(table_name)
   local key = string.format(REDIS_KEY, get_username(), table_name)
   local columns = ntop.getPref(key)

   return not isEmptyString(columns)
end

------------------------------------------------------------------------
-- DataTable columns definitions (JSON)

-- #####################################

local function build_datatable_column_def_default(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
   }
end

-- #####################################

local function build_datatable_column_def_number(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      style = "text-align:right;",
      class = { "no-wrap" },
      render_type = "full_number",
   }
end

-- #####################################

local function build_datatable_column_def_ip(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatIP",
   }
end

-- #####################################

local function build_datatable_column_def_port(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_flow(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = false,
      class = { "text-nowrap" },
      render_type = "formatFlowTuple",
   }
end

-- #####################################

local function build_datatable_column_def_nw_latency(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      style = "text-align:right;",
      class = { "no-wrap" },
   }
end

-- #####################################

local function build_datatable_column_def_asn(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
   }
end

-- #####################################

local function build_datatable_column_def_snmp_interface(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = false,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_network(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = false,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_pool_id(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_country(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = false,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_community_id(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = false,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_packets(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap", "text-center" },
      render_type = "full_number",
   }
end

-- #####################################

local function build_datatable_column_def_bytes(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      style = "text-align:right;",
      class = { "no-wrap" },
      render_type = "bytes",
   }
end

-- #####################################

local function build_datatable_column_def_tcp_flags(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_dscp(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      class = { "no-wrap" },
      render_generic = name,
   }
end

-- #####################################

local function build_datatable_column_def_float(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      style = "text-align:right;",
      class = { "no-wrap", "text-center" },
   }
end

-- #####################################

local function build_datatable_column_def_msec(name, i18n_label)
   return {
      data_field = name,
      title_i18n = i18n_label,
      sortable = true,
      style = "text-align:right;",
      class = { "no-wrap" },
      render_type = "ms",
   }
end

-- #####################################

local all_datatable_columns_def_by_tag = {
   ['first_seen'] = {
      title_i18n = "db_search.first_seen",
      data_field = "first_seen",
      sortable = true,
      class = { "no-wrap" },
   },
   ['last_seen'] = {
      title_i18n = "db_search.last_seen",
      data_field = "last_seen",
      sortable = true,
      class = { "no-wrap" },
   },
   ['l4proto'] = {
      title_i18n = "db_search.l4proto",
      data_field = "l4proto",
      sortable = true,
      class = { "no-wrap" },
      render_generic = "l4proto",
   },
   ['l7proto'] = {
      title_i18n = "db_search.l7proto",
      data_field = "l7proto",
      sortable = true,
      class = { "no-wrap" },
   },
   ['score'] = {
      title_i18n = "score",
      data_field = "score",
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatValueLabel",
   },
   ["flow"] = build_datatable_column_def_flow("flow", "flow"),
   ['vlan_id'] = {
      title_i18n = "db_search.vlan_id",
      data_field = "vlan_id",
      sortable = true,
      class = { "no-wrap" },
      render_generic = "vlan_id",
   },
   ['ip'] = build_datatable_column_def_ip('ip', "db_search.host"),
   ['cli_ip'] = build_datatable_column_def_ip('cli_ip', "db_search.client"),
   ['srv_ip'] = build_datatable_column_def_ip('srv_ip', "db_search.server"),
   ['cli_port'] = build_datatable_column_def_port('cli_port', "db_search.cli_port"),
   ['srv_port'] = build_datatable_column_def_port('srv_port', "db_search.srv_port"),
   ['packets'] = build_datatable_column_def_packets('packets', "db_search.packets"),
   ['bytes'] = build_datatable_column_def_bytes('bytes', "db_search.bytes"),
   ['throughput'] = {
      title_i18n = "db_search.throughput",
      data_field = "throughput",
      sortable = true,
      class = { "no-wrap" },
   },
   ['asn'] = build_datatable_column_def_asn('asn', "db_search.asn"),
   ['cli_asn'] = build_datatable_column_def_asn('cli_asn', "db_search.cli_asn"),
   ['srv_asn'] = build_datatable_column_def_asn('srv_asn', "db_search.srv_asn"),
   ['l7cat'] = {
      title_i18n = "db_search.l7cat",
      data_field = "l7cat",
      sortable = true,
      class = { "no-wrap" },
      render_generic = "l7cat",
   },
   ['alert_id'] = {
      title_i18n = "db_search.alert_id",
      data_field = "alert_id",
      sortable = true,
      class = { "no-wrap" },
      render_generic = "alert_id",
   },
   ['flow_risk'] = {
      title_i18n = "db_search.flow_risk",
      data_field = "flow_risk",
      sortable = true,
      class = { "no-wrap" },
   },
   ['src2dst_tcp_flags'] = build_datatable_column_def_tcp_flags('src2dst_tcp_flags', "db_search.src2dst_tcp_flags"),
   ['dst2src_tcp_flags'] = build_datatable_column_def_tcp_flags('dst2src_tcp_flags', "db_search.dst2src_tcp_flags"),
   ['src2dst_dscp'] = build_datatable_column_def_dscp('src2dst_dscp', "db_search.src2dst_dscp"),
   ['dst2src_dscp'] = build_datatable_column_def_dscp('dst2src_dscp', "db_search.dst2src_dscp"),
   ['cli_nw_latency'] = build_datatable_column_def_nw_latency('cli_nw_latency', "db_search.cli_nw_latency"),
   ['srv_nw_latency'] = build_datatable_column_def_nw_latency('srv_nw_latency', "db_search.srv_nw_latency"),
   ['info'] = {
      title_i18n = "db_search.info",
      data_field = "info",
      sortable = true,
      class = { "no-wrap" },
   },
   ['observation_point_id'] = {
      title_i18n = "db_search.observation_point_id",
      data_field = "observation_point_id",
      sortable = true,
      class = { "no-wrap" },
      render_generic = "observation_point_id",
   },
   ['probe_ip'] = {
      title_i18n = "db_search.probe_ip",
      data_field = "probe_ip",
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatProbeIP",
   },
   ['network'] = build_datatable_column_def_network('network', "db_search.tags.network"),
   ['cli_network'] = build_datatable_column_def_network('cli_network', "db_search.tags.cli_network"),
   ['srv_network'] = build_datatable_column_def_network('srv_network', "db_search.tags.srv_network"),
   ['cli_host_pool_id'] = build_datatable_column_def_pool_id('cli_host_pool_id', "db_search.tags.cli_host_pool_id"),
   ['srv_host_pool_id'] = build_datatable_column_def_pool_id('srv_host_pool_id', "db_search.tags.srv_host_pool_id"),
   ["input_snmp"] = build_datatable_column_def_snmp_interface("input_snmp", "db_search.tags.input_snmp"),
   ["output_snmp"] = build_datatable_column_def_snmp_interface("output_snmp", "db_search.tags.output_snmp"),
   ['country'] = build_datatable_column_def_country('country', "db_search.tags.country"),
   ['cli_country'] = build_datatable_column_def_country('cli_country', "db_search.tags.cli_country"),
   ['srv_country'] = build_datatable_column_def_country('srv_country', "db_search.tags.srv_country"),
   ['community_id'] = build_datatable_column_def_community_id('community_id', "db_search.tags.community_id"),
   ['mitre_id'] = {
      title_i18n = "db_search.tags.mitre_id",
      data_field = "mitre_data",
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatMitreId",
   },
   ['mitre_tactic'] = {
      title_i18n = "db_search.tags.mitre_tactic",
      data_field = "mitre_data",
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatMitreTactic",
   },
   ['mitre_technique'] = {
      title_i18n = "db_search.tags.mitre_technique",
      data_field = "mitre_data",
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatMitreTechnique",
   },
   ['mitre_subtechnique'] = {
      title_i18n = "db_search.tags.mitre_subtechnique",
      data_field = "mitre_data",
      sortable = true,
      class = { "no-wrap" },
      render_type = "formatMitreSubTechnique",
   },
}

-- #####################################

datatable_utils.datatable_column_def_builder_by_type = {
   ['default'] = build_datatable_column_def_default,
   ['number'] = build_datatable_column_def_number,
   ['ip'] = build_datatable_column_def_ip,
   ['port'] = build_datatable_column_def_port,
   ['asn'] = build_datatable_column_def_asn,
   ['tcp_flags'] = build_datatable_column_def_tcp_flags,
   ['dscp'] = build_datatable_column_def_dscp,
   ['packets'] = build_datatable_column_def_packets,
   ['bytes'] = build_datatable_column_def_bytes,
   ['float'] = build_datatable_column_def_float,
   ['msec'] = build_datatable_column_def_msec,
   ['network'] = build_datatable_column_def_network,
   ['pool_id'] = build_datatable_column_def_pool_id,
   ['country'] = build_datatable_column_def_country,
   ['snmp_interface'] = build_datatable_column_def_snmp_interface,
}

-- #####################################

function datatable_utils.get_datatable_column_def_by_tag(tag)
   if all_datatable_columns_def_by_tag[tag] then
      return all_datatable_columns_def_by_tag[tag]
   else
      return build_datatable_column_def_default(tag, 
               (i18n("db_search.tags."..tag) and "db_search.tags."..tag) or tag)
   end
end

return datatable_utils
