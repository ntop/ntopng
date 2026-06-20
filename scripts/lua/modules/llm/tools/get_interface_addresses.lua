--
-- (C) 2013-26 - ntop.org
--

local json = require("dkjson")

return {
   name = "get_interface_addresses",
   description = "Return the IP addresses assigned to the currently monitored network interface. " ..
      "Useful to identify the local machine IP without heuristics.",
   handler = function(args)
      local ifstats = interface.getStats()
      if not ifstats then
         return nil, "Unable to retrieve interface stats"
      end

      local out = {
         interface = ifstats.name or interface.getName(),
         ifid      = ifstats.id,
         addresses = {},
      }

      if not isEmptyString(ifstats.ip_addresses) then
         local tokens = split(ifstats.ip_addresses, ",")
         for _, addr in pairs(tokens or {}) do
            if not isEmptyString(addr) then
               out.addresses[#out.addresses + 1] = addr
            end
         end
      end

      return json.encode(out), nil
   end,
   opts = { read_only = true }
}
