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

-- format resources_used
local resources_used = {
  system = {
    cpu = {
      load = round(system_host_stats["cpu_load"], 2),
      states = {
        iowait_percentage = formatValue(system_host_stats["cpu_states"]["iowait"])
        active_percentage = round(formatValue(system_host_stats["cpu_states"]["user"] + system_host_stats["cpu_states"]["system"] + system_host_stats["cpu_states"]["nice"] + system_host_stats["cpu_states"]["irq"] + system_host_stats["cpu_states"]["softirq"] + system_host_stats["cpu_states"]["guest"] + system_host_stats["cpu_states"]["guest_nice"]), 2),
        idle_percentage = round(formatValue(system_host_stats["cpu_states"]["idle"] + system_host_stats["cpu_states"]["steal"]), 2),
      }
    },
    ram = {
      percentage_used = round((ram_used / system_host_stats["mem_total"]) * 100 * 100) / 100,
      available_bytes = (system_host_stats["mem_total"] - ram_used) * 1024,
      total_bytes = system_host_stats["mem_total"] * 1024,
    },
  },
  ntopng = {
    ram = {
      bytes_used = system_host_stats["mem_ntopng_resident"] * 1024,
    },
  },
}

-- return REST response
rest_utils.answer(rest_utils.consts.success.ok, { license_info = license_info, resources_used = resources_used})