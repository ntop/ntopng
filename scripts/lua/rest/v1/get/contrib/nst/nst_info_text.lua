--
-- ###################################################################################
-- nst_info_text.lua (v2.01)
--
-- NST - 2014, 2015, 2020:
--     Dump selective ntopng information as key/value data in text format.
--
-- Usage Example:
--   curl --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_info_text.lua";
--
-- ###################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- sendHTTPHeader('text/html')

-- ################################# FUNCTIONS ########################################
function dumpNtopngInfoData(netint)
  --
  -- Configure stats dump for Network Interface: 'netint'
  interface.select(netint)
  ifstats = interface.getStats()

  if(ifstats ~= nil) then
    uptime = ntop.getUptime()
    --
    -- Print key values...
    print('epoch=' .. os.time() ..'\n') 
    print('uptime=' .. secondsToTime(uptime) ..'\n') 
    return
  end
end
-- ###################################################################################

-- ####################################### CODE ######################################
--
-- Dump information for all configured Network Interface...
ntopngcfgints = interface.getIfNames()
num = 0

for id, int in pairs(ntopngcfgints) do
  if (num > 0) then
    print('interface=' .. int ..'\n') 
  else
    --
    -- Use the first configured net int for selective info...
    dumpNtopngInfoData(int)
    print('interface=' .. int ..'\n') 
    num = num + 1
  end
end
