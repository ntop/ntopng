--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local format_utils = require("format_utils")
local cpu_utils = require("cpu_utils")

-- retrieve license info
local info = ntop.getInfo()

-- format license info
local license_info = {
  version = split(getNtopngRelease(info, true)," |")[1],
  system_id = info["pro.systemid"],
  license = info["pro.license_encoded"],
  status = info["pro.license_type"],
}

-- retrieve resources_used
local system_host_stats = cpu_utils.systemHostStats()
local ram_used = system_host_stats["mem_used"] 

local cpu_load = system_host_stats["cpu_load"] or 0
local mem_total = system_host_stats["mem_total"] or 0
local cpu_states = system_host_stats["cpu_states"] or {}
local mem_ntopng_resident = system_host_stats["mem_ntopng_resident"] or 0

-- format resources_used
local resources_used = {
  system = {
    cpu = {
      load = round(cpu_load, 2),
      states = {
        iowait_percentage = formatValue(cpu_states["iowait"]),
        active_percentage = round(formatValue((cpu_states["user"] or 0) + (cpu_states["system"] or 0) + (cpu_states["nice"] or 0) + (cpu_states["irq"] or 0) + (cpu_states["softirq"] or 0) + (cpu_states["guest"] or 0) + (cpu_states["guest_nice"] or 0)), 2),
        idle_percentage = round(formatValue((cpu_states["idle"] or 0) + (cpu_states["steal"] or 0)), 2),
      }
    },
    ram = {
      percentage_used = round((ram_used / mem_total) * 100 * 100) / 100,
      available_bytes = (mem_total - ram_used) * 1024,
      total_bytes = mem_total * 1024,
    },
  },
  ntopng = {
    ram = {
      bytes_used = mem_ntopng_resident * 1024,
    },
  },
}

-- return REST response
rest_utils.answer(rest_utils.consts.success.ok, { license_info = license_info, resources_used = resources_used})
