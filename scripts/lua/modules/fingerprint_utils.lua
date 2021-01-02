--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

-- #####################################################################

local fingerprint_utils = {}

-- #####################################################################

-- stats_key equals the name as returned by Host::lua
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

-- #####################################################################

-- @brief Extracts figerprint stats from host stats fetched with `interface.getHostInfo`
-- @param host_stats A lua table retrieved with `interface.getHostInfo`
-- @param fingerprint_type One of the keys of `available_fingerprints`
-- @return the extracted fingerprints stats or nil when no fingerprint stats are found
local function get_fingerprint_stats(host_stats, fingerprint_type)
   if not host_stats or not fingerprint_type or not available_fingerprints[fingerprint_type] then
      return false
   end

   local host_stats_k = available_fingerprints[fingerprint_type]["stats_key"]
   local fingerprint_stats = host_stats[host_stats_k]

   if fingerprint_stats and table.len(fingerprint_stats) > 0 then
      return fingerprint_stats
   end
end

-- #####################################################################

-- @brief Checks if host stats fetched with `interface.getHostInfo` contain fingerprint data of a certain type
-- @param host_stats A lua table retrieved with `interface.getHostInfo`
-- @param fingerprint_type One of the keys of `available_fingerprints`
-- @return true if the host fingerprints of `fingerprint_type`, false otherwise
function fingerprint_utils.has_fingerprint_stats(host_stats, fingerprint_type)
   if get_fingerprint_stats(host_stats, fingerprint_type) then
      return true
   end

   return false
end

-- #####################################################################

-- @brief Helper sort function to sort fingerprints by number of uses
-- @param a A fingerprint data table entry
-- @param b A fingerprint data table entry
-- @return True if a has more uses than b, false otherwise
function revFP(a, b)
   return (a.num_uses > b.num_uses)
end

-- #####################################################################

-- @brief Prints table rows on an HTML table with fingerprint data
-- @param host_stats A lua table retrieved with `interface.getHostInfo`
-- @param fingerprint_type One of the keys of `available_fingerprints`
-- @return nil
function fingerprint_utils.fingerprint2record(host_stats, fingerprint_type)
   local fingerprint_stats = get_fingerprint_stats(host_stats, fingerprint_type)

   if not fingerprint_stats then
      return
   end

   local num = 0
   local max_num = 50 -- set a limit
   for key, value in pairsByValues(fingerprint_stats, revFP) do
      if(num == max_num) then
	 break
      else
	 num = num + 1
	 print('<tr><td>'..available_fingerprints[fingerprint_type]["href"](key)..'</td>')
	 if not isEmptyString(value.app_name) then
	    print('<td align=left nowrap>'..value.app_name..'</td>')
	 end
	 print('<td align="right">'..formatValue(value.num_uses)..'</td>')
	 print('</tr>\n')
      end
   end

end

-- #####################################################################

return fingerprint_utils
