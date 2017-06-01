--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')
local debug = false

------------------------

function setAggregationValue(p_type,p_flow,p_key)
  l_array = {}
  if (p_type == "ndpi") then
    l_array = ndpi
  elseif (p_type == "l4proto") then
    l_array = l4
  else -- port
    l_array = ports
  end

  if (l_array[p_flow[p_key]] == nil) then
      aggregation_value[aggregation_value_size] = p_flow[p_key];
      aggregation_value_size = aggregation_value_size + 1
      l_array[p_flow[p_key]] = {}
      l_array[p_flow[p_key]]["flows.bytes"] = p_flow["bytes"]
  else
      l_array[p_flow[p_key]]["flows.bytes"] = l_array[p_flow[p_key]]["flows.bytes"] + p_flow["bytes"]
  end

  if(debug) then io.write(p_type.." bytes: "..l_array[p_flow[p_key]]["flows.bytes"].."\n") end

  if (p_type == "ndpi") then
    ndpi = l_array
  elseif (p_type == "l4proto") then
    l4 = l_array
  else -- port
    ports =l_array
  end

end

------------------------


-- Default value
interface.select(ifname)
aggregation = "ndpi"

max_num_hosts = 24
compared_hosts = {}
compared_hosts_size = 0;

ifstats = interface.getStats()

if(ifstats.sprobe) then
   base_url = ntop.getHttpPrefix().."/lua/sflows_stats.lua?"
else
   base_url = ntop.getHttpPrefix().."/lua/flows_stats.lua?"
end

hosts = _GET["hosts"]
aggregation = _GET["aggregation"]

if(hosts == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> This flow cannot be found (expired ?)</div>")
else
  if(debug) then io.write("Host:"..hosts.."\n") end

  compared_hosts, compared_hosts_size = getHostCommaSeparatedList(hosts)

  if (compared_hosts_size >= 2) then

    if(_GET["aggregation"] == nil) then
      aggregation = "ndpi"
    end

    -- 1.    Find all flows between compared hosts
    flows_stats = interface.getFlowsInfo(nil,{detailsLevel="higher"})
    flows_stats = flows_stats["flows"]

    ndpi = {}
    l4 = {}
    ports = {}

    aggregation_value = {}
    aggregation_value_size = 1
    num = 0
    for key, value in ipairs(flows_stats) do
      flow = flows_stats[key]

      cli_key = hostinfo2hostkey(flow,"cli",ifstats.vlan)
      srv_key = hostinfo2hostkey(flow,"srv",ifstats.vlan)
      if (debug) then io.write(cli_key .. '\t') end
      if (debug) then io.write(srv_key .. '\n') end

      process = 0
      if ((findStringArray(cli_key,compared_hosts)) and
        (findStringArray(srv_key,compared_hosts)))then
        if(cli_key ~= srv_key) then process  = 1 end
      end -- findStringArray

      if (num > max_num_hosts)then process = 0 end

      if (process == 1) then

        if (debug) then io.write("PROCESS => Cli:"..cli_key..",Srv:"..srv_key..",Ndpi:"..flow["proto.ndpi"]..",L4:"..flow["proto.l4"]..",Bytes:"..flow["bytes"].."\n") end

        -- 1.1   Save ndpi protocol
        if (aggregation == "ndpi") then
          setAggregationValue(aggregation,flow,"proto.ndpi")
        end
        -- 1.2   Save l4 protocol
        if (aggregation == "l4proto") then
          setAggregationValue(aggregation,flow,"proto.l4")
        end
        -- 1.3   Save port
        if (aggregation == "port") then
          setAggregationValue(aggregation,flow,"cli.port")
          setAggregationValue(aggregation,flow,"srv.port")
        end
        num = num + 1
      end
    end

    print( "{\n\"name\": \"flare\",\n\"children\": [\n")
    num = 0
    for key, value in pairs(aggregation_value) do

      if(num > 0) then
       print ",\n"
      end

      flow_bytes = 1;
      if (aggregation == "port") then
       flow_bytes = ports[aggregation_value[key]]["flows.bytes"]
       elseif (aggregation == "l4proto") then
           flow_bytes = l4[aggregation_value[key]]["flows.bytes"]
       else
           flow_bytes = ndpi[aggregation_value[key]]["flows.bytes"]
       end

       local param_name
       if aggregation == "port" then
         param_name = "port"
       else
         param_name = "application"
       end
       url = base_url.."hosts=".._GET["hosts"].."&aggregation="..aggregation.."&"..param_name.."="..aggregation_value[key]

       print ("\t{\n\t\"name\": \"" ..aggregation_value[key].. "\",\n\t\"children\": [ \n\t{\"name\": \"" .. aggregation_value[key] .. "\", \"size\": " .. flow_bytes ..", \"aggregation\": \"" .. aggregation .. "\", \"key\": \"" .. aggregation_value[key] .."\", \"url\": \"" .. url .."\"}\n\t]\n\t}")

       num = num + 1

    end

  end --End if (compared host size)
  print ("\n]}\n")

end -- End if _GET[hosts]





