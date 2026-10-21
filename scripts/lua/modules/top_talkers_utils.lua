--
-- (C) 2014-26 - ntop.org
--

local top_talkers_utils = {}
top_talkers_utils.MAX_NUM_ENTRIES = 10
top_talkers_utils.THRESHOLD_LOW = .05
top_talkers_utils.TOP_ENABLED_KEY = "ntopng.prefs.ifid_%i.interface_top_talkers_creation"

local OTHER_KEY = "Other"
local HIDDEN_KEY = "Hidden Hosts"

-- ########################################################

local function getTopEnabledKey(ifid)
    return string.format(top_talkers_utils.TOP_ENABLED_KEY, ifid)
end

-- ########################################################

-- Per-direction bounded top: the array part holds at most MAX_NUM_ENTRIES
-- entries sorted by value (descending), 'sum' is the total of all the deltas.
-- Memory is O(MAX_NUM_ENTRIES) per VLAN instead of O(num hosts) and no full sort
-- is needed: most hosts are rejected with a single comparison.
local function newDirectionTop()
    return {
        n = 0,
        sum = 0
    }
end

-- ########################################################

local function topInsert(top, value, hostkey, hoststats)
    local max_entries = top_talkers_utils.MAX_NUM_ENTRIES
    local n = top.n

    if n < max_entries then
        n = n + 1
        top.n = n
    elseif value <= top[n].value then
        return -- Smaller than the current smallest top entry
    end

    -- Insertion sort step: shift smaller entries down (the last one is dropped when full)
    -- Basically what happens is the following, being the table ordered by the greater to the lowest
    -- e.g. : 7 - 5 - 3 - 1
    -- this algorithm starts from the end (latest position) and shift on the "right" the values
    -- until it finds a greater value where it stops shifting
    local i = n
    while (i > 1) and (top[i - 1].value < value) do
        top[i] = top[i - 1]
        i = i - 1
    end

    top[i] = {
        value = value,
        hostkey = hostkey,
        host = hoststats
    }
end

-- ########################################################

local function makeHostRecord(entry)
    local hoststats = entry.host

    if hoststats == nil then
        -- Pseudo entry (e.g. hidden hosts)
        return {
            address = entry.hostkey,
            value = entry.value,
            ["local"] = "false"
        }
    end

    local hostkey = entry.hostkey
    local tskey = hoststats.tskey or hostkey
    local name = hoststats.name
    local rec = {
        address = tskey,
        value = entry.value,
        ["local"] = hoststats.localhost and "true" or "false"
    }

    if (name ~= nil) and (name ~= tskey) then
        rec.label = name
    end

    if hostkey ~= tskey then
        -- storing the IP address is necessary for MAC based keys to create the
        -- correct URL
        rec.ipaddr = hostkey
    end

    return rec
end

-- ########################################################

-- Converts a direction top into the list of records saved on the DB:
-- the first MAX_NUM_ENTRIES / 2 entries are always kept, the following ones
-- only if they are at least THRESHOLD_LOW of the total; the rest goes into "Other"
local function finalizeDirection(top, hidden_sum)
    if hidden_sum > 0 then
        topInsert(top, hidden_sum, HIDDEN_KEY, nil)
    end

    local total = top.sum
    local min_kept = top_talkers_utils.MAX_NUM_ENTRIES / 2
    local min_value = total * top_talkers_utils.THRESHOLD_LOW
    local list = {}
    local kept_sum = 0

    for i = 1, top.n do
        local entry = top[i]

        -- Entries are sorted, once one is discarded all the following ones are too
        if (i > min_kept) and (entry.value < min_value) then
            break
        end

        list[i] = makeHostRecord(entry)
        kept_sum = kept_sum + entry.value
    end

    local other = total - kept_sum
    if other > 0 then
        list[#list + 1] = {
            address = OTHER_KEY,
            value = other,
            ["local"] = "false"
        }
    end

    return list
end

-- ########################################################

function top_talkers_utils.areTopEnabled(ifid)
    local k = getTopEnabledKey(ifid)

    return not (ntop.getPref(k) == "false")
end

-- ########################################################

function top_talkers_utils.disableTop(ifid)
    local k = getTopEnabledKey(ifid)
    ntop.setPref(k, "false")
end

-- ########################################################

function top_talkers_utils.enableTop(ifid)
    local k = getTopEnabledKey(ifid)
    ntop.delCache(k)
end

-- ########################################################

-- Computes the top talkers of the last minute (since the previous checkpoint)
-- in a single pass over the hosts, keeping only the top MAX_NUM_ENTRIES per
-- VLAN and direction. Returns the JSON to be saved on the DB.
function top_talkers_utils.makeTopJson(_ifname, ifid)
    require "ntop_utils"

    if not top_talkers_utils.areTopEnabled(ifid) then
        return nil
    end

    -- Include here otherwise it's a useless waste of memory
    local json = require "dkjson"

    local getBatchedHostsInfo = interface.getBatchedHostsInfo
    local isDeadlineApproaching = ntop.isDeadlineApproaching
    local isShuttingDown = ntop.isShuttingDown
    local vlans = {}
    local next_slot = 0
    local num_hosts = 0
    local in_time = true

    interface.select(_ifname)

    -- Iterate the hosts batches directly (no per-host closure/iterator), the
    -- deadline is checked once per batch.
    -- NOTE: hosts are checkpointed (delta reset) by the C core when fetched
    repeat
        if isShuttingDown() then
            break
        end

        if isDeadlineApproaching() then
            in_time = false
            break
        end

        local batch = getBatchedHostsInfo(next_slot, false --[[ no details ]])

        if batch == nil then
            break
        end

        for hostkey, hoststats in pairs(batch.hosts or {}) do
            local delta = hoststats.delta

            if delta ~= nil then
                local vlan_id = hoststats.vlan or 0
                local v = vlans[vlan_id]
                local sent = delta.sent or 0
                local rcvd = delta.rcvd or 0

                if v == nil then
                    v = {
                        sent = newDirectionTop(),
                        rcvd = newDirectionTop(),
                        hidden_sent = 0,
                        hidden_rcvd = 0
                    }
                    vlans[vlan_id] = v
                end

                if sent > 0 then
                    local top = v.sent
                    top.sum = top.sum + sent

                    if hoststats.hiddenFromTop then
                        v.hidden_sent = v.hidden_sent + sent
                    else
                        topInsert(top, sent, hostkey, hoststats)
                    end
                end

                if rcvd > 0 then
                    local top = v.rcvd
                    top.sum = top.sum + rcvd

                    if hoststats.hiddenFromTop then
                        v.hidden_rcvd = v.hidden_rcvd + rcvd
                    else
                        topInsert(top, rcvd, hostkey, hoststats)
                    end
                end
            end

            num_hosts = num_hosts + 1
        end

        next_slot = batch.nextSlot
    until (next_slot == nil) or (next_slot == 0)

    if not in_time then
        require "lua_trace"

        local deadline = ntop.getDeadline()
        local remaining = deadline - os.time()

        if num_hosts == 0 then
            -- Nothing processed: the script started (almost) at its deadline,
            -- i.e. it was waiting in the periodic activities queue
            traceError(TRACE_ERROR, TRACE_CONSOLE,
                string.format("[%s] Top talkers not computed: the periodic script started too late " ..
                                  "(%d sec before its deadline). Are the periodic activities overloaded?",
                    _ifname, remaining))
        else
            traceError(TRACE_ERROR, TRACE_CONSOLE,
                string.format("[%s] Cannot complete top talkers generation in 1 minute " ..
                                  "(processed %d hosts, %d sec before the deadline). Is there a huge number of hosts in the system?",
                    _ifname, num_hosts, remaining))
        end
    end

    local res = {}

    for vlan_id, v in pairs(vlans) do
        local total = v.sent.sum + v.rcvd.sum

        -- Skip VLANs without traffic in the last minute
        if total > 0 then
            res[#res + 1] = {
                hosts = {{
                    senders = finalizeDirection(v.sent, v.hidden_sent),
                    receivers = finalizeDirection(v.rcvd, v.hidden_rcvd)
                }},
                value = total,
                address = tostring(vlan_id)
            }
        end
    end

    return json.encode({
        vlan = res
    })
end

-- ########################################################

-- Computes label and url during visualization
function top_talkers_utils.enrichRecordInformation(class_key, rec, show_vlan)
    require "ntop_utils"
    require "label_utils"

    local url = ""
    local label = rec.label or rec.address
    local url_target = rec.address

    if (rec.address ~= "Other") and (rec.address ~= "Hidden Hosts") then
        if class_key == "hosts" then
            local address = rec.address

            if ends(address, "_v4") or ends(address, "_v6") then
                rec.visual_addr = visualTsKey(address)
                address = string.sub(address, 1, string.len(address) - 3)

                if (rec.ipaddr ~= nil) then
                    url_target = rec.ipaddr
                end
            end

            url_target = url_target .. "&tskey=" .. rec.address

            url = ntop.getHttpPrefix() .. '/lua/host_details.lua?always_show_hist=true&host='

            -- Use the host alias as label, if set
            local alt_name = ip2label(address, 0, 100)

            if not isEmptyString(alt_name) and (alt_name ~= address) then
                label = alt_name
            else
                local hinfo = hostkey2hostinfo(address)
                if not show_vlan then
                    hinfo.vlan = 0
                end
                alt_name = hostinfo2label(hinfo)

                if not isEmptyString(alt_name) and (alt_name ~= address) then
                    label = alt_name
                else
                    label = address
                end
            end
        elseif class_key == "asn" then
            url = ntop.getHttpPrefix() .. '/lua/hosts_stats.lua?asn='
        elseif class_key == "networks" then
            url = ntop.getHttpPrefix() .. '/lua/hosts_stats.lua?network='

            local network_name = nil
            if rec.address == "-1" then
                network_name = i18n("remote_networks")
            else
                network_name = getFullLocalNetworkName(ntop.getNetworkNameById(tonumber(rec.address)))
            end
            if not isEmptyString(network_name) then
                label = network_name
            end
        elseif class_key:contains("os") then
            url = ntop.getHttpPrefix() .. '/lua/hosts_stats.lua?os='
        end

        if not isEmptyString(url) then
            url = url .. url_target
        end
    end

    -- Update record information
    rec.url = url
    rec.label = label
end

-- ########################################################

function top_talkers_utils.enrichVlanInformation(vlan_tbl)
    local vlan_id = ternary(vlan_tbl.address, tostring(vlan_tbl.address), "0")
    vlan_tbl["label"] = vlan_id
    vlan_tbl["name"] = vlan_id
    vlan_tbl["url"] = ntop.getHttpPrefix() .. '/lua/hosts_stats.lua?vlan=' .. vlan_id
end

-- ########################################################

return top_talkers_utils
