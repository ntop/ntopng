--
-- (C) 2013-19 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"

--sendHTTPContentTypeHeader('text/html')
sendHTTPContentTypeHeader('Application/json')


local discover = require "discover_utils" 
local matrix = interface.getArpStatsMatrixInfo()


--[[   
    per le serie temporali? che dati tengo? e come?
    potrei anche "temporizzare" tutte le info sopra descritte cambiando l'ID (es <ip + timestamp> ),
    ma occuperebbero MOLTO spazio

    --però così una marea di info sono "duplicate" :( non posso mettere puntatori qua in lua; farla in C++?
______________________________________________
    es. struttura elemento tabella:
    
    > hostID (ip? mac?)
        > MAC/IP
        > tot talkers
        > tot pkts sent
        > tot pkts rvc
        > freq tot
            > tot req 
                > snt
                > snt freq
                > rcv
                > rvc freq
            > tot rep 
                > snt
                > snt freq
                > rcv
                > rvc freq
        > Talkers (list)
            > hostID
            > MAC
            > country
            > OS
            > device type
            > manufacturers
            > pkts
                > req 
                    > snt
                    > snt freq
                    > rcv
                    > rvc freq
                > rep 
                    > snt
                    > snt freq
                    > rcv
                    > rvc freq

____________________________________________


]]

local function in_if(cond, t, f)
    if cond then 
        return t
    else
        return f
    end
end 



-- le voci della tabella commentate sono legate alla dim temporale
-- si può facilmente modificare per creare stats solo per uno (o predeterminati) host
local function createStats(matrix)

    if not matrix then return nil end

    local t_res = {}
    local t_tmp = {}
    local macInfo = nil
    local hostInfo = nil
    

    for _, m_elem in pairs(matrix) do
        for i,stats in pairs(m_elem)do
            tmp = split(i,"-")
            src_ip = tmp[1]
            dst_ip = tmp[2]

            if not t_res[src_ip] then    --il controllo serve solo per il dst2src

                --ho omesso allcune stats (OS, devType, manufacturer, country)
                --accessibili in tabella nella cella relativa al dst_ip

                macInfo = interface.getMacInfo(stats["src_mac"])
                --hostInfo = interface.getHostInfo(src_ip, nil)

                t_res[src_ip] = {          -- nuovo elemento

                        ip = src_ip,
                        mac = stats["src_mac"],
                        pkts_snt = stats["src2dst.requests"] + stats["src2dst.replies"],
                        pkts_rcvd = stats["dst2src.requests"] + stats["dst2src.replies"],
                        talkers_num = 1,

                        device_type = in_if( macInfo,  discover.devtype2string(macInfo["devtype"]), nil),
                        --TODO: fun di utilità per l'OS
                        OS = in_if(macInfo, macInfo["operatingSystem"], nil ),
                        manufacturer = in_if(macInfo, macInfo["manufacturer"], nil ),

                        talkers = {}
                    }

            else                        -- aggiorno a basta

                t_res[src_ip].pkts_snt = t_res[src_ip].pkts_snt + stats["src2dst.requests"] + stats["src2dst.replies"]
                t_res[src_ip].pkts_rcvd = t_res[src_ip].pkts_rcvd + stats["dst2src.requests"] + stats["dst2src.replies"]
                t_res[src_ip].talkers_num = t_res[src_ip].talkers_num +1
            end

            --ora l'elemento c'è di certo, aggiorno la lista dei talkers
            if not t_res[src_ip].talkers[dst_ip] then --aggiungo talker 
                
                t_res[src_ip].talkers[dst_ip] = { 
                    ip = dst_ip,
                    mac = stats["dst_mac"],
                    pkts_snt = stats["src2dst.requests"] + stats["src2dst.replies"],
                    pkts_rcvd = stats["dst2src.requests"] + stats["dst2src.replies"]

                }
            else        --aggiorno cnt
                t_res[src_ip].talkers[dst_ip].pkts_snt  = t_res[src_ip].talkers[dst_ip].pkts_snt  + stats["src2dst.requests"] + stats["src2dst.replies"]
                t_res[src_ip].talkers[dst_ip].pkts_rcvd = t_res[src_ip].talkers[dst_ip].pkts_rcvd + stats["dst2src.requests"] + stats["dst2src.replies"]
                --potrei controllare se è cambiato il mac (cioè se il dispositivo ha cambiato ip)
            end
--#################################### ############################################################################################################################
                --ORA IL DST2SRC

            if not t_res[dst_ip] then 

                macInfo = in_if( dst_mac ~= "FF:FF:FF:FF:FF:FF", interface.getMacInfo(stats["dst_mac"]), nil )

                t_res[dst_ip] = {          -- nuovo elemento

                        ip = dst_ip,
                        mac = stats["dst_mac"],
                        pkts_rcvd = stats["src2dst.requests"] + stats["src2dst.replies"],
                        pkts_snt = stats["dst2src.requests"] + stats["dst2src.replies"],
                        talkers_num = 1,
                        device_type = in_if( macInfo,  discover.devtype2string(macInfo["devtype"]), nil),
                        OS = in_if(macInfo, macInfo["operatingSystem"], nil ),--TODO: fun di utilità per l'OS
                        manufacturer = in_if(macInfo, macInfo["manufacturer"], nil ),

                        talkers = {}
                    }

            else                        -- aggiorno a basta

                t_res[dst_ip].pkts_snt = t_res[dst_ip].pkts_snt + stats["dst2src.requests"] + stats["dst2src.replies"]
                t_res[dst_ip].pkts_rcvd = t_res[dst_ip].pkts_rcvd +  stats["src2dst.requests"] + stats["src2dst.replies"]
                t_res[dst_ip].talkers_num = t_res[dst_ip].talkers_num +1
            end

            --ora l'elemento c'è di certo, aggiorno la lista dei talkers
            if not t_res[dst_ip].talkers[src_ip] then --aggiungo talker 
                
                t_res[dst_ip].talkers[src_ip] = { 
                    ip = src_ip,
                    mac = stats["dst_mac"],
                    pkts_rcvd = stats["src2dst.requests"] + stats["src2dst.replies"],
                    pkts_snt = stats["dst2src.requests"] + stats["dst2src.replies"]

                }
            else        --aggiorno cnt
                t_res[dst_ip].talkers[src_ip].pkts_snt  = t_res[dst_ip].talkers[src_ip].pkts_snt  + stats["dst2src.requests"] + stats["dst2src.replies"]
                t_res[dst_ip].talkers[src_ip].pkts_rcvd = t_res[dst_ip].talkers[src_ip].pkts_rcvd + stats["src2dst.requests"] + stats["src2dst.replies"]
                --potrei controllare se è cambiato il mac (cioè se il dispositivo ha cambiato ip)
            end



        end
    end
    --here i can elaborate the ratio stats

    return t_res
end



local json = require("dkjson")
--print( json.encode(createStats(matrix), {indent = true} ) )
--print( json.encode( matrix, {indent = true} ) )

-- tprint(interface.getMacInfo("00:86:9C:77:5C:4C" ) )
--print( json.encode( interface.getMacsInfo(), {indent = true}) )
print( json.encode( interface.getMacInfo("E4:11:5B:E3:D0:3A"), {indent = true}) )




--[[ MAC INFO

source_mac boolean true
throughput_trend_bps number 2
operatingSystem number 0
bytes.ndpi.unknown number 0
bytes.rcvd.anomaly_index number 0
arp_replies.rcvd number 0
seen.last number 1556543236
bytes.rcvd number 0
packets.sent.anomaly_index number 100
throughput_trend_bps_diff number -12.012893676758
manufacturer string Dell Inc.
bridge_seen_iface_id number 0
pool number 0
throughput_trend_pps number 2
bytes.sent number 3840
arp_requests.rcvd number 0
special_mac boolean false
location string unknown
throughput_pps number 0.59977388381958
duration number 375
packets.rcvd.anomaly_index number 0
seen.first number 1556542862
num_hosts number 0
devtype number 0
packets.rcvd number 0
packets.sent number 64
arp_requests.sent number 64
last_throughput_pps number 0.79998880624771
arp_replies.sent number 0
last_throughput_bps number 47.999328613281
throughput_bps number 35.986434936523
bytes.sent.anomaly_index number 100
fingerprint string 
mac string 14:18:77:53:49:9C

    per la stringa relativa al tipo
    discover.devtype2string(num_type)
]]


--[[ HOST INFO

bytes.ndpi.unknown number 0
tcp.packets.lost number 0
active_flows.as_server number 0
systemhost boolean false
udp.bytes.sent number 29669
json string { "flows.as_client": 5, "flows.as_server": 0, "anomalous_flows.as_client": 0, "anomalous_flows.as_server": 0, "unreachable_flows.as_client": 0, "unreachable_flows.as_server": 0, "host_unreachable_flows.as_client": 0, "host_unreachable_flows.as_server": 0, "total_alerts": 0, "sent": { "packets": 52, "bytes": 29669 }, "rcvd": { "packets": 0, "bytes": 0 }, "ndpiStats": { "MDNS": { "duration": 20, "bytes": { "sent": 25801, "rcvd": 0 }, "packets": { "sent": 32, "rcvd": 0 } }, "NetBIOS": { "duration": 15, "bytes": { "sent": 2360, "rcvd": 0 }, "packets": { "sent": 16, "rcvd": 0 } }, "Dropbox": { "duration": 5, "bytes": { "sent": 1508, "rcvd": 0 }, "packets": { "sent": 4, "rcvd": 0 } }, "categories": { "Cloud": { "id": 13, "bytes_sent": 1508, "bytes_rcvd": 0, "duration": 5 }, "Network": { "id": 14, "bytes_sent": 25801, "bytes_rcvd": 0, "duration": 20 }, "System": { "id": 18, "bytes_sent": 2360, "bytes_rcvd": 0, "duration": 15 } } }, "total_activity_time": 25, "ip": { "ipVersion": 4, "localHost": false, "ip": "146.48.99.68" }, "mac_address": "00:0E:C6:C7:D8:4A", "ifid": 3, "seen.first": 1556542967, "seen.last": 1556542989, "last_stats_reset": 0, "asn": 137, "symbolic_name": "Marlin", "asname": "Consortium GARR", "localHost": false, "systemHost": false, "broadcastDomainHost": true, "is_blacklisted": false, "num_alerts": 0 }
continent string EU
os string 
low_goodput_flows.as_server number 0
packets.sent number 52
bytes.rcvd number 0
total_alerts number 0
host_pool_id number 0
tcp.bytes.sent.anomaly_index number 0
privatehost boolean false
ipkey number 2452644676
is_multicast boolean false
longitude number 12.109700202942
bytes.rcvd.anomaly_index number 0
tcp.packets.out_of_order number 0
drop_all_host_traffic boolean false
packets.rcvd number 0
dhcpHost boolean false
duration number 23
tcp.packets.rcvd number 0
throughput_pps number 0.0
other_ip.bytes.rcvd.anomaly_index number 0
broadcast_domain_host boolean true
tskey string 146.48.99.68
other_ip.packets.sent number 0
udp.bytes.sent.anomaly_index number 0
low_goodput_flows.as_client.anomaly_index number 0
seen.first number 1556542967
total_activity_time number 25
throughput_trend_pps number 2
tcp.packets.sent number 0
is_broadcast boolean false
tcp.packets.retransmissions number 0
anomalous_flows.as_server number 0
low_goodput_flows.as_client number 0
packets.sent.anomaly_index number 0
host_unreachable_flows.as_client number 0
icmp.bytes.rcvd.anomaly_index number 0
latitude number 43.147899627686
country string IT
last_throughput_pps number 0.80018645524979
throughput_trend_bps number 2
names table
names.dhcp string Marlin
names.mdns string Marlin
num_alerts number 0
ifid number 3
name string Marlin
asname string Consortium GARR
udp.bytes.rcvd.anomaly_index number 0
udp.packets.rcvd number 0
active_http_hosts number 0
other_ip.bytes.rcvd number 0
other_ip.packets.rcvd number 0
contacts.as_client number 0
other_ip.bytes.sent.anomaly_index number 0
ndpi table
ndpi.Dropbox table
ndpi.Dropbox.packets.rcvd number 0
ndpi.Dropbox.duration number 5
ndpi.Dropbox.packets.sent number 4
ndpi.Dropbox.bytes.rcvd number 0
ndpi.Dropbox.breed string Acceptable
ndpi.Dropbox.bytes.sent number 1508
ndpi.MDNS table
ndpi.MDNS.packets.rcvd number 0
ndpi.MDNS.duration number 20
ndpi.MDNS.packets.sent number 32
ndpi.MDNS.bytes.rcvd number 0
ndpi.MDNS.breed string Acceptable
ndpi.MDNS.bytes.sent number 25801
ndpi.NetBIOS table
ndpi.NetBIOS.packets.rcvd number 0
ndpi.NetBIOS.duration number 15
ndpi.NetBIOS.packets.sent number 16
ndpi.NetBIOS.bytes.rcvd number 0
ndpi.NetBIOS.breed string Acceptable
ndpi.NetBIOS.bytes.sent number 2360
icmp.packets.sent number 0
asn number 137
packets.rcvd.anomaly_index number 0
flows.as_server number 0
icmp.bytes.sent number 0
ip string 146.48.99.68
bytes.sent.anomaly_index number 0
udp.bytes.rcvd number 0
udp.packets.sent number 52
mac string 00:0E:C6:C7:D8:4A
tcp.bytes.rcvd number 0
vlan number 0
flows.as_client number 5
tcp.bytes.sent number 0
devtype number 4
low_goodput_flows.as_server.anomaly_index number 0
contacts.as_server number 0
throughput_trend_bps_diff number -301.67028808594
localhost boolean false
active_flows.as_client number 5
other_ip.bytes.sent number 0
childSafe boolean false
unreachable_flows.as_server number 0
unreachable_flows.as_client number 0
seen.last number 1556542989
tcp.bytes.rcvd.anomaly_index number 0
ndpi_categories table
ndpi_categories.System table
ndpi_categories.System.bytes.sent number 2360
ndpi_categories.System.duration number 15
ndpi_categories.System.category number 18
ndpi_categories.System.bytes.rcvd number 0
ndpi_categories.System.bytes number 2360
ndpi_categories.Network table
ndpi_categories.Network.bytes.sent number 25801
ndpi_categories.Network.duration number 20
ndpi_categories.Network.category number 14
ndpi_categories.Network.bytes.rcvd number 0
ndpi_categories.Network.bytes number 25801
ndpi_categories.Cloud table
ndpi_categories.Cloud.bytes.sent number 1508
ndpi_categories.Cloud.duration number 5
ndpi_categories.Cloud.category number 13
ndpi_categories.Cloud.bytes.rcvd number 0
ndpi_categories.Cloud.bytes number 1508
icmp.bytes.sent.anomaly_index number 0
total_flows.as_client number 5
tcp.packets.keep_alive number 0
icmp.bytes.rcvd number 0
total_flows.as_server number 0
pktStats.sent table
pktStats.sent.upTo1024 number 2
pktStats.sent.rst number 0
pktStats.sent.finack number 0
pktStats.sent.upTo1518 number 14
pktStats.sent.above9000 number 0
pktStats.sent.upTo512 number 10
pktStats.sent.synack number 0
pktStats.sent.syn number 0
pktStats.sent.upTo64 number 0
pktStats.sent.upTo2500 number 0
pktStats.sent.upTo9000 number 0
pktStats.sent.upTo6500 number 0
pktStats.sent.upTo128 number 10
pktStats.sent.upTo256 number 16
icmp.packets.rcvd number 0
pktStats.recv table
pktStats.recv.upTo1024 number 0
pktStats.recv.rst number 0
pktStats.recv.finack number 0
pktStats.recv.upTo1518 number 0
pktStats.recv.above9000 number 0
pktStats.recv.upTo512 number 0
pktStats.recv.synack number 0
pktStats.recv.syn number 0
pktStats.recv.upTo64 number 0
pktStats.recv.upTo2500 number 0
pktStats.recv.upTo9000 number 0
pktStats.recv.upTo6500 number 0
pktStats.recv.upTo128 number 0
pktStats.recv.upTo256 number 0
operatingSystem number 0
city string 
anomalous_flows.as_client number 0
is_blacklisted boolean false
has_dropbox_shares boolean true
bytes.sent number 29669
host_unreachable_flows.as_server number 0
hiddenFromTop boolean false
tcp.packets.seq_problems boolean false
last_throughput_bps number 301.67028808594
throughput_bps number 0.0






macs.1.throughput_trend_bps_diff number 0.0
macs.1.bytes.sent number 6030
macs.1.location string lan
macs.1.arp_requests.rcvd number 0
macs.1.arp_replies.rcvd number 0
macs.1.bytes.sent.anomaly_index number 60
macs.1.packets.rcvd.anomaly_index number 0
macs.1.throughput_pps number 0.0
macs.1.fingerprint string 
macs.1.throughput_bps number 0.0
macs.1.seen.last number 1557827812
macs.1.talkers.asServer number 0
macs.1.talkers.asClient number 6
macs.1.packets.sent.anomaly_index number 0
macs.1.source_mac boolean true
macs.1.duration number 341
macs.1.special_mac boolean false
macs.1.last_throughput_bps number 0.0
macs.1.seen.first number 1557827472
macs.1.arp_requests.sent number 107
macs.1.pool number 0
macs.1.bytes.rcvd number 0
macs.1.devtype number 0
macs.1.operatingSystem number 0
macs.2 table
macs.2.bridge_seen_iface_id number 1
macs.2.packets.rcvd number 177
macs.2.manufacturer string Palo Alto Networks
macs.2.throughput_trend_pps number 2
macs.2.num_hosts number 7
macs.2.arp_replies.sent number 0
macs.2.throughput_trend_bps number 2
macs.2.bytes.ndpi.unknown number 0
macs.2.bytes.rcvd.anomaly_index number 60
macs.2.packets.sent number 365
macs.2.mac string 00:86:9C:75:5D:4C
macs.2.last_throughput_pps number 1.7996081113815
macs.2.throughput_trend_bps_diff number -858.01287841797
macs.2.bytes.sent number 214520
macs.2.location string lan
macs.2.arp_requests.rcvd number 0
macs.2.arp_replies.rcvd number 0
macs.2.bytes.sent.anomaly_index number 59
macs.2.packets.rcvd.anomaly_index number 60
macs.2.throughput_pps number 0.39991483092308
macs.2.fingerprint string 
macs.2.throughput_bps number 63.386501312256
macs.2.seen.last number 1557827829
macs.2.talkers.asServer number 0
macs.2.talkers.asClient number 0
macs.2.packets.sent.anomaly_index number 59
macs.2.source_mac boolean true
macs.2.duration number 365
macs.2.special_mac boolean false
macs.2.last_throughput_bps number 921.39935302734
macs.2.seen.first number 1557827465
macs.2.arp_requests.sent number 0
macs.2.pool number 0
macs.2.bytes.rcvd number 35059
macs.2.devtype number 8
macs.2.operatingSystem number 0
macs.3 table
macs.3.bridge_seen_iface_id number 1
macs.3.packets.rcvd number 14
macs.3.manufacturer string Palo Alto Networks
macs.3.throughput_trend_pps number 3
macs.3.num_hosts number 2
macs.3.arp_replies.sent number 0
macs.3.throughput_trend_bps number 3
macs.3.bytes.ndpi.unknown number 0
macs.3.bytes.rcvd.anomaly_index number 100
macs.3.packets.sent number 10
macs.3.mac string 00:86:9C:77:5C:4C
macs.3.last_throughput_pps number 0.0
macs.3.throughput_trend_bps_diff number 0.0
macs.3.bytes.sent number 716
macs.3.location string lan
macs.3.arp_requests.rcvd number 0
macs.3.arp_replies.rcvd number 0
macs.3.bytes.sent.anomaly_index number 0
macs.3.packets.rcvd.anomaly_index number 100
macs.3.throughput_pps number 0.0
macs.3.fingerprint string 
macs.3.throughput_bps number 0.0
macs.3.seen.last number 1557827817
macs.3.talkers.asServer number 0
macs.3.talkers.asClient number 0
macs.3.packets.sent.anomaly_index number 0
macs.3.source_mac boolean true
macs.3.duration number 211
macs.3.special_mac boolean false
macs.3.last_throughput_bps number 0.0
macs.3.seen.first number 1557827607
macs.3.arp_requests.sent number 0
macs.3.pool number 0
macs.3.bytes.rcvd number 11229
macs.3.devtype number 8
macs.3.operatingSystem number 0
macs.4 table
macs.4.bridge_seen_iface_id number 0
macs.4.packets.rcvd number 12
macs.4.seen.first number 1557827592
macs.4.throughput_trend_pps number 3
macs.4.num_hosts number 1
macs.4.arp_replies.sent number 0
macs.4.throughput_trend_bps number 3
macs.4.bytes.ndpi.unknown number 0
macs.4.bytes.rcvd.anomaly_index number 0
macs.4.packets.sent number 0
macs.4.mac string 01:00:5E:00:00:01
macs.4.last_throughput_pps number 0.0
macs.4.throughput_trend_bps_diff number 0.0
macs.4.bytes.sent number 0
macs.4.location string unknown
macs.4.arp_requests.rcvd number 0
macs.4.arp_replies.rcvd number 0
macs.4.bytes.sent.anomaly_index number 0
macs.4.packets.rcvd.anomaly_index number 0
macs.4.throughput_pps number 0.0
macs.4.fingerprint string 
macs.4.throughput_bps number 0.0
macs.4.seen.last number 1557827592
macs.4.talkers.asServer number 0
macs.4.packets.sent.anomaly_index number 0
macs.4.talkers.asClient number 0
macs.4.source_mac boolean false
macs.4.special_mac boolean true
macs.4.last_throughput_bps number 0.0
macs.4.duration number 1
macs.4.arp_requests.sent number 0
macs.4.pool number 0
macs.4.bytes.rcvd number 504
macs.4.devtype number 0
macs.4.operatingSystem number 0
macs.5 table
macs.5.bridge_seen_iface_id number 0
macs.5.packets.rcvd number 16
macs.5.seen.first number 1557827607
macs.5.throughput_trend_pps number 2
macs.5.num_hosts number 1
macs.5.arp_replies.sent number 0
macs.5.throughput_trend_bps number 2
macs.5.bytes.ndpi.unknown number 0
macs.5.bytes.rcvd.anomaly_index number 0
macs.5.packets.sent number 0
macs.5.mac string 01:00:5E:00:00:0D
macs.5.last_throughput_pps number 0.19995646178722
macs.5.throughput_trend_bps_diff number -13.597039222717
macs.5.bytes.sent number 0
macs.5.location string unknown
macs.5.arp_requests.rcvd number 0
macs.5.arp_replies.rcvd number 0
macs.5.bytes.sent.anomaly_index number 0
macs.5.packets.rcvd.anomaly_index number 0
macs.5.throughput_pps number 0.0
macs.5.fingerprint string 
macs.5.throughput_bps number 0.0
macs.5.seen.last number 1557827607
macs.5.talkers.asServer number 0
macs.5.packets.sent.anomaly_index number 0
macs.5.talkers.asClient number 0
macs.5.source_mac boolean false
macs.5.special_mac boolean true
macs.5.last_throughput_bps number 13.597039222717
macs.5.duration number 1
macs.5.arp_requests.sent number 0
macs.5.pool number 0
macs.5.bytes.rcvd number 1088
macs.5.devtype number 0
macs.5.operatingSystem number 0
macs.6 table
macs.6.bridge_seen_iface_id number 0
macs.6.packets.rcvd number 388
macs.6.seen.first number 1557827582
macs.6.throughput_trend_pps number 1
macs.6.num_hosts number 1
macs.6.arp_replies.sent number 0
macs.6.throughput_trend_bps number 1
macs.6.bytes.ndpi.unknown number 0
macs.6.bytes.rcvd.anomaly_index number 65
macs.6.packets.sent number 0
macs.6.mac string 01:00:5E:00:00:FB
macs.6.last_throughput_pps number 0.7998258471489
macs.6.throughput_trend_bps_diff number 105.37837219238
macs.6.bytes.sent number 0
macs.6.location string unknown
macs.6.arp_requests.rcvd number 0
macs.6.arp_replies.rcvd number 0
macs.6.bytes.sent.anomaly_index number 0
macs.6.packets.rcvd.anomaly_index number 65
macs.6.throughput_pps number 1.5996593236923
macs.6.fingerprint string 
macs.6.throughput_bps number 276.74105834961
macs.6.seen.last number 1557827582
macs.6.talkers.asServer number 0
macs.6.packets.sent.anomaly_index number 0
macs.6.talkers.asClient number 0
macs.6.source_mac boolean false
macs.6.special_mac boolean true
macs.6.last_throughput_bps number 171.36268615723
macs.6.duration number 1
macs.6.arp_requests.sent number 0
macs.6.pool number 0
macs.6.bytes.rcvd number 101646
macs.6.devtype number 0
macs.6.operatingSystem number 0
macs.7 table
macs.7.bridge_seen_iface_id number 0
macs.7.packets.rcvd number 8
macs.7.seen.first number 1557827697
macs.7.throughput_trend_pps number 2
macs.7.num_hosts number 2
macs.7.arp_replies.sent number 0
macs.7.throughput_trend_bps number 2
macs.7.bytes.ndpi.unknown number 0
macs.7.bytes.rcvd.anomaly_index number 100
macs.7.packets.sent number 0
macs.7.mac string 01:00:5E:7F:FF:FA
macs.7.last_throughput_pps number 0.19995646178722
macs.7.throughput_trend_bps_diff number -42.790679931641
macs.7.bytes.sent number 0
macs.7.location string unknown
macs.7.arp_requests.rcvd number 0
macs.7.arp_replies.rcvd number 0
macs.7.bytes.sent.anomaly_index number 0
macs.7.packets.rcvd.anomaly_index number 100
macs.7.throughput_pps number 0.0
macs.7.fingerprint string 
macs.7.throughput_bps number 0.0
macs.7.seen.last number 1557827697
macs.7.talkers.asServer number 0
macs.7.packets.sent.anomaly_index number 0
macs.7.talkers.asClient number 0
macs.7.source_mac boolean false
macs.7.special_mac boolean true
macs.7.last_throughput_bps number 42.790679931641
macs.7.duration number 1
macs.7.arp_requests.sent number 0
macs.7.pool number 0
macs.7.bytes.rcvd number 1712
macs.7.devtype number 0
macs.7.operatingSystem number 0
macs.8 table
macs.8.bridge_seen_iface_id number 1
macs.8.packets.rcvd number 0
macs.8.manufacturer string Apple, Inc.
macs.8.throughput_trend_pps number 3
macs.8.num_hosts number 1
macs.8.arp_replies.sent number 0
macs.8.throughput_trend_bps number 3
macs.8.bytes.ndpi.unknown number 0
macs.8.bytes.rcvd.anomaly_index number 0
macs.8.packets.sent number 12
macs.8.mac string 24:F6:77:15:86:4C
macs.8.last_throughput_pps number 0.0
macs.8.throughput_trend_bps_diff number 0.0
macs.8.bytes.sent number 1228
macs.8.location string lan
macs.8.arp_requests.rcvd number 0
macs.8.arp_replies.rcvd number 0
macs.8.bytes.sent.anomaly_index number 100
macs.8.packets.rcvd.anomaly_index number 0
macs.8.throughput_pps number 0.0
macs.8.fingerprint string 
macs.8.throughput_bps number 0.0
macs.8.seen.last number 1557827769
macs.8.talkers.asServer number 0
macs.8.talkers.asClient number 0
macs.8.packets.sent.anomaly_index number 100
macs.8.source_mac boolean true
macs.8.duration number 138
macs.8.special_mac boolean false
macs.8.last_throughput_bps number 0.0
macs.8.seen.first number 1557827632
macs.8.arp_requests.sent number 0
macs.8.pool number 0
macs.8.bytes.rcvd number 0
macs.8.devtype number 0
macs.8.operatingSystem number 0
macs.9 table
macs.9.bridge_seen_iface_id number 1
macs.9.packets.rcvd number 0
macs.9.manufacturer string Apple, Inc.
macs.9.arp_requests.sent number 0
macs.9.num_hosts number 2
macs.9.arp_replies.sent number 0
macs.9.throughput_trend_bps number 1
macs.9.bytes.ndpi.unknown number 0
macs.9.bytes.rcvd.anomaly_index number 0
macs.9.packets.sent number 63
macs.9.mac string 24:F6:77:15:C1:EE
macs.9.last_throughput_pps number 0.0
macs.9.throughput_trend_bps_diff number 155.16694641113
macs.9.bytes.sent number 14395
macs.9.location string lan
macs.9.arp_requests.rcvd number 0
macs.9.arp_replies.rcvd number 0
macs.9.bytes.sent.anomaly_index number 90
macs.9.packets.rcvd.anomaly_index number 0
macs.9.throughput_pps number 0.39991483092308
macs.9.fingerprint string 
macs.9.throughput_bps number 155.16694641113
macs.9.talkers.asServer number 0
macs.9.seen.last number 1557827827
macs.9.talkers.asClient number 0
macs.9.source_mac boolean true
macs.9.packets.sent.anomaly_index number 89
macs.9.duration number 365
macs.9.throughput_trend_pps number 1
macs.9.special_mac boolean false
macs.9.last_throughput_bps number 0.0
macs.9.seen.first number 1557827463
macs.9.model string iMac18,3
macs.9.pool number 0
macs.9.bytes.rcvd number 0
macs.9.devtype number 3
macs.9.operatingSystem number 0
macs.10 table
macs.10.bridge_seen_iface_id number 1
macs.10.packets.rcvd number 362
macs.10.manufacturer string Liteon Technology Corporation
macs.10.throughput_trend_pps number 2
macs.10.num_hosts number 3
macs.10.arp_replies.sent number 0
macs.10.throughput_trend_bps number 2
macs.10.bytes.ndpi.unknown number 0
macs.10.bytes.rcvd.anomaly_index number 59
macs.10.packets.sent number 425
macs.10.mac string 30:10:B3:0A:33:AB
macs.10.last_throughput_pps number 3.9991290569305
macs.10.throughput_trend_bps_diff number -1541.4637451172
macs.10.bytes.sent number 76217
macs.10.location string lan
macs.10.arp_requests.rcvd number 0
macs.10.arp_replies.rcvd number 3
macs.10.bytes.sent.anomaly_index number 67
macs.10.packets.rcvd.anomaly_index number 59
macs.10.throughput_pps number 0.79982966184616
macs.10.fingerprint string 
macs.10.throughput_bps number 99.978706359863
macs.10.seen.last number 1557827829
macs.10.talkers.asServer number 3
macs.10.talkers.asClient number 3
macs.10.packets.sent.anomaly_index number 61
macs.10.source_mac boolean true
macs.10.duration number 369
macs.10.special_mac boolean false
macs.10.last_throughput_bps number 1641.4425048828
macs.10.seen.first number 1557827461
macs.10.arp_requests.sent number 3
macs.10.pool number 0
macs.10.bytes.rcvd number 214316
macs.10.devtype number 0
macs.10.operatingSystem number 0
macs.11 table
macs.11.bridge_seen_iface_id number 0
macs.11.packets.rcvd number 12
macs.11.seen.first number 1557827592
macs.11.throughput_trend_pps number 3
macs.11.num_hosts number 1
macs.11.arp_replies.sent number 0
macs.11.throughput_trend_bps number 3
macs.11.bytes.ndpi.unknown number 0
macs.11.bytes.rcvd.anomaly_index number 0
macs.11.packets.sent number 0
macs.11.mac string 33:33:00:00:00:01
macs.11.last_throughput_pps number 0.0
macs.11.throughput_trend_bps_diff number 0.0
macs.11.bytes.sent number 0
macs.11.location string unknown
macs.11.arp_requests.rcvd number 0
macs.11.arp_replies.rcvd number 0
macs.11.bytes.sent.anomaly_index number 0
macs.11.packets.rcvd.anomaly_index number 0
macs.11.throughput_pps number 0.0
macs.11.fingerprint string 
macs.11.throughput_bps number 0.0
macs.11.seen.last number 1557827592
macs.11.talkers.asServer number 0
macs.11.packets.sent.anomaly_index number 0
macs.11.talkers.asClient number 0
macs.11.source_mac boolean false
macs.11.special_mac boolean true
macs.11.last_throughput_bps number 0.0
macs.11.duration number 1
macs.11.arp_requests.sent number 0
macs.11.pool number 0
macs.11.bytes.rcvd number 1032
macs.11.devtype number 0
macs.11.operatingSystem number 0
macs.12 table
macs.12.bridge_seen_iface_id number 0
macs.12.packets.rcvd number 373
macs.12.seen.first number 1557827582
macs.12.throughput_trend_pps number 1
macs.12.num_hosts number 1
macs.12.arp_replies.sent number 0
macs.12.throughput_trend_bps number 1
macs.12.bytes.ndpi.unknown number 0
macs.12.bytes.rcvd.anomaly_index number 63
macs.12.packets.sent number 0
macs.12.mac string 33:33:00:00:00:FB
macs.12.last_throughput_pps number 0.39991292357445
macs.12.throughput_trend_bps_diff number 180.7621307373
macs.12.bytes.sent number 0
macs.12.location string unknown
macs.12.arp_requests.rcvd number 0
macs.12.arp_replies.rcvd number 0
macs.12.bytes.sent.anomaly_index number 0
macs.12.packets.rcvd.anomaly_index number 64
macs.12.throughput_pps number 1.5996593236923
macs.12.fingerprint string 
macs.12.throughput_bps number 312.1335144043
macs.12.seen.last number 1557827582
macs.12.talkers.asServer number 0
macs.12.packets.sent.anomaly_index number 0
macs.12.talkers.asClient number 0
macs.12.source_mac boolean false
macs.12.special_mac boolean true
macs.12.last_throughput_bps number 131.37138366699
macs.12.duration number 1
macs.12.arp_requests.sent number 0
macs.12.pool number 0
macs.12.bytes.rcvd number 110229
macs.12.devtype number 0
macs.12.operatingSystem number 0
macs.13 table
macs.13.bridge_seen_iface_id number 0
macs.13.packets.rcvd number 12
macs.13.seen.first number 1557827596
macs.13.throughput_trend_pps number 3
macs.13.num_hosts number 1
macs.13.arp_replies.sent number 0
macs.13.throughput_trend_bps number 3
macs.13.bytes.ndpi.unknown number 0
macs.13.bytes.rcvd.anomaly_index number 0
macs.13.packets.sent number 0
macs.13.mac string 33:33:FF:35:18:54
macs.13.last_throughput_pps number 0.0
macs.13.throughput_trend_bps_diff number 0.0
macs.13.bytes.sent number 0
macs.13.location string unknown
macs.13.arp_requests.rcvd number 0
macs.13.arp_replies.rcvd number 0
macs.13.bytes.sent.anomaly_index number 0
macs.13.packets.rcvd.anomaly_index number 0
macs.13.throughput_pps number 0.0
macs.13.fingerprint string 
macs.13.throughput_bps number 0.0
macs.13.seen.last number 1557827596
macs.13.talkers.asServer number 0
macs.13.packets.sent.anomaly_index number 0
macs.13.talkers.asClient number 0
macs.13.source_mac boolean false
macs.13.special_mac boolean true
macs.13.last_throughput_bps number 0.0
macs.13.duration number 1
macs.13.arp_requests.sent number 0
macs.13.pool number 0
macs.13.bytes.rcvd number 1032
macs.13.devtype number 0
macs.13.operatingSystem number 0
macs.14 table
macs.14.bridge_seen_iface_id number 0
macs.14.packets.rcvd number 12
macs.14.seen.first number 1557827594
macs.14.throughput_trend_pps number 3
macs.14.num_hosts number 1
macs.14.arp_replies.sent number 0
macs.14.throughput_trend_bps number 3
macs.14.bytes.ndpi.unknown number 0
macs.14.bytes.rcvd.anomaly_index number 67
macs.14.packets.sent number 0
macs.14.mac string 33:33:FF:89:2B:72
macs.14.last_throughput_pps number 0.0
macs.14.throughput_trend_bps_diff number 0.0
macs.14.bytes.sent number 0
macs.14.location string unknown
macs.14.arp_requests.rcvd number 0
macs.14.arp_replies.rcvd number 0
macs.14.bytes.sent.anomaly_index number 0
macs.14.packets.rcvd.anomaly_index number 0
macs.14.throughput_pps number 0.0
macs.14.fingerprint string 
macs.14.throughput_bps number 0.0
macs.14.seen.last number 1557827594
macs.14.talkers.asServer number 0
macs.14.packets.sent.anomaly_index number 0
macs.14.talkers.asClient number 0
macs.14.source_mac boolean false
macs.14.special_mac boolean true
macs.14.last_throughput_bps number 0.0
macs.14.duration number 1
macs.14.arp_requests.sent number 0
macs.14.pool number 0
macs.14.bytes.rcvd number 1032
macs.14.devtype number 0
macs.14.operatingSystem number 0
macs.15 table
macs.15.bridge_seen_iface_id number 0
macs.15.packets.rcvd number 12
macs.15.seen.first number 1557827594
macs.15.throughput_trend_pps number 3
macs.15.num_hosts number 1
macs.15.arp_replies.sent number 0
macs.15.throughput_trend_bps number 3
macs.15.bytes.ndpi.unknown number 0
macs.15.bytes.rcvd.anomaly_index number 100
macs.15.packets.sent number 0
macs.15.mac string 33:33:FF:CF:76:CF
macs.15.last_throughput_pps number 0.0
macs.15.throughput_trend_bps_diff number 0.0
macs.15.bytes.sent number 0
macs.15.location string unknown
macs.15.arp_requests.rcvd number 0
macs.15.arp_replies.rcvd number 0
macs.15.bytes.sent.anomaly_index number 0
macs.15.packets.rcvd.anomaly_index number 0
macs.15.throughput_pps number 0.0
macs.15.fingerprint string 
macs.15.throughput_bps number 0.0
macs.15.seen.last number 1557827594
macs.15.talkers.asServer number 0
macs.15.packets.sent.anomaly_index number 0
macs.15.talkers.asClient number 0
macs.15.source_mac boolean false
macs.15.special_mac boolean true
macs.15.last_throughput_bps number 0.0
macs.15.duration number 1
macs.15.arp_requests.sent number 0
macs.15.pool number 0
macs.15.bytes.rcvd number 1032
macs.15.devtype number 0
macs.15.operatingSystem number 0

]]