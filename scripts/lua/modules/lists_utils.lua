--
-- (C) 2018 - ntop.org
--

local lists_utils = {}

local dirs = ntop.getDirs()
local os_utils = require("os_utils")
local categories_utils = require("categories_utils")
local json = require("dkjson")

-- ##############################################

local CUSTOM_CATEGORY_MINING = 99
local CUSTOM_CATEGORY_MALWARE = 100

local DEFAULT_UPDATE_INTERVAL = 86400

-- supported formats: ip, domain, hosts
local BUILTIN_LISTS = {
  ["Emerging Threats"] = {
    url = "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = true,
  }, ["Cisco Talos Intelligence"] = {
    url = "https://talosintelligence.com/documents/ip-blacklist",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = true,
  }, ["Ransomware Domain Blocklist"] = {
    url = "https://ransomwaretracker.abuse.ch/downloads/RW_DOMBL.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "domain",
    enabled = true,
  }, ["Anti-WebMiner"] = {
    url = "https://raw.githubusercontent.com/greatis/Anti-WebMiner/master/hosts",
    category = CUSTOM_CATEGORY_MINING,
    format = "hosts",
    enabled = false,
  }, ["NoCoin Filter List"] = {
    url = "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt",
    category = CUSTOM_CATEGORY_MINING,
    format = "hosts",
    enabled = true,
  }
}

-- ##############################################

local function loadListsFromRedis()
  local redis_lists = ntop.getPref("ntopng.prefs.category_lists")

  if isEmptyString(redis_lists) then
    return {}
  end

  local decoded = json.decode(redis_lists)

  if isEmptyString(decoded) then
    return {}
  end

  return decoded
end

local function saveListsToRedis(lists)
  lists = lists or {}
  ntop.setPref("ntopng.prefs.category_lists", json.encode(lists))
end

-- ##############################################

function lists_utils.getCategoryLists()
  -- TODO add support for user defined urls
  local lists = {}
  local redis_lists = loadListsFromRedis()
  local default_status = {last_update=0, current_hosts=0, update_interval=DEFAULT_UPDATE_INTERVAL, last_error=false}

  for key, default_values in pairs(BUILTIN_LISTS) do
    local list = table.merge(default_values, redis_lists[key] or {})
    lists[key] = table.merge(default_status, list)
  end

  return lists
end

-- ##############################################

local function initListCacheDir()
  ntop.mkdir(os_utils.fixPath(string.format("%s/category_lists", dirs.workingdir)))
end

local function getListCacheFile(list_name, downloading)
  local f = string.format("%s/category_lists/%s.txt", dirs.workingdir, list_name)

  if downloading then
    f = string.format("%s.new", f)
  end

  return os_utils.fixPath(f)
end

-- ##############################################

-- Check if the lists require an update
-- Returns true if some lists where updated, false if anything is changed
function lists_utils.checkListsUpdate()
  local lists = lists_utils.getCategoryLists()
  local now = os.time()
  local needs_reload = false

  initListCacheDir()

  for list_name, list in pairsByKeys(lists) do
    local list_file = getListCacheFile(list_name, false)

    if list.enabled and
        ((list.last_update + list.update_interval <= now) or (not ntop.exists(list_file))) then
      local temp_fname = getListCacheFile(list_name, true)

      traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Updating list '%s'...", list_name))

      if ntop.httpFetch(list.url, temp_fname) then
        -- download was successful, replace the original file
        os.rename(temp_fname, list_file)
        list.last_error = false
        list.last_update = now
        needs_reload = true
      else
        -- failure
        traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Error occurred while downloading list '%s'", list_name))
        list.last_error = true
      end
    end
  end

  -- update lists state
  saveListsToRedis(lists)

  return needs_reload
end

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

local function loadFromListFile(list_name, list, user_custom_categories)
  local list_fname = getListCacheFile(list_name)
  local num_lines = 0
  local f = io.open(list_fname, "r")

  if f == nil then
    traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Could not find '%s'...", list_fname))
    return 0
  end
  
  traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Loading list '%s'...", list_fname))

  for line in f:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")

    if((string.len(trimmed) > 0) and not(string.starts(trimmed, "#"))) then
      local host = trimmed

      if list.format == "hosts" then
        host = string.split(trimmed, "%s")[2]
      end

      if host then
        if loadListItem(host, list.category, user_custom_categories) then
          num_lines = num_lines + 1
        end
      end
    end
  end

  f:close()
  return num_lines
end

-- ##############################################

-- NOTE: use reloadLists below if wait is a concern
function lists_utils.reloadListsNow()
-- TODO this should be performed on startup/periodically, not here
  lists_utils.checkListsUpdate()

  local user_custom_categories = categories_utils.getAllCustomCategoryHosts()
  local lists = lists_utils.getCategoryLists()

  -- Load hosts from cached URL lists
  for list_name, list in pairsByKeys(lists) do
    if list.enabled then
      list.current_hosts = loadFromListFile(list_name, list, user_custom_categories)
    end
  end

  -- update lists state
  saveListsToRedis(lists)

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
