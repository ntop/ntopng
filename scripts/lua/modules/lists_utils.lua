--
-- (C) 2018 - ntop.org
--

local lists_utils = {}

local dirs = ntop.getDirs()
local lists_path = dirs.httpdocsdir .. "/other/lists"
local CUSTOM_CATEGORY_MALWARE = 100

local blacklist_utils = require "blacklist_utils"

local function loadListItem(host, category)
  category = tonumber(category)

  if category ~= nil then
    --traceError(TRACE_NORMAL, TRACE_CONSOLE, host .. " -> " .. category)

    if category ~= CUSTOM_CATEGORY_MALWARE or blacklist_utils.isBlacklistEnabled() then
      if isIPv4Network(host) then
        if(category ~= CUSTOM_CATEGORY_MALWARE) then
          ntop.loadCustomCategoryIp(host, category)
        else
          -- Add the host to the blacklist instead
          ntop.addToHostBlacklist(host)
        end

        return true
      else
        ntop.loadCustomCategoryHost(host, category)
        return true
      end
    end
  end

  return false
end

local function loadList(list_path)
  for line in io.lines(list_path) do
    if not starts(line, "#") then
      local parts = {}
      for word in line:gmatch("%S+") do parts[#parts + 1] = word end

      if #parts == 2 then
        host = parts[1]
        category = parts[2]

        loadListItem(host, category)
      end
    end
  end
end

function lists_utils.reloadLists(force_purge)
  blacklist_utils.beginLoad(force_purge)

  for fname in pairs(ntop.readdir(lists_path) or {}) do
    local list_path = lists_path .. "/" .. fname

    traceError(TRACE_INFO, TRACE_CONSOLE, "Loading list " .. fname)
    loadList(list_path)
  end

  ntop.reloadCustomCategories()
  blacklist_utils.endLoad(force_purge)
end

return lists_utils
