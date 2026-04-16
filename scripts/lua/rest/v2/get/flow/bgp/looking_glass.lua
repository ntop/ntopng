--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local json = require "dkjson"
local bgp_utils = require "bgp_utils"
local rest_utils = require "rest_utils"

-- ################################################

local rsp = {}
local host_to_find = _GET["host"]

--[[
if isEmptyString(host_to_find) then
   rest_utils.answer(rest_utils.consts.err.bad_format)
   return
end
]]
-- ################################################

--local rib = ntop.ribFind(host_to_find)
-- DEBUG
local rib = '{"1.1.1.0\\24": {"212.74.82.15": {"asn":8220,"origin":"igp","as_path": [8220,13335],"next_hop":"87.241.16.133","med":0,"local_pref":200,"communities": ["8220:65000","8220:65060","8220:65401"]},"185.54.80.4": {"asn":202032,"origin":"igp","as_path": [13335],"next_hop":"185.54.80.4","local_pref":305,"communities": ["20203:2004"]},"185.54.80.3": {"asn":202032,"origin":"igp","as_path": [13335],"next_hop":"185.54.80.3","local_pref":305,"communities": ["20203:2003"]},"38.28.1.11": {"asn":174,"origin":"igp","as_path": [174,13335],"next_hop":"149.11.89.168","med":0,"local_pref":200,"communities": ["174:21101","174:22004"]},"193.221.216.30": {"asn":5398,"origin":"igp","as_path": [5398,13335],"next_hop":"77.220.74.109","local_pref":200,"communities": ["5398:12051"]}}}'
--rib = json.encode(rib)
if not isEmptyString(rib) then
   rib = json.decode(rib)
   rsp = bgp_utils.formatBgpBmpInfo(rib)
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)