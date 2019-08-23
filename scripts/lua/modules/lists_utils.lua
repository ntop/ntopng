--
-- (C) 2018 - ntop.org
--

local lists_utils = {}

local dirs = ntop.getDirs()
local os_utils = require("os_utils")
local categories_utils = require("categories_utils")
local json = require("dkjson")
local alerts_api = require("alerts_api")

-- ##############################################

local CUSTOM_CATEGORY_MINING = 99
local CUSTOM_CATEGORY_MALWARE = 100
local CUSTOM_CATEGORY_ADVERTISEMENT = 101

local DEFAULT_UPDATE_INTERVAL = 86400
local MAX_LIST_ERRORS = 3

local is_nedge = ntop.isnEdge()

-- supported formats: ip, domain, hosts
--
-- Examples:
--    [ip] 1.2.3.4
--    [ip] 1.2.3.0/24
--    [domain] amalwaredomain.com
--    [hosts] 127.0.0.1   amalwaredomain.com
--    [hosts] 127.0.0.1   1.2.3.4
--
local BUILTIN_LISTS = {
  ["Emerging Threats"] = {
    url = "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = true,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["Cisco Talos Intelligence"] = {
    url = "https://talosintelligence.com/documents/ip-blacklist",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = true,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["Ransomware Domain Blocklist"] = {
    url = "https://ransomwaretracker.abuse.ch/downloads/RW_DOMBL.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "domain",
    enabled = true,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["Ransomware IP Blocklist"] = {
    url = "https://ransomwaretracker.abuse.ch/downloads/RW_IPBL.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = false, -- Medium False Positive rate
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["Feodo Tracker Botnet C2 IP Blocklist"] = {
    url = "https://feodotracker.abuse.ch/downloads/ipblocklist.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = true,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["SSLBL Botnet C2 IP Blacklist"] = {
    url = "https://sslbl.abuse.ch/blacklist/sslipblacklist.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "ip",
    enabled = true,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["MalwareDomainList Hosts"] = {
    url = "https://www.malwaredomainlist.com/hostslist/hosts.txt",
    category = CUSTOM_CATEGORY_MALWARE,
    format = "hosts",
    enabled = false,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["Anti-WebMiner"] = {
    url = "https://raw.githubusercontent.com/greatis/Anti-WebMiner/master/hosts",
    category = CUSTOM_CATEGORY_MINING,
    format = "hosts",
    enabled = false,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["NoCoin Filter List"] = {
    url = "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt",
    category = CUSTOM_CATEGORY_MINING,
    format = "hosts",
    enabled = true,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["Disconnect.me Simple Ad List"] = {
    url = "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt",
    category = CUSTOM_CATEGORY_ADVERTISEMENT,
    format = "domain",
    enabled = is_nedge,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["hpHosts Ad and Tracking"] = {
    url = "https://hosts-file.net/ad_servers.txt",
    category = CUSTOM_CATEGORY_ADVERTISEMENT,
    format = "hosts",
    enabled = is_nedge,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  }, ["AdAway default blocklist"] = {
    url = "https://adaway.org/hosts.txt",
    category = CUSTOM_CATEGORY_ADVERTISEMENT,
    format = "hosts",
    enabled = is_nedge,
    update_interval = DEFAULT_UPDATE_INTERVAL,
  },
}

-- ##############################################

-- NOTE: metadata and status are handled as separate keys.
-- Metadata can only be updated by the gui, whereas status can only be
-- updated by housekeeping. This avoid concurrency issues.
local METADATA_KEY = "ntopng.prefs.category_lists.metadata"
local STATUS_KEY = "ntopng.prefs.category_lists.status"


local function loadListsFromRedis()
  local lists_metadata = ntop.getPref(METADATA_KEY)
  local lists_status = ntop.getPref(STATUS_KEY)

  if isEmptyString(lists_status) then
    return {}
  end

  local status = json.decode(lists_status)
  local lists = {}

  if not isEmptyString(lists_metadata) then
    lists = json.decode(lists_metadata)
  end

  lists = table.merge(BUILTIN_LISTS, lists)

  if((lists == nil) or (status == nil)) then
    return {}
  end

  for list_name, list in pairs(lists) do
    if status[list_name] then
      list.status = status[list_name]
    end
  end

  return lists
end

-- ##############################################

local function saveListsStatusToRedis(lists)
  local status = {}

  for list_name, list in pairs(lists or {}) do
    status[list_name] = list.status
  end

  ntop.setPref(STATUS_KEY, json.encode(status))
end

-- ##############################################

local function saveListsMetadataToRedis(lists)
  local metadata = {}

  for list_name, list in pairs(lists or {}) do
    local meta = table.clone(list)
    meta.status = nil

    metadata[list_name] = meta
  end

  ntop.setPref(METADATA_KEY, json.encode(metadata))
end

-- ##############################################

function lists_utils.getCategoryLists()
  -- TODO add support for user defined urls
  local lists = {}
  local redis_lists = loadListsFromRedis()

  local default_status = {last_update=0, num_hosts=0, last_error=false, num_errors=0}

  for key, default_values in pairs(BUILTIN_LISTS) do
    local list = table.merge(default_values, redis_lists[key] or {status = {}})
    list.status = table.merge(default_status, list.status)
    lists[key] = list
  end

  return lists
end

-- ##############################################

function lists_utils.editList(list_name, metadata_override)
  local lists = lists_utils.getCategoryLists()
  local list = lists[list_name]

  if not list then
    return false
  end

  list = table.merge(list, metadata_override)
  lists[list_name] = list

  saveListsMetadataToRedis(lists)

  -- Trigger a reload, for example for disabled lists
  lists_utils.downloadLists()
end

-- ##############################################

-- Force a single list reload
function lists_utils.updateList(list_name)
  ntop.setCache("ntopng.cache.category_lists.update." .. list_name, "1")
  lists_utils.downloadLists()
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

local function getNextListUpdate(list)
  local interval

  if(list.status.last_error and (list.status.num_errors < MAX_LIST_ERRORS)) then
    -- When the download fails, retry next hour
    interval = 3600
  else
    interval = list.update_interval
  end

  local next_update

  -- align if possible
  if interval == 3600 then
    next_update = ntop.roundTime(list.status.last_update, 3600, false)
  elseif interval == 86400 then
    next_update = ntop.roundTime(list.status.last_update, 86400, true --[[ UTC align ]])
  else
    next_update = list.status.last_update + interval
  end

  return next_update
end

-- Returns true if the given list should be updated
function lists_utils.shouldUpdate(list_name, list, now)
  local list_file = getListCacheFile(list_name, false)
  local next_update = getNextListUpdate(list)

  -- note: num_errors is used to avoid retying downloading the same list again when
  -- the file does not exist
  return(list.enabled and
    ((now >= next_update) or
      (not ntop.exists(list_file) and (list.status.num_errors < MAX_LIST_ERRORS)) or
      (ntop.getCache("ntopng.cache.category_lists.update." .. list_name) == "1")))
end

-- ##############################################

-- Check if the lists require an update
-- Returns true after all the lists are processed, false otherwise
local function checkListsUpdate(timeout)
  local lists = lists_utils.getCategoryLists()
  local begin_time = os.time()
  local now = begin_time

  initListCacheDir()

  for list_name, list in pairsByKeys(lists) do
    local list_file = getListCacheFile(list_name, false)

    if lists_utils.shouldUpdate(list_name, list, now) then
      local temp_fname = getListCacheFile(list_name, true)

      traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Updating list '%s'...", list_name))
      local started_at = os.time()
      local res = ntop.httpFetch(list.url, temp_fname, timeout)

      if(res and (res["RESPONSE_CODE"] == 200)) then
        -- download was successful, replace the original file
        os.rename(temp_fname, list_file)
        list.status.last_error = false
        list.status.num_errors = 0
      else
        -- failure
        local respcode = 0
        local last_error = i18n("delete_data.msg_err_unknown")

        if res and res["ERROR"] then
          last_error = res["ERROR"]
        elseif res and res["RESPONSE_CODE"] ~= nil then
          respcode = ternary(res["RESPONSE_CODE"], res["RESPONSE_CODE"], "-")

          if res["IS_PARTIAL"] then
            last_error = i18n("category_lists.connection_time_out", {duration=(os.time() - started_at)})
          else
            last_error = i18n("category_lists.server_returned_error")
          end

          if(respcode > 0) then
            last_error = last_error .. i18n("category_lists.http_code", {err_code = respcode})
          end
        end

        list.status.last_error = last_error
        list.status.num_errors = list.status.num_errors + 1

        alerts_api.store(
          alerts_api.categoryListsEntity(list_name),
          alerts_api.listDownloadFailedType(list_name, last_error)
        )
      end

      now = os.time()
      -- set last_update even on failure to avoid blocking on the same list again
      list.status.last_update = now
      ntop.delCache("ntopng.cache.category_lists.update." .. list_name)

      if now-begin_time >= timeout then
        -- took too long, will resume on next housekeeping execution
        break
      end
    end
  end

  -- update lists state
  saveListsStatusToRedis(lists)

  if now-begin_time >= timeout then
    -- Still in progress, do not mark as finished yet
    return false
  else
    return true
  end
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

-- Loads hosts from a list file on disk
local function loadFromListFile(list_name, list, user_custom_categories)
  local list_fname = getListCacheFile(list_name)
  local num_lines = 0
  local f = io.open(list_fname, "r")

  if f == nil then
    if list.status.num_hosts > 0 then
      -- avoid generating warnings during first startup
      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Could not find '%s'...", list_fname))
    end

    return 0
  end
  
  traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Loading list '%s'...", list_fname))

  for line in f:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")

    if((string.len(trimmed) > 0) and not(string.starts(trimmed, "#"))) then
      local host = trimmed

      if list.format == "hosts" then
        local words = string.split(trimmed, "%s+")

        if words and (#words == 2) then
          host = words[2]

          if((host == "localhost") or (host == "127.0.0.1") or (host == "::1")) then
            host = nil
          end
        else
          -- invalid host
          host = nil
        end
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

-- NOTE: this must be executed in the same thread as checkListsUpdate
local function reloadListsNow()
  local user_custom_categories = categories_utils.getAllCustomCategoryHosts()
  local lists = lists_utils.getCategoryLists()

  -- Load hosts from cached URL lists
  for list_name, list in pairsByKeys(lists) do
    if list.enabled then
      local new_hosts = loadFromListFile(list_name, list, user_custom_categories)

      if new_hosts > 0 then
        list.status.num_hosts = new_hosts
      end
    end
  end

  -- update lists state
  saveListsStatusToRedis(lists)

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

-- This is necessary to avoid concurrency issues
function lists_utils.downloadLists()
  ntop.setCache("ntopng.cache.download_lists_utils", "1")
end

-- ##############################################

-- This is run in housekeeping.lua
function lists_utils.checkReloadLists()
  local reload_now = (ntop.getCache("ntopng.cache.reload_lists_utils") == "1")

  if ntop.getCache("ntopng.cache.download_lists_utils") == "1" then
    if checkListsUpdate(60 --[[ timeout ]]) then
      ntop.delCache("ntopng.cache.download_lists_utils")
      -- lists where possibly updated, reload
      reload_now = true
    end
  end

  if reload_now then
    reloadListsNow()
    ntop.delCache("ntopng.cache.reload_lists_utils")
  end

  -- Possibly reload hosts blacklist status
  ntop.checkReloadHostBlacklist()
end

-- ##############################################

return lists_utils
