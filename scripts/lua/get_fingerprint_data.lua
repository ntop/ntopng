--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
require "flow_utils"
require "historical_utils"
local fingerprint_utils = require "fingerprint_utils"

local available_fingerprints = {
   ja3 = {
      stats_key = "ja3_fingerprint",
      href = function(fp) return '<A HREF="https://sslbl.abuse.ch/ja3-fingerprints/'..fp..'" target="_blank">'..fp..'</A>  <i class="fas fa-external-link-alt"></i>' end
   },
   hassh = {
      stats_key = "hassh_fingerprint",
      href = function(fp) return fp end
   }
}

sendHTTPContentTypeHeader('text/html')

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local fingerprint_type = _GET["fingerprint_type"]

-- #####################################################################

local stats

if(host_info["host"] ~= nil) then
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
end

fingerprint_utils.fingerprint2record(stats, fingerprint_type)
