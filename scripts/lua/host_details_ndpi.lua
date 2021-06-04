--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
require "historical_utils"

sendHTTPContentTypeHeader('text/html')

ifid = _GET["ifid"]
direction = _GET["sflow_filter"]

interface.select(ifid)
local host_info = url2hostinfo(_GET)
local host_ip = host_info["host"]
local host_vlan = host_info["vlan"]
local host = interface.getHostInfo(host_ip, host_vlan)

local now    = os.time()
local ago1h  = now - 3600
local protos = interface.getnDPIProtocols()

if(host == nil) then
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("ndpi_page.unable_to_find_host",{host_ip=host_ip}).."</div>")
   return
end

local FILTER_SENT_ONLY = "sent"
local FILTER_RECV_ONLY = "recv"

vals = {}
for k in pairs(host["ndpi"]) do
  vals[k] = k
  -- print(k)
end
table.sort(vals)

local filter_pass = function(row)
  local isok

  if direction == FILTER_SENT_ONLY and row["bytes.rcvd"] ~= 0 then
    isok = false
  elseif direction == FILTER_RECV_ONLY and row["bytes.sent"] ~= 0 then
    isok = false
  else
    isok = true
  end

  return isok
end

local total_sent
local total_recv

if direction ~= nil then
  total_sent = 0
  total_recv = 0

  for _k in pairsByKeys(vals , desc) do
    k = vals[_k]

    if filter_pass(host["ndpi"][k]) then
      total_sent = total_sent + host["ndpi"][k]["bytes.sent"]
      total_recv = total_recv + host["ndpi"][k]["bytes.rcvd"]
    end
  end
else
  total_sent = host["bytes.sent"]
  total_recv = host["bytes.rcvd"]
end

local total = total_sent + total_recv

print("<tr><td>Total</td><td class=\"text-end\">".. secondsToTime(host["total_activity_time"]) .."</td><td class=\"text-end\">" .. bytesToSize(total_sent) .. "</td><td class=\"text-end\">" .. bytesToSize(total_recv) .. "</td>")

print("<td>")
graph_utils.breakdownBar(total_sent, i18n("ndpi_page.sent"), total_recv, i18n("ndpi_page.rcvd"), 0, 100)
print("</td>\n")

print("<td colspan=2 class=\"text-end\">" ..  bytesToSize(total).. "</td></tr>\n")

for _k in pairsByKeys(vals , desc) do
  k = vals[_k]

  if filter_pass(host["ndpi"][k]) then
    print("<tr><td>")

    local host_href = hostinfo2detailshref(host_info, {page = "historical", ts_schema = "host:ndpi", protocol = k}, k.." "..formatBreed(host["ndpi"][k]["breed"]))
    print(host_href)

    t = host["ndpi"][k]["bytes.sent"]+host["ndpi"][k]["bytes.rcvd"]

    if((host["ndpi"][k]["bytes.sent"] == 0) and (host["ndpi"][k]["bytes.rcvd"] > 0)) then
       print(" <i class=\"fas fa-exclamation-triangle fa-lg\" style=\"color: orange;\"></i>")
    end

    historicalProtoHostHref(getInterfaceId(ifname), host, nil, protos[k], nil)

    print('</td>')
    print("<td class=\"text-end\">" .. secondsToTime(host["ndpi"][k]["duration"]) .. "</td>")
    print("<td class=\"text-end\">" .. bytesToSize(host["ndpi"][k]["bytes.sent"]) .. "</td><td class=\"text-end\">" .. bytesToSize(host["ndpi"][k]["bytes.rcvd"]) .. "</td>")

    print("<td>")
    graph_utils.breakdownBar(host["ndpi"][k]["bytes.sent"], i18n("ndpi_page.sent"), host["ndpi"][k]["bytes.rcvd"], i18n("ndpi_page.rcvd"), 0, 100)
    print("</td>\n")

    print("<td class=\"text-end\">" .. bytesToSize(t).. "</td><td class=\"text-end\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")
  end
end
