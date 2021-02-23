--
-- (C) 2021 - ntop.org
--

-- TODO: check the 'is_alert' field
-- TODO: reset custom callback
-- TODO: /scripts/lua/module/user_scripts/templates

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require("template_utils")
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local user_scripts = require("user_scripts")
local rest_utils = require "rest_utils"
local auth = require "auth"
local user_scripts_utils = require("user_scripts_utils")
local alert_severities = require("alert_severities")

if not auth.has_capability(auth.capabilities.user_scripts) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.scripts_config)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local script_subdir = _GET["subdir"]
local confset_id    = _GET["confset_id"]
local script_key    = _GET["script_key"]

local configset     = user_scripts.getConfigsets()[tonumber(confset_id)]
local script_type   = user_scripts.getScriptType(script_subdir)
local selected_script = user_scripts.loadModule(getSystemInterfaceId(), script_type, script_subdir, script_key)
local script_title = i18n(selected_script.gui.i18n_title) or selected_script.gui.i18n_title

local confset_name  = configset.name
local titles        = user_scripts_utils.load_configset_titles()

local hooks_config = user_scripts.getScriptConfig(configset, selected_script, script_subdir)
local generated_templates = selected_script.template:render(hooks_config)

local generated_breadcrumb = ui_utils.render_breadcrumb(i18n("about.user_scripts"), {
    {
        href = ntop.getHttpPrefix() .. "/lua/admin/scripts_config.lua?subdir=" .. script_subdir,
        label = titles[script_subdir],
    },
    {
        href = ntop.getHttpPrefix() .. "/lua/admin/edit_configset.lua?confset_id=" .. confset_id .. "&subdir=" .. script_subdir,
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
    edit_user_script = {
        breadcrumb = generated_breadcrumb,
        plugin = selected_script,
        alert_severities = alert_severities,
        script_title = script_title,
        rendered_hooks = generated_templates,
        
        hooks_config = hooks_config,
        script_subdir = script_subdir,
        confset_id = confset_id,
        script_key = script_key
    }
}

print(template.gen("pages/edit_user_script.template", base_context))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")