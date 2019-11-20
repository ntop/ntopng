--
-- (C) 2013-19 - ntop.org
--

local probe = {
   name = "Process Memory",
   descripton = "Monitors the memory usage of the process",
}

-- ##############################################

function probe.runTask(when, ts_utils, ts_creation)
   if ts_creation then
      local system_host_stats = ntop.systemHostStat()

      if((system_host_stats.mem_ntopng_resident ~= nil) and
	 (system_host_stats.mem_ntopng_virtual ~= nil)) then
	 ts_utils.append("process:resident_memory",
			 {
			    ifid = getSystemInterfaceId(),
			    resident_bytes = system_host_stats.mem_ntopng_resident * 1024,
			 }, when, verbose)
      end
   end
end

-- ##############################################

return probe
