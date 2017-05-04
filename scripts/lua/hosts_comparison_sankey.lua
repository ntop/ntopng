--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')
-- Default value
local debug = false
interface.select(ifname)
ifstats = interface.getStats()
max_num_links = 32
max_num_hosts = 8
aggregation = "ndpi"

compared_hosts = {}
compared_hosts_size = 0;

if(debug) then io.write("==== hosts_compared_sankey ====\n") end
hosts = _GET["hosts"]
if(debug) then io.write("Host:"..hosts.."\n") end

if (_GET["hosts"] ~= nil) then

  compared_hosts, compared_hosts_size = getHostCommaSeparatedList(_GET["hosts"])

  for k,v in pairs(compared_hosts) do
    if(debug) then io.write(k .. '-'.. v.."\n") end
  end
  if (compared_hosts_size >= 2) then

    if(_GET["aggregation"] ~= nil) then
        aggregation = _GET["aggregation"]
    end

    -- 1.    Find all flows between compared hosts
    flows_stats = interface.getFlowsInfo(nil, {detailedResults=true})
    flows_stats = flows_stats["flows"]

    links = {}
    links_size = 0

    ndpi = {}
    ndpi_size = compared_hosts_size

    l4 = {}
    l4_size = compared_hosts_size

    ports = {}
    ports_size = compared_hosts_size


    for key, value in ipairs(flows_stats) do

      cli_key = hostinfo2hostkey(flows_stats[key],"cli",ifstats.iface_vlan)
      srv_key = hostinfo2hostkey(flows_stats[key],"srv",ifstats.iface_vlan)
      if (debug) then io.write(cli_key .. '\t') end
      if (debug) then io.write(srv_key .. '\n') end

        process = 0
        cli_num = findStringArray(cli_key,compared_hosts)
        srv_num = findStringArray(srv_key,compared_hosts)

         if ( (cli_num ~= nil) and (srv_num ~= nil) )then
          if (cli_num and srv_num) then
            if (cli_key == srv_key) then
              process = 0
            else
              process = 1
            end
          else
            process = 0
          end
        end

        if (links_size > max_num_links) then process = 0 end
        if ((ndpi_size > max_num_hosts) or
            (l4_size > max_num_hosts) or
            (ports_size > max_num_hosts))then process = 0 end

        if (process == 1) then
            if (debug) then io.write("Cli:"..cli_key..",Srv:"..srv_key..",Ndpi:"..flows_stats[key]["proto.ndpi"]..",L4:"..flows_stats[key]["proto.l4"].."\n") end
            if (debug) then io.write("Aggregation:"..aggregation.."\n") end
            aggregation_value = {}
            if (aggregation == "ndpi") then
                if (debug) then io.write("=>Value:"..flows_stats[key]["proto.ndpi"].."\n") end
                -- 1.1   Save ndpi protocol
                if (ndpi[flows_stats[key]["proto.ndpi"]] == nil) then
                    ndpi[flows_stats[key]["proto.ndpi"]] = ndpi_size
                    ndpi_size = ndpi_size + 1
                    aggregation_value[0] = flows_stats[key]["proto.ndpi"]
                end
            end

            if (aggregation == "l4proto") then
                if (debug) then io.write("=>Value:"..flows_stats[key]["proto.l4"].."\n") end
                -- 1.2   Save l4 protocol
                if (l4[flows_stats[key]["proto.l4"]] == nil) then
                    l4[flows_stats[key]["proto.l4"]] = l4_size
                    l4_size = l4_size + 1
                    aggregation_value[0] = flows_stats[key]["proto.l4"]
                end
            end

            if (aggregation == "port") then
                if (debug) then io.write("=>Value:"..flows_stats[key]["cli.port"].."\n") end
                -- 1.3   Save port
                nport = 0
                if (ports[flows_stats[key]["cli.port"]] == nil) then
                    ports[flows_stats[key]["cli.port"]] = ports_size
                    ports_size = ports_size + 1
                    aggregation_value[nport] = flows_stats[key]["cli.port"]
                    nport = nport + 1
                end

                if (ports[flows_stats[key]["srv.port"]] == nil) then
                    ports[flows_stats[key]["srv.port"]] = ports_size
                    ports_size = ports_size + 1
                    aggregation_value[nport] = flows_stats[key]["srv.port"]
                    nport = nport + 1
                end
            end

            for k,v in pairs(aggregation_value) do
              if(debug) then io.write("links:" ..k .. '-' .. v ..'\n') end

                if (links[cli_key..":"..v] == nil) then
                    links[cli_key..":"..v] = {}
                    links[cli_key..":"..v]["value"] = flows_stats[key]["cli2srv.bytes"]
                else
                    links[cli_key..":"..v]["value"] = links[cli_key..":"..v]["value"] + flows_stats[key]["cli2srv.bytes"]
                end

                if (links[srv_key..":"..v] == nil) then
                    links[srv_key..":"..v] = {}
                    links[srv_key..":"..v]["value"] = flows_stats[key]["srv2cli.bytes"]
                else
                    links[srv_key..":"..v]["value"] = links[srv_key..":"..v]["value"] + flows_stats[key]["cli2srv.bytes"]
                end

                if(debug) then io.write("Client: "..cli_key..", aggregation: "..v..",Value: "..links[cli_key..":"..v]["value"].."\n") end
                if(debug) then io.write("Server: "..srv_key..", aggregation: "..v..",Value: "..links[srv_key..":"..v]["value"].."\n") end

            end
        end
    end

    -- 2.    Create node
    print '{"nodes":[\n'

    -- 2.1   Host node
    node_size = 0

    for i,host_ip in ipairs(compared_hosts) do

      if(node_size > 0) then
        print ",\n"
      end
      node_info = interface.getHostInfo(host_ip)

      if (node_info ~= nil) then
        vlan_id = node_info["vlan"]
      else
        vlan_id = " "
      end

      print ("\t{\"name\": \"" .. getResolvedAddress(hostkey2hostinfo(host_ip)) .. "\", \"ip\": \"" .. host_ip .. "\", \"vlan\": \"" .. vlan_id .. "\"}")
      node_size = node_size + 1
    end

    -- 2.2   Aggregation node

    if(aggregation == "l4proto") then
        aggregation_node = l4
    elseif (aggregation == "port") then
        aggregation_node = ports
    else
        -- Default ndpi
        aggregation_node = ndpi
    end

      for key,value in pairs(aggregation_node) do
          if(debug) then io.write("Aggregation Node: "..key.."\n") end
          if(node_size > 0) then
            print ",\n"
          end

          print ("\t{\"name\": \"" .. key .. "\", \"ip\": \"" .. key ..  "\"}")

          node_size = node_size + 1
      end


    -- 3.    Create links

    print "\n],\n"
    print '"links" : [\n'


    -- 2. print links
    num = 0
    for i,host_ip in ipairs(compared_hosts) do

       for aggregation_key,value in pairs(aggregation_node) do



           if(links[host_ip..":"..aggregation_key] ~= nil) then

            if(num > 0) then
               print ",\n"
           end
               val = links[host_ip..":"..aggregation_key]["value"]

               if (val == 0 ) then val = 1 end

               print ("\t{\"source\": "..(i -1).. ", \"target\": "..(compared_hosts_size + value -2)..", \"value\": " .. val .. ", \"aggregation\": \""..aggregation.."\"}")
               num = num + 1
           end

       end


    end


  end --End if (compared host size)
  print ("\n]}\n")
end -- End if _GET[hosts]





