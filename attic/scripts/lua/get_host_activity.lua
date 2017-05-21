--
-- (C) 2016-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

sendHTTPContentTypeHeader('text/html')

-- mandatory parameters: host(as ip), ifid
local res = {}

local MIN_STEP = 300

-- TODO these names should be in sync with ndpi
local name_map = {
      { "Chat", "Chat and Realtime Communications" },
      { "RemoteControl", "Remote Access" },
      { "MailSend", "Email Send" },
      { "Media", "Media and Streaming" },
      { "MailSync", "Email Synchronization" },
      { "FileTransfer", "File Transfer" },
      { "FileSharing", "File Sharing" },
      { "SocialNetwork", "Social Networks" },
      { "Web", "Web Browsing" },
      { "Game", "Online Gaming" },
      { "Unspecified", "Other Traffic" }
}

function mapRRDname(name) 	 
  for id,_ in ipairs(name_map) do
    local m = name_map[id]
    if(name == m[1]) then
      return(m[2])
     end
  end

  return(name)
end

if (_GET["host"] ~= nil and _GET["ifid"] ~= nil and _GET["step"] ~= nil) then
   local host_info = url2hostinfo(_GET)
   local ifId = _GET["ifid"]
   local host = hostinfo2hostkey(host_info)
   local hostbase = dirs.workingdir .. "/" .. ifId .. "/rrd/" .. getPathFromKey(host)
   local activbase = hostbase .. "/activity"
   local actname = _GET["activity"]

   local islive = _GET["step"] and tonumber(_GET["step"]) < MIN_STEP
   local fetchData = false
   local rrd

   if islive then
      if not _GET["activity"] then
         -- mode=list
         interface.select(ifId)
         local activities = interface.getHostActivity(host)
         if activities then
            for key,value in pairs(activities) do
               res[mapRRDname(key)] = key
            end
         end
      else
         -- mode=get
         fetchData = true
      end
   else
      if ntop.isdir(activbase) then
         if not _GET["activity"] then
            -- mode=list
            for key,value in pairs(ntop.readdir(activbase)) do
               if string.ends(key, ".rrd") then
                  local clean = string.sub(key, 1, -5)
                  res[mapRRDname(clean)] = clean
               end
            end
         else
            -- mode=get
            rrd = activbase.."/"..actname..".rrd"
            
            if(ntop.notEmptyFile(rrd)) then
               fetchData = true
            end
         end
      end
   end

   if fetchData then
      res.live = islive
      res.step = _GET["step"]
      res.up = {}
      res.down = {}
      res.bg = {}

      if islive then
         interface.select(ifId)
         local activity = interface.getHostActivity(host)
         if activity and activity[actname] then
            local data = activity[actname]
            table.insert(res.up, data.up)
            table.insert(res.down, data.down)
            table.insert(res.bg, data.background)
         end
      else
         local start_time = tonumber(_GET["epoch_begin"])
         local end_time = tonumber(_GET["epoch_end"])
         local cf = _GET["cf"] or "AVERAGE"
         local fstart, fstep, fnames, fdata = ntop.rrd_fetch(rrd, cf, start_time, end_time)
         res.step = fstep
         
         function getValue(w) if w ~= w then return 0 else return math.max(tonumber(w), 0) end end

         for i, v in ipairs(fdata) do
            table.insert(res.up, getValue(v[1])*fstep)
            table.insert(res.down, getValue(v[2])*fstep)
            table.insert(res.bg, getValue(v[3])*fstep)
         end
      end
   end
end

print(json.encode(res, nil))
