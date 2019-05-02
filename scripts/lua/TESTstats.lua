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
print( json.encode(createStats(matrix), {indent = true} ) )



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

]]