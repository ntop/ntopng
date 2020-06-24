--
-- ###################################################################################
-- nst_export_ip_txt.lua (v3.0.1)
--
-- NST - 2014, 2015, 2016, 2017, 2019, 2020:
--   Export Host IPv4/IPv6 Addresses as text - one Address per line.
--
-- Usage Example:
--   curl --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_ip_text.lua?p_nstifnamelist=p5p1,p1p2";
--
--      Where <ifnamelist> is an optional comma separated Network Interface
--      name list. If omitted, All IP Addresses for each configured
--      ntopng network interfaces will be used.
--
-- ###################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- local json = require("dkjson")

-- sendHTTPHeader('application/json')

-- ################################# FUNCTIONS ########################################
function dumpNtopngHostsIpAddrs(netint)
  --
  -- Configure hosts selective data dump for Network Interface: 'netint'
  interface.select(netint)
  --
  -- ntopng configured Network Interface check...
  if (not interface.isRunning()) then
    return
  end
  --
  -- Dump All hosts IP Addresses detected by ntopng for NST Usage...
  hosts_stats = interface.getHostsInfo()
  hosts_stats = hosts_stats["hosts"]
  --
  for key, value in pairs(hosts_stats) do
    host = interface.getHostInfo(key)
    if (host ~= nil) then
      if (host["ip"] ~= nil) then
        print(host["ip"] .. "\n")
      end
    end
  end
end
-- ###################################################################################


-- ####################################### CODE ######################################

--
-- Get a list of user selected Network Interfaces from URL...
intlist = _GET["p_nstifnamelist"]
if (intlist == nil) then
  --
  -- Get all configured ntopng Network Interfaces
  -- if user did not specify a list...
  ntopngints = interface.getIfNames()
else
  ntopngints = split(intlist, ",")
end

--
-- For each selected Network Interface dump host selective data...
inum = 0
for id, int in pairs(ntopngints) do
  dumpNtopngHostsIpAddrs(int)
end
