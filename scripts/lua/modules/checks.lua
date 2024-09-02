--
-- (C) 2019-24 - ntop.org
--
local dirs = ntop.getDirs()

-- Checks provide a scriptable way to interact with the ntopng
-- core. Users can provide their own modules to trigger custom alerts,
-- export data, or perform periodic tasks.

local clock_start = os.clock()

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_generic"
require "check_redis_prefs"
local os_utils = require("os_utils")
local json = require("dkjson")
local script_manager = require("script_manager")
local alert_management = require "alert_management"
local alert_entities_utils = require "alert_entities_utils"
local http_lint = require "http_lint"
local alert_entity_builders = require "alert_entity_builders"
local alert_category_utils = require "alert_category_utils"

-- ##############################################
-- structs
local alert_categories = require "alert_categories"
local alert_granularities = require "alert_granularities"
local alert_entities = require "alert_entities"
local field_units = require "field_units"

-- ##############################################

local checks = {}
-- Checks category consts
checks.check_categories = alert_categories

-- ##############################################

checks.field_units = field_units

-- ##############################################

-- Operator functions associated to checks `operator`, which is specified
-- both inside checks default configuration values, as well as when checks
-- are configured from the UI.
--
checks.operator_functions = {
    gt --[[ greater than --]] = function(value, threshold)
        return value > threshold
    end,
    lt --[[ less than    --]] = function(value, threshold)
        return value < threshold
    end
}

-- ##############################################

-- A default check definition for all checks associated to nDPI risks that don't have an explicitly defined .lua check_definition file
local FLOW_RISK_SIMPLE_CHECK_DEFINITION_PATH = os_utils.fixPath(string.format(
    "%s/scripts/lua/modules/flow_risk_simple_check_definition.lua", dirs.installdir))
local NUM_FILTERED_KEY = "ntopng.cache.checks.exclusion_counter.subdir_%s.script_key_%s"
local NON_TRAFFIC_ELEMENT_CONF_KEY = "all"
local NON_TRAFFIC_ELEMENT_ENTITY = "no_entity"
local ALL_HOOKS_CONFIG_KEY = "all"
local CONFIGSET_KEY = "ntopng.prefs.checks.configset_v1" -- Keep in sync with ntop_defines.h CHECKS_CONFIG

checks.DEFAULT_CONFIGSET_ID = 0
checks.HOST_SUBDIR_NAME = "host"
checks.FLOW_SUBDIR_NAME = "flow"
checks.INTERFACE_SUBDIR_NAME = "interface"
checks.NETWORK_SUBDIR_NAME = "network"
checks.SNMP_DEVICE_SUBDIR_NAME = "snmp_device"
checks.SYSTEM_SUBDIR_NAME = "system"
checks.SYSLOG_SUBDIR_NAME = "syslog"
checks.ACTIVE_MONITORING_SUBDIR_NAME = "active_monitoring"

-- NOTE: the subdir id must be unique
local available_subdirs = {{
    id = checks.HOST_SUBDIR_NAME,
    label = "hosts",
    filter = {
        -- Default fields populated automatically when creating filters
        default_fields = {"ip"},
        -- All possible filter fields
        available_fields = {
            ip = {
                lint = http_lint.validateIpAddress
            }
        }
    }
}, {
    id = checks.INTERFACE_SUBDIR_NAME,
    label = "interfaces",
    filter = {
        default_fields = {"alert_entity_val"},
        available_fields = {
            alert_entity_val = {
                lint = http_lint.validateInterface, -- An interface id
                match = function(context, val)
                    -- Do the comparison
                    if not context or context.alert_entity ~= alert_entities_utils.alertEntity("interface") then
                        return false
                    end

                    -- Match on the interface id
                    return tonumber(val) == tonumber(context.alert_entity_val)
                end,
                sqlite = function(val)
                    -- Keep in sync with SQLite database schema declared in AlertsManager.cpp
                    return string.format("(alert_entity = %u AND alert_entity_val = '%s')",
                        alert_entities_utils.alertEntity("interface"), val)
                end,
                find = function(alert, alert_json, filter, val)
                    return (alert[filter] and (alert[filter] == val))
                end
            }
        }
    }
}, {
    id = checks.NETWORK_SUBDIR_NAME,
    label = "networks",
    filter = {
        default_fields = {"alert_entity_val"},
        available_fields = {
            alert_entity_val = {
                lint = http_lint.validateNetworkWithVLAN, -- A local network
                match = function(context, val)
                    -- Do the comparison
                    if not context or context.alert_entity ~= alert_entities_utils.alertEntity("network") then
                        return false
                    end

                    -- Match on the interface id
                    return val == context.alert_entity_val
                end,
                sqlite = function(val)
                    -- Keep in sync with SQLite database schema declared in AlertsManager.cpp
                    return string.format("(alert_entity = %u AND alert_entity_val = '%s')",
                        alert_entities_utils.alertEntity("network"), val)
                end,
                find = function(alert, alert_json, filter, val)
                    return (alert[filter] and (alert[filter] == val))
                end
            }
        }
    }
}, {
    id = checks.SNMP_DEVICE_SUBDIR_NAME,
    label = "host_details.snmp",
    filter = {
        default_fields = {"alert_entity_val"},
        available_fields = {
            alert_entity_val = {
                lint = http_lint.validateHost, -- The IP address of an SNMP device
                match = function(context, val)
                    -- Do the comparison
                    if not context or context.alert_entity ~= alert_entities_utils.alertEntity("snmp_device") then
                        return false
                    end

                    -- Match the SNMP device
                    return val == context.alert_entity_val
                end,
                sqlite = function(val)
                    -- Keep in sync with SQLite database schema declared in AlertsManager.cpp
                    return string.format("(alert_entity = %u AND alert_entity_val = '%s')",
                        alert_entities_utils.alertEntity("snmp_device"), val)
                end,
                find = function(alert, alert_json, filter, val)
                    return (alert[filter] and (alert[filter] == val))
                end
            }
        }
    }
}, {
    id = checks.FLOW_SUBDIR_NAME,
    label = "flows",
    -- User script execution filters (field names are those that arrive from the C Flow.cpp)
    filter = {
        -- Default fields populated automatically when creating filters
        default_fields = {"ip"},
        -- All possible filter fields
        available_fields = {
            ip = {
                lint = http_lint.validateIpAddress
            }
        }
    }
}, {
    id = checks.SYSTEM_SUBDIR_NAME,
    label = "system"
}, {
    id = checks.ACTIVE_MONITORING_SUBDIR_NAME,
    label = "active_monitoring"
}, {
    id = checks.SYSLOG_SUBDIR_NAME,
    label = "Syslog"
}}

-- Hook points for flow/periodic modules
-- NOTE: keep in sync with the Documentation
checks.script_types = {
    flow = {
        parent_dir = "interface",
        hooks = {"protocolDetected", "statusChanged", "flowEnd", "periodicUpdate", "flowBegin"},
        subdirs = {"flow"},
        default_config_only = true -- Only the default configset can be used
    },
    traffic_element = {
        parent_dir = "interface",
        hooks = {"min", "5mins", "hour", "day"},
        subdirs = {"interface", "network"},
        has_per_hook_config = true -- Each hook has a separate configuration
    },
    host = {
        parent_dir = "interface",
        hooks = {"min", "5mins", "hour", "day"},
        subdirs = {"host"},
        has_per_hook_config = true -- Each hook has a separate configuration
    },
    snmp_device = {
        parent_dir = "system",
        hooks = {"snmpDevice", "snmpDeviceInterface"},
        subdirs = {"snmp_device"}
    },
    system = {
        parent_dir = "system",
        hooks = {"min", "5mins", "hour", "day"},
        subdirs = {"system"},
        has_per_hook_config = true, -- Each hook has a separate configuration
        default_config_only = true -- Only the default configset can be used
    },
    active_monitoring = {
        parent_dir = "system",
        hooks = {"min", "5mins", "hour", "day"},
        subdirs = {"active_monitoring"},
        has_per_hook_config = true, -- Each hook has a separate configuration
        default_config_only = true -- Only the default configset can be used
    },
    syslog = {
        parent_dir = "system",
        hooks = {"handleEvent"},
        subdirs = {"syslog"},
        default_config_only = true -- Only the default configset can be used
    }
}

-- ##############################################

local current_script = nil
local current_configset = nil

local function invokeScriptHook(check, configset, hook_fn, p1, p2, p3)
    current_script = check
    current_configset = configset
    return (hook_fn(p1, p2, p3))
end

-- ###########################################

-- @brief Deletes all the cache/prefs keys matching the pattern
local function deleteCachePattern(pattern)
    local keys = ntop.getKeysCache(pattern)

    for key in pairs(keys or {}) do
        ntop.delCache(key)
    end
end

-- ##############################################

-- @brief Given a subdir, returns the corresponding script type
function checks.getScriptType(search_subdir)
    for _, script_type in pairs(checks.script_types) do
        for _, subdir in pairs(script_type.subdirs) do
            if (subdir == search_subdir) then
                return (script_type)
            end
        end
    end

    -- Not found
    return (nil)
end

-- ##############################################

-- @brief Given a subdir, returns the corresponding numeric id
local function getSubdirId(subdir_name)
    for id, values in pairs(available_subdirs) do
        if values["id"] == subdir_name then
            return id
        end
    end

    return -1
end

-- ##############################################

function checks.getSubdirectoryPath(script_type, subdir)
    local res = {}
    local path

    -- Checks definition path
    path = string.format("%s/scripts/lua/modules/check_definitions/%s", dirs.installdir, subdir)

    res[#res + 1] = os_utils.fixPath(path)

    -- Add pro check_definitions if necessary
    if ntop.isPro() then
        local pro_path = string.format("%s/pro/scripts/lua/modules/check_definitions/%s", dirs.installdir, subdir)
        res[#res + 1] = os_utils.fixPath(pro_path)
    end

    return res
end

-- ##############################################

-- @brief Lists available checks.
-- @params script_type one of checks.script_types
-- @params subdir the modules subdir
-- @return a list of available module names
function checks.listScripts(script_type, subdir)
    local check_dirs = checks.getSubdirectoryPath(script_type, subdir)
    local rv = {}

    for _, checks_dir in pairs(check_dirs) do
        for fname in pairs(ntop.readdir(checks_dir)) do
            if string.ends(fname, ".lua") then
                local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
                rv[#rv + 1] = mod_fname
            end
        end
    end

    return rv
end

-- ##############################################

-- @brief Tries and load a script template, returning a new instance (if found)
--        All templates loaded here must inherit from `check_template.lua`
local function loadAndCheckScriptTemplate(check, check_template)
    local res

    if not check_template then
        -- Default name
        check_template = "check_template"
    end

    -- First, try and load the template straight from the script templates
    local template_require

    if check.script then
        template_require = script_manager.loadTemplate(check.script.key, check_template)
    end

    -- Then, if no template is found inside the script, try and load the template from the ntopng templates
    -- in modules that can be shared across multiple scripts
    if not template_require then
        -- Attempt at locating the template class under modules (global to ntopng)
        local template_path = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/check_templates/" ..
                                                   check_template .. ".lua")
        if ntop.exists(template_path) then
            -- Require the template file
            template_require = require("check_templates." .. check_template)
        end
    end

    if template_require then
        -- Create an instance of the template
        res = template_require.new(check)
    end

    return res
end

-- ##############################################

local function init_check(check, mod_fname, full_path, script, script_type, subdir)
    check.key = mod_fname
    check.path = full_path
    check.subdir = subdir
    check.default_enabled = ternary(check.default_enabled == false, false, true --[[ a nil value means enabled ]] )
    check.script = script
    check.script_type = script_type
    check.category = alert_category_utils.checkCategory(check.category)
    -- A user script is assumed to be able to generate alerts if it has a flag or an alert id specified
    check.num_filtered = tonumber(ntop.getCache(string.format(NUM_FILTERED_KEY, subdir, mod_fname))) or 0 -- math.random(1000,2000)

    if script then
        check.edition = check.edition or script.edition or ""
    end

    if subdir == "host" then
        check.hooks = {
            min = true
        }
    end

    if check.gui then
        check.template = loadAndCheckScriptTemplate(check, check.gui.input_builder)

        if (check.template == nil) then
            traceError(TRACE_WARNING, TRACE_CONSOLE,
                string.format("Unknown template '%s' for user script '%s'", check.gui.input_builder, mod_fname))
        end

        -- Possibly localize the input title/description
        if check.gui.input_title then
            check.gui.input_title = i18n(check.gui.input_title)
        end
        if check.gui.input_description then
            check.gui.input_description = i18n(check.gui.input_description)
        end
    end

    -- Expand hooks
    if (check.hooks and check.hooks["all"] ~= nil) then
        local callback = check.hooks["all"]
        check.hooks["all"] = nil

        for _, hook in pairs(script_type.hooks) do
            check.hooks[hook] = callback
        end
    end

    if not check.hooks then
        -- Flow checks no longer have hooks. They have callbacks in C++ that have replaced hooks
        check.hooks = {}
    end
end

-- ##############################################

local function loadAndCheckScript(mod_fname, full_path, script, script_type, subdir, return_all, scripts_filter,
    hook_filter)
    local setup_ok = true

    -- Recheck the edition as the demo mode may expire
    if script then
        if (script.setup and script.setup() == false) then
            return (nil)
        end
        if (script.edition == "pro" and not ntop.isPro()) or
            ((script.edition == "enterprise_l" or script.edition == "enterprise_m") and not ntop.isEnterpriseM()) or
            (script.edition == "enterprise_l" and not ntop.isEnterpriseL()) then
            traceError(TRACE_DEBUG, TRACE_CONSOLE,
                string.format("Skipping user script '%s' with '%s' edition", mod_fname, script.edition))
            return (nil)
        end
    end

    traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Loading user script '%s'", mod_fname))
    local check = dofile(full_path)

    if (type(check) ~= "table") then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Loading '%s' failed", full_path))
        return (nil)
    end

    if ((not return_all) and check.packet_interface_only and (not interface.isPacketInterface())) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for non packet interface", mod_fname))
        return (nil)
    end

    if ((check.nedge_exclude and ntop.isnEdge()) or (check.nedge_only and (not ntop.isnEdge()))) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for nEdge", mod_fname))
        return (nil)
    end

    if ((not return_all) and (check.windows_exclude and ntop.isWindows())) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' not supported on Windows", mod_fname))
        return (nil)
    end

    if (subdir ~= "flow" and subdir ~= "host" and subdir ~= "interface" and table.empty(check.hooks)) then
        traceError(TRACE_WARNING, TRACE_CONSOLE,
            string.format("No 'hooks' defined in user script '%s', skipping", mod_fname))
        return (nil)
    end

    if (check.l7_proto ~= nil) then
        check.l7_proto_id = interface.getnDPIProtoId(check.l7_proto)

        if (check.l7_proto_id == -1) then
            traceError(TRACE_WARNING, TRACE_CONSOLE, string.format(
                "Unknown L7 protocol filter '%s' in user script '%s', skipping", check.l7_proto, mod_fname))
            return (nil)
        end
    end

    if (full_path == FLOW_RISK_SIMPLE_CHECK_DEFINITION_PATH) then
        -- Loading a check associated to a flow risk without an explicitly defined .lua check_definition file
        local flow_risk_alerts = ntop.getFlowRiskAlerts()
        local flow_risk_alert = flow_risk_alerts[mod_fname]

        if not flow_risk_alert then
            traceError(TRACE_WARNING, TRACE_CONSOLE,
                string.format("Module '%s' is not associated to any known flow risk alert", mod_fname))
        else
            -- Add the necessary elements as found in C++
            check.alert_id = flow_risk_alert.alert_id
            check.category = alert_category_utils.checkCategory({
                id = flow_risk_alert.category
            })
            check.gui.i18n_title = flow_risk_alert.risk_name
            check.gui.i18n_description = flow_risk_alert.risk_name
        end
    end

    if ((not check.gui) or (not check.gui.i18n_title) or (not check.gui.i18n_description)) then
        traceError(TRACE_WARNING, TRACE_CONSOLE,
            string.format("Module '%s' does not define a gui [%s]", mod_fname, full_path))
    end

    -- Augument with additional attributes
    init_check(check, mod_fname, full_path, script, script_type, subdir)

    if (hook_filter ~= nil) then
        -- Only return modules which should be called for the specified hook
        if ((check.hooks[hook_filter] == nil) and (check.hooks["all"] == nil)) then
            traceError(TRACE_DEBUG, TRACE_CONSOLE,
                string.format("Skipping module '%s' for hook '%s'", check.key, hook_filter))
            return (nil)
        end
    end

    if (scripts_filter ~= nil) then
        local script_ok = scripts_filter(check)

        if (not script_ok) then
            traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module'%s' for scripts_filter", check.key))
            return (nil)
        end
    end

    -- If a setup function is available, call it
    if (check.setup ~= nil) then
        setup_ok = check.setup()
    end

    if ((not return_all) and (not setup_ok)) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE,
            string.format("Skipping module '%s' as setup() returned %s", check.key, setup_ok))
        return (nil)
    end

    return (check)
end

-- ##############################################

-- This function return the edition and key of the check
local function get_check_info(dir, fname)
    local edition = "community"

    if string.find(dir, "enterprise_l") then
        edition = "enterprise_l"
    elseif string.find(dir, "enterprise_m") then
        edition = "enterprise_m"
    elseif string.find(dir, "pro") then
        edition = "pro"
    end

    return {
        edition = edition,
        key = fname
    }
end

-- ##############################################

-- @brief Get a table with all loadable checks
-- @param script_type one of checks.script_types
-- @param subdir the modules subdir. *NOTE* this must be unique as it is used as a key.
-- @return A table with all loadable checks
local function get_loadable_checks(script_type, subdir)
    local loadable_checks = {}
    local check_dirs = checks.getSubdirectoryPath(script_type, subdir)

    for _, checks_dir in pairs(check_dirs) do
        for fname in pairs(ntop.readdir(checks_dir)) do
            if string.ends(fname, ".lua") then
                local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
                local full_path = os_utils.fixPath(checks_dir .. "/" .. fname)
                local check_info

                -- Getting check info, like edition and key
                if subdir == "host" then
                    check_info = ntop.getHostCheckInfo(mod_fname)
                elseif subdir == "flow" then
                    check_info = ntop.getFlowCheckInfo(mod_fname)
                else
                    check_info = get_check_info(checks_dir, fname)
                end

                -- Add the script to the loadable checks
                loadable_checks[mod_fname] = {
                    full_path = full_path,
                    script = check_info
                }
            end
        end
    end

    if subdir == "flow" then
        -- Flow checks associated to nDPI risks don't necessarily have a corresponding .lua file
        -- For those checks, a builtin default file is loaded instead
        local flow_risk_alerts = ntop.getFlowRiskAlerts()

        for mod_fname, flow_risk_alert in pairs(flow_risk_alerts) do
            if loadable_checks[mod_fname] then
                -- There's a .lua file explicity defining the check. Already using it.
            else
                -- No explicit .lua file defining the check. Loading a default.
                local full_path = FLOW_RISK_SIMPLE_CHECK_DEFINITION_PATH
                local script = ntop.getFlowCheckInfo(mod_fname)
                loadable_checks[mod_fname] = {
                    full_path = full_path,
                    script = script
                }
            end
        end
    end

    return loadable_checks
end

-- ##############################################

-- @brief Load the checks.
-- @param ifid the interface ID
-- @param script_type one of checks.script_types
-- @param subdir the modules subdir. *NOTE* this must be unique as it is used as a key.
-- @param options an optional table with the following supported options:
--  - hook_filter: if non nil, only load the checks for the specified hook
--  - return_all: if true, returns all the scripts, even those with filters not matching the current configuration
--    NOTE: this can only be applied if the script type has the "has_no_entity" flag set.
--  - scripts_filter: a filter function(check) -> true, false. false will cause the script to be skipped.
-- @return {modules = key->check, hooks = check->function}
function checks.load(ifid, script_type, subdir, options)
    local rv = {
        modules = {},
        hooks = {},
        conf = {}
    }
    local old_ifid = interface.getId()
    options = options or {}
    ifid = tonumber(ifid)

    -- Load additional schemas
    script_manager.loadSchemas(options.hook_filter)

    local hook_filter = options.hook_filter
    local return_all = options.return_all
    local scripts_filter = options.scripts_filter

    if (old_ifid ~= ifid) then
        interface.select(tostring(ifid)) -- required for interface.isPacketInterface() below
    end

    for _, hook in pairs(script_type.hooks) do
        rv.hooks[hook] = {}
    end

    local loadable_checks = get_loadable_checks(script_type, subdir)

    for mod_fname, loadable_check in pairs(loadable_checks) do
        local full_path = loadable_check.full_path
        local script = loadable_check.script

        -- io.write("Loading "..full_path.."\n")

        if (rv.modules[mod_fname]) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping duplicate module '%s'", mod_fname))
            goto next_module
        end

        local check = loadAndCheckScript(mod_fname, full_path, script, script_type, subdir, return_all, scripts_filter,
            hook_filter)

        if (not check) then
            goto next_module
        end

        -- Checks passed, now load the script information

        -- Populate hooks fast lookup table
        for hook, hook_fn in pairs(check.hooks or {}) do
            if (rv.hooks[hook] == nil) then
                traceError(TRACE_WARNING, TRACE_CONSOLE,
                    string.format("Unknown hook '%s' in module '%s'", hook, check.key))
            else
                rv.hooks[hook][check.key] = hook_fn
            end
        end

        rv.modules[check.key] = check

        ::next_module::
    end

    if (old_ifid ~= ifid) then
        interface.select(tostring(old_ifid))
    end

    return (rv)
end

-- ##############################################

-- @brief Convenient method to only load a specific script
function checks.loadModule(ifid, script_type, subdir, mod_fname, return_all)
    local check
    local check_dirs = checks.getSubdirectoryPath(script_type, subdir)

    for _, checks_dir in pairs(check_dirs) do
        local full_path = os_utils.fixPath(checks_dir .. "/" .. mod_fname .. ".lua")

        if ntop.exists(full_path) then
            check = loadAndCheckScript(mod_fname, full_path, script, script_type, subdir, return_all)
            break
        end
    end

    -- If this is a flow check, we attempt at locating it among the checks of nDPI flow risks
    -- To load it, we use the default path for all simple flow check definitions
    if not check and subdir == "flow" then
        local flow_risk_alerts = ntop.getFlowRiskAlerts()
        local flow_risk_alert = flow_risk_alerts[mod_fname]

        if flow_risk_alert then
            check = loadAndCheckScript(mod_fname, FLOW_RISK_SIMPLE_CHECK_DEFINITION_PATH, script, script_type, subdir)
        end
    end

    return check
end

-- ##############################################

-- @brief Teardown function, to be called at the end of the VM
function checks.teardown(available_modules)
    for _, script in pairs(available_modules.modules) do
        if script.teardown then
            script.teardown()
        end
    end
end

-- ##############################################

function checks.listSubdirs()
    local rv = {}

    for _, subdir in ipairs(available_subdirs) do
        local item = table.clone(subdir)
        item.label = i18n(item.label) or item.label

        rv[#rv + 1] = item
    end

    return (rv)
end

-- ##############################################

-- @brief Reload checks with their existing configurations.
--        Method called as part of scripts reload (during startup or when scripts are reloaded)
-- @param is_load Boolean, indicating whether callback onLoad/onUnload should be called
-- @return nil
function checks.loadUnloadUserScripts(is_load)
    -- Read configset
    local configset = checks.getConfigset()

    -- For each subdir available, (i.e., host, flow, interface, ...)
    for _, subdir in ipairs(checks.listSubdirs()) do
        -- Load all the available checks for this subdir
        local scripts = checks.load(interface.getId(), checks.getScriptType(subdir.id), subdir.id, {
            return_all = true
        })

        for name, script in pairsByKeys(scripts.modules) do
            -- Call user script callbacks for
            -- each available configuration existing for the user script
            if not configset.config then
                traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Configuration is missing"))
                return
            end

            if not configset.config[subdir.id] then
                traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing subdir '%s' from config", subdir.id))
                return
            end

            if not configset.config[subdir.id][script.key] then
                -- Configuration can be empty (for example the first time a user script is added)
                traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
                    "Script '%s' configuration is missing from subdir '%s'. New user script?", script.key, subdir.id))
            else
                local s = configset.config[subdir.id][script.key]

                if (s ~= nil) then
                    for hook, hook_config in pairs(s) do
                        -- For each configuration there are multiple hooks.
                        -- Some hooks can be enabled, whereas some other hooks can be disabled:
                        -- methods onLoad/onUnload are only called for hooks that are enabled.
                        if script and hook_config.enabled then
                            -- onLoad/onUnload methods are ONLY called for checks that are enabled
                            if is_load and script.onLoad then
                                -- This is a load operation
                                script.onLoad(hook, hook_config)
                            elseif not is_load and script.onUnload then
                                -- This is an unload operation
                                script.onUnload(hook, hook_config)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ##############################################

local function saveConfigset(configset)
    local v = json.encode(configset)

    ntop.setCache(CONFIGSET_KEY, v)

    -- Reload flow and host callbacks executed in C++
    ntop.reloadFlowChecks()
    ntop.reloadHostChecks()

    return true
end

-- ##############################################

local cached_config_set = nil

-- Return the default config set
-- Note: Other config sets are deprecated
function checks.getConfigset()
    if not cached_config_set then
        cached_config_set = json.decode(ntop.getCache(CONFIGSET_KEY))
    end

    return cached_config_set
end

-- ##############################################

function checks.createOrReplaceConfigset(configset)
    -- Skip configurations other then the only one supported (others are deprecated)
    if configset.id and configset.id ~= checks.DEFAULT_CONFIGSET_ID then
        return false
    end

    -- Clone config
    configset = table.clone(configset)
    configset.id = checks.DEFAULT_CONFIGSET_ID

    -- Save config
    local rv = saveConfigset(configset)
    if not rv then
        return rv
    end

    return true
end

-- ##############################################

local function filterIsEqual(applied_config, new_filter)
    local ctr = 1

    if applied_config == nil then
        applied_config = {}

        return ctr
    end

    for counter, filter in pairs(applied_config) do
        if table.compare(filter, new_filter) then
            return 0
        end

        ctr = ctr + 1
    end

    return ctr
end

-- ##############################################

-- @brief Update the configuration of a specific script in a configset
function checks.updateScriptConfig(script_key, subdir, new_config)
    local configset = checks.getConfigset()
    local script_type = checks.getScriptType("flow")
    new_config = new_config or {}
    local applied_config = {}

    local script_type = checks.getScriptType(subdir)
    local script = checks.loadModule(interface.getId(), script_type, subdir, script_key)

    if (script) then
        -- Try to validate the configuration
        for hook, conf in pairs(new_config) do
            local valid = true
            local rv_or_err = ""

            if (conf.enabled == nil) then
                return false, "Missing 'enabled' item"
            end

            if (conf.script_conf == nil) then
                return false, "Missing 'script_conf' item"
            end

            if conf.enabled then
                valid, rv_or_err = script.template:parseConfig(conf.script_conf)
            else
                -- Assume the config is valid when the script is disabled to simplify the check
                valid = true
                rv_or_err = conf.script_conf
            end

            if (not valid) then
                return false, rv_or_err
            end

            -- The validator may have changed the configuration
            conf.script_conf = rv_or_err
            applied_config[hook] = conf
        end
    end

    local config = configset.config

    -- Creating the filters conf if necessary
    if not configset["filters"] then
        configset["filters"] = {}
    end
    if not configset["filters"][subdir] then
        configset["filters"][subdir] = {}
    end
    if not configset["filters"][subdir][script_key] then
        configset["filters"][subdir][script_key] = {}
    end

    local filter_conf = configset["filters"][subdir][script_key]

    ------------------------------------

    config[subdir] = config[subdir] or {}

    if script then
        local prev_config = config[subdir][script_key] or new_config

        -- Perform hook callbacks for config changes, or enable/disable
        for hook, hook_config in pairs(prev_config) do
            local hook_applied_config = applied_config[hook]

            if hook_applied_config then
                if script.onDisable and hook_config.enabled and not hook_applied_config.enabled then
                    -- Hook previously disabled has been enabled
                    script.onDisable(hook, hook_applied_config, confid)
                elseif script.onEnable and not hook_config.enabled and hook_applied_config.enabled then
                    -- Hook previously enabled has now been disabled
                    script.onEnable(hook, hook_applied_config, confid)
                elseif script.onUpdateConfig and not table.compare(hook_config, applied_config[hook]) then
                    -- Configuration for the hook has changed
                    script.onUpdateConfig(hook, hook_applied_config, confid)
                end
            end
        end
    end

    if table.len(applied_config) > 0 then
        -- Set the new configuration
        config[subdir][script_key] = applied_config
    end

    return saveConfigset(configset)
end

-- ##############################################

-- @brief Toggles script `script_key` configuration on or off depending on `enable` for configuration `configset`
--        Hooks onDisable and onEnable are called.
-- @param configset A user script configuration, obtained with checks.getConfigset()
-- @param script_key The string script identifier
-- @param subdir The string identifying the sub directory (e.g., flow, host, ...)
-- @param enable A boolean indicating whether the script shall be toggled on or off
local function toggleScriptConfigset(configset, script_key, subdir, enable)
    local script_type = checks.getScriptType(subdir)
    local script = checks.loadModule(interface.getId(), script_type, subdir, script_key, true)

    if not script then
        return false, i18n("configsets.unknown_check", {
            check = script_key
        })
    end

    local config = checks.getScriptConfig(configset, script, subdir)

    if config then
        for hook, hook_config in pairs(config) do
            -- Remember the previous toggle
            local prev_hook_config = hook_config.enabled
            -- Save the new toggle
            hook_config.enabled = enable

            if script.onDisable and prev_hook_config and not enable then
                -- Hook has been enabled for the user script
                script.onDisable(hook, hook_config)
            elseif script.onEnable and not prev_hook_config and enable then
                -- Hook has been disabled for the user script
                script.onEnable(hook, hook_config)
            end
        end
    end

    if (not configset["config"][subdir]) then
        configset["config"][subdir] = {}
    end

    if (not configset["config"][subdir][script_key]) or (table.len(configset["config"][subdir][script_key]) == 0) then
        configset["config"][subdir][script_key] = {}
        configset["config"][subdir][script_key] = config
    end

    return true
end

-- ##############################################

function checks.toggleScript(script_key, subdir, enable)
    local configset = checks.getConfigset()

    -- Toggle the configuration (result is put in `configset`)
    local res, err = toggleScriptConfigset(configset, script_key, subdir, enable)
    if not res then
        return res, err
    end

    -- If the toggle has been successful, write the new configset and return
    return saveConfigset(configset)
end

-- ##############################################

function checks.toggleAllScripts(subdir, enable)
    local configset = checks.getConfigset()

    -- Toggle the configuration (result is put in `configset`)
    local scripts = checks.load(getSystemInterfaceId(), checks.getScriptType(subdir), subdir)

    for script_name, script in pairs(scripts.modules) do
        -- Toggle each script individually
        local res, err = toggleScriptConfigset(configset, script.key, subdir, enable)
        if not res then
            return res, err
        end
    end

    -- If the toggle has been successful for all scripts, write the new configset and return
    return saveConfigset(configset)
end

-- ##############################################

-- @brief Returns the factory checks configuration
--        Any user-submitted conf param is ignored
function checks.getFactoryConfig()
    local ifid = getSystemInterfaceId()
    local default_conf = {}

    for type_id, script_type in pairs(checks.script_types) do
        for _, subdir in pairs(script_type.subdirs) do
            local scripts = checks.load(ifid, script_type, subdir, {
                return_all = true
            })

            for key, usermod in pairs(scripts.modules) do
                default_conf[subdir] = default_conf[subdir] or {}
                default_conf[subdir][key] = default_conf[subdir][key] or {}
                local script_config = default_conf[subdir][key]
                local hooks = ternary(script_type.has_per_hook_config, usermod.hooks, {
                    [ALL_HOOKS_CONFIG_KEY] = 1
                })

                for hook in pairs(hooks) do
                    script_config[hook] = {
                        enabled = usermod.default_enabled or false,
                        script_conf = usermod.default_value or {}
                    }
                end
            end
        end
    end

    local res = {
        id = checks.DEFAULT_CONFIGSET_ID,
        name = i18n("policy_presets.default"),
        config = default_conf
    }

    return res
end

-- ##############################################

-- @brief Migrate old configurations, if any
function checks.migrateOldConfig()

    -- Check if there is a v3 already
    local configset_v3 = ntop.getCache(CONFIGSET_KEY)
    if isEmptyString(configset_v3) then

        -- Check if there is a v2
        local CONFIGSETS_KEY_V2 = "ntopng.prefs.checks.configsets_v2"
        local configsets_v2 = ntop.getHashAllCache(CONFIGSETS_KEY_V2)
        if configsets_v2 then

            -- Migrate v2 to v3
            local default_confset_json = configsets_v2["0"]
            if default_confset_json then
                ntop.setCache(CONFIGSET_KEY, default_confset_json)
            end

            -- Remove v2
            ntop.delCache(CONFIGSETS_KEY_V2)
        end
    end

end

-- ##############################################

-- @brief Initializes a default configuration for checks
-- @param overwrite If true, a possibly existing configuration is overwritten with default values
function checks.initDefaultConfig()
    local ifid = getSystemInterfaceId()

    -- Current (possibly not-existing, not yet created configset)
    local configset = checks.getConfigset() or {}
    -- Default per user-script configuration
    local default_conf = configset.config or {}
    -- Default per user-script filters
    local default_filters = configset.filters or {}

    for type_id, script_type in pairs(checks.script_types) do
        for _, subdir in pairs(script_type.subdirs) do
            local scripts = checks.load(ifid, script_type, subdir, {
                return_all = true
            })

            for key, usermod in pairs(scripts.modules) do
                -- Cleanup exclusion counters
                ntop.delCache(string.format(NUM_FILTERED_KEY, subdir, key))

                -- Add configuration when required (default_enabled or default_value)
                if usermod.default_enabled ~= nil or usermod.default_value ~= nil then

                    if default_conf[subdir] and default_conf[subdir][key] then
                        -- There is already a configuration for this script
                        -- (nothing to do)

                    else
                        -- Add default configuration
                        default_conf[subdir] = default_conf[subdir] or {}
                        default_conf[subdir][key] = default_conf[subdir][key] or {}
                        local script_config = default_conf[subdir][key]
                        local hooks = ternary(script_type.has_per_hook_config, usermod.hooks, {
                            [ALL_HOOKS_CONFIG_KEY] = 1
                        })

                        for hook in pairs(hooks) do
                            -- Do not override an existing configuration
                            if (script_config[hook] == nil) then
                                script_config[hook] = {
                                    enabled = usermod.default_enabled or false,
                                    script_conf = usermod.default_value or {}
                                }
                            end
                        end

                    end

                end

                if usermod.filter and usermod.filter.default_filters then
                    default_filters[subdir] = default_filters[subdir] or {}

                    if default_filters[subdir][key] then
                        -- Do not override filter of an existing configuration
                        -- (nothing to do)

                    else
                        -- Add filter
                        default_filters[subdir][key] = usermod.filter.default_filters
                    end
                end
            end
        end
    end

    -- This is the new configset with all defaults
    configset = {
        config = default_conf,
        filters = default_filters
    }

    -- Save configuration (even if already present, as there may be new checks/risks)
    saveConfigset(configset)
end

-- ##############################################

function checks.resetConfigset()
    cached_config_set = nil
    ntop.delCache(CONFIGSET_KEY)
    checks.initDefaultConfig()

    return (true)
end

-- ##############################################

-- Returns true if a script is enabled
-- Example: checks.isCheckEnabled("host", "external_host_script")
function checks.isCheckEnabled(entity_name, script_key)
    local configset = checks.getConfigset()
    local default_config = checks.getConfig(configset, entity_name)

    local script_config = default_config[script_key]

    if (script_config) then
        for _, hook in pairs(script_config) do
            if (hook.enabled) then
                return (true)
            end
        end
    end

    return (false)
end

-- ##############################################

-- Returns true if a system script is enabled for some hook
function checks.isSystemScriptEnabled(script_key)
    -- Verify that the script is currently available
    local k = "ntonpng.cache.checks.available_system_modules." .. script_key
    local available = ntop.getCache(k)

    if (isEmptyString(available)) then
        local m = checks.loadModule(getSystemInterfaceId(), checks.script_types.system, "system", script_key)
        available = (m ~= nil)

        ntop.setCache(k, ternary(available, "1", "0"))
    else
        available = ternary(available == "1", true, false)
    end

    if (not available) then
        return (false)
    end

    -- Here the configuration is update with the exclusion list for the alerts
    return checks.isCheckEnabled("system", script_key)
end

-- ##############################################

local default_config = {
    enabled = false,
    script_conf = {}
}

-- @brief Retrieves the configuration of a specific script
function checks.getScriptConfig(configset, script, subdir)
    local script_key = script.key
    local config = configset.config[subdir]

    if (config) and (config[script_key]) and (table.len(config[script_key]) > 0) then
        -- A configuration was found
        return (config[script_key])
    end

    -- Default
    local rv = {}
    local script_type = checks.getScriptType(subdir)
    local hooks = ternary(script_type.has_per_hook_config, script.hooks, {
        [ALL_HOOKS_CONFIG_KEY] = 1
    })

    for hook, _ in pairs(hooks or {}) do
        rv[hook] = default_config
        if script and script.default_value then
            rv[hook].script_conf = script.default_value
        end
    end

    return (rv)
end

-- ##############################################

-- @brief Retrieves the configuration of a specific hook of the target
-- @param target_config target configuration as returned by
-- checks.getTargetConfig/checks.getHostTargetConfigset
function checks.getTargetHookConfig(target_config, script, hook)
    local script_conf = target_config[script.key or script]

    if not hook then
        -- See has_per_hook_config
        hook = ALL_HOOKS_CONFIG_KEY
    end

    if (not script_conf) then
        return (default_config)
    end

    local conf = script_conf[hook] or default_config
    local default_values = script.default_value or {}

    -- Each new default value will be added to the conf.script_conf table
    -- in this way if future values need to be added here there won't be problems
    for key, value in pairs(default_values) do
        if not conf.script_conf[key] then
            conf.script_conf[key] = value
        end
    end

    local default_filter_table = script.filter or {}
    local default_filter_suppression = {}

    -- Checking if filters are configured by default
    if default_filter_table then
        conf.script_conf["filter"] = {}
        default_filter_suppression = default_filter_table.default_filter or {}
    end

    return conf
end

-- ##############################################

-- @brief Retrieve a `subdir` configuration from the configset identified with `confset_id` from all the available `configsets` passed
function checks.getConfig(configset, subdir)
    if configset and configset["config"] and configset["config"][subdir] then
        return configset["config"][subdir]
    end

    return {}, nil
end

-- ##############################################

-- @brief Retrieve `subdir` filters from the configset
function checks.getFilters(configset, subdir)
    if configset and configset["filters"] and configset["filters"][subdir] then
        return configset["filters"][subdir]
    end

    return {}, nil
end

-- ##############################################

function checks.getScriptEditorUrl(script)
    if (script.edition == "community" and script.source_path) then
        local script_file_path = string.sub(script.source_path, string.len(dirs.scriptdir) + 1)
        local script_path = string.sub(script.script.path, string.len(dirs.scriptdir) + 1)
        return (string.format("%s/lua/code_viewer.lua?script_file_path=%s&script_path=%s", ntop.getHttpPrefix(),
            script_file_path, script_path))
    end

    return (nil)
end

-- ##############################################

-- @brief Returns the list of the default filters of a specific alert
function checks.getFilterPreset(alert, alert_info)
    local alert_generation = alert_info["alert_generation"]

    if not alert_generation then
        return ''
    end

    local subdir = alert_generation["subdir"]
    local subdir_id = getSubdirId(subdir)

    if subdir_id == -1 then
        return ''
    end

    if not available_subdirs[subdir_id]["filter"] then
        return ''
    end

    local filter_to_use = {}

    if available_subdirs[subdir_id]["filter"]["default_fields"] then
        filter_to_use = available_subdirs[subdir_id]["filter"]["default_fields"]
    end

    local filter_table = {}
    local index = 1

    for _, field in pairs(filter_to_use) do
        -- Check for field existance in the alert
        local field_val = alert[field]

        -- If the filed does not exist, try and look it up inside `alert_info`, that is,
        -- a decoded JSON table containing variable alert data.
        if not field_val then
            field_val = alert_info[field]
        end

        if field_val then
            -- Forming the string e.g. srv_addr=1.1.1.1
            filter_table[index] = field .. "=" .. field_val
            index = index + 1
        end
    end

    -- Creating the required string to print into the GUI
    return table.concat(filter_table, ",")
end

-- #################################

-- @bief Given an already validated filter, returns a SQLite WHERE clause matching all filter fields
-- @param configset A user script configuration, obtained with checks.getConfigset()
-- @param subdir the modules subdir
-- @param check The string script identifier
-- @param filter An already validated user script filter
-- @return A string with the SQLite WHERE clause
function checks.prepareFilterSQLiteWhere(subdir, check, filter)
    -- Access the alert_json using SQLite `json_` functions to properly filter with fields
    local filters_where = {}

    -- This is to match elements inside the alert_json
    local script_where = {string.format("json_extract(alert_json, '$.alert_generation.subdir') = '%s'", subdir),
                          string.format("json_extract(alert_json, '$.alert_generation.script_key') = '%s'", check)}

    -- Now prepare each SQLite statement for every field
    local subdir_id = getSubdirId(subdir)

    -- Retrieving the available filters for the subdir. e.g. flow subdir
    local available_fields = available_subdirs[subdir_id]["filter"]["available_fields"]

    for field_key, field_val in pairs(filter) do
        if available_fields[field_key] and available_fields[field_key]["sqlite"] then
            local sqlite = available_fields[field_key]["sqlite"](field_val)
            filters_where[#filters_where + 1] = sqlite
        end
    end

    -- Concatenate
    local where = table.merge(filters_where, script_where)
    -- And merge everything with ANDs
    where = table.concat(where, " AND ")

    return where
end

-- ##############################################

-- @brief This function is going to check if the user script needs to be excluded
--        from the list, due to not having filters or not
function checks.excludeScriptFilters(alert, alert_json, script_key, subdir)
    local configset = checks.getConfigset()

    -- Getting the configuration
    local config = configset["filters"]

    if not config then
        return false
    end

    -- Security checks
    local conf = config[subdir]

    if not conf then
        return false
    end

    conf = conf[script_key]

    if not conf then
        return false
    end

    local applied_filter_config = {}
    local subdir_id = getSubdirId(subdir)

    -- Checking if the script has the field "filter.current_filters"
    if conf["filter"] then
        applied_filter_config = conf["filter"]["current_filters"]
    end

    if not applied_filter_config then
        return false
    end

    -- Cycling through the filters
    for _, values in pairs(applied_filter_config) do
        local done = true
        -- Getting the keys and values of the filters. e.g. filter=src_port, value=3900
        for filter, value in pairs(values) do
            -- Possible strange pattern, so using the function find,
            -- defined into the available field to check the presence of the data
            local find_value = available_subdirs[subdir_id]["filter"]["available_fields"][filter]["find"]
            if not find_value(alert, alert_json, filter, value) then
                -- The alert has a different value for that filter
                done = false
                goto continue2
            end
            ::continue::
        end

        -- if
        if done then
            return true
        end

        ::continue2::
    end

    -- all the filters are correct, exclude the alert
    return false
end

-- ##############################################

function checks.getDefaultFilters(ifid, subdir, script_key)

    local script_type = checks.getScriptType(subdir)
    local script = checks.loadModule(ifid, script_type, subdir, script_key)
    local filters = {}
    filters["current_filters"] = {}

    if script["filter"] and script["filter"]["default_filters"] then
        filters["current_filters"] = script["filter"]["default_filters"]
    end

    return filters
end

-- ##############################################

local function printUserScriptsTable()
    local ifid = interface.getId()
    local flow_checks_stats = ntop.getFlowChecksStats() or {}

    for _, info in ipairs(checks.listSubdirs()) do
        local scripts = checks.load(ifid, checks.getScriptType(info.id), info.id, {
            return_all = true
        })

        for name, script in pairsByKeys(scripts.modules) do
            local available = ""
            local filters = {}
            local hooks = {}
            local tot_exec_time

            -- Hooks
            for hook in pairsByKeys(script.hooks) do
                hooks[#hooks + 1] = hook
            end
            hooks = table.concat(hooks, ", ")

            -- Filters
            if (script.l4_proto) then
                filters[#filters + 1] = "l4_proto=" .. script.l4_proto
            end
            if (script.l7_proto) then
                filters[#filters + 1] = "l7_proto=" .. script.l7_proto
            end
            if (script.packet_interface_only) then
                filters[#filters + 1] = "packet_interface"
            end
            if (script.three_way_handshake_ok) then
                filters[#filters + 1] = "3wh_completed"
            end
            if (script.local_only) then
                filters[#filters + 1] = "local_only"
            end
            if (script.nedge_only) then
                filters[#filters + 1] = "nedge=true"
            end
            if (script.nedge_exclude) then
                filters[#filters + 1] = "nedge=false"
            end
            filters = table.concat(filters, ", ")

            if (name == "my_custom_script") then
                goto skip
            end

            -- Availability
            if (script.edition == "enterprise_m") then
                available = "Enterprise M"
            elseif (script.edition == "enterprise_l") then
                available = "Enterprise L"
            elseif (script.edition == "pro") then
                available = "Pro"
            else
                available = "Community"
            end

            -- Execution stats
            if info.id == 'flow' and flow_checks_stats[name] and flow_checks_stats[name].stats and
                flow_checks_stats[name].stats.execution_time then
                -- Importing just when needed
                local format_utils = require("format_utils")
                tot_exec_time = format_utils.msToTime(flow_checks_stats[name].stats.execution_time / 1000000)
            end

            print(string.format(([[
                <tr>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td class="text-end">%u</td>
                    <td class="text-end">%s</td>
                    <td class="text-center">%s</td></tr>
                ]]), name, info.label, available, hooks, filters, script.num_filtered, tot_exec_time or "",
                edit_url or ""))
            ::skip::
        end
    end
end

-- #######################################################

function checks.printUserScripts()
    print([[
            <div class='col-12 my-3'>
                <table class='table table-bordered table-striped' id='user-scripts'>
                    <thead>
                        <tr>
                            <th>]] .. i18n("scripts_overview.script") .. [[</th>
                            <th>]] .. i18n("scripts_overview.type") .. [[</th>
                            <th>]] .. i18n("availability") .. [[</th>
                            <th>]] .. i18n("scripts_overview.hooks") .. [[</th>
                            <th>]] .. i18n("scripts_overview.filters") .. [[</th>
                            <th>]] .. i18n("scripts_overview.filtered") .. [[</th>
                            <th>]] .. i18n("scripts_overview.total_elapsed_time") .. [[</th>
                            <th>]] .. i18n("action") .. [[</th>
                        </tr>
                    </thead>
                    <tbody>]])
    printUserScriptsTable()
    print([[
                    </tbody>
                </table>
        </div>
    <script type='text/javascript'>

    $(document).ready(function() {

        const addFilterDropdown = (title, values, column_index, datatableFilterId, tableApi) => {

            const createEntry = (val, callback) => {
                const $entry = $(`<li class='dropdown-item pointer'>${val}</li>`);
                $entry.click(function(e) {

                    $dropdownTitle.html(`<i class='fas fa-filter'></i> ${val}`);
                    $menuContainer.find('li').removeClass(`active`);
                    $entry.addClass(`active`);
                    callback(e);
                });

                return $entry;
            }

            const dropdownId = `${title}-filter-menu`;
            const $dropdownContainer = $(`<div id='${dropdownId}' class='dropdown d-inline'></div>`);
            const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-bs-toggle='dropdown' type='button'></button>`);
            const $dropdownTitle = $(`<span>${title}</span>`);
            $dropdownButton.append($dropdownTitle);

            const $menuContainer = $(`<ul class='dropdown-menu' id='${title}-filter'></ul>`);
            values.forEach((val) => {
                const $entry = createEntry(val, (e) => {
                    tableApi.columns(column_index).search(val).draw(true);
                });
                $menuContainer.append($entry);
            });

            const $allEntry = createEntry(']] .. i18n('all') .. [[', (e) => {
                $dropdownTitle.html(`${title}`);
                $menuContainer.find('li').removeClass(`active`);
                tableApi.columns().search('').draw(true);
            });
            $menuContainer.prepend($allEntry);

            $dropdownContainer.append($dropdownButton, $menuContainer);
            $(datatableFilterId).prepend($dropdownContainer);
        }

        const $userScriptsTable = $('#user-scripts').DataTable({
            pagingType: 'full_numbers',
            initComplete: function(settings) {

                const table = settings.oInstance.api();
                const types = [... new Set(table.columns(1).data()[0].flat())];
                const availability = [... new Set(table.columns(2).data()[0].flat())];

                addFilterDropdown(']] .. i18n("availability") .. [[', availability, 2, "#user-scripts_filter", table);
                addFilterDropdown(']] .. i18n("scripts_overview.type") .. [[', types, 1, "#user-scripts_filter", table);
            },
            pageLength: 25,
            language: {
                info: "]] .. i18n('showing_x_to_y_rows', {
        x = '_START_',
        y = '_END_',
        tot = '_TOTAL_'
    }) .. [[",
                search: "]] .. i18n('search') .. [[:",
                infoFiltered: "",
                paginate: {
                    previous: '&lt;',
                    next: '&gt;',
                    first: '«',
                    last: '»'
                },
            },
        });

    });

    </script>
]])

end

-- #################################################################

local function snmp_device_run_checks(cached_device, checks_var)
    local snmp_utils = require "snmp_utils"
    local granularity = checks_var.cur_granularity
    local device_ip = cached_device["host_ip"]
    local snmp_device_entity = alert_entity_builders.snmpDeviceEntity(device_ip)
    local all_modules = checks_var.available_modules.modules
    local now = os.time()
    now = now - now % 300

    local info = {
        granularity = granularity,
        alert_entity = snmp_device_entity,
        check = check,
        cached_device = cached_device,
        now = now
    }

    -- Retrieve the configuration
    local device_conf = checks.getConfig(checks_var.configset, "snmp_device")

    -- Run callback for each device
    for mod_key, hook_fn in pairs(checks_var.available_modules.hooks["snmpDevice"] or {}) do
        local script = all_modules[mod_key]
        local conf = checks.getTargetHookConfig(device_conf, script)

        if (conf.enabled) then
            invokeScriptHook(script, checks_var.configset, hook_fn, device_ip, info, conf)
        end
    end

    -- Run callback for each interface
    for mod_key, hook_fn in pairs(checks_var.available_modules.hooks["snmpDeviceInterface"] or {}) do
        local script = all_modules[mod_key]
        local conf = checks.getTargetHookConfig(device_conf, script)

        -- For each interface of the current device...
        for snmp_interface_index, snmp_interface in pairs(cached_device.interfaces) do
            if (script.skip_virtual_interfaces and snmp_utils.isVirtualInterfaceType(snmp_interface.type)) then
                goto continue
            end

            if (conf.enabled) then
                local iface_entity = alert_entity_builders.snmpInterfaceEntity(device_ip, snmp_interface_index)

                -- Augment data with counters and status
                snmp_interface["if_counters"] = cached_device.if_counters[snmp_interface_index]
                snmp_interface["bridge"] = cached_device.bridge[snmp_interface_index]

                invokeScriptHook(script, checks_var.configset, hook_fn, device_ip, snmp_interface_index,
                    table.merge(snmp_interface, {
                        granularity = granularity,
                        alert_entity = iface_entity,
                        check = script,
                        check_config = conf.script_conf,
                        cached_device = cached_device,
                        now = now
                    }))
            end

            ::continue::
        end
    end

    return true
end

-- #################################################################

-- The function below is called at shutdown
local function teardownChecks(str_granularity, checks_var, do_trace)
    if (do_trace) then
        print("alert.lua:teardown(" .. str_granularity .. ") called\n")
    end

    checks.teardown(checks_var.available_modules)
end

-- ##############################################

-- The function below ia called once at the startup
local function setupInterfaceChecks(str_granularity, checks_var, do_trace)
    if (do_trace) then
        print("alert.lua:setup(" .. str_granularity .. ") called\n")
    end
    checks_var.ifid = interface.getId()

    -- Load the check modules
    checks_var.available_modules = checks.load(checks_var.ifid, checks.script_types.traffic_element, "interface", {
        hook_filter = str_granularity
    })

    checks_var.configset = checks.getConfigset()
    -- Retrieve the configuration associated to the confset
    checks_var.iface_config = checks.getConfig(checks_var.configset, "interface")
end

-- #################################################################

-- The function below ia called once (#pragma once)
local function setupLocalNetworkChecks(str_granularity, checks_var, do_trace)
    checks_var.network_entity = alert_entities.network.entity_id
    if do_trace then
        print("alert.lua:setup(" .. str_granularity .. ") called\n")
    end
    checks_var.ifid = interface.getId()

    -- Load the threshold checking functions
    checks_var.available_modules = checks.load(ifid, checks.script_types.traffic_element, "network", {
        hook_filter = str_granularity
    })

    checks_var.configset = checks.getConfigset()
end

-- #################################################################

-- The function below ia called once (#pragma once)
local function setupSystemChecks(str_granularity, checks_var, do_trace)
    if do_trace then
        traceError(TRACE_NORMAL, TRACE_CONSOLE, "system.lua:setup(%s) called", str_granularity)
    end

    interface.select(getSystemInterfaceId())
    checks_var.ifid = getSystemInterfaceId()

    checks_var.system_ts_enabled = areSystemTimeseriesEnabled()

    -- Load the threshold checking functions
    checks_var.available_modules = checks.load(checks_var.ifid, checks.script_types.system, "system", {
        hook_filter = str_granularity
    })

    checks_var.configset = checks.getConfigset()
    checks_var.system_config = checks.getConfig(checks_var.configset, "system")
end

-- #################################################################

-- The function below ia called once (#pragma once)
local function setupSNMPChecks(str_granularity, checks_var, do_trace)
    if not ntop.isEnterprise() and not ntop.isnEdgeEnterprise() then
        return false
    end

    if do_trace then
        print("alert.lua:setup(" .. str_granularity .. ") called\n")
    end

    checks_var.snmp_device_entity = alert_entities.snmp_device.entity_id

    interface.select(getSystemInterfaceId())
    checks_var.ifid = getSystemInterfaceId()

    -- Load the threshold checking functions
    checks_var.available_modules = checks.load(ifid, checks.script_types.snmp_device, "snmp_device")
    checks_var.configset = checks.getConfigset()

    return true
end

-- #################################################################

-- The function below ia called once (#pragma once)
local function setupActiveMonitoringChecks(str_granularity, checks_var, do_trace)
    if not ntop.isEnterpriseL() then
        return false
    end

    if do_trace then
        print("alert.lua:setup(" .. str_granularity .. ") called\n")
    end

    checks_var.snmp_device_entity = alert_entities.snmp_device.entity_id

    interface.select(getSystemInterfaceId())
    checks_var.ifid = getSystemInterfaceId()

    -- Load the threshold checking functions
    checks_var.available_modules = checks.load(ifid, checks.script_types.active_monitoring, "active_monitoring")
    checks_var.configset = checks.getConfigset()

    return true
end

-- #################################################################

-- This function runs interfaces checks
local function runInterfaceChecks(granularity, checks_var, do_trace)
    if table.empty(checks_var.available_modules.hooks[granularity]) then
        if (do_trace) then
            print("interface:runScripts(" .. granularity .. "): no modules, skipping\n")
        end
        return
    end

    local granularity_id = alert_granularities[granularity].granularity_id

    local info = interface.getStats()
    local cur_alerts = interface.getAlerts(granularity_id)
    local entity_info = alert_entity_builders.interfaceAlertEntity(checks_var.ifid)

    if (do_trace) then
        print("checkInterfaceAlerts()\n")
    end

    for mod_key, hook_fn in pairs(checks_var.available_modules.hooks[granularity]) do
        local check = checks_var.available_modules.modules[mod_key]
        local conf = checks.getTargetHookConfig(checks_var.iface_config, check, granularity)

        if (conf.enabled) then
            invokeScriptHook(check, checks_var.configset, hook_fn, {
                granularity = granularity,
                alert_entity = entity_info,
                entity_info = info,
                cur_alerts = cur_alerts,
                check_config = conf.script_conf,
                check = check
            })
        end
    end

    -- cur_alerts now contains unprocessed triggered alerts, that is,
    -- those alerts triggered but then disabled or unconfigured (e.g., when
    -- the user removes a threshold from the gui)
    if #cur_alerts > 0 then
        alert_management.releaseEntityAlerts(entity_info, cur_alerts)
    end
end

-- #################################################################

-- The function below is called once per local network
local function runLocalNetworkChecks(granularity, checks_var, do_trace)
    if table.empty(checks_var.available_modules.hooks[granularity]) then
        if (do_trace) then
            print("network:runScripts(" .. granularity .. "): no modules, skipping\n")
        end
        return
    end

    local info = network.getNetworkStats()
    local network_key = info and info.network_key
    if not network_key then
        return
    end

    local granularity_id = alert_granularities[granularity].granularity_id

    local cur_alerts = network.getAlerts(granularity_id)
    local entity_info = alert_entity_builders.networkAlertEntity(network_key)

    -- Retrieve the configuration
    local subnet_conf = checks.getConfig(checks_var.configset, "network")

    for mod_key, hook_fn in pairs(checks_var.available_modules.hooks[granularity]) do
        local check = checks_var.available_modules.modules[mod_key]
        local conf = checks.getTargetHookConfig(subnet_conf, check, granularity)

        if (conf.enabled) then
            invokeScriptHook(check, checks_var.configset, hook_fn, {
                granularity = granularity,
                alert_entity = entity_info,
                entity_info = info,
                cur_alerts = cur_alerts,
                check_config = conf.script_conf,
                check = check
            })
        end
    end

    -- cur_alerts contains unprocessed triggered alerts, that is,
    -- those alerts triggered but then disabled or unconfigured (e.g., when
    -- the user removes a threshold from the gui)
    if #cur_alerts > 0 then
        alert_management.releaseEntityAlerts(entity_info, cur_alerts)
    end
end

-- #################################################################

local function runSystemChecks(granularity, checks_var, do_trace)

    if do_trace then
        print("system.lua:runScripts(" .. granularity .. ") called\n")
    end

    if table.empty(checks_var.available_modules.hooks[granularity]) then
        if (do_trace) then
            print("system:runScripts(" .. granularity .. "): no modules, skipping\n")
        end
        return
    end

    -- NOTE: currently no deadline check is explicitly performed here.
    -- The "process:resident_memory" must always be written as it has the
    -- is_critical_ts flag set.

    local info = interface.getStats()
    local when = os.time()

    for mod_key, hook_fn in pairs(checks_var.available_modules.hooks[granularity]) do
        local check = checks_var.available_modules.modules[mod_key]
        local conf = checks.getTargetHookConfig(checks_var.system_config, check, granularity)

        if (conf.enabled) then
            invokeScriptHook(check, checks_var.configset, hook_fn, {
                granularity = granularity,
                alert_entity = alert_entity_builders.interfaceAlertEntity(getSystemInterfaceId()),
                check_config = conf.script_conf,
                check = check,
                when = when,
                entity_info = info,
                ts_enabled = checks_var.system_ts_enabled
            })

            -- Safety check
            if interface.getId() ~= tonumber(getSystemInterfaceId()) then
                traceError(TRACE_ERROR, TRACE_CONSOLE,
                    string.format("Script '%s' changed the interface from '%d' to '%d'. Resetting interface.", mod_key,
                        tonumber(getSystemInterfaceId()), interface.getId()))
                interface.select(getSystemInterfaceId())
            end
        end
    end
end

-- #################################################################

local function runSNMPChecks(granularity, checks_var, do_trace)
    local snmp_config = require "snmp_config"
    local snmp_cached_dev = require "snmp_cached_dev"

    checks_var.cur_granularity = granularity

    if (table.empty(checks_var.available_modules.hooks)) then
        -- Nothing to do
        return
    end

    -- NOTE: don't use foreachSNMPDevice, we want to get all the SNMP
    -- devices, not only the active ones, without changing the device state
    local snmpdevs = snmp_config.get_all_configured_devices()

    for device_ip, device in pairs(snmpdevs) do
        local load_all_cached_info = false
        local cached_device = snmp_cached_dev:create(device_ip, load_all_cached_info)

        if cached_device then
            snmp_device_run_checks(cached_device, checks_var)
        end
    end
end

-- #################################################################

local function runActiveMonitoringChecks(granularity, checks_var, do_trace)
    if do_trace then
        print("active_monitoring.lua:runScripts(" .. granularity .. ") called\n")
    end

    if table.empty(checks_var.available_modules.hooks[granularity]) then
        if (do_trace) then
            print("active_monitoring:runScripts(" .. granularity .. "): no modules, skipping\n")
        end
        return
    end

    -- NOTE: currently no deadline check is explicitly performed here.
    -- The "process:resident_memory" must always be written as it has the
    -- is_critical_ts flag set.

    local info = interface.getStats()
    local when = os.time()
    local active_monitoring_conf = checks.getConfig(checks_var.configset, "active_monitoring")

    for mod_key, hook_fn in pairs(checks_var.available_modules.hooks[granularity]) do
        local check = checks_var.available_modules.modules[mod_key]
        local conf = checks.getTargetHookConfig(active_monitoring_conf, check, granularity)

        if (conf.enabled) then
            invokeScriptHook(check, checks_var.configset, hook_fn, {
                granularity = granularity,
                alert_entity = alert_entity_builders.interfaceAlertEntity(getSystemInterfaceId()),
                check_config = conf.script_conf,
                check = check,
                when = when,
                entity_info = info,
                ts_enabled = checks_var.system_ts_enabled
            })

            -- Safety check
            if interface.getId() ~= tonumber(getSystemInterfaceId()) then
                traceError(TRACE_ERROR, TRACE_CONSOLE,
                    string.format("Script '%s' changed the interface from '%d' to '%d'. Resetting interface.", mod_key,
                        tonumber(getSystemInterfaceId()), interface.getId()))
                interface.select(getSystemInterfaceId())
            end
        end
    end
end

-- #################################################################
-- @brief Setup, run and shutdown interface, network, system and
--        SNMP checks
--        The setup, loads the alerts, needs to be done once per VM
--        The run, cycle all the alerts and execute them
--        The teardown, unloads the alerts from the vm
-- #################################################################

-- #################################################################

function checks.interfaceChecks(granularity, checks_var, do_trace)
    setupInterfaceChecks(granularity, checks_var, do_trace)
    runInterfaceChecks(granularity, checks_var, do_trace)
    teardownChecks(granularity, checks_var, do_trace)
end

-- #################################################################

function checks.localNetworkChecks(granularity, checks_var, do_trace)
    setupLocalNetworkChecks(granularity, checks_var, do_trace)
    runLocalNetworkChecks(granularity, checks_var, do_trace)
    teardownChecks(granularity, checks_var, do_trace)
end

-- #################################################################

function checks.systemChecks(granularity, checks_var, do_trace)
    setupSystemChecks(granularity, checks_var, do_trace)
    runSystemChecks(granularity, checks_var, do_trace)
    teardownChecks(granularity, checks_var, do_trace)
end

-- #################################################################

function checks.SNMPChecks(granularity, checks_var, do_trace)
    if not setupSNMPChecks(granularity, checks_var, do_trace) then
        return false
    end

    runSNMPChecks(granularity, checks_var, do_trace)
    teardownChecks(granularity, checks_var, do_trace)

    return true
end

-- #################################################################

function checks.activeMonitoringChecks(granularity, checks_var, do_trace)
    if not setupActiveMonitoringChecks(granularity, checks_var, do_trace) then
        return false
    end

    runActiveMonitoringChecks(granularity, checks_var, do_trace)
    teardownChecks(granularity, checks_var, do_trace)

    return true
end

-- #################################################################

-- @brief Loads the ntopng scripts into a single directory.
function checks.loadChecks()
    for _, path in pairs(script_manager.getAllRuntimePaths()) do
        ntop.mkdir(path)
    end

    -- Remove the list of system scripts enabled, re-added from the checks.lua file
    deleteCachePattern("ntonpng.cache.checks.available_system_modules.*")

    -- Reload checks with their configurations
    checks.initDefaultConfig()
    checks.loadUnloadUserScripts(true --[[ load --]] )

    return (true)
end

-- #################################################################

if (trace_script_duration ~= nil) then
    io.write(debug.getinfo(1, 'S').source .. " executed in " .. (os.clock() - clock_start) * 1000 .. " ms\n")
end

return (checks)

