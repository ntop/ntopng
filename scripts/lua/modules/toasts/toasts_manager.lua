--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local page_utils = require("page_utils")
local template = require("template_utils")
local defined_toasts = require("defined_toasts")

local MAX_NON_PRIORITY_TOASTS_TO_SHOW = 1

-- Redis Key used to store the toast status
local REDIS_KEY = "ntopng.user.%s.dismissed_toasts.toast_%d"
local toats_manager = {}

local function toast_has_been_dismissed(toast_id)
    return ntop.getPref(string.format(REDIS_KEY, _SESSION['user'], toast_id)) == "1"
end

--- Returns an array of toast to be displayed inside the pages
--- @return table
function toats_manager.load_main_toasts()

    local container = {}
    local current_page = page_utils.get_active_entry()
    local curent_subpage = _GET['page']

    local non_priority_toasts = 0

    for _, toast in pairsByField(defined_toasts, 'id', asc) do

        -- We can only show MAX_NON_PRIORITY_TOASTSS_TO_SHOW toasts inside the page,
        -- in order to not overwhelm the user
        if (non_priority_toasts>= MAX_NON_PRIORITY_TOASTS_TO_SHOW) and not toast.has_priority then
            goto continue
        end

        -- if the current page is excluded then don't show the toast
        if (table.contains(toast.excluded_pages, current_page)) then
            goto continue
        end

        -- if we are in a excluded subpage then don't show the toast
        local excluded_subpages = toast.excluded_subpages or {[current_page] = {}}
        if (table.contains(excluded_subpages, curent_subpage)) then
            goto continue
        end

        -- check if the toast have the predicate function
        if (toast.predicate == nil) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "The toast '".. toast.id .. "' doesn't have a predicate function!")
            goto continue
        end

        -- has the toast be dissmissed by the user?
        local dismissed = (toast.dismissable and toast_has_been_dismissed(toast.id))
        if (dismissed) then goto continue end

        -- check if we can add the toast inside the page
        local subpages = toast.subpages or {[current_page] = {}}
        local can_add = (table.len(toast.pages) == 0) or (
            table.contains(toast.pages, current_page)) or (table.contains(subpages[current_page], curent_subpage))

        if can_add then
            local container_size = #container
            -- check the predicate function
            toast.predicate(toast, container)

            -- if the container size is increase then a toast
            -- has been added
            if #container > container_size and not toast.has_priority then
                non_priority_toasts = non_priority_toasts + 1
            end
        end

        -- used to jump to the next toast
        ::continue::
    end


    return container
end

--- Dismiss the toast if the toast is is valid, otherwise return an error
--- @param toast_id number The toast to dismiss
--- @return (boolean, string) True if the toast has been dismissed
function toats_manager.dismiss_toast(toast_id)

    -- Check if the toast id is valid in order to prevent to set not valid
    -- REDIS keys
    local compare = (function(n) return n.id == toast_id end)
    if not (table.contains(defined_toasts, toast_id, compare)) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "The passed toast ID is not valid!")
        return false, "Not a valid toast ID!"
    end

    -- Dismiss the toast
    ntop.setPref(string.format(REDIS_KEY, _SESSION['user'], toast_id), "1")
    return true, "Success"
end

--- Create a toast container inside the page where to render the alert toasts.
--- @param container_id string The container id attribute
--- @param toasts table A alert_toasts list to render inside the container,
function toats_manager.render_toasts(container_id, toasts)
    -- render the toasts
    print(template.gen('pages/components/toasts-container.template', {
        toasts = toasts,
        container_id = container_id
    }))
end

return toats_manager
