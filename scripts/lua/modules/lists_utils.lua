--
-- (C) 2019-20 - ntop.org
--

local lists_utils = {}

local dirs = ntop.getDirs()
local os_utils = require("os_utils")
local categories_utils = require("categories_utils")
local json = require("dkjson")
local alerts_api = require("alerts_api")

-- ##############################################

local trace_level = TRACE_INFO -- TRACE_NORMAL

local CUSTOM_CATEGORY_MINING = 99
local CUSTOM_CATEGORY_MALWARE = 100
local CUSTOM_CATEGORY_ADVERTISEMENT = 101

local DEFAULT_UPDATE_INTERVAL = 86400
local MAX_LIST_ERRORS = 3

-- IP addresses have very litte impact on memory/load time.
-- 150k IP addresses rules can be loaded in 2 seconds
local MAX_TOTAL_IP_RULES = 1000000
-- Domain rules are the most expensive.
-- On average they take ~7.5 KB/domain. 40k rules are loaded in about 7 seconds.
local MAX_TOTAL_DOMAIN_RULES = 90000
-- JA3 rules use hash tables, so they are fast to load
local MAX_TOTAL_JA3_RULES = 200000

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
   ["ntop IP Malware Meltdown"] = {
      url = "http://blacklists.ntop.org/blacklist-ip.txt",
      category = CUSTOM_CATEGORY_MALWARE,
      format = "ip",
      enabled = false,
      update_interval = DEFAULT_UPDATE_INTERVAL,
   }, ["ntop Host Malware Meltdown"] = {
      url = "http://blacklists.ntop.org/blacklist-hostnames.txt",
      category = CUSTOM_CATEGORY_MALWARE,
      format = "domain",
      enabled = false,
      update_interval = DEFAULT_UPDATE_INTERVAL,
   }, ["Emerging Threats"] = {
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
   }, ["SSLBL JA3"] = {
      url = "https://sslbl.abuse.ch/blacklist/ja3_fingerprints.csv",
      format = "ja3_suricata_csv",
      category = CUSTOM_CATEGORY_MALWARE,
      enabled = true,
      update_interval = DEFAULT_UPDATE_INTERVAL,
   }
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

-- @brief save the lists stats and other status to redis.
-- @note see saveListsMetadataToRedis for user preferences information
local function saveListsStatusToRedis(lists)
   local status = {}

   for list_name, list in pairs(lists or {}) do
      status[list_name] = list.status
   end

   ntop.setPref(STATUS_KEY, json.encode(status))
end

-- ##############################################

-- @brief save the lists user preferences to redis.
-- @note see saveListsStatusToRedis for the list status
local function saveListsMetadataToRedis(lists)
   local metadata = {}

   for list_name, list in pairs(lists or {}) do
      local default_prefs = BUILTIN_LISTS[list_name]
      local meta = {}
      local has_custom_pref = false

      -- Only save the preferences that differ from the default configuration
      for key, val in pairs(list) do
         if((key ~= "status") and (default_prefs[key] ~= val)) then
            meta[key] = val
            has_custom_pref = true
         end
      end

      if(has_custom_pref) then
         metadata[list_name] = meta
      end
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
      list.name = key
   end

   return lists
end

-- ##############################################

function lists_utils.editList(list_name, metadata_override)
   local lists = lists_utils.getCategoryLists()
   local list = lists[list_name]

   if(not list) then
      return false
   end

   local was_triggered = (list.enabled ~= metadata_override.enabled)

   list = table.merge(list, metadata_override)
   lists[list_name] = list

   saveListsMetadataToRedis(lists)

   -- Trigger a reload, for example for disabled lists
   lists_utils.downloadLists()

   if(was_triggered) then
      -- Must reload the lists as a list was enabled/disabaled
      lists_utils.reloadLists()
   end
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
-- Returns a table:
--  in_progress: true if the update is still in progress and checkListsUpdate should be called again
--  needs_reload: if in_progress is false, then needs_reload indicates if some lists were updated and a reload is needed
local function checkListsUpdate(timeout)
   local lists = lists_utils.getCategoryLists()
   local begin_time = os.time()
   local now = begin_time
   local needs_reload = (ntop.getCache("ntopng.cache.category_lists.needs_reload") == "1")
   local all_processed = true

   initListCacheDir()

   for list_name, list in pairsByKeys(lists) do
      local list_file = getListCacheFile(list_name, false)

      if lists_utils.shouldUpdate(list_name, list, now) then
	 local temp_fname = getListCacheFile(list_name, true)

	 traceError(trace_level, TRACE_CONSOLE, string.format("Updating list '%s'...", list_name))
	 local started_at = os.time()
	 local res = ntop.httpFetch(list.url, temp_fname, timeout)

	 if(res and (res["RESPONSE_CODE"] == 200)) then
	    -- download was successful, replace the original file
	    os.rename(temp_fname, list_file)
	    list.status.last_error = false
	    list.status.num_errors = 0
	    needs_reload = true
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
	    all_processed = false
	    break
	 end
      end
   end

   -- update lists state
   saveListsStatusToRedis(lists)

   if(not all_processed) then
      -- Still in progress, do not mark as finished yet
      if(needs_reload) then
	 -- cache this for the next invocation of checkListsUpdate as
	 -- we are still in progress
	 ntop.setCache("ntopng.cache.category_lists.needs_reload", "1")
      end

      return {
	 in_progress = true
      }
   else
      ntop.delCache("ntopng.cache.category_lists.needs_reload")

      return {
	 in_progress = false,
	 needs_reload = needs_reload,
      }
   end
end

-- ##############################################

local cur_load_warnings = 0
local max_load_warnings = 50

local function loadWarning(msg)
   if(cur_load_warnings >= max_load_warnings) then
      return
   end

   traceError(TRACE_WARNING, TRACE_CONSOLE, msg)
   cur_load_warnings = cur_load_warnings + 1
end

--@return nil on parse error, "domain" if the loaded item is an host, "ip" otherwise
local function loadListItem(host, category, user_custom_categories, list)
   category = tonumber(category)

   -- Checking for "whitelisted hosts" (Format: !<host>)
   if string.sub(host, 1, 1) == "!" then
      return nil
   end

   if category ~= nil then
      --traceError(TRACE_NORMAL, TRACE_CONSOLE, host .. " -> " .. category)

      -- Checking for "whitelisted hosts"
      if user_custom_categories[category] ~= nil then
	 local hosts_map = swapKeysValues(user_custom_categories[category])
	 if hosts_map["!"..host] ~= nil then
	    return nil
	 end
      end

      if isIPv4(host) or isIPv4Network(host) then
	 -- IPv4 address
	 if((not list) or (list.format ~= "domain")) then
	   if((host == "0.0.0.0") or (host == "0.0.0.0/0")) then
	     loadWarning(string.format("Bad IPv4 address '%s' in list '%s'", host, list.name))
	   else
	     ntop.loadCustomCategoryIp(host, category)
	     return "ip"
	   end
	 else
	   loadWarning(string.format("Invalid IPv4 address '%s' in list '%s'", host, list.name))
	 end
      elseif isIPv6(host) then
	 -- IPv6 address
         loadWarning(string.format("Unsupported IPv6 address '%s' found in list '%s'", host, list.name))
      else
	 -- Domain
	 if((not list) or (list.format ~= "ip")) then
	   if((string.len(host) < 4) or (string.find(host, "%.") == nil)) then
	     traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Bad domain name '%s' in list '%s'", host, list.name))
	   else
	     ntop.loadCustomCategoryHost(host, category)
	     return "domain"
	   end
	 else
	   loadWarning(string.format("Invalid domain '%s' in list '%s'", host, list.name))
	 end
      end
   end

   return nil
end

-- ##############################################

local function parse_hosts_line(line)
   local words = string.split(line, "%s+")
   local host = nil

   if(words and (#words == 2)) then
      host = words[2]

      if((host == "localhost") or (host == "127.0.0.1") or (host == "::1")) then
	 host = nil
      end
   else
      -- invalid host
      host = nil
   end

   return(host)
end

-- ##############################################

local function handle_ja3_suricata_csv_line(line)
   local parts = string.split(line, ",")

   if((parts ~= nil) and (#parts >= 1)) then
      local md5_hash = parts[1]

      if(string.len(md5_hash) == 32) then
	 ntop.loadMaliciousJA3Hash(string.lower(md5_hash))
	 return(true)
      end
   end

   return(false)
end

-- ##############################################

-- Loads hosts from a list file on disk
local function loadFromListFile(list_name, list, user_custom_categories, stats)
   local list_fname = getListCacheFile(list_name)
   local f = io.open(list_fname, "r")
   local num_rules = 0
   local limit_exceeded = false

   if f == nil then
      if list.status.num_hosts > 0 then
	 -- avoid generating warnings during first startup
	 traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Could not find '%s'...", list_fname))
      end

      return(false)
   end

   traceError(trace_level, TRACE_CONSOLE, string.format("Loading '%s' [%s]...", list_name, list.format))

   for line in f:lines() do
      if ntop.isShutdown() then
	 break
      end
      local trimmed = line:match("^%s*(.-)%s*$")

      if((string.len(trimmed) > 0) and not(string.starts(trimmed, "#"))) then
	 local host = trimmed

	 if list.format == "hosts" then
	    host = parse_hosts_line(trimmed)
	 elseif list.format == "ja3_suricata_csv" then
	    -- handled differently
	    if handle_ja3_suricata_csv_line(trimmed) then
	       stats.num_ja3 = stats.num_ja3 + 1
	       num_rules = num_rules + 1
	    end
	    host = nil
	 end

	 if host then
	    local rv = loadListItem(host, list.category, user_custom_categories, list)

	    if(rv == "domain") then
	       stats.num_hosts = stats.num_hosts + 1
	       num_rules = num_rules + 1
	    elseif(rv == "ip") then
	       stats.num_ips = stats.num_ips + 1
	       num_rules = num_rules + 1
	    end
	 end

	 if((stats.num_ips >= MAX_TOTAL_IP_RULES) or
	       (stats.num_hosts >= MAX_TOTAL_DOMAIN_RULES) or
	       (stats.num_ja3 >= MAX_TOTAL_JA3_RULES)) then
	    limit_exceeded = true
	    break
	 end
      end
   end

   list.status.num_hosts = num_rules
   f:close()

   traceError(trace_level, TRACE_CONSOLE, string.format("\tRead '%d' rules", num_rules))

   if((num_rules == 0) and (not limit_exceeded)) then
      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("List '%s' has 0 rules. Please report this to https://github.com/ntop/ntopng", list_name))
   end

   return(limit_exceeded)
end

-- ##############################################

-- NOTE: this must be executed in the same thread as checkListsUpdate
local function reloadListsNow()
   local user_custom_categories = categories_utils.getAllCustomCategoryHosts()
   local lists = lists_utils.getCategoryLists()
   local stats = {num_hosts = 0, num_ips = 0, num_ja3 = 0, begin = os.time(), duration = 0}
   local limit_reached_error = nil

   if(not ntop.startCustomCategoriesReload()) then
      -- Too early, need to retry later
      traceError(trace_level, TRACE_CONSOLE, string.format("custom categories: too early reload"))
      return(false)
   end

   traceError(trace_level, TRACE_CONSOLE, string.format("custom categories: reloading now"))

   -- Load hosts from cached URL lists
   for list_name, list in pairsByKeys(lists) do
      if list.enabled then
	 if((not limit_reached_error) and loadFromListFile(list_name, list, user_custom_categories, stats)) then
	    -- A limit was exceeded
	    if(stats.num_ips >= MAX_TOTAL_IP_RULES) then
	       limit_reached_error = i18n("category_lists.too_many_ips_loaded", {limit = MAX_TOTAL_IP_RULES}) ..
		  ". " .. i18n("category_lists.disable_some_list")
	    elseif(stats.num_hosts >= MAX_TOTAL_DOMAIN_RULES) then
	       limit_reached_error = i18n("category_lists.too_many_hosts_loaded", {limit = MAX_TOTAL_DOMAIN_RULES}) ..
		  ". " .. i18n("category_lists.disable_some_list")
	    elseif(stats.num_ja3 >= MAX_TOTAL_JA3_RULES) then
	       limit_reached_error = i18n("category_lists.too_many_ja3_loaded", {limit = MAX_TOTAL_JA3_RULES}) ..
		  ". " .. i18n("category_lists.disable_some_list")
	    else
	       -- should never happen
	       limit_reached_error = "reloadListsNow: unknown error"
	    end

	    -- Continue to iterate to also set the error on the next lists
	    traceError(TRACE_WARNING, TRACE_CONSOLE, limit_reached_error)
	 end

	 if(limit_reached_error) then
	    -- Set the invalid status to show it into the gui
	    list.status.last_error = limit_reached_error

	    traceError(trace_level, TRACE_CONSOLE, limit_reached_error)
	 end
      end
   end

   -- update lists state
   saveListsStatusToRedis(lists)

   -- Load user-customized categories
   for category_id, hosts in pairs(user_custom_categories) do
      for _, host in ipairs(hosts) do
	 if ntop.isShutdown() then
	    break
	 end
	 loadListItem(host, category_id, user_custom_categories)
      end
   end

   -- Reload into memory
   ntop.reloadCustomCategories()
   ntop.reloadJA3Hashes()

   -- Calculate stats
   stats.duration = (os.time() - stats.begin)

   traceError(trace_level, TRACE_CONSOLE, string.format("Lists (%u hosts, %u IPs, %u JA3) loaded in %d seconds",
      stats.num_hosts, stats.num_ips, stats.num_ja3, stats.duration))

   -- Save the stats
   ntop.setCache("ntopng.cache.category_lists.load_stats", json.encode(stats))

   return(true)
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

-- @brief Clears the lists download errors
function lists_utils.clearErrors()
   local lists = lists_utils.getCategoryLists()

   for _, list in pairs(lists) do
      if(list.status ~= nil) then
	 list.status.num_errors = 0
      end
   end

   saveListsStatusToRedis(lists)
end

-- ##############################################

-- This is run in housekeeping.lua
function lists_utils.checkReloadLists()
   local forced_reload = (ntop.getCache("ntopng.cache.reload_lists_utils") == "1")
   local reload_now = false

   if(ntop.getCache("ntopng.cache.download_lists_utils") == "1") then
      local rv = checkListsUpdate(60 --[[ timeout ]])

      if(not rv.in_progress) then
	 ntop.delCache("ntopng.cache.download_lists_utils")
	 reload_now = forced_reload or rv.needs_reload
      end
   else
      reload_now = forced_reload
   end

   -- print("[DEBUG]  Checking reload [") if(reload_now) then print("reload now") else print("don't reload") end print("] !!!!\n")
   
   if reload_now then
      -- print("[DEBUG] **** Reloading ****\n")
      
      if reloadListsNow() then
	 -- print("[DEBUG]  Success !!!!\n")
	 -- success
	 ntop.delCache("ntopng.cache.reload_lists_utils")
      else
	 -- print("[DEBUG]  ERROR !!!!\n")
	 -- Remember to load the lists next time
	 ntop.setCache("ntopng.cache.reload_lists_utils", "1")
      end

      -- print("[DEBUG] **** Reloading is over ****\n")
   end
end

-- ##############################################

return lists_utils
