--
-- (C) 2013-26 - ntop.org
--

local json     = require("dkjson")
local discover = require("discover_utils")

return {
   name = "discover_lan",
   description = "Return a table of all devices currently visible on the local network, with MAC address, " ..
      "IP, hostname, manufacturer, and device type. " ..
      "First attempts an active scan (ARP + mDNS + SSDP); if no results, falls back to the passive " ..
      "MAC table that ntopng builds from observed traffic. " ..
      "Returns an error if the interface does not support discovery. " ..
      "Required arguments: ifid (integer) and ifname (string) — interface id and name as provided in the system prompt.",
   handler = function(args)
      if not args or not args.ifid then
         return nil, "Missing required argument: ifid"
      end
      interface.select(tostring(args.ifid))

      if not interface.isDiscoverableInterface() then
         return nil, "This interface does not support network discovery"
      end

      local ifname = args.ifname
      if not ifname then return nil, "Missing required argument: ifname" end
      local devices = {}

      -- Run active scan (populates cache, returns status only)
      local scan = discover.discover2table(ifname, true)
      if scan and scan.status and scan.status.code == "OK" then
         -- Read devices from cache
         local result = discover.discover2table(ifname, false)
         if result and result.devices and #result.devices > 0 then
            for _, dev in ipairs(result.devices) do
               local mfr = dev.manufacturer or ""
               if mfr == "" and not isEmptyString(dev.mac) then
                  local mi = interface.getMacInfo(dev.mac)
                  if mi then mfr = mi.manufacturer or "" end
               end
               devices[#devices + 1] = {
                  ip           = dev.ip      or "",
                  mac          = dev.mac     or "",
                  hostname     = dev.sym     or dev.name or "",
                  manufacturer = mfr,
                  device_type  = discover.devtype2string(dev.device_type) or "",
                  os           = dev.os_type     or "",
                  source       = "active",
               }
            end
         end
      end

      -- Fallback: passive MAC table
      if #devices == 0 then
         local known = interface.getMacsInfo(nil, 999, 0, false, true, nil, nil, nil, nil, nil) or {}
         local now   = os.time()
         for _, hmac in pairs(known.macs or {}) do
            if (hmac["bytes.sent"] or 0) > 0 and (now - (hmac["seen.last"] or 0)) < 300 then
               local ips = interface.findHostByMac(hmac.mac) or {}
               local ip  = ""
               for k, _ in pairs(ips) do ip = k; break end
               local hostname = ntop.getResolvedName(ip) or ""
               if hostname == ip then hostname = "" end
               devices[#devices + 1] = {
                  ip           = ip,
                  mac          = hmac.mac          or "",
                  hostname     = hostname,
                  manufacturer = hmac.manufacturer  or "",
                  device_type  = discover.devtype2string(hmac.devtype) or "",
                  os           = "",
                  source       = "passive",
               }
            end
         end
      end

      if #devices == 0 then
         return "No devices found on the LAN", nil
      end

      local rows = { "ip,mac,hostname,manufacturer,device_type,os,source" }
      for _, dev in ipairs(devices) do
         rows[#rows + 1] = string.format("%s,%s,%s,%s,%s,%s,%s",
            dev.ip, dev.mac, dev.hostname, dev.manufacturer,
            dev.device_type, dev.os, dev.source)
      end

      local hdr = string.format("LAN devices on %s — %d found\n", ifname, #devices)
      return hdr .. table.concat(rows, "\n"), nil
   end,
   opts = { read_only = true }
}
