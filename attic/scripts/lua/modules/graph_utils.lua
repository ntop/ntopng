-- ########################################################

function createActivityRRDCounter(path, verbose)
   if(not(ntop.exists(path))) then
      if(verbose) then io.write('Creating RRD '..path..'\n') end
      local prefs = ntop.getPrefs()
      local step = 300
      local hb = step * 2
      ntop.rrd_create(
	 path,
	 step,
	 'DS:in:DERIVE:'..hb..':U:U',
	 'DS:out:DERIVE:'..hb..':U:U',
	 'DS:bg:DERIVE:'..hb..':U:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.host_activity_rrd_raw_hours*12),
	 'RRA:AVERAGE:0.5:12:'..tostring(prefs.host_activity_rrd_1h_days*24),
	 'RRA:AVERAGE:0.5:288:'..tostring(prefs.host_activity_rrd_1d_days)
      )
   end
end
