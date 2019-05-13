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

--(utility) inline if
local function in_if(cond, t, f)
	if cond then return t else return f end
end 

local function setup()
	local schema
	--vedi graph_utils.lua linea 803 per l'unità di misura
    schema = ts_utils.newSchema("host:num_local_talkers", {step=300, rrd_fname="num_local_talkers", metrics_type=ts_utils.metrics.gauge} ) 
    schema:addTag("ifid")
    schema:addTag("host")
	schema:addMetric("talkers")     

    io.write("schema added\n")
end

local function create_host_data( hostname)
	local cont = 0
	local matrix = interface.getArpStatsMatrixInfo() --serve? 

	if not matrix then return 0	end

	for _, m_elem in pairs(matrix) do
		for i, stats in pairs(m_elem)do
			tmp = split(i,"-")
			src_ip = tmp[1]
			dst_ip = tmp[2]

			if src_ip == hostname or dst_ip == hostname then  
                cont = cont + 1
			end
		
		end
	end     

	return cont
end


--TRY: ma devo chiamare setup() per ogni host!? o lo fa lui visto che c'è il campo hostname?
function ts_custom.host_update_stats(when, hostname, host, ifstats, verbose)
    --    io.write("\nhost_update_stats invoked\n")
	--local info = interface.getMacInfo( interface.getHostInfo(hostname, nil)["mac"] )
	local n = create_host_data( hostname ) 

	if n > 0 then io.write(hostname .. " -->\t \t" .. n .. "\n") end 

	ts_utils.append("host:num_local_talkers",
		{ifid = ifstats.id, host = hostname,

		talkers = n..""},

		when, verbose
	)
end

setup()
return ts_custom
