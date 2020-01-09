--
-- (C) 2017-20 - ntop.org
--

local dhcp_utils = {}

-- ##############################################

local function getDhcpRangesKey(ifid)
  return string.format("ntopng.prefs.ifid_%u.dhcp_ranges", ifid)
end

-- ##############################################

function dhcp_utils.listRanges(ifid)
  local ranges_str = ntop.getPref(getDhcpRangesKey(ifid))
  local ranges = string.split(ranges_str, ",") or {ranges_str}
  local res = {}

  for _, range in ipairs(ranges) do
    local r = string.split(range, "%-")

    if r and #r == 2 then
      res[#res + 1] = {r[1], r[2]}
    end
  end

  return res
end

-- ##############################################

function dhcp_utils.setRanges(ifid, ranges_str)
  ntop.setPref(getDhcpRangesKey(ifid), ranges_str)
  interface.reloadDhcpRanges()
end

-- ##############################################

return dhcp_utils
