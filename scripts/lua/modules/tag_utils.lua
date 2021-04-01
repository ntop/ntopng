--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local tag_utils = {}

tag_utils.tag_operators = {
    ["eq"] = "=",
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
   ["flow_risk"] = "FLOW_RISK",
   ["pkts"]     = "PACKETS",
   ["bytes"]    = "TOTAL_BYTES",
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
   ["pkts"]     = "PACKETS",
   ["bytes"]    = "TOTAL_BYTES",
}

-- #####################################

return tag_utils
