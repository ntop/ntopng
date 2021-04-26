--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local tag_utils = {}

tag_utils.tag_operators = {
    ["eq"] = "=",
    ["neq"] = "!=",
    ["lt"] = "<",
    ["gt"] = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
}

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
}

-- #####################################

function tag_utils.add_tag_if_valid(tags, tag_key, tag, formatters)
    
   if isEmptyString(_GET[tag_key]) then
        return
   end

   local value
   local selected_operator = 'eq'

   local get_value = _GET[tag_key]
   local splitted = split(get_value, ',')

   if #splitted == 2 then
       value = splitted[1]
       selected_operator = splitted[2]
   end

   if formatters[tag_key] ~= nil then
       value = formatters[tag_key](value)
   end

   table.insert(tags, {
       value = value, label = i18n("tags.".. tag_key), key = tag_key, operators = tag.operators, selectedOperator = selected_operator
   })
end

return tag_utils
