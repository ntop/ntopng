--
-- (C) 2019 - ntop.org
--


--[[from --> https://www.ntop.org/guides/ntopng/api/timeseries/intro.html

----------VARI APPUNTI-------------

A schema can be seen as a table of a database. It specifies the data format and types. A schema is identified by it’s name and contains the following informations:

        Step: the expected interval, in seconds, between raw data points.
        Tags: a tag is a label which can be used to filter data. Example of tags are the interface name, host name and nDPI protocol name.
        Metrics: a metric is a particual value which is being measured. Example of metrics are the host bytes sent traffic, interface number of flows and ASN round trip time.
                All metrics must be consistent with the specified type (see below).
        Type: the type for all the metrics of the schema. Currently “counter” or “gauge”.
        Options: some driver specific options.

SCHEMA NAME: The two parts are separated by a single ":" (for example “host:ndpi”)

-ntopng provides metrics of two types, namely gauges (measure) and counters (incremental).

-ntopng itself can now be used as a timeseries exporter

Traffic elements (such as local hosts and interfaces) are iterated periodically and by some Lua scripts and their statistics are dumped in the form of timeseries.
Traffic elements are handled in some standard ways:

       1) Most traffic elements are implemented in C, and their statistics are passed to lua via the ::lua method.
          For example, AutonomousSystem::lua dumps the autonomous system statistics to lua. Important if the element has a ::tsLua method check out the case 2 below.

       2) Some other traffic elements are implemented in C, but their statistics are hold on a TimeseriesPoint rather then the element itself.
          For example, the local hosts data is stored into the HostTimeseriesPoint class.
          In order to add new timeseries for a local host, the HostTimeseriesPoint is the class to modify (and related ::lua method).

       3) Some traffic elements are implemented in Lua. Their state is stored in Redis usually in json form. This includes, for example, the SNMP devices.

Once the new metrics are available in lua it’s necessary to export such metrics as timeseries the metric should be declared in a timeseries schema and 
should be written to the timeseries driver; both actions can be implemented inside the custom timeseries scripts.

ntopng handles custom timeseries with updates every 1 minute for interfaces, 5 minutes for local hosts.
----------------
File ts_5min_custom.lua must contain a callback ts_custom.host_update_stats which is called by ntopng every 5 minutes for every active local host.
This callback accepts the following arguments:

       - "when" The time (expressed as a Unix Epoch) of the call
       - "hostname" The IP address of the host, possibly followed by a VLAN tag
       - "host" The host metrics in a lua table
       - "ifstats" The interface stats of the host interface
       - "verbose" and extra flag passed when ntopng is working in verbose mode

-----------------
File ts_minute_custom.lua must contain a callback ts_custom.iface_update_stats which is called by ntopng every minute for every monitored interface.
This callback accepts the following arguments:

        - "when"    The time (expressed as a Unix Epoch) of the call
        - "_ifname" The name of the monitored interface
        - "ifstats" The interface stats of the monitored interface
        - "verbose" and extra flag passed when ntopng is working in verbose mode

Callbacks can be used to append points to the timeseries. Indeed, once the schema is defined, it is necessary to append points to the timeseries.
The function used to append points to the timeseries is the ts_utils.append() 

(example: https://www.ntop.org/guides/ntopng/api/timeseries/adding_new_timeseries.html#example)

The first argument of ts_utils.append is the timeseries name and must be equal to the one specified when defining the schema.
The second argument is a table which must contain the tag (ifid) and the metric (packets) which must be set to their actual values.
As it can be seen from the example above, the field id of table ifstats is used to set tag ifid,
whereas the sum of ifstats.tcpPacketStats table fields retransmissions, out_of_order and lost are used as value for the metric packets.


]]

--TODO: per ora solo i pkt, poi aggiungo il numero di talkers ecc.

--TODO: fare in modo che non vengano create le time series se non è attiva la matrice arp


local ts_custom = {}

local ts_utils = require "ts_utils_core"
local matrix = interface.getArpStatsMatrixInfo()

--(utility) inline if
-- local function in_if(cond, t, f)
-- 	if cond then return t else return f end
-- end 

local function setup()
    local schema
    
    schema = ts_utils.newSchema("host:arp_packets_counter", {step=300} ) -- andrà bene 300 che è anche il tempo di mantenimento di una cella della matrice arp?

    schema:addTag("ifid")
    schema:addTag("host")
    --schema:addTag("mac")  --come tag cista, ma che valore passo per tale tag dentro la append()?

    schema:addMetric("replies_sent_packets")
    schema:addMetric("requests_sent_packets")
    schema:addMetric("replies_received_packets")
    schema:addMetric("requests_received_packets")

    --aggiungo lo schema per il numero di talkers qui!? o serve un altro script?
    --schema:addTag("talkers")
    --schema:addMetric("talkers")
end


--TODO: È UN WIP, FINISCILO!!!!!
local function create_host_data(matrix)
	local t_res = {}

	if not matrix then
		--TODO: popola tabella coi valori a 0, oppure nil?
		return false
	end

	for _, m_elem in pairs(matrix) do
		for i, stats in pairs(m_elem)do
			tmp = split(i,"-")
			src_ip = tmp[1]
			dst_ip = tmp[2]

			if not t_res[src_ip] then    --il controllo serve solo per il dst2src
                t_res[src_ip] = {          -- nuovo elemento
                        pkts_snt = stats["src2dst.requests"] + stats["src2dst.replies"],
                        pkts_rcvd = stats["dst2src.requests"] + stats["dst2src.replies"],
                        talkers_num = 1
                    }
            else                        -- aggiorno a basta
                t_res[src_ip].pkts_snt = t_res[src_ip].pkts_snt + stats["src2dst.requests"] + stats["src2dst.replies"]
                t_res[src_ip].pkts_rcvd = t_res[src_ip].pkts_rcvd + stats["dst2src.requests"] + stats["dst2src.replies"]
                t_res[src_ip].talkers_num = t_res[src_ip].talkers_num +1
            end

    --ORA IL DST2SRC

            if not t_res[dst_ip] then 
                t_res[dst_ip] = {          -- nuovo elemento
                        pkts_rcvd = stats["src2dst.requests"] + stats["src2dst.replies"],
                        pkts_snt = stats["dst2src.requests"] + stats["dst2src.replies"],
                        talkers_num = 1
                    }
            else                        -- aggiorno a basta
                t_res[dst_ip].pkts_snt = t_res[dst_ip].pkts_snt + stats["dst2src.requests"] + stats["dst2src.replies"]
                t_res[dst_ip].pkts_rcvd = t_res[dst_ip].pkts_rcvd +  stats["src2dst.requests"] + stats["src2dst.replies"]
                t_res[dst_ip].talkers_num = t_res[dst_ip].talkers_num +1
            end

		end --end main cicle
	end     

	return t_res
end

--[[
STRUTTURA DELLA (WIP)-TABELLA RESTITUITA DA creare_host_data():

	>IP
		>tot replies sent
		>tot replies received
		>tot requests sent
		>tot requests received

]]



--TRY: ma devo chiamare setup() per ogni host!? o lo fa lui visto che c'è il campo hostname?
function ts_custom.host_update_stats(when, hostname, host, ifstats, verbose)

	--METODO 1: 

	local info = interface.getMacInfo( interface.getHostInfo(hostname, nil)["mac"] )

	-- if not info then 
	-- 	info["arp_replies.sent"]  = 0
	-- 	info["arp_requests.sent"] = 0
	-- 	info["arp_replies.rcvd"]  = 0
	-- 	info["arp_requests.rcvd"] = 0
	-- end
	tprint(info["arp_replies.sent"])
	tprint(info["arp_requests.sent"])
	tprint(info["arp_replies.rcvd"])
	tprint(info["arp_requests.rcvd"])

	--METODO 2:
		--uso la arp matrix e la funzione sopra
	if info then 	

		ts_utils.append("host:arp_packets_counter",
			{	ifid = ifstats.id,
				host = hostname,

				--TODO: popola
				replies_sent_packets 		= info["arp_replies.sent"] ,
				requests_sent_packets 		= info["arp_requests.sent"],
				replies_received_packets 	= info["arp_replies.rcvd"],
				requests_received_packets 	= info["arp_requests.rcvd"],

				when, verbose
			}
		)
	end
end

setup()
return ts_custom
