--
-- (C) 2019-24 - ntop.org
--
local lists_utils = {}

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_trace"
require "lua_utils_generic"
local json = require("dkjson")
local os_utils = require("os_utils")

-- ##############################################

-- NOTE: metadata and status are handled as separate keys.
-- Metadata can only be updated by the gui, whereas status can only be
-- updated by housekeeping. This avoid concurrency issues.
local METADATA_KEY = "ntopng.cache.category_lists.metadata"
local STATUS_KEY = "ntopng.cache.category_lists.status"

local trace_level = TRACE_INFO -- TRACE_NORMAL

local CUSTOM_CATEGORY_MINING = 99
local CUSTOM_CATEGORY_MALWARE = 100
local CUSTOM_CATEGORY_ADVERTISEMENT = 101

local DEFAULT_UPDATE_INTERVAL = 86400
local MAX_LIST_ERRORS = 2
local MIN_DOWNLOAD_INTERVAL = 3600
local SIXH_DOWNLOAD_INTERVAL = 21600

-- IP addresses have very litte impact on memory/load time.
-- 150k IP addresses rules can be loaded in 2 seconds
local MAX_TOTAL_IP_RULES = 1000000
-- Domain rules are the most expensive.
-- On average they take ~7.5 KB/domain. 40k rules are loaded in about 7 seconds.
local MAX_TOTAL_DOMAIN_RULES = 200000

local is_nedge = ntop.isnEdge()

-- supported formats: ip, ip_csv, domain, hosts
--
-- Examples:
--    [ip] 1.2.3.4
--    [ip] 1.2.3.0/24
--    [ip_csv] 0,216.245.221.83,0.0962959583990113 (Number,IP address,Rating)
--    [domain] amalwaredomain.com
--    [hosts] 127.0.0.1   amalwaredomain.com
--    [hosts] 127.0.0.1   1.2.3.4
--

-- ##############################################

local function parse_lists_from_dir(where)
    local file_utils = require "file_utils"
    local files = ntop.readdir(where)
    local ret = {}

    for _, f in pairs(files) do
        if (string.ends(f, ".list")) then
            local path = where .. "/" .. f
            local content = file_utils.read_file(path)
            local j = json.decode(content)

            if (j == nil) then
                traceError(TRACE_WARNING, TRACE_CONSOLE, "Skipping invalid list " .. path .. ": parse error")
            else
                -- Fix glitches
                local skip = false

                if (j.category == nil) then
                    traceError(TRACE_WARNING, TRACE_CONSOLE, "Skipping invalid list " .. path .. ": no category")
                    skip = true

                else
                    local category = string.lower(tostring(j.category))
                    if (category == "mining") then
                        j.category = CUSTOM_CATEGORY_MINING
                    elseif (category == "malware") then
                        j.category = CUSTOM_CATEGORY_MALWARE
                    elseif (category == "advertisement") then
                        j.category = CUSTOM_CATEGORY_ADVERTISEMENT
                    else
                        traceError(TRACE_WARNING, TRACE_CONSOLE,
                            "Skipping invalid list " .. path .. ": invalid category " .. j.category)
                        skip = true
                    end
                end

                if (not (skip) and (j.name == nil)) then
                    traceError(TRACE_WARNING, TRACE_CONSOLE, "Skipping invalid list " .. path .. ": missing name")
                    skip = true
                end

                if (not (skip)) then
                    ret[j.name] = j
                end
            end
        end
    end

    return (ret)
end

-- ##############################################

local cached_lists = nil

local function get_lists()
    if (cached_lists == nil) then
        local lists_dir = dirs.installdir .. "/" .. "httpdocs/misc/lists"

        local builtin = parse_lists_from_dir(lists_dir .. "/builtin")
        local custom = parse_lists_from_dir(lists_dir .. "/custom")

        cached_lists = table.merge(builtin, custom)
    end

    return cached_lists
end

-- ##############################################

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

    lists = table.merge(get_lists(), lists)

    if ((lists == nil) or (status == nil)) then
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
local function saveListsStatusToRedis(lists, caller)
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
    local all_lists = get_lists()

    for list_name, list in pairs(lists or {}) do
        local default_prefs = all_lists[list_name]
        local meta = {}
        local has_custom_pref = false

        -- Only save the preferences that differ from the default configuration
        for key, val in pairs(list) do
            if ((key ~= "status") and (default_prefs[key] ~= val)) then
                meta[key] = val
                has_custom_pref = true
            end
        end

        if (has_custom_pref) then
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
    local all_lists = get_lists()
    local blacklists_stats = ntop.getBlacklistStats()

    local default_status = {
        last_update = 0,
        num_hosts = 0,
        last_error = false,
        num_errors = 0
    }

    for key, default_values in pairs(all_lists) do
        local list = table.merge(default_values, redis_lists[key] or {
            status = {}
        })
        list.status = table.merge(default_status, list.status)

        list.status.num_hits = blacklists_stats[key] or {
            current = 0,
            total = 0
        }
        lists[key] = list
        list.name = key
    end

    return lists
end

-- ##############################################

function lists_utils.editList(list_name, metadata_override)
    local lists = lists_utils.getCategoryLists()
    local list = lists[list_name]

    if (not list) then
        return false
    end

    local was_triggered = (list.enabled ~= metadata_override.enabled)

    list = table.merge(list, metadata_override)
    lists[list_name] = list

    saveListsMetadataToRedis(lists)

    -- Trigger a reload, for example for disabled lists
    lists_utils.downloadLists()

    if (was_triggered) then
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

-- ##############################################

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

    if (list.status.last_error and (list.status.num_errors < MAX_LIST_ERRORS)) then
        -- When the download fails, retry next hour
        interval = MIN_DOWNLOAD_INTERVAL
    else
        interval = list.update_interval
    end

    local next_update

    -- align if possible
    if interval == 0 then
        next_update = -1
    elseif interval == 3600 then
        next_update = ntop.roundTime(list.status.last_update, 3600, false)
    elseif interval == 86400 then
        next_update = ntop.roundTime(list.status.last_update, 86400, true --[[ UTC align ]] )
    else
        if (interval < MIN_DOWNLOAD_INTERVAL) then
            interval = MIN_DOWNLOAD_INTERVAL
        end
        next_update = list.status.last_update + interval
    end

    return next_update
end

-- ##############################################

-- Returns true if the given list should be updated
function shouldUpdate(list_name, list, now)
    local list_file
    local next_update

    if (list.enabled == false) then
        return (false)
    end

    traceError(trace_level, TRACE_CONSOLE, string.format("Checking if list '%s' will be updated... ", list_name))

    list_file = getListCacheFile(list_name, false)

    if (not (ntop.exists(list_file))) then
        -- The file does not exist: it needs to be downladed for sure
        return true
    end

    next_update = getNextListUpdate(list, now)

    if next_update == -1 then
        return ((not ntop.exists(list_file) and (list.status.num_errors < MAX_LIST_ERRORS)) or
                   (ntop.getCache("ntopng.cache.category_lists.update." .. list_name) == "1"))
    end

    if (false) then
        tprint('---------------')
        tprint(list_file)
        tprint('-')
        tprint(ntop.getCache("ntopng.cache.category_lists.update." .. list_name))
        tprint('-')
        tprint(list)
        tprint('---------------')

        tprint(((now >= next_update) or (not ntop.exists(list_file) and (list.status.num_errors < MAX_LIST_ERRORS)) or
                   (ntop.getCache("ntopng.cache.category_lists.update." .. list_name) == "1")))
        return (false)
    else
        -- note: num_errors is used to avoid retying downloading the same list again when
        -- the file does not exist
        return (((now >= next_update) or (not ntop.exists(list_file) and (list.status.num_errors < MAX_LIST_ERRORS)) or
                   (ntop.getCache("ntopng.cache.category_lists.update." .. list_name) == "1")))
    end
end

-- ##############################################

-- Check if the lists require an update
-- Returns a table:
--  in_progress: true if the update is still in progress and checkListsUpdate should be called again
--  needs_reload: if in_progress is false, then needs_reload indicates if some lists were updated and a reload is needed
local function checkListsUpdate(timeout)
    local alerts_api = require "alerts_api"
    local alert_consts = require "alert_consts"

    local lists = lists_utils.getCategoryLists()
    local begin_time = os.time()
    local now = begin_time
    local needs_reload = (ntop.getCache("ntopng.cache.category_lists.needs_reload") == "1")
    local all_processed = true

    initListCacheDir()

    traceError(trace_level, TRACE_INFO, "checkListsUpdate()")

    for list_name, list in pairsByKeys(lists) do
        local list_file = getListCacheFile(list_name, false)

        if (shouldUpdate(list_name, list, now)) then
            local temp_fname = getListCacheFile(list_name, true)
            local msg = string.format("Updating list '%s' [%s]... ", list_name, list.url)

            traceError(trace_level, TRACE_INFO, string.format("Updating list '%s'... ", list_name))

            local started_at = os.time()
            local res = ntop.httpFetch(list.url, temp_fname, timeout)

            if (res and (res["RESPONSE_CODE"] == 200)) then
                -- download was successful, replace the original file
                os.rename(temp_fname, list_file)
                list.status.last_error = false
                list.status.num_errors = 0
                needs_reload = true

                local alert = alert_consts.alert_types.alert_list_download_succeeded.new(list_name)
                alert:set_score_notice()
                alert:store(alerts_api.systemEntity(list_name))

                msg = msg .. "OK"
            else
                -- failure
                local respcode = 0
                local last_error = i18n("delete_data.msg_err_unknown")

                if res and res["ERROR"] then
                    last_error = res["ERROR"]
                elseif res and res["RESPONSE_CODE"] ~= nil then
                    respcode = ternary(res["RESPONSE_CODE"], res["RESPONSE_CODE"], "-")

                    if res["IS_PARTIAL"] then
                        last_error = i18n("category_lists.connection_time_out", {
                            duration = (os.time() - started_at)
                        })
                    else
                        last_error = i18n("category_lists.server_returned_error")
                    end

                    if (respcode > 0) then
                        last_error = string.format("%s %s", last_error, i18n("category_lists.http_code", {
                            err_code = respcode
                        }))
                    end
                end

                list.status.last_error = last_error
                list.status.num_errors = list.status.num_errors + 1

                local alert = alert_consts.alert_types.alert_list_download_failed.new(list_name, last_error)

                alert:set_score_error()

                alert:store(alerts_api.systemEntity(list_name))

                msg = msg .. "ERROR [" .. last_error .. "]"
            end

            traceError(TRACE_NORMAL, TRACE_CONSOLE, msg)

            now = os.time()
            -- set last_update even on failure to avoid blocking on the same list again
            list.status.last_update = now
            ntop.delCache("ntopng.cache.category_lists.update." .. list_name)

            if now - begin_time >= timeout then
                -- took too long, will resume on next housekeeping execution
                all_processed = false
                break
            end
        end
    end

    -- update lists state
    saveListsStatusToRedis(lists, "checkListsUpdate")

    if (not all_processed) then
        -- Still in progress, do not mark as finished yet
        if (needs_reload) then
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
            needs_reload = needs_reload
        }
    end
end

-- ##############################################

local cur_load_warnings = 0
local max_load_warnings = 50

local function loadWarning(msg)
    if (cur_load_warnings >= max_load_warnings) then
        return
    end

    -- traceError(TRACE_NORMAL, TRACE_CONSOLE, msg)

    cur_load_warnings = cur_load_warnings + 1
end

-- ##############################################

local function parse_hosts_line(line)
    local words = string.split(line, "%s+")
    local host = nil

    if (words and (#words == 2)) then
        host = words[2]

        if ((host == "localhost") or (host == "127.0.0.1") or (host == "::1")) then
            host = nil
        end
    else
        -- invalid host
        host = nil
    end

    return (host)
end

-- ##############################################

local function parse_ip_csv_line(line)
    local words = string.split(line, ",")
    local host = nil

    if (words and (#words == 2)) then
        host = words[1]

        if ((host == "localhost") or (host == "127.0.0.1") or (host == "::1")) then
            host = nil
        end
    else
        -- invalid host
        host = nil
    end

    return (host)
end

-- ##############################################

local function parse_ip_occurencies_line(line)
    local words = {}
    -- split line by space
    for word in line:gmatch("%S+") do
        table.insert(words, word)
    end

    local host = nil
    local ip_occurencies = nil

    if (table.len(words) == 2) then
        ip_occurencies = tonumber(words[2])
        host = words[1]

        -- IP occurrences must be greater than 2 or equal to 2
        -- and the host must not be 127.0.0.1
        if (host == "127.0.0.1" or ip_occurencies < 2) then
            host = nil
        end
    end

    return (host)
end

-- ##############################################

-- Loads hosts from a list file on disk
local function loadFromListFile(list_name, list, user_custom_categories, stats)
    local list_fname = getListCacheFile(list_name)
    local num_rules = 0
    local limit_exceeded = false
    local ignore_private_ips = true -- Ignore IPs that belong to local networks (eg. 10.0.0.0/8)
    
    traceError(trace_level, TRACE_CONSOLE, string.format("Loading '%s' [%s]...", list_name, list.format))

    if list.format == "hosts" then
        -- MAX_TOTAL_DOMAIN_RULES
        num_rules = ntop.loadCustomCategoryFile(list_fname, 0, list.category, list.name, ignore_private_ips) or 0
        stats.num_hosts = stats.num_hosts + num_rules
    elseif list.format == "ip_csv" then
        -- MAX_TOTAL_IP_RULES
        num_rules = ntop.loadCustomCategoryFile(list_fname, 1, list.category, list.name, ignore_private_ips) or 0
        stats.num_ips = stats.num_ips + num_rules
    elseif list.format == "ip_occurencies" then
        -- MAX_TOTAL_IP_RULES
        num_rules = ntop.loadCustomCategoryFile(list_fname, 2, list.category, list.name, ignore_private_ips) or 0
        stats.num_ips = stats.num_ips + num_rules
    elseif list.format == "ip" then
        -- MAX_TOTAL_IP_RULES
        num_rules = ntop.loadCustomCategoryFile(list_fname, 3, list.category, list.name, ignore_private_ips) or 0
        stats.num_ips = stats.num_ips + num_rules
    else
        traceError(TRACE_WARNING, TRACE_CONSOLE, "Unknown list format " .. list.format)
    end

    list.status.num_hosts = num_rules
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Loaded " .. list.name .. ": " .. num_rules .. " rules\n")
    traceError(trace_level, TRACE_CONSOLE, string.format("\tRead '%d' rules", num_rules))

    if ((num_rules == 0) and (not limit_exceeded) and (not ntop.isShuttingDown())) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
            "List '%s' has 0 rules. Please report this to https://github.com/ntop/ntopng", list_name))
    end

    return (limit_exceeded)
end

-- ##############################################

function loadnDPIExceptions()
    local EXCEPTIONS_KEY = "ntopng.prefs.alert_exclusions"
    local ndpi_exceptions_json = ntop.getPref(EXCEPTIONS_KEY)

    if isEmptyString(ndpi_exceptions_json) then
        return
    else
        ndpi_exceptions = json.decode(ndpi_exceptions_json)
    end

    for key, value in pairs(ndpi_exceptions) do
        if value.type == "domain" then
            ntop.setDomainMask(key)
        elseif value.type == "host" then
            -- Skip
        elseif value.type == "certificate" then
            ntop.setDomainMask(key)
        end
    end
end

-- TODO: create an host alert if a local host is inside a blacklist

-- ##############################################

-- NOTE: this must be executed in the same thread as checkListsUpdate
local function reloadListsNow()
    local categories_utils = require("categories_utils")
    if (ntop.limitResourcesUsage()) then
        return
    end

    local user_custom_categories = categories_utils.getAllCustomCategoryHosts()
    local lists = lists_utils.getCategoryLists()
    local stats = {
        num_hosts = 0,
        num_ips = 0,
        begin = os.time(),
        duration = 0
    }
    local limit_reached_error = nil

    if (not ntop.initnDPIReload()) then
        -- Too early, need to retry later
        traceError(trace_level, TRACE_CONSOLE, string.format("custom categories: too early reload"))
        return (false)
    end

    traceError(trace_level, TRACE_CONSOLE, string.format("Loading nDPI Exceptions"))
    loadnDPIExceptions()

    traceError(trace_level, TRACE_CONSOLE, string.format("Custom categories: reloading now"))

    -- Load hosts from cached URL lists
    for list_name, list in pairsByKeys(lists) do
        if list.enabled then
            if ((not limit_reached_error) and loadFromListFile(list_name, list, user_custom_categories, stats)) then
                -- A limit was exceeded
                if (stats.num_ips >= MAX_TOTAL_IP_RULES) then
                    limit_reached_error = i18n("category_lists.too_many_ips_loaded", {
                        limit = MAX_TOTAL_IP_RULES
                    }) .. ". " .. i18n("category_lists.disable_some_list")
                elseif (stats.num_hosts >= MAX_TOTAL_DOMAIN_RULES) then
                    limit_reached_error = i18n("category_lists.too_many_hosts_loaded", {
                        limit = MAX_TOTAL_DOMAIN_RULES
                    }) .. ". " .. i18n("category_lists.disable_some_list")
                else
                    -- should never happen
                    limit_reached_error = "reloadListsNow: unknown error"
                end

                -- Continue to iterate to also set the error on the next lists
                traceError(TRACE_WARNING, TRACE_CONSOLE, limit_reached_error)
            end

            if (limit_reached_error) then
                -- Set the invalid status to show it into the gui
                list.status.last_error = limit_reached_error

                traceError(trace_level, TRACE_CONSOLE, limit_reached_error)
            end
        end
    end

    -- update lists state
    saveListsStatusToRedis(lists, "reloadListsNow")

    -- Reload into memory
    ntop.finalizenDPIReload()

    -- Calculate stats
    stats.duration = (os.time() - stats.begin)

    traceError(TRACE_NORMAL, TRACE_CONSOLE,
        string.format("Loaded Category Lists (%u hosts, %u IPs) loaded in %d sec", stats.num_hosts,
            stats.num_ips, stats.duration))

    -- Save the stats
    ntop.setCache("ntopng.cache.category_lists.load_stats", json.encode(stats))

    return (true)
end

-- ##############################################

function lists_utils.reloadListsNow()
    reloadListsNow()
end

-- ##############################################

function lists_utils.reset_blacklist_url(list_name, enabled)
    local saved_lists = lists_utils.getCategoryLists()
    local lists = get_lists() -- original lists
    local list = lists[list_name]
    local default_url = list.url
    local lists_metadata = ntop.getPref(METADATA_KEY)
    local current_lists = {}
    if not isEmptyString(lists_metadata) then
        current_lists = json.decode(lists_metadata)
    end
    current_lists[list_name].url = default_url
    ntop.setPref(METADATA_KEY, json.encode(current_lists))
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
    traceError(trace_level, TRACE_CONSOLE, "Checking list reload")

    if ntop.isOffline() then
        return
    end

    local forced_reload = (ntop.getCache("ntopng.cache.reload_lists_utils") == "1")
    local reload_now = false

    if (ntop.getCache("ntopng.cache.download_lists_utils") == "1") then
        local rv = checkListsUpdate(60 --[[ timeout ]] )

        if (not rv.in_progress) then
            ntop.delCache("ntopng.cache.download_lists_utils")
            reload_now = forced_reload or rv.needs_reload
        end
    else
        reload_now = forced_reload
    end

    if reload_now then
        traceError(trace_level, TRACE_INFO, "[DEBUG] Reloading lists")

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

function lists_utils.startup()
    local protos_utils = require "protos_utils"
    local all_lists = get_lists()

    -- tprint(all_lists)
    if (ntop.limitResourcesUsage()) then
        return
    end

    if ntop.isOffline() then
        traceError(TRACE_NORMAL, TRACE_CONSOLE, "Category lists not loaded (offline)")
        -- Reload the last list version as we're offline
        reloadListsNow()
        return
    end

    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Refreshing category lists...")
    protos_utils.clearOldApplications()
    lists_utils.downloadLists()
    lists_utils.reloadLists()
    -- Need to do the actual reload also here as otherwise some
    -- flows may be misdetected until housekeeping.lua is executed
    lists_utils.checkReloadLists()
end

-- ##############################################

return lists_utils
