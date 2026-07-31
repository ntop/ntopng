--
-- (C) 2013-26 - ntop.org
--

local json = require("dkjson")

return {
   name = "list_networks",
   description = "List the configured local networks (CIDR subnets) known to a monitored interface. " ..
      'content = JSON {"ifid":"<ifid>"}. ifid is required.',
   handler = function(content)
      local req = type(content) == "table" and content
                  or (type(content) == "string" and json.decode(content))
      if type(req) ~= "table" or isEmptyString(req.ifid) then
         return nil, "content must be JSON {ifid}"
      end

      interface.select(tostring(req.ifid))
      local networks_stats = interface.getNetworksStats()
      if not networks_stats or table.len(networks_stats) == 0 then
         return "no local networks configured for this interface", nil
      end

      local out = {}
      for n, ns in pairs(networks_stats) do
         out[#out + 1] = { cidr = n, network_id = ns.network_id }
      end
      return json.encode(out), nil
   end,
   opts = { read_only = true }
}
