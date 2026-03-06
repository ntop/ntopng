--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

local host_info = url2hostinfo(_GET)
-- Use sent or rcvd based on the direction parameter, defaulting to rcvd
local what      = (_GET["direction"] == "sent") and "sent" or "rcvd"
local host      = interface.getHostInfo(host_info["host"], host_info["vlan"])
local res       = {}

if host ~= nil then
   -- Navigate the dns.{direction}.queries table, nil if any level is missing
   local queries = host["dns"] and host["dns"][what] and host["dns"][what]["queries"]

   if queries ~= nil then
      local types = {
         { label = "A",     key = "num_a"     },
         { label = "NS",    key = "num_ns"    },
         { label = "CNAME", key = "num_cname" },
         { label = "SOA",   key = "num_soa"   },
         { label = "PTR",   key = "num_ptr"   },
         { label = "MX",    key = "num_mx"    },
         { label = "TXT",   key = "num_txt"   },
         { label = "AAAA",  key = "num_aaaa"  },
         { label = "ANY",   key = "num_any"   },
      }
      
      local other_count = queries["num_other"] or 0

      for _, dns_type in ipairs(types) do
         local count = queries[dns_type.key] or 0
         if count > 0 then
            res[#res + 1] = { label = dns_type.label, value = count }
         else
            other_count = other_count + count
         end
      end

      if other_count > 0 then
         res[#res + 1] = { label = "Other", value = other_count }
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)