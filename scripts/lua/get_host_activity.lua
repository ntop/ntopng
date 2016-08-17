--
-- (C) 2016 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

sendHTTPHeader('text/html; charset=iso-8859-1')

-- mandatory parameters: host(as ip), ifid
local res = {}

if (_GET["host"] ~= nil and _GET["ifid"] ~= nil) then
   local host_info = url2hostinfo(_GET)
   local ifId = _GET["ifid"]
   local hostbase = dirs.workingdir .. "/" .. ifId .. "/rrd/" .. getPathFromKey(hostinfo2hostkey(host_info))
   local activbase = hostbase .. "/activity"

   if ntop.isdir(activbase) then
      if not _GET["activity"] then
         -- mode=list         
         for key,value in pairs(ntop.readdir(activbase)) do
            if string.ends(key, ".rrd") then
               table.insert(res, string.sub(key, 1, -5))
            end
         end
      else
         -- mode=get
         local start_time = tonumber(_GET["start"])
         local end_time = tonumber(_GET["stop"])
         local cf = _GET["cf"] or "AVERAGE"

         local rrd = activbase.."/".._GET["activity"]..".rrd"
         
         if(ntop.notEmptyFile(rrd)) then
            local fstart, fstep, fnames, fdata = ntop.rrd_fetch(rrd, cf, start_time, end_time)
            res.step = fstep
            res.up = {}
            res.down = {}
            res.bg = {}

            function getValue(w) if w ~= w then return 0 else return math.max(tonumber(w), 0) end end

            for i, v in ipairs(fdata) do
               table.insert(res.up, getValue(v[1]))
               table.insert(res.down, getValue(v[2]))
               table.insert(res.bg, getValue(v[3]))
            end
         end
      end
   end
end

print(json.encode(res, nil))
