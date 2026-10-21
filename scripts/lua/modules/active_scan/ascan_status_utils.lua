--
-- (C) 2026 - ntop.org
--
-- Lightweight active scan helpers with no heavy dependencies, for frequently
-- polled callers (e.g. rest/v2/get/interface/data.lua): requiring ascan_utils
-- also loads recipients, ascan_db_utils, ascan_rest_utils, ... which takes
-- hundreds of ms per request. ascan_utils delegates to this module.
--

local json = require "dkjson"

local ascan_status_utils = {}

-- Hash: host-scan_type -> JSON with the host scan status
ascan_status_utils.host_to_scan_key = "ntopng.vs.hosts.scanned_values"

ascan_status_utils.scan_status = {
   error       = 0,
   ok          = 1,
   scheduled   = 2,
   not_scanned = 3,
   scanning    = 4,
   failed      = 5,
}

local NMAP_PATHS = {
   "/usr/bin/nmap",
   "/usr/local/bin/nmap",
   "/opt/homebrew/bin/nmap"
}

-- ##############################################

-- @brief Returns the path of the nmap binary, nil if not installed
function ascan_status_utils.get_nmap_binary()
   for _, p in ipairs(NMAP_PATHS) do
      if ntop.exists(p) then
         return p
      end
   end

   return nil
end

-- ##############################################

-- @brief Same result as ascan_utils.is_available() without loading the scan
--        modules: all the modules in active_scan/modules require nmap
function ascan_status_utils.is_available()
   if ntop.isnEdge and ntop.isnEdge() then
      return false
   end

   return (ascan_status_utils.get_nmap_binary() ~= nil)
end

-- ##############################################

-- @brief Returns the total number of hosts to scan and how many of them are
--        scheduled or being scanned
function ascan_status_utils.check_in_progress_status()
   local hash_keys = ntop.getHashKeysCache(ascan_status_utils.host_to_scan_key)
   local scheduled = ascan_status_utils.scan_status.scheduled
   local scanning = ascan_status_utils.scan_status.scanning
   local total_in_progress = 0
   local total = 0

   if hash_keys then
      for k in pairs(hash_keys) do
         local hash_value_string = ntop.getHashCache(ascan_status_utils.host_to_scan_key, k)

         if (hash_value_string ~= nil) and (hash_value_string ~= "") then
            local hash_value = json.decode(hash_value_string)

            if hash_value and ((hash_value.is_ok_last_scan == scheduled) or (hash_value.is_ok_last_scan == scanning)) then
               total_in_progress = total_in_progress + 1
            end

            total = total + 1
         end
      end
   end

   return total, total_in_progress
end

-- ##############################################

return ascan_status_utils
