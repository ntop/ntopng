--
-- (C) 2017-21 - ntop.org
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

function dhcp_utils.editRanges(ifid, ranges_to_remove, ranges_to_add)
  local cur_ranges = ntop.getPref(getDhcpRangesKey(ifid))
  local num_ranges = 0

  if ranges_to_remove == "" then ranges_to_remove = nil end
  if ranges_to_add == "" then ranges_to_add = nil end
  if cur_ranges == "" then cur_ranges = nil end

  ranges_to_remove = swapKeysValues(string.split(ranges_to_remove or '', ',') or {ranges_to_remove})
  ranges_to_add = swapKeysValues(string.split(ranges_to_add or '', ',') or {ranges_to_add})
  cur_ranges = string.split(cur_ranges or '', ',') or {cur_ranges}
  num_ranges = #cur_ranges
  cur_ranges = swapKeysValues(cur_ranges)

  for k in pairs(ranges_to_remove) do
    if not ranges_to_add[k] then
      cur_ranges[k] = nil
    end
  end

  for k in pairs(ranges_to_add) do
    num_ranges = num_ranges + 1
    cur_ranges[k] = num_ranges
  end

  local sorted_ranges = {}

  -- NOTE: the sort order in cur_ranges should stay unchanged
  for k in pairsByValues(cur_ranges, asc) do
    sorted_ranges[#sorted_ranges + 1] = k
  end

  dhcp_utils.setRanges(ifid, table.concat(sorted_ranges, ','))
end

-- ##############################################

function dhcp_utils.setRanges(ifid, ranges_str)
  ntop.setPref(getDhcpRangesKey(ifid), ranges_str)
  interface.reloadDhcpRanges()
end

-- ##############################################

return dhcp_utils
