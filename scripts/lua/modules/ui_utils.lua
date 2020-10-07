--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local template_utils = require("template_utils")

local ui_utils = {}

function ui_utils.render_configuration_footer(item)
    return template_utils.gen('pages/components/manage-configuration-link.template', {item = item})
end

--- Single note element: { content = 'note description', hidden = true|false }
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