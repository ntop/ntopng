local json = require("dkjson")
local page_utils = require("page_utils")

return {
   name = "get_host_info",
   description = "Retrieve live, in-memory traffic statistics for a host that is currently active on the network. " ..
      "Data reflects real-time state: active flows, bytes/packets, protocol breakdown, scores, and alerts. " ..
      "Use this when asking about what a host is doing RIGHT NOW. " ..
      "If the host is offline, no data will be returned. " ..
      'content = JSON {"ip":"<ip>","vlan":"<vlan>"}. ' ..
      "ip is required. vlan defaults to 0 if omitted.",
   handler = function(content)
      local req = type(content) == "table" and content
                  or (type(content) == "string" and json.decode(content))
      if type(req) ~= "table" then
         return nil, "content must be JSON {ip, vlan}"
      end
      local host_ip  = req.ip
      local host_key = hostkey2hostinfo(host_ip)
      local info     = interface.getHostInfo(host_key["host"], host_key["vlan"])
      if not info then
         return "No data found for host " .. tostring(host_ip), nil
      end
      local out = {
         ip              = info.ip,
         name            = info.name,
         mac             = info["mac.address"],
         vlan            = info.vlan,
         bytes_sent      = info["bytes.sent"],
         bytes_rcvd      = info["bytes.rcvd"],
         num_flows       = info["active_flows.as_client"] and
                           (info["active_flows.as_client"] + (info["active_flows.as_server"] or 0)),
         score           = info.score,
         country         = info.country,
         os              = info.os,
         manufacturer    = info.manufacturer,
         is_blacklisted  = info["is_blacklisted"],
         num_alerts      = info.num_alerts,
         seen_first      = info["seen.first"],
         seen_last       = info["seen.last"],
      }
      return json.encode(out), nil
   end,
   opts = { read_only = true }
}
