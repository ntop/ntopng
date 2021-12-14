--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_consts = require "alert_consts"
local tag_utils = {}

-- Operator Separator in query strings
tag_utils.SEPARATOR = ';'

-- #####################################

-- Supported operators
tag_utils.tag_operators = {
    ["eq"]  = "=",
    ["neq"] = "!=",
    ["lt"]  = "<",
    ["gt"]  = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
    ["in"]  = i18n("has"),
    ["nin"] = i18n("does_not_have"),
}

-- #####################################

tag_utils.defined_tags = {
   l7proto = {
      value_type = 'l7_proto',
      i18n_label = i18n('db_search.tags.l7_proto'),
      operators = {'eq', 'neq'}
   },
   l7proto_master = {
      value_type = 'l7_proto',
      i18n_label = i18n('db_search.tags.l7_proto'),
      operators = {'eq', 'neq'},
      hide = true,
   },
   l7cat = {
      value_type = 'l7_category',
      i18n_label = i18n('db_search.tags.l7cat'),
      operators = {'eq', 'neq'}
   },
   flow_risk = {
      value_type = 'flow_risk',
      i18n_label = i18n('db_search.tags.flow_risk'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   status = {
      value_type = 'alert_type',
      i18n_label = i18n('db_search.tags.status'),
      operators = {'eq', 'neq'}
   },
   l4proto = {
      value_type = 'l4_proto',
      i18n_label = i18n('db_search.tags.l4proto'),
      operators = {'eq', 'neq'}
   },
   ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.ip'),
      operators = {'eq', 'neq'}
   },
   cli_ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.cli_ip'),
      operators = {'eq', 'neq'}
   },
   cli_location = {
      value_type = 'location',
      i18n_label = i18n('db_search.tags.cli_location'),
      operators = {'eq', 'neq'}
   },
   srv_ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.srv_ip'),
      operators = {'eq', 'neq'}
   },
   srv_location = {
      value_type = 'location',
      i18n_label = i18n('db_search.tags.srv_location'),
      operators = {'eq', 'neq'}
   },
   cli_name = {
      value_type = 'hostname',
      i18n_label = i18n('db_search.tags.cli_name'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   srv_name = {
      value_type = 'hostname',
      i18n_label = i18n('db_search.tags.srv_name'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   src2dst_dscp = {
      value_type = 'dscp_type',
      i18n_label = i18n('db_search.tags.src2dst_dscp'),
      operators = {'eq', 'neq'}
   },
   dst2src_dscp = {
      value_type = 'dscp_type',
      i18n_label = i18n('db_search.tags.dst2src_dscp'),
      operators = {'eq', 'neq'}
   },
   cli_port = {
      value_type = 'port',
      i18n_label = i18n('db_search.tags.cli_port'),
      operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'}
   },
   srv_port = {
      value_type = 'port',
      i18n_label = i18n('db_search.tags.srv_port'),
      operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'}
   },
   cli_asn = {
      value_type = 'asn',
      i18n_label = i18n('db_search.tags.cli_asn'),
      operators = {'eq', 'neq'}
   },
   srv_asn = {
      value_type = 'asn',
      i18n_label = i18n('db_search.tags.srv_asn'),
      operators = {'eq', 'neq'}
   },
   cli_nw_latency = {
      value_type = 'nw_latency_type',
      i18n_label = i18n('db_search.tags.cli_nw_latency'),
      operators = {'eq', 'lt', 'gt', 'lte', 'gte'}
   },
   srv_nw_latency = {
      value_type = 'nw_latency_type',
      i18n_label = i18n('db_search.tags.srv_nw_latency'),
      operators = {'eq', 'lt', 'gt', 'lte', 'gte'}
   },
   observation_point_id = {
      value_type = 'observation_point_id',
      i18n_label = i18n('db_search.tags.observation_point_id'),
      operators = {'eq', 'neq'}
   },
   probe_ip = {
      value_type = 'ip',
      i18n_label = i18n('db_search.tags.probe_ip'),
      operators = {'eq', 'neq'}
   },
   vlan_id = {
      value_type = 'id',
      i18n_label = i18n('db_search.tags.vlan_id'),
      operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'}
   },
   src2dst_tcp_flags = {
      value_type = 'flags',
      i18n_label = i18n('db_search.src2dst_tcp_flags'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   dst2src_tcp_flags = {
      value_type = 'flags',
      i18n_label = i18n('db_search.dst2src_tcp_flags'),
      operators = {'eq', 'neq', 'in', 'nin'}
   },
   score = {
      value_type = 'score',
      i18n_label = i18n('db_search.tags.score'),
      operators = {'eq', 'neq','lt', 'gt', 'gte', 'lte'}
   },
   cli_mac = {
      value_type = 'mac',
      i18n_label = i18n('db_search.tags.cli_mac'),
      operators = {'eq', 'neq'}
   },
   srv_mac = {
      value_type = 'mac',
      i18n_label = i18n('db_search.tags.srv_mac'),
      operators = {'eq', 'neq'}
   },
   cli_network = {
      value_type = 'network_id',
      i18n_label = i18n('db_search.tags.cli_network'),
      operators = {'eq', 'neq'}
   },
   srv_network = {
      value_type = 'network_id',
      i18n_label = i18n('db_search.tags.srv_network'),
      operators = {'eq', 'neq'}
   },
}

-- #####################################

tag_utils.ip_location = {
   { label = "Remote", id = 0 },
   { label = "Local",  id = 1 },
   { label = "Multicast", id = 2},
}

-- #####################################

function tag_utils.get_tag_filters_from_request()
   local filters = {}

   for key, value in pairs(tag_utils.defined_tags) do
      if _GET[key] ~= nil then
         filters[key] = _GET[key]
      end
   end

   return filters
end

-- ##############################################

--@brief Evaluate operator
function tag_utils.eval_op(v1, op, v2)
   local default_verdict = true

   -- Convert boolean for compatibility
   if type(v1) == 'boolean' then
      if v1 then v1 = 1 else v1 = 0 end
   end

   if not v1 or not v2 then
      return default_verdict
   end

   if op == 'eq' then
      return v1 == v2
   elseif op == 'neq' then
      return v1 ~= v2
   elseif op == 'lt' then
      return v1 < v2
   elseif op == 'gt' then
      return v1 > v2
   elseif op == 'gte' then
      return v1 >= v2
   elseif op == 'lte' then
      return v1 <= v2
   elseif op == 'in' then
      v_and = v1 & v2
      return v1 == v_and
   elseif op == 'nin' then
      v_and = v1 & v2
      return v1 ~= v_and
   end 

   return default_verdict
end

-- #####################################

tag_utils.formatters = {
   l7_proto = function(proto) return interface.getnDPIProtoName(tonumber(proto)) end,
   l7proto  = function(proto) return interface.getnDPIProtoName(tonumber(proto)) end,
   severity = function(severity) return (i18n(alert_consts.alertSeverityById(tonumber(severity)).i18n_title)) end,
   role = function(role) return (i18n(role)) end,
   role_cli_srv = function(role) return (i18n(role)) end,
}

-- ######################################

function tag_utils.add_tag_if_valid(tags, tag_key, operators, i18n_prefix)
   if isEmptyString(_GET[tag_key]) then
      return
   end

   local get_value = _GET[tag_key]
   local list = split(get_value, ',')

   for _,item in ipairs(list) do
      local selected_operator = 'eq'

      local splitted = split(item, tag_utils.SEPARATOR)

      local realValue
      if #splitted == 2 then
         realValue = splitted[1]
         selected_operator = splitted[2]
      end

      local value = realValue
      if tag_utils.formatters[tag_key] ~= nil then
         value = tag_utils.formatters[tag_key](value)
      end

      tag = {
         realValue = realValue,
         value = value,
         label = i18n(i18n_prefix .. "." .. tag_key),
         key = tag_key,
         operators = operators,
         selectedOperator = selected_operator
      }

      table.insert(tags, tag)
   end
end

-- #####################################

return tag_utils
