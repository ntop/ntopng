--
-- (C) 2018 - ntop.org
--

local lists_utils = {}

local dirs = ntop.getDirs()
local lists_path = dirs.httpdocsdir .. "/other/lists"

local categories_utils = require "categories_utils"

-- ##############################################

local CUSTOM_CATEGORY_MALWARE = 100

local category_urls = {
   ["http://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"] = CUSTOM_CATEGORY_MALWARE,
}

-- ##############################################

local function loadListItem(host, category, user_custom_categories)
  category = tonumber(category)
  
  -- Checking for "whitelisted hosts" (Format: !<host>)
  if string.sub(host, 1, 1) == "!" then
    return false
  end

  if category ~= nil then
    --traceError(TRACE_NORMAL, TRACE_CONSOLE, host .. " -> " .. category)

    -- Checking for "whitelisted hosts"
    if user_custom_categories[category] ~= nil then
      local hosts_map = swapKeysValues(user_custom_categories[category])
      if hosts_map["!"..host] ~= nil then
        return false
      end
    end

    if isIPv4(host) or isIPv4Network(host) then  
      ntop.loadCustomCategoryIp(host, category)
      return true
    else
      ntop.loadCustomCategoryHost(host, category)
      return true
    end
  end

  return false
end

-- ##############################################

local function loadList(list_path, user_custom_categories)
  for line in io.lines(list_path) do
    if not starts(line, "#") then
      local parts = {}
      for word in line:gmatch("%S+") do parts[#parts + 1] = word end

      if #parts == 2 then
        host = parts[1]
        category = parts[2]

        loadListItem(host, category, user_custom_categories)
      end
    end
  end
end

-- ##############################################

local function loadListFromSimpleUrl(url, category, user_custom_categories)
  local resp = ntop.httpGet(url)

  if((resp ~= nil) and (resp["CONTENT"] ~= nil)) then
    local content = resp["CONTENT"]
    local line
    local lines = string.split(content, "\n")

    for _,line in pairs(lines) do
      line = trimSpace(line)
      if((string.len(line) > 0) and not(string.starts(line, "#"))) then
        -- print("Loading "..line.."\n")
        loadListItem(line, category, user_custom_categories)
      end
    end
  end
end

-- ##############################################

-- NOTE: use reloadLists below if wait is a concern
function lists_utils.reloadListsNow()
  local user_custom_categories = categories_utils.getAllCustomCategoryHosts()

  -- Load hosts from URL lists
  for url, category in pairs(category_urls) do
    loadListFromSimpleUrl(url, category, user_custom_categories)
  end

  -- Load hosts from local files
  for fname in pairs(ntop.readdir(lists_path) or {}) do
    local list_path = lists_path .. "/" .. fname

    traceError(TRACE_INFO, TRACE_CONSOLE, "Loading list " .. fname)
    loadList(list_path, user_custom_categories)
  end

  -- Load user-customized categories
  for category_id, hosts in pairs(user_custom_categories) do
    for _, host in ipairs(hosts) do
      loadListItem(host, category_id, user_custom_categories)
    end
  end

  -- Reload into memory
  ntop.reloadCustomCategories()
end

-- ##############################################

-- This avoids waiting for lists reload
function lists_utils.reloadLists()
  ntop.setCache("ntopng.cache.reload_lists_utils", "1")
end

function lists_utils.checkReloadLists()
  if ntop.getCache("ntopng.cache.reload_lists_utils") == "1" then
    lists_utils.reloadListsNow()
    ntop.delCache("ntopng.cache.reload_lists_utils")
  end
end

-- ##############################################

return lists_utils
