--
-- (C) 2013-19 - ntop.org
--

local probe = {
   name = "CPU",
   descripton = "Monitors the CPU usage",
}

-- ##############################################

function probe.runTask(when, ts_utils, ts_creation)
   local cpu_load = ntop.refreshCpuLoad()

   if ts_creation and cpu_load then
      ts_utils.append("system:cpu_load", {ifid = getSystemInterfaceId(), load_percentage = cpu_load}, when)
   end
end

-- ##############################################

return probe
