--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local template_utils = require("template_utils")

local ui_utils = {}

function ui_utils.render_configuration_footer(import_export_context, reset_context)

    local template = {
        template_utils.gen('pages/components/import-export-link.template', import_export_context),
        template_utils.gen('pages/components/reset-config-link.template', reset_context)
    }

    return table.concat(template, "\n")
end

--- Single not element: { content = 'note description', hidden = true|false }
function ui_utils.render_notes(notes_items)

    if notes_items == nil then
        ntop.traceEvent("The notes table is nil!")
        return ""
    end

    return template_utils.gen("pages/components/notes.template", {
        notes = notes_items
    })
end

return ui_utils