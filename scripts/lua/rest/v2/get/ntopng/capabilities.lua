--
-- (C) 2013-26 - ntop.org
--
-- Reports which instance-level features an external client (e.g. the
-- ntopng Companion Chrome extension) may use, so it can gate
-- Enterprise-only functionality (IOC cross-reference, §3.5 of the
-- Companion PRD) per-instance rather than assuming from a single global flag.
--
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/capabilities.lua
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

local info = ntop.getInfo() or {}

local is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false
local is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false
local is_pro = (ntop.isPro and ntop.isPro()) or false
local is_clickhouse_enabled = (ntop.isClickHouseEnabled and ntop.isClickHouseEnabled()) or false

local license_days_left = info["pro.license_days_left"] or 0
local license_type = info["pro.license_type"] or ""

local res = {
   product = info.product or "",
   version = info.version or "",
   is_pro = is_pro,
   is_enterprise_l = is_enterprise_l,
   is_enterprise_m = is_enterprise_m,
   is_clickhouse_enabled = is_clickhouse_enabled,
   license = {
      type = license_type,
      days_left = license_days_left
   },
   -- IOC historical cross-reference requires Enterprise M (or higher) and
   -- ClickHouse; without ClickHouse the fallback path is not implemented, so don't advertise the capability.
   ioc_lookup_available = is_enterprise_m and is_clickhouse_enabled
}

rest_utils.answer(rest_utils.consts.success.ok, res)
