--
-- ###################################################################################
-- nst_export_ip_data.lua (v3.0.2)
--
-- NST - 2014, 2015, 2016, 2017, 2019, 2020:
--    Export Host IPv4/IPv6 Addresses with Selective Data in XML format from an active
--    ntopng session.
--
-- Usage Example:
--   curl --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_ip_xml.lua";
--
-- Usage Example (Silent):
--   curl --silent --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_ip_xml.lua?p_nstifnamelist=p5p1,p1p2";
--
--      Where <ifnamelist> is an optional comma separated Network Interface
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
--
-- Available Stats: 05-31-2019
-- ---------------------------
-- Key: host["tcpPacketStats.rcvd"]
-- Key: host["anomalous_flows.as_client"]
-- Key: host["mac"]
-- Key: host["tcp.packets.seq_problems"]
-- Key: host["city"]
-- Key: host["name"]
-- Key: host["ifid"]
-- Key: host["hiddenFromTop"]
-- Key: host["icmp.bytes.sent"]
-- Key: host["active_flows.as_client"]
-- Key: host["throughput_pps"]
-- Key: host["icmp.packets.sent"]
-- Key: host["dhcpHost"]
-- Key: host["throughput_trend_bps_diff"]
-- Key: host["http"]
-- Key: host["ndpi"]
-- Key: host["os"]
-- Key: host["ndpi_categories"]
-- Key: host["icmp.bytes.rcvd.anomaly_index"]
-- Key: host["pktStats.sent"]
-- Key: host["last_throughput_pps"]
-- Key: host["throughput_bps"]
-- Key: host["other_ip.packets.rcvd"]
-- Key: host["other_ip.packets.sent"]
-- Key: host["last_throughput_bps"]
-- Key: host["privatehost"]
-- Key: host["bytes.ndpi.unknown"]
-- Key: host["udpBytesSent.non_unicast"]
-- Key: host["local_network_name"]
-- Key: host["drop_all_host_traffic"]
-- Key: host["udpBytesSent.unicast"]
-- Key: host["pktStats.recv"]
-- Key: host["active_http_hosts"]
-- Key: host["packets.sent.anomaly_index"]
-- Key: host["json"]
-- Key: host["other_ip.bytes.sent.anomaly_index"]
-- Key: host["ssl_fingerprint"]
-- Key: host["ip"]
-- Key: host["tskey"]
-- Key: host["tcp.packets.sent"]
-- Key: host["operatingSystem"]
-- Key: host["seen.last"]
-- Key: host["latitude"]
-- Key: host["tcpPacketStats.sent"]
-- Key: host["icmp.bytes.sent.anomaly_index"]
-- Key: host["asn"]
-- Key: host["seen.first"]
-- Key: host["flows.as_server"]
-- Key: host["is_blacklisted"]
-- Key: host["broadcast_domain_host"]
-- Key: host["packets.sent"]
-- Key: host["udp.bytes.sent.anomaly_index"]
-- Key: host["low_goodput_flows.as_server.anomaly_index"]
-- Key: host["total_flows.as_server"]
-- Key: host["other_ip.bytes.rcvd"]
-- Key: host["low_goodput_flows.as_client.anomaly_index"]
-- Key: host["low_goodput_flows.as_server"]
-- Key: host["low_goodput_flows.as_client"]
-- Key: host["vlan"]
-- Key: host["longitude"]
-- Key: host["host_unreachable_flows.as_server"]
-- Key: host["tcp.bytes.sent"]
-- Key: host["continent"]
-- Key: host["names"]
-- Key: host["info"]
-- Key: host["ipkey"]
-- Key: host["local_network_id"]
-- Key: host["bytes.sent.anomaly_index"]
-- Key: host["bytes.rcvd.anomaly_index"]
-- Key: host["num_alerts"]
-- Key: host["is_multicast"]
-- Key: host["systemhost"]
-- Key: host["has_blocking_shaper"]
-- Key: host["has_blocking_quota"]
-- Key: host["tcp.bytes.sent.anomaly_index"]
-- Key: host["udp.bytes.rcvd.anomaly_index"]
-- Key: host["unreachable_flows.as_client"]
-- Key: host["contacts.as_server"]
-- Key: host["dns"]
-- Key: host["unreachable_flows.as_server"]
-- Key: host["icmp.bytes.rcvd"]
-- Key: host["anomalous_flows.as_server"]
-- Key: host["udp.bytes.rcvd"]
-- Key: host["icmp.packets.rcvd"]
-- Key: host["other_ip.bytes.sent"]
-- Key: host["udp.packets.sent"]
-- Key: host["has_dropbox_shares"]
-- Key: host["udp.packets.rcvd"]
-- Key: host["is_broadcast"]
-- Key: host["tcp.bytes.rcvd"]
-- Key: host["active_flows.as_server"]
-- Key: host["tcp.packets.rcvd"]
-- Key: host["throughput_trend_pps"]
-- Key: host["udp.bytes.sent"]
-- Key: host["total_alerts"]
-- Key: host["packets.rcvd.anomaly_index"]
-- Key: host["other_ip.bytes.rcvd.anomaly_index"]
-- Key: host["contacts.as_client"]
-- Key: host["country"]
-- Key: host["host_unreachable_flows.as_client"]
-- Key: host["packets.rcvd"]
-- Key: host["childSafe"]
-- Key: host["flows.as_client"]
-- Key: host["total_activity_time"]
-- Key: host["devtype"]
-- Key: host["duration"]
-- Key: host["bytes.sent"]
-- Key: host["throughput_trend_bps"]
-- Key: host["asname"]
-- Key: host["bytes.rcvd"]
-- Key: host["localhost"]
-- Key: host["total_flows.as_client"]
-- Key: host["host_pool_id"]
-- Key: host["tcp.bytes.rcvd.anomaly_index"]

-- 
-- Dump Selected Host Stats in XML format
function dumpNtopngHostsStatsXml(netint)
  --
  -- Configure hosts selective data dump for Network Interface: 'netint'
  interface.select(netint)
  --
  -- ntopng configured Network Interface check...
  if (not interface.isRunning()) then
    return
  end
  --
  -- Dump All hosts stats detected by ntopng for NST Usage...
  hosts_stats = interface.getHostsInfo()
  hosts_stats = hosts_stats["hosts"]
  for key, value in pairs(hosts_stats) do
    host = interface.getHostInfo(key)
    if (host ~= nil) then
--
--  Dump Available Keys...
--
--for k, v in pairs(host) do
--  print('-- Key: ' .. k .. '\n')
--  print('Key: ' .. k .. "\t\t\t\tValue: " .. tostring(v) .. '\n')
--end
--do return end
--

      if ((host["ip"] ~= nil)  and (host["ip"] ~= "0.0.0.0")) then
        print('    <host>\n')
        --MAC ADDRESS (mac)--
        if (host["mac"] ~= nil) then
          print('      <mac>' .. host["mac"] .. '</mac>\n')
        else
          print('      <mac>00:00:00:00:00:00</mac>\n')
        end
        --IPv4 / IPv6 ADDRESS (ip4 or ip6)--
        if (isIPv6(host["ip"])) then
          print('      <ip6>' .. host["ip"] .. '</ip6>\n')
        else
          print('      <ip4>' .. host["ip"] .. '</ip4>\n')
        end
        --RESOLVED NAME - FQDN (rsv)--
        if ((host["name"] ~= nil) and (host["name"] ~= "")) then
          --
          -- Remove unwanted chars (&, !, $, etc...)in name...
          local hn = host["name"]
          hn = string.gsub(hn, "&", "")
          hn = string.gsub(hn, "!", "")
          hn = string.gsub(hn, "$", "")
          print('      <rsv>' .. hn .. '</rsv>\n')
        else
          print('      <rsv>' .. host["ip"] .. '</rsv>\n')
        end
        --AUTONOMOUS SYSTEM NUMBER (asn)--
        if (host["asn"] ~= nil) then
          print('      <asn>' .. host["asn"] .. '</asn>\n')
        else
          print('      <asn></asn>\n')
        end
        --TRANSMIT DATA BYTES/PACKETS (tdb/tdp)--
        if (host["bytes.sent"] ~= nil) then
          print('      <tdb>' .. host["bytes.sent"] .. '</tdb>\n')
        else
          print('      <tdb>0</tdb>\n')
        end
        if (host["packets.sent"] ~= nil) then
          print('      <tdp>' .. host["packets.sent"] .. '</tdp>\n')
        else
          print('      <tdp>0</tdp>\n')
        end
        --RECEIVED DATA BYTES/PACKETS (rdb/rdp)--
        if (host["bytes.rcvd"] ~= nil) then
          print('      <rdb>' .. host["bytes.rcvd"] .. '</rdb>\n')
        else
          print('      <rdb>0</rdb>\n')
        end
        if (host["packets.rcvd"] ~= nil) then
          print('      <rdp>' .. host["packets.rcvd"] .. '</rdp>\n')
        else
          print('      <rdp>0</rdp>\n')
        end
        --TCP SENT BYTES/PACKETS (tsb/tsp)--
        if (host["tcp.bytes.sent"] ~= nil) then
          print('      <tsb>' .. host["tcp.bytes.sent"] .. '</tsb>\n')
        else
          print('      <tsb>0</tsb>\n')
        end
        if (host["tcp.packets.sent"] ~= nil) then
          print('      <tsp>' .. host["tcp.packets.sent"] .. '</tsp>\n')
        else
          print('      <tsp>0</tsp>\n')
        end
        --TCP RECEIVED BYTES/PACKETS (trb/trp)--
        if (host["tcp.bytes.rcvd"] ~= nil) then
          print('      <trb>' .. host["tcp.bytes.rcvd"] .. '</trb>\n')
        else
          print('      <trb>0</trb>\n')
        end
        if (host["tcp.packets.rcvd"] ~= nil) then
          print('      <trp>' .. host["tcp.packets.rcvd"] .. '</trp>\n')
        else
          print('      <trp>0</trp>\n')
        end
        --UDP SENT BYTES/PACKETS (usb/usp)--
        if (host["udp.bytes.sent"] ~= nil) then
          print('      <usb>' .. host["udp.bytes.sent"] .. '</usb>\n')
        else
          print('      <usb>0</usb>\n')
        end
        if (host["udp.packets.sent"] ~= nil) then
          print('      <usp>' .. host["udp.packets.sent"] .. '</usp>\n')
        else
          print('      <usp>0</usp>\n')
        end
        --UDP RECEIVED BYTES/PACKETS (urb/urp)--
        if (host["udp.bytes.rcvd"] ~= nil) then
          print('      <urb>' .. host["udp.bytes.rcvd"] .. '</urb>\n')
        else
          print('      <urb>0</urb>\n')
        end
        if (host["udp.packets.rcvd"] ~= nil) then
          print('      <urp>' .. host["udp.packets.rcvd"] .. '</urp>\n')
        else
          print('      <urp>0</urp>\n')
        end
        --ICMP SENT BYTES/PACKETS (isb/isp)--
        if (host["icmp.bytes.sent"] ~= nil) then
          print('      <isb>' .. host["icmp.bytes.sent"] .. '</isb>\n')
        else
          print('      <isb>0</isb>\n')
        end
        if (host["icmp.packets.sent"] ~= nil) then
          print('      <isp>' .. host["icmp.packets.sent"] .. '</isp>\n')
        else
          print('      <isp>0</isp>\n')
        end
        --ICMP RECEIVED BYTES/PACKETS (irb/irp)--
        if (host["icmp.bytes.rcvd"] ~= nil) then
          print('      <irb>' .. host["icmp.bytes.rcvd"] .. '</irb>\n')
        else
          print('      <irb>0</irb>\n')
        end
        if (host["icmp.packets.rcvd"] ~= nil) then
          print('      <irp>' .. host["icmp.packets.rcvd"] .. '</irp>\n')
        else
          print('      <irp>0</irp>\n')
        end
        --OTHER IP SENT BYTES/PACKETS (osb/osp)--
        if (host["other_ip.bytes.sent"] ~= nil) then
          print('      <osb>' .. host["other_ip.bytes.sent"] .. '</osb>\n')
        else
          print('      <osb>0</osb>\n')
        end
        if (host["other_ip.packets.sent"] ~= nil) then
          print('      <osp>' .. host["other_ip.packets.sent"] .. '</osp>\n')
        else
          print('      <osp>0</osp>\n')
        end
        --OTHER IP RECEIVED BYTES/PACKETS (orb/orp)--
        if (host["other_ip.bytes.rcvd"] ~= nil) then
          print('      <orb>' .. host["other_ip.bytes.rcvd"] .. '</orb>\n')
        else
          print('      <orb>0</orb>\n')
        end
        if (host["other_ip.packets.rcvd"] ~= nil) then
          print('      <orp>' .. host["other_ip.packets.rcvd"] .. '</orp>\n')
        else
          print('      <orp>0</orp>\n')
        end
        --PACKET STATS SENT (pss)--
        print('      <pss>\n')
        if (host["pktStats.sent"] ~= nil) then
          if (host["pktStats.sent"].upTo64 ~= nil) then
            if (host["pktStats.sent"].upTo64 > 0) then
              print("        <pkt upto='64'>" .. host["pktStats.sent"].upTo64 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo128 ~= nil) then
            if (host["pktStats.sent"].upTo128 > 0) then
              print("        <pkt upto='128'>" .. host["pktStats.sent"].upTo128 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo256 ~= nil) then
            if (host["pktStats.sent"].upTo256 > 0) then
              print("        <pkt upto='256'>" .. host["pktStats.sent"].upTo256 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo512 ~= nil) then
            if (host["pktStats.sent"].upTo512 > 0) then
              print("        <pkt upto='512'>" .. host["pktStats.sent"].upTo512 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo1024 ~= nil) then
            if (host["pktStats.sent"].upTo1024 > 0) then
              print("        <pkt upto='1024'>" .. host["pktStats.sent"].upTo1024 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo1518 ~= nil) then
            if (host["pktStats.sent"].upTo1518 > 0) then
              print("        <pkt upto='1518'>" .. host["pktStats.sent"].upTo1518 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo2500 ~= nil) then
            if (host["pktStats.sent"].upTo2500 > 0) then
              print("        <pkt upto='2500'>" .. host["pktStats.sent"].upTo2500 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo6500 ~= nil) then
            if (host["pktStats.sent"].upTo6500 > 0) then
              print("        <pkt upto='6500'>" .. host["pktStats.sent"].upTo6500 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].upTo9000 ~= nil) then
            if (host["pktStats.sent"].upTo9000 > 0) then
              print("        <pkt upto='9000'>" .. host["pktStats.sent"].upTo9000 .. '</pkt>\n')
            end
          end
          if (host["pktStats.sent"].above9000 ~= nil) then
            if (host["pktStats.sent"].above9000 > 0) then
              print("        <pkt above='9000'>" .. host["pktStats.sent"].above9000 .. '</pkt>\n')
            end
          end
        end
        print('      </pss>\n')
        --PACKET STATS RECEIVED (psr)--
        print('      <psr>\n')
        if (host["pktStats.recv"] ~= nil) then
          if (host["pktStats.recv"].upTo64 ~= nil) then
            if (host["pktStats.recv"].upTo64 > 0) then
              print("        <pkt upto='64'>" .. host["pktStats.recv"].upTo64 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo128 ~= nil) then
            if (host["pktStats.recv"].upTo128 > 0) then
              print("        <pkt upto='128'>" .. host["pktStats.recv"].upTo128 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo256 ~= nil) then
            if (host["pktStats.recv"].upTo256 > 0) then
              print("        <pkt upto='256'>" .. host["pktStats.recv"].upTo256 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo512 ~= nil) then
            if (host["pktStats.recv"].upTo512 > 0) then
              print("        <pkt upto='512'>" .. host["pktStats.recv"].upTo512 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo1024 ~= nil) then
            if (host["pktStats.recv"].upTo1024 > 0) then
              print("        <pkt upto='1024'>" .. host["pktStats.recv"].upTo1024 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo1518 ~= nil) then
            if (host["pktStats.recv"].upTo1518 > 0) then
              print("        <pkt upto='1518'>" .. host["pktStats.recv"].upTo1518 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo2500 ~= nil) then
            if (host["pktStats.recv"].upTo2500 > 0) then
              print("        <pkt upto='2500'>" .. host["pktStats.recv"].upTo2500 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo6500 ~= nil) then
            if (host["pktStats.recv"].upTo6500 > 0) then
              print("        <pkt upto='6500'>" .. host["pktStats.recv"].upTo6500 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].upTo9000 ~= nil) then
            if (host["pktStats.recv"].upTo9000 > 0) then
              print("        <pkt upto='9000'>" .. host["pktStats.recv"].upTo9000 .. '</pkt>\n')
            end
          end
          if (host["pktStats.recv"].above9000 ~= nil) then
            if (host["pktStats.recv"].above9000 > 0) then
              print("        <pkt above='9000'>" .. host["pktStats.recv"].above9000 .. '</pkt>\n')
            end
          end
        end
        print('      </psr>\n')
        --THROUGHTPUT BYTES PER SEC (bps)--
        if (host["throughput_bps"] ~= nil) then
          print('      <bps>' .. host["throughput_bps"] .. '</bps>\n')
        else
          print('      <bps>0</bps>\n')
        end
        --THROUGHTPUT TREND BYTES PER SEC (tbs)--
        if (host["throughput_trend_bps"] ~= nil) then
          print('      <tbs>' .. host["throughput_trend_bps"] .. '</tbs>\n')
        else
          print('      <tbs>0</tbs>\n')
        end
        --THROUGHTPUT PACKETS PER SEC (pps)--
        if (host["throughput_pps"] ~= nil) then
          print('      <pps>' .. host["throughput_pps"] .. '</pps>\n')
        else
          print('      <pps>0</pps>\n')
        end
        --THROUGHTPUT TREND PACKETS PER SEC (tps)--
        if (host["throughput_trend_pps"] ~= nil) then
          print('      <tps>' .. host["throughput_trend_pps"] .. '</tps>\n')
        else
          print('      <tps>0</tps>\n')
        end
        --FLOWS AS CLIENT (fac)--
        if (host["flows.as_client"] ~= null) then
          print('      <fac>' .. host["flows.as_client"] .. '</fac>\n')
        else
          print('      <fac>0</fac>\n')
        end
        --FLOWS AS SERVER (fas)--
        if (host["flows.as_server"] ~= null) then
          print('      <fas>' .. host["flows.as_server"] .. '</fas>\n')
        else
          print('      <fas>0</fas>\n')
        end
        --NUMBER OF ALERTS (noa)--
        if (host["num_alerts"] ~= nil) then
          print('      <noa>' .. host["num_alerts"] .. '</noa>\n')
        else
          print('      <nos>0</nos>\n')
        end
        --NTOPNG DEEP PACKET INSPECTION (dpi)--
        if (host["ndpi"] ~= nil) then
          pnum = 0
          print('      <dpi>')
          for proto, data in pairs(host["ndpi"]) do
            if (pnum > 0) then
              print(" ")
            else
              pnum = pnum + 1
            end
            print(proto)
          end
          print('</dpi>')
        else
          print('      <dpi></dpi>')
        end
        print('\n    </host>\n')
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
print('<?xml version="1.0" encoding="UTF-8"?>\n')
print('<ntopng-host-data>\n')

for id, int in pairs(ntopngints) do
  interface.select(int)
  if (interface.isRunning()) then
    print('  <int net="' .. int .. '">\n')
    dumpNtopngHostsStatsXml(int)
    print('  </int>\n')
  end
end
print('</ntopng-host-data>\n')
