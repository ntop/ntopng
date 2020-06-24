--
-- ###################################################################################
-- nst_export_ip_data.lua (v3.0.1)
--
-- NST - 2014, 2015, 2016, 2017, 2019, 2020:
--    Export Host IPv4/IPv6 Addresses with Selective Data as an array of JSON objects.
--
-- Usage Example:
--   curl --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_ip_data.lua?p_nstifnamelist=p5p1,p1p2";
--
-- Usage Example (Silent):
--   curl --silent --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_ip_data.lua?p_nstifnamelist=p5p1,p1p2";
--
--      Where <p_nstifnamelist> is an optional comma separated Network Interface
--      name list. If omitted, All host selective data for each configured
--      ntopng network interfaces will be used.
--
-- ###################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- local json = require("dkjson")

-- sendHTTPHeader('application/json')


-- ################################# FUNCTIONS ########################################
function dumpNtopngHostsStats(netint)
  --
  -- Configure hosts selective data dump for Network Interface: 'netint'
  interface.select(netint)
  --
  -- ntopng configured Network Interface check...
  if (not interface.isRunning()) then
    return false
  end
  --
  -- Dump All hosts stats detected by ntopng for NST Usage...
  --
  hosts_stats = interface.getHostsInfo()
  hosts_stats = hosts_stats["hosts"]
  hnum = 0
  for key, value in pairs(hosts_stats) do
    host = interface.getHostInfo(key)
    if (host ~= nil) then
--
--  Dump Available Keys...
--
--for k, v in pairs(host) do
--  print('Key: ' .. k .. "\t\t\t\tValue: " .. tostring(v) .. '\n')
--end
--do return end
--
      if ((host["ip"] ~= nil) and (host["ip"] ~= "0.0.0.0")) then
        if (hnum > 0) then
          print(",")
        else
          hnum = hnum + 1
        end
        print("{")
        print("\"ipa\":\"" .. host["ip"] .. "\",")
        --
        if (host["ip"] ~= nil) then
          print("\"mac\":\"" .. host["ip"] .. "\",")
        else
          print("\"mac\":\"00:00:00:00:00:00\",")
        end
        --
        if (host["bytes.sent"] ~= nil) then
          print("\"tdb\":" .. host["bytes.sent"] .. ",")
        else
          print("\"tdb\":0,")
        end
        if (host["packets.sent"] ~= nil) then
          print("\"tdp\":" .. host["packets.sent"] .. ",")
        else
          print("\"tdp\":0,")
        end
        --
        if (host["bytes.rcvd"] ~= nil) then
          print("\"rdb\":" .. host["bytes.rcvd"] .. ",")
        else
          print("\"rdb\":0,")
        end
        if (host["packets.rcvd"] ~= nil) then
          print("\"rdp\":" .. host["packets.rcvd"] .. ",")
        else
          print("\"rdp\":0,")
        end
        --
        if (host["ndpi"] ~= nil) then
          pnum = 0
          print("\"dpi\":\"")
          for proto, data in pairs(host["ndpi"]) do
            if (pnum > 0) then
              print(" ")
            else
              pnum = pnum + 1
            end
            print(proto)
          end
          print("\"")
        else
          print("\"dpi\":\"\"")
        end
        print("}")
      end
    end
  end
  if (hnum == 0) then
    return false
  else
    return true
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
print("\n[")
for id, int in pairs(ntopngints) do
  if (inum > 0) then
    interface.select(int)
    if (interface.isRunning()) then
      print(",")
    end
  end
  rc = dumpNtopngHostsStats(int)
  if (rc) then
    inum = inum + 1
  end
end
print("]")
