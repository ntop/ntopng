--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
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

-- This table is done to convert tags to their where 
tag_utils.nindex_tags_to_where_v4 = {
   ["srv_ip"]   = {[4] = "IPV4_DST_ADDR", [6] = "IPV6_DST_ADDR"},
   ["cli_ip"]   = {[4] = "IPV4_SRC_ADDR", [6] = "IPV6_SRC_ADDR"},
   ["cli_port"] = "IP_SRC_PORT",
   ["srv_port"] = "IP_DST_PORT",
   ["vlan_id"]  = "VLAN_ID",
   ["status"]   = "STATUS",
   ["l7proto"]  = "L7_PROTO",
   ["l4proto"]  = "PROTOCOL",
   ["l7cat"]    = "L7_CATEGORY",
   ["flow_risk"]   = "FLOW_RISK",
   ["packets"]     = "PACKETS",
   ["traffic"]     = "TOTAL_BYTES",
   ["first_seen"]  = "FIRST_SEEN",
   ["last_seen"]   = "LAST_SEEN",
   ["src2dst_dscp"] = "SRC2DST_DSCP",
   ["dst2src_dscp"] = "DST2SRC_DSCP",
   ["info"]         = "INFO",
   ["srv_label"]    = "DST_LABEL",
   ["cli_label"]    = "SRC_LABEL",
   ["cli_asn"]      = "SRC_ASN",
   ["cli_asname"]   = "SRC_ASNAME",
   ["srv_asn"]      = "DST_ASN",
   ["srv_asname"]   = "DST_ASNAME",
   ["observation_point_id"] = "OBSERVATION_POINT_ID",
   ["probe_ip"]     = "PROBE_IP",
   ["throughput"]   = "THROUGHPUT",
   ["src2dst_tcp_flags"] = "SRC2DST_TCP_FLAGS",
   ["dst2src_tcp_flags"] = "DST2SRC_TCP_FLAGS",
   ["l7proto_master"]  = "L7_PROTO_MASTER",
   ["score"] = "SCORE",
}

tag_utils.orders = {
   ["asc"]  = "ASC",
   ["desc"] = "DESC",
}

-- #####################################

tag_utils.topk_tags_v4 = {
   ["host"]   = {
      "IPV4_DST_ADDR",
      "IPV4_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

-- #####################################

tag_utils.topk_tags_v6 = {
   ["host"]   = {
      "IPV6_DST_ADDR",
      "IPV6_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

-- #####################################

function tag_utils.add_tag_if_valid(tags, tag_key, operators, formatters, i18n_prefix)
    
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
      if formatters[tag_key] ~= nil then
         value = formatters[tag_key](value)
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

return tag_utils
