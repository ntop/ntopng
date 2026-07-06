--
-- (C) 2013-26 - ntop.org
--

--
-- This script harvests old RRDs
--

interface.rrd_harvest(tonumber(ntop.getCache("ntopng.prefs.rrd_files_retention_days") or "0"))
