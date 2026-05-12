local json = require("dkjson")

return {
   name = "get_mac_info",
   description = "Return details for a given MAC address: manufacturer, device type, host pool, " ..
      "and the list of IP addresses currently associated with it. " ..
      "Required argument: mac (string, e.g. '00:11:22:33:44:55').",
   handler = function(args)
      if not args or not args.mac then
         return nil, "Missing required argument: mac"
      end
      local mac = tostring(args.mac)
      local dev = interface.getMacInfo(mac)
      if not dev then
         return nil, "MAC address not found: " .. mac
      end

      local out = {
         mac          = mac,
         manufacturer = dev.manufacturer or dev.vendor or "unknown",
         device_type  = dev.device_type  or dev.devtype or "unknown",
         host_pool_id = dev.host_pool_id or 0,
         num_hosts    = dev.num_hosts    or 0,
         bytes_sent   = dev.bytes and dev.bytes.sent  or 0,
         bytes_rcvd   = dev.bytes and dev.bytes.rcvd  or 0,
         score        = dev.score        or 0,
         seen_first   = dev["seen.first"] or 0,
         seen_last    = dev["seen.last"]  or 0,
      }

      local hosts_info = interface.getMacHosts(mac)
      local ips = {}
      if hosts_info then
         for ip, _ in pairs(hosts_info) do ips[#ips + 1] = ip end
      end
      out.associated_ips = ips

      return json.encode(out), nil
   end,
   opts = { read_only = true }
}
