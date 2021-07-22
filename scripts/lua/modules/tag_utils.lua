--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local tag_utils = {}

-- Operator Separator in query strings
tag_utils.SEPARATOR = ';'

-- #####################################

-- Supported operators
tag_utils.tag_operators = {
    ["eq"] = "=",
    ["neq"] = "!=",
    ["lt"] = "<",
    ["gt"] = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
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
   end 

   return default_verdict
end

-- #####################################

-- This table is done to convert tags to their where 
tag_utils.nindex_tags_to_where_v4 = {
   ["srv_ip"]   = "IPV4_DST_ADDR",
   ["cli_ip"]   = "IPV4_SRC_ADDR",
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
   ["srv_asn"]      = "DST_ASN",
   ["observation_point_id"] = "OBSERVATION_POINT_ID",
   ["probe_ip"]     = "PROBE_IP",
}

-- #####################################

tag_utils.nindex_tags_to_where_v6 = {
   ["srv_ip"]   = "IPV6_DST_ADDR",
   ["cli_ip"]   = "IPV6_SRC_ADDR",
   ["cli_port"] = "IP_SRC_PORT",
   ["srv_port"] = "IP_DST_PORT",
   ["vlan_id"]  = "VLAN_ID",
   ["status"]   = "STATUS",
   ["l7proto"]  = "L7_PROTO",
   ["l4proto"]  = "PROTOCOL",
   ["l7cat"]    = "L7_CATEGORY",
   ["packets"]      = "PACKETS",
   ["traffic"]      = "TOTAL_BYTES",
   ["first_seen"]   = "FIRST_SEEN",
   ["last_seen"]    = "LAST_SEEN",
   ["src2dst_dscp"] = "SRC2DST_DSCP",
   ["dst2src_dscp"] = "DST2SRC_DSCP",
   ["info"]         = "INFO",
   ["cli_asn"]      = "SRC_ASN",
   ["srv_asn"]      = "DST_ASN",
   ["observation_point_id"] = "OBSERVATION_POINT_ID",
   ["probe_ip"]     = "PROBE_IP",
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
