--
-- (C) 2013-19 - ntop.org
--

local probe = {
  name = "CPU",
  descripton = "Monitors the CPU usage",
}

-- ##############################################

function probe.runTask(when, ts_utils)
  local cpu_load = ntop.refreshCpuLoad()

  if(cpu_load ~= nil) then
    ts_utils.append("system:cpu_load", {load_percentage = cpu_load}, when)
  end
end

-- ##############################################

return probe
