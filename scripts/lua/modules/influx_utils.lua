--
-- (C) 2014-15 - ntop.org
--


-- Enable/disable Influx DB
use_influx = false

influx_user = ""
influx_pwd  = ""
influx_url  = "http://localhost:8086/db/ntopng/series?u=ntopng&p=ntopng"

-- Local variables
local influx_debug = false
local influx_old_value  = { }
local influx_curr_value = { }
local json = require ("dkjson")

function load_last_influx(cache_key)
   influx_old_value = ntop.getCache(cache_key)
   -- io.write(influx_old_value.."\n")
   if((influx_old_value == nil) or (influx_old_value == "")) then 
      influx_old_value = { } 
   else 
      influx_old_value = json.decode(influx_old_value)
      if(influx_old_value == nil) then influx_old_value = { } end
   end
end

function save_curr_influx(cache_key)  
   local j = json.encode(influx_curr_value)
   -- if(influx_debug) then io.write(j.."\n") end
   ntop.setCache(cache_key, j)
end

function diff_value_influx(ifname, key, current_value)
   local v

   if(influx_debug) then 
      if(current_value > 0) then 
	 io.write("["..__FILE__()..":"..__LINE__().."] "..ifname.."|"..key.."="..current_value.."\n") 
      end
   end

   if(influx_old_value[ifname] == nil) then
      influx_old_value[ifname] = { }
   end

   if(influx_old_value[ifname][key] == nil) then
      influx_old_value[ifname][key] = current_value
   end

   if(influx_curr_value[ifname] == nil) then
      influx_curr_value[ifname] = {} 
   end

   influx_curr_value[ifname][key] = current_value

   v = current_value-influx_old_value[ifname][key]
   if(influx_debug 
      -- and (v > 0)
   ) then 
      io.write("["..__FILE__()..":"..__LINE__().."] ***> "..ifname.."|"..key.."="..v.." [current: "..current_value.."][old: ".. influx_old_value[ifname][key].."]\n") 
   end

   return(v)
end

