--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local datasources_utils = require("datasources_utils")
local datamodel = require("datamodel_utils")
local ts_utils = require "ts_utils"

local function reportError(msg)
    print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local ifid       = _GET["ifid"]       or getSystemInterfaceId()
local key        = _GET["key"]        or ""
local metric     = _GET["metric"]     or ""
local schema     = _GET["schema"]     or ""
local begin_time = _GET["begin_time"] or os.time()-3600
local end_time   = _GET["end_time"]   or os.time()

-- Remove
key    = "spaziogames.it"
metric = "http"
schema = "am_host:http_stats_min"


local rsp = ts_utils.query(
   schema,
	{
      ifid = ifid,
      host = key,
      metric = metric
   },
   begin_time,
   end_time,
	{
		fill_value = 0/0, -- Show unknown values as NaN
	}
)

if (rsp ~= nil) then

   local labels = {}
   local values = {}
   local start  = rsp.start
   local step   = rsp.step
   local m

   for k, v in pairs(rsp.series) do
      table.insert(labels, v.label)
   end

   m = datamodel:create(labels)

   for k, v in pairs(rsp.series) do
      local when = start
      for k1, val in pairs(v.data) do

         local real_val = val
         if real_val == nil then real_val = 0 end
	      m:appendRow(when, v.label, real_val)
	      when = when + step
      end
   end

   return(m)
end


