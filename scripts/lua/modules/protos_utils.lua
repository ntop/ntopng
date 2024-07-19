--
-- (C) 2021 - ntop.org
--
local os_utils = require("os_utils")
local protos_utils = {}

local proto_key = "ntopng.preferences.protos_list_id"
local proto_last_id = "ntopng.preferences.protos_last_id"
local first_proto_id = 1024

-- ##############################################

local function getProtosFile()
    return os_utils.fixPath(ntop.getPrefs().ndpi_proto_file)
end

-- ##############################################

-- Function used to reload the custom applications (the protocol file, -p option)
local function reloadApplications()
   local lists_utils = require "lists_utils"

   lists_utils.reloadLists()
end

-- ##############################################

local function parsePortBasedRule(filter, value, line)
    local parts

    if ((filter == "tcp") or (filter == "udp")) then
        -- single port or port range
        local lower, upper
        parts = string.split(value, "-")

        if ((parts ~= nil) and (#parts == 2)) then
            -- port range
            lower = tonumber(parts[1])
            upper = tonumber(parts[2])
        else
            lower = tonumber(value)
            upper = lower
        end

        if ((lower ~= nil) and (upper ~= nil)) then
            return true, {
                match = "port",
                proto = filter,
                port_lower = lower,
                port_upper = upper,
                value = string.format("%s:%s", filter, value)
            }
        else
            traceError(TRACE_WARNING, TRACE_CONSOLE,
                string.format("[protos.txt] Ignoring bad %s port range '%s' in rule: %s", filter, value, line))
            return true, nil
        end
    end

    return false, nil
end

-- ##############################################

-- Parses a nDPI protos.txt file and returns an a key-based table
-- with the mappings app->rules mappings. Also an index based tabled of the
-- defined protocols is returned to ensure that the protocols are always appended to the
-- end of the file as nDPI assigns the custom protocol IDs sequentially.
function protos_utils.parseProtosTxt()
    local path = getProtosFile()

    if not ntop.exists(path) then
        return {}, {}
    end

    local f = io.open(path, "r")
    local defined_protos = {}
    local rules = {}
    local app_id_mapping = {}

    local function addRule(proto, rule)
        if (rules[proto] == nil) then
            rules[proto] = {}
            defined_protos[#defined_protos + 1] = proto
        end

        rules[proto][#rules[proto] + 1] = rule
    end

    if f == nil then
        traceError(TRACE_ERROR, TRACE_CONSOLE,
            string.format("[protos.txt] Could not open '%s' (invalid permissions?)", path))
        return {}, {}
    end

    for full_line in f:lines() do
        local line = trimString(full_line)
        local parts = string.split(line, "@")

        if ((line == "") or starts(line, "#")) then
            -- comment or empty line
        elseif ((parts ~= nil) and (#parts == 2)) then
            local proto = parts[2]
            local rules = parts[1]
            local tmp = string.split(proto, "=")
            rules = string.split(rules, ",") or {rules}

            if (tmp ~= nil) and (#tmp == 2) then
                proto = tmp[1]
                app_id_mapping[tmp[2]] = proto
            end

            for _, rule in ipairs(rules) do
                parts = string.split(rule, ":")

                if ((parts ~= nil) and (#parts >= 2)) then
                    local filter = parts[1]
                    local value = rule:gsub(filter .. ":", "")

                    local is_port_based, port_based_rule = parsePortBasedRule(filter, value, line)

                    if is_port_based then
                        addRule(proto, port_based_rule)
                    elseif (filter == "host") then
                        -- possibly remove quotas
                        value = value:gsub("^\"*(.-)\"*$", "%1")

                        if not isEmptyString(value) then
                            addRule(proto, {
                                match = "host",
                                value = value
                            })
                        else
                            traceError(TRACE_WARNING, TRACE_CONSOLE,
                                string.format("[protos.txt] Ignoring bad host '%s' in rule: %s", value, line))
                        end
                    elseif (filter == "ip") then
                        addRule(proto, {
                            match = "ip",
                            value = value
                        })
                    elseif (filter == "ipv6") then
                        addRule(proto, {
                            match = "ipv6",
                            value = value
                        })
                    else
                        traceError(TRACE_WARNING, TRACE_CONSOLE,
                            string.format("[protos.txt] Ignoring unknown filter '%s' in rule: %s", filter, line))
                    end
                else
                    traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("[protos.txt] Ignoring bad rule: %s", line))
                end
            end
        else
            traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("[protos.txt] Ignoring bad rule: %s", line))
        end
    end

    f:close()

    return rules, defined_protos, app_id_mapping
end

-- ##############################################

function protos_utils.hasProtosFile()
    return (not isEmptyString(getProtosFile()))
end

-- ##############################################

function protos_utils.getProtosTxtRule(line)
    local http_lint = require "http_lint"

    line = trimString(line)

    if isIPv4(line) or http_lint.validateNetwork(line) then
        return {
            match = "ip",
            value = line
        }
    else
        local parts = string.split(line, ":")
        
        if ((parts ~= nil) and (#parts >= 2)) then
            local filter = parts[1]
            local value = parts[2]

            if filter == 'ip' then
                -- Add the port in case there is one, so accept both cases, ip and ip:port :
                -- e.g. ip:1.1.1.1 and ip:1.1.1.1:5466
                if parts[3] then
                    value = value .. ':' .. parts[3]
                end
                return {
                    match = "ip",
                    value = value
                }
            elseif filter == 'ipv6' then
                -- Add each value after 'ipv6:', so accept both cases, [ipv6] and [ipv6]:port :
                -- e.g. ipv6:[1:1:1:1:1:1:1:1] and ipv6:[1:1:1:1:1:1:1:1]:5466
                value = line:gsub(filter .. ":", "")
                return {
                    match = "ipv6",
                    value = value
                }
            elseif filter == 'host' then
                -- Domain name filter
                -- e.g. host:google
                return {
                    match = "host",
                    value = value
                }
            else
                -- Check if it's a port or port range filter
                -- e.g. udp:5555 and udp:5555-5557
                local is_port_based, port_based_rule = parsePortBasedRule(filter, value, line)

                if is_port_based then
                    return port_based_rule
                end
            end
        end
    end
end

-- ##############################################

function protos_utils.overwriteAppRules(app, rules)
    local json = require "dkjson"
    local current_rules, defined_protos = protos_utils.parseProtosTxt()
    local found = false
    local skip_rules = false

    if (current_rules == nil) or (type("app") ~= "string") then
        return false
    end

    -- In case the name has different major or lower cases
    -- Replace with the new name
    for app_name, old_rules in pairs(current_rules) do
        if app:lower() == app_name:lower() then
            current_rules[app] = rules
            found = true
            if json.encode(rules) == json.encode(old_rules) then
                skip_rules = true
            end
        end
    end

    if not found then
        defined_protos[#defined_protos + 1] = app
        current_rules[app] = rules
    end

    if not skip_rules then
        protos_utils.generateProtosTxt(current_rules, defined_protos)
    end
end

-- ##############################################

function protos_utils.addAppRule(app, rule)
    local current_rules, defined_protos = protos_utils.parseProtosTxt()
    local app_rules

    if (current_rules == nil) or (type("app") ~= "string") then
        return false
    end

    app_rules = current_rules[app] or {}

    -- Uniqueness Check
    for _, existing_rule in pairs(app_rules) do
        if ((existing_rule.match == rule.match) and (existing_rule.value == rule.value)) then
            return false
        end
    end

    if (not current_rules[app]) then
        -- This is a new app, append it to the end
        defined_protos[#defined_protos + 1] = app
    end

    app_rules[#app_rules + 1] = rule
    current_rules[app] = app_rules
    return protos_utils.generateProtosTxt(current_rules, defined_protos)
end

-- ##############################################

function protos_utils.deleteAppRules(app)
    local current_rules, defined_protos = protos_utils.parseProtosTxt()

    if (not current_rules[app]) then
        -- App does not exist
        return false
    end

    current_rules[app] = nil
    return protos_utils.generateProtosTxt(current_rules, defined_protos)
end

-- ##############################################

-- In order to have a clean startup, remove the old mappings 
-- between protocols no more defined and categories
function protos_utils.clearOldApplications()
    local current_rules, defined_protos, app_id_mapping = protos_utils.parseProtosTxt()
    local key = getCustomnDPIProtoCategoriesKey()
    local app_cat_mapping = ntop.getHashAllCache(key) or {}
    if app_id_mapping then
        for application_id, category_id in pairs(app_cat_mapping) do
            if not app_id_mapping[application_id] then
                traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Removing Application - Category old mapping: %s %s", application_id, category_id))
                ntop.delHashCache(key, application_id)
            end
        end
    else
        for application_id, category_id in pairs(app_cat_mapping) do
            ntop.delHashCache(key, application_id)
        end
    end
end

-- ##############################################

-- Generates a protos.txt file based on the supplied rules
-- The defined_protos is used to ensure that the protocols are written
-- in the specified order as nDPI assigns IDs sequentially and existing
-- IDs must not be changed.
function protos_utils.generateProtosTxt(rules, defined_protos)
    local path = getProtosFile()
    local backup_file = path .. ".bak"

    if (ntop.exists(path) and (not ntop.exists(backup_file))) then
        traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Backing up '%s' to '%s'", path, backup_file))
        os.rename(path, backup_file)
    end

    local f = io.open(path, "w")

    if f == nil then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("[protos.txt] Could not open '%s' for write", path))
        return false
    end

    local function writeRule(rule)
        f:write(string.format("%s\n", rule))
    end

    -- Important: iterate by index to ensure that new protocols are always appended
    for _, proto in ipairs(defined_protos) do
        local proto_rules = rules[proto]
        local proto_name = string.split(proto, "=") or {}

        if proto_name and #proto_name == 2 then
            proto_name = proto_name[1]
        else
            proto_name = proto
        end

        local proto_id = interface.getnDPIProtoId(proto_name)

        if isEmptyString(proto_id) then
            proto_id = ntop.getHashCache(proto_key, proto_name) or ''    
        end
        
        if isEmptyString(proto_id) or proto_id == 0 then
            proto_id = tonumber(ntop.getCache(proto_last_id)) or 0
            if proto_id == 0 then
                proto_id = first_proto_id
            end

            ntop.setCache(proto_last_id, proto_id + 1)
            ntop.setHashCache(proto_key, proto_name, proto_id)
        end

        if proto_rules then
            writeRule(string.format("# %s", proto_name))

            for _, rule in ipairs(proto_rules) do
                if rule.match == "port" then
                    writeRule(string.format("%s@%s=%s", rule.value, proto_name, proto_id))
                elseif rule.match == "host" then
                    writeRule(string.format("host:\"%s\"@%s=%s", rule.value, proto_name, proto_id))
                elseif rule.match == "ip" then
                    writeRule(string.format("ip:%s@%s=%s", rule.value, proto_name, proto_id))
                elseif rule.match == "ipv6" then
                    writeRule(string.format("ipv6:%s@%s=%s", rule.value, proto_name, proto_id))
                end
            end

            writeRule("")
        end
    end

    f:close()

    -- Reload the application file
    reloadApplications()

    return true
end

-- ##############################################

return (protos_utils)
