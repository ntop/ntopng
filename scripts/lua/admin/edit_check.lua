--
-- (C) 2021 - ntop.org
--

-- TODO: reset custom callback
-- TODO: /scripts/lua/module/checks/templates

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require("template_utils")
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local checks = require("checks")
local rest_utils = require "rest_utils"
local auth = require "auth"
local checks_utils = require("checks_utils")
local alert_severities = require("alert_severities")

local function format_exclusion_list_filters(filters)

    local formatted = {}

    for _, filter in ipairs(filters.current_filters) do
        for key, filter_value in pairs(filter) do
            formatted[#formatted+1] = key .. "=" .. filter_value
        end
    end 

    return table.concat(formatted, '\n')
end

if not auth.has_capability(auth.capabilities.checks) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.scripts_config)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local check_subdir = _GET["subdir"]
local script_key    = _GET["script_key"]

local configset     = checks.getConfigset()
local script_type   = checks.getScriptType(check_subdir)
local selected_script = checks.loadModule(getSystemInterfaceId(), script_type, check_subdir, script_key)
local script_title = i18n(selected_script.gui.i18n_title) or selected_script.gui.i18n_title

local confset_name  = configset.name
local titles        = checks_utils.load_configset_titles()

local hooks_config = checks.getScriptConfig(configset, selected_script, check_subdir)
local generated_templates = selected_script.template:render(hooks_config)

local generated_breadcrumb = ui_utils.render_breadcrumb(i18n("about.checks"), {
    {
        label = titles[check_subdir],
    },
    {
        href = ntop.getHttpPrefix() .. "/lua/admin/edit_configset.lua?subdir=" .. check_subdir,
        label = i18n("scripts_list.config", {}) .. " " .. confset_name
    },
    {
        active = true, 
        label = script_title
    }
    
}, "fab fa-superpowers")

local base_context = {
    info = ntop.getInfo(),
    json = json,
    edit_check = {
        breadcrumb = generated_breadcrumb,
        plugin = selected_script,
        alert_severities = alert_severities,
        script_title = script_title,
        rendered_hooks = generated_templates,
        
        hooks_config = hooks_config,
        check_subdir = check_subdir,
        script_key = script_key,
        filters = format_exclusion_list_filters(checks.getDefaultFilters(interface.getId(), check_subdir, script_key))
    }
}

print(template.gen("pages/edit_check.template", base_context))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
